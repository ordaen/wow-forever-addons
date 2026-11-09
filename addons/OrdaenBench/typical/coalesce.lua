-- coalesce, as a typical addon writes it: every write calls the 100 listeners at once (an event per change).
local counters = import("bench/counters")

local WATCHES = 100

local Coalesce = {}

local value, sink = 0, 0
local listeners = {}
for i = 1, WATCHES do
	listeners[i] = function()
		counters.runs = counters.runs + 1
		sink = value
	end
end

function Coalesce.WriteMany(times)
	for _ = 1, times do
		value = value + 1
		for _, fn in ipairs(listeners) do
			fn()
		end
	end
end

return Coalesce
