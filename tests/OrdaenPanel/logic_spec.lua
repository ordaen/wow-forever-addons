-- Ordaen Panel's pure logic: visibility rules (Visibility.lua) and what the segments show (Data.lua).
describe("Ordaen Panel", function()
	local ns

	before_each(function()
		ns = {}
		for _, file in ipairs({ "Visibility.lua", "Data.lua" }) do
			assert(loadfile("addons/OrdaenPanel/" .. file))("OrdaenPanel", ns)
		end
	end)

	describe("visibility", function()
		local function v(over)
			local t = { show = "always", combat = "any", vehicle = true, petBattle = true, resting = false, condition = "" }
			for k, x in pairs(over or {}) do
				t[k] = x
			end
			return t
		end
		local function s(over)
			local t = { combat = false, vehicle = false, petBattle = false, resting = false, hover = false }
			for k, x in pairs(over or {}) do
				t[k] = x
			end
			return t
		end

		it("shows by default and hides in a vehicle and pet battle", function()
			assert.is_true(ns.Visibility.Shown(v(), s()))
			assert.is_false(ns.Visibility.Shown(v(), s({ vehicle = true })))
			assert.is_false(ns.Visibility.Shown(v(), s({ petBattle = true })))
			assert.is_true(ns.Visibility.Shown(v(), s({ resting = true })))
			assert.is_false(ns.Visibility.Shown(v({ resting = true }), s({ resting = true })))
		end)

		it("follows the combat setting", function()
			assert.is_false(ns.Visibility.Shown(v({ combat = "hide" }), s({ combat = true })))
			assert.is_true(ns.Visibility.Shown(v({ combat = "hide" }), s()))
			assert.is_false(ns.Visibility.Shown(v({ combat = "only" }), s()))
			assert.is_true(ns.Visibility.Shown(v({ combat = "only" }), s({ combat = true })))
		end)

		it("shows on mouseover only while hovered, and never never", function()
			assert.is_false(ns.Visibility.Shown(v({ show = "mouseover" }), s()))
			assert.is_true(ns.Visibility.Shown(v({ show = "mouseover" }), s({ hover = true })))
			assert.is_false(ns.Visibility.Shown(v({ show = "never" }), s({ hover = true })))
		end)

		it("lets the custom condition decide alone", function()
			assert.is_false(ns.Visibility.Shown(v({ condition = "[combat] hide; show" }), s({ condition = "hide" })))
			assert.is_true(
				ns.Visibility.Shown(v({ show = "never", condition = "[combat] hide; show" }), s({ condition = "show" }))
			)
		end)

		it("lists only the events the settings need, in a reused table", function()
			local out = { "stale", "stale", "stale", "stale", "stale", "stale", "stale" }
			local events = ns.Visibility.Events(v({ vehicle = false, petBattle = false }), out)
			assert.equals(out, events)
			assert.same({}, events)
			ns.Visibility.Events(v({ combat = "hide" }), out)
			assert.same(
				{ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE",
					"PET_BATTLE_OPENING_START", "PET_BATTLE_CLOSE" },
				out
			)
		end)
	end)

	describe("data", function()
		it("shows experience with rest below the cap, nothing at the cap", function()
			local bar = {}
			ns.Data.Experience(bar, 42, 60, 3000, 10000, 2000)
			assert.equals("xp", bar.kind)
			assert.same({ 3000, 10000, 5000, 30, 20 }, { bar.value, bar.max, bar.overlay, bar.percent, bar.restedPercent })
			ns.Data.Experience(bar, 42, 60, 9000, 10000, 5000)
			assert.equals(10000, bar.overlay, "rest never runs past the level")
			ns.Data.Experience(bar, 60, 60, 0, 0, nil)
			assert.is_nil(bar.kind)
		end)

		it("shows the watched reputation, full at the top", function()
			local bar = {}
			ns.Data.Reputation(bar, {
				name = "Argent Dawn", reaction = 6, currentReactionThreshold = 9000, nextReactionThreshold = 21000,
				currentStanding = 15000,
			})
			assert.same(
				{ "reputation", "honored", 6000, 12000, 50 },
				{ bar.kind, bar.standing, bar.value, bar.max, bar.percent }
			)
			ns.Data.Reputation(bar, {
				name = "X", reaction = 8, currentReactionThreshold = 42000, nextReactionThreshold = 42000,
			})
			assert.same({ 1, 1, 100 }, { bar.value, bar.max, bar.percent })
			ns.Data.Reputation(bar, nil)
			assert.is_nil(bar.kind)
		end)

		it("splits money", function()
			assert.same({ 123, 45, 67 }, { ns.Data.Money(1234567) })
		end)
	end)
end)
