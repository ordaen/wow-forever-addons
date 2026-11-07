-- Ordaen Tooltips, a spell's key numbers: cost, range, cast time and cooldown, read from the spell tooltip's own
-- lines (Blizzard's format strings, so every client language) for the section under the title (the user's request,
-- 2026-11-07; the idea is PrettyTooltip's). Pure: no WoW calls but Blizzard's strings, so specs read it as is.
--
-- No captions (the user's decision, 2026-11-07): the columns' order says what each is. Range and times keep the
-- number Blizzard wrote and drop the words around it ("30 yd range" shows as "30 yd"); the cost shows Blizzard's
-- whole line ("30 Mana": a bare number would say nothing). Values are a format and one argument (SetFormattedText),
-- so a show builds no strings.
-- Cost: a line's parse is cached per text (the player's spells: a bounded set; the cache is emptied past a cap).
local _, ns = ...

local SpellStats = {}
ns.SpellStats = SpellStats

local L = ns.L

--- The order of the section's columns.
SpellStats.ORDER = { "cost", "range", "cast", "cooldown" }

-- A Lua pattern for a line built from Blizzard's format string: its placeholder (%s, %d, %.3g, %1$s ...) captures
-- the number, the rest is matched literally.
local PLACEHOLDER = "\1"
local function patternOf(format)
	if type(format) ~= "string" or format == "" then
		return nil
	end
	local p = format:gsub("%%%d*%$?[%-%.%d]*[sdfg]", PLACEHOLDER)
	p = p:gsub("[%%%(%)%.%+%-%*%?%[%]%^%$]", "%%%0")
	return "^" .. p:gsub(PLACEHOLDER, "(.-)") .. "$"
end

local function global(name)
	return rawget(_G, name)
end

-- What each line can be: the stat it is, the pattern (or the exact text for the wordy ones), the value's format
-- (with the captured number, or the whole line when `whole`).
local RULES
local function rules()
	if RULES then
		return RULES
	end
	RULES = {}
	local function add(stat, format, valueFormat, exact, whole)
		local pattern = exact and format or patternOf(format)
		if pattern then
			RULES[#RULES + 1] = { stat = stat, pattern = pattern, exact = exact, format = valueFormat, whole = whole }
		end
	end
	for _, power in ipairs({ "MANA", "RAGE", "ENERGY", "FOCUS", "RUNIC_POWER" }) do
		add("cost", global(power .. "_COST"), "%s", false, true)
	end
	add("range", global("SPELL_RANGE"), L.STAT_YARDS)
	add("range", global("MELEE_RANGE"), global("MELEE") or "%s", true)
	add("cast", global("SPELL_CAST_TIME_SEC"), L.STAT_SECONDS)
	add("cast", global("SPELL_CAST_TIME_MIN"), L.STAT_MINUTES)
	for _, name in ipairs({ "SPELL_CAST_TIME_INSTANT", "SPELL_CAST_TIME_INSTANT_NO_MANA", "SPELL_CAST_CHANNELED",
		"SPELL_ON_NEXT_SWING" }) do
		local text = global(name)
		add("cast", text, text, true)
	end
	add("cooldown", global("SPELL_RECAST_TIME_SEC"), L.STAT_SECONDS)
	add("cooldown", global("SPELL_RECAST_TIME_MIN"), L.STAT_MINUTES)
	add("cooldown", global("SPELL_RECAST_TIME_HOURS"), L.STAT_HOURS)
	add("cooldown", global("SPELL_RECAST_TIME_DAYS"), L.STAT_DAYS)
	return RULES
end

local CACHE_CAP = 256
local parsed, cached = {}, 0 -- text -> { rule, number } or false
local NONE = false

--- What a tooltip line's text is: its rule (stat, format) and the value's argument (the number in it, or the whole
--- line); nil when it's no stat.
---@param text string
---@return table|nil, string|nil
function SpellStats.Parse(text)
	if type(text) ~= "string" or text == "" then
		return nil, nil
	end
	local entry = parsed[text]
	if entry == nil then
		entry = NONE
		for _, rule in ipairs(rules()) do
			if rule.exact then
				if text == rule.pattern then
					entry = { rule, "" }
					break
				end
			else
				local number = text:match(rule.pattern)
				if number and number ~= "" then
					entry = { rule, rule.whole and text or number }
					break
				end
			end
		end
		if cached >= CACHE_CAP then
			parsed, cached = {}, 0
		end
		parsed[text], cached = entry, cached + 1
	end
	if not entry then
		return nil, nil
	end
	return entry[1], entry[2]
end

SpellStats.PatternOf = patternOf
