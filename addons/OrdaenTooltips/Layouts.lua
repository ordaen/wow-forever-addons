-- Ordaen Tooltips, layouts: what each kind of tooltip puts in its header and which of its lines move there. The
-- view draws the result; the rows stay the native tooltip's own lines, in their order.
--
--   items   the item's icon; its name in the quality colour (the accent); the item level as the subtitle
--   spells  the spell's icon; cost, range, cast time and cooldown in a section under the title (SpellStats.lua),
--           out of the rows
--   units   the name in its reaction or class colour; the level/race/class line as the subtitle
--   other   the first line as the title
-- For every kind, the lines other addons added (after the game's own, per the tooltip data) start after a divider.
--
-- Cost: one result table, reused; the subtitle is one of the tooltip's own strings, so nothing is built per show.
local _, ns = ...

local Layouts = {}
ns.Layouts = Layouts

---@class OrdaenTooltipsLayout
---@field icon number|string|false the header's icon
---@field subtitle string|false
---@field skip table<integer, boolean> rows shown in the header instead
---@field tint boolean the title's colour also tints the tooltip's border (an item's quality); else only the title
--- wears it (a unit's reaction)
---@field extrasFrom integer|false the first row another addon added
---@field stats table<string, OrdaenTooltipsStat> a spell's section under the title, by stat (SpellStats.ORDER)
local result = { icon = false, subtitle = false, skip = {}, extrasFrom = false, stats = {}, tint = false }

---@class OrdaenTooltipsStat
---@field shown boolean
---@field format string the value's format ("%s yd")
---@field arg string the number in it (or the whole line)
for _, stat in ipairs(ns.SpellStats.ORDER) do
	result.stats[stat] = { shown = false, format = "%s", arg = "" }
end

-- A spell's stats sit in its first lines, both sides ("30 Mana" | "30 yd range", "1.5 sec cast" | "6 sec cooldown").
local STAT_ROWS = 5

-- "Item Level %d" -> "^Item Level (%d+)$", once per client language.
local function patternOf(format)
	if type(format) ~= "string" then
		return nil
	end
	local escaped = format:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
	local pattern = escaped:gsub("%%d", "(%%d+)"):gsub("%%s", "(.+)")
	return "^" .. pattern .. "$"
end

local ITEM_LEVEL_PATTERN = patternOf(rawget(_G, "ITEM_LEVEL"))

local function types()
	return Enum and Enum.TooltipDataType
end

local function item(model)
	local id = model.id
	result.tint = true -- its quality on the border too, as Blizzard's item tooltips
	result.icon = C_Item.GetItemIconByID(id) or false
	if not ITEM_LEVEL_PATTERN then
		return
	end
	-- The item level line is one of the first few, right after the name (and a heroic/upgrade line).
	for i = 2, math.min(4, model.count) do
		local row = model.rows[i]
		if row.right == "" and row.left:find(ITEM_LEVEL_PATTERN) then
			result.subtitle = row.left
			result.skip[i] = true
			return
		end
	end
end

local function stat(text)
	local rule, number = ns.SpellStats.Parse(text)
	if not rule then
		return false
	end
	local s = result.stats[rule.stat]
	if not s.shown then -- the first line naming a stat wins
		s.shown, s.format, s.arg = true, rule.format, number
	end
	return true
end

local function spell(model)
	result.icon = C_Spell.GetSpellTexture(model.id) or false
	for i = 2, math.min(STAT_ROWS, model.count) do
		local row = model.rows[i]
		local left = row.left ~= "" and stat(row.left)
		local right = row.right ~= "" and stat(row.right)
		-- The row moves to the section only when everything in it is a stat.
		if (left or right) and (row.left == "" or left) and (row.right == "" or right) then
			result.skip[i] = true
		end
	end
end

local function unit(model)
	local second = model.count >= 2 and model.rows[2]
	if second and second.right == "" and second.left ~= "" then
		result.subtitle = second.left
		result.skip[2] = true
	end
end

--- Decide the header and the moved rows for `model`. Returns the shared result table (valid until the next call).
---@param model OrdaenTooltipsModel
---@return OrdaenTooltipsLayout
function Layouts.Decide(model)
	local skip = result.skip
	for k in pairs(skip) do
		skip[k] = nil
	end
	result.icon, result.subtitle, result.tint = false, false, false
	for _, s in pairs(result.stats) do
		s.shown = false
	end
	local T = types()
	local kind = model.kind
	if T and kind and model.id then
		if kind == T.Item then
			item(model)
		elseif kind == T.Spell then
			spell(model)
		end
	end
	if T and kind == T.Unit then
		unit(model)
	end
	result.extrasFrom = model.gameLines > 0 and model.gameLines < model.count and model.gameLines + 1 or false
	return result
end

Layouts.PatternOf = patternOf
