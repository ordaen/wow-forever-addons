-- The bench's driver: runs steps one frame at a time on a frame of its own (the game draws between steps), measures
-- them with debugprofilestop and the Lua heap, and records each result twice: a line in chat, and a structured line
-- `scenario|size|impl|metric|ms|maxMs|kb|n|check` that scripts/bench_save.lua turns into the round's file.
-- Dev only: it uses WoW directly.
local format = string.format
local debugprofilestop, collectgarbage = debugprofilestop, collectgarbage

local Driver = {}

local frame
local running = false

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

---@param print fun(line: string) a line for people (chat, log)
---@param store fun(line: string) a structured line for the round's file
function Driver.NewMeasure(print, store)
	return setmetatable({ print = print, store = store, failures = 0 }, MeasureMeta)
end

-- Heap growth reads low (or below zero) when a garbage collection step runs inside the measured code.
local SHOWN = "%-9s %-5s %-9s %-26s %9.3f ms  max %8.3f  %9.1f KB  n=%-4d %s"

function Measure:Record(scenario, size, impl, metric, ms, max, kb, n, check)
	check = check or ""
	self.print(format(SHOWN, scenario, size, impl, metric, ms, max, kb, n, check))
	self.store(format("%s|%s|%s|%s|%.4f|%.4f|%.2f|%d|%s", scenario, size, impl, metric, ms, max, kb, n, check))
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

--- One timed call. `fn` may return a check: true (ok), or false and why.
function Measure:Once(scenario, size, impl, metric, fn)
	return function()
		local kb = collectgarbage("count")
		local start = debugprofilestop()
		local ok, why = fn()
		local ms = debugprofilestop() - start
		self:Record(scenario, size, impl, metric, ms, ms, collectgarbage("count") - kb, 1, self:Verdict(ok, why))
		return true
	end
end

--- `count` timed calls, one per frame, reported per call: fn(i). `verify()` (optional) runs after the last, untimed.
function Measure:Series(scenario, size, impl, metric, count, fn, verify)
	local done, total, max, kb = 0, 0, 0, 0
	return function()
		done = done + 1
		local before = collectgarbage("count")
		local start = debugprofilestop()
		fn(done)
		local ms = debugprofilestop() - start
		kb = kb + collectgarbage("count") - before
		total = total + ms
		if ms > max then
			max = ms
		end
		if done < count then
			return false
		end
		local check
		if verify then
			check = self:Verdict(verify())
		end
		self:Record(scenario, size, impl, metric, total / count, max, kb / count, count, check)
		done, total, max, kb = 0, 0, 0, 0
		return true
	end
end

--- A correctness check alone, untimed.
function Measure:Check(scenario, size, impl, metric, verify)
	return function()
		self:Record(scenario, size, impl, metric, 0, 0, 0, 1, self:Verdict(verify()))
		return true
	end
end

return Driver
