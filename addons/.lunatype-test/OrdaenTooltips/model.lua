-- Made by lunatype from OrdaenTooltips/model.luna: change the source, not this file.
local R = LunaType
local M = {}
R.addon("OrdaenTooltips")["model"] = M
local named, namedWith, side, iconOf

function named(term)
	return { "Term", term = term, amount = nil }
end

function namedWith(term, amount)
	return { "Term", term = term, amount = amount }
end

function side(faction)
	if faction == "Alliance" then
		return named("alliance")
	end
	if faction == "Horde" then
		return named("horde")
	end
	return "None"
end

function iconOf(art)
	if art == nil then
		return "None"
	end
	return { "Icon", art = art }
end

M.named = named
M.namedWith = namedWith
M.side = side
M.iconOf = iconOf
