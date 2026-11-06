-- UI: the "Ordaen Dev" window and its minimap button. Dev mode only.
--
-- Open it with the gear button on the minimap edge (drag it around the minimap; a red number =
-- new errors), /ordaen, or /<addon command> debug. No addon compartment entry on purpose.
-- "Save for Claude & reload" dumps every Ordaen addon's state, stores an optional note and
-- reloads, so everything is on disk for Claude.
local addonName, ns = ...
local Store, Capture = ns.Store, ns.Capture

local UI = {}
ns.UI = UI

local TITLE = "Ordaen Dev"
local ROW_HEIGHT = 18
local LIST_WIDTH = 330
local BACKDROP = {
	bgFile = "Interface/Tooltips/UI-Tooltip-Background",
	edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
	edgeSize = 16,
	insets = { left = 4, right = 4, top = 4, bottom = 4 },
}
local TABS = {
	{ key = "errors", label = "Errors" },
	{ key = "perf", label = "Performance" },
	{ key = "log", label = "Log" },
	{ key = "inspect", label = "Inspect" },
}
local FILTERS = {
	{ key = "all", label = "All" },
	{ key = "ours", label = "Ordaen" },
	{ key = "other", label = "Other addons" },
	{ key = "taint", label = "Blocked actions" },
}
local SOURCE_COLORS = { ours = "ffff6666", other = "ffaaaaaa", taint = "ffffaa33" }

local window, button
local rows = {}
local selectedId
local currentTab = "errors"
local announced = {} -- error ids already announced in chat

local function backdropTemplate()
	return BackdropTemplateMixin and "BackdropTemplate" or nil
end

local function applyBackdrop(frame, alpha)
	if frame.SetBackdrop then
		frame:SetBackdrop(BACKDROP)
		frame:SetBackdropColor(0, 0, 0, alpha or 0.92)
	end
end

local function newButton(parent, text, width)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(width or 110, 22)
	b:SetText(text)
	return b
end

local function savePosition(frame, key)
	local point, _, relativePoint, x, y = frame:GetPoint(1)
	Store.Get().ui[key] = { point, relativePoint, x, y }
end

local function restorePosition(frame, key, ...)
	local saved = Store.Get().ui[key]
	frame:ClearAllPoints()
	if type(saved) == "table" and saved[1] then
		frame:SetPoint(saved[1], UIParent, saved[2], saved[3], saved[4])
	else
		frame:SetPoint(...)
	end
end

local function makeMovable(frame, key)
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		savePosition(self, key)
	end)
end

-- A read-only multi-line text box in a scroll frame; returns the edit box.
local function newTextView(parent)
	local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
	local text = CreateFrame("EditBox", nil, scroll)
	text:SetMultiLine(true)
	text:SetAutoFocus(false)
	text:SetFontObject(ChatFontNormal)
	text:SetWidth(400)
	text:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
	end)
	text:SetScript("OnTextChanged", function(self, userInput)
		if userInput then -- read-only: put the text back
			self:SetText(self.value or "")
		end
	end)
	scroll:SetScrollChild(text)
	scroll:SetScript("OnSizeChanged", function(_, width)
		text:SetWidth(math.max(50, width - 4))
	end)
	text.scroll = scroll
	return text
end

local function setTextView(view, value)
	view.value = value
	view:SetText(value)
	view:SetCursorPosition(0)
end

local function versionLine()
	local m = Store.Get().sessions[Store.Session()] or {}
	local parts = {
		string.format("Client %s (%s) %s", tostring(m.client), tostring(m.build), tostring(m.locale)),
		"Core " .. tostring(OrdaenCore and OrdaenCore.version),
	}
	local names = {}
	for name in pairs(ns.instances) do
		names[#names + 1] = name
	end
	table.sort(names)
	for _, name in ipairs(names) do
		parts[#parts + 1] = name .. " " .. tostring(Store.Metadata(name, "Version") or "?")
	end
	return table.concat(parts, ", ")
end

local function rowLabel(e)
	local key = e.kind == "taint" and "taint" or (e.source == "other" and "other" or "ours")
	local first = e.message:match("[^\n]*"):gsub("Interface[/\\]AddOns[/\\]", "")
	return string.format("|c%s%s|r x%d  %s", SOURCE_COLORS[key], e.source, e.count, first)
end

------------------------------------------------------------------------------------------------
-- Errors tab

local function selectError(id)
	selectedId = id
	UI.RefreshErrors()
end

local function newRow(list, i)
	local row = CreateFrame("Button", nil, list)
	row:SetHeight(ROW_HEIGHT)
	row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
	row:SetPoint("RIGHT", list, "RIGHT", 0, 0)
	row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
	row.selected = row:CreateTexture(nil, "BACKGROUND")
	row.selected:SetAllPoints()
	row.selected:SetColorTexture(0.3, 0.3, 0.6, 0.6)
	row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.text:SetPoint("LEFT", 4, 0)
	row.text:SetPoint("RIGHT", -4, 0)
	row.text:SetJustifyH("LEFT")
	row.text:SetWordWrap(false)
	row:SetScript("OnClick", function(self)
		selectError(self.entry and self.entry.id)
	end)
	rows[i] = row
	return row
end

local function raiseTestError()
	local exampleLocal = "visible in the error's locals"
	error("Ordaen Dev test error (" .. #exampleLocal .. ")")
end

local function buildErrorsTab(panel)
	local filterButtons = {}
	for i, filter in ipairs(FILTERS) do
		local b = newButton(panel, filter.label, 110)
		b:SetPoint("TOPLEFT", (i - 1) * 114, 0)
		b:SetScript("OnClick", function()
			Store.Get().ui.filter = filter.key
			selectedId = nil
			UI.RefreshErrors()
		end)
		b.key = filter.key
		filterButtons[i] = b
	end
	panel.filterButtons = filterButtons

	local clear = newButton(panel, "Clear all", 90)
	clear:SetPoint("TOPRIGHT", 0, 0)
	panel.clearButton = clear
	clear:SetScript("OnClick", function()
		Store.ClearErrors()
		selectedId = nil
		UI.RefreshErrors()
	end)

	local test = newButton(panel, "Test error", 90)
	test:SetPoint("RIGHT", clear, "LEFT", -4, 0)
	panel.testButton = test
	test:SetScript("OnClick", function()
		xpcall(raiseTestError, Capture.Handler)
	end)

	local listScroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
	listScroll:SetPoint("TOPLEFT", 0, -30)
	listScroll:SetPoint("BOTTOMLEFT", 0, 0)
	listScroll:SetWidth(LIST_WIDTH)
	local list = CreateFrame("Frame", nil, listScroll)
	list:SetSize(LIST_WIDTH, 1)
	listScroll:SetScrollChild(list)
	panel.list = list

	panel.empty = panel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
	panel.empty:SetPoint("TOPLEFT", listScroll, "TOPLEFT", 8, -8)
	panel.empty:SetText("No errors.")

	local copy = newButton(panel, "Select for copy", 130)
	copy:SetPoint("BOTTOMRIGHT", 0, 0)
	copy:SetScript("OnClick", function()
		panel.detail:SetFocus()
		panel.detail:HighlightText()
	end)
	local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	hint:SetPoint("RIGHT", copy, "LEFT", -8, 0)
	hint:SetText("then Ctrl+C")

	panel.detail = newTextView(panel)
	panel.detail.scroll:SetPoint("TOPLEFT", listScroll, "TOPRIGHT", 28, 0)
	panel.detail.scroll:SetPoint("BOTTOMRIGHT", copy, "TOPRIGHT", -24, 6)
end

function UI.RefreshErrors()
	if not (window and window:IsShown()) then
		return
	end
	local panel = window.panels.errors
	local filter = Store.Get().ui.filter or "all"
	for _, b in ipairs(panel.filterButtons) do
		if b.key == filter then
			b:LockHighlight()
		else
			b:UnlockHighlight()
		end
	end

	local list = Store.Filter(filter)
	local selected
	for i, e in ipairs(list) do
		if e.id == selectedId then
			selected = e
		end
		local row = rows[i] or newRow(panel.list, i)
		row.entry = e
		row.text:SetText(rowLabel(e))
		row:Show()
	end
	for i = #list + 1, #rows do
		rows[i]:Hide()
		rows[i].entry = nil
	end
	selected = selected or list[1]
	selectedId = selected and selected.id
	for i = 1, #list do
		rows[i].selected:SetShown(rows[i].entry == selected)
	end
	panel.list:SetHeight(math.max(1, #list * ROW_HEIGHT))
	panel.empty:SetShown(#list == 0)
	-- Don't replace the text under the user while they select it (a repeating error would
	-- otherwise reset the selection on every refresh).
	if not (panel.detail:HasFocus() and panel.detail.entryId == selectedId) then
		panel.detail.entryId = selectedId
		setTextView(panel.detail, selected and Store.FormatError(selected) or "")
	end

	Store.MarkSeen()
	UI.UpdateButton()
end

------------------------------------------------------------------------------------------------
-- Window

local function showTab(key)
	currentTab = key
	for _, tab in ipairs(window.tabs) do
		if tab.key == key then
			tab:LockHighlight()
		else
			tab:UnlockHighlight()
		end
	end
	for panelKey, panel in pairs(window.panels) do
		panel:SetShown(panelKey == key)
	end
	if key == "errors" then
		UI.RefreshErrors()
	end
end

local function updateCombat()
	if window then
		window.combat:SetText(InCombatLockdown and InCombatLockdown() and "|cffff3333In combat|r" or "")
	end
end

function UI.SaveForClaude()
	for _, instance in pairs(ns.instances) do
		pcall(instance.Dump)
	end
	local note = window and window.note:GetText() or ""
	Store.AddSave({
		note = note ~= "" and note or nil,
		combat = InCombatLockdown and InCombatLockdown() or false,
	})
	local reload = (C_UI and C_UI.Reload) or ReloadUI
	reload()
end

local function buildWindow()
	local f = CreateFrame("Frame", "OrdaenDevWindow", UIParent, backdropTemplate())
	f:SetSize(860, 520)
	f:SetFrameStrata("DIALOG")
	f:EnableMouse(true)
	applyBackdrop(f)
	restorePosition(f, "window", "CENTER", UIParent, "CENTER", 0, 0)
	makeMovable(f, "window")
	table.insert(UISpecialFrames, "OrdaenDevWindow") -- Escape closes it

	local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -14)
	title:SetText(TITLE)

	f.versions = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	f.versions:SetPoint("LEFT", title, "RIGHT", 12, 0)
	f.versions:SetPoint("RIGHT", f, "RIGHT", -140, 0)
	f.versions:SetJustifyH("LEFT")
	f.versions:SetWordWrap(false)

	f.combat = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	f.combat:SetPoint("TOPRIGHT", -40, -16)

	local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -2, -2)

	f.tabs, f.panels = {}, {}
	for i, tab in ipairs(TABS) do
		local b = newButton(f, tab.label, 120)
		b:SetPoint("TOPLEFT", 16 + (i - 1) * 124, -42)
		b.key = tab.key
		b:SetScript("OnClick", function()
			showTab(tab.key)
		end)
		f.tabs[i] = b

		local panel = CreateFrame("Frame", nil, f)
		panel:SetPoint("TOPLEFT", 16, -74)
		panel:SetPoint("BOTTOMRIGHT", -16, 52)
		panel:Hide()
		f.panels[tab.key] = panel
		if tab.key ~= "errors" then
			local soon = panel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
			soon:SetPoint("CENTER")
			soon:SetText(tab.label .. " is coming next.")
		end
	end
	buildErrorsTab(f.panels.errors)

	-- Channel test for the Ordaen Companion app (Channel.lua): runs 30 s, then stops by itself.
	local channel = newButton(f, "Channel test (30 s)", 150)
	channel:SetPoint("TOPRIGHT", -16, -42)
	channel:SetScript("OnClick", function()
		if ns.Channel then
			ns.Channel.Start()
		end
	end)
	f.channelButton = channel

	-- API dump (ApiDump.lua): one click dumps and reloads; once imported into the repo, clear it.
	local apiButton = newButton(f, "Dump game API", 150)
	apiButton:SetPoint("RIGHT", channel, "LEFT", -6, 0)
	apiButton:SetScript("OnClick", function(self)
		if ns.ApiDump.Exists() then
			ns.ApiDump.Clear()
			self:SetText("Dump game API")
		else
			ns.ApiDump.Run()
			UI.SaveForClaude()
		end
	end)
	f.apiButton = apiButton

	local save = newButton(f, "Save for Claude & reload", 220)
	save:SetPoint("BOTTOMRIGHT", -16, 16)
	save:SetScript("OnClick", UI.SaveForClaude)
	f.saveButton = save

	local noteLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	noteLabel:SetPoint("BOTTOMLEFT", 20, 22)
	noteLabel:SetText("Note for Claude:")
	f.note = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
	f.note:SetPoint("LEFT", noteLabel, "RIGHT", 10, 0)
	f.note:SetPoint("RIGHT", save, "LEFT", -12, 0)
	f.note:SetHeight(20)
	f.note:SetAutoFocus(false)
	f.note:SetScript("OnEnterPressed", f.note.ClearFocus)
	f.note:SetScript("OnEscapePressed", f.note.ClearFocus)

	f:SetScript("OnShow", function()
		f.apiButton:SetText(ns.ApiDump.Exists() and "Clear API dump" or "Dump game API")
		f.versions:SetText(versionLine())
		updateCombat()
		showTab(currentTab)
	end)
	f:Hide()
	return f
end

function UI.Toggle()
	window = window or buildWindow()
	window:SetShown(not window:IsShown())
end

------------------------------------------------------------------------------------------------
-- Floating button with the new-error badge

function UI.UpdateButton()
	if not button then
		return
	end
	local n = Store.NewCount()
	button.badge:SetText(n > 0 and tostring(n) or "")
	if button.SetBackdropBorderColor then
		if n > 0 then
			button:SetBackdropBorderColor(1, 0.2, 0.2)
		else
			button:SetBackdropBorderColor(0.6, 0.6, 0.6)
		end
	end
end

-- The button sits on the minimap's edge at an angle (degrees, 0 = right, counter-clockwise) and is
-- dragged around it, like LibDBIcon buttons (same APIs, confirmed on Forever by LibDBIcon). It is
-- deliberately not a compartment entry and its name doesn't look like a minimap button, so the
-- Ordaen Minimap drawer leaves it on the minimap.
local DEFAULT_ANGLE = 200
local EDGE_OFFSET = 4

--- Offset from the minimap center for an angle: on the circle for round minimaps, on the edge of
--- the square for square ones. Pure math, unit-tested.
function UI.EdgeOffset(angle, halfWidth, halfHeight, shape)
	local rad = math.rad(angle)
	local x, y = math.cos(rad), math.sin(rad)
	if shape == "SQUARE" then
		local m = math.max(math.abs(x), math.abs(y))
		x, y = x / m, y / m
	end
	return x * halfWidth, y * halfHeight
end

local function placeOnMinimap(b)
	if not Minimap then
		return
	end
	local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
	local halfWidth = (Minimap:GetWidth() or 140) / 2 + EDGE_OFFSET
	local halfHeight = (Minimap:GetHeight() or 140) / 2 + EDGE_OFFSET
	local x, y = UI.EdgeOffset(Store.Get().ui.buttonAngle or DEFAULT_ANGLE, halfWidth, halfHeight, shape)
	b:ClearAllPoints()
	b:SetPoint("CENTER", Minimap, "CENTER", x, y)
end
UI.PlaceButton = function()
	if button then
		placeOnMinimap(button)
	end
end

local function dragAroundMinimap(self)
	local mx, my = Minimap:GetCenter()
	local px, py = GetCursorPosition()
	local scale = Minimap:GetEffectiveScale()
	px, py = px / scale, py / scale
	Store.Get().ui.buttonAngle = math.deg(math.atan2(py - my, px - mx)) % 360
	placeOnMinimap(self)
end

local function buildButton()
	local parent = Minimap or UIParent
	local b = CreateFrame("Button", "OrdaenDevButton", parent, backdropTemplate())
	b:SetSize(28, 28)
	b:SetFrameStrata("MEDIUM")
	b:SetFrameLevel((parent:GetFrameLevel() or 1) + 10)
	applyBackdrop(b, 0.8)
	b:RegisterForClicks("LeftButtonUp")
	b:RegisterForDrag("LeftButton")
	if Minimap then
		placeOnMinimap(b)
		b:SetScript("OnDragStart", function(self)
			self:SetScript("OnUpdate", dragAroundMinimap)
		end)
		b:SetScript("OnDragStop", function(self)
			self:SetScript("OnUpdate", nil)
		end)
		-- Keep it on the edge when the minimap changes size (Ordaen Minimap's size slider).
		Minimap:HookScript("OnSizeChanged", function()
			placeOnMinimap(b)
		end)
	else
		restorePosition(b, "button", "RIGHT", UIParent, "RIGHT", -40, 160)
		makeMovable(b, "button")
	end

	local icon = b:CreateTexture(nil, "ARTWORK")
	icon:SetPoint("TOPLEFT", 4, -4)
	icon:SetPoint("BOTTOMRIGHT", -4, 4)
	icon:SetTexture("Interface\\Icons\\INV_Misc_Gear_01")

	b.badge = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	b.badge:SetPoint("BOTTOMRIGHT", -2, 2)
	b.badge:SetTextColor(1, 0.25, 0.25)

	b:SetScript("OnClick", UI.Toggle)
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:AddLine(TITLE)
		local n = Store.NewCount()
		if n > 0 then
			GameTooltip:AddLine(n .. " new error(s)", 1, 0.3, 0.3)
		end
		GameTooltip:AddLine("Click: open. Drag: move around the minimap.", 0.8, 0.8, 0.8)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	return b
end

------------------------------------------------------------------------------------------------
-- Startup and notifications

-- An error that repeats every frame must not rebuild the window every frame: new errors show
-- at once, repeats (only a count changes) refresh at most every REPEAT_REFRESH seconds.
local REPEAT_REFRESH = 0.5
local refreshPending = false

local function refreshSoon()
	if refreshPending then
		return
	end
	refreshPending = true
	local function run()
		refreshPending = false
		UI.RefreshErrors()
	end
	if C_Timer and C_Timer.After then
		C_Timer.After(REPEAT_REFRESH, run)
	else
		run()
	end
end

Store.OnChange(function(entry, isNew)
	if isNew or not entry then
		UI.UpdateButton()
		UI.RefreshErrors()
	elseif window and window:IsShown() then
		refreshSoon()
	end
	-- Announce new errors of our own addons once in chat; others only show in the badge.
	if isNew and entry and entry.source ~= "other" and not announced[entry.id] and DEFAULT_CHAT_FRAME then
		announced[entry.id] = true
		DEFAULT_CHAT_FRAME:AddMessage(string.format(
			"|cffff5555%s:|r new %s in %s. Click the gear button to see it.", TITLE,
			entry.kind == "taint" and "blocked action" or "error", entry.source))
	end
end)

SLASH_ORDAENDEV1 = "/ordaen"
SlashCmdList.ORDAENDEV = UI.Toggle

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
function UI.OnEvent(_, event, arg1)
	if event == "ADDON_LOADED" and arg1 == addonName then
		OrdaenCoreDebugDB = Store.Load(OrdaenCoreDebugDB, Store.ClientMeta())
	elseif event == "PLAYER_LOGIN" then
		button = button or buildButton()
		UI.UpdateButton()
	elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
		updateCombat()
	end
end
events:SetScript("OnEvent", UI.OnEvent)
