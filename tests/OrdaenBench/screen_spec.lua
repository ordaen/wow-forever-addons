-- The bench's checks offline: the built Ordaen and OrdaenBench run in the fake client (tests/fake/wow.lua), `/obench
-- check` runs the whole plan (every scenario's framework and hand-written sides, the same seeded actions), and every
-- check it makes must pass: the screen comparisons (bench/screen.lua: same texts and textures in the same places as
-- the hand-written side), the state verifies, the level and retention checks. A layout path that draws something
-- else than hand code fails here before it reaches the game.
--
-- Positions come from the fake's anchor rules and its fixed-width font, the same for both sides; the in-game round
-- still decides with WoW's own.
local Fake = require("tests.fake.wow")

local DIST = ".ordaen/check/dist"
local MAX_FRAMES = 20000 -- a check run takes a few thousand frames

-- The persistent list `name` in a module's SavedVariables, wherever its component path put it.
local function findList(db, name)
	for _, t in pairs(db or {}) do
		if type(t) == "table" and type(t[name]) == "table" then
			return t[name]
		end
	end
end

describe("OrdaenBench /obench check in the fake client", function()
	local wow, results

	setup(function()
		wow = Fake.New({ dist = DIST, addons = { "OrdaenCore", "OrdaenBench" } })
		wow:Login()
		wow:Tick()
		assert(wow:Slash("/obench check"), "/obench isn't registered: the bench module didn't load\n"
			.. table.concat(wow.errors, "\n"))
		local done = false
		for _ = 1, MAX_FRAMES do
			wow:Tick()
			local last = wow.printed[#wow.printed]
			if last and last:find("done:", 1, true) then
				done = true
				break
			end
		end
		assert(done, "the check run didn't finish in " .. MAX_FRAMES .. " frames; last printed: "
			.. tostring(wow.printed[#wow.printed]) .. "\n" .. table.concat(wow.errors, "\n"))
		results = findList(wow.env.OrdaenBenchDB, "results") or {}
	end)

	it("raises no Lua errors", function()
		assert.are.same({}, wow.errors)
	end)

	it("passes every check", function()
		local failed = {}
		for _, line in ipairs(results) do
			if line:find("|FAIL ", 1, true) then
				failed[#failed + 1] = line
			end
		end
		assert(#results > 0, "the run wrote no results")
		assert(#failed == 0, #failed .. " failed checks:\n" .. table.concat(failed, "\n"))
	end)
end)
