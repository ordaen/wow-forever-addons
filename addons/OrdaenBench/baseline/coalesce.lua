-- coalesce, by hand: writes only set the value and a dirty flag; the frame's work calls the 100 watchers once if
-- the flag is set. Each watcher is a function of its own, as each watch is separate code in an addon.
local counters = import("bench/counters")

local WATCHES = 100

local Coalesce = {}

local value, changed, sink = 0, false, 0
local watchers = {}
for i = 1, WATCHES do
	watchers[i] = function()
		counters.runs = counters.runs + 1
		sink = value
	end
end

function Coalesce.WriteMany(times)
	local v = value
	for _ = 1, times do
		v = v + 1
	end
	value = v
	changed = true
end

function Coalesce.Flush()
	if not changed then
		return
	end
	changed = false
	local list = watchers
	for i = 1, WATCHES do
		list[i]()
	end
end

return Coalesce
