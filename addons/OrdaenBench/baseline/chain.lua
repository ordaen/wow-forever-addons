-- chain, by hand: a change of the root recomputes the 150 steps in a loop and checks the last.
local counters = import("bench/counters")

local LENGTH = 150 -- below the ~195 levels where nested recomputes overflow the C stack (a framework limit to fix)

local Chain = {}

local root = 0
local steps = {}

function Chain.Bump()
	local r = root + 1
	root = r
	local list, previous = steps, r
	for i = 1, LENGTH do
		previous = previous + 1
		list[i] = previous
	end
	counters.runs = counters.runs + 1
	if list[LENGTH] ~= r + LENGTH then
		counters.violations = counters.violations + 1
	end
end

return Chain
