-- Ordaen Bench: measures the framework in game against hand-written code doing the same (design:
-- development/framework/mvp#the-benchmark). Dev only, never packaged. `/obench` runs every scenario (components/ on
-- the framework, baseline/ by hand; bench/plan.lua says what and how). Every result goes to the module's log
-- (wow_log) and OrdaenBenchDB; after a /reload, `ordaen lua scripts/bench_save.lua` saves the round to bench/results/.
local Define = import("@ordaen/define")
local Driver = import("bench/driver")
local Plan = import("bench/plan")
local Stub = import("bench/stub")
local Probes = import("bench/probes")
local Progress = import("bench/progress")

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

---@enum BenchScene
local BenchScene = { None = "none" }
for _, scene in ipairs(SCENES) do
	BenchScene[scene.id] = scene.id
end

return Define.Module({
	title = "Ordaen Bench",

	Setup = function(game, self)
		Define.Ephemeral({ scene = { type = "choice", choices = BenchScene, default = BenchScene.None } })
		-- the last run's results, one structured line each (bench/driver.lua), read by scripts/bench_save.lua,
		-- and how many rounds ran (the round's number)
		Define.Persistent({
			results = { type = "list", of = { type = "string" }, cap = 3000 },
			-- the probes' lines (bench/probes.lua): answers for the backend's owner, never part of a round
			probes = { type = "list", of = { type = "string" }, cap = 500 },
			rounds = { type = "number", default = 0 },
		})
		local scene, results, rounds = self.state.ephemeral.scene, self.state.persistent.results, self.state.persistent.rounds
		local probes = self.state.persistent.probes

		local refs, mounts = {}, {}
		for _, s in ipairs(SCENES) do
			refs[s.id] = Define.Ref(s.component)
			mounts[s.id] = { component = s.component, data = { key = s.id, ref = refs[s.id], attributes = { size = s.size, itemsRead = s.itemsRead, naive = s.naive,
				unit = s.unit } } }
		end
		self:Watch(function()
			local mount = mounts[scene:Get()]
			if mount then
				self:Mount(mount.component, mount.data)
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
				scene:Set(to)
			end,
			Show = function(to)
				scene:Set(to)
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

		-- a dev tool's own slash command (modules get `commands` after the MVP)
		SLASH_ORDAENBENCH1 = "/obench"
		local ran = false
		-- `/obench`: a round. `/obench check`: the same plan with a few calls per series, for the checks only
		-- (bench_save reports its checks and never records it). `/obench variants`: a round with the framework's
		-- variants (naive, itemsRead) too. `/obench probes`: only the probes (bench/probes.lua:
		-- what WoW's calls cost, for the backend's owner), never part of a round.
		SlashCmdList.ORDAENBENCH = function(message)
			local word = (message or ""):match("^%s*(%a*)%s*$")
			local mode = (word == "check" or word == "probes" or word == "variants") and word or "round"
			if Driver.IsRunning() then
				Say("already running")
				return
			end
			-- one round per /reload: its cold block needs a fresh session (empty pools, no frames made yet)
			if ran then
				Say("one run per session: /reload, then /obench")
				return
			end
			ran = true
			local round = rounds:Get() + ((mode == "round" or mode == "variants") and 1 or 0)
			rounds:Set(round)
			local _, build = GetBuildInfo()
			pending[#pending + 1] = string.format("round|%s|%s|%.0f|%.0f|%d", date("%Y-%m-%d %H:%M:%S"), build,
				GetFramerate(), collectgarbage("count"), round)
			pending[#pending + 1] = "mode|" .. mode
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
				steps = Plan.Steps(bench, tracked, Progress.Set, mode)
			end
			Quiet(true)
			Driver.Run(steps, function()
				Quiet(false)
				Progress.Hide()
				local errors = Driver.errors
				pending[#pending + 1] = "errors|" .. errors.count .. "|" .. table.concat(errors.first, " // ")
				results:Reset()
				for i = 1, #pending do
					results:Insert(pending[i])
					pending[i] = nil
				end
				probes:Reset()
				for i = 1, #probed do
					probes:Insert(probed[i])
					debug:Log("probe|" .. probed[i])
					probed[i] = nil
				end
				debug:Logf("round %d: %d lines, %d failed checks", round, results:Len(), tracked.failures)
				Say(string.format("done: %d failed checks, %d errors. /reload, then save the round.", tracked.failures,
					errors.count))
			end)
		end
	end,
})
