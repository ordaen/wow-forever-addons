-- signals, as a typical addon writes it: a write calls every listener of that value at once (an event per change),
-- so a listener that depends on several values runs once per change of each, and recomputes its sum each time.
local SIZES = {
	small = { values = 1000, sums = 100, watches = 300 },
	large = { values = 10000, sums = 1000, watches = 3000 },
}

local Signals = {}

local values, listeners, nValues
local sink = 0

function Signals.Make(size)
	local s = SIZES[size]
	nValues = s.values
	values, listeners = {}, {}
	for i = 1, s.values do
		values[i] = 0
		listeners[i] = {}
	end
	local function listen(v, fn)
		table.insert(listeners[v], fn)
	end
	for w = 1, s.watches do
		local a, b, c = w, (w * 7) % s.values + 1, (w % s.sums) + 1
		local function OnChange()
			sink = values[a] + values[b] + values[c] + values[c + s.sums] + values[c + 2 * s.sums]
		end
		listen(a, OnChange)
		listen(b, OnChange)
		listen(c, OnChange)
		listen(c + s.sums, OnChange)
		listen(c + 2 * s.sums, OnChange)
	end
end

function Signals.Write(k)
	k = (k - 1) % nValues + 1
	values[k] = values[k] + 1
	for _, fn in ipairs(listeners[k]) do
		fn()
	end
end

return Signals
