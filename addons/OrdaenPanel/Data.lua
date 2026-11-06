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
---@field overlay number rested XP drawn up to here (= value without rest)
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
---@return OrdaenPanelBar out
function Data.Experience(out, level, maxLevel, xp, xpMax, rested, disabled)
	if disabled or level >= maxLevel or not xpMax or xpMax <= 0 then
		out.kind = nil
		return out
	end
	rested = rested or 0
	out.kind = "xp"
	out.value, out.max, out.level = xp, xpMax, level
	out.overlay = min(xp + rested, xpMax)
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
	out.overlay = out.value
	out.percent = floor(out.value / out.max * 100)
	out.restedPercent, out.level = 0, nil
	return out
end

--- Copper -> gold, silver, copper.
---@param copper integer GetMoney()
---@return integer gold, integer silver, integer copper
function Data.Money(copper)
	return floor(copper / 10000), floor(copper / 100) % 100, copper % 100
end
