-- cascade, by hand: a change of the first value is copied along the 50 in a loop.
local LENGTH = 50

local Cascade = {}

local values = {}
for i = 1, LENGTH do
	values[i] = 0
end

function Cascade.Bump()
	values[1] = values[1] + 1
	for i = 2, LENGTH do
		values[i] = values[i - 1]
	end
end

function Cascade.Settled()
	return values[LENGTH] == values[1]
end

return Cascade
