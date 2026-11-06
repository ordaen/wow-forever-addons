-- Drives the Ordaen Dev window against stubbed frames: catches typos and wrong call order in the
-- UI code. How it looks is checked in game.
local helpers = require("tests.OrdaenCore.helpers")

describe("OrdaenCore_Debug UI", function()
	local ns, UI, Store, chat

	before_each(function()
		chat = {}
		helpers.stubGlobals({
			DEFAULT_CHAT_FRAME = {
				AddMessage = function(_, msg)
					chat[#chat + 1] = msg
				end,
			},
		})
		helpers.loadCore(true)
		ns = helpers.debugNs
		UI, Store = ns.UI, ns.Store
		UI.OnEvent(nil, "ADDON_LOADED", "OrdaenCore_Debug")
		UI.OnEvent(nil, "PLAYER_LOGIN")
	end)

	local function window()
		return rawget(_G, "OrdaenDevWindow")
	end

	it("loads the SavedVariables and builds the button at login", function()
		assert.are.equal(1, rawget(_G, "OrdaenCoreDebugDB").session)
		assert.is_not_nil(rawget(_G, "OrdaenDevButton"))
	end)

	it("badges new errors and announces our own once in chat", function()
		Store.AddError({ message = "Interface/AddOns/OrdaenMinimap/Map.lua:1: ours" })
		Store.AddError({ message = "Interface/AddOns/OrdaenMinimap/Map.lua:1: ours" })
		Store.AddError({ message = "Interface/AddOns/Details/x.lua:1: theirs" })
		assert.are.equal("2", rawget(_G, "OrdaenDevButton").badge:GetText())
		assert.are.equal(1, #chat)
		assert.truthy(chat[1]:find("OrdaenMinimap", 1, true))
	end)

	it("opens on the Errors tab, shows the newest error and marks errors seen", function()
		Store.AddError({ message = "Interface/AddOns/OrdaenMinimap/Map.lua:1: first" })
		Store.AddError({ message = "Interface/AddOns/OrdaenMinimap/Map.lua:2: second" })
		OrdaenCoreDebug_OnAddonCompartmentClick()
		assert.is_true(window():IsShown())
		local panel = window().panels.errors
		assert.is_true(panel:IsShown())
		assert.truthy(panel.detail:GetText():find("second", 1, true))
		assert.are.equal(0, Store.NewCount())
		assert.are.equal("", rawget(_G, "OrdaenDevButton").badge:GetText())
	end)

	it("filters, clears and raises a test error from its buttons", function()
		SlashCmdList.ORDAENDEV()
		local panel = window().panels.errors
		panel.testButton.scripts.OnClick()
		local entry = Store.Get().errors[1]
		assert.truthy(entry.source:find("^OrdaenCore"))
		assert.truthy(entry.message:find("Ordaen Dev test error", 1, true))
		assert.truthy(panel.detail:GetText():find("Ordaen Dev test error", 1, true))

		panel.filterButtons[3].scripts.OnClick() -- "Other addons"
		assert.are.equal("other", Store.Get().ui.filter)
		assert.are.equal("", panel.detail:GetText())

		panel.clearButton.scripts.OnClick()
		assert.are.same({}, Store.Get().errors)
	end)

	it("refreshes for a repeating error at most once per batch, not on every repeat", function()
		local timers = {}
		rawset(_G, "C_Timer", {
			After = function(_, fn)
				timers[#timers + 1] = fn
			end,
		})
		UI.Toggle()
		local loop = "Interface/AddOns/OrdaenMinimap/Drawer.lua:401: attempt to call a nil value"
		Store.AddError({ message = loop })
		for _ = 1, 100 do
			Store.AddError({ message = loop })
		end
		assert.are.equal(1, #timers)
		local panel = window().panels.errors
		assert.truthy(panel.detail:GetText():find(": x1,", 1, true))
		timers[1]()
		assert.truthy(panel.detail:GetText():find(": x101,", 1, true))
	end)

	it("switches tabs", function()
		UI.Toggle()
		window().tabs[2].scripts.OnClick()
		assert.is_true(window().panels.perf:IsShown())
		assert.is_false(window().panels.errors:IsShown())
	end)

	it("saves dumps and the note for Claude, then reloads", function()
		local debug = OrdaenCore.NewDebug("TestAddon")
		debug.Init({}, {
			dump = function()
				return { scale = 1.2 }
			end,
		})
		UI.Toggle()
		window().note:SetText("drawer overlaps the clock")
		window().saveButton.scripts.OnClick()
		local db = Store.Get()
		assert.are.equal("drawer overlaps the clock", db.saves[1].note)
		assert.are.same({ scale = 1.2 }, db.addons.TestAddon.dump.state)
		assert.is_true(helpers.reloaded)
	end)
end)
