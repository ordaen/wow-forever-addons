-- The bench's driver: runs steps one frame at a time on a frame of its own (the game draws between steps), and
-- measures them with debugprofilestop and the Lua heap. Dev only: it uses WoW directly.
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

---@param record fun(line: string)
function Driver.NewMeasure(record)
	return setmetatable({ record = record }, MeasureMeta)
end

-- Heap growth can read low (or below zero) when a garbage collection step runs inside the measured code.
local LINE = "%-40s %9.3f ms  max %8.3f ms  %8.1f KB  (n=%d)"

--- One timed call.
function Measure:Once(label, fn)
	return function()
		local kb = collectgarbage("count")
		local start = debugprofilestop()
		fn()
		local ms = debugprofilestop() - start
		self.record(format(LINE, label, ms, ms, collectgarbage("count") - kb, 1))
		return true
	end
end

local function Series(self, label, count, fn)
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
		self.record(format(LINE, label, total / count, max, kb / count, count))
		return true
	end
end

--- `count` timed calls, one per frame, reported per call: fn(i).
function Measure:Repeat(label, count, fn)
	return Series(self, label, count, fn)
end

--- `count` frames of steady work, reported per frame: fn(frame).
function Measure:Frames(label, count, fn)
	return Series(self, label, count, fn)
end

return Driver
