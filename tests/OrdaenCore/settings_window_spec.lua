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
		assert.are.equal(wow.addons.OrdaenPanel.toc.meta.IconTexture, panel.icon)
		assert.are.equal("Ordaen", ns.Game.Ordaen.title)
		assert.are.equal(wow.addons.OrdaenCore.toc.meta.IconTexture, ns.Game.Ordaen.icon)
		assert.is_string(ns.Game.Ordaen.icon)
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
						local setting = self.attributes.value
						drawn[#drawn + 1] = { kind = kind, value = setting and setting:Get(), module = self.module.name }
						game.ui:Slot(1, "default")
					end,
				})
			end
		end
		for _, kind in ipairs({ "settingsTab", "slider", "dropdown", "section", "checkbox", "switch", "zones", "input" }) do
			library["components/" .. kind] = Probe(kind)
		end
		local module = { name = "OrdaenSpec", ns = {}, cache = {}, Import = function()
			return nil
		end }
		local window = ns.Engine:Mount(nil, ns.Define.Component({
			Setup = function()
				ns.Define.Ephemeral({ tab = { type = "number", default = 5 } })
			end,
			Render = function(game, self)
				game.ui:ModuleSettings(1, { attributes = { module = "OrdaenPanel", tab = self.state.ephemeral.tab:Get() } })
			end,
		}), 0, {}, ns.Game.Layer.Screen, module, ns.Game.ForModule(module))
		ns.Scheduler.Flush()
		assert.are.same({}, wow.errors)
		-- the fifth tab only (the bottom panel's: its height slider among its rows), drawn by the panel's own module
		assert.are.equal("settingsTab", drawn[1].kind)
		local stored = ns.App.Module("OrdaenPanel").root.state.persistent.height
		local height
		for _, d in ipairs(drawn) do
			assert.are.equal("OrdaenPanel", d.module)
			if d.kind == "slider" and d.value == stored then
				height = d.value
			end
		end
		assert.are.equal(stored, height)
		drawn = {}
		window.state.ephemeral.tab:Set(2)
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

describe("a draft of settings changes", function()
	it("stages writes through its views until Save, and Discard drops them", function()
		local wow, ns = Start(nil)
		local draft = ns.Game.Settings:Draft()
		local scale = draft.Settings.scale
		local seen
		local module = { name = "OrdaenSpec", ns = {}, cache = {}, Import = function()
			return nil
		end }
		ns.Engine:Mount(nil, ns.Define.Component({ Setup = function(_, self)
			self:Watch(function()
				seen = scale:Get()
			end)
		end }), 0, {}, ns.Game.Layer.Screen, module, ns.Game.ForModule(module))
		scale:Set(1.2)
		ns.Scheduler.Flush()
		assert.are.equal(1.2, seen)
		assert.are.equal(1, ns.Game.Settings.scale:Peek()) -- not saved yet
		assert.are.equal(1, draft.changed:Peek())
		assert.are.equal("GLOBAL_SCALE", scale:Label())
		scale:Set(1) -- the stored value again: nothing to save
		assert.are.equal(0, draft.changed:Peek())
		scale:Set(1.3)
		assert.has_error(function()
			scale:Set(9) -- checked as the setting checks it
		end)
		draft:Save()
		assert.are.equal(1.3, ns.Game.Settings.scale:Peek())
		assert.are.equal(0, draft.changed:Peek())
		assert.is_true(draft.saved:Peek())
		draft:Rollback()
		assert.are.equal(1, ns.Game.Settings.scale:Peek())
		assert.is_false(draft.saved:Peek())
		draft.Settings.clock:Set("12")
		draft:Discard()
		assert.are.equal("24", draft.Settings.clock:Peek())
		assert.are.same({}, wow.errors)
	end)

	it("is what a module's page binds when the window hands it one", function()
		local wow, ns = Start(nil)
		ns.App.Library()
		local bound = {}
		local function Probe()
			return function(import)
				local Define = import("@ordaen/define")
				return Define.Component({
					Render = function(game, self)
						bound[#bound + 1] = self.attributes.value and self.attributes.value:Get() or false
						game.ui:Slot(1, "default")
					end,
				})
			end
		end
		local library = wow.addons.OrdaenLibrary.ns
		for _, kind in ipairs({ "settingsTab", "slider", "dropdown", "section", "checkbox", "switch", "zones", "input" }) do
			library["components/" .. kind] = Probe()
		end
		local draft = ns.Game.Settings:Draft()
		local module = { name = "OrdaenSpec", ns = {}, cache = {}, Import = function()
			return nil
		end }
		ns.Engine:Mount(nil, ns.Define.Component({
			Render = function(game)
				game.ui:ModuleSettings(1, { attributes = { module = "OrdaenPanel", tab = 5, draft = draft } })
			end,
		}), 0, {}, ns.Game.Layer.Screen, module, ns.Game.ForModule(module))
		ns.Scheduler.Flush()
		local stored = ns.App.Module("OrdaenPanel").root.state.persistent.height
		local height
		for _, b in ipairs(bound) do
			if b == draft:Of(stored) then
				height = b
			end
		end
		assert.are.equal(draft:Of(stored), height)
		height:Set(80)
		assert.are.equal(60, stored:Peek())
		draft:Save()
		assert.are.equal(80, stored:Peek())
		assert.are.same({}, wow.errors)
	end)
end)
