-- The bench's driver: runs steps one frame at a time on a frame of its own, measures them, and hands each result to
-- the module as a structured line
-- `scenario|size|impl|metric|luaMedian|luaP95|frameMedian|frameP95|kb|n|check|keptKb`
-- that scripts/bench_save.lua turns into the round's file. Dev only: it uses WoW directly.
--
-- Two times per measurement:
-- - Lua: debugprofilestop around the call. It misses work WoW defers to drawing (anchors, text layout).
-- - Frame: from the call's start to the next frame's start: the deferred work included, with everything else the
--   client does in a frame (the report reads it above the block's idle frame).
-- Medians and the 95th percentile. No garbage collection anywhere in a series: a full collection in its untimed
-- first frame, then the collector stays stopped through every frame of it (prepare frames, warm-up and measured
-- calls) until its result is recorded, so neither time holds collector work and KB is exactly each call's net heap
-- growth. What collecting a scenario's garbage costs is a bench of its own. Where the client can't stop the
-- collector, a full collection runs before each call instead. The first WARMUP calls of a series stay out of the
-- numbers. A step that hits the scheduler's pass cap (it didn't finish propagating) fails, whatever its time.
local format, sort, find = string.format, table.sort, string.find
local debugprofilestop, collectgarbage = debugprofilestop, collectgarbage

local Driver = {}

local canStop = pcall(collectgarbage, "stop") and pcall(collectgarbage, "restart")

--- How the collector is kept out of a series: "stop" (stopped from its first frame to its record) or "collect" (a
--- full collection before each call).
Driver.collector = canStop and "stop" or "collect"

-- A full collection, then the collector stopped (a full collection restarts it in Lua 5.1, so stop it again).
local function CollectAndStop()
	collectgarbage("collect")
	if canStop then
		collectgarbage("stop")
	end
end

local function Restart()
	if canStop then
		collectgarbage("restart")
	end
end

local WARMUP = 5

local frame
local running = false
local capHits = 0 -- the scheduler's "effects kept re-running each other" reports during the run

--- Every error during the run (the debug addon is off in measured rounds, so nothing else shows them): a step that
--- errored left its row missing or half-measured, so a round with any isn't recorded.
Driver.errors = { count = 0, first = {} }
local ERRORS_KEPT = 3

function Driver.IsRunning()
	return running
end

--- Run `steps` (functions returning true when done), one call per frame, then `done()`. While it runs, the error
--- handler counts the scheduler's pass-cap reports (then passes every error on).
---@param steps (fun(): boolean)[]
---@param done fun()
function Driver.Run(steps, done)
	if not frame then
		frame = CreateFrame("Frame")
	end
	running = true
	local previous = geterrorhandler()
	seterrorhandler(function(message, ...)
		local errors = Driver.errors
		errors.count = errors.count + 1
		if #errors.first < ERRORS_KEPT then
			errors.first[#errors.first + 1] = (tostring(message):gsub("[|\n]", " "))
		end
		if type(message) == "string" and find(message, "effects kept re-running", 1, true) then
			capHits = capHits + 1
		end
		return previous(message, ...)
	end)
	local index = 1
	frame:SetScript("OnUpdate", function()
		local step = steps[index]
		if not step then
			frame:SetScript("OnUpdate", nil)
			Restart() -- a series that errored left the collector stopped
			seterrorhandler(previous)
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

--- `store(line)` gets every structured line; a silent measure (the untracked warm-up pass) stores nothing.
---@param store fun(line: string)|nil
function Driver.NewMeasure(store)
	return setmetatable({ store = store, failures = 0 }, MeasureMeta)
end

function Measure:Record(scenario, size, impl, metric, lua, luaP95, frameMs, frameP95, kb, n, check, kept)
	if not self.store then
		return
	end
	self.store(format("%s|%s|%s|%s|%.4f|%.4f|%.3f|%.3f|%.2f|%d|%s|%s", scenario, size, impl, metric, lua, luaP95,
		frameMs, frameP95, kb, n, check or "", kept and format("%.1f", kept) or ""))
end

--- A line of its own (the order of a block's sides).
function Measure:Note(line)
	if self.store then
		self.store(line)
	end
end

function Measure:Verdict(ok, why)
	if ok == nil then
		return nil
	end
	if ok then
		return "ok"
	end
	if self.store then
		self.failures = self.failures + 1
	end
	return "FAIL " .. tostring(why or "")
end

local function Percentile(samples, n, p)
	sort(samples)
	return samples[math.floor((n - 1) * p + 0.5) + 1]
end

--- `count` timed calls, one per frame: fn(i); the first WARMUP (when count > WARMUP) aren't in the numbers.
--- options:
--- - prepare(i): runs untimed in a frame of its own before each timed call (open what a close then measures);
--- - verify(): untimed after the last call, decides the check (true, or false and why);
--- - kept: after each call (use with count 1), an untimed full collection: the heap growth since a collection just
---   before the call is what the call keeps (KB), next to what it allocated.
---@param options { prepare: fun(i: integer)?, verify: (fun(): boolean?, string?)?, kept: boolean? }|nil
function Measure:Series(scenario, size, impl, metric, count, fn, options)
	options = options or {}
	local prepare, verify, kept = options.prepare, options.verify, options.kept
	local skip = count > WARMUP and WARMUP or 0
	local measured = count - skip
	local lua, frames = {}, {}
	local i, prepared, started, kb, capStart, keptKb, base = 0, false, nil, 0, 0, nil, 0
	-- measured calls and frames the collector ran in anyway (the heap shrank): WoW's own collection step between
	-- frames re-arms a stopped collector, so it is stopped again before every call, and this proves it held
	local gcInCall, gcInFrame, after = 0, 0, 0
	return function()
		local now = debugprofilestop()
		if started then -- the frame of the last timed call ends here
			if i > skip then
				frames[i - skip] = now - started
				if collectgarbage("count") < after then
					gcInFrame = gcInFrame + 1
				end
			end
			started = nil
			if kept then
				CollectAndStop()
				keptKb = collectgarbage("count") - base
			end
		end
		if i == 0 and not prepared then -- the series' first frame: untimed
			CollectAndStop()
			kb, capStart, gcInCall, gcInFrame = 0, capHits, 0, 0
			if prepare then
				prepare(1)
			end
			prepared = true
			return false
		end
		if i == count then
			local check
			if capHits > capStart then
				check = self:Verdict(false, "the scheduler hit its pass cap: the change didn't finish")
			elseif gcInCall > 0 or gcInFrame > 0 then
				check = self:Verdict(false, string.format("the collector ran in %d measured calls and %d measured frames",
					gcInCall, gcInFrame))
			elseif verify then
				check = self:Verdict(verify())
			end
			self:Record(scenario, size, impl, metric, Percentile(lua, measured, 0.5), Percentile(lua, measured, 0.95),
				Percentile(frames, measured, 0.5), Percentile(frames, measured, 0.95), kb / measured, measured, check,
				keptKb)
			Restart()
			i, prepared = 0, false
			return true
		end
		if not prepared then -- a frame of its own for preparing the next call
			prepare(i + 1)
			prepared = true
			return false
		end
		i = i + 1
		prepared = prepare == nil -- with no preparing, the next call comes in the next frame
		if kept or not canStop then
			CollectAndStop()
			base = collectgarbage("count")
		end
		if canStop then
			collectgarbage("stop") -- again: a collection step since the last call re-arms it (no collection here)
		end
		local before = collectgarbage("count")
		local start = debugprofilestop()
		fn(i)
		local ms = debugprofilestop() - start
		after = collectgarbage("count")
		local grew = after - before
		started = start
		if i > skip then
			lua[i - skip] = ms
			kb = kb + grew
			if grew < 0 then
				gcInCall = gcInCall + 1
			end
		end
		return false
	end
end

--- One untimed action in a frame of its own (setting up or tearing down between measurements).
function Measure:Do(fn)
	return function()
		fn()
		return true
	end
end

--- A fact for the record (the probes), untimed: `describe()` returns its text, stored in the check field.
function Measure:Info(scenario, size, impl, metric, describe)
	return function()
		self:Record(scenario, size, impl, metric, 0, 0, 0, 0, 0, 1, "info " .. tostring(describe()))
		return true
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
