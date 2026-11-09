-- diamond, by hand: a change of the root recomputes the 100 parts and their sum, and checks it.
local counters = import("bench/counters")

local WIDTH = 100
local EXPECTED = WIDTH * (WIDTH + 1) / 2

local Diamond = {}

local root = 1
local parts = {}

function Diamond.Bump()
	local r = root + 1
	root = r
	local list, total = parts, 0
	for i = 1, WIDTH do
		local part = r * i
		list[i] = part
		total = total + part
	end
	counters.runs = counters.runs + 1
	if total ~= r * EXPECTED then
		counters.violations = counters.violations + 1
	end
end

return Diamond
