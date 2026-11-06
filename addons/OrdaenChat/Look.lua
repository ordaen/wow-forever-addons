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
local windows = {} -- chat window -> its dress
local tabs = {} -- tab -> its dress
local tabOf = {} -- chat window -> its tab
local flashing = {} -- chat window -> true while its tab flashes

local function selected(frame)
	return FCFDock_GetSelectedWindow(GeneralDockManager) == frame or not frame.isDocked
end

local function showTabState(frame)
	local tab = tabOf[frame]
	local dress = tab and tabs[tab]
	if not dress then
		return
	end
	if selected(frame) then
		dress:SetState("selected")
	elseif flashing[frame] then
		dress:SetState("flash")
	else
		dress:SetState(nil)
	end
end

local function dressWindow(frame)
	if not frame or windows[frame] then
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
		tabs[tab] = UI.Dress(tab, { style = "tab", size = "frame", states = TAB_STATES })
		local label = tab:GetFontString()
		if label then
			UI.DressFont(label, "label")
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
	return { on = on, windows = n, tabs = states }
end
