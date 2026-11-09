-- signals, by hand: values in a plain array. Which watchers each value feeds is one flat array (the watchers of value
-- k are feeds[first[k]] .. feeds[first[k + 1] - 1]), so the heap holds three tables, not one per value. A write queues
-- each watcher it feeds once per frame (a frame stamp, nothing to reset); the frame's work calls the queued watchers.
-- Each watcher is a function of its own, as each watch is separate code in an addon; it adds its sum inline.
local SIZES = {
	small = { values = 1000, sums = 100, watches = 300 },
	large = { values = 10000, sums = 1000, watches = 3000 },
}

local Signals = {}

local values, first, feeds, watchers, stamp, queue
local queued, frame, nValues = 0, 1, 0
local sink

function Signals.Make(size)
	local s = SIZES[size]
	nValues = s.values
	values, watchers, stamp, queue = {}, {}, {}, {}
	queued, frame = 0, 1
	local lists = {} -- per value, only while building
	for i = 1, s.values do
		values[i] = 0
		lists[i] = {}
	end
	local function feed(v, w)
		local list = lists[v]
		list[#list + 1] = w
	end
	local vals = values
	for w = 1, s.watches do
		local a, b, c = w, (w * 7) % s.values + 1, (w % s.sums) + 1
		local c2, c3 = c + s.sums, c + 2 * s.sums
		feed(a, w)
		feed(b, w)
		feed(c, w)
		feed(c2, w)
		feed(c3, w)
		watchers[w] = function()
			sink = vals[a] + vals[b] + vals[c] + vals[c2] + vals[c3]
		end
		stamp[w] = 0
	end
	first, feeds = {}, {}
	local n = 0
	for i = 1, s.values do
		first[i] = n + 1
		local list = lists[i]
		for j = 1, #list do
			n = n + 1
			feeds[n] = list[j]
		end
	end
	first[s.values + 1] = n + 1
end

function Signals.Write(k)
	k = (k - 1) % nValues + 1
	local vals = values
	vals[k] = vals[k] + 1
	local list, stamps, now, n = feeds, stamp, frame, queued
	for j = first[k], first[k + 1] - 1 do
		local w = list[j]
		if stamps[w] ~= now then
			stamps[w] = now
			n = n + 1
			queue[n] = watchers[w]
		end
	end
	queued = n
end

function Signals.Flush()
	local list = queue
	for i = 1, queued do
		list[i]()
	end
	queued = 0
	frame = frame + 1
end

return Signals
