-- Ordaen Bench: measures the framework in game against hand-written code doing the same (design:
-- development/framework/mvp#the-benchmark). Dev only, never packaged. `/obench` runs every scenario; results go to
-- chat, the module's log (wow_log) and OrdaenBenchDB.
local Define = import("@ordaen/define")
local Driver = import("bench/driver")
local Baseline = import("bench/baseline")
local Signals = import("components/signals")
local Grid = import("components/grid")
local Ticker = import("components/ticker")

---@enum BenchScenario
local BenchScenario = { None = "none", Signals = "signals", Grid = "grid", Ticker = "ticker" }

local FRAMES = 300 -- frames per steady-state scenario
local REPEATS = 20 -- repeats of each one-off change

return Define.Module({
	title = "Ordaen Bench",

	Setup = function(game, self)
		Define.Ephemeral({ scenario = { type = "choice", choices = BenchScenario, default = BenchScenario.None } })
		Define.Persistent({ results = { type = "list", of = { type = "string" }, cap = 200 } })
		local scenario = self.state.ephemeral.scenario
		local results = self.state.persistent.results
		local signals, grid, ticker = Define.Ref(Signals), Define.Ref(Grid), Define.Ref(Ticker)

		self:Watch(function()
			local current = scenario:Get()
			if current == BenchScenario.Signals then
				self:Mount(Signals, { ref = signals })
			elseif current == BenchScenario.Grid then
				self:Mount(Grid, { ref = grid })
			elseif current == BenchScenario.Ticker then
				self:Mount(Ticker, { ref = ticker })
			end
		end)

		local function Record(line)
			print("|cff88ccffOrdaen Bench|r " .. line)
			self.module.debug:Log(line)
			results:Insert(line)
		end
		local measure = Driver.NewMeasure(Record)
		local flush = OrdaenCore._Flush -- the bench's door: a change timed with its flush

		local function Switch(to)
			return function()
				scenario:Set(to)
				flush()
			end
		end

		local function Steps()
			local steps = {}
			local function add(step)
				steps[#steps + 1] = step
			end
			add(measure:Once("framework signals: mount", Switch(BenchScenario.Signals)))
			add(measure:Frames("framework signals: 50 writes/frame", FRAMES, function(frame)
				for i = 1, 50 do
					signals.Write((frame * 50 + i * 37) % 1000 + 1)
				end
				flush()
			end))
			add(measure:Once("framework signals: unmount", Switch(BenchScenario.None)))
			add(measure:Once("baseline signals: make", Baseline.SignalsMake))
			add(measure:Frames("baseline signals: 50 writes/frame", FRAMES, Baseline.SignalsFrame))

			add(measure:Once("framework grid: mount 200", Switch(BenchScenario.Grid)))
			add(measure:Repeat("framework grid: one changed", REPEATS, function(i)
				grid.SetOne(i, i)
				flush()
			end))
			add(measure:Repeat("framework grid: all changed", REPEATS, function(i)
				for k = 1, 200 do
					grid.SetOne(k, i + k)
				end
				flush()
			end))
			add(measure:Once("framework grid: unmount", Switch(BenchScenario.None)))
			add(measure:Repeat("framework grid: open+close", REPEATS, function()
				Switch(BenchScenario.Grid)()
				Switch(BenchScenario.None)()
			end))
			add(measure:Once("baseline grid: make 200", Baseline.GridMake))
			add(measure:Repeat("baseline grid: one changed", REPEATS, Baseline.GridOne))
			add(measure:Repeat("baseline grid: all changed", REPEATS, Baseline.GridAll))
			add(measure:Repeat("baseline grid: show+hide", REPEATS, Baseline.GridToggle))

			add(measure:Once("framework ticker: mount 50", Switch(BenchScenario.Ticker)))
			add(measure:Frames("framework ticker: 50 texts/frame", FRAMES, function()
				ticker.Tick()
				flush()
			end))
			add(measure:Once("framework ticker: unmount", Switch(BenchScenario.None)))
			add(measure:Once("baseline ticker: make", Baseline.TickerMake))
			add(measure:Frames("baseline ticker: 50 texts/frame", FRAMES, Baseline.TickerFrame))
			add(measure:Once("baseline: hide all", Baseline.HideAll))
			return steps
		end

		-- a dev tool's own slash command (modules get `commands` after the MVP)
		SLASH_ORDAENBENCH1 = "/obench"
		SlashCmdList.ORDAENBENCH = function()
			if Driver.IsRunning() then
				print("|cff88ccffOrdaen Bench|r already running")
				return
			end
			results:Reset()
			Record(string.format("start: Lua heap %.0f KB", collectgarbage("count")))
			Driver.Run(Steps(), function()
				Record(string.format("done: Lua heap %.0f KB", collectgarbage("count")))
			end)
		end
	end,
})
