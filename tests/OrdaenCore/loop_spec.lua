-- The loop (addons/OrdaenCore/Loop.lua; design development/framework/loop): tasks and their waits, driven by hand
-- with Loop.Step as the Scheduler does once a frame.
local Fake = require("tests.fake.wow")

local function start()
	local wow = Fake.New({ dist = ".ordaen/check/dist", addons = { "OrdaenCore" } })
	wow:Login()
	return wow, wow.addons.OrdaenCore.ns.Loop
end

describe("the loop", function()
	it("runs a task now up to its first wait, then a frame later", function()
		local wow, Loop = start()
		local seen = {}
		Loop.Spawn(nil, function(a)
			seen[#seen + 1] = "start " .. a
			Loop.await.frame()
			seen[#seen + 1] = "next frame"
		end, "x")
		assert.are.same({ "start x" }, seen)
		Loop.Step(wow.time)
		assert.are.same({ "start x", "next frame" }, seen)
		assert.is_nil(next(Loop._Live())) -- ended: gone
		assert.are.same({}, wow.errors)
	end)

	it("waits a delay in game time, and tells the driver when to wake", function()
		local wow, Loop = start()
		local done = false
		local woke
		Loop.OnWake = function(at)
			woke = at
		end
		Loop.Spawn(nil, function()
			Loop.await.delay(2)
			done = true
		end)
		assert.are.equal(wow.time + 2, woke)
		Loop.Step(wow.time + 1)
		assert.is_false(done)
		Loop.Step(wow.time + 2)
		assert.is_true(done)
	end)

	it("resumes a task on a source's firing with its payload, and unsubscribes", function()
		local _, Loop = start()
		local subs = {}
		local source = { Subscribe = function(_, fn)
			subs[#subs + 1] = fn
			return function()
				subs[#subs] = nil
			end
		end }
		local got
		Loop.Spawn(nil, function()
			got = Loop.await.source(source)
		end)
		assert.are.equal(1, #subs)
		subs[1](42)
		assert.are.equal(0, #subs) -- one firing: unsubscribed
		Loop.Step(0)
		assert.are.equal(42, got)
	end)

	it("gives the frame back at a checkpoint once the budget is spent, and goes on next frame", function()
		local wow, Loop = start()
		wow.clock = 0
		local units = 0
		Loop.Spawn(nil, function()
			Loop.await.frame()
			for _ = 1, 100 do
				units = units + 1
				wow.clock = wow.clock + 0.1 -- each unit costs 0.1 ms
				Loop.checkpoint()
			end
		end)
		Loop.Step(0, 2) -- a 2 ms budget: about 20 units, a few more (the clock read every 16 checkpoints)
		assert.is_true(units >= 20 and units < 100, units)
		local first = units
		Loop.Step(0, 2)
		assert.is_true(units > first)
		for _ = 1, 10 do
			Loop.Step(0, 2)
		end
		assert.are.equal(100, units)
	end)

	it("cancels once and for all, also from inside the task", function()
		local wow, Loop = start()
		local after = false
		local task = Loop.Spawn(nil, function()
			Loop.await.delay(1)
			after = true
		end)
		task:Cancel()
		task:Cancel() -- again: nothing more
		Loop.Step(wow.time + 5)
		assert.is_false(after)
		local self = Loop.Spawn(nil, function()
			Loop.Current():Cancel()
			after = true -- never reached
		end)
		assert.is_false(after)
		assert.are.equal("done", self.state)
		assert.are.same({}, wow.errors)
	end)

	it("waits for other tasks with await.all", function()
		local wow, Loop = start()
		local a = Loop.Spawn(nil, function()
			Loop.await.delay(1)
		end)
		local b = Loop.Spawn(nil, function()
			Loop.await.frame()
		end)
		local done = false
		Loop.Spawn(nil, function()
			Loop.await.all(a, b)
			done = true
		end)
		Loop.Step(wow.time) -- b ends
		assert.is_false(done)
		Loop.Step(wow.time + 1) -- a ends, then the waiter is ready
		Loop.Step(wow.time + 1)
		assert.is_true(done)
	end)

	it("reports a failing task with its own stack and where it was spawned", function()
		local wow, Loop = start()
		Loop.Spawn(nil, function()
			Loop.await.frame()
			error("boom")
		end)
		Loop.Step(wow.time)
		assert.are.equal(1, #wow.errors)
		local text = tostring(wow.errors[1].message or wow.errors[1])
		assert.is_truthy(text:find("boom", 1, true))
		assert.is_truthy(text:find("spawned at", 1, true))
		assert.is_truthy(text:find("loop_spec", 1, true)) -- its spawn site
	end)

	it("refuses a wait outside a task, naming it", function()
		local _, Loop = start()
		assert.has_error(function()
			Loop.await.frame()
		end, nil)
		local ok, err = pcall(Loop.checkpoint)
		assert.is_false(ok)
		assert.is_truthy(tostring(err):find("checkpoint outside a task", 1, true))
	end)

	it("records through a debug stand-in that makes no garbage per call (no vararg `arg` table)", function()
		local wow = start()
		local kit = wow.addons.OrdaenCore.ns.Core.NewDebug("OrdaenCore")
		for _ = 1, 10 do
			kit:Record("loop", "x %d %d", 1, 2)
		end
		collectgarbage("collect")
		collectgarbage("stop")
		local before = collectgarbage("count")
		for _ = 1, 1000 do
			kit:Record("loop", "x %d %d", 1, 2)
			kit:Logf("x %d", 1)
			kit:Log("a", "b")
			kit:Warnf("x %d", 1)
			kit:Verbosef("x %d", 1)
		end
		local grew = collectgarbage("count") - before
		collectgarbage("restart")
		assert.is_true(grew < 1, "grew " .. grew .. " KB")
	end)

	it("makes no garbage per wait", function()
		local wow, Loop = start()
		Loop.Spawn(nil, function()
			while true do
				Loop.await.frame()
			end
		end)
		for _ = 1, 50 do
			Loop.Step(wow.time)
		end
		collectgarbage("collect")
		collectgarbage("stop")
		local before = collectgarbage("count")
		for _ = 1, 1000 do
			Loop.Step(wow.time)
		end
		local grew = collectgarbage("count") - before
		collectgarbage("restart")
		assert.is_true(grew < 4, "grew " .. grew .. " KB over 1000 frames") -- a few stray bytes of the spec itself
	end)
end)
