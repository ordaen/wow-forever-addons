-- The loop (design development/framework/loop): tasks, coroutines the engine resumes. A task waits with `await` (the
-- next frame, a delay, a source's firing, other tasks) and gives the frame back in long work with `checkpoint()`.
-- One driver runs them once a frame inside a CPU budget (Loop.Step, called by the Scheduler before its flush).
--
-- No garbage per wait: the task (its coroutine) is the continuation; what it waits for is kept in its own fields, the
-- ready and waiting lists are reused arrays. Idle costs nothing: with only delays waiting, one C_Timer set to the
-- nearest due time wakes the driver (Loop.OnWake); with only sources waiting, nothing runs until one fires.
local _, ns = ...

local coroutine, debugprofilestop, GetTime = coroutine, debugprofilestop, GetTime
local create, resume, status, yield = coroutine.create, coroutine.resume, coroutine.status, coroutine.yield

---@class OrdaenLoop
local Loop = {}
ns.Loop = Loop

local BUDGET = 2 -- ms a frame for tasks: the Core's default
local CHECK_EVERY = 16 -- checkpoint() reads the clock once every this many calls

-- The debug kit once the dev addon can have replaced the stand-in (after login): the recorder's "loop" channel
local kitCache
local function kit()
	if kitCache then
		return kitCache
	end
	local k = ns.Core.NewDebug("OrdaenCore")
	if ns.Stage and ns.Stage.Login.fired then
		kitCache = k
	end
	return k
end

---@class OrdaenTask
---@field co thread
---@field owner any what holds it (an instance); ends with it
---@field site string where it was spawned (file:line)
---@field state "ready"|"running"|"waiting"|"done"
---@field wait string what it waits for: "frame", "delay", "source", "all", "checkpoint", "" while running
---@field due number? game time it's due (a delay)
---@field cpu number ms spent in its resumes
---@field a1 any what its next resume passes (the first resume's arguments, or a source's payload), up to four
---@field a2 any
---@field a3 any
---@field a4 any
---@field waiters OrdaenTask[]? the tasks waiting for it to end (await.all)
---@field pending integer? tasks it still waits for (await.all)
---@field onFire function? its handler for the sources it waits on, made once
---@field unsubscribe fun(task: OrdaenTask)? ends its wait on a source
local Task = {}
local TaskMeta = { __index = Task }

local byCo = setmetatable({}, { __mode = "k" }) -- coroutine -> its task
local live = {} -- every task not ended (for the dev window), as a set
local ready, nReady = {}, 0 -- resumed in this order
local later, nLater = {}, 0 -- ready from the next frame on (await.frame, a checkpoint)
local timers, nTimers = {}, 0 -- waiting on a delay (unordered: a few)
local current -- the task running now
local frameEnd = 0 -- debugprofilestop() when this frame's budget is spent
local checks = 0 -- checkpoint calls since the last clock read

--- How one resume runs: `run(task.owner, step, task)`; the engine sets it to Engine:Run, so a resume is a
--- transaction (its writes kept when it reaches a wait or ends, reverted when it fails). Plain call by default.
Loop.Runner = function(_, step, task)
	step(task)
end
--- Called when a delay waits with nothing else to run: the driver sets a C_Timer to `at` (game time). Set by the
--- Scheduler.
---@type fun(at: number?)
Loop.OnWake = function(_) end
--- Called when a task becomes ready while the driver may be asleep: the Scheduler sets its OnUpdate again.
Loop.OnReady = function() end

local function push(task)
	task.state, task.wait = "ready", ""
	nReady = nReady + 1
	ready[nReady] = task
	Loop.OnReady()
end

local function pushLater(task, wait)
	task.state, task.wait = "waiting", wait
	nLater = nLater + 1
	later[nLater] = task
	Loop.OnReady()
end

local function fail(task, err)
	local Debug = kit()
	Debug:Record("loop", "failed %s: %s", task.site, err)
	-- the task's own stack (where it failed), not the loop's: debugstack takes the coroutine
	local ok, stack = pcall(debugstack, task.co, 1, 20, 0)
	geterrorhandler()(tostring(err) .. "\n" .. (ok and stack or "") .. "\nspawned at " .. task.site)
end

local function finish(task)
	task.state, task.wait = "done", ""
	live[task] = nil
	local Debug = kit()
	Debug:Record("loop", "ended %s (%.2f ms)", task.site, task.cpu)
	local waiters = task.waiters
	if waiters then -- tasks waiting on this one (await.all)
		task.waiters = nil
		for i = 1, #waiters do
			local w = waiters[i]
			if w.state == "waiting" and w.wait == "all" then
				w.pending = w.pending - 1
				if w.pending == 0 then
					push(w)
				end
			end
		end
	end
end

-- One resume of a task, inside the runner: its arguments (the first resume's, or what it waited for) are the task's
-- own fields, set before.
local function step(task)
	local co = task.co
	local outer = current -- a task spawned by a task: the spawner runs again after
	current = task
	local t0 = debugprofilestop()
	local ok, err = resume(co, task.a1, task.a2, task.a3, task.a4)
	task.cpu = task.cpu + (debugprofilestop() - t0)
	current = outer
	task.a1, task.a2, task.a3, task.a4 = nil, nil, nil, nil
	if not ok then
		live[task] = nil
		task.state = "done"
		fail(task, err)
		error(err, 0) -- the runner's transaction sees the failure and reverts
	elseif status(co) == "dead" then
		finish(task)
	end
end

local function run(task)
	if task.state == "done" then
		return
	end
	task.state = "running"
	local ok = pcall(Loop.Runner, task.owner, step, task)
	if not ok and task.state ~= "done" then -- the runner itself failed: the task can't go on
		task.state = "done"
		live[task] = nil
	end
end

--- Spawn a task: `fn(...)` runs now, up to its first wait. `owner` is what holds it (it ends with it: the engine's
--- holder cancels it). Returns the task.
---@param owner any
---@param fn function
---@return OrdaenTask
function Loop.Spawn(owner, fn, a1, a2, a3, a4)
	-- where it was spawned: the first file:line of the caller's stack
	local where = debugstack(2, 1, 0) or ""
	local site = where:match("([%w_%-%./\\]+%.lua%]?:%d+)") or "?"
	local task = setmetatable({ co = create(fn), owner = owner, state = "ready", wait = "", cpu = 0,
		site = site }, TaskMeta)
	byCo[task.co] = task
	live[task] = true
	task.a1, task.a2, task.a3, task.a4 = a1, a2, a3, a4
	local Debug = kit()
	Debug:Record("loop", "spawned %s", task.site)
	run(task)
	return task
end

--- End the task: it never resumes. Idempotent, and safe from inside the task itself (it ends at its next wait).
function Task:Cancel()
	if self.state == "done" then
		return
	end
	local unsubscribe = self.unsubscribe
	if unsubscribe then
		self.unsubscribe = nil
		unsubscribe(self)
	end
	self.state, self.wait = "done", ""
	live[self] = nil
	local Debug = kit()
	Debug:Record("loop", "cancelled %s", self.site)
	if current == self then
		yield() -- from inside: stop here (never resumed again)
	end
end

local function inTask(name)
	local task = current
	if not task then
		error("Ordaen: " .. name .. " outside a task (only a function given to Spawn may wait)", 3)
	end
	return task
end

-- After a wait returns: a task cancelled while it waited stops for good
local function resumed(task)
	if task.state == "done" then
		yield()
	end
end

---@class OrdaenAwait
local await = {}
Loop.await = await

--- Wait for the next frame.
function await.frame()
	local task = inTask("await.frame")
	pushLater(task, "frame")
	yield()
	resumed(task)
end

--- Wait `seconds` of game time (checked once a frame: at most a frame late).
---@param seconds number
function await.delay(seconds)
	local task = inTask("await.delay")
	task.state, task.wait, task.due = "waiting", "delay", GetTime() + seconds
	nTimers = nTimers + 1
	timers[nTimers] = task
	Loop.OnWake(Loop.NextDue())
	yield()
	resumed(task)
end

--- Wait for a source's next firing (a framework signal or event: `source:Subscribe(fn, owner)` returning a function
--- that unsubscribes); returns its payload. The source's handler for this task is made once, on its first wait.
---@param source table
function await.source(source)
	local task = inTask("await.source")
	local onFire = task.onFire
	if not onFire then
		onFire = function(a1, a2, a3, a4)
			if task.state ~= "waiting" or task.wait ~= "source" then
				return
			end
			local unsubscribe = task.unsubscribe --[[@as fun(task: OrdaenTask)?]]
			task.unsubscribe = nil
			if unsubscribe then
				unsubscribe(task)
			end
			task.a1, task.a2, task.a3, task.a4 = a1, a2, a3, a4
			push(task)
		end
		task.onFire = onFire
	end
	task.state, task.wait = "waiting", "source"
	local off = source:Subscribe(onFire, task.owner)
	task.unsubscribe = off and function()
		off()
	end or nil
	return yield()
end
await.event = await.source

--- Wait until every task given has ended.
function await.all(...)
	local task = inTask("await.all")
	local pending = 0
	for i = 1, select("#", ...) do
		local other = select(i, ...)
		if other.state ~= "done" then
			pending = pending + 1
			local waiters = other.waiters
			if not waiters then
				waiters = {}
				other.waiters = waiters
			end
			waiters[#waiters + 1] = task
		end
	end
	if pending == 0 then
		return
	end
	task.state, task.wait, task.pending = "waiting", "all", pending
	yield()
	resumed(task)
end

--- In long work: gives the frame back when the frame's budget is spent (the clock read once every CHECK_EVERY calls).
function Loop.checkpoint()
	local task = inTask("checkpoint")
	checks = checks + 1
	if checks < CHECK_EVERY then
		return
	end
	checks = 0
	if debugprofilestop() < frameEnd then
		return
	end
	pushLater(task, "checkpoint")
	yield()
	resumed(task)
end

--- The nearest game time a delay is due, or nil.
function Loop.NextDue()
	local due
	for i = 1, nTimers do
		local t = timers[i].due
		if t and (not due or t < due) then
			due = t
		end
	end
	return due
end

--- One frame's slice: delays due by `now` become ready, the tasks ready from the last frame join them, and ready
--- tasks run in order until `budget` ms are spent (at least one, so none starves). Returns whether tasks are left
--- ready (the driver keeps running next frame) and the nearest due time (the driver's wake-up while idle).
---@param now number game time (GetTime)
---@param budget number? ms; the Core's default when nil
---@return boolean, number?
function Loop.Step(now, budget)
	-- the tasks that gave the last frame back, then the delays now due
	for i = 1, nLater do
		local task = later[i]
		later[i] = nil
		if task.state == "waiting" then
			push(task)
		end
	end
	nLater = 0
	local i = 1
	while i <= nTimers do
		local task = timers[i]
		if task.state ~= "waiting" or task.wait ~= "delay" then -- cancelled: drop it
			timers[i] = timers[nTimers]
			timers[nTimers] = nil
			nTimers = nTimers - 1
		elseif task.due <= now then
			timers[i] = timers[nTimers]
			timers[nTimers] = nil
			nTimers = nTimers - 1
			task.due = nil
			push(task)
		else
			i = i + 1
		end
	end
	local start = debugprofilestop()
	frameEnd = start + (budget or BUDGET)
	checks = 0
	local ran, longest, k = 0, 0, 1
	while k <= nReady do
		local task = ready[k]
		ready[k] = nil
		k = k + 1
		if task.state == "ready" then
			local t0 = debugprofilestop()
			run(task)
			ran = ran + 1
			local spent = debugprofilestop() - t0
			if spent > longest then
				longest = spent
			end
			if debugprofilestop() >= frameEnd then
				break
			end
		end
	end
	-- what's left waits for the next frame, in its order
	local left = 0
	for j = k, nReady do
		left = left + 1
		ready[left] = ready[j]
		if j ~= left then
			ready[j] = nil
		end
	end
	nReady = left
	if ran > 0 then
		local Debug = kit()
		Debug:Record("loop", "frame: %d resumed, %.3f ms of %.1f, longest %.3f, %d left ready, %d waiting a delay",
			ran, debugprofilestop() - start, budget or BUDGET, longest, nReady + nLater, nTimers)
	end
	return nReady + nLater > 0, Loop.NextDue()
end

--- Every live task (for the dev window's list and the specs): the set, task -> true.
function Loop._Live()
	return live
end

--- The task running now, or nil.
function Loop.Current()
	return current
end

return Loop
