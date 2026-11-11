-- Made by lunatype from OrdaenTooltips/aura.luna: change the source, not this file.
local R = LunaType
local __insert = table.insert
local __x = {
	game__Spells_known = R.game.Spells.known,
	game__Spells_name = R.game.Spells.name,
	OrdaenTooltips_text_duration = R.addon("OrdaenTooltips")["text"].duration,
	game__Strings_hours = R.game.Strings.hours,
	game__Strings_minutes = R.game.Strings.minutes,
	game__Strings_seconds = R.game.Strings.seconds,
	OrdaenTooltips_locales_CAMP_WELL_NAME = R.addon("OrdaenTooltips")["locales"].CAMP_WELL_NAME,
	OrdaenTooltips_locales_CAMP_WELL = R.addon("OrdaenTooltips")["locales"].CAMP_WELL,
	OrdaenTooltips_locales_CAMP_AQUA_NAME = R.addon("OrdaenTooltips")["locales"].CAMP_AQUA_NAME,
	OrdaenTooltips_locales_CAMP_AQUA = R.addon("OrdaenTooltips")["locales"].CAMP_AQUA,
	string_split = R.string.split,
	string_captures = R.string.captures,
	OrdaenTooltips_locales_TOTAL_PATTERN = R.addon("OrdaenTooltips")["locales"].TOTAL_PATTERN,
	string_toNumber = R.string.toNumber,
	math_floor = R.math.floor,
	math_max = R.math.max,
	string_contains = R.string.contains,
	OrdaenTooltips_locales_HEAL_WORD = R.addon("OrdaenTooltips")["locales"].HEAL_WORD,
	OrdaenTooltips_locales_TOTAL_HEAL = R.addon("OrdaenTooltips")["locales"].TOTAL_HEAL,
	OrdaenTooltips_locales_TOTAL_DAMAGE = R.addon("OrdaenTooltips")["locales"].TOTAL_DAMAGE,
	string_format = R.string.format,
	OrdaenTooltips_locales_TOTAL_VALUE = R.addon("OrdaenTooltips")["locales"].TOTAL_VALUE,
	game__Auras_shown = R.game.Auras.shown,
	OrdaenTooltips_text_clean = R.addon("OrdaenTooltips")["text"].clean,
	OrdaenTooltips_locales_REMAINING_WORD = R.addon("OrdaenTooltips")["locales"].REMAINING_WORD,
	string_unformat = R.string.unformat,
	game__Strings_timeRemainingMin = R.game.Strings.timeRemainingMin,
	game__Strings_timeRemainingSec = R.game.Strings.timeRemainingSec,
	OrdaenTooltips_locales_CAMP = R.addon("OrdaenTooltips")["locales"].CAMP,
	OrdaenTooltips_model_named = R.addon("OrdaenTooltips")["model"].named,
	OrdaenTooltips_locales_AURA_DEBUFF = R.addon("OrdaenTooltips")["locales"].AURA_DEBUFF,
	OrdaenTooltips_locales_AURA_BUFF = R.addon("OrdaenTooltips")["locales"].AURA_BUFF,
	OrdaenTooltips_locales_AURA_YOURS = R.addon("OrdaenTooltips")["locales"].AURA_YOURS,
	OrdaenTooltips_colors_GOLD = R.addon("OrdaenTooltips")["colors"].GOLD,
	game__Player_classTag = R.game.Player.classTag,
	OrdaenTooltips_locales_CANCEL_KEY = R.addon("OrdaenTooltips")["locales"].CANCEL_KEY,
	OrdaenTooltips_locales_CASTER = R.addon("OrdaenTooltips")["locales"].CASTER,
	OrdaenTooltips_locales_YOU = R.addon("OrdaenTooltips")["locales"].YOU,
	OrdaenTooltips_model_iconOf = R.addon("OrdaenTooltips")["model"].iconOf,
	game__Spells_texture = R.game.Spells.texture,
	OrdaenTooltips_colors_RED = R.addon("OrdaenTooltips")["colors"].RED,
}
local M = {}
R.addon("OrdaenTooltips")["aura"] = M
local BLANK, CAMP, REMOVE_COLOR, DISPEL, REMOVE, PURGE, remover, wait, campShort, campRows, total, aura
BLANK = 1
CAMP = 1229741
REMOVE_COLOR = { r = 0.561, g = 0.824, b = 1, a = 1 }
DISPEL = { ["Magic"] = { r = 0.235, g = 0.612, b = 1, a = 1 }, ["Curse"] = { r = 0.706, g = 0.361, b = 1, a = 1 }, ["Poison"] = { r = 0.184, g = 0.749, b = 0.247, a = 1 }, ["Disease"] = { r = 0.784, g = 0.565, b = 0.251, a = 1 } }
REMOVE = { ["MAGE"] = { ["Curse"] = { 475 } }, ["DRUID"] = { ["Curse"] = { 2782 }, ["Poison"] = { 2893, 8946 } }, ["PRIEST"] = { ["Magic"] = { 527, 988 }, ["Disease"] = { 552, 528 } }, ["PALADIN"] = { ["Magic"] = { 4987 }, ["Poison"] = { 4987, 1152 }, ["Disease"] = { 4987, 1152 } }, ["SHAMAN"] = { ["Poison"] = { 526 }, ["Disease"] = { 2870 } } }
PURGE = { ["SHAMAN"] = { 8012, 370 }, ["PRIEST"] = { 988, 527 } }

function remover(spells)
	if spells == nil then
		return nil
	end
	for __i1 = 1, #spells do
		local id = spells[__i1]
		if __x.game__Spells_known(id) then
			return __x.game__Spells_name(id)
		end
	end
	return nil
end

function wait(seconds)
	return __x.OrdaenTooltips_text_duration(seconds, __x.game__Strings_hours, __x.game__Strings_minutes, __x.game__Strings_seconds)
end

function campShort(name)
	if name == __x.OrdaenTooltips_locales_CAMP_WELL_NAME then
		return __x.OrdaenTooltips_locales_CAMP_WELL
	end
	if name == __x.OrdaenTooltips_locales_CAMP_AQUA_NAME then
		return __x.OrdaenTooltips_locales_CAMP_AQUA
	end
	return nil
end

function campRows(text, body)
	local first = true
	local __l3 = __x.string_split(text, "\n")
	for __i2 = 1, #__l3 do
		local line = __l3[__i2]
		repeat
			if line == "" then
				break
			end
			if first then
				first = false
				break
			end
			local name, effect = (line):match("^%s*([^:]+):%s*(.+)$")
			if name ~= nil and effect ~= nil then
				__insert(body, { left = name, right = campShort(name) or effect, opens = "None" })
			end
		until true
	end
end

function total(text, left, stacks)
	if left == nil then
		return nil, nil
	end
	local found = __x.string_captures(text, __x.OrdaenTooltips_locales_TOTAL_PATTERN)
	if found == nil then
		return nil, nil
	end
	local amount = __x.string_toNumber(found[1] or "")
	local period = __x.string_toNumber(found[2] or "")
	if amount == nil or period == nil or period <= 0 then
		return nil, nil
	end
	local sum = amount * __x.math_floor(left / period) * __x.math_max(stacks, 1)
	if sum <= 0 then
		return nil, nil
	end
	local __t4
	if __x.string_contains(text, __x.OrdaenTooltips_locales_HEAL_WORD) then
		__t4 = __x.OrdaenTooltips_locales_TOTAL_HEAL
	else
		__t4 = __x.OrdaenTooltips_locales_TOTAL_DAMAGE
	end
	local label = __t4
	return label, __x.string_format(__x.OrdaenTooltips_locales_TOTAL_VALUE, sum, wait(left))
end

function aura(data, options)
	local id = data.id
	local known = __x.game__Auras_shown(data)
	local name = nil
	local description = nil
	local desc = {}
	local info = {}
	local facts = {}
	local body = {}
	local foot = {}
	local __l5 = data.lines
	for i = 1, #__l5 do
		local line = __l5[i]
		repeat
			local left = __x.OrdaenTooltips_text_clean(line.left)
			if i == 1 then
				name = left
				break
			end
			if left == nil or line.kind == 1 then
				break
			end
			if (left):match("^ID ") ~= nil or __x.string_contains(left, __x.OrdaenTooltips_locales_REMAINING_WORD) or __x.string_unformat(left, __x.game__Strings_timeRemainingMin) ~= nil or __x.string_unformat(left, __x.game__Strings_timeRemainingSec) ~= nil then
				break
			end
			if id == 1229741 then
				campRows(left, body)
			else
				__insert(body, { left = left, desc = true, opens = "None" })
			end
			description = description or left
		until true
	end
	if name == nil then
		return nil
	end
	local harmful = known ~= nil and known.harmful
	if id == 1229741 then
		__insert(desc, { text = __x.OrdaenTooltips_locales_CAMP, opens = __x.OrdaenTooltips_model_named("camp") })
	else
		local __t6
		if harmful then
			__t6 = __x.OrdaenTooltips_locales_AURA_DEBUFF
		else
			__t6 = __x.OrdaenTooltips_locales_AURA_BUFF
		end
		__insert(desc, { text = __t6, opens = "None" })
	end
	local timer = false
	if known ~= nil then
		local dispel = known.dispel
		if dispel ~= nil then
			__insert(desc, { text = known.dispelName or dispel, color = DISPEL[dispel], opens = "None" })
		end
		if known.source == "player" or known.source == "pet" then
			__insert(desc, { text = __x.OrdaenTooltips_locales_AURA_YOURS, color = __x.OrdaenTooltips_colors_GOLD, opens = __x.OrdaenTooltips_model_named("mine") })
		end
		if known.stacks > 1 then
			__insert(facts, { text = "×" .. known.stacks, opens = __x.OrdaenTooltips_model_named("stacks") })
		end
		local left = known.left
		if left ~= nil then
			__insert(facts, { text = wait(__x.math_max(0.0, left)), glyph = "glyphs/time", opens = __x.OrdaenTooltips_model_named("time") })
			timer = true
		end
		local mine = __x.game__Player_classTag
		local by = nil
		if dispel ~= nil and harmful then
			local spells = REMOVE[mine]
			local __t7
			if spells ~= nil then
				__t7 = spells[dispel]
			else
				__t7 = nil
			end
			by = remover(__t7)
		elseif dispel == "Magic" and not harmful and known.hostile then
			by = remover(PURGE[mine])
		end
		if known.own and not harmful then
			__insert(facts, { text = __x.OrdaenTooltips_locales_CANCEL_KEY, opens = __x.OrdaenTooltips_model_named("cancel") })
		elseif by ~= nil then
			__insert(facts, { text = by, color = REMOVE_COLOR, opens = __x.OrdaenTooltips_model_named("removeby") })
		end
		local caster = known.sourceName
		if options.aurasCaster and caster ~= nil then
			local __t8
			if known.source == "player" then
				__t8 = __x.OrdaenTooltips_locales_YOU
			else
				__t8 = caster
			end
			local __t9
			if options.classNames then
				__t9 = known.sourceColor
			else
				__t9 = nil
			end
			__insert(foot, { left = __x.OrdaenTooltips_locales_CASTER, right = __t8, valueColor = __t9, opens = __x.OrdaenTooltips_model_named("caster") })
		end
		if options.aurasTotal and description ~= nil then
			local label, value = total(description, left, known.stacks)
			if label ~= nil then
				__insert(foot, { left = label, right = value, opens = __x.OrdaenTooltips_model_named("total") })
			end
		end
	end
	if id ~= nil and options.aurasId then
		__insert(info, { text = "ID " .. id, opens = "None" })
	end
	local __t10
	if id ~= nil then
		__t10 = __x.game__Spells_texture(id)
	else
		__t10 = nil
	end
	local __t11
	if harmful then
		__t11 = __x.OrdaenTooltips_colors_RED
	else
		__t11 = __x.OrdaenTooltips_colors_GOLD
	end
	return { kind = "aura", picture = __x.OrdaenTooltips_model_iconOf(__t10), name = name, nameColor = __t11, desc = desc, info = info, facts = facts, body = body, more = {}, foot = foot, keys = {}, timer = timer }
end

M.BLANK = BLANK
M.CAMP = CAMP
M.REMOVE_COLOR = REMOVE_COLOR
M.DISPEL = DISPEL
M.REMOVE = REMOVE
M.PURGE = PURGE
M.remover = remover
M.wait = wait
M.campShort = campShort
M.campRows = campRows
M.total = total
M.aura = aura
