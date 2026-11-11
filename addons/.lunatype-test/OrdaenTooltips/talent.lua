-- Made by lunatype from OrdaenTooltips/talent.luna: change the source, not this file.
local R = LunaType
local __insert = table.insert
local __string_split = R.string.split
local __game__Spells_name = R.game.Spells.name
local __OrdaenTooltips_spell_spell = R.addon("OrdaenTooltips")["spell"].spell
local __OrdaenTooltips_locales_TALENT = R.addon("OrdaenTooltips")["locales"].TALENT
local __OrdaenTooltips_model_named = R.addon("OrdaenTooltips")["model"].named
local __OrdaenTooltips_colors_GREEN = R.addon("OrdaenTooltips")["colors"].GREEN
local __OrdaenTooltips_talents_tab = R.addon("OrdaenTooltips")["talents"].tab
local __OrdaenTooltips_talents_name = R.addon("OrdaenTooltips")["talents"].name
local __game__Client_locale = R.game.Client.locale
local __OrdaenTooltips_locales_NEXT_RANK = R.addon("OrdaenTooltips")["locales"].NEXT_RANK
local __OrdaenTooltips_colors_GREY = R.addon("OrdaenTooltips")["colors"].GREY
local __OrdaenTooltips_locales_TALENT_POINTS = R.addon("OrdaenTooltips")["locales"].TALENT_POINTS
local __string_of = R.string.of
local __OrdaenTooltips_colors_RED = R.addon("OrdaenTooltips")["colors"].RED
local __OrdaenTooltips_locales_TALENT_LOCKED = R.addon("OrdaenTooltips")["locales"].TALENT_LOCKED
local __game__Spells_texture = R.game.Spells.texture
local M = {}
R.addon("OrdaenTooltips")["talent"] = M
local SPELL_NAME, LIT, plain, words, diff, talent
SPELL_NAME = 13
LIT = "|cff40ff60"

function plain(word)
	return ((((word):gsub("|c%x%x%x%x%x%x%x%x", ""))):gsub("|r", ""))
end

function words(text)
	local list = {}
	local __l2 = __string_split(((text):gsub("%s+", " ")), " ")
	for __i1 = 1, #__l2 do
		local word = __l2[__i1]
		if word ~= "" then
			__insert(list, word)
		end
	end
	return list
end

function diff(current, after)
	local before = words(current)
	local out = ""
	local __l3 = words(after)
	for i = 1, #__l3 do
		local word = __l3[i]
		local __t4
		if word == before[i] then
			__t4 = word
		else
			__t4 = "|cff40ff60" .. plain(word) .. "|r"
		end
		local shown = __t4
		local __t5
		if i == 1 then
			__t5 = shown
		else
			__t5 = out .. " " .. shown
		end
		out = __t5
	end
	return out
end

function talent(data, known, options)
	local name = __game__Spells_name(known.spell)
	if name == nil then
		return nil
	end
	local lines = { { left = name, kind = 13 } }
	local __l7 = data.lines
	for __i6 = 1, #__l7 do
		local line = __l7[__i6]
		__insert(lines, line)
	end
	local read = __OrdaenTooltips_spell_spell({ id = known.spell, lines = lines, kind = data.kind, plain = data.plain, about = data.about }, options)
	if read == nil then
		return nil
	end
	local maxed = known.rank >= known.ranks
	local __t8
	if maxed then
		__t8 = __OrdaenTooltips_colors_GREEN
	else
		__t8 = nil
	end
	local desc = { { text = __OrdaenTooltips_locales_TALENT, opens = __OrdaenTooltips_model_named("talent") }, { text = known.rank .. "/" .. known.ranks, color = __t8, opens = __OrdaenTooltips_model_named("talent") } }
	local tab = __OrdaenTooltips_talents_tab[known.spell]
	local __t9
	if tab ~= nil then
		__t9 = __OrdaenTooltips_talents_name[tab]
	else
		__t9 = nil
	end
	local tree = __t9
	if tree ~= nil then
		local __t10
		if __game__Client_locale == "ruRU" then
			__t10 = tree.ruRU
		else
			__t10 = tree.enUS
		end
		__insert(desc, { text = __t10, opens = "None" })
	end
	local more = {}
	local current = known.current
	local after = known.next
	if options.spellsNext and known.rank > 0 and not maxed and current ~= nil and after ~= nil and after ~= "" then
		__insert(more, { left = __OrdaenTooltips_locales_NEXT_RANK, color = __OrdaenTooltips_colors_GREY, opens = "None" })
		__insert(more, { left = diff(current, after), desc = true, opens = "None" })
	end
	local foot = {}
	local __l12 = read.foot
	for __i11 = 1, #__l12 do
		local note = __l12[__i11]
		__insert(foot, note)
	end
	if known.rank == 0 then
		local __l14 = known.conditions
		for __i13 = 1, #__l14 do
			local condition = __l14[__i13]
			if condition.points > 0 then
				local __t15
				if condition.met then
					__t15 = nil
				else
					__t15 = __OrdaenTooltips_colors_RED
				end
				__insert(foot, { left = __OrdaenTooltips_locales_TALENT_POINTS, right = __string_of(condition.points), valueColor = __t15, opens = __OrdaenTooltips_model_named("talent") })
			end
		end
		if known.locked then
			__insert(foot, { left = __OrdaenTooltips_locales_TALENT_LOCKED, valueColor = __OrdaenTooltips_colors_RED, opens = __OrdaenTooltips_model_named("talent") })
		end
	end
	local art = __game__Spells_texture(known.spell)
	if art == nil then
		return { desc = desc, more = more, foot = foot, kind = read.kind, header = read.header, picture = read.picture, name = read.name, nameColor = read.nameColor, info = read.info, facts = read.facts, body = read.body, keys = read.keys, timer = read.timer }
	end
	return { desc = desc, more = more, foot = foot, picture = { "Icon", art = art }, kind = read.kind, header = read.header, name = read.name, nameColor = read.nameColor, info = read.info, facts = read.facts, body = read.body, keys = read.keys, timer = read.timer }
end

M.SPELL_NAME = SPELL_NAME
M.LIT = LIT
M.plain = plain
M.words = words
M.diff = diff
M.talent = talent
