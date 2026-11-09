-- Ordaen Bench: measures the framework in game against hand-written code doing the same (design:
-- development/framework/mvp#the-benchmark). Dev only, never packaged. `/obench` runs every scenario (components/ on
-- the framework, baseline/ by hand; bench/plan.lua says what and how). Every result goes to the module's log
-- (wow_log) and OrdaenBenchDB; after a /reload, `ordaen lua scripts/bench_save.lua` saves the round to bench/results/.
local Define = import("@ordaen/define")
local Driver = import("bench/driver")
local Plan = import("bench/plan")
local Stub = import("bench/stub")

local SCENES = {
	{ id = "signals-small", component = import("components/signals"), size = "small" },
	{ id = "signals-large", component = import("components/signals"), size = "large" },
	{ id = "coalesce", component = import("components/coalesce") },
	{ id = "chain", component = import("components/chain") },
	{ id = "diamond", component = import("components/diamond") },
	{ id = "fanout", component = import("components/fanout") },
	{ id = "cascade", component = import("components/cascade") },
	{ id = "grid-small", component = import("components/grid"), size = "small" },
	{ id = "grid-large", component = import("components/grid"), size = "large" },
	{ id = "grid-small-itemsRead", component = import("components/grid"), size = "small", itemsRead = true },
	{ id = "grid-large-itemsRead", component = import("components/grid"), size = "large", itemsRead = true },
	{ id = "ticker-small", component = import("components/ticker"), size = "small" },
	{ id = "ticker-large", component = import("components/ticker"), size = "large" },
	{ id = "reorder", component = import("components/reorder") },
	{ id = "deep", component = import("components/deep") },
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
		-- the last round's results, one structured line each (bench/driver.lua), read by scripts/bench_save.lua,
		-- and how many rounds ran: it rotates which side of each block goes first
		Define.Persistent({
			results = { type = "list", of = { type = "string" }, cap = 3000 },
			rounds = { type = "number", default = 0 },
		})
		local scene, results, rounds = self.state.ephemeral.scene, self.state.persistent.results, self.state.persistent.rounds

		local refs, mounts = {}, {}
		for _, s in ipairs(SCENES) do
			refs[s.id] = Define.Ref(s.component)
			mounts[s.id] = { component = s.component, data = { key = s.id, ref = refs[s.id], attributes = { size = s.size, itemsRead = s.itemsRead } } }
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
		local silent = Driver.NewMeasure(nil)
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
		SlashCmdList.ORDAENBENCH = function()
			if Driver.IsRunning() then
				Say("already running")
				return
			end
			-- one round per /reload: its cold block needs a fresh session (empty pools, no frames made yet)
			if ran then
				Say("one round per session: /reload, then /obench")
				return
			end
			ran = true
			local round = rounds:Get() + 1
			rounds:Set(round)
			local _, build = GetBuildInfo()
			pending[#pending + 1] = string.format("round|%s|%s|%.0f|%.0f|%d", date("%Y-%m-%d %H:%M:%S"), build,
				GetFramerate(), collectgarbage("count"), round)
			-- what else ran: every loaded addon's work is in the frame times
			local loaded = {}
			for i = 1, C_AddOns.GetNumAddOns() do
				if C_AddOns.IsAddOnLoaded(i) then
					loaded[#loaded + 1] = (C_AddOns.GetAddOnInfo(i))
				end
			end
			pending[#pending + 1] = "addons|" .. table.concat(loaded, ",")
			-- what decides how frame times read: a capped frame rate or vsync makes frames wait (the cap is on only
			-- while useMaxFPS is 1; maxFPS keeps its value either way); the resolution and render scale set the drawing
			local physicalWidth, physicalHeight = GetPhysicalScreenSize()
			pending[#pending + 1] = string.format(
				"settings|collector=%s|useMaxFPS=%s|maxFPS=%s|useMaxFPSBk=%s|maxFPSBk=%s|vsync=%s|physical=%dx%d|ui=%.0fx%.0f|renderScale=%s",
				Driver.collector, tostring(GetCVar("useMaxFPS")), tostring(GetCVar("maxFPS")),
				tostring(GetCVar("useMaxFPSBk")), tostring(GetCVar("maxFPSBk")), tostring(GetCVar("vsync")),
				physicalWidth, physicalHeight, GetScreenWidth(), GetScreenHeight(), tostring(GetCVar("renderScale")))
			tracked.failures = 0
			Say("running: several minutes; keep the game in front, frame rate uncapped, vsync off")
			Quiet(true)
			Driver.Run(Plan.Steps(bench, round, tracked, silent), function()
				Quiet(false)
				results:Reset()
				for i = 1, #pending do
					results:Insert(pending[i])
					pending[i] = nil
				end
				debug:Logf("round %d: %d lines, %d failed checks", round, results:Len(), tracked.failures)
				Say(string.format("done: %d failed checks. /reload, then save the round.", tracked.failures))
			end)
		end
	end,
})
