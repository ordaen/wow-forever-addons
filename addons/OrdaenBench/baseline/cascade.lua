-- cascade, by hand: a change of the first value is the value of all 50 (a copy along the chain, written in one loop).
local LENGTH = 50

local Cascade = {}

local values = {}
for i = 1, LENGTH do
	values[i] = 0
end

function Cascade.Bump()
	local list = values
	local v = list[1] + 1
	for i = 1, LENGTH do
		list[i] = v
	end
end

function Cascade.Settled()
	return values[LENGTH] == values[1]
end

return Cascade
