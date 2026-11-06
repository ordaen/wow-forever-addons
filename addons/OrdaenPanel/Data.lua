-- Ordaen Panel: what the segments show, from what the game's API returns. Pure logic (the WoW side calls the API
-- on its events and passes the results); every function fills a table it is given, so an update makes no garbage.
local _, ns = ...

local Data = {}
ns.Data = Data

local floor, min = math.floor, math.min

---@class OrdaenPanelBar
---@field kind "xp"|"reputation"|nil nil: nothing to show
---@field value number
---@field max number
---@field quest number XP from completed quests not yet turned in, drawn from value up to here (= value without)
---@field overlay number rested XP, dimmed, drawn from quest up to here (= quest without rest)
---@field percent integer
---@field restedPercent integer
---@field level integer
---@field name string|nil the faction
---@field standing string|nil the standing's token name ("friendly")

--- Experience: nil kind at the level cap or with XP turned off.
---@param out OrdaenPanelBar
---@param level integer UnitLevel("player")
---@param maxLevel integer GetMaxPlayerLevel()
---@param xp number UnitXP("player")
---@param xpMax number UnitXPMax("player")
---@param rested number|nil GetXPExhaustion()
---@param disabled boolean|nil IsXPUserDisabled()
---@param questXP number|nil XP of completed quests in the log (Data.QuestXP)
---@return OrdaenPanelBar out
function Data.Experience(out, level, maxLevel, xp, xpMax, rested, disabled, questXP)
	if disabled or level >= maxLevel or not xpMax or xpMax <= 0 then
		out.kind = nil
		return out
	end
	rested = rested or 0
	out.kind = "xp"
	out.value, out.max, out.level = xp, xpMax, level
	out.quest = min(xp + (questXP or 0), xpMax)
	out.overlay = min(out.quest + rested, xpMax)
	out.percent = floor(xp / xpMax * 100)
	out.restedPercent = floor(rested / xpMax * 100)
	out.name, out.standing = nil, nil
	return out
end

-- Blizzard's reaction 1..8 -> the theme token's standing name (color.reputation.<standing>).
local STANDINGS = { "hated", "hostile", "unfriendly", "neutral", "friendly", "honored", "revered", "exalted" }
Data.STANDINGS = STANDINGS

--- The watched reputation (C_Reputation.GetWatchedFactionData()), nil kind when none is watched.
---@param out OrdaenPanelBar
---@param data table|nil { name, reaction, currentReactionThreshold, nextReactionThreshold, currentStanding }
---@return OrdaenPanelBar out
function Data.Reputation(out, data)
	if not data or not data.name or data.name == "" then
		out.kind = nil
		return out
	end
	local low, high = data.currentReactionThreshold or 0, data.nextReactionThreshold or 0
	local span = high - low
	out.kind = "reputation"
	out.name = data.name
	out.standing = STANDINGS[data.reaction or 4] or "neutral"
	if span <= 0 then -- the top of the last standing: a full bar
		out.value, out.max = 1, 1
	else
		out.value, out.max = (data.currentStanding or low) - low, span
	end
	out.quest, out.overlay = out.value, out.value
	out.percent = floor(out.value / out.max * 100)
	out.restedPercent, out.level = 0, nil
	return out
end

--- XP of the quests in the log that are complete (ready to turn in).
---@param count integer C_QuestLog.GetNumQuestLogEntries()
---@param questAt fun(i: integer): (integer|nil) the quest ID of entry i, nil for headers (C_QuestLog.GetInfo)
---@param ready fun(questID: integer): boolean C_QuestLog.ReadyForTurnIn
---@param rewardXP fun(questID: integer): number GetQuestLogRewardXP
---@return number
function Data.QuestXP(count, questAt, ready, rewardXP)
	local total = 0
	for i = 1, count do
		local id = questAt(i)
		if id and ready(id) then
			total = total + (rewardXP(id) or 0)
		end
	end
	return total
end

---@class OrdaenPanelSession
---@field start number GetTime() when the session started (login or level up)
---@field gained number XP (or reputation) gained since then
---@field last number the size of the last gain (for "gains to level")

--- Record a gain (the difference between two readings; a level up counts what was left of the old level).
---@param session OrdaenPanelSession
---@param amount number
function Data.Gain(session, amount)
	if amount > 0 then
		session.gained = session.gained + amount
		session.last = amount
	end
end

--- Per hour, seconds to fill the rest, and gains like the last one to fill it; nil until there is a rate.
---@param session OrdaenPanelSession
---@param now number GetTime()
---@param remaining number XP (or reputation) to the next level (standing)
---@return number|nil perHour, number|nil seconds, integer|nil gains
function Data.Rate(session, now, remaining)
	local elapsed = now - session.start
	if session.gained <= 0 or elapsed < 60 then
		return nil
	end
	local perSecond = session.gained / elapsed
	local gains = session.last > 0 and math.ceil(remaining / session.last) or nil
	return perSecond * 3600, remaining / perSecond, gains
end

--- Copper -> gold, silver, copper.
---@param copper integer GetMoney()
---@return integer gold, integer silver, integer copper
function Data.Money(copper)
	return floor(copper / 10000), floor(copper / 100) % 100, copper % 100
end
