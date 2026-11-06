-- Buttons around the minimap, WoW side. Every button lives just outside the border, at a saved angle,
-- and is dragged around it (like the Ordaen Dev gear button):
--   * our own buttons (the drawer button) in one style: the gear button's dark backdrop with an icon;
--   * Blizzard's tracking button, dressed in that style (its own art hidden; it still gets the clicks,
--     so its menu works as before);
--   * Blizzard's other buttons and indicators (mail, queue, difficulty, ...), moved off the map as they are.
-- Blizzard's layout code moves its buttons back now and then; hooks put them back at our angle.
local _, ns = ...

local Buttons = {}
ns.Buttons = Buttons

local SIZE = 28
local ICON_INSET = 4
local BACKDROP = { -- same as the Ordaen Dev gear button
	bgFile = "Interface/Tooltips/UI-Tooltip-Background",
	edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
	edgeSize = 16,
	insets = { left = 4, right = 4, top = 4, bottom = 4 },
}
local TRACKING_ICON = "Interface\\Icons\\INV_Misc_Spyglass_02"
local RETRY_DELAY = 5 -- some Blizzard buttons are created after login

-- Blizzard's buttons on Forever's (modern) minimap. The API dump confirms MinimapCluster.Tracking,
-- .IndicatorFrame and ExpansionLandingPageMinimapButton; the frames inside IndicatorFrame are one level
-- deeper than the dump goes (their mixins exist), so they are looked up and skipped when missing.
local BLIZZARD = {
	{ id = "tracking", names = { "MinimapCluster.Tracking" }, skin = true },
	-- keepParent: these call self:GetParent():Layout() on their events (Blizzard_Minimap Minimap.lua:520), so
	-- they must stay children of IndicatorFrame. We only anchor them to the minimap.
	{ id = "mail", names = { "MinimapCluster.IndicatorFrame.MailFrame" }, keepParent = true },
	{ id = "craftingOrder", names = { "MinimapCluster.IndicatorFrame.CraftingOrderFrame" }, keepParent = true },
	{ id = "landing", names = { "ExpansionLandingPageMinimapButton" } },
	-- The Ordaen Dev gear button (dev mode, wow-dev-tools). While `ordaenPlacedBy` is set, it leaves its
	-- position and dragging to us (agreed with the dev-tools session); clicks and tooltip stay its own.
	{ id = "dev", names = { "OrdaenDevButton" }, claim = true },
}

local db
local items = {} -- id -> { id, frame }
local itemByFrame = {}
local found = {} -- id -> name found, or false (dev-mode dump)
local applying = false
local setUp = false

local function outset()
	local style = ns.GetBorderStyle(db.borderStyle)
	if style.backdrop or style.frame then
		return style.outset or 0
	end
	return 0
end

local function place(item)
	if not db or not ns.Map.active then
		return
	end
	local frame = item.frame
	-- The ring is computed in minimap units; anchor offsets are in the button's own units. The two differ
	-- by the ratio of effective scales (the button's own scale, or a different parent's).
	local mapScale = Minimap:GetEffectiveScale() or 1
	local k = mapScale / (frame:GetEffectiveScale() or mapScale) -- button units per minimap unit
	if k <= 0 then
		k = 1
	end
	local half = (frame:GetWidth() or SIZE) / k / 2
	local x, y = ns.RingOffset(ns.ButtonAngle(db.buttonAngles, item.id),
		(Minimap:GetWidth() or 140) / 2, (Minimap:GetHeight() or 140) / 2, outset(), half)
	applying = true
	frame:ClearAllPoints()
	frame:SetPoint("CENTER", Minimap, "CENTER", x * k, y * k)
	applying = false
end

--- Place every button again (border style, size or angle changed).
function Buttons.Layout()
	for _, item in pairs(items) do
		place(item)
	end
end

-- Hook bodies run whenever Blizzard re-anchors a button: plain functions, no closures or tables.
local function onForeignSetPoint(frame)
	if applying then
		return
	end
	local item = itemByFrame[frame]
	if item then
		place(item)
	end
end

local function onForeignSetParent(frame)
	if applying then
		return
	end
	if frame:GetParent() ~= Minimap then
		applying = true
		frame:SetParent(Minimap)
		applying = false
	end
	onForeignSetPoint(frame)
end

-- Dragging --------------------------------------------------------------------------------------

local driver -- runs OnUpdate only while a button is being dragged
local dragging

local function follow()
	local mx, my = Minimap:GetCenter()
	if not mx or not dragging then
		return
	end
	local px, py = GetCursorPosition()
	local s = Minimap:GetEffectiveScale() or 1
	db.buttonAngles[dragging.id] = math.floor(ns.RingAngle(px / s - mx, py / s - my) + 0.5) % 360
	place(dragging)
end

local function startDrag(frame)
	local item = itemByFrame[frame] or frame.ordaenRingItem
	if not item then
		return
	end
	dragging = item
	if not driver then
		driver = CreateFrame("Frame")
	end
	driver:SetScript("OnUpdate", follow)
end

local function stopDrag()
	if driver then
		driver:SetScript("OnUpdate", nil)
	end
	if dragging then
		ns.Debug.Logf("buttons: %s moved to %d", dragging.id, db.buttonAngles[dragging.id] or -1)
	end
	dragging = nil
end

local function register(id, frame, dragFrame)
	local item = { id = id, frame = frame }
	items[id] = item
	itemByFrame[frame] = item
	dragFrame = dragFrame or frame
	dragFrame.ordaenRingItem = item
	dragFrame:RegisterForDrag("LeftButton")
	return item, dragFrame
end

-- Our buttons -----------------------------------------------------------------------------------

--- Dress a button in our style (the gear button's look): dark backdrop, icon, highlight.
---@return table icon texture
function Buttons.Style(button)
	button:SetSize(SIZE, SIZE)
	if button.SetBackdrop then
		button:SetBackdrop(BACKDROP)
		button:SetBackdropColor(0, 0, 0, 0.8)
	end
	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetPoint("TOPLEFT", ICON_INSET, -ICON_INSET)
	icon:SetPoint("BOTTOMRIGHT", -ICON_INSET, ICON_INSET)
	button.icon = icon
	local highlight = button:CreateTexture(nil, "HIGHLIGHT")
	highlight:SetPoint("TOPLEFT", ICON_INSET, -ICON_INSET)
	highlight:SetPoint("BOTTOMRIGHT", -ICON_INSET, ICON_INSET)
	highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
	highlight:SetBlendMode("ADD")
	button.highlight = highlight
	return icon
end

---@class OrdaenMinimapButton : Button, BackdropTemplate
---@field icon Texture set by Buttons.Style
---@field highlight Texture set by Buttons.Style

---@return OrdaenMinimapButton
local function newStyled(name, frameType)
	local template = BackdropTemplateMixin and "BackdropTemplate" or nil
	local button = CreateFrame(frameType or "Button", name, Minimap, template) --[[@as OrdaenMinimapButton]]
	Buttons.Style(button)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 8)
	return button
end

--- A new button of ours on the ring, e.g. the drawer button. Left-drag moves it around the minimap.
---@param id string key in ns.RING_DEFAULT_ANGLES
---@param name string global frame name
---@param iconTexture string
---@return table button
function Buttons.Create(id, name, iconTexture)
	local button = newStyled(name)
	button.icon:SetTexture(iconTexture)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	register(id, button)
	button:SetScript("OnDragStart", startDrag)
	button:SetScript("OnDragStop", stopDrag)
	place(items[id])
	return button
end

-- Blizzard's buttons ----------------------------------------------------------------------------

local function hideArt(frame)
	for _, region in ipairs({ frame:GetRegions() }) do
		region:SetAlpha(0)
	end
	for _, child in ipairs({ frame:GetChildren() }) do
		hideArt(child)
	end
end

--- The clickable child Blizzard keeps in `.Button` (modern clients), if any.
local function childButton(frame)
	local button = rawget(frame, "Button")
	if type(button) == "table" then
		return button
	end
	return nil
end

local trackingLook -- our styled frame shown under Blizzard's (invisible) tracking button

local function highlightOn()
	trackingLook.highlight:Show()
end

local function highlightOff()
	trackingLook.highlight:Hide()
end

--- Dress Blizzard's tracking button in our style. Blizzard's frame stays on top and gets the clicks
--- (its menu keeps working); its own art is made invisible and ours sits underneath.
local function skinTracking(frame)
	local clickable = childButton(frame) or frame
	trackingLook = newStyled("OrdaenMinimapTrackingButton", "Frame")
	trackingLook:EnableMouse(false)
	trackingLook.highlight:SetDrawLayer("OVERLAY")
	trackingLook.highlight:Hide()
	trackingLook:SetPoint("CENTER", frame, "CENTER")
	frame:SetSize(SIZE, SIZE)
	if clickable ~= frame then
		clickable:ClearAllPoints()
		clickable:SetAllPoints(frame)
	end
	frame:SetFrameStrata("MEDIUM")
	frame:SetFrameLevel(trackingLook:GetFrameLevel() + 2)
	hideArt(frame)
	clickable:HookScript("OnEnter", highlightOn)
	clickable:HookScript("OnLeave", highlightOff)
	-- Forever has no API for the tracked type's icon (no GetTrackingTexture), so a spyglass.
	trackingLook.icon:SetTexture(TRACKING_ICON)
	return clickable
end

local function adopt(entry)
	if items[entry.id] then
		return
	end
	local frame, name = ns.FindFirst(entry.names)
	found[entry.id] = name or false
	if not frame then
		return
	end
	if entry.claim then
		frame.ordaenPlacedBy = "OrdaenMinimap"
	end
	applying = true
	if not entry.keepParent then
		frame:SetParent(Minimap)
	end
	local dragFrame
	if entry.skin then
		dragFrame = skinTracking(frame)
	else
		dragFrame = childButton(frame) or frame
	end
	applying = false
	local _, target = register(entry.id, frame, dragFrame)
	target:HookScript("OnDragStart", startDrag)
	target:HookScript("OnDragStop", stopDrag)
	hooksecurefunc(frame, "SetPoint", onForeignSetPoint)
	if not entry.keepParent then
		hooksecurefunc(frame, "SetParent", onForeignSetParent)
	end
	place(items[entry.id])
	ns.Debug.Logf("buttons: adopted %s (%s)", entry.id, name)
end

local function adoptAll()
	for _, entry in ipairs(BLIZZARD) do
		adopt(entry)
	end
end

--- Take over Blizzard's buttons (once) and place everything for the current settings.
---@param savedDb table OrdaenMinimapDB
function Buttons.Apply(savedDb)
	db = savedDb
	if not setUp then
		setUp = true
		adoptAll()
		C_Timer.After(RETRY_DELAY, ns.Debug.Wrap(adoptAll))
		Minimap:HookScript("OnSizeChanged", Buttons.Layout)
	end
	Buttons.Layout()
end

--- What the dev-mode dump records about the buttons.
function Buttons.Describe()
	local placed = {}
	for id, item in pairs(items) do
		placed[id] = { angle = ns.ButtonAngle(db and db.buttonAngles, id), frame = item.frame }
	end
	return { found = found, placed = placed, trackingLook = trackingLook }
end
