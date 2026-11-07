-- The chat in the theme: chat windows (their background), tabs (unselected, selected, flashing) and the text (chat
-- lines, tab names) through OrdaenCore.UI. We never draw: UI.Dress hides Blizzard's art and draws the theme's look
-- under each frame, UI.DressFont puts the theme's font and the global text size on Blizzard's text. Sizes and
-- positions stay Blizzard's and Edit Mode's.
-- Cost: no events and nothing per frame. Hooks on Blizzard's tab colour and alert flash functions (they run when a
-- tab is selected or a message arrives in a hidden tab), on opening a temporary (whisper) window, and on each
-- window's RefreshLayout (a resize or font change: one loop over its visible messages, no garbage).
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
local TAB_STATES = { selected = "chatTabSelected", flash = "chatTabFlash" }
-- Room around the messages (the user's request, 2026-11-06): our background reaches past Blizzard's by these spacing
-- tokens (left, right, top, bottom); less at the top, where the tabs sit.
local PADDING = { "md", "md", "sm", "md" }
-- Blizzard's chat has one spacing for the lines of a wrapped message and between messages (each message is one font
-- string, stacked by RefreshLayout with the font's spacing as the offset). We keep the font's spacing small for the
-- lines and re-anchor the messages with a bigger gap after each of Blizzard's layouts (the user's choice, 2026-11-06).
local LINE_GAP = "xs"
-- 8 at the default text size (the user's choice, 2026-11-07), following the text size.
local MESSAGE_GAP = "md"

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
local blizzardSpacing = {} -- chat window -> its line spacing before ours (given back when the look goes off)
local messageGap = 0 -- UI units: MESSAGE_GAP at the current text size
local layoutHooked = {} -- chat window -> true once its RefreshLayout is hooked

-- Blizzard stacked a window's messages (RefreshLayout: on a resize or a font change, not per message): the gap between
-- messages, ours. Only anchors: Blizzard's own fields and text stay untouched.
local function spaceMessages(frame)
	local lines = on and rawget(frame, "visibleLines")
	if not lines then
		return
	end
	if frame:GetInsertMode() == SCROLLING_MESSAGE_FRAME_INSERT_MODE_TOP then
		for i = 2, #lines do
			lines[i]:SetPoint("TOPLEFT", lines[i - 1], "BOTTOMLEFT", 0, -messageGap)
		end
	else
		for i = 2, #lines do
			lines[i]:SetPoint("BOTTOMLEFT", lines[i - 1], "TOPLEFT", 0, messageGap)
		end
	end
end

-- The theme's gaps on a chat window: between the lines of a message (the font's spacing; Blizzard's is kept to give
-- back) and between messages (after each of Blizzard's layouts).
local function spaceLines(frame)
	if blizzardSpacing[frame] == nil then
		blizzardSpacing[frame] = frame:GetSpacing() or 0
	end
	messageGap = UI.Space(MESSAGE_GAP)
	frame:SetSpacing(UI.Space(LINE_GAP))
	if not layoutHooked[frame] then
		layoutHooked[frame] = true
		hooksecurefunc(frame, "RefreshLayout", spaceMessages)
	end
	frame:MarkLayoutDirty() -- laid out again on its next refresh, with our gap
end

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
	local dress = UI.Dress(frame, {
		style = "panel", size = "frame", cover = _G[name .. "Background"], extend = PADDING, art = art,
	})
	if not dress then
		return -- OrdaenCore_UI can't load (the player was told)
	end
	windows[frame] = dress
	UI.DressFont(frame, "body")
	spaceLines(frame)
	local tab = _G[name .. "Tab"]
	if tab then
		tabOf[frame] = tab
		-- The tab's look: its name stays Blizzard's (centred over it); a badge on the right counts unread whispers.
		---@type OrdaenUIText
		local badge = { format = "%d", args = { 0 }, style = "value", hidden = true, valign = "center" }
		badges[tab] = badge
		tabs[tab] = UI.Dress(tab, { style = "chatTab", size = "frame", states = TAB_STATES,
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

-- Blizzard closes a whisper window and reuses it for the next conversation: its old unread count goes with it.
local function onWindowClosed(frame)
	if unread[frame] or flashing[frame] then
		unread[frame], flashing[frame] = nil, nil
		showTabState(frame)
	end
end

local hooked = false

-- Blizzard hangs the tab dock on the chat window (FCFDock_SetPrimary: BOTTOMLEFT to its TOPLEFT, 3 up), but our
-- background reaches further left by Blizzard's background and our padding: the first tab sat inside it (2026-11-07).
-- Its left edge goes to our background's; the right one and the height stay Blizzard's.
local DOCK_UP = 3 -- Blizzard's own offset
local function alignTabs()
	local chat = ChatFrame1
	local cover = on and Look.Cover(chat)
	local left, coverLeft = chat:GetLeft(), cover and cover:GetLeft()
	if not (left and coverLeft) then
		return
	end
	GeneralDockManager:SetPoint("BOTTOMLEFT", chat, "TOPLEFT", coverLeft - left, DOCK_UP)
end

-- The text size changed: the gaps follow it (the padding follows by itself: UI.Dress), and the tabs the padding.
local function onThemeChanged()
	if on then
		for frame in pairs(windows) do
			spaceLines(frame)
		end
		alignTabs()
	end
end

--- Dress the chat: the "look" feature's OnEnable.
function Look.Enable()
	on = true
	for frame, dress in pairs(windows) do
		dress:Apply()
		spaceLines(frame)
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
		hooksecurefunc("FCF_Close", onWindowClosed)
		EventRegistry:RegisterCallback("OrdaenUI.ThemeChanged", onThemeChanged, Look)
		-- Blizzard anchors the dock again (a new primary window, a reset): our edge again.
		hooksecurefunc("FCFDock_SetPrimary", alignTabs)
	end
	onTabColors()
	alignTabs()
end

--- Give the chat Blizzard's look back (the fonts stay the theme's until a /reload).
function Look.Disable()
	on = false
	fullScrollbars()
	for frame, dress in pairs(windows) do
		dress:Undress()
		if blizzardSpacing[frame] then
			frame:SetSpacing(blizzardSpacing[frame])
		end
		frame:MarkLayoutDirty() -- Blizzard's own stacking again
	end
	for _, dress in pairs(tabs) do
		dress:Undress()
	end
	GeneralDockManager:SetPoint("BOTTOMLEFT", ChatFrame1, "TOPLEFT", 0, DOCK_UP) -- Blizzard's anchor
end

--- Our background of a chat window (it reaches past Blizzard's by the padding), or nil when it has none.
--- Open sides of a chat window's look (Position: the edges it's docked to), or nil to close them. No-op while the
--- window isn't dressed.
---@param frame Frame
---@param sides table|nil
function Look.SetOpen(frame, sides)
	local dress = windows[frame]
	if dress and dress.opts.open ~= sides then
		dress:SetOpen(sides)
	end
end

---@param frame Frame
---@return Frame|nil
function Look.Cover(frame)
	local dress = windows[frame]
	return dress and dress.dressed and dress.look.frame or nil
end

--- What the dev-mode dump records.
-- Dev dump: the chat window's border corners as drawn, Blizzard's layout entries, and how texture coordinates behave
-- after SetAtlas on this client (absolute in the file, or relative to the atlas): the mirrored top corner drew
-- nothing (2026-11-07). Runs only on "Send state".
local probeTexture
local function pieceState(piece)
	if not piece then
		return false
	end
	local point, _, relPoint, x, y = piece:GetPoint(1)
	return { atlas = piece:GetAtlas() or false, coords = { piece:GetTexCoord() }, shown = piece:IsShown(),
		alpha = piece:GetAlpha(), width = piece:GetWidth(), height = piece:GetHeight(), scale = piece:GetScale(),
		point = { point or false, relPoint or false, x or false, y or false } }
end

local function describeCorners()
	local look = Look.Cover(ChatFrame1)
	local out = { look = look ~= nil } ---@type table<string, any>
	if look then
		for _, name in ipairs({ "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner", "TopEdge" }) do
			out[name] = pieceState(look[name])
		end
	end
	local layout = NineSliceLayouts and NineSliceLayouts.ButtonFrameTemplateNoPortrait
	if type(layout) == "table" then
		local entries = {}
		for key, entry in pairs(layout) do
			if type(entry) == "table" then
				local e = {}
				for k, v in pairs(entry) do
					e[k] = type(v) == "table" and "<table>" or v
				end
				entries[key] = e
			else
				entries[key] = tostring(entry)
			end
		end
		out.layout = entries
		local bottomRight = type(layout.BottomRightCorner) == "table" and layout.BottomRightCorner.atlas
		if bottomRight then
			local info = C_Texture.GetAtlasInfo(bottomRight)
			out.atlasInfo = info and { info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord,
				info.width, info.height, info.file or false } or false
			probeTexture = probeTexture or UIParent:CreateTexture()
			probeTexture:SetAtlas(bottomRight)
			out.afterSetAtlas = { probeTexture:GetTexCoord() }
			probeTexture:Hide()
		end
	end
	return out
end

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
	return { on = on, windows = n, tabs = states, unread = counts, corners = describeCorners() }
end
