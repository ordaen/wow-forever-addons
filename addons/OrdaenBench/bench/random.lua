-- A seeded random sequence (Park and Miller's minimal standard generator: every product stays below 2^53, so Lua's
-- doubles keep it exact): random-looking actions (cell 53, then 8, then 132),
-- the same sequence on every side and in every round, so the sides do the same work and rounds compare. Made once per
-- series at plan time; drawing a number makes no garbage.
local Random = {}
local RandomMeta = { __index = Random }

local SEED = 20261109 -- any value from 1 to 2^31 - 2

--- A new sequence, always from the same seed.
function Random.New()
	return setmetatable({ state = SEED }, RandomMeta)
end

--- A whole number from 1 to n.
function Random:Next(n)
	self.state = self.state * 16807 % 2147483647
	return self.state % n + 1
end

return Random
