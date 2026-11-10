-- The event loop's research bench (`/ordaen bench loop`): what a cooperative loop on coroutines costs in the real
-- client, timed with debugprofilestop. Not part of a round: its lines go to the log as `loop|...` and to chat.
--   yield: one coroutine yield + resume, and the garbage it makes (a plain call for scale)
--   await: an await on an event and its firing, the coroutine as the continuation (no closure per await)
--   slice: a long job run in one go, then the same job as a task sliced by a per-frame budget over real frames
--     (OnUpdate): frames used, the worst frame, the total time, against the one go
-- Dev only.
local Loop = {}

local N = 200000 -- round trips for the per-call costs
local UNIT = 200 -- additions per unit of the sliced job

local clock = debugprofilestop -- ms, microsecond precision

local function kb()
	return collectgarbage("count")
end

local function costYield()
	local co = coroutine.create(function()
		while true do
			coroutine.yield()
		end
	end)
	coroutine.resume(co)
	collectgarbage("collect")
	collectgarbage("stop")
	local m0, t0 = kb(), clock()
	for _ = 1, N do
		coroutine.resume(co)
	end
	local t1, m1 = clock(), kb()
	collectgarbage("restart")
	local f = function() end
	local c0 = clock()
	for _ = 1, N do
		f()
	end
	local call = (clock() - c0) * 1000 / N
	return (t1 - t0) * 1000 / N, (m1 - m0) * 1024 / N, call
end

local function costAwait()
	local waiting = { n = 0 }
	local function await()
		waiting.n = waiting.n + 1
		waiting[waiting.n] = coroutine.running()
		return coroutine.yield()
	end
	local function fire(v)
		local n = waiting.n
		waiting.n = 0
		for i = 1, n do
			local co = waiting[i]
			waiting[i] = nil
			coroutine.resume(co, v)
		end
	end
	local got = 0
	local co = coroutine.create(function()
		while true do
			got = got + await()
		end
	end)
	coroutine.resume(co)
	collectgarbage("collect")
	collectgarbage("stop")
	local m0, t0 = kb(), clock()
	for _ = 1, N do
		fire(1)
	end
	local t1, m1 = clock(), kb()
	collectgarbage("restart")
	return (t1 - t0) * 1000 / N, (m1 - m0) * 1024 / N, got == N
end

local function work(units)
	local x = 0
	for _ = 1, units do
		for k = 1, UNIT do
			x = x + k * 0.5
		end
	end
	return x
end

--- Run the bench; `say(text)` prints, `log(line)` records; `done()` when the sliced runs end (they span frames).
function Loop.Run(say, log, done)
	local yus, yb, call = costYield()
	log(string.format("loop|yield|%.4f|us|%.2f|bytes|call|%.4f", yus, yb, call))
	say(string.format("yield+resume %.3f µs, %.2f bytes (a call %.3f µs)", yus, yb, call))
	local aus, ab, ok = costAwait()
	log(string.format("loop|await|%.4f|us|%.2f|bytes|%s", aus, ab, ok and "ok" or "wrong"))
	say(string.format("await+fire %.3f µs, %.2f bytes", aus, ab))
	-- sliced jobs, one after another, over real frames
	local cases = { { units = 20000, budget = 2 }, { units = 20000, budget = 4 }, { units = 200000, budget = 4 } }
	local frame = CreateFrame("Frame")
	local index, co, case, frames, worst, total, oneGo, budget, frameStart = 0, nil, nil, 0, 0, 0, 0, 0, 0
	local function checkpoint()
		if clock() - frameStart >= budget then
			coroutine.yield()
		end
	end
	local function nextCase()
		index = index + 1
		case = cases[index]
		if not case then
			frame:SetScript("OnUpdate", nil)
			done()
			return
		end
		local t0 = clock()
		work(case.units)
		oneGo = clock() - t0
		budget, frames, worst, total = case.budget, 0, 0, 0
		co = coroutine.create(function()
			local x = 0
			for _ = 1, case.units do
				for k = 1, UNIT do
					x = x + k * 0.5
				end
				checkpoint()
			end
			return x
		end)
	end
	nextCase()
	frame:SetScript("OnUpdate", function()
		if not case then
			return
		end
		frameStart = clock()
		coroutine.resume(co)
		local spent = clock() - frameStart
		frames = frames + 1
		total = total + spent
		if spent > worst then
			worst = spent
		end
		if coroutine.status(co) == "dead" then
			log(string.format("loop|slice|%d|units|%d|ms budget|%.2f|one go ms|%d|frames|%.3f|worst ms|%.2f|total ms",
				case.units, case.budget, oneGo, frames, worst, total))
			say(string.format("job %d, budget %d ms: one go %.1f ms; sliced %d frames, worst %.2f ms, total %.1f ms " ..
				"(%+.1f%%)", case.units, case.budget, oneGo, frames, worst, total, (total - oneGo) / oneGo * 100))
			nextCase()
		end
	end)
end

return Loop
