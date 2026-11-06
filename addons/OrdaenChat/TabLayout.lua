-- Ordaen Chat's default tabs, as data (the user's choices, 2026-11-06): General (conversation, your progress, what
-- you must notice), Guild, Channels, and Journal last (Blizzard's Combat Log window, renamed: the combat log plus
-- everything else). Whispers open a tab per conversation (Whispers.lua) and aren't in General. Pure: no WoW calls,
-- so specs read it as is.
local _, ns = ...

--- Bump when the layout changes: each character gets the new one once at its next login.
--- 2: Combat Log combat only, and the last tab. 3: Journal (Combat Log renamed) takes the non-essential messages.
ns.TAB_LAYOUT_VERSION = 3

-- Message groups (ChatTypeGroup keys, all in api/forever/<CURRENT>) per tab. `window = 1` is the first chat window,
-- kept with its own name; `window = 2` is Blizzard's Combat Log window, renamed `name` (a locale key); the others
-- are found by title or opened. `channels = true`: the tab holds the channels. Crafting and openings are in both
-- General and Journal: a filter shows yours in General and other players' in Journal (Route.lua).
ns.TAB_LAYOUT = {
	{
		id = "general",
		window = 1,
		groups = {
			"SAY", "EMOTE", "YELL", "PARTY", "PARTY_LEADER", "RAID", "RAID_LEADER", "RAID_WARNING", "INSTANCE_CHAT",
			"INSTANCE_CHAT_LEADER", "BN_INLINE_TOAST_ALERT", "SYSTEM", "IGNORED", "MONSTER_SAY", "MONSTER_EMOTE",
			"MONSTER_YELL", "MONSTER_WHISPER", "MONSTER_BOSS_EMOTE", "MONSTER_BOSS_WHISPER", "ACHIEVEMENT",
			"BG_ALLIANCE", "BG_HORDE", "BG_NEUTRAL", "COMBAT_XP_GAIN", "COMBAT_HONOR_GAIN", "COMBAT_FACTION_CHANGE",
			"SKILL", "LOOT", "CURRENCY", "MONEY", "TRADESKILLS", "OPENING", "PING", "TARGETICONS", "VOICE_TEXT",
		},
	},
	{ id = "guild", title = "GUILD", groups = { "GUILD", "OFFICER", "GUILD_ACHIEVEMENT", "GUILD_DISCORD" } },
	{ id = "channels", title = "CHANNELS", groups = { "CHANNEL" }, channels = true },
	-- Journal: Blizzard's Combat Log window (its combat filters stay) plus the messages you rarely need. Kept the last
	-- tab (Tabs.lua).
	{
		id = "journal",
		window = 2,
		name = "JOURNAL",
		groups = {
			"ERRORS", "AFK", "DND", "COMBAT_MISC_INFO", "PET_INFO", "PET_BATTLE_INFO", "PET_BATTLE_COMBAT_LOG",
			"COLLECTED_APPEARANCE", "TRADESKILLS", "OPENING",
		},
	},
}

--- The channel names in `list` (a chat window's channelList: names, possibly with nil holes) as a new array.
---@param list table|nil
---@return string[]
function ns.ChannelNames(list)
	local names = {}
	if list then
		for _, name in pairs(list) do
			if type(name) == "string" then
				names[#names + 1] = name
			end
		end
		table.sort(names)
	end
	return names
end

--- Whether a CHAT_MSG_CHANNEL_NOTICE names a channel the player just joined (not a zone change or leaving).
---@param notice string the event's first argument
---@return boolean
function ns.IsJoinNotice(notice)
	return notice == "YOU_JOINED" or notice == "YOU_CHANGED"
end
