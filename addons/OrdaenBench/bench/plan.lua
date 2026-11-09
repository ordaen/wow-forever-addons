-- The bench's plan. One /obench (one per /reload) runs:
-- 1. a cold block: opening the large grid on every side while the session is fresh (the framework's pools empty,
--    the hand sides' frames never made), measured;
-- 2. the whole plan once untracked, so one-time costs (fonts, first textures, Blizzard code running for the first
--    time) land outside the numbers;
-- 3. the whole plan again, measured.
-- Every scenario runs on the framework, on the framework with a stub backend (framework-engine: the engine alone,
-- where something is drawn), by hand at its best (baseline/) and, where it differs, as a typical addon writes it
-- (typical/). Each block starts with an idle series (the frame to read its frame times against) and notes the order
-- its sides ran in, which rotates with each round.
-- `bench` gives: flush, Show(scene) (switch and flush), Set(scene) (switch, no flush), refs, Swap(toStub).
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
local STEADY = 300 -- frames of a grid on screen with nothing changing (only a long series shows drawing cost)
local IDLE = 60 -- frames of each block's idle series
local REPEATS = 60 -- repeats of each one-off change
local HEAVY = 20 -- repeats of make, close and remount (each needs an untimed frame to prepare)
local FW, FW_ITEMS, FW_ENGINE = "framework", "framework-itemsRead", "framework-engine"
local BEST, TYPICAL = "baseline", "typical"

local Plan = {}

local function Nothing() end

--- The steps of one /obench.
---@param bench table
---@param round integer rotates which side of each block goes first
---@param tracked BenchMeasure records the numbers
---@param silent BenchMeasure records nothing (the warm-up pass)
function Plan.Steps(bench, round, tracked, silent)
	local flush, Show, Set, refs = bench.flush, bench.Show, bench.Set, bench.refs
	local steps = {}
	local function add(step)
		steps[#steps + 1] = step
	end
	local measure -- the pass's measure: tracked for the cold block, silent for the warm-up, tracked again

	local mark = {}
	local function Mark(name)
		return measure:Do(function()
			mark[name] = counters[name]
		end)
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

	--- A block: its idle series, then its sides in this round's order (a side: { impl, add = fn }).
	local function Block(scenario, size, sides)
		add(measure:Series(scenario, size, "-", "idle", IDLE, Nothing))
		local n, order, names = #sides, {}, {}
		for k = 0, n - 1 do
			order[k + 1] = sides[(round + k) % n + 1]
			names[k + 1] = order[k + 1].impl
		end
		local note, m = "order|" .. scenario .. "|" .. size .. "|" .. table.concat(names, ","), measure
		add(m:Do(function()
			m:Note(note)
		end))
		for k = 1, n do
			order[k].add()
		end
	end

	--- A framework-engine side: the stub backend swapped in before it, the real one back after.
	local function UnderStub(addSteps)
		return function()
			add(measure:Do(function()
				bench.Swap(true)
			end))
			addSteps()
			add(measure:Do(function()
				bench.Swap(false)
			end))
		end
	end

	--- Make, measured repeatedly: unmount untimed, then mount timed (the scene stays mounted after).
	local function FwMake(scenario, size, impl, scene)
		add(measure:Series(scenario, size, impl, "make (pool warm)", HEAVY, function()
			Show(scene)
		end, { prepare = function()
			Show("none")
		end }))
	end
	--- Close, measured repeatedly: mount untimed, then unmount timed (unmounted after).
	local function FwClose(scenario, size, impl, scene)
		add(measure:Series(scenario, size, impl, "close (unmount)", HEAVY, function()
			Show("none")
		end, { prepare = function()
			Show(scene)
		end }))
	end
	--- A hand side's close: show untimed, then hide timed (hidden after).
	local function HandClose(scenario, size, impl, ShowIt, HideIt)
		add(measure:Series(scenario, size, impl, "close", HEAVY, HideIt, { prepare = ShowIt }))
	end

	local texts = {}
	--- The framework drew `count` counts, each base + its index (first, middle, last checked).
	local function ShowsCounts(count, base)
		return function()
			local n = OrdaenCore._ScreenTexts(texts)
			if n ~= count then
				return false, n .. " texts on screen, not " .. count
			end
			for _, i in ipairs({ 1, math.floor(n / 2), n }) do
				if texts[i] ~= tostring(base + i) then
					return false, "cell " .. i .. " shows " .. tostring(texts[i])
				end
			end
			return true
		end
	end

	local function Pass()
		-- signals: many values, sums, watches
		for _, size in ipairs({ "small", "large" }) do
			local scene, writes = "signals-" .. size, size == "small" and 50 or 500
			local metric = writes .. " writes/frame"
			Block("signals", size, {
				{ impl = FW, add = function()
					FwMake("signals", size, FW, scene)
					add(measure:Series("signals", size, FW, metric, FRAMES, function(frame)
						local ref = refs[scene]
						for i = 1, writes do
							ref.Write(frame * writes + i * 37)
						end
						flush()
					end))
					FwClose("signals", size, FW, scene)
				end },
				{ impl = BEST, add = function()
					add(measure:Series("signals", size, BEST, "make", 1, function()
						Best.signals.Make(size)
					end, { kept = true }))
					add(measure:Series("signals", size, BEST, metric, FRAMES, function(frame)
						for i = 1, writes do
							Best.signals.Write(frame * writes + i * 37)
						end
						Best.signals.Flush()
					end))
				end },
				{ impl = TYPICAL, add = function()
					add(measure:Series("signals", size, TYPICAL, "make", 1, function()
						Typical.signals.Make(size)
					end, { kept = true }))
					add(measure:Series("signals", size, TYPICAL, metric, FRAMES, function(frame)
						for i = 1, writes do
							Typical.signals.Write(frame * writes + i * 37)
						end
					end))
				end },
			})
		end

		-- coalesce: 1000 writes of one value a frame, 100 watches: each should run once a frame
		Block("coalesce", "-", {
			{ impl = FW, add = function()
				FwMake("coalesce", "-", FW, "coalesce")
				add(Mark("runs"))
				add(measure:Series("coalesce", "-", FW, "1000 writes/frame", FRAMES, function()
					refs.coalesce.WriteMany(1000)
					flush()
				end, { verify = Grew("runs", 100 * FRAMES) }))
				FwClose("coalesce", "-", FW, "coalesce")
			end },
			{ impl = BEST, add = function()
				add(Mark("runs"))
				add(measure:Series("coalesce", "-", BEST, "1000 writes/frame", FRAMES, function()
					Best.coalesce.WriteMany(1000)
					Best.coalesce.Flush()
				end, { verify = Grew("runs", 100 * FRAMES) }))
			end },
			{ impl = TYPICAL, add = function()
				add(measure:Series("coalesce", "-", TYPICAL, "1000 writes/frame", FRAMES, function()
					Typical.coalesce.WriteMany(1000)
				end))
			end },
		})

		-- chain, diamond: derived values, glitch-free
		for _, name in ipairs({ "chain", "diamond" }) do
			Block(name, "-", {
				{ impl = FW, add = function()
					FwMake(name, "-", FW, name)
					add(Mark("runs"))
					add(Mark("violations"))
					add(measure:Series(name, "-", FW, "1 change/frame", FRAMES, function()
						refs[name].Bump()
						flush()
					end, { verify = function()
						local ok, why = Grew("runs", FRAMES)()
						if not ok then
							return false, "watch runs: " .. why
						end
						return NoViolations()
					end }))
					FwClose(name, "-", FW, name)
				end },
				{ impl = BEST, add = function()
					add(Mark("violations"))
					add(measure:Series(name, "-", BEST, "1 change/frame", FRAMES, Best[name].Bump,
						{ verify = NoViolations }))
				end },
			})
		end

		-- fanout: one value, 5000 watches
		Block("fanout", "-", {
			{ impl = FW, add = function()
				FwMake("fanout", "-", FW, "fanout")
				add(measure:Series("fanout", "-", FW, "1 change/frame", FRAMES, function()
					refs.fanout.Bump()
					flush()
				end))
				FwClose("fanout", "-", FW, "fanout")
			end },
			{ impl = BEST, add = function()
				add(measure:Series("fanout", "-", BEST, "make", 1, Best.fanout.Make, { kept = true }))
				add(measure:Series("fanout", "-", BEST, "1 change/frame", FRAMES, Best.fanout.Bump))
			end },
		})

		-- cascade: 50 watches each writing the next value
		Block("cascade", "-", {
			{ impl = FW, add = function()
				FwMake("cascade", "-", FW, "cascade")
				add(measure:Series("cascade", "-", FW, "1 change/frame", FRAMES, function()
					refs.cascade.Bump()
					flush()
				end, { verify = function()
					return refs.cascade.Settled(), "the last value lags the first"
				end }))
				FwClose("cascade", "-", FW, "cascade")
			end },
			{ impl = BEST, add = function()
				add(measure:Series("cascade", "-", BEST, "1 change/frame", FRAMES, Best.cascade.Bump, {
					verify = function()
						return Best.cascade.Settled(), "the last value lags the first"
					end,
				}))
			end },
		})

		-- grid: item buttons
		for _, size in ipairs({ "small", "large" }) do
			local scene = "grid-" .. size
			local count = size == "small" and 200 or 1000
			local function Framework(impl, mounted, engine)
				return function()
					FwMake("grid", size, impl, mounted)
					if not engine then
						add(measure:Series("grid", size, impl, "steady (shown, unchanged)", STEADY, Nothing))
					end
					add(measure:Series("grid", size, impl, "one changed", REPEATS, function(i)
						refs[mounted].SetOne(i, i)
						flush()
					end))
					add(measure:Series("grid", size, impl, "all changed", REPEATS, function(i)
						local ref = refs[mounted]
						for k = 1, count do
							ref.SetOne(k, i + k)
						end
						flush()
					end, { verify = not engine and ShowsCounts(count, REPEATS) or nil }))
					FwClose("grid", size, impl, mounted)
					add(measure:Series("grid", size, impl, "open+close (remount)", HEAVY, function()
						Show(mounted)
						Show("none")
					end))
					if not engine then
						add(Mark("mounts"))
						add(measure:Series("grid", size, impl, "race: open+close in one frame", 1, function()
							Set(mounted)
							Set("none")
							flush()
						end, { verify = Grew("mounts", 0) }))
						add(measure:Check("grid", size, impl, "race: handle after close", function()
							return pcall(refs[mounted].SetOne, 1, 1)
						end))
					end
				end
			end
			local function ByHand(impl, Grid)
				return function()
					add(measure:Series("grid", size, impl, "make", 1, function()
						Grid.Make(size)
					end, { kept = true }))
					add(measure:Series("grid", size, impl, "steady (shown, unchanged)", STEADY, Nothing))
					add(measure:Series("grid", size, impl, "one changed", REPEATS, function(i)
						Grid.SetOne(size, i, i)
					end))
					add(measure:Series("grid", size, impl, "all changed", REPEATS, function(i)
						Grid.SetAll(size, i)
					end, { verify = function()
						return Grid.Verify(size, REPEATS)
					end }))
					HandClose("grid", size, impl, function()
						Grid.Show(size)
					end, function()
						Grid.Hide(size)
					end)
					add(measure:Series("grid", size, impl, "open+close", HEAVY, function()
						Grid.Show(size)
						Grid.Hide(size)
					end))
				end
			end
			Block("grid", size, {
				{ impl = FW, add = Framework(FW, scene) },
				{ impl = FW_ITEMS, add = Framework(FW_ITEMS, scene .. "-itemsRead") },
				{ impl = FW_ENGINE, add = UnderStub(Framework(FW_ENGINE, scene, true)) },
				{ impl = BEST, add = ByHand(BEST, Best.grid) },
				{ impl = TYPICAL, add = ByHand(TYPICAL, Typical.grid) },
			})
		end

		-- ticker: texts changed every frame
		for _, size in ipairs({ "small", "large" }) do
			local scene = "ticker-" .. size
			local function Framework(impl)
				return function()
					FwMake("ticker", size, impl, scene)
					add(measure:Series("ticker", size, impl, "all texts/frame", FRAMES, function()
						refs[scene].Tick()
						flush()
					end))
					FwClose("ticker", size, impl, scene)
				end
			end
			local function ByHand(impl, Ticker)
				return function()
					add(measure:Series("ticker", size, impl, "make", 1, function()
						Ticker.Make(size)
					end, { kept = true }))
					add(measure:Series("ticker", size, impl, "all texts/frame", FRAMES, function()
						Ticker.Tick(size)
					end))
					HandClose("ticker", size, impl, function()
						Ticker.Show(size)
					end, function()
						Ticker.Hide(size)
					end)
				end
			end
			Block("ticker", size, {
				{ impl = FW, add = Framework(FW) },
				{ impl = FW_ENGINE, add = UnderStub(Framework(FW_ENGINE)) },
				{ impl = BEST, add = ByHand(BEST, Best.ticker) },
				{ impl = TYPICAL, add = ByHand(TYPICAL, Typical.ticker) },
			})
		end

		-- reorder: a keyed list changing order
		local OPERATIONS = { "Reverse", "Rotate", "InsertFront", "RemoveMiddle", "Shuffle" }
		local function ReorderFramework(impl, engine)
			return function()
				FwMake("reorder", "-", impl, "reorder")
				for _, operation in ipairs(OPERATIONS) do
					local verify
					if operation == "Shuffle" and not engine then
						verify = function()
							local ids = refs.reorder.Ids()
							local n = OrdaenCore._ScreenTexts(texts)
							if n ~= #ids then
								return false, n .. " rows on screen, not " .. #ids
							end
							for i = 1, n do
								if texts[i] ~= "row " .. ids[i] then
									return false, "row " .. i .. " shows " .. tostring(texts[i])
								end
							end
							return true
						end
					end
					add(measure:Series("reorder", "-", impl, operation, REPEATS, function()
						refs.reorder[operation]()
						flush()
					end, { verify = verify }))
				end
				FwClose("reorder", "-", impl, "reorder")
			end
		end
		local function ReorderByHand(impl, Reorder)
			return function()
				add(measure:Series("reorder", "-", impl, "make", 1, Reorder.Make, { kept = true }))
				for _, operation in ipairs(OPERATIONS) do
					add(measure:Series("reorder", "-", impl, operation, REPEATS, Reorder[operation]))
				end
				HandClose("reorder", "-", impl, Reorder.Show, Reorder.Hide)
			end
		end
		Block("reorder", "-", {
			{ impl = FW, add = ReorderFramework(FW) },
			{ impl = FW_ENGINE, add = UnderStub(ReorderFramework(FW_ENGINE, true)) },
			{ impl = BEST, add = ReorderByHand(BEST, Best.reorder) },
			{ impl = TYPICAL, add = ReorderByHand(TYPICAL, Typical.reorder) },
		})

		-- deep: 100 nested components
		local function DeepFramework(impl, engine)
			return function()
				FwMake("deep", "-", impl, "deep")
				add(Mark("renders"))
				add(measure:Series("deep", "-", impl, "leaf signal changed", REPEATS, function(i)
					refs.deep.SetSource(i)
					flush()
				end, { verify = Grew("renders", REPEATS) }))
				add(measure:Series("deep", "-", impl, "value through 100 levels", REPEATS, function(i)
					refs.deep.SetValue(i)
					flush()
				end, { verify = function()
					return counters.leafValue == REPEATS, "the leaf shows " .. tostring(counters.leafValue)
				end }))
				if engine then
					FwClose("deep", "-", impl, "deep")
				else
					add(Mark("renders"))
					add(measure:Series("deep", "-", impl, "race: change + close in one frame", 1, function()
						refs.deep.SetSource(-1)
						Set("none")
						flush()
					end, { verify = Grew("renders", 0) }))
				end
			end
		end
		Block("deep", "-", {
			{ impl = FW, add = DeepFramework(FW) },
			{ impl = FW_ENGINE, add = UnderStub(DeepFramework(FW_ENGINE, true)) },
			{ impl = BEST, add = function()
				add(measure:Series("deep", "-", BEST, "make", 1, Best.deep.Make, { kept = true }))
				add(measure:Series("deep", "-", BEST, "leaf signal changed", REPEATS, Best.deep.SetSource))
				add(measure:Series("deep", "-", BEST, "value through 100 levels", REPEATS, Best.deep.SetValue))
				HandClose("deep", "-", BEST, Best.deep.Show, Best.deep.Hide)
			end },
		})

		add(measure:Series("idle", "-", "-", "idle (end)", IDLE, Nothing))
	end

	-- 1. the cold block, measured while the session is fresh
	measure = tracked
	Block("grid", "large", {
		{ impl = FW, add = function()
			add(measure:Series("grid", "large", FW, "make (cold)", 1, function()
				Show("grid-large")
			end, { kept = true }))
			add(measure:Do(function()
				Show("none")
			end))
		end },
		{ impl = BEST, add = function()
			add(measure:Series("grid", "large", BEST, "make (cold)", 1, function()
				Best.grid.Make("large")
			end, { kept = true }))
			add(measure:Do(function()
				Best.grid.Hide("large")
			end))
		end },
		{ impl = TYPICAL, add = function()
			add(measure:Series("grid", "large", TYPICAL, "make (cold)", 1, function()
				Typical.grid.Make("large")
			end, { kept = true }))
			add(measure:Do(function()
				Typical.grid.Hide("large")
			end))
		end },
	})
	-- 2. the warm-up pass, untracked
	measure = silent
	Pass()
	-- 3. the measured pass
	measure = tracked
	Pass()
	return steps
end

return Plan
