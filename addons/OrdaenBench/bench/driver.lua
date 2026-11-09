-- The bench's driver: runs steps one frame at a time on a frame of its own, measures them, and records each result
-- twice: a line for the log, and a structured line
-- `scenario|size|impl|metric|luaMedian|luaP95|frameMedian|frameP95|kb|n|check` that scripts/bench_save.lua turns
-- into the round's file. Dev only: it uses WoW directly.
--
-- Two times per measurement:
-- - Lua: debugprofilestop around the step. It misses work WoW defers to drawing (anchors, text layout), so code that
--   never reads geometry back looks cheaper than it is.
-- - Frame: from this OnUpdate to the next, which includes that deferred work (and everything else the client does in
--   the frame, so cap the frame rate high and turn vsync off while the bench runs).
-- Medians and the 95th percentile, not mean and max. Garbage collection never runs inside a timed call: Lua runs a
-- GC step in whatever code allocates when the debt is due, so code that allocates would pay for other addons'
-- garbage. The collector is stopped around each timed call where the client allows it, else a full collection runs
-- just before the call; the heap growth (KB) is then exactly what the call allocated. Before every measurement an
-- untimed full collection, so one side's garbage isn't left to the other. The first WARMUP calls of a series grow
-- arrays and queues to their working size and stay out of the numbers.
local format, sort = string.format, table.sort
local debugprofilestop, collectgarbage = debugprofilestop, collectgarbage

local Driver = {}

local frame
local running = false

local canStop = pcall(collectgarbage, "stop") and pcall(collectgarbage, "restart")

local function Quiet()
	if canStop then
		collectgarbage("stop")
	else
		collectgarbage("collect")
	end
end

local function Resume()
	if canStop then
		collectgarbage("restart")
	end
end

local WARMUP = 5

--- How the collector is kept out of timed calls: "stop" (stopped around each call; its work for a call's garbage
--- lands in that frame) or "collect" (a full collection before each call; frame times then hold no GC).
Driver.collector = canStop and "stop" or "collect"

function Driver.IsRunning()
	return running
end

--- Run `steps` (functions returning true when done), one call per frame, then `done()`.
---@param steps (fun(): boolean)[]
---@param done fun()
function Driver.Run(steps, done)
	if not frame then
		frame = CreateFrame("Frame")
	end
	running = true
	local index = 1
	frame:SetScript("OnUpdate", function()
		local step = steps[index]
		if not step then
			frame:SetScript("OnUpdate", nil)
			running = false
			done()
			return
		end
		local ok, finished = xpcall(step, geterrorhandler())
		if not ok or finished then
			index = index + 1
		end
	end)
end

---@class BenchMeasure
local Measure = {}
local MeasureMeta = { __index = Measure }

---@param log fun(line: string) a line for people (the log)
---@param store fun(line: string) a structured line for the round's file
function Driver.NewMeasure(log, store)
	return setmetatable({ log = log, store = store, failures = 0 }, MeasureMeta)
end

local SHOWN = "%-9s %-5s %-9s %-30s lua %8.3f/%8.3f  frame %7.2f/%7.2f ms  %8.1f KB  n=%-4d %s"

function Measure:Record(scenario, size, impl, metric, lua, luaP95, frame, frameP95, kb, n, check)
	check = check or ""
	self.log(format(SHOWN, scenario, size, impl, metric, lua, luaP95, frame, frameP95, kb, n, check))
	self.store(format("%s|%s|%s|%s|%.4f|%.4f|%.3f|%.3f|%.2f|%d|%s", scenario, size, impl, metric, lua, luaP95, frame,
		frameP95, kb, n, check))
end

function Measure:Verdict(ok, why)
	if ok == nil then
		return nil
	end
	if ok then
		return "ok"
	end
	self.failures = self.failures + 1
	return "FAIL " .. tostring(why or "")
end

local function Percentile(samples, n, p)
	sort(samples)
	local i = math.floor((n - 1) * p + 0.5) + 1
	return samples[i]
end

--- `count` calls, one per frame: fn(i); the first WARMUP aren't in the numbers. Before them an untimed frame collects
--- garbage; after the last, one more frame closes the last frame time, then `verify()` (optional, untimed) decides
--- the check.
function Measure:Series(scenario, size, impl, metric, count, fn, verify)
	local lua, frames = {}, {}
	local phase, kb, last = 0, 0, 0
	local measured = count - WARMUP
	return function()
		local now = debugprofilestop()
		if phase == 0 then
			collectgarbage("collect")
			phase, kb = 1, 0
			return false
		end
		if phase > WARMUP + 1 then
			frames[phase - 1 - WARMUP] = now - last
		end
		if phase > count then
			local check
			if verify then
				check = self:Verdict(verify())
			end
			self:Record(scenario, size, impl, metric, Percentile(lua, measured, 0.5), Percentile(lua, measured, 0.95),
				Percentile(frames, measured, 0.5), Percentile(frames, measured, 0.95), kb / measured, measured, check)
			phase = 0
			return true
		end
		Quiet()
		local before = collectgarbage("count")
		last = debugprofilestop()
		fn(phase)
		local ms = debugprofilestop() - last
		local grew = collectgarbage("count") - before
		Resume()
		if phase > WARMUP then
			lua[phase - WARMUP] = ms
			kb = kb + grew
		end
		phase = phase + 1
		return false
	end
end

--- One timed call (`fn` may return a check: true, or false and why), after an untimed garbage collection; its frame
--- time is the frame it ran in.
function Measure:Once(scenario, size, impl, metric, fn)
	local phase, lua, kb, check, start = 0, 0, 0, nil, 0
	return function()
		local now = debugprofilestop()
		if phase == 0 then
			collectgarbage("collect")
			phase = 1
			return false
		end
		if phase == 2 then
			self:Record(scenario, size, impl, metric, lua, lua, now - start, now - start, kb, 1, check)
			phase = 0
			return true
		end
		Quiet()
		local before = collectgarbage("count")
		start = debugprofilestop()
		local ok, why = fn()
		lua = debugprofilestop() - start
		kb = collectgarbage("count") - before
		Resume()
		check = self:Verdict(ok, why)
		phase = 2
		return false
	end
end

--- A correctness check alone, untimed.
function Measure:Check(scenario, size, impl, metric, verify)
	return function()
		self:Record(scenario, size, impl, metric, 0, 0, 0, 0, 0, 1, self:Verdict(verify()))
		return true
	end
end

return Driver
