-- Made by lunatype from OrdaenTooltips/read.luna: change the source, not this file.
local R = LunaType
local __insert = table.insert
local __string_unformat = R.string.unformat
local __game__Strings_itemMinSkill = R.game.Strings.itemMinSkill
local __string_format = R.string.format
local __OrdaenTooltips_locales_KEY_OPEN = R.addon("OrdaenTooltips")["locales"].KEY_OPEN
local __OrdaenTooltips_colors_tint = R.addon("OrdaenTooltips")["colors"].tint
local __OrdaenTooltips_colors_WHITE = R.addon("OrdaenTooltips")["colors"].WHITE
local __OrdaenTooltips_colors_colorOf = R.addon("OrdaenTooltips")["colors"].colorOf
local __OrdaenTooltips_text_clean = R.addon("OrdaenTooltips")["text"].clean
local __OrdaenTooltips_colors_RED = R.addon("OrdaenTooltips")["colors"].RED
local __OrdaenTooltips_model_named = R.addon("OrdaenTooltips")["model"].named
local __game__Items_count = R.game.Items.count
local __OrdaenTooltips_locales_KEY_NEEDED = R.addon("OrdaenTooltips")["locales"].KEY_NEEDED
local __OrdaenTooltips_colors_GOLD = R.addon("OrdaenTooltips")["colors"].GOLD
local __OrdaenTooltips_quests_quests = R.addon("OrdaenTooltips")["quests"].quests
local __OrdaenTooltips_item_item = R.addon("OrdaenTooltips")["item"].item
local __game__Talents_shown = R.game.Talents.shown
local __OrdaenTooltips_talent_talent = R.addon("OrdaenTooltips")["talent"].talent
local __OrdaenTooltips_spell_spell = R.addon("OrdaenTooltips")["spell"].spell
local __OrdaenTooltips_aura_aura = R.addon("OrdaenTooltips")["aura"].aura
local __OrdaenTooltips_unit_unit = R.addon("OrdaenTooltips")["unit"].unit
local M = {}
R.addon("OrdaenTooltips")["read"] = M
local BLANK, REQUIREMENT, kindOf, skillOf, plain, object, fill, group
BLANK = 1
REQUIREMENT = 43

function kindOf(data)
	if data.plain == true then
		return "text"
	end
	local about = data.kind
	if about == nil then
		return nil
	end
	if about == 0 then
		return "item"
	elseif about == 1 then
		return "spell"
	elseif about == 2 then
		return "unit"
	elseif about == 4 then
		return "object"
	elseif about == 7 then
		return "aura"
	else
		return nil
	end
end

function skillOf(text)
	local parts = __string_unformat(text, __game__Strings_itemMinSkill)
	if parts == nil then
		return nil, nil
	end
	return parts[1], parts[2]
end

function plain(data)
	local first = data.lines[1]
	if first == nil then
		return nil
	end
	local title = first.left
	if title == nil then
		return nil
	end
	local keys = {}
	local name, key = (title):match("^(.-)%s*|c%x%x%x%x%x%x%x%x%(([^()]+)%)|r$")
	if name ~= nil and key ~= nil and name ~= "" then
		title = name
		__insert(keys, __string_format(__OrdaenTooltips_locales_KEY_OPEN, key))
	end
	local body = {}
	local __l1 = data.lines
	for i = 1, #__l1 do
		local line = __l1[i]
		repeat
			if i == 1 then
				break
			end
			local left = line.left
			local right = line.right
			if left ~= nil and right ~= nil then
				__insert(body, { left = left, right = right, color = __OrdaenTooltips_colors_tint(line.leftColor), rightColor = __OrdaenTooltips_colors_tint(line.rightColor), opens = "None" })
			else
				local only = left or right
				if only ~= nil then
					local color = __OrdaenTooltips_colors_tint(line.leftColor)
					local __t2
					if color == nil then
						__t2 = true
					else
						__t2 = nil
					end
					__insert(body, { left = only, color = color, desc = __t2, opens = "None" })
				end
			end
		until true
	end
	return { kind = "text", name = title, nameColor = __OrdaenTooltips_colors_colorOf(first.leftColor) or __OrdaenTooltips_colors_WHITE, desc = {}, info = {}, facts = {}, body = body, more = {}, foot = {}, keys = keys, picture = "None" }
end

function object(data, options)
	local name = nil
	local body = {}
	local foot = {}
	local __l3 = data.lines
	for i = 1, #__l3 do
		local line = __l3[i]
		repeat
			local text = __OrdaenTooltips_text_clean(line.left)
			if i == 1 then
				name = text
				break
			end
			if text == nil or line.kind == 1 or line.kind == 17 or line.kind == 8 or line.kind == 18 then
				break
			end
			if line.kind ~= 43 then
				__insert(body, { left = text, color = __OrdaenTooltips_colors_colorOf(line.leftColor), opens = "None" })
				break
			end
			local locked = line.usable == false
			local skill, rank = skillOf(text)
			if skill ~= nil and rank ~= nil then
				local __t4
				if locked then
					__t4 = __OrdaenTooltips_colors_RED
				else
					__t4 = nil
				end
				__insert(foot, { left = skill, right = rank, valueColor = __t4, opens = __OrdaenTooltips_model_named("lock") })
			else
				local key = (text):match("^[^:]+:%s*(.+)$") or ((text):gsub("^%S+%s+", ""))
				local missing = __game__Items_count(key) == 0
				local __t5
				if locked or missing then
					__t5 = __OrdaenTooltips_colors_RED
				else
					__t5 = nil
				end
				__insert(foot, { left = __OrdaenTooltips_locales_KEY_NEEDED, right = key, valueColor = __t5, opens = __OrdaenTooltips_model_named("lock") })
			end
		until true
	end
	if name == nil then
		return nil
	end
	return { kind = "object", name = name, nameColor = __OrdaenTooltips_colors_GOLD, desc = {}, info = {}, facts = {}, body = body, more = __OrdaenTooltips_quests_quests(data.lines, options.npcsParty), foot = foot, keys = {}, picture = "None" }
end

function fill(data, options)
	local kind = kindOf(data)
	if kind == nil then
		return nil
	end
	if kind == "item" then
		local read = __OrdaenTooltips_item_item(data, options)
		local __t6
		if read ~= nil then
			__t6 = read.model
		else
			__t6 = nil
		end
		return __t6
	end
	if kind == "spell" then
		local known = __game__Talents_shown(data)
		if known ~= nil then
			return __OrdaenTooltips_talent_talent(data, known, options)
		end
	end
	if kind == "text" then
		return plain(data)
	elseif kind == "object" then
		return object(data, options)
	elseif kind == "spell" then
		return __OrdaenTooltips_spell_spell(data, options)
	elseif kind == "aura" then
		return __OrdaenTooltips_aura_aura(data, options)
	elseif kind == "unit" then
		return __OrdaenTooltips_unit_unit(data, options)
	else
		return nil
	end
end

function group(data, options)
	if kindOf(data) ~= "item" then
		local model = fill(data, options)
		if model == nil then
			return nil
		end
		return { model = model, sides = {}, stats = {} }
	end
	local read = __OrdaenTooltips_item_item(data, options)
	if read == nil then
		return nil
	end
	local sides = {}
	local __l8 = read.sides
	for __i7 = 1, #__l8 do
		local side = __l8[__i7]
		__insert(sides, side)
	end
	local __l10 = read.makes
	for __i9 = 1, #__l10 do
		local made = __l10[__i9]
		local inner = __OrdaenTooltips_item_item(made, options)
		if inner ~= nil then
			__insert(sides, inner.model)
		end
	end
	return { model = read.model, sides = sides, stats = read.stats }
end

M.BLANK = BLANK
M.REQUIREMENT = REQUIREMENT
M.kindOf = kindOf
M.skillOf = skillOf
M.plain = plain
M.object = object
M.fill = fill
M.group = group
