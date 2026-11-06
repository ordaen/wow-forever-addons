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
local L = ns.L
local SIZE = 28 -- our ring buttons: the "iconButton" style's padding (4 each side) around a 20 px icon
local ICON = 20
local TRACKING_ICON = "Interface\\Icons\\INV_Misc_Spyglass_02"
local RETRY_DELAY = 5 -- some Blizzard buttons are created after login

-- Blizzard's buttons on Forever's (modern) minimap. The API dump confirms MinimapCluster.Tracking,
-- .IndicatorFrame and ExpansionLandingPageMinimapButton; the frames inside IndicatorFrame are one level
-- deeper than the dump goes (their mixins exist), so they are looked up and skipped when missing.
local BLIZZARD = {
	{ id = "tracking", names = { "MinimapCluster.Tracking" }, skin = true, tip = "tracking" },
	-- keepParent: these call self:GetParent():Layout() on their events (Blizzard_Minimap Minimap.lua:520), so
	-- they must stay children of IndicatorFrame. We only anchor them to the minimap.
	{ id = "mail", names = { "MinimapCluster.IndicatorFrame.MailFrame" }, keepParent = true, tip = "mail" },
	{ id = "craftingOrder", names = { "MinimapCluster.IndicatorFrame.CraftingOrderFrame" }, keepParent = true },
	{ id = "landing", names = { "ExpansionLandingPageMinimapButton" }, tip = "landing" },
	-- The Ordaen Dev gear button (dev mode, wow-dev-tools). While `ordaenPlacedBy` is set, it leaves its
	-- position and dragging to us (agreed with the dev-tools session); clicks and tooltip stay its own.
	-- The dev addon makes it seconds after login, so it also announces it (DEV_BUTTON_CREATED below).
	{ id = "dev", names = { "OrdaenDevButton" }, claim = true },
}
-- EventRegistry event the dev addon triggers right after creating its gear button (with the button). Taking
-- the button over on that event, as well as at Apply, works in either order: no timer, no window in which
-- the button sits at the dev addon's own spot on the border.
local DEV_BUTTON_CREATED = "OrdaenDevButton.Created"
local DEV_ENTRY = BLIZZARD[#BLIZZARD]

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

-- Tooltips for Blizzard's buttons ---------------------------------------------------------------
-- Everything on our minimap shows OrdaenCore.UI tooltips, Blizzard's buttons too: their OnEnter shows
-- GameTooltip, a hook hides it and shows ours. No title: what the tooltip belongs to is under the mouse
-- (CLAUDE.md, "Tooltips"). Built once; filled on hover from Blizzard's own data and strings.

local MAX_LINES = 6
local RING_TIP = { side = "left" } -- side set per hover from the button's angle

local function lineList(style)
	local lines = {}
	for i = 1, MAX_LINES do
		lines[i] = { text = "", style = style, hidden = true }
	end
	return lines
end

local function addLine(lines, n, value)
	if n < MAX_LINES and type(value) == "string" and value ~= "" then
		n = n + 1
		lines[n].text, lines[n].hidden = value, false
	end
	return n
end

local function hideFrom(lines, n)
	for i = n + 1, MAX_LINES do
		lines[i].hidden = true
	end
end

local trackingLines = lineList("value")
local trackingNone = { text = MINIMAP_TRACKING_TOOLTIP_NONE, style = "label", hidden = true }
local trackingBlock = {}
for i = 1, MAX_LINES do
	trackingBlock[i] = trackingLines[i]
end
trackingBlock[#trackingBlock + 1] = trackingNone
trackingBlock[#trackingBlock + 1] = { text = L.TRACKING_TOOLTIP_MENU, style = "hint" }
local trackingTip = UI.Tooltip(trackingBlock, RING_TIP)

-- What is tracked now. Forever's info has `name` and `active` like mainline's; anything else is unused.
local function fillTracking()
	local n = 0
	for i = 1, C_Minimap.GetNumTrackingTypes() do
		local info = C_Minimap.GetTrackingInfo(i)
		if info and info.active then
			n = addLine(trackingLines, n, info.name)
		end
	end
	hideFrom(trackingLines, n)
	trackingNone.hidden = n > 0
	return true
end

local mailFrom = { text = HAVE_MAIL_FROM, style = "label" }
local mailLines = lineList("value")
local mailBlock = { mailFrom }
for i = 1, MAX_LINES do
	mailBlock[#mailBlock + 1] = mailLines[i]
end
local mailTip = UI.Tooltip(mailBlock, RING_TIP)

local function fillMail()
	local a, b, c = GetLatestThreeSenders()
	local n = addLine(mailLines, 0, a)
	n = addLine(mailLines, n, b)
	n = addLine(mailLines, n, c)
	hideFrom(mailLines, n)
	mailFrom.text = n > 0 and HAVE_MAIL_FROM or HAVE_MAIL
	return true
end

local landingTitle = { text = "", style = "value" }
local landingText = { text = "", style = "hint" }
local landingTip = UI.Tooltip({ landingTitle, landingText }, RING_TIP)

-- Blizzard's expansion button keeps its name and description in .title / .description (mainline code);
-- without them its own tooltip stays.
local function fillLanding(frame)
	local title, text = rawget(frame, "title"), rawget(frame, "description")
	if type(title) ~= "string" then
		return false
	end
	landingTitle.text = title
	landingText.text = type(text) == "string" and text or ""
	landingText.hidden = landingText.text == ""
	landingTip.hotkey = UI.Binding("TOGGLEGARRISONLANDINGPAGE")
	return true
end

local TIPS = {
	tracking = { tip = trackingTip, fill = fillTracking },
	mail = { tip = mailTip, fill = fillMail },
	landing = { tip = landingTip, fill = fillLanding },
}

local tipOf = {} -- hovered frame -> { tip, fill, item }

local function showTip(frame)
	local t = tipOf[frame]
	if not (t and t.fill(frame)) then
		return -- nothing to say: Blizzard's own tooltip stays
	end
	if GameTooltip:IsOwned(frame) then
		GameTooltip:Hide()
	end
	-- Left half of the ring: the tooltip goes left, right half: right, so it never covers the map.
	local angle = ns.ButtonAngle(db and db.buttonAngles, t.item.id) % 360
	RING_TIP.side = (angle > 90 and angle < 270) and "left" or "right"
	t.tip:Show(frame)
end

local function hideTip(frame)
	local t = tipOf[frame]
	if t then
		t.tip:Hide(frame)
	end
end

local function useOurTip(entry, hovered, item)
	local spec = TIPS[entry.tip]
	if not spec then
		return
	end
	tipOf[hovered] = { tip = spec.tip, fill = spec.fill, item = item }
	hovered:HookScript("OnEnter", showTip)
	hovered:HookScript("OnLeave", hideTip)
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
	local item, target = register(entry.id, frame, dragFrame)
	target:HookScript("OnDragStart", startDrag)
	target:HookScript("OnDragStop", stopDrag)
	useOurTip(entry, target, item)
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

local function onDevButtonCreated()
	adopt(DEV_ENTRY)
end

--- Take over Blizzard's buttons (once) and place everything for the current settings.
---@param savedDb table OrdaenMinimapDB
function Buttons.Apply(savedDb)
	db = savedDb
	if not setUp then
		setUp = true
		adoptAll()
		EventRegistry:RegisterCallback(DEV_BUTTON_CREATED, onDevButtonCreated, Buttons)
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
