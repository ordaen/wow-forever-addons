-- The bench's plan: every scenario on the framework, by hand at its best (baseline/) and, where it differs, as a
-- typical addon writes it (typical/), with the checks that tell a correct run. The sides of a scenario run in an
-- order that rotates with each round, so none always goes first.
-- `bench` gives: measure (driver), Show(scene) (switch and flush), Set(scene) (switch, no flush), flush, refs.
local counters = import("bench/counters")
local Best = {
	signals = import("baseline/signals"), coalesce = import("baseline/coalesce"), chain = import("baseline/chain"),
	diamond = import("baseline/diamond"), fanout = import("baseline/fanout"), cascade = import("baseline/cascade"),
	grid = import("baseline/grid"), ticker = import("baseline/ticker"), reorder = import("baseline/reorder"),
	deep = import("baseline/deep"),
}
local Typical = {
	signals = import("typical/signals"), coalesce = import("typical/coalesce"), grid = import("typical/grid"),
	ticker = import("typical/ticker"), reorder = import("typical/reorder"),
}

local FRAMES = 120 -- frames per steady-state series
local REPEATS = 20 -- repeats of each one-off change
local FW, BEST, TYPICAL = "framework", "baseline", "typical"

local Plan = {}

---@param round integer rotates which side of each scenario goes first
function Plan.Steps(bench, round)
	local measure, flush, Show, Set, refs = bench.measure, bench.flush, bench.Show, bench.Set, bench.refs
	local steps = {}
	local function add(step)
		steps[#steps + 1] = step
	end
	--- Each side is a function adding its steps; they run in the round's order.
	local function Sides(sides)
		local n = #sides
		for i = 0, n - 1 do
			sides[(round + i) % n + 1]()
		end
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
		local metric = writes .. " writes/frame"
		Sides({
			function()
				add(measure:Once("signals", size, FW, "make", function()
					Show(scene)
				end))
				add(measure:Series("signals", size, FW, metric, FRAMES, function(frame)
					local ref = refs[scene]
					for i = 1, writes do
						ref.Write(frame * writes + i * 37)
					end
					flush()
				end))
				add(measure:Once("signals", size, FW, "unmount", function()
					Show("none")
				end))
			end,
			function()
				add(measure:Once("signals", size, BEST, "make", function()
					Best.signals.Make(size)
				end))
				add(measure:Series("signals", size, BEST, metric, FRAMES, function(frame)
					for i = 1, writes do
						Best.signals.Write(frame * writes + i * 37)
					end
					Best.signals.Flush()
				end))
			end,
			function()
				add(measure:Once("signals", size, TYPICAL, "make", function()
					Typical.signals.Make(size)
				end))
				add(measure:Series("signals", size, TYPICAL, metric, FRAMES, function(frame)
					for i = 1, writes do
						Typical.signals.Write(frame * writes + i * 37)
					end
				end))
			end,
		})
	end

	-- coalesce: 1000 writes of one value a frame, 100 watches: each should run once a frame
	Sides({
		function()
			add(measure:Once("coalesce", "-", FW, "make", function()
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
		end,
		function()
			add(Mark("runs"))
			add(measure:Series("coalesce", "-", BEST, "1000 writes/frame", FRAMES, function()
				Best.coalesce.WriteMany(1000)
				Best.coalesce.Flush()
			end, Grew("runs", 100 * FRAMES)))
		end,
		function()
			add(measure:Series("coalesce", "-", TYPICAL, "1000 writes/frame", FRAMES, function()
				Typical.coalesce.WriteMany(1000)
			end))
		end,
	})

	-- chain, diamond: derived values, glitch-free
	for _, name in ipairs({ "chain", "diamond" }) do
		Sides({
			function()
				add(measure:Once(name, "-", FW, "make", function()
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
			end,
			function()
				add(Mark("violations"))
				add(measure:Series(name, "-", BEST, "1 change/frame", FRAMES, Best[name].Bump, NoViolations))
			end,
		})
	end

	-- fanout: one value, 5000 watches
	Sides({
		function()
			add(measure:Once("fanout", "-", FW, "make", function()
				Show("fanout")
			end))
			add(measure:Series("fanout", "-", FW, "1 change/frame", FRAMES, function()
				refs.fanout.Bump()
				flush()
			end))
			add(measure:Once("fanout", "-", FW, "unmount", function()
				Show("none")
			end))
		end,
		function()
			add(measure:Once("fanout", "-", BEST, "make", Best.fanout.Make))
			add(measure:Series("fanout", "-", BEST, "1 change/frame", FRAMES, Best.fanout.Bump))
		end,
	})

	-- cascade: 50 watches each writing the next value
	Sides({
		function()
			add(measure:Once("cascade", "-", FW, "make", function()
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
		end,
		function()
			add(measure:Series("cascade", "-", BEST, "1 change/frame", FRAMES, Best.cascade.Bump, function()
				return Best.cascade.Settled(), "the last value lags the first"
			end))
		end,
	})

	-- grid: item buttons
	for _, size in ipairs({ "small", "large" }) do
		local scene = "grid-" .. size
		local function ByHand(impl, Grid)
			return function()
				add(measure:Once("grid", size, impl, "make", function()
					Grid.Make(size)
				end))
				add(measure:Series("grid", size, impl, "one changed", REPEATS, function(i)
					Grid.SetOne(size, i, i)
				end))
				add(measure:Series("grid", size, impl, "all changed", REPEATS, function(i)
					Grid.SetAll(size, i)
				end))
				add(measure:Once("grid", size, impl, "close", function()
					Grid.Hide(size)
				end))
				add(measure:Series("grid", size, impl, "open+close", REPEATS, function()
					Grid.Show(size)
					Grid.Hide(size)
				end))
			end
		end
		Sides({
			function()
				add(measure:Once("grid", size, FW, "make", function()
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
					return pcall(refs[scene].SetOne, 1, 1)
				end))
			end,
			ByHand(BEST, Best.grid),
			ByHand(TYPICAL, Typical.grid),
		})
	end

	-- ticker: texts changed every frame
	for _, size in ipairs({ "small", "large" }) do
		local scene = "ticker-" .. size
		local function ByHand(impl, Ticker)
			return function()
				add(measure:Once("ticker", size, impl, "make", function()
					Ticker.Make(size)
				end))
				add(measure:Series("ticker", size, impl, "all texts/frame", FRAMES, function()
					Ticker.Tick(size)
				end))
				add(measure:Once("ticker", size, impl, "close", function()
					Ticker.Hide(size)
				end))
			end
		end
		Sides({
			function()
				add(measure:Once("ticker", size, FW, "make", function()
					Show(scene)
				end))
				add(measure:Series("ticker", size, FW, "all texts/frame", FRAMES, function()
					refs[scene].Tick()
					flush()
				end))
				add(measure:Once("ticker", size, FW, "close", function()
					Show("none")
				end))
			end,
			ByHand(BEST, Best.ticker),
			ByHand(TYPICAL, Typical.ticker),
		})
	end

	-- reorder: a keyed list changing order
	local OPERATIONS = { "Reverse", "Rotate", "InsertFront", "RemoveMiddle", "Shuffle" }
	local function ReorderByHand(impl, Reorder)
		return function()
			add(measure:Once("reorder", "-", impl, "make", Reorder.Make))
			for _, operation in ipairs(OPERATIONS) do
				add(measure:Series("reorder", "-", impl, operation, REPEATS, Reorder[operation]))
			end
			add(measure:Once("reorder", "-", impl, "close", Reorder.Hide))
		end
	end
	Sides({
		function()
			add(measure:Once("reorder", "-", FW, "make", function()
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
		end,
		ReorderByHand(BEST, Best.reorder),
		ReorderByHand(TYPICAL, Typical.reorder),
	})

	-- deep: 100 nested components
	Sides({
		function()
			add(measure:Once("deep", "-", FW, "make", function()
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
		end,
		function()
			add(measure:Once("deep", "-", BEST, "make", Best.deep.Make))
			add(measure:Series("deep", "-", BEST, "leaf signal changed", REPEATS, Best.deep.SetSource))
			add(measure:Series("deep", "-", BEST, "value through 100 levels", REPEATS, Best.deep.SetValue))
			add(measure:Once("deep", "-", BEST, "close", Best.deep.Hide))
		end,
	})
	return steps
end

return Plan
