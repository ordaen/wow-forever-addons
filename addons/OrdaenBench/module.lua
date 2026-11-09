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
		-- the last round's results, one structured line each (bench/driver.lua), read by scripts/bench_save.lua
		-- and how many rounds ran: it rotates which side of each scenario goes first
		Define.Persistent({
			results = { type = "list", of = { type = "string" }, cap = 1000 },
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

		local flush = OrdaenCore._Flush -- the bench's door: a change timed with its flush
		-- log lines wait for the end of the round: the dev addon streams each one over the following frames, which
		-- would land in the next measurements' frame times
		local held = {}
		local measure = Driver.NewMeasure(function(line)
			held[#held + 1] = line
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
		local ran = false
		SlashCmdList.ORDAENBENCH = function()
			if Driver.IsRunning() then
				Say("already running")
				return
			end
			-- one round per /reload: hand code makes its frames again each round and WoW never frees a frame, while the
			-- framework's pools would start warm
			if ran then
				Say("one round per session: /reload, then /obench")
				return
			end
			ran = true
			results:Reset()
			local round = rounds:Get() + 1
			rounds:Set(round)
			local _, build = GetBuildInfo()
			results:Insert(string.format("round|%s|%s|%.0f|%.0f|%d", date("%Y-%m-%d %H:%M:%S"), build, GetFramerate(),
				collectgarbage("count"), round))
			-- what else ran: every loaded addon's work is in the frame times
			local loaded = {}
			for i = 1, C_AddOns.GetNumAddOns() do
				if C_AddOns.IsAddOnLoaded(i) then
					loaded[#loaded + 1] = (C_AddOns.GetAddOnInfo(i))
				end
			end
			results:Insert("addons|" .. table.concat(loaded, ","))
			-- what decides how frame times read: a capped frame rate or vsync makes frames wait
			results:Insert(string.format("settings|collector=%s|maxFPS=%s|maxFPSBk=%s|vsync=%s", Driver.collector,
				tostring(GetCVar("maxFPS")), tostring(GetCVar("maxFPSBk")), tostring(GetCVar("vsync"))))
			measure.failures = 0
			Say("running: a few minutes; keep the game in front, frame rate uncapped, vsync off")
			Driver.Run(Plan.Steps(bench, round), function()
				for i = 1, #held do
					self.module.debug:Log(held[i])
					held[i] = nil
				end
				Say(string.format("done: %d results, %d failed checks. /reload, then save the round.", results:Len() - 3,
					measure.failures))
			end)
		end
	end,
})
