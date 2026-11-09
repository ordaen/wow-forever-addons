-- chain, by hand: a change of the root recomputes the 150 steps in a loop and checks the last.
local counters = import("bench/counters")

local LENGTH = 150 -- below the ~195 levels where nested recomputes overflow the C stack (a framework limit to fix)

local Chain = {}

local root = 0
local steps = {}

function Chain.Bump()
	root = root + 1
	local previous = root
	for i = 1, LENGTH do
		previous = previous + 1
		steps[i] = previous
	end
	counters.runs = counters.runs + 1
	if steps[LENGTH] ~= root + LENGTH then
		counters.violations = counters.violations + 1
	end
end

return Chain
