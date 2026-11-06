-- Ordaen Tooltips, layouts: what each kind of tooltip puts in its header and which of its lines move there. The
-- view draws the result; the rows stay the native tooltip's own lines, in their order.
--
--   items   the item's icon; its name in the quality colour (the accent); the item level as the subtitle
--   spells  the spell's icon
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
---@field extrasFrom integer|false the first row another addon added
local result = { icon = false, subtitle = false, skip = {}, extrasFrom = false }

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

local function spell(model)
	result.icon = C_Spell.GetSpellTexture(model.id) or false
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
	result.icon, result.subtitle = false, false
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
