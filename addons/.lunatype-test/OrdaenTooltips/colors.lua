-- Made by lunatype from OrdaenTooltips/colors.luna: change the source, not this file.
local R = LunaType
local __string_format = R.string.format
local __math_round = R.math.round
local __math_abs = R.math.abs
local M = {}
R.addon("OrdaenTooltips")["colors"] = M
local RED, GOLD, YELLOW, WHITE, GREEN, GREY, LABEL, hex, near, colorOf, tint
RED = { r = 1, g = 0.251, b = 0.251, a = 1 }
GOLD = { r = 1, g = 0.820, b = 0, a = 1 }
YELLOW = { r = 1, g = 0.820, b = 0, a = 1 }
WHITE = { r = 1, g = 1, b = 1, a = 1 }
GREEN = { r = 0.118, g = 1, b = 0, a = 1 }
GREY = { r = 0.502, g = 0.502, b = 0.502, a = 1 }
LABEL = { r = 0.796, g = 0.725, b = 0.580, a = 1 }

function hex(color)
	return __string_format("ff%02x%02x%02x", __math_round(color.r * 255), __math_round(color.g * 255), __math_round(color.b * 255))
end

function near(a, b)
	return __math_abs(a - b) < 0.002
end

function colorOf(color)
	if color == nil then
		return nil
	end
	if color.r > 0.95 and color.g > 0.95 and color.b > 0.95 then
		return nil
	end
	return color
end

function tint(color)
	local own = colorOf(color)
	if own == nil then
		return nil
	end
	if near(own.r, GOLD.r) and near(own.g, GOLD.g) and near(own.b, GOLD.b) then
		return nil
	end
	return own
end

M.RED = RED
M.GOLD = GOLD
M.YELLOW = YELLOW
M.WHITE = WHITE
M.GREEN = GREEN
M.GREY = GREY
M.LABEL = LABEL
M.hex = hex
M.near = near
M.colorOf = colorOf
M.tint = tint
