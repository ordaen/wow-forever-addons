-- signals, by hand: values in a plain array; each value lists the watchers that depend on it; a write sets a dirty
-- flag per watcher and queues it once; the frame's work runs the queue once (what the framework's scheduler does,
-- written for this one case). Sums are recomputed inside the watcher that needs them.
local SIZES = {
	small = { values = 1000, sums = 100, watches = 300 },
	large = { values = 10000, sums = 1000, watches = 3000 },
}

local Signals = {}

local values, dependants, queue, queued, dirty, watchA, watchB, watchSum, sumBase, sink
local nValues

function Signals.Make(size)
	local s = SIZES[size]
	nValues = s.values
	values, dependants, queue, queued, dirty = {}, {}, {}, 0, {}
	watchA, watchB, watchSum, sumBase = {}, {}, {}, s.sums
	for i = 1, s.values do
		values[i] = 0
		dependants[i] = {}
	end
	local function depend(v, w)
		local list = dependants[v]
		list[#list + 1] = w
	end
	for w = 1, s.watches do
		local a, b, c = w, (w * 7) % s.values + 1, (w % s.sums) + 1
		watchA[w], watchB[w], watchSum[w] = a, b, c
		depend(a, w)
		depend(b, w)
		depend(c, w)
		depend(c + s.sums, w)
		depend(c + 2 * s.sums, w)
		dirty[w] = false
	end
end

function Signals.Write(k)
	k = (k - 1) % nValues + 1
	values[k] = values[k] + 1
	local list = dependants[k]
	for j = 1, #list do
		local w = list[j]
		if not dirty[w] then
			dirty[w] = true
			queued = queued + 1
			queue[queued] = w
		end
	end
end

function Signals.Flush()
	local base = sumBase
	for i = 1, queued do
		local w = queue[i]
		queue[i] = nil
		dirty[w] = false
		local c = watchSum[w]
		sink = values[watchA[w]] + values[watchB[w]] + values[c] + values[c + base] + values[c + 2 * base]
	end
	queued = 0
end

return Signals
