-- Ordaen Chat's tabs, WoW side: sets up the default layout (TabLayout.lua) once per character through Blizzard's
-- own chat window API, so the game saves it as usual and the player can change any tab in Blizzard's tab menu
-- afterwards; we never apply it again unless asked (/ochat tabs). New channels go to the Channels tab.
-- Cost: nothing at all after the first login, except one handler for channel notices (rare) while sortChannels is on.
local _, ns = ...

local Tabs = {}
ns.Tabs = Tabs

local L = ns.L

local function debug()
	return ns.Debug
end

-- The shown or docked chat window named `title` (1 .. NUM_CHAT_WINDOWS), or nil.
local function windowNamed(title)
	for i = 1, NUM_CHAT_WINDOWS do
		local name, _, _, _, _, _, shown, _, docked = GetChatWindowInfo(i)
		if name == title and (shown or docked) then
			return _G["ChatFrame" .. i]
		end
	end
	return nil
end

-- The window for a tab: found by name, else a new docked one (nil when all windows are taken).
local function openWindow(title)
	return windowNamed(title) or FCF_OpenNewWindow(title, true)
end

local function setGroups(frame, groups)
	frame:RemoveAllMessageGroups()
	for _, group in ipairs(groups) do
		frame:AddMessageGroup(group)
	end
end

local function channelsWindow()
	for _, tab in ipairs(ns.TAB_LAYOUT) do
		if tab.channels then
			return windowNamed(_G[tab.title])
		end
	end
	return nil
end

-- Move `channel` from every other window into `target` (General keeps none: they have their own tab).
local function moveChannel(channel, target)
	for i = 1, NUM_CHAT_WINDOWS do
		local frame = _G["ChatFrame" .. i]
		if frame and frame ~= target and frame:ContainsChannel(channel) then
			frame:RemoveChannel(channel)
		end
	end
	if not target:ContainsChannel(channel) then
		target:AddChannel(channel)
	end
end

local moving = false

-- The docked windows' IDs in dock order (dev mode: the state dump and the log).
local function dockIds()
	local ids = {}
	for i, frame in ipairs(FCFDock_GetChatFrames(GeneralDockManager) or {}) do
		ids[i] = frame:GetID()
	end
	return ids
end
Tabs.DockIds = dockIds

local lastSeen
-- Dev mode: log what CombatLogLast found, once per different state (Journal stayed second, 2026-11-06).
local function noteDock(what)
	if ns.Debug:IsEnabled() then
		local seen = what .. ", dock " .. table.concat(dockIds(), ",")
		if seen ~= lastSeen then
			lastSeen = seen
			ns.Debug:Logf("tabs: Journal %s", seen)
		end
	end
end

--- Keep Journal (Blizzard's Combat Log window) the last docked tab (new tabs and whisper tabs are added after it).
function Tabs.CombatLogLast()
	local combat = ChatFrame2
	if moving then
		return
	end
	local t = ns.Debug:TimeStart()
	if not (combat and combat.isDocked) then
		if ns.Debug:IsEnabled() then -- a hooked path: no string unless it's logged
			noteDock("not docked (isDocked " .. tostring(combat and combat.isDocked) .. ")")
		end
		return
	end
	local relayout = false
	if combat.isStaticDocked then
		-- Blizzard draws a "static docked" window's tab (General's, Combat Log's) on the dock itself, right after
		-- General, whatever its place in the dock: Journal stayed second although the dock had it last (2026-11-06).
		-- Clearing the flag lets its tab follow the dock order. The user's choice, knowing the cost: a field an addon
		-- writes is tainted, so Blizzard's tab code runs tainted after reading it (watch for "tainted by OrdaenChat").
		combat.isStaticDocked = false -- luacheck: ignore 122 (deliberate taint, the user's choice: see above)
		relayout = true
	end
	local docked = FCFDock_GetChatFrames(GeneralDockManager)
	if not docked or docked[#docked] == combat then
		noteDock("already last")
	else
		moving = true
		-- Docking a window that's already docked doesn't move it (Combat Log stayed second, 2026-11-06): take it
		-- out of the dock, then dock it at the end.
		FCF_UnDockFrame(combat)
		FCF_DockFrame(combat, #FCFDock_GetChatFrames(GeneralDockManager) + 1, false)
		-- Blizzard re-docks from each window's saved place (at login, renaming a window): save the new order.
		for i, frame in ipairs(FCFDock_GetChatFrames(GeneralDockManager)) do
			SetChatWindowDocked(frame:GetID(), i)
		end
		moving = false
		noteDock("moved to the end")
	end
	if relayout then
		moving = true
		-- Blizzard's FCFDock_UpdateTabs places the tabs first and anchors the scroll frame of the other tabs to the last
		-- static tab only afterwards: it is still anchored to Combat Log's tab, which now goes inside it, so placing the
		-- tab fails ("Cannot anchor to a region dependent on it", 2026-11-06) and the tabs vanish. Anchor it to
		-- General's tab first, as Blizzard does next.
		GeneralDockManager.scrollFrame:SetPoint("LEFT", ChatFrame1Tab, "RIGHT", 0, 0)
		FCFDock_UpdateTabs(GeneralDockManager, true)
		moving = false
		noteDock("no longer static docked")
	end
	ns.Debug:TimeEnd(t, "chat: journal last")
end

--- Set up the default tabs now (first login of a character with this layout version, or /ochat tabs).
---@param charDb table OrdaenChatCharDB
function Tabs.Apply(charDb)
	local general = ChatFrame1
	-- The channels the player has: those General shows now (Blizzard puts every channel there by default).
	local channels = ns.ChannelNames(general.channelList)
	for _, tab in ipairs(ns.TAB_LAYOUT) do
		local frame
		if tab.window then
			frame = _G["ChatFrame" .. tab.window]
		else
			frame = openWindow(_G[tab.title])
		end
		if not frame then
			ns.Print(L.NO_FREE_WINDOW:format(_G[tab.title]))
		else
			if tab.name then
				FCF_SetWindowName(frame, L[tab.name])
			end
			setGroups(frame, tab.groups)
			if tab.channels then
				for _, channel in ipairs(channels) do
					moveChannel(channel, frame)
				end
			end
		end
	end
	ns.Whispers.UseTabs()
	Tabs.CombatLogLast()
	charDb.tabLayout = ns.TAB_LAYOUT_VERSION
	FCF_SelectDockFrame(general)
	debug():Logf("tabs: layout %d applied, channels %s", ns.TAB_LAYOUT_VERSION, table.concat(channels, ", "))
	ns.Print(L.TABS_DONE)
end

--- Give `channel` its own tab (by its name), out of the Channels tab.
---@param channel string
function Tabs.ForChannel(channel)
	local joined = false
	for _, name in ipairs(ns.ChannelNames(ChatFrame1.channelList)) do
		joined = joined or name:lower() == channel:lower()
	end
	local window = channelsWindow()
	for _, name in ipairs(ns.ChannelNames(window and window.channelList)) do
		if name:lower() == channel:lower() then
			joined, channel = true, name
		end
	end
	if not joined and GetChannelName(channel) == 0 then
		ns.Print(L.CHANNEL_NOT_JOINED:format(channel))
		return
	end
	local frame = openWindow(channel)
	if not frame then
		ns.Print(L.NO_FREE_WINDOW:format(channel))
		return
	end
	setGroups(frame, { "CHANNEL" })
	moveChannel(channel, frame)
	Tabs.CombatLogLast()
	FCF_SelectDockFrame(frame)
	ns.Print(L.TAB_FOR_CHANNEL:format(channel))
end

-- A channel the player joined goes to the Channels tab, unless a tab other than General already shows it.
local function onChannelNotice(_, notice, _, _, _, _, _, _, _, channel)
	if not (ns.IsJoinNotice(notice) and type(channel) == "string" and channel ~= "") then
		return
	end
	local target = channelsWindow()
	if not target or target:ContainsChannel(channel) then
		return
	end
	for i = 2, NUM_CHAT_WINDOWS do
		local frame = _G["ChatFrame" .. i]
		if frame and frame:ContainsChannel(channel) then
			return -- the player keeps it in a tab of their own
		end
	end
	moveChannel(channel, target)
	debug():Logf("tabs: channel %s moved to the Channels tab", channel)
end

local hookedLast = false

--- Set up the default tabs if this character hasn't had this layout version yet (the "layout" feature).
---@param charDb table OrdaenChatCharDB
function Tabs.ApplyOnce(charDb)
	if (charDb.tabLayout or 0) < ns.TAB_LAYOUT_VERSION then
		Tabs.Apply(charDb)
	end
	Tabs.CombatLogLast()
	if not hookedLast then
		hookedLast = true
		-- A tab the player opens (Blizzard's tab menu) or a whisper tab is added at the end: Combat Log goes after it.
		hooksecurefunc("FCF_OpenNewWindow", Tabs.CombatLogLast)
		hooksecurefunc("FCF_OpenTemporaryWindow", Tabs.CombatLogLast)
		-- Blizzard laid the tabs out again (a re-dock from saved places, a renamed window): Journal last again.
		hooksecurefunc("FCFDock_UpdateTabs", Tabs.CombatLogLast)
	end
end

--- Sort new channels into the Channels tab while the "sortChannels" feature is on.
---@param feature OrdaenFeature
function Tabs.SortChannels(feature)
	feature:On("CHAT_MSG_CHANNEL_NOTICE", onChannelNotice)
end

--- What the dev-mode dump records: each chat window's name, groups and channels.
function Tabs.Describe()
	local windows = {}
	for i = 1, NUM_CHAT_WINDOWS do
		local name, _, _, _, _, _, shown, _, docked = GetChatWindowInfo(i)
		if name and name ~= "" and (shown or docked) then
			local frame = _G["ChatFrame" .. i]
			windows[#windows + 1] = {
				index = i,
				name = name,
				groups = frame and frame.messageTypeList,
				channels = frame and ns.ChannelNames(frame.channelList),
			}
		end
	end
	return windows
end
