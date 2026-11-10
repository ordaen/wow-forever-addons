-- Ordaen Bench: measures the framework in game against hand-written code doing the same (design:
-- development/framework/mvp#the-benchmark). Dev only, never packaged. `/ordaen bench round` runs every scenario
-- (components/ on the framework, baseline/ by hand; bench/plan.lua says what and how). Every result goes to
-- OrdaenBenchDB and, with the debug addon on, over the strip; `ordaen lua scripts/bench_save.lua` saves the round to
-- bench/results/.
local Define = import("@ordaen/define")
local L = import("locales")
local Driver = import("bench/driver")
local Stub = import("bench/stub")
-- the plan and the probes (and through them every hand-written side, the screen check and the pixel sizes) load at
-- the first run, not with the module: the module loads before WoW applies the UI scale, and the hand sides size
-- themselves in whole pixels of the scale they load at (bench/px.lua)
local Plan, Probes, Px
local Progress = import("bench/progress")
local LoopBench = import("bench/loop")
local WindowCheck = import("components/windowCheck")
local WINDOW_CHECK = { key = "window" }

local SCENES = {
	{ id = "signals-large", component = import("components/signals"), size = "large" },
	{ id = "coalesce", component = import("components/coalesce") },
	{ id = "chain", component = import("components/chain") },
	{ id = "diamond", component = import("components/diamond") },
	{ id = "fanout", component = import("components/fanout") },
	{ id = "cascade", component = import("components/cascade") },
	{ id = "grid-large", component = import("components/grid"), size = "large" },
	{ id = "grid-large-itemsRead", component = import("components/grid"), size = "large", itemsRead = true },
	{ id = "grid-large-naive", component = import("components/grid"), size = "large", naive = true },
	{ id = "ticker-large-naive", component = import("components/ticker"), size = "large", naive = true },
	{ id = "resize", component = import("components/resize") },
	{ id = "columns", component = import("components/columns") },
	{ id = "grow", component = import("components/grow") },
	{ id = "rows", component = import("components/rows") },
	{ id = "tooltip", component = import("components/tooltip") },
	{ id = "filter", component = import("components/filter") },
	{ id = "drag", component = import("components/drag") },
	{ id = "bars", component = import("components/bars") },
	{ id = "sections", component = import("components/sections") },
	{ id = "events", component = import("components/events") },
	{ id = "hover", component = import("components/hover") },
	{ id = "units-text", component = import("components/units"), unit = "text" },
	{ id = "units-box", component = import("components/units"), unit = "box" },
	{ id = "units-look", component = import("components/units"), unit = "look" },
	{ id = "units-size", component = import("components/units"), unit = "size" },
	{ id = "units-textFixed", component = import("components/units"), unit = "textFixed" },
	{ id = "units-textClimb", component = import("components/units"), unit = "textClimb" },
	{ id = "units-offset", component = import("components/units"), unit = "offset" },
	{ id = "units-unchanged", component = import("components/units"), unit = "unchanged" },
	{ id = "units-writes", component = import("components/units"), unit = "writes" },
	{ id = "units-runs", component = import("components/units"), unit = "runs" },
	{ id = "units-wide", component = import("components/units"), unit = "wide" },
	{ id = "ticker-large", component = import("components/ticker"), size = "large" },
	{ id = "reorder", component = import("components/reorder") },
	{ id = "deep", component = import("components/deep") },
}

-- the graphics settings a round records (bench_save compares rounds only with the same ones)
local GRAPHICS = {
	"graphicsQuality", "graphicsViewDistance", "graphicsEnvironmentDetail", "graphicsGroundClutter",
	"graphicsShadowQuality", "graphicsLiquidDetail", "graphicsParticleDensity", "graphicsSSAO",
	"graphicsDepthEffects", "graphicsTextureResolution", "graphicsSpellDensity", "graphicsProjectedTextures",
	"graphicsOutlineMode", "graphicsComputeEffects", "MSAAQuality", "ffxAntiAliasingMode",
}

local RECORD_LINES = 500 -- result lines per record sent over the strip

-- Starts a run of `mode` ("round", "check", "variants", "probes"): made by the module's setup, which holds the
-- run's state; the commands call it
local start

---@enum BenchScene
local BenchScene = { None = "none" }
for _, scene in ipairs(SCENES) do
	BenchScene[scene.id] = scene.id
end

return Define.Module({
	title = "Ordaen Bench",
	icon = Define.Asset("Interface/Icons/INV_Misc_PocketWatch_01"), -- a stopwatch: it times the engine

	Setup = function(game, self)
		Define.Ephemeral({
			scene = { type = "choice", choices = BenchScene, default = BenchScene.None },
			-- the library's Window shown for a look in game (/ordaen bench window), never during a round
			window = { type = "boolean", default = false },
		})
		-- the last run's results, one structured line each (bench/driver.lua), read by scripts/bench_save.lua,
		-- and how many rounds ran (the round's number)
		Define.Persistent({
			results = { type = "list", of = { type = "string" }, cap = 3000 },
			-- the probes' lines (bench/probes.lua): answers for the backend's owner, never part of a round
			probes = { type = "list", of = { type = "string" }, cap = 500 },
			rounds = { type = "number", default = 0 },
		})

		local refs, mounts = {}, {}
		for _, s in ipairs(SCENES) do
			refs[s.id] = Define.Ref(s.component)
			mounts[s.id] = { component = s.component, data = { key = s.id, ref = refs[s.id], attributes = { size = s.size, itemsRead = s.itemsRead, naive = s.naive,
				unit = s.unit } } }
		end
		self:Watch(function()
			local mount = mounts[self.state.scene]
			if mount then
				self:Mount(mount.component, mount.data)
			end
		end)
		self:Watch(function()
			if self.state.window then
				self:Mount(WindowCheck, WINDOW_CHECK)
			end
		end)

		local flush = OrdaenCore._Flush -- the bench's door (OrdaenCore's Bench.dev.lua): a change timed with its flush
		-- results wait in memory until the round ends: written to the persistent list during the round, they would be
		-- synced and streamed by the dev addon over the following frames, inside the next measurements
		local pending = {}
		local tracked = Driver.NewMeasure(function(line)
			pending[#pending + 1] = line
		end)
		local probed = {}
		local probing = Driver.NewMeasure(function(line)
			probed[#probed + 1] = line
		end)
		local real -- the drawing backend while the stub is in (framework-engine sides)
		local bench = {
			flush = flush, refs = refs,
			Set = function(to)
				self.state.scene = to
			end,
			Show = function(to)
				self.state.scene = to
				flush()
			end,
			StubCount = Stub.Count,
			Swap = function(toStub)
				if toStub then
					-- every layer made on the real backend first: a layer is made on first use and kept for the
					-- session, so one first touched under the stub would stay a stub
					local _ = game.Layer.Screen, game.Layer.Dialog, game.Layer.Tooltip
					Stub.Fill(20000)
					real = OrdaenCore._SwapBackend(Stub)
				elseif real then
					OrdaenCore._SwapBackend(real)
					real = nil
				end
			end,
		}

		local debug = self.module.debug
		--- The dev addon's background work (state sync, Perf sampler, channel) paused while the round runs, where
		--- the dev addon offers it.
		local function Quiet(on)
			local method = debug.Quiet
			if method then
				method(debug, on)
			end
		end

		local function Say(text)
			print("|cff88ccffOrdaen Bench|r " .. text)
		end

		local runs = 0 -- runs this session: the first has the cold block (a fresh session), later ones skip it
		start = function(mode)
			if Driver.IsRunning() then
				Say("already running")
				return
			end
			-- a round counts only on the bench builds (bench_save refuses any other): say so before minutes are spent
			if mode == "round" or mode == "variants" then
				local core = C_AddOns.GetAddOnMetadata("OrdaenCore", "X-Ordaen-Build")
				local benchBuild = C_AddOns.GetAddOnMetadata("OrdaenBench", "X-Ordaen-Build")
				if core ~= "bench" or benchBuild ~= "bench" then
					Say(string.format("not running: Ordaen is a %s build and the bench a %s build; a round needs both on"
						.. " the bench build (ordaen watch --profile bench), then /reload.", tostring(core),
						tostring(benchBuild)))
					return
				end
			end
			Plan = Plan or import("bench/plan")
			Probes = Probes or import("bench/probes")
			Px = Px or import("bench/px")
			-- the hand sides are sized in whole pixels of the scale they loaded at; the framework follows the scale
			if not Px.Current() then
				Say("not running: the UI scale or the resolution changed since the bench's first run. /reload, then"
					.. " /ordaen bench round.")
				return
			end
			runs = runs + 1
			local cold = runs == 1
			Driver.errors.count, Driver.errors.first = 0, {}
			local round = Define.Peek(self.state.rounds) + ((mode == "round" or mode == "variants") and 1 or 0)
			self.state.rounds = round
			local _, build = GetBuildInfo()
			pending[#pending + 1] = string.format("round|%s|%s|%.0f|%.0f|%d", date("%Y-%m-%d %H:%M:%S"), build,
				GetFramerate(), collectgarbage("count"), round)
			pending[#pending + 1] = "mode|" .. mode
			-- the run's number in this session: a later run has no cold block (its rows are a different plan shape)
			pending[#pending + 1] = "session|" .. runs
			-- what else ran: every loaded addon's work is in the frame times
			local loaded = {}
			for i = 1, C_AddOns.GetNumAddOns() do
				if C_AddOns.IsAddOnLoaded(i) then
					loaded[#loaded + 1] = (C_AddOns.GetAddOnInfo(i))
				end
			end
			pending[#pending + 1] = "addons|" .. table.concat(loaded, ",")
			-- what decides how frame times read: a capped frame rate or vsync makes frames wait (the cap is on only
			-- while useMaxFPS is 1; maxFPS keeps its value either way). Resolution and render scale aren't recorded:
			-- every round runs at the same ones.
			pending[#pending + 1] = string.format(
				"settings|collector=%s|useMaxFPS=%s|maxFPS=%s|useMaxFPSBk=%s|maxFPSBk=%s|vsync=%s",
				Driver.collector, tostring(GetCVar("useMaxFPS")), tostring(GetCVar("maxFPS")),
				tostring(GetCVar("useMaxFPSBk")), tostring(GetCVar("maxFPSBk")), tostring(GetCVar("vsync")))
			tracked.failures = 0
			-- the build the game loaded (bench_save records only rounds on the bench profile: release stripping),
			-- where the round ran and the graphics settings (the world drawn is in every frame time): each drawing
			-- setting itself, since what the overall quality slider writes isn't documented for this client
			local graphics = {}
			for i = 1, #GRAPHICS do
				graphics[i] = GRAPHICS[i] .. ":" .. tostring(GetCVar(GRAPHICS[i]))
			end
			pending[#pending + 1] = string.format("build|core=%s|bench=%s|zone=%s|subzone=%s|graphics=%s",
				tostring(C_AddOns.GetAddOnMetadata("OrdaenCore", "X-Ordaen-Build")),
				tostring(C_AddOns.GetAddOnMetadata("OrdaenBench", "X-Ordaen-Build")), GetZoneText() or "",
				GetSubZoneText() or "", table.concat(graphics, ","))
			Say(mode == "probes" and "probing: under a minute."
				or mode == "check" and "checking: about a minute. Keep the mouse away from the bench's frames."
				or "running: several minutes. Keep the game in front and the mouse away from the bench's frames.")
			local steps
			if mode == "probes" then
				steps = Probes.Steps(probing, bench)
			else
				steps = Plan.Steps(bench, tracked, Progress.Set, mode, cold)
			end
			Quiet(true)
			Driver.Run(steps, function()
				Quiet(false)
				Progress.Hide()
				local errors = Driver.errors
				pending[#pending + 1] = "errors|" .. errors.count .. "|" .. table.concat(errors.first, " // ")
				-- over the strip too, so a run needs no /reload to be saved: the dev addon's record channel (a
				-- global: the bench build strips the debug kit's calls), in parts (one record carries up to 250 KB);
				-- the companion files them, bench_save joins them by run
				local record = OrdaenCoreDebug_Record
				if record then
					local run, parts = pending[1] .. "|" .. runs, math.ceil(#pending / RECORD_LINES)
					for part = 1, parts do
						local lines = {}
						for i = (part - 1) * RECORD_LINES + 1, math.min(part * RECORD_LINES, #pending) do
							lines[#lines + 1] = pending[i]
						end
						record("bench", { run = run, part = part, parts = parts, lines = lines })
					end
				end
				Define.Reset(self.state.results)
				for i = 1, #pending do
					table.insert(self.state.results, pending[i])
					pending[i] = nil
				end
				Define.Reset(self.state.probes)
				for i = 1, #probed do
					table.insert(self.state.probes, probed[i])
					debug:Log("probe|" .. probed[i])
					probed[i] = nil
				end
				debug:Logf("round %d: %d lines, %d failed checks", round, #self.state.results, tracked.failures)
				Say(string.format("done: %d failed checks, %d errors. /reload, then save the round.", tracked.failures,
					errors.count))
			end)
		end
	end,

	-- `/ordaen bench round`: a round. `check`: the same plan with a few calls per series, for the checks only
	-- (bench_save reports its checks and never records it). `variants`: a round with the framework's variants
	-- (naive, itemsRead) too. `probes`: only the probes (bench/probes.lua: what WoW's calls cost, for the backend's
	-- owner), never part of a round.
	commands = {
		round = { help = L.CMD_ROUND, Run = function()
			start("round")
		end },
		check = { help = L.CMD_CHECK, Run = function()
			start("check")
		end },
		variants = { help = L.CMD_VARIANTS, Run = function()
			start("variants")
		end },
		probes = { help = L.CMD_PROBES, Run = function()
			start("probes")
		end },
		-- `loop`: the event loop's research bench (bench/loop.lua), not part of a round
		loop = { help = L.CMD_LOOP, Run = function(_, self)
			local debug = self.module.debug
			LoopBench.Run(function(text)
				print("|cff88ccffOrdaen Bench|r " .. text)
			end, function(line)
				debug:Log(line)
			end, function()
				print("|cff88ccffOrdaen Bench|r loop bench done")
			end)
		end },
		window = { help = L.CMD_WINDOW, Run = function(_, self)
			self.state.window = not Define.Peek(self.state.window)
		end },
	},
})
