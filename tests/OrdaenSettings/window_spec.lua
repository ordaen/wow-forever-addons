-- The settings window (addons/OrdaenSettings; design settings/) on the fake client, as built, with Ordaen Panel: a bare
-- /ordaen loads it and opens the window; its list (General, the modules with their switches); General's tabs and rows
-- bound to the global settings; a module's page in its tabs; a module that's off shows only that it's off.
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
	local wow = Fake.New({ dist = DIST, addons = { "OrdaenCore", "OrdaenPanel", "OrdaenLibrary", "OrdaenSettings" } })
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

-- every text drawn on the dialog layer (the window's), and every box there
local function walk(ns, fn)
	local function go(node)
		fn(node)
		for i = 1, node.count or 0 do
			go(node.children[i])
		end
	end
	go(ns.Game.Layer.Dialog.node)
end
local function texts(ns)
	local out = {}
	walk(ns, function(node)
		if node.kind == "text" then
			out[node.fs:GetText()] = node
		end
	end)
	return out
end
local function click(node)
	local frame = node.frame
	frame:GetScript("OnClick")(frame, "LeftButton")
end

describe("the settings window", function()
	it("isn't loaded at login, and a bare /ordaen loads it and opens the window on General", function()
		local wow, ns = Start(nil)
		assert.is_false(wow.addons.OrdaenSettings.loaded)
		wow:Slash("/ordaen")
		ns.Scheduler.Flush()
		assert.is_true(wow.addons.OrdaenSettings.loaded)
		local t = texts(ns)
		assert.is_truthy(t["General"]) -- the list's own entry
		assert.is_truthy(t["Panel"]) -- the module, its title without "Ordaen "
		assert.is_truthy(t["Scale"] and t["Numbers"] and t["Behaviour"]) -- General's tabs
		assert.is_truthy(t["Ordaen window scale"]) -- the scale's row, bound to the global
		assert.is_truthy(t["100%"])
		assert.are.same({}, wow.errors)
	end)

	it("shows a module's page when its entry is picked, and that it's off when it is", function()
		local wow, ns = Start(nil)
		wow:Slash("/ordaen")
		ns.Scheduler.Flush()
		click(texts(ns)["Panel"].parent)
		ns.Scheduler.Flush()
		local t = texts(ns)
		assert.is_falsy(t["Ordaen window scale"]) -- General's rows are gone
		assert.is_truthy(t["Micro menu"] and t["Bottom panel"]) -- the Panel's tabs, from its page description
		assert.is_truthy(t["Menu icons"] and t["Character button"]) -- its first tab's rows
		assert.is_falsy(t["Height"]) -- not the second tab's
		assert.are.same({}, wow.errors)
		-- turned off from its switch: off now, its page says so
		local panel
		for _, entry in ipairs(ns.Game.Modules) do
			if entry.folder == "OrdaenPanel" then
				panel = entry
			end
		end
		panel:Enable(false)
		ns.Scheduler.Flush()
		t = texts(ns)
		local off = false
		for text in pairs(t) do
			if text:find("module is off", 1, true) then
				off = true
			end
		end
		assert.is_true(off)
		assert.are.same({}, wow.errors)
	end)
end)
