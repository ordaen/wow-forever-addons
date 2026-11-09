-- What the settings window (OrdaenSettings) gets from Ordaen, on the fake client as built: the module list with each
-- module's on/off (`game.Modules`, addons/OrdaenCore/App.lua), a module's page in its own context, one tab of it
-- (`game.ui:ModuleSettings`, Draw.lua), and a setting's texts by the build's locale keys (State.lua, Label/Tip/
-- ChoiceLabel).
local Fake = require("tests.fake.wow")

local DIST = ".ordaen/check/dist"

-- Blizzard's frames Ordaen Panel takes, as FrameXML makes them before any addon loads
local BLIZZARD = {
	"CharacterMicroButton", "ProfessionMicroButton", "SpellbookMicroButton", "TalentMicroButton", "LegacyMicroButton",
	"QuestLogMicroButton", "GuildMicroButton", "LFDMicroButton", "CollectionsMicroButton", "MainMenuMicroButton",
	"QuickJoinToastButton", "MainMenuBarBackpackButton", "CharacterBag0Slot", "CharacterBag1Slot", "CharacterBag2Slot",
	"CharacterBag3Slot",
}

local function Start(db)
	local wow = Fake.New({ dist = DIST, addons = { "OrdaenCore", "OrdaenPanel", "OrdaenLibrary" } })
	local home = wow.env.CreateFrame("Frame", "BagsBar", wow.env.UIParent)
	for _, name in ipairs(BLIZZARD) do
		local f = wow.env.CreateFrame("Button", name, home)
		f:SetSize(45, 45)
		f:SetPoint("CENTER", home, "CENTER", 0, 0)
	end
	wow.env.OrdaenCoreDB = db
	wow:Login()
	wow:Tick()
	return wow, wow.addons.OrdaenCore.ns
end

local function Panel(ns)
	for _, entry in ipairs(ns.Game.Modules) do
		if entry.folder == "OrdaenPanel" then
			return entry
		end
	end
end

describe("the module list", function()
	it("lists the modules with their title, on and running", function()
		local wow, ns = Start(nil)
		local panel = Panel(ns)
		assert.are.equal("Ordaen Panel", panel.title)
		assert.is_true(panel.on:Get())
		assert.is_true(panel.loaded:Get())
		assert.is_nil(panel.reason:Get())
		assert.is_false(panel.pending:Get())
		assert.are.same({}, wow.errors)
	end)

	it("keeps a module that is off unloaded, and turning it on loads it now", function()
		local wow, ns = Start({ off = { OrdaenPanel = true } })
		local panel = Panel(ns)
		assert.is_false(panel.on:Get())
		assert.is_false(panel.loaded:Get())
		assert.is_false(wow.addons.OrdaenPanel.loaded)
		panel:Enable(true)
		assert.is_true(panel.loaded:Get())
		assert.is_nil(wow.env.OrdaenCoreDB.off) -- only what's off is stored
		assert.are.same({}, wow.errors)
	end)

	it("stores off at once and keeps the module running until /reload", function()
		local wow, ns = Start(nil)
		local panel = Panel(ns)
		panel:Enable(false)
		assert.are.same({ OrdaenPanel = true }, wow.env.OrdaenCoreDB.off)
		assert.is_false(panel.on:Get())
		assert.is_true(panel.loaded:Get())
		assert.is_true(panel.pending:Get())
		panel:Enable(true)
		assert.is_false(panel.pending:Get())
	end)
end)

describe("a module's settings page", function()
	it("draws one tab of it in the module's own context, its controls bound to the module's settings", function()
		local wow, ns = Start(nil)
		ns.App.Library() -- loaded first: loading it would put its own controls back over the probes
		local library = wow.addons.OrdaenLibrary.ns
		local drawn = {}
		local function Probe(kind)
			return function(import)
				local Define = import("@ordaen/define")
				return Define.Component({
					Render = function(game, self)
						local value = self.attributes.value:Get()
						drawn[#drawn + 1] = { kind = kind, value = value, module = self.module.name }
						game.ui:Slot(1, "default")
					end,
				})
			end
		end
		library["components/settingsTab"] = Probe("tab")
		library["components/slider"] = Probe("slider")
		library["components/dropdown"] = Probe("dropdown")
		local module = { name = "OrdaenSpec", ns = {}, cache = {}, Import = function()
			return nil
		end }
		local window = ns.Engine:Mount(nil, ns.Define.Component({
			Setup = function()
				ns.Define.Ephemeral({ tab = { type = "number", default = 2 } })
			end,
			Render = function(game, self)
				game.ui:ModuleSettings(1, { attributes = { module = "OrdaenPanel", tab = self.state.ephemeral.tab:Get() } })
			end,
		}), 0, {}, ns.Game.Layer.Screen, module, ns.Game.ForModule(module))
		ns.Scheduler.Flush()
		assert.are.same({}, wow.errors)
		-- the second tab only (its height slider), drawn by the panel's own module
		assert.are.equal(2, #drawn)
		assert.are.equal("tab", drawn[1].kind)
		assert.are.equal("slider", drawn[2].kind)
		assert.are.equal("OrdaenPanel", drawn[2].module)
		local height = drawn[2].value
		assert.are.equal(ns.App.Module("OrdaenPanel").root.state.persistent.height, height)
		drawn = {}
		window.state.ephemeral.tab:Set(1)
		ns.Scheduler.Flush()
		assert.are.equal("dropdown", drawn[#drawn].kind)
		assert.are.same({}, wow.errors)
	end)
end)

describe("a setting's texts", function()
	it("come from the declaring module's locales by the build's keys, a global's from the settings window's", function()
		local wow, ns = Start(nil)
		local state = ns.App.Module("OrdaenPanel").root.state.persistent
		wow.addons.OrdaenPanel.ns.locales.PANEL_HEIGHT = "Height"
		assert.are.equal("Height", state.height:Label())
		assert.are.equal(wow.addons.OrdaenPanel.ns.locales.PANEL_HEIGHT_TIP, state.height:Tip())
		assert.are.equal("PANEL_CHARBUTTON_SPEC", state.charButton:ChoiceLabel("spec")) -- a missing text: its key
		assert.are.equal("GLOBAL_NUMBERFORMAT", ns.Game.Settings.numberFormat:Label())
	end)
end)
