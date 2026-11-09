-- The bench's plan. One /obench (one per /reload) runs:
-- 0. the client's one-time costs paid untimed (a frame, a texture, the bench font);
-- 1. a cold block: opening the large grid on every side while the session is fresh (the framework's pools empty,
--    the hand sides' frames never made), measured;
-- 2. the whole plan once untracked, so one-time costs (fonts, first textures, Blizzard code running for the first
--    time) land outside the numbers;
-- 3. the whole plan again, measured.
-- `/obench check` runs the same plan with a few calls per series: a quick run for the checks, never a round.
-- Every scenario runs on the framework, on the framework with a stub backend (framework-engine: the engine alone,
-- where something is drawn), written naively (framework-naive: new tables every call, as code reads without the
-- build's hoisting; grid and ticker), by hand at its best (baseline/) and, where it differs, as a typical addon writes
-- it (typical/). Each block starts with a short spin (the CPU at full clock) and an idle series (the frame to read its
-- frame times against), runs its sides in a fixed order (the same in every round, so rounds compare like with like)
-- and ends by comparing what every side ended on with the baseline (bench/screen.lua: the texts and where they sit,
-- textures where the scenario draws shapes; checksums where nothing is drawn). Actions follow seeded random sequences
-- (bench/random.lua): the same on every side and in every round.
-- `bench` gives: flush, Show(scene) (switch and flush), Set(scene) (switch, no flush), refs, Swap(toStub), StubCount.
local counters = import("bench/counters")
local FONT = import("bench/font")
local Random = import("bench/random")
local Screen = import("bench/screen")
local Schedulers = import("bench/schedulers")
local Best = {
	signals = import("baseline/signals"), coalesce = import("baseline/coalesce"), chain = import("baseline/chain"),
	diamond = import("baseline/diamond"), fanout = import("baseline/fanout"), cascade = import("baseline/cascade"),
	grid = import("baseline/grid"), ticker = import("baseline/ticker"), reorder = import("baseline/reorder"),
	deep = import("baseline/deep"), resize = import("baseline/resize"), columns = import("baseline/columns"),
	grow = import("baseline/grow"), rows = import("baseline/rows"), tooltip = import("baseline/tooltip"),
	filter = import("baseline/filter"), drag = import("baseline/drag"), bars = import("baseline/bars"),
	sections = import("baseline/sections"), events = import("baseline/events"),
	hover = import("baseline/hover"),
}
local Typical = {
	signals = import("typical/signals"), coalesce = import("typical/coalesce"), grid = import("typical/grid"),
	ticker = import("typical/ticker"), reorder = import("typical/reorder"),
}

-- calls per series: a round, and a check run (`/obench check`: enough calls to pass the warm-up, then a few)
local FRAMES, STEADY, IDLE, REPEATS, HEAVY
local COUNTS = {
	round = { frames = 120, steady = 300, idle = 60, repeats = 60, heavy = 20 },
	check = { frames = 8, steady = 8, idle = 8, repeats = 8, heavy = 7 },
}
local SPIN = 200 -- ms of untimed work before each block: the CPU at full clock when its idle series and sides run
local FW, FW_ITEMS, FW_ENGINE, FW_NAIVE = "framework", "framework-itemsRead", "framework-engine", "framework-naive"
local BEST, TYPICAL = "baseline", "typical"

local Plan = {}

local function Nothing() end

local function Spin()
	local stop = debugprofilestop() + SPIN
	local x = 0
	while debugprofilestop() < stop do
		x = x + 1
	end
	return x
end

--- The steps of one /obench.
---@param bench table
---@param tracked BenchMeasure records the numbers
---@param silent BenchMeasure records nothing (the warm-up pass)
---@param progress fun(line: string) shows what runs now
---@param mode "round"|"check"
function Plan.Steps(bench, tracked, silent, progress, mode)
	local counts = COUNTS[mode]
	FRAMES, STEADY, IDLE, REPEATS, HEAVY = counts.frames, counts.steady, counts.idle, counts.repeats, counts.heavy
	local flush, Show, Set, refs = bench.flush, bench.Show, bench.Set, bench.refs
	local steps = {}
	local function add(step)
		steps[#steps + 1] = step
	end
	local measure -- the pass's measure: tracked for the cold block, silent for the warm-up, tracked again
	local passName -- what the progress line calls the pass
	local blocks, totals = 0, {}

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

	-- What each side ended on, per measured series (Seen), compared with the baseline's when the block ends.
	local seen, seenKeys = {}, {}
	local COMPARED = { FW, FW_ITEMS, FW_NAIVE, TYPICAL }
	local EVENED = { BEST, FW, FW_ITEMS, FW_NAIVE, TYPICAL } -- every side drawing a list spaces its lines evenly

	--- A series' verify that first records what the side ended on: `take()` gives a screen snapshot
	--- (bench/screen.lua) or a checksum. `verify` (optional) is the side's own check.
	local function Seen(metric, impl, take, verify)
		return function()
			if not seen[metric] then
				seen[metric] = {}
				seenKeys[#seenKeys + 1] = metric
			end
			seen[metric][impl] = take()
			if verify then
				return verify()
			end
		end
	end
	--- The framework's screen: the scene's root box frame.
	local function FwScreen(textures)
		return function()
			local node = OrdaenCore._ScreenNode("box")
			return Screen.Of(node and node.frame, textures)
		end
	end
	--- A hand side's screen: its module's Root(size).
	local function HandScreen(module, textures, size)
		return function()
			return Screen.Of(module.Root(size), textures)
		end
	end

	--- A block: a spin and its idle series, then its sides in the order given (the same in every round), then every
	--- side's end state compared with the baseline's (a side: { impl, add = fn }).
	local function Block(scenario, size, sides)
		blocks = blocks + 1
		local number, pass, label = blocks, passName, scenario .. (size ~= "-" and (" " .. size) or "")
		add(function()
			progress(string.format("%s · block %d/%d · %s", pass, number, totals.blocks, label))
			Spin()
			return true
		end)
		add(measure:Series(scenario, size, "-", "idle", IDLE, Nothing))
		local names = {}
		for k = 1, #sides do
			names[k] = sides[k].impl
		end
		local note, m = "order|" .. scenario .. "|" .. size .. "|" .. table.concat(names, ","), measure
		add(m:Do(function()
			m:Note(note)
		end))
		for k = 1, #sides do
			sides[k].add()
		end
		add(function()
			for _, metric in ipairs(seenKeys) do
				local ended = seen[metric]
				local reference = ended[BEST]
				for _, impl in ipairs(COMPARED) do
					local value = ended[impl]
					if value ~= nil then
						local ok, why
						if reference == nil then
							ok, why = false, "no baseline to compare with"
						elseif type(value) == "table" then
							ok, why = Screen.Same(value, reference)
						else
							ok, why = value == reference, tostring(value) .. ", the baseline " .. tostring(reference)
						end
						m:Record(scenario, size, impl, metric .. " (same as baseline)", 0, 0, 0, 0, 0, 1, m:Verdict(ok, why))
					end
				end
				for _, impl in ipairs(EVENED) do
					local value = ended[impl]
					if type(value) == "table" then
						m:Record(scenario, size, impl, metric .. " (even line spacing)", 0, 0, 0, 0, 0, 1,
							m:Verdict(Screen.Even(value)))
					end
				end
				seen[metric] = nil
			end
			for i = #seenKeys, 1, -1 do
				seenKeys[i] = nil
			end
			return true
		end)
	end

	--- A framework-engine side: the stub backend swapped in before it, the real one back after, and a check that
	--- the stub got every node back.
	local function UnderStub(scenario, size, addSteps)
		return function()
			local pooled
			add(measure:Do(function()
				bench.Swap(true)
				pooled = bench.StubCount()
			end))
			addSteps()
			add(measure:Check(scenario, size, FW_ENGINE, "stub: every node back", function()
				local now = bench.StubCount()
				bench.Swap(false)
				return now == pooled, (pooled - now) .. " nodes kept, or real ones taken in"
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
	--- A hand side's make (once: hand code makes new frames every time, and WoW never frees one). `release` (for a
	--- make that replaces module state) drops the last make's state in the untimed frame before, so kept KB is this
	--- make's own and not minus the state it orphans.
	local function HandMake(scenario, size, impl, make, release)
		add(measure:Series(scenario, size, impl, "make", 1, make, { kept = true, prepare = release }))
	end
	--- A hand side's close: show untimed, then hide timed (hidden after).
	local function HandClose(scenario, size, impl, ShowIt, HideIt)
		add(measure:Series(scenario, size, impl, "close", HEAVY, HideIt, { prepare = ShowIt }))
	end

	local texts = {}
	--- The framework drew `values` in order (every cell).
	local function ShowsValues(values, count)
		return function()
			local n = OrdaenCore._ScreenTexts(texts)
			if n ~= count then
				return false, n .. " texts on screen, not " .. count
			end
			for i = 1, n do
				if texts[i] ~= tostring(values[i]) then
					return false, "cell " .. i .. " shows " .. tostring(texts[i]) .. ", not " .. tostring(values[i])
				end
			end
			return true
		end
	end

	--- One framework side of a simple scenario: make, the measured change, close; under the stub with `engine`.
	local function Simple(scenario, impl, scene, change, verify, engine)
		return function()
			FwMake(scenario, "-", impl, scene)
			for _, c in ipairs(change) do
				add(measure:Series(scenario, "-", impl, c.metric, c.count or REPEATS, c.fn,
					{ verify = not engine and c.verify or nil }))
			end
			FwClose(scenario, "-", impl, scene)
		end
	end

	local function Pass()
		-- signals: many values, sums, watches; writes to random values
		for _, size in ipairs({ "small", "large" }) do
			local scene, writes = "signals-" .. size, size == "small" and 50 or 500
			local values = size == "small" and 1000 or 10000
			local metric = writes .. " writes/frame"
			local function Writes(write, after)
				local rng = Random.New()
				return function()
					for _ = 1, writes do
						write(rng:Next(values))
					end
					if after then
						after()
					end
				end
			end
			Block("signals", size, {
				{ impl = FW, add = function()
					FwMake("signals", size, FW, scene)
					add(measure:Series("signals", size, FW, metric, FRAMES, Writes(function(k)
						refs[scene].Write(k)
					end, flush), { verify = Seen(metric, FW, function()
						return refs[scene].Checksum()
					end) }))
					FwClose("signals", size, FW, scene)
				end },
				{ impl = BEST, add = function()
					HandMake("signals", size, BEST, function()
						Best.signals.Make(size)
					end, Best.signals.Release)
					add(measure:Series("signals", size, BEST, metric, FRAMES, Writes(Best.signals.Write,
						Best.signals.Flush), { verify = Seen(metric, BEST, Best.signals.Checksum) }))
				end },
				{ impl = TYPICAL, add = function()
					HandMake("signals", size, TYPICAL, function()
						Typical.signals.Make(size)
					end, Typical.signals.Release)
					add(measure:Series("signals", size, TYPICAL, metric, FRAMES, Writes(Typical.signals.Write),
						{ verify = Seen(metric, TYPICAL, Typical.signals.Checksum) }))
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
				end, { verify = Seen("1 change/frame", FW, function()
					return refs.fanout.Checksum()
				end) }))
				FwClose("fanout", "-", FW, "fanout")
			end },
			{ impl = BEST, add = function()
				HandMake("fanout", "-", BEST, Best.fanout.Make, Best.fanout.Release)
				add(measure:Series("fanout", "-", BEST, "1 change/frame", FRAMES, Best.fanout.Bump,
					{ verify = Seen("1 change/frame", BEST, Best.fanout.Checksum) }))
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

		-- events: bursts of 20 bag updates a frame
		Block("events", "-", {
			{ impl = FW, add = function()
				FwMake("events", "-", FW, "events")
				local rng = Random.New()
				add(measure:Series("events", "-", FW, "20 BAG_UPDATE/frame", FRAMES, function()
					for _ = 1, 20 do
						OrdaenCore._FireEvent("BAG_UPDATE", rng:Next(5))
					end
					flush()
				end, { verify = Seen("20 BAG_UPDATE/frame", FW, FwScreen()) }))
				FwClose("events", "-", FW, "events")
			end },
			{ impl = BEST, add = function()
				HandMake("events", "-", BEST, Best.events.Make)
				local rng = Random.New()
				add(measure:Series("events", "-", BEST, "20 BAG_UPDATE/frame", FRAMES, function()
					for _ = 1, 20 do
						Best.events.OnBagUpdate(rng:Next(5))
					end
					Best.events.Flush()
				end, { verify = Seen("20 BAG_UPDATE/frame", BEST, HandScreen(Best.events)) }))
				add(measure:Do(Best.events.Hide))
			end },
		})

		-- grid: item buttons
		for _, size in ipairs({ "small", "large" }) do
			local scene = "grid-" .. size
			local count = size == "small" and 200 or 1000
			--- Random cells changed to random numbers of 1 to 4 digits, which fit a cell (one changed), and every cell to a new random
			--- number (all changed): the same sequences on every side.
			local function OneChanged(set)
				local rng = Random.New()
				return function()
					set(rng:Next(count), rng:Next(9999))
				end
			end
			local function AllChanged(setAll)
				local rng, values = Random.New(), {}
				return function()
					for k = 1, count do
						values[k] = rng:Next(9999)
					end
					setAll(values)
				end, values
			end
			local function Framework(impl, mounted, engine)
				return function()
					FwMake("grid", size, impl, mounted)
					if not engine then
						add(measure:Series("grid", size, impl, "steady (shown, unchanged)", STEADY, Nothing))
					end
					add(measure:Series("grid", size, impl, "one changed", REPEATS, OneChanged(function(k, v)
						refs[mounted].SetOne(k, v)
						flush()
					end), { verify = not engine and Seen("one changed", impl, FwScreen(true)) or nil }))
					local all, values = AllChanged(function(values)
						local ref = refs[mounted]
						for k = 1, count do
							ref.SetOne(k, values[k])
						end
						flush()
					end)
					add(measure:Series("grid", size, impl, "all changed", REPEATS, all,
						{ verify = not engine and Seen("all changed", impl, FwScreen(true), ShowsValues(values, count))
							or nil }))
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
					HandMake("grid", size, impl, function()
						Grid.Make(size)
					end)
					add(measure:Series("grid", size, impl, "steady (shown, unchanged)", STEADY, Nothing))
					add(measure:Series("grid", size, impl, "one changed", REPEATS, OneChanged(function(k, v)
						Grid.SetOne(size, k, v)
					end), { verify = Seen("one changed", impl, HandScreen(Grid, true, size)) }))
					local all, values = AllChanged(function(values)
						Grid.SetAll(size, values)
					end)
					add(measure:Series("grid", size, impl, "all changed", REPEATS, all, {
						verify = Seen("all changed", impl, HandScreen(Grid, true, size), function()
							return Grid.Verify(size, values)
						end),
					}))
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
				{ impl = FW_NAIVE, add = Framework(FW_NAIVE, scene .. "-naive") },
				{ impl = FW_ENGINE, add = UnderStub("grid", size, Framework(FW_ENGINE, scene, true)) },
				{ impl = BEST, add = ByHand(BEST, Best.grid) },
				{ impl = TYPICAL, add = ByHand(TYPICAL, Typical.grid) },
			})
		end

		-- ticker: texts changed every frame
		for _, size in ipairs({ "small", "large" }) do
			local scene = "ticker-" .. size
			local function Framework(impl, mounted, engine)
				return function()
					FwMake("ticker", size, impl, mounted)
					add(measure:Series("ticker", size, impl, "all texts/frame", FRAMES, function()
						refs[mounted].Tick()
						flush()
					end, { verify = engine == nil and Seen("all texts/frame", impl, FwScreen()) or nil }))
					FwClose("ticker", size, impl, mounted)
				end
			end
			local function ByHand(impl, Ticker)
				return function()
					HandMake("ticker", size, impl, function()
						Ticker.Make(size)
					end)
					add(measure:Series("ticker", size, impl, "all texts/frame", FRAMES, function()
						Ticker.Tick(size)
					end, { verify = Seen("all texts/frame", impl, HandScreen(Ticker, false, size)) }))
					HandClose("ticker", size, impl, function()
						Ticker.Show(size)
					end, function()
						Ticker.Hide(size)
					end)
				end
			end
			Block("ticker", size, {
				{ impl = FW, add = Framework(FW, scene) },
				{ impl = FW_NAIVE, add = Framework(FW_NAIVE, scene .. "-naive") },
				{ impl = FW_ENGINE, add = UnderStub("ticker", size, Framework(FW_ENGINE, scene, true)) },
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
					end, { verify = not engine and Seen(operation, impl, FwScreen(), verify) or nil }))
				end
				FwClose("reorder", "-", impl, "reorder")
			end
		end
		local function ReorderByHand(impl, Reorder)
			return function()
				HandMake("reorder", "-", impl, Reorder.Make)
				for _, operation in ipairs(OPERATIONS) do
					add(measure:Series("reorder", "-", impl, operation, REPEATS, Reorder[operation],
						{ verify = Seen(operation, impl, HandScreen(Reorder)) }))
				end
				HandClose("reorder", "-", impl, Reorder.Show, Reorder.Hide)
			end
		end
		Block("reorder", "-", {
			{ impl = FW, add = ReorderFramework(FW) },
			{ impl = FW_ENGINE, add = UnderStub("reorder", "-", ReorderFramework(FW_ENGINE, true)) },
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
				end, { verify = engine and Grew("renders", REPEATS)
					or Seen("leaf signal changed", impl, FwScreen(), Grew("renders", REPEATS)) }))
				local function LeafValue()
					return counters.leafValue == REPEATS, "the leaf got " .. tostring(counters.leafValue)
				end
				add(measure:Series("deep", "-", impl, "value through 100 levels", REPEATS, function(i)
					refs.deep.SetValue(i)
					flush()
				end, { verify = engine and LeafValue or Seen("value through 100 levels", impl, FwScreen(), LeafValue) }))
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
			{ impl = FW_ENGINE, add = UnderStub("deep", "-", DeepFramework(FW_ENGINE, true)) },
			{ impl = BEST, add = function()
				HandMake("deep", "-", BEST, Best.deep.Make)
				add(measure:Series("deep", "-", BEST, "leaf signal changed", REPEATS, Best.deep.SetSource,
					{ verify = Seen("leaf signal changed", BEST, HandScreen(Best.deep)) }))
				add(measure:Series("deep", "-", BEST, "value through 100 levels", REPEATS, Best.deep.SetValue,
					{ verify = Seen("value through 100 levels", BEST, HandScreen(Best.deep)) }))
				HandClose("deep", "-", BEST, Best.deep.Show, Best.deep.Hide)
			end },
		})

		-- the scenarios common in our addons: layout changes, tooltips, filters, dragging, bars, sections. Each runs
		-- its change on the framework, on the stub (the engine alone) and by hand, from the same random sequence.
		local COMMON = {
			{ name = "resize", metric = "window resized (300-700)", draw = function(rng, set) set(299 + rng:Next(400)) end,
				fw = "SetWidth", hand = Best.resize.SetWidth, textures = true },
			{ name = "columns", metric = "column count changed (6-14)", draw = function(rng, set) set(5 + rng:Next(9)) end,
				fw = "SetColumns", hand = Best.columns.SetColumns, textures = true },
			{ name = "grow", metric = "50 texts new length (1-30)", draw = function(rng, set)
				for r = 1, 50 do
					set(r, rng:Next(30))
				end
			end, fw = "SetLength", hand = Best.grow.SetLength, textures = true },
			{ name = "rows", metric = "row count changed (50-150)", draw = function(rng, set) set(49 + rng:Next(101)) end,
				fw = "SetCount", hand = Best.rows.SetCount },
			{ name = "filter", metric = "filter shifted", draw = function(rng, set) set(rng:Next(1000)) end,
				fw = "SetShift", hand = Best.filter.SetShift },
			{ name = "drag", metric = "moved", frames = true, draw = function(rng, set)
				set(100 + rng:Next(400), 100 + rng:Next(300))
			end, fw = "Move", hand = Best.drag.Move, textures = true },
			{ name = "bars", metric = "20 fills changed", frames = true, draw = function(rng, set)
				for i = 1, 20 do
					set(i, rng:Next(100))
				end
			end, fw = "SetFill", hand = Best.bars.SetFill, textures = true },
			{ name = "sections", metric = "a section toggled", draw = function(rng, set) set(rng:Next(20)) end,
				fw = "Toggle", hand = Best.sections.Toggle },
		}
		for _, c in ipairs(COMMON) do
			local count = c.frames and FRAMES or REPEATS
			local function FrameworkChange(engine)
				local rng = Random.New()
				local function set(...)
					refs[c.name][c.fw](...)
				end
				return { { metric = c.metric, count = count, fn = function()
					c.draw(rng, set)
					flush()
				end, verify = Seen(c.metric, FW, FwScreen(c.textures)) } }
			end
			local hand = Best[c.name]
			Block(c.name, "-", {
				{ impl = FW, add = Simple(c.name, FW, c.name, FrameworkChange(false)) },
				{ impl = FW_ENGINE, add = UnderStub(c.name, "-", Simple(c.name, FW_ENGINE, c.name, FrameworkChange(true),
					nil, true)) },
				{ impl = BEST, add = function()
					HandMake(c.name, "-", BEST, hand.Make)
					local rng = Random.New()
					add(measure:Series(c.name, "-", BEST, c.metric, count, function()
						c.draw(rng, c.hand)
					end, { verify = Seen(c.metric, BEST, HandScreen(hand, c.textures)) }))
					add(measure:Do(hand.Hide))
				end },
			})
		end

		-- tooltip: shown with new content, then hidden
		local function TooltipFramework(impl)
			return function()
				FwMake("tooltip", "-", impl, "tooltip")
				local rng = Random.New()
				local engine = impl == FW_ENGINE
				add(measure:Series("tooltip", "-", impl, "show with new content", REPEATS, function()
					refs.tooltip.ShowWith(rng:Next(1000))
					flush()
				end, { prepare = function()
					refs.tooltip.Hide()
					flush()
				end, verify = not engine and Seen("show with new content", impl, FwScreen(true)) or nil }))
				add(measure:Series("tooltip", "-", impl, "hide", REPEATS, function()
					refs.tooltip.Hide()
					flush()
				end, { prepare = function()
					refs.tooltip.ShowWith(7)
					flush()
				end, verify = not engine and Seen("hide", impl, FwScreen(true)) or nil }))
				FwClose("tooltip", "-", impl, "tooltip")
			end
		end
		Block("tooltip", "-", {
			{ impl = FW, add = TooltipFramework(FW) },
			{ impl = FW_ENGINE, add = UnderStub("tooltip", "-", TooltipFramework(FW_ENGINE)) },
			{ impl = BEST, add = function()
				HandMake("tooltip", "-", BEST, Best.tooltip.Make)
				local rng = Random.New()
				add(measure:Series("tooltip", "-", BEST, "show with new content", REPEATS, function()
					Best.tooltip.ShowWith(rng:Next(1000))
				end, { prepare = Best.tooltip.Hide,
					verify = Seen("show with new content", BEST, HandScreen(Best.tooltip, true)) }))
				add(measure:Series("tooltip", "-", BEST, "hide", REPEATS, Best.tooltip.Hide, { prepare = function()
					Best.tooltip.ShowWith(7)
				end, verify = Seen("hide", BEST, HandScreen(Best.tooltip, true)) }))
			end },
		})

		-- hover: the cursor leaves one item cell and enters a random other, through the frames' own OnLeave/OnEnter
		-- scripts (no stub side: the stub draws no frames to hover)
		local function Hovers(cells, after)
			local rng, last = Random.New(), nil
			return function()
				if last then
					local script = last:GetScript("OnLeave")
					script(last)
				end
				last = cells[rng:Next(#cells)]
				local script = last:GetScript("OnEnter")
				script(last)
				if after then
					after()
				end
			end, function()
				return last
			end
		end
		local hoverFrames, hoverNodes = {}, {}
		Block("hover", "-", {
			{ impl = FW, add = function()
				FwMake("hover", "-", FW, "hover")
				add(measure:Do(function()
					local n, k = OrdaenCore._ScreenNodes("box", hoverNodes), 0
					for i = 1, n do
						if hoverNodes[i].mouse then
							k = k + 1
							hoverFrames[k] = hoverNodes[i].frame
						end
					end
					for i = #hoverFrames, k + 1, -1 do
						hoverFrames[i] = nil
					end
				end))
				local move, current = Hovers(hoverFrames, flush)
				add(measure:Series("hover", "-", FW, "hovered item changed", FRAMES, move, { verify = Seen(
					"hovered item changed", FW, FwScreen(), function()
					if #hoverFrames ~= 100 then
						return false, #hoverFrames .. " hoverable cells, not 100"
					end
					local index
					for i = 1, #hoverFrames do
						if hoverFrames[i] == current() then
							index = i
						end
					end
					local n = OrdaenCore._ScreenTexts(texts)
					if n ~= 1 or texts[1] ~= "Item " .. tostring(index) then
						return false, "the line shows " .. tostring(texts[1]) .. ", not Item " .. tostring(index)
					end
					local lit = 0
					for i = 1, #hoverFrames do
						if hoverFrames[i].node.hovered then
							lit = lit + 1
						end
					end
					return lit == 1, lit .. " cells lit, not 1"
				end) }))
				FwClose("hover", "-", FW, "hover")
			end },
			{ impl = BEST, add = function()
				HandMake("hover", "-", BEST, Best.hover.Make)
				add(measure:Series("hover", "-", BEST, "hovered item changed", FRAMES, (Hovers(Best.hover.Cells())), {
					verify = Seen("hovered item changed", BEST, HandScreen(Best.hover), function()
						local lit = Best.hover.Lit()
						return lit == 1, lit .. " cells lit, not 1"
					end),
				}))
				add(measure:Do(Best.hover.Hide))
			end },
		})

		-- units: one operation 1000 times per call (components/units.lua), the shape around it held still: a row's ms is
		-- µs per operation. The framework, and the engine alone on the stub where something is drawn.
		local unitBoxes = {}
		local function Texts(count, first)
			return function()
				local n = OrdaenCore._ScreenTexts(texts)
				if n ~= count then
					return false, n .. " texts on screen, not " .. count
				end
				return first == nil or texts[1] == first, "the first text shows " .. tostring(texts[1])
			end
		end
		local function Boxes(count, field, value, index)
			return function()
				local n = OrdaenCore._ScreenNodes("box", unitBoxes)
				if n ~= count then
					return false, n .. " boxes on screen, not " .. count
				end
				local got = field and unitBoxes[index or 2].a[field]
				if type(value) == "string" then -- a theme colour: its reference's path
					got = type(got) == "table" and rawget(got, "path") or got
				end
				return field == nil or got == value, field and (field .. " is " .. tostring(got))
			end
		end
		-- every Flip unit starts off and flips an even number of times (REPEATS calls), so it ends off
		local UNITS = {
			{ unit = "text", metric = "take 1000 texts", fn = "Show", arg = true, prepare = false, drawn = true,
				verify = Texts(1000) },
			{ unit = "text", metric = "release 1000 texts", fn = "Show", arg = false, prepare = true, drawn = true,
				verify = Texts(0) },
			{ unit = "box", metric = "take 1000 boxes", fn = "Show", arg = true, prepare = false, drawn = true,
				verify = Boxes(1001) },
			{ unit = "box", metric = "release 1000 boxes", fn = "Show", arg = false, prepare = true, drawn = true,
				verify = Boxes(1) },
			{ unit = "look", metric = "1000 backgrounds changed", fn = "Flip", drawn = true,
				verify = Boxes(1001, "background", "color.border") },
			{ unit = "size", metric = "1000 widths changed in fixed cells", fn = "Flip", drawn = true,
				verify = Boxes(2001, "width", 20, 3) },
			{ unit = "textFixed", metric = "1000 texts changed, layout unchanged", fn = "Flip", drawn = true,
				verify = Texts(1000, "1001") },
			{ unit = "textClimb", metric = "1000 texts changed width, 3 levels", fn = "Flip", drawn = true,
				verify = Texts(1000, "1") },
			{ unit = "offset", metric = "100 boxes moved", fn = "Flip", drawn = true,
				verify = Boxes(101, "left", 10) },
			{ unit = "unchanged", metric = "1000 calls, nothing changed", fn = "Flip", drawn = true,
				verify = Texts(1000, "1") },
			{ unit = "writes", metric = "1000 writes, no reader", fn = "WriteAll", verify = function(ref)
				local sum = ref.Sum()
				return sum == REPEATS * 1000, "values add up to " .. sum
			end },
			{ unit = "runs", metric = "1000 x (write, flush), 1 watch", fn = "Flip", each = 1000, verify = function(ref)
				local runs = ref.Runs()
				return runs == 1 + REPEATS * 1000, "the watch ran " .. runs .. " times"
			end },
			{ unit = "wide", metric = "5000 writes, 5000 watches, 1 flush", fn = "WriteAll", verify = function(ref)
				local runs = ref.Runs()
				return runs == 5000 * (1 + REPEATS), "the watches ran " .. runs .. " times"
			end },
		}
		local function UnitSide(u, impl)
			return function()
				local scene = "units-" .. u.unit
				add(measure:Do(function()
					Show(scene)
				end))
				-- the ref's functions are read at call time: before the mount they are the empty public part
				local prepare
				if u.prepare ~= nil then
					prepare = function()
						refs[scene].Show(u.prepare)
						flush()
					end
				end
				local name, arg, each = u.fn, u.arg, u.each or 1
				add(measure:Series("units", "-", impl, u.metric, REPEATS, function()
					local call = refs[scene][name]
					for _ = 1, each do
						call(arg)
						flush()
					end
				end, { prepare = prepare, verify = impl == FW and function()
					return u.verify(refs[scene])
				end or nil }))
				add(measure:Do(function()
					Show("none")
				end))
			end
		end
		for _, u in ipairs(UNITS) do
			local sides = { { impl = FW, add = UnitSide(u, FW) } }
			if u.drawn then
				sides[2] = { impl = FW_ENGINE, add = UnderStub("units", "-", UnitSide(u, FW_ENGINE)) }
			end
			Block("units", "-", sides)
		end

		-- scheduler: two ways to start the flush, 1000 minimal schedulers each (bench/schedulers.lua); the framework
		-- column is the engine's way (attach the OnUpdate per busy frame), the best column the proposed one (always
		-- attached, returning when nothing is pending)
		local PATTERNS = {
			{ metric = "nothing written", writes = function(_) return 0 end },
			{ metric = "a write every other frame", writes = function(i) return i % 2 end },
			{ metric = "a write every frame", writes = function(_) return 1 end },
			{ metric = "10 writes every frame", writes = function(_) return 10 end },
		}
		local function SchedulerSide(variant, impl)
			return function()
				add(measure:Do(function()
					Schedulers.Make()
					Schedulers.Start(variant)
				end))
				for _, p in ipairs(PATTERNS) do
					local before, expected = 0, 0
					add(measure:Do(function()
						before = Schedulers.Flushes(variant)
						expected = 0
					end))
					add(measure:Series("scheduler", "-", impl, p.metric, FRAMES, function(i)
						local times = p.writes(i)
						if times > 0 then
							Schedulers.Write(variant, times)
							expected = expected + 1000
						end
					end, { verify = function()
						local ran = Schedulers.Flushes(variant) - before
						if Schedulers.Pending(variant) then
							return false, "writes still pending after their frame"
						end
						return ran == expected, ran .. " flushes, not " .. expected
					end }))
				end
				add(measure:Do(function()
					Schedulers.Stop(variant)
				end))
			end
		end
		Block("scheduler", "-", {
			{ impl = FW, add = SchedulerSide("attach", FW) },
			{ impl = BEST, add = SchedulerSide("always", BEST) },
		})

		add(measure:Series("idle", "-", "-", "idle (end)", IDLE, Nothing))
	end

	-- 0. the client's one-time costs (the font file, the first texture, the first frame), paid untimed by WoW objects
	-- of the bench's own, so no side's cold make carries them and the framework's pools stay empty; drawn for one
	-- frame, then hidden
	local warm
	add(tracked:Do(function()
		progress("client warm-up")
		warm = CreateFrame("Frame", nil, UIParent)
		warm:SetSize(36, 36)
		warm:SetPoint("CENTER")
		local texture = warm:CreateTexture(nil, "BACKGROUND")
		texture:SetAllPoints()
		texture:SetColorTexture(0.3, 0.3, 0.35, 1)
		local text = warm:CreateFontString(nil, "OVERLAY", FONT)
		text:SetAllPoints()
		text:SetFormattedText("%d", 1)
	end))
	add(tracked:Do(function()
		warm:Hide()
	end))
	-- 1. the cold block, measured while the session is fresh
	measure, passName = tracked, "cold"
	Block("grid", "large", {
		{ impl = FW, add = function()
			add(measure:Series("grid", "large", FW, "make (cold)", 1, function()
				Show("grid-large")
			end, { kept = true }))
			add(measure:Do(function()
				Show("none")
			end))
		end },
		-- the engine alone (the stub backend) right after: its kept KB splits the framework's between engine and
		-- backend. Not quite cold for the engine: the framework side's first mount ran its one-time code just before.
		{ impl = FW_ENGINE, add = UnderStub("grid", "large", function()
			add(measure:Series("grid", "large", FW_ENGINE, "make (cold)", 1, function()
				Show("grid-large")
			end, { kept = true }))
			add(measure:Do(function()
				Show("none")
			end))
		end) },
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
	measure, passName = silent, "warm-up"
	Pass()
	-- 3. the measured pass
	measure, passName = tracked, "measured"
	Pass()
	totals.blocks = blocks
	return steps
end

return Plan
