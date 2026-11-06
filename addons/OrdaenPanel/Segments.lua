-- Ordaen Panel: what each segment shows, read from the game on its events. Each segment is a model table updated in
-- place (no garbage per event) plus the events that change it; Core.lua registers those only while the segment's
-- group is on (A:Feature) and calls ns.Changed(name) after an update, which the drawing code (Panel.lua) listens to.
local _, ns = ...

local Data = ns.Data

local Segments = {}
ns.Segments = Segments

-- Social: friends and guild members online ------------------------------------------------------------------------

---@class OrdaenPanelSocial
local social = { friends = 0, bnet = 0, guild = 0, guildTotal = 0, inGuild = false }
Segments.social = {
	model = social,
	events = {
		"FRIENDLIST_UPDATE", "BN_FRIEND_INFO_CHANGED", "BN_FRIEND_ACCOUNT_ONLINE", "BN_FRIEND_ACCOUNT_OFFLINE",
		"GUILD_ROSTER_UPDATE", "PLAYER_GUILD_UPDATE",
	},
	update = function()
		social.friends = C_FriendList.GetNumOnlineFriends() or 0
		local _, bnetOnline = BNGetNumFriends()
		social.bnet = bnetOnline or 0
		social.inGuild = IsInGuild() and true or false
		if social.inGuild then
			local total, online = GetNumGuildMembers()
			social.guild, social.guildTotal = online or 0, total or 0
		else
			social.guild, social.guildTotal = 0, 0
		end
	end,
	-- The server sends the guild roster only when asked (and throttles asking): ask once when the group starts.
	start = function()
		if IsInGuild() then
			C_GuildInfo.GuildRoster()
		end
	end,
}

-- Experience, or the watched reputation at the level cap ---------------------------------------------------------

---@type OrdaenPanelBar
local bar = { value = 0, max = 1, quest = 0, overlay = 0, percent = 0, restedPercent = 0, level = 0 }
---@type OrdaenPanelSession
local session = { start = 0, gained = 0, last = 0 }
local last = { kind = nil, value = 0, max = 0, level = 0, name = nil } -- the previous reading, for gains
local questXP = 0
local questPending = false

-- made once: no closures per count
local function questAt(i)
	local info = C_QuestLog.GetInfo(i)
	return info and not info.isHeader and info.questID or nil
end
local function readyForTurnIn(id)
	return C_QuestLog.ReadyForTurnIn(id) and true or false
end

local function countQuestXP()
	questPending = false
	questXP = Data.QuestXP(C_QuestLog.GetNumQuestLogEntries(), questAt, readyForTurnIn, GetQuestLogRewardXP)
end

-- A gain since the last reading: within one level/standing the difference; across a level up, what was left of the
-- old level plus the new value. A new kind or faction starts a new session.
local function track()
	local now = GetTime()
	if bar.kind ~= last.kind or bar.name ~= last.name or session.start == 0 then
		session.start, session.gained, session.last = now, 0, 0
	elseif bar.kind == "xp" and bar.level ~= last.level then
		Data.Gain(session, (last.max - last.value) + bar.value)
	else
		Data.Gain(session, bar.value - last.value)
	end
	last.kind, last.value, last.max, last.level, last.name = bar.kind, bar.value, bar.max, bar.level, bar.name
end

Segments.experience = {
	model = bar,
	session = session,
	events = {
		"PLAYER_XP_UPDATE", "UPDATE_EXHAUSTION", "PLAYER_LEVEL_UP", "UPDATE_FACTION", "QUEST_LOG_UPDATE",
		"PLAYER_ENTERING_WORLD",
	},
	update = function(event)
		if event == "QUEST_LOG_UPDATE" then
			-- the quest log updates in bursts: count once, half a second after the first
			if not questPending then
				questPending = true
				C_Timer.After(0.5, Segments.questCounted)
			end
			return false -- nothing changed yet
		end
		Data.Experience(bar, UnitLevel("player"), GetMaxPlayerLevel(), UnitXP("player"), UnitXPMax("player"),
			GetXPExhaustion(), IsXPUserDisabled(), questXP)
		if not bar.kind then
			Data.Reputation(bar, C_Reputation.GetWatchedFactionData())
		end
		track()
	end,
	start = function()
		countQuestXP()
	end,
}

-- The quest log settled (half a second after a burst of QUEST_LOG_UPDATE): count, update, draw. Made once.
function Segments.questCounted()
	countQuestXP()
	Segments.experience.update()
	ns.Changed("experience")
end

-- Gold and the currencies shown on the backpack (the game's Currency tab decides which) -------------------------

---@class OrdaenPanelCurrency
---@field name string
---@field quantity number
---@field icon number|string

local currencies = { gold = 0, silver = 0, copper = 0, list = {}, count = 0 }
Segments.currencies = {
	model = currencies,
	events = { "PLAYER_MONEY", "CURRENCY_DISPLAY_UPDATE" },
	update = function()
		currencies.gold, currencies.silver, currencies.copper = Data.Money(GetMoney())
		local n = 0
		while true do
			local info = C_CurrencyInfo.GetBackpackCurrencyInfo(n + 1)
			if not info or not info.name then
				break
			end
			n = n + 1
			local entry = currencies.list[n] or {}
			currencies.list[n] = entry
			entry.name, entry.quantity, entry.icon = info.name, info.quantity, info.iconFileID
		end
		currencies.count = n
	end,
}

-- Bags: free slots in the backpack, the bags and the reagent bag ------------------------------------------------

local bags = { free = 0, reagentFree = 0 }
Segments.bags = {
	model = bags,
	events = { "BAG_UPDATE_DELAYED" },
	update = function()
		local free = 0
		for bag = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
			free = free + (C_Container.GetContainerNumFreeSlots(bag) or 0)
		end
		bags.free = free
		local reagent = 0
		for i = 1, NUM_REAGENTBAG_SLOTS or 0 do
			reagent = reagent + (C_Container.GetContainerNumFreeSlots(NUM_BAG_SLOTS + i) or 0)
		end
		bags.reagentFree = reagent
	end,
}

-- Micro menu: Blizzard's own buttons, in Blizzard's order ---------------------------------------------------------

local Micro = {}
ns.Micro = Micro

--- The micro buttons to show, in the order Blizzard laid them out: visible frames named "...MicroButton" (a button
--- this client doesn't use is shown on a hidden parent: the Housing and Achievements buttons on Forever), sorted
--- by position (left to right, or top to bottom when they stand in a column), minus the ones the player hid.
---@param children table[] MicroMenu's children (frames with GetName, IsShown, GetLeft, GetTop)
---@param hidden table<string, boolean> db.hiddenMicro
---@param out table[] filled and cut to length (reused)
---@return table[] out
function Micro.Order(children, hidden, out)
	local n = 0
	for _, child in ipairs(children) do
		local name = child.GetName and child:GetName()
		if name and name:find("MicroButton$") and child:IsVisible() and not hidden[name] then
			n = n + 1
			out[n] = child
		end
	end
	for i = #out, n + 1, -1 do
		out[i] = nil
	end
	table.sort(out, Micro.Before)
	return out
end

--- Blizzard's order: left to right, then top to bottom.
function Micro.Before(a, b)
	local ax, bx = a:GetLeft() or 0, b:GetLeft() or 0
	if ax ~= bx then
		return ax < bx
	end
	return (a:GetTop() or 0) > (b:GetTop() or 0)
end
