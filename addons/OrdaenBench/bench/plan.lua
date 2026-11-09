-- The bench's plan: every scenario on the framework, then by hand, with the checks that tell a correct run.
-- `bench` gives: measure (driver), Show(scene) (switch and flush), Set(scene) (switch, no flush), flush, refs.
local counters = import("bench/counters")
local Signals = import("baseline/signals")
local Coalesce = import("baseline/coalesce")
local Chain = import("baseline/chain")
local Diamond = import("baseline/diamond")
local Fanout = import("baseline/fanout")
local Cascade = import("baseline/cascade")
local Grid = import("baseline/grid")
local Ticker = import("baseline/ticker")
local Reorder = import("baseline/reorder")
local Deep = import("baseline/deep")

local FRAMES = 120 -- frames per steady-state series
local REPEATS = 20 -- repeats of each one-off change
local FW, BY_HAND = "framework", "baseline"

local Plan = {}

function Plan.Steps(bench)
	local measure, flush, Show, Set, refs = bench.measure, bench.flush, bench.Show, bench.Set, bench.refs
	local steps = {}
	local function add(step)
		steps[#steps + 1] = step
	end
	local mark = {}
	local function Mark(name)
		return function()
			mark[name] = counters[name]
			return true
		end
	end
	local function Grew(name, by)
		return function()
			local grew = counters[name] - mark[name]
			return grew == by, "expected " .. by .. ", got " .. grew
		end
	end
	local function NoViolations()
		return counters.violations == mark.violations, (counters.violations - mark.violations) .. " stale reads"
	end

	-- signals: many values, sums, watches
	for _, size in ipairs({ "small", "large" }) do
		local scene, writes = "signals-" .. size, size == "small" and 50 or 500
		add(measure:Once("signals", size, FW, "mount", function()
			Show(scene)
		end))
		add(measure:Series("signals", size, FW, writes .. " writes/frame", FRAMES, function(frame)
			local ref = refs[scene]
			for i = 1, writes do
				ref.Write(frame * writes + i * 37)
			end
			flush()
		end))
		add(measure:Once("signals", size, FW, "unmount", function()
			Show("none")
		end))
		add(measure:Once("signals", size, BY_HAND, "make", function()
			Signals.Make(size)
		end))
		add(measure:Series("signals", size, BY_HAND, writes .. " writes/frame", FRAMES, function(frame)
			for i = 1, writes do
				Signals.Write(frame * writes + i * 37)
			end
			Signals.Flush()
		end))
	end

	-- coalesce: 1000 writes of one value a frame, 100 watches: each runs once a frame
	add(measure:Once("coalesce", "-", FW, "mount", function()
		Show("coalesce")
	end))
	add(Mark("runs"))
	add(measure:Series("coalesce", "-", FW, "1000 writes/frame", FRAMES, function()
		refs.coalesce.WriteMany(1000)
		flush()
	end, Grew("runs", 100 * FRAMES)))
	add(measure:Once("coalesce", "-", FW, "unmount", function()
		Show("none")
	end))
	add(Mark("runs"))
	add(measure:Series("coalesce", "-", BY_HAND, "1000 writes/frame", FRAMES, function()
		Coalesce.WriteMany(1000)
		Coalesce.Flush()
	end, Grew("runs", 100 * FRAMES)))

	-- chain, diamond: derived values, glitch-free
	for _, name in ipairs({ "chain", "diamond" }) do
		local byHand = name == "chain" and Chain or Diamond
		add(measure:Once(name, "-", FW, "mount", function()
			Show(name)
		end))
		add(Mark("runs"))
		add(Mark("violations"))
		add(measure:Series(name, "-", FW, "1 change/frame", FRAMES, function()
			refs[name].Bump()
			flush()
		end, function()
			local ok, why = Grew("runs", FRAMES)()
			if not ok then
				return false, "watch runs: " .. why
			end
			return NoViolations()
		end))
		add(measure:Once(name, "-", FW, "unmount", function()
			Show("none")
		end))
		add(Mark("runs"))
		add(Mark("violations"))
		add(measure:Series(name, "-", BY_HAND, "1 change/frame", FRAMES, function()
			byHand.Bump()
		end, NoViolations))
	end

	-- fanout: one value, 5000 watches
	add(measure:Once("fanout", "-", FW, "mount", function()
		Show("fanout")
	end))
	add(measure:Series("fanout", "-", FW, "1 change/frame", FRAMES, function()
		refs.fanout.Bump()
		flush()
	end))
	add(measure:Once("fanout", "-", FW, "unmount", function()
		Show("none")
	end))
	add(measure:Once("fanout", "-", BY_HAND, "make", Fanout.Make))
	add(measure:Series("fanout", "-", BY_HAND, "1 change/frame", FRAMES, Fanout.Bump))

	-- cascade: 50 watches each writing the next value
	add(measure:Once("cascade", "-", FW, "mount", function()
		Show("cascade")
	end))
	add(measure:Series("cascade", "-", FW, "1 change/frame", FRAMES, function()
		refs.cascade.Bump()
		flush()
	end, function()
		return refs.cascade.Settled(), "the last value lags the first"
	end))
	add(measure:Once("cascade", "-", FW, "unmount", function()
		Show("none")
	end))
	add(measure:Series("cascade", "-", BY_HAND, "1 change/frame", FRAMES, Cascade.Bump, function()
		return Cascade.Settled(), "the last value lags the first"
	end))

	-- grid: item buttons
	for _, size in ipairs({ "small", "large" }) do
		local scene = "grid-" .. size
		add(measure:Once("grid", size, FW, "open", function()
			Show(scene)
		end))
		add(measure:Series("grid", size, FW, "one changed", REPEATS, function(i)
			refs[scene].SetOne(i, i)
			flush()
		end))
		add(measure:Series("grid", size, FW, "all changed", REPEATS, function(i)
			local ref = refs[scene]
			for k = 1, ref.Count() do
				ref.SetOne(k, i + k)
			end
			flush()
		end))
		add(measure:Once("grid", size, FW, "close", function()
			Show("none")
		end))
		add(measure:Series("grid", size, FW, "open+close", REPEATS, function()
			Show(scene)
			Show("none")
		end))
		add(Mark("mounts"))
		add(measure:Once("grid", size, FW, "race: open+close in one frame", function()
			Set(scene)
			Set("none")
			flush()
			return Grew("mounts", 0)()
		end))
		add(measure:Check("grid", size, FW, "race: handle after close", function()
			local ok, err = pcall(refs[scene].SetOne, 1, 1)
			return ok, err
		end))
		add(measure:Once("grid", size, BY_HAND, "open (make)", function()
			Grid.Make(size)
		end))
		add(measure:Series("grid", size, BY_HAND, "one changed", REPEATS, function(i)
			Grid.SetOne(size, i, i)
		end))
		add(measure:Series("grid", size, BY_HAND, "all changed", REPEATS, function(i)
			Grid.SetAll(size, i)
		end))
		add(measure:Once("grid", size, BY_HAND, "close", function()
			Grid.Hide(size)
		end))
		add(measure:Series("grid", size, BY_HAND, "open+close", REPEATS, function()
			Grid.Show(size)
			Grid.Hide(size)
		end))
	end

	-- ticker: texts changed every frame
	for _, size in ipairs({ "small", "large" }) do
		local scene = "ticker-" .. size
		add(measure:Once("ticker", size, FW, "open", function()
			Show(scene)
		end))
		add(measure:Series("ticker", size, FW, "all texts/frame", FRAMES, function()
			refs[scene].Tick()
			flush()
		end))
		add(measure:Once("ticker", size, FW, "close", function()
			Show("none")
		end))
		add(measure:Once("ticker", size, BY_HAND, "open (make)", function()
			Ticker.Make(size)
		end))
		add(measure:Series("ticker", size, BY_HAND, "all texts/frame", FRAMES, function()
			Ticker.Tick(size)
		end))
		add(measure:Once("ticker", size, BY_HAND, "close", function()
			Ticker.Hide(size)
		end))
	end

	-- reorder: a keyed list changing order
	local OPERATIONS = { "Reverse", "Rotate", "InsertFront", "RemoveMiddle", "Shuffle" }
	add(measure:Once("reorder", "-", FW, "open", function()
		Show("reorder")
	end))
	for _, operation in ipairs(OPERATIONS) do
		add(measure:Series("reorder", "-", FW, operation, REPEATS, function()
			refs.reorder[operation]()
			flush()
		end))
	end
	add(measure:Once("reorder", "-", FW, "close", function()
		Show("none")
	end))
	add(measure:Once("reorder", "-", BY_HAND, "open (make)", Reorder.Make))
	for _, operation in ipairs(OPERATIONS) do
		add(measure:Series("reorder", "-", BY_HAND, operation, REPEATS, Reorder[operation]))
	end
	add(measure:Once("reorder", "-", BY_HAND, "close", Reorder.Hide))

	-- deep: 100 nested components
	add(measure:Once("deep", "-", FW, "open", function()
		Show("deep")
	end))
	add(Mark("renders"))
	add(measure:Series("deep", "-", FW, "leaf signal changed", REPEATS, function(i)
		refs.deep.SetSource(i)
		flush()
	end, Grew("renders", REPEATS)))
	add(measure:Series("deep", "-", FW, "value through 100 levels", REPEATS, function(i)
		refs.deep.SetValue(i)
		flush()
	end))
	add(Mark("renders"))
	add(measure:Once("deep", "-", FW, "race: change + close in one frame", function()
		refs.deep.SetSource(-1)
		Set("none")
		flush()
		return Grew("renders", 0)()
	end))
	add(measure:Once("deep", "-", BY_HAND, "open (make)", Deep.Make))
	add(measure:Series("deep", "-", BY_HAND, "leaf signal changed", REPEATS, Deep.SetSource))
	add(measure:Series("deep", "-", BY_HAND, "value through 100 levels", REPEATS, Deep.SetValue))
	add(measure:Once("deep", "-", BY_HAND, "close", Deep.Hide))
	return steps
end

return Plan
