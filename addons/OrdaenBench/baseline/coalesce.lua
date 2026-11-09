-- coalesce, by hand: writes only set the value and a dirty flag; the frame's work calls the 100 watchers once if
-- the flag is set.
local counters = import("bench/counters")

local WATCHES = 100

local Coalesce = {}

local value, changed, sink = 0, false, 0

function Coalesce.WriteMany(times)
	for _ = 1, times do
		value = value + 1
	end
	changed = true
end

function Coalesce.Flush()
	if not changed then
		return
	end
	changed = false
	for _ = 1, WATCHES do
		counters.runs = counters.runs + 1
		sink = value
	end
end

return Coalesce
