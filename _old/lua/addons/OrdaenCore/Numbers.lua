-- Numbers as Ordaen shows them (design: settings/index.md, «Numbers» in the implementation gotchas; the design
-- site's theme/numbers.js is the same formatter): one formatter for every module, so the global settings decide how
-- all numbers look. `game.Numbers:Format(n)`:
--   separators (numberFormat): "space" 1 000 000.09 (a no-break space, so a number never wraps), "comma"
--     1,000,000.09, "dot" 1.000.000,09;
--   at most numberPrecision decimals, trailing zeros dropped (1795 -> "1 795", 2.5 -> "2.5");
--   numberRound: whole numbers from 1 up;
--   under 1 (not 0): at least 2 significant digits, rounding or not (0.25 -> "0.25", 0.004 -> "0.004");
--   a negative number keeps its sign unless it rounds to 0.
-- The settings are read tracked: a render that formats a number re-runs when they change.
local _, ns = ...

local Globals = ns.Globals
local format, floor, abs, log10, max = string.format, math.floor, math.abs, math.log10, math.max
local gsub, find, sub = string.gsub, string.find, string.sub
local tostring = tostring

---@class OrdaenNumbers
local Numbers = {}
ns.Numbers = Numbers

local NBSP = "\194\160"
local SEPARATORS = { space = { NBSP, "." }, comma = { ",", "." }, dot = { ".", "," } }

-- how many decimals a value gets
local function decimalsFor(value, precision, round)
	if value > 0 and value < 1 then
		return max(precision, 1 - floor(log10(value)))
	end
	return round and 0 or precision
end

-- "1234567" with `group` every three digits from the right
local function grouped(int, group)
	local n = #int
	if n <= 3 then
		return int
	end
	local first = n % 3
	local out = first > 0 and sub(int, 1, first) or ""
	for i = first + 1, n, 3 do
		out = (out == "" and "" or out .. group) .. sub(int, i, i + 2)
	end
	return out
end

--- `n` as text, by the global number settings.
---@param n number
---@return string
function Numbers:Format(n) -- luacheck: ignore 212
	if type(n) ~= "number" or n ~= n or n == math.huge or n == -math.huge then
		return tostring(n)
	end
	local separators = SEPARATORS[Globals.Get("numberFormat"):Get()] or SEPARATORS.space
	local precision, round = Globals.Get("numberPrecision"):Get(), Globals.Get("numberRound"):Get()
	local value = abs(n)
	local text = format("%." .. decimalsFor(value, precision, round) .. "f", value)
	if find(text, ".", 1, true) then
		text = gsub(gsub(text, "0+$", ""), "%.$", "")
	end
	local int, frac = text:match("^(%d+)%.?(%d*)$")
	local sign = (n < 0 and tonumber(text) ~= 0) and "-" or ""
	local out = sign .. grouped(int, separators[1])
	if frac ~= "" then
		out = out .. separators[2] .. frac
	end
	return out
end
