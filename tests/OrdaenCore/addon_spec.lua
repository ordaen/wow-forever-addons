-- OrdaenCore.NewAddon: the addon framework (addons/OrdaenCore/Addon.lua, Settings.lua).
local helpers = require("tests.OrdaenCore.helpers")

describe("OrdaenCore.NewAddon", function()
	local Core, chat

	-- A game event, to every frame registered for it (each addon has its own).
	local fire = helpers.fire

	local function newAddon(spec, ns)
		return Core.NewAddon("TestAddon", ns or {}, spec or {})
	end

	before_each(function()
		chat = {}
		helpers.loggedIn, helpers.inCombat = false, false
		helpers.stubGlobals({
			DEFAULT_CHAT_FRAME = {
				AddMessage = function(_, msg)
					chat[#chat + 1] = msg
				end,
			},
		})
		rawset(_G, "TestAddonDB", nil)
		Core = helpers.loadCore()
	end)

	it("returns nil, after telling the player, when the Core is too old", function()
		helpers.metadata.TestAddon["X-Ordaen-MinCore"] = "99.0"
		Core.isDevBuild = false
		assert.is_nil(newAddon())
		assert.truthy(chat[1]:find("Test Addon", 1, true))
		helpers.metadata.TestAddon["X-Ordaen-MinCore"] = nil
	end)

	it("gives each addon its own event frame, made in NewAddon (WoW bills a handler to the addon that made its frame)",
		function()
			local A = newAddon()
			local framesBefore = #helpers.created
			local B = Core.NewAddon("OtherAddon", {}, {})
			assert.equals(framesBefore + 1, #helpers.created, "NewAddon makes the frame, not the first On")
			local own = helpers.created[#helpers.created]
			local got = {}
			A:On("BAG_UPDATE", function()
				got[#got + 1] = "A"
			end)
			B:On("BAG_UPDATE", function()
				got[#got + 1] = "B"
			end)
			assert.is_true(own.registered.BAG_UPDATE)
			local carriers = 0
			for _, frame in ipairs(helpers.created) do
				carriers = carriers + ((frame.registered or {}).BAG_UPDATE and 1 or 0)
			end
			assert.equals(2, carriers)
			fire("BAG_UPDATE")
			assert.same({ "A", "B" }, got)
		end)

	it("fills the SavedVariables with defaults on its ADDON_LOADED, keeping saved values", function()
		rawset(_G, "TestAddonDB", { scale = 2 })
		local A = newAddon({ db = "TestAddonDB", defaults = { scale = 1, list = { a = 1 }, on = true } })
		local loaded
		A:OnLoad(function(db)
			loaded = db
		end)
		fire("ADDON_LOADED", "SomethingElse")
		assert.is_nil(loaded)
		fire("ADDON_LOADED", "TestAddon")
		assert.equals(rawget(_G, "TestAddonDB"), loaded)
		assert.same({ scale = 2, list = { a = 1 }, on = true }, loaded)
		assert.equals(loaded, A.db)
	end)

	it("copies table defaults instead of sharing them", function()
		local defaults = { list = { a = 1 } }
		local A = newAddon({ db = "TestAddonDB", defaults = defaults })
		fire("ADDON_LOADED", "TestAddon")
		A.db.list.a = 2
		assert.equals(1, defaults.list.a)
	end)

	it("runs OnLogin after OnLoad, at PLAYER_LOGIN", function()
		local A = newAddon({ db = "TestAddonDB" })
		local order = {}
		A:OnLogin(function()
			order[#order + 1] = "login"
		end)
		A:OnLoad(function()
			order[#order + 1] = "load"
		end)
		fire("ADDON_LOADED", "TestAddon")
		assert.same({ "load" }, order)
		fire("PLAYER_LOGIN")
		assert.same({ "load", "login" }, order)
		A:OnLogin(function()
			order[#order + 1] = "late" -- already in the world: runs at once
		end)
		assert.same({ "load", "login", "late" }, order)
	end)

	it("runs OnLogin right after loading when the player is already in the world (load on demand)", function()
		fire("PLAYER_LOGIN") -- the Core loads before login; a load-on-demand addon after it
		local A = newAddon()
		local ran = false
		A:OnLogin(function()
			ran = true
		end)
		fire("ADDON_LOADED", "TestAddon")
		assert.is_true(ran)
	end)

	it("dispatches events to handlers in the order they were added, until Off", function()
		local A = newAddon()
		local seen = {}
		local function first(event, arg)
			seen[#seen + 1] = "first " .. event .. " " .. arg
		end
		A:On("ZONE_CHANGED", first)
		A:On("ZONE_CHANGED", function(_, arg)
			seen[#seen + 1] = "second " .. arg
		end)
		fire("ZONE_CHANGED", "x")
		A:Off("ZONE_CHANGED", first)
		fire("ZONE_CHANGED", "y")
		assert.same({ "first ZONE_CHANGED x", "second x", "second y" }, seen)
	end)

	it("keeps running the other handlers when one fails (securecallfunction)", function()
		local reported = {}
		rawset(_G, "securecallfunction", function(fn, ...)
			local ok, err = pcall(fn, ...)
			if not ok then
				reported[#reported + 1] = err
			end
		end)
		Core = helpers.loadCore() -- picks up securecallfunction
		local A = newAddon()
		local ran = false
		A:On("ZONE_CHANGED", function()
			error("boom")
		end)
		A:On("ZONE_CHANGED", function()
			ran = true
		end)
		fire("ZONE_CHANGED")
		assert.is_true(ran)
		assert.equals(1, #reported)
		rawset(_G, "securecallfunction", nil)
	end)

	it("holds AfterCombat work until combat ends, then runs it once", function()
		local A = newAddon()
		local runs = 0
		A:AfterCombat(function()
			runs = runs + 1
		end)
		assert.equals(1, runs) -- not in combat: right away
		helpers.inCombat = true
		A:AfterCombat(function()
			runs = runs + 1
		end)
		assert.equals(1, runs)
		helpers.inCombat = false
		fire("PLAYER_REGEN_ENABLED")
		fire("PLAYER_REGEN_ENABLED")
		assert.equals(2, runs)
	end)

	describe("slash commands", function()
		local A

		before_each(function()
			A = newAddon({ db = "TestAddonDB", defaults = { scale = 1 }, slash = { "/ta", "/testaddon" } })
			fire("ADDON_LOADED", "TestAddon")
		end)

		it("registers every alias", function()
			assert.equals("/ta", rawget(_G, "SLASH_TESTADDON1"))
			assert.equals("/testaddon", rawget(_G, "SLASH_TESTADDON2"))
		end)

		it("runs commands with the rest of the line", function()
			local got
			A:Command("Say", function(rest)
				got = rest
			end)
			SlashCmdList.TESTADDON("say hello there ")
			assert.equals("hello there", got)
		end)

		it("resets the settings to the defaults, then runs OnReset", function()
			A.db.scale = 3
			A.db.extra = true
			local reset = false
			A:OnReset(function()
				reset = true
			end)
			SlashCmdList.TESTADDON("reset")
			assert.same({ scale = 1 }, A.db)
			assert.equals(rawget(_G, "TestAddonDB"), A.db)
			assert.is_true(reset)
		end)

		it("prints help for unknown commands", function()
			A:Command("say", function() end, "HELP_SAY")
			SlashCmdList.TESTADDON("what")
			local text = table.concat(chat, "\n")
			assert.truthy(text:find("/ta reset", 1, true))
			assert.truthy(text:find("HELP_SAY", 1, true)) -- an unknown locale key shows as itself
		end)
	end)

	it("keeps declared settings valid", function()
		local A = newAddon({
			db = "TestAddonDB",
			defaults = { style = "a", scale = 1, columns = 6, on = true },
			settings = {
				{ key = "style", label = "STYLE", choices = { { id = "a", label = "A" }, { id = "b", label = "B" } } },
				{ key = "scale", label = "SCALE", min = 0.8, max = 1.6, step = 0.05 },
				{ key = "columns", label = "COLUMNS", min = 2, max = 12, step = 1 },
				{ key = "on", label = "ON" },
			},
		})
		rawset(_G, "TestAddonDB", { style = "gone", scale = 9, columns = 3.6, on = "yes" })
		fire("ADDON_LOADED", "TestAddon")
		assert.same({ style = "a", scale = 1.6, columns = 4, on = true }, A.db)
	end)

	it("handles dotted keys (nested tables), and reset keeps the nested tables settings are bound to", function()
		local A = newAddon({
			db = "TestAddonDB",
			slash = { "/ta" },
			defaults = { ui = { theme = "a", size = 12 } },
			settings = {
				{ key = "ui.theme", label = "THEME", choices = { { id = "a", label = "A" }, { id = "b", label = "B" } } },
				{ key = "ui.size", label = "SIZE", min = 10, max = 16, step = 1 },
			},
		})
		rawset(_G, "TestAddonDB", { ui = { theme = "gone", size = 40 } })
		fire("ADDON_LOADED", "TestAddon")
		assert.same({ ui = { theme = "a", size = 16 } }, A.db)
		local ui = A.db.ui
		ui.theme, ui.extra = "b", true
		SlashCmdList.TESTADDON("reset")
		assert.equals(ui, A.db.ui, "the same table, so a control bound to it keeps working")
		assert.same({ theme = "a", size = 12 }, A.db.ui)
	end)

	it("adds an addon compartment entry that passes the mouse button on", function()
		local registered
		rawset(_G, "AddonCompartmentFrame", {
			RegisterAddon = function(_, info)
				registered = info
			end,
		})
		local A = newAddon()
		local clicked
		A:Compartment({
			onClick = function(button)
				clicked = button
			end,
		})
		assert.equals("Test Addon", registered.text)
		registered.func(nil, { buttonName = "RightButton" })
		assert.equals("RightButton", clicked)
		rawset(_G, "AddonCompartmentFrame", nil)
	end)
end)
