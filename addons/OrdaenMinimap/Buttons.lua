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

local UI = OrdaenCore.UI
local SIZE = 28 -- our ring buttons: the "iconButton" style's padding (4 each side) around a 20 px icon
local ICON = 20
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
		ns.Debug:Logf("buttons: %s moved to %d", dragging.id, db.buttonAngles[dragging.id] or -1)
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

-- Our ring buttons are OrdaenCore.UI components in the "iconButton" style (the gear button's look).
local function iconSpec(name, iconTexture)
	return {
		name = name,
		parent = Minimap,
		style = "iconButton",
		strata = "MEDIUM",
		level = (Minimap:GetFrameLevel() or 1) + 8,
		{ image = iconTexture, size = ICON },
	}
end

local function onDragStart(button)
	startDrag(button.frame)
end

--- A new button of ours on the ring, e.g. the drawer button. Left-drag moves it around the minimap.
---@param id string key in ns.RING_DEFAULT_ANGLES
---@param name string global frame name
---@param iconTexture string
---@return OrdaenUIComponent|nil button nil when OrdaenCore_UI can't load (the player was told)
function Buttons.Create(id, name, iconTexture)
	local button = UI.Button(iconSpec(name, iconTexture))
	if not button then
		return nil
	end
	register(id, button.frame)
	button:On("dragstart", onDragStart)
	button:On("dragstop", stopDrag)
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

local trackingLook -- our component shown under Blizzard's (invisible) tracking button; takes no mouse

-- Blizzard's button gets the hover, so ours shows its highlight on request.
local function highlightOn()
	trackingLook:LockHighlight()
end

local function highlightOff()
	trackingLook:UnlockHighlight()
end

--- Dress Blizzard's tracking button in our style. Blizzard's frame stays on top and gets the clicks
--- (its menu keeps working); its own art is made invisible and ours sits underneath.
local function skinTracking(frame)
	local clickable = childButton(frame) or frame
	-- Forever has no API for the tracked type's icon (no GetTrackingTexture), so a spyglass.
	trackingLook = UI.Block(iconSpec("OrdaenMinimapTrackingButton", TRACKING_ICON))
	if not trackingLook then
		return clickable -- OrdaenCore_UI can't load: Blizzard's own look stays
	end
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
	ns.Debug:Logf("buttons: adopted %s (%s)", entry.id, name)
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
		C_Timer.After(RETRY_DELAY, ns.Debug:Wrap(adoptAll))
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
	return { found = found, placed = placed, trackingLook = trackingLook and trackingLook.frame or false }
end
