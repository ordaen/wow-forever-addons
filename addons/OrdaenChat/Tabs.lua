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
			setGroups(frame, tab.groups)
			if tab.channels then
				for _, channel in ipairs(channels) do
					moveChannel(channel, frame)
				end
			end
		end
	end
	ns.Whispers.UseTabs()
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

--- Set up the default tabs if this character hasn't had this layout version yet (the "layout" feature).
---@param charDb table OrdaenChatCharDB
function Tabs.ApplyOnce(charDb)
	if (charDb.tabLayout or 0) < ns.TAB_LAYOUT_VERSION then
		Tabs.Apply(charDb)
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
