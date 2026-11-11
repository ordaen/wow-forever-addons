-- Made by lunatype from OrdaenTooltips/spell.luna: change the source, not this file.
local R = LunaType
local __insert = table.insert
local __x = {
	game__Client_locale = R.game.Client.locale,
	OrdaenTooltips_text_form = R.addon("OrdaenTooltips")["text"].form,
	string_format = R.string.format,
	OrdaenTooltips_locales_COMBO_ONE = R.addon("OrdaenTooltips")["locales"].COMBO_ONE,
	OrdaenTooltips_locales_COMBO_FEW = R.addon("OrdaenTooltips")["locales"].COMBO_FEW,
	OrdaenTooltips_locales_COMBO_MANY = R.addon("OrdaenTooltips")["locales"].COMBO_MANY,
	string_unformat = R.string.unformat,
	game__Strings_spellReagents = R.game.Strings.spellReagents,
	string_split = R.string.split,
	math_floor = R.math.floor,
	string_toNumber = R.string.toNumber,
	game__Items_count = R.game.Items.count,
	OrdaenTooltips_locales_COUNT = R.addon("OrdaenTooltips")["locales"].COUNT,
	OrdaenTooltips_colors_RED = R.addon("OrdaenTooltips")["colors"].RED,
	OrdaenTooltips_model_named = R.addon("OrdaenTooltips")["model"].named,
	game__Strings_castInstant = R.game.Strings.castInstant,
	game__Strings_castInstantNoMana = R.game.Strings.castInstantNoMana,
	OrdaenTooltips_locales_CAST_INSTANT = R.addon("OrdaenTooltips")["locales"].CAST_INSTANT,
	string_contains = R.string.contains,
	game__Strings_castChanneled = R.game.Strings.castChanneled,
	game__Strings_castTimeSec = R.game.Strings.castTimeSec,
	game__Strings_castTimeMin = R.game.Strings.castTimeMin,
	game__Strings_onNextSwing = R.game.Strings.onNextSwing,
	game__Strings_onNextRanged = R.game.Strings.onNextRanged,
	OrdaenTooltips_locales_CAST_NEXT = R.addon("OrdaenTooltips")["locales"].CAST_NEXT,
	game__Strings_meleeRange = R.game.Strings.meleeRange,
	OrdaenTooltips_locales_MELEE_RANGE_TEXT = R.addon("OrdaenTooltips")["locales"].MELEE_RANGE_TEXT,
	OrdaenTooltips_locales_MELEE_RANGE_SHORT = R.addon("OrdaenTooltips")["locales"].MELEE_RANGE_SHORT,
	game__Spells_cost = R.game.Spells.cost,
	OrdaenTooltips_text_clean = R.addon("OrdaenTooltips")["text"].clean,
	game__Spells_tab = R.game.Spells.tab,
	OrdaenTooltips_text_labelled = R.addon("OrdaenTooltips")["text"].labelled,
	OrdaenTooltips_colors_colorOf = R.addon("OrdaenTooltips")["colors"].colorOf,
	game__Spells_cooldown = R.game.Spells.cooldown,
	OrdaenTooltips_text_duration = R.addon("OrdaenTooltips")["text"].duration,
	game__Strings_hours = R.game.Strings.hours,
	game__Strings_minutes = R.game.Strings.minutes,
	game__Strings_seconds = R.game.Strings.seconds,
	OrdaenTooltips_locales_READY_IN = R.addon("OrdaenTooltips")["locales"].READY_IN,
	OrdaenTooltips_colors_YELLOW = R.addon("OrdaenTooltips")["colors"].YELLOW,
	OrdaenTooltips_model_iconOf = R.addon("OrdaenTooltips")["model"].iconOf,
	game__Spells_texture = R.game.Spells.texture,
	OrdaenTooltips_colors_WHITE = R.addon("OrdaenTooltips")["colors"].WHITE,
}
local M = {}
R.addon("OrdaenTooltips")["spell"] = M
local BLANK, SPELL_NAME, PASSIVE, DESCRIPTION, REQUIREMENT, valueOf, combo, reagents, comboValue, describe, cell, spell
BLANK = 1
SPELL_NAME = 13
PASSIVE = 33
DESCRIPTION = 34
REQUIREMENT = 43

function valueOf(text)
	return (text):match("^[^:]+:%s*(.+)$") or text
end

function combo(points)
	local __t1
	if __x.game__Client_locale == "ruRU" then
		__t1 = __x.OrdaenTooltips_text_form(points)
	else
		local __t2
		if points == 1 then
			__t2 = 1
		else
			__t2 = 3
		end
		__t1 = __t2
	end
	local which = __t1
	if which == 1 then
		return __x.string_format(__x.OrdaenTooltips_locales_COMBO_ONE, points)
	elseif which == 2 then
		return __x.string_format(__x.OrdaenTooltips_locales_COMBO_FEW, points)
	else
		return __x.string_format(__x.OrdaenTooltips_locales_COMBO_MANY, points)
	end
end

function reagents(text, foot)
	local parts = __x.string_unformat(text, __x.game__Strings_spellReagents)
	if parts == nil then
		return false
	end
	local list = parts[1]
	if list == nil then
		return false
	end
	local __l4 = __x.string_split(list, ",")
	for __i3 = 1, #__l4 do
		local part = __l4[__i3]
		local counted, count = (part):match("^%s*(.-)%s*%((%d+)%)%s*$")
		local name = counted or (part):match("^%s*(.-)%s*$") or ""
		local need = __x.math_floor(__x.string_toNumber(count or "") or 1)
		if name ~= "" then
			local have = __x.game__Items_count(name)
			local __t5
			if have < need then
				__t5 = __x.OrdaenTooltips_colors_RED
			else
				__t5 = nil
			end
			__insert(foot, { left = name, right = __x.string_format(__x.OrdaenTooltips_locales_COUNT, need), valueColor = __t5, opens = "None" })
		end
	end
	return true
end

function comboValue(effect)
	local low, high = (effect):match("(%d+)%s*%-%s*(%d+)")
	if low ~= nil and high ~= nil then
		return low .. "–" .. high
	end
	local from, to = (effect):match("(%d+)%s*–%s*(%d+)")
	if from ~= nil and to ~= nil then
		return from .. "–" .. to
	end
	return (effect):match("%d+")
end

function describe(text, body)
	if (text):match("^%s*%d%s") == nil and (text):match("\n%s*%d%s") == nil then
		__insert(body, { left = text, desc = true, opens = "None" })
		return
	end
	local rows = {}
	local first = nil
	local rest = nil
	local __l7 = __x.string_split(text, "\n")
	for __i6 = 1, #__l7 do
		local line = __l7[__i6]
		repeat
			if line == "" then
				break
			end
			local points, effect = (line):match("^%s*(%d)%s+[^%d:]-:%s*(.+)$")
			local __t8
			if effect ~= nil then
				__t8 = comboValue(effect)
			else
				__t8 = nil
			end
			local value = __t8
			if points ~= nil and value ~= nil then
				__insert(rows, { left = combo(__x.math_floor(__x.string_toNumber(points) or 0)), right = value, opens = __x.OrdaenTooltips_model_named("combo") })
			elseif first == nil then
				first = line
			else
				rest = (rest or first) .. "\n" .. line
			end
		until true
	end
	if first ~= nil then
		__insert(body, { left = rest or first, desc = true, opens = "None" })
	end
	for __i9 = 1, #rows do
		local row = rows[__i9]
		__insert(body, row)
	end
end

function cell(text, first, right, cost, cast, facts)
	local glyph = nil
	local tint = nil
	local shown = text
	local isCast = false
	local opens = "None"
	local digits = (text):match("%d[%d%s\194\160]*")
	if text == __x.game__Strings_castInstant or text == __x.game__Strings_castInstantNoMana then
		shown = __x.OrdaenTooltips_locales_CAST_INSTANT
		glyph = "glyphs/castNow"
		opens = __x.OrdaenTooltips_model_named("castnow")
		isCast = true
	elseif __x.string_contains(text, __x.game__Strings_castChanneled) then
		glyph = "glyphs/castChan"
		opens = __x.OrdaenTooltips_model_named("castchan")
		isCast = true
	elseif __x.string_unformat(text, __x.game__Strings_castTimeSec) ~= nil or __x.string_unformat(text, __x.game__Strings_castTimeMin) ~= nil then
		glyph = "glyphs/castTime"
		opens = __x.OrdaenTooltips_model_named("casttime")
		isCast = true
	elseif text == __x.game__Strings_onNextSwing or text == __x.game__Strings_onNextRanged then
		shown = __x.OrdaenTooltips_locales_CAST_NEXT
		glyph = "glyphs/castNext"
		opens = __x.OrdaenTooltips_model_named("castnext")
		isCast = true
	elseif not right and first and cost ~= nil and digits ~= nil and __x.string_toNumber(((digits):gsub("%D", ""))) == cost.amount then
		glyph = "glyphs/cost"
		tint = cost.color
		shown = ((digits):gsub("%s+$", ""))
	elseif right and cast then
		if digits ~= nil then
			shown = "CD " .. valueOf(text)
			opens = __x.OrdaenTooltips_model_named("cd")
		end
	elseif first then
		if text == __x.game__Strings_meleeRange or text == __x.OrdaenTooltips_locales_MELEE_RANGE_TEXT then
			shown = __x.OrdaenTooltips_locales_MELEE_RANGE_SHORT
			opens = __x.OrdaenTooltips_model_named("melee")
		else
			shown = ((valueOf(text)):gsub("%.$", ""))
			opens = __x.OrdaenTooltips_model_named("range")
		end
	end
	__insert(facts, { text = shown, glyph = glyph, tint = tint, opens = opens })
	return isCast
end

function spell(data, options)
	local id = data.id
	local __t10
	if id ~= nil then
		__t10 = __x.game__Spells_cost(id)
	else
		__t10 = nil
	end
	local cost = __t10
	local name = nil
	local desc = {}
	local info = {}
	local facts = {}
	local body = {}
	local foot = {}
	local band = 0
	local __l11 = data.lines
	for i = 1, #__l11 do
		local line = __l11[i]
		local left = __x.OrdaenTooltips_text_clean(line.left)
		local right = __x.OrdaenTooltips_text_clean(line.right)
		if line.kind == 13 and name == nil then
			name = left
			if right ~= nil then
				__insert(desc, { text = right, opens = "None" })
			end
			local __t12
			if id ~= nil then
				__t12 = __x.game__Spells_tab(id)
			else
				__t12 = nil
			end
			local tab = __t12
			if tab ~= nil then
				__insert(desc, { text = tab, opens = "None" })
			end
		elseif line.kind == 43 then
			if left ~= nil then
				local label, value = __x.OrdaenTooltips_text_labelled(left)
				local __t13
				if line.usable == false then
					__t13 = __x.OrdaenTooltips_colors_RED
				else
					__t13 = nil
				end
				__insert(foot, { left = label, right = value, valueColor = __t13, opens = "None" })
			end
		elseif line.kind == 34 then
			if left ~= nil then
				describe(left, body)
			end
		elseif line.kind == 33 then
			if left ~= nil then
				__insert(desc, { text = left, opens = "None" })
			end
		elseif line.kind ~= 1 and left ~= nil then
			if right ~= nil then
				band = band + 1
				local cast = cell(left, band == 1, false, cost, false, facts)
				cell(right, band == 1, true, cost, cast, facts)
			elseif not reagents(left, foot) then
				if i <= 4 and #body == 0 then
					band = band + 1
					cell(left, band == 1, false, cost, false, facts)
				else
					__insert(body, { left = left, color = __x.OrdaenTooltips_colors_colorOf(line.leftColor), opens = "None" })
				end
			end
		end
	end
	local timer = false
	if id ~= nil and options.spellsCooldown then
		local left = __x.game__Spells_cooldown(id)
		if left ~= nil then
			local wait = __x.OrdaenTooltips_text_duration(left, __x.game__Strings_hours, __x.game__Strings_minutes, __x.game__Strings_seconds)
			__insert(foot, { left = __x.OrdaenTooltips_locales_READY_IN, right = wait, valueColor = __x.OrdaenTooltips_colors_YELLOW, opens = __x.OrdaenTooltips_model_named("ready") })
			timer = true
		end
	end
	if id ~= nil and options.spellsId then
		__insert(info, { text = "ID " .. id, opens = "None" })
	end
	if name == nil then
		return nil
	end
	local __t14
	if id ~= nil then
		__t14 = __x.game__Spells_texture(id)
	else
		__t14 = nil
	end
	return { kind = "spell", picture = __x.OrdaenTooltips_model_iconOf(__t14), name = name, nameColor = __x.OrdaenTooltips_colors_WHITE, desc = desc, info = info, facts = facts, body = body, more = {}, foot = foot, keys = {}, timer = timer }
end

M.BLANK = BLANK
M.SPELL_NAME = SPELL_NAME
M.PASSIVE = PASSIVE
M.DESCRIPTION = DESCRIPTION
M.REQUIREMENT = REQUIREMENT
M.valueOf = valueOf
M.combo = combo
M.reagents = reagents
M.comboValue = comboValue
M.describe = describe
M.cell = cell
M.spell = spell
