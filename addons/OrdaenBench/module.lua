-- Ordaen Bench: measures the framework in game against hand-written code doing the same (design:
-- development/framework/mvp#the-benchmark). Dev only, never packaged. `/obench` runs every scenario (components/ on
-- the framework, baseline/ by hand; bench/plan.lua says what and how). Every result goes to the module's log
-- (wow_log) and OrdaenBenchDB; after a /reload, `ordaen lua scripts/bench_save.lua` saves the round to bench/results/.
local Define = import("@ordaen/define")
local Driver = import("bench/driver")
local Plan = import("bench/plan")

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
		-- the last round's results, one structured line each (bench/driver.lua), read by scripts/bench_save.lua
		Define.Persistent({ results = { type = "list", of = { type = "string" }, cap = 1000 } })
		local scene, results = self.state.ephemeral.scene, self.state.persistent.results

		local refs, mounts = {}, {}
		for _, s in ipairs(SCENES) do
			refs[s.id] = Define.Ref(s.component)
			mounts[s.id] = { component = s.component, data = { key = s.id, ref = refs[s.id], attributes = { size = s.size } } }
		end
		self:Watch(function()
			local mount = mounts[scene:Get()]
			if mount then
				self:Mount(mount.component, mount.data)
			end
		end)

		local flush = OrdaenCore._Flush -- the bench's door: a change timed with its flush
		local measure = Driver.NewMeasure(function(line)
			self.module.debug:Log(line)
		end, function(line)
			results:Insert(line)
		end)
		local bench = {
			measure = measure, flush = flush, refs = refs,
			Set = function(to)
				scene:Set(to)
			end,
			Show = function(to)
				scene:Set(to)
				flush()
			end,
		}

		local function Say(text)
			print("|cff88ccffOrdaen Bench|r " .. text)
		end

		-- a dev tool's own slash command (modules get `commands` after the MVP)
		SLASH_ORDAENBENCH1 = "/obench"
		SlashCmdList.ORDAENBENCH = function()
			if Driver.IsRunning() then
				Say("already running")
				return
			end
			results:Reset()
			local _, build = GetBuildInfo()
			results:Insert(string.format("round|%s|%s|%.0f|%.0f", date("%Y-%m-%d %H:%M:%S"), build, GetFramerate(),
				collectgarbage("count")))
			measure.failures = 0
			Say("running: about two minutes, keep the game in front")
			Driver.Run(Plan.Steps(bench), function()
				Say(string.format("done: %d results, %d failed checks. /reload, then save the round.", results:Len() - 1,
					measure.failures))
			end)
		end
	end,
})
