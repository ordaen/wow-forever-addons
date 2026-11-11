-- Made by lunatype from OrdaenTooltips/term.luna: change the source, not this file.
local R = LunaType
local __string_contains = R.string.contains
local __string_format = R.string.format
local __OrdaenTooltips_terms_glossary = R.addon("OrdaenTooltips")["terms"].glossary
local __OrdaenTooltips_colors_GOLD = R.addon("OrdaenTooltips")["colors"].GOLD
local M = {}
R.addon("OrdaenTooltips")["term"] = M
local with, term

function with(text, amount)
	local __t1
	if __string_contains(text, "%s") then
		__t1 = __string_format(text, amount)
	else
		__t1 = text
	end
	return __t1
end

function term(which, amount)
	local entry = __OrdaenTooltips_terms_glossary(which)
	local spoken = amount or ""
	return { kind = "term", name = with(entry.name, spoken), nameColor = __OrdaenTooltips_colors_GOLD, desc = {}, info = {}, facts = {}, body = { { left = with(entry.text, spoken), opens = "None" } }, more = {}, foot = {}, keys = {}, picture = "None" }
end

M.with = with
M.term = term
