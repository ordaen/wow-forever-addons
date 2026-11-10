-- The bench's checks offline: the built Ordaen and OrdaenDev (the Ordaen Dev window, its bench: a private module
-- linked into addons/ from wow-dev-tools; without the link this spec is pending) run in the fake client
-- (tests/fake/wow.lua), `/ordaen dev check` runs the whole plan (every scenario's framework and hand-written sides,
-- the same seeded actions), and every
-- check it makes must pass: the screen comparisons (bench/screen.lua: same texts and textures in the same places as
-- the hand-written side), the state verifies, the level and retention checks. A layout path that draws something
-- else than hand code fails here before it reaches the game. A second run in the same session (the companion's key
-- presses run the bench without a /reload) must pass too, without the cold block.
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

local function failures(lines)
	local failed = {}
	for _, line in ipairs(lines) do
		if line:find("|FAIL ", 1, true) then
			failed[#failed + 1] = line
		end
	end
	return failed
end

describe("the bench: /ordaen dev check in the fake client", function()
	local linked = io.open(DIST .. "/OrdaenDev/OrdaenDev.toc", "rb")
	if not linked then
		pending("OrdaenDev isn't linked (private: wow-dev-tools/modules/OrdaenDev)")
		return
	end
	linked:close()
	local wow, first, second

	-- One /ordaen dev check to its end; a copy of the results it saved.
	local function run()
		local before = #wow.printed
		assert(wow:Slash("/ordaen dev check"), "/ordaen dev isn't there: the dev module didn't load\n"
			.. table.concat(wow.errors, "\n"))
		local done = false
		for _ = 1, MAX_FRAMES do
			wow:Tick()
			local last = wow.printed[#wow.printed]
			if #wow.printed > before and last:find("done:", 1, true) then
				done = true
				break
			end
		end
		assert(done, "the check run didn't finish in " .. MAX_FRAMES .. " frames; last printed: "
			.. tostring(wow.printed[#wow.printed]) .. "\n" .. table.concat(wow.errors, "\n"))
		local saved = findList(wow.env.OrdaenDevDB, "results") or {}
		local copy = {}
		for i = 1, #saved do
			copy[i] = saved[i]
		end
		return copy
	end

	setup(function()
		wow = Fake.New({ dist = DIST, addons = { "OrdaenCore", "OrdaenLibrary", "OrdaenDev" } })
		wow:Login()
		wow:Tick()
		first = run()
		second = run()
	end)

	it("raises no Lua errors", function()
		assert.are.same({}, wow.errors)
	end)

	it("passes every check", function()
		local failed = failures(first)
		assert(#first > 0, "the run wrote no results")
		assert(#failed == 0, #failed .. " failed checks:\n" .. table.concat(failed, "\n"))
	end)

	it("runs again in the same session: every check passes, without the cold block", function()
		local failed = failures(second)
		assert(#failed == 0, #failed .. " failed checks on the second run:\n" .. table.concat(failed, "\n"))
		local cold, session = 0, nil
		for _, line in ipairs(second) do
			if line:find("|first open|", 1, true) then
				cold = cold + 1
			end
			session = session or line:match("^session|(%d+)")
		end
		assert.are.equal(0, cold)
		assert.are.equal("2", session)
	end)
end)
