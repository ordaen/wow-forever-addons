-- The chat in the theme: chat windows (their background), tabs (unselected, selected, flashing) and the text (chat
-- lines, tab names) through OrdaenCore.UI. We never draw: UI.Dress hides Blizzard's art and draws the theme's look
-- under each frame, UI.DressFont puts the theme's font and the global text size on Blizzard's text. Sizes and
-- positions stay Blizzard's and Edit Mode's.
-- Cost: no events and nothing per frame. Hooks on Blizzard's tab colour and alert flash functions (they run when a
-- tab is selected or a message arrives in a hidden tab) and on opening a temporary (whisper) window.
local _, ns = ...

local Look = {}
ns.Look = Look

local UI = OrdaenCore.UI

-- Each window's art, by name suffix (all in api/forever/<CURRENT> for ChatFrame1): the background and its border
-- pieces, and the button frame beside it. The message lines are children too, so the list is explicit.
local WINDOW_ART = {
	"Background", "TopLeftTexture", "TopRightTexture", "BottomLeftTexture", "BottomRightTexture", "TopTexture",
	"BottomTexture", "LeftTexture", "RightTexture", "ButtonFrameBackground", "ButtonFrameTopLeftTexture",
	"ButtonFrameTopRightTexture", "ButtonFrameBottomLeftTexture", "ButtonFrameBottomRightTexture",
	"ButtonFrameTopTexture", "ButtonFrameBottomTexture", "ButtonFrameLeftTexture", "ButtonFrameRightTexture",
}
local TAB_STATES = { selected = "tabSelected", flash = "tabFlash" }

local on = false
local centering = false
local labelTab = {} -- tab name FontString -> its tab
local windows = {} -- chat window -> its dress
local tabs = {} -- tab -> its dress
local tabOf = {} -- chat window -> its tab
local flashing = {} -- chat window -> true while its tab flashes
-- Unread whisper tabs: lit (the flash look) until opened, with a badge counting the messages since. Only whisper
-- windows (Blizzard's temporary ones): a busy channel tab would count forever.
local unread = {} -- whisper window -> messages arrived while it wasn't the tab shown
local badges = {} -- tab -> its badge text element (in the tab's look)

local function selected(frame)
	return FCFDock_GetSelectedWindow(GeneralDockManager) == frame or not frame.isDocked
end

local function showTabState(frame)
	local tab = tabOf[frame]
	local dress = tab and tabs[tab]
	if not dress then
		return
	end
	local count = unread[frame] or 0
	if selected(frame) then
		unread[frame], count = nil, 0
		dress:SetState("selected")
	elseif count > 0 or flashing[frame] then
		dress:SetState("flash")
	else
		dress:SetState(nil)
	end
	local badge = badges[tab]
	if badge then
		badge.hidden = count == 0
		badge.args[1] = count
		dress.look:Refresh()
	end
end

-- A whisper window (Blizzard's temporary windows come after the fixed ones).
local function isWhisper(frame)
	return frame.isTemporary or (frame.GetID and frame:GetID() > NUM_CHAT_WINDOWS)
end

-- A line added to a whisper window: one more unread while it isn't the tab shown.
local function onMessage(frame)
	if on and isWhisper(frame) and not selected(frame) then
		unread[frame] = (unread[frame] or 0) + 1
		showTabState(frame)
	end
end

-- Blizzard places a tab's name low in the tab (room for its old art's top edge): in our look it sits in the middle,
-- the same space above and below. Blizzard moving it (a selected tab's text shifts) gets it centred again.
local function centerLabel(label)
	local tab = labelTab[label]
	if centering or not (on and tab) then
		return
	end
	centering = true
	label:ClearAllPoints()
	label:SetPoint("CENTER", tab, "CENTER", 0, 0)
	centering = false
end

-- The chat's scrollbar without its arrow buttons: the track takes their room (the mouse wheel and the thumb scroll).
local arrows = {} -- arrow button -> true (hidden while the look is on)
local tracks = {} -- track -> its points before
local function keepArrowHidden(button)
	if on and arrows[button] then
		button:Hide()
	end
end

local function slimScrollbar(frame)
	local bar = frame.ScrollBar
	if type(bar) ~= "table" or not bar.Track then
		return
	end
	for _, button in ipairs({ bar.Back, bar.Forward }) do
		if button and not arrows[button] then
			arrows[button] = true
			hooksecurefunc(button, "Show", keepArrowHidden)
		end
		if button then
			button:Hide()
		end
	end
	local track = bar.Track
	if not tracks[track] then
		local points = {}
		for i = 1, track:GetNumPoints() do
			points[i] = { track:GetPoint(i) }
		end
		tracks[track] = points
	end
	track:ClearAllPoints()
	track:SetPoint("TOP", bar, "TOP", 0, 0)
	track:SetPoint("BOTTOM", bar, "BOTTOM", 0, 0)
end

local function fullScrollbars()
	for button in pairs(arrows) do
		button:Show()
	end
	for track, points in pairs(tracks) do
		track:ClearAllPoints()
		for _, p in ipairs(points) do
			track:SetPoint(p[1], p[2], p[3], p[4], p[5])
		end
	end
end

local function dressWindow(frame)
	if not frame then
		return
	end
	slimScrollbar(frame)
	if windows[frame] then
		return
	end
	local name = frame:GetName()
	local art = {}
	for _, suffix in ipairs(WINDOW_ART) do
		local texture = _G[name .. suffix]
		if texture then
			art[#art + 1] = texture
		end
	end
	local dress = UI.Dress(frame, { style = "panel", size = "frame", cover = _G[name .. "Background"], art = art })
	if not dress then
		return -- OrdaenCore_UI can't load (the player was told)
	end
	windows[frame] = dress
	UI.DressFont(frame, "body")
	local tab = _G[name .. "Tab"]
	if tab then
		tabOf[frame] = tab
		-- The tab's look: its name stays Blizzard's (centred over it); a badge on the right counts unread whispers.
		---@type OrdaenUIText
		local badge = { format = "%d", args = { 0 }, style = "value", hidden = true, valign = "center" }
		badges[tab] = badge
		tabs[tab] = UI.Dress(tab, { style = "tab", size = "frame", states = TAB_STATES,
			block = { columns = { "1fr", "auto" }, padding = { 0, "xs", 0, 0 }, {}, badge } })
		if isWhisper(frame) then
			hooksecurefunc(frame, "AddMessage", onMessage)
		end
		local label = tab:GetFontString()
		if label then
			UI.DressFont(label, "label")
			labelTab[label] = tab
			hooksecurefunc(label, "SetPoint", centerLabel)
			centerLabel(label)
		end
		showTabState(frame)
	end
end

-- Blizzard recolours a tab when the selection changes: follow it for every window (the old and the new selection).
local function onTabColors()
	if not on then
		return
	end
	for frame in pairs(tabOf) do
		showTabState(frame)
	end
end

local function onFlash(frame)
	if frame then
		flashing[frame] = true
		if on then
			showTabState(frame)
		end
	end
end

local function onFlashStop(frame)
	if frame then
		flashing[frame] = nil
		if on then
			showTabState(frame)
		end
	end
end

local function dressAll()
	for i = 1, NUM_CHAT_WINDOWS do
		dressWindow(_G["ChatFrame" .. i])
	end
	-- Temporary windows (whisper tabs) come after the fixed ones.
	for i = NUM_CHAT_WINDOWS + 1, NUM_CHAT_WINDOWS + 40 do
		local frame = _G["ChatFrame" .. i]
		if not frame then
			break
		end
		dressWindow(frame)
	end
end

local function onTemporaryWindow()
	if on then
		dressAll()
	end
end

local hooked = false

--- Dress the chat: the "look" feature's OnEnable.
function Look.Enable()
	on = true
	for _, dress in pairs(windows) do
		dress:Apply()
	end
	for _, dress in pairs(tabs) do
		dress:Apply()
	end
	dressAll()
	-- Blizzard sized the tabs for its own font: size them again for the theme's (else "General" reads "Gen...").
	FCFDock_UpdateTabs(GeneralDockManager, true)
	if not hooked then
		hooked = true
		hooksecurefunc("FCFTab_UpdateColors", onTabColors)
		hooksecurefunc("FCF_StartAlertFlash", onFlash)
		hooksecurefunc("FCF_StopAlertFlash", onFlashStop)
		hooksecurefunc("FCF_OpenTemporaryWindow", onTemporaryWindow)
	end
	onTabColors()
end

--- Give the chat Blizzard's look back (the fonts stay the theme's until a /reload).
function Look.Disable()
	on = false
	fullScrollbars()
	for _, dress in pairs(windows) do
		dress:Undress()
	end
	for _, dress in pairs(tabs) do
		dress:Undress()
	end
end

--- What the dev-mode dump records.
function Look.Describe()
	local states = {}
	for tab, dress in pairs(tabs) do
		states[tab:GetName() or "?"] = dress.state or "normal"
	end
	local n = 0
	for _ in pairs(windows) do
		n = n + 1
	end
	local counts = {}
	for frame, count in pairs(unread) do
		counts[frame:GetName() or "?"] = count
	end
	return { on = on, windows = n, tabs = states, unread = counts }
end
