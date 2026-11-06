-- Loads an addon file the way WoW does: as a chunk called with (addonName, namespaceTable).
local function loadAddonFile(path)
	local ns = {}
	assert(loadfile(path))("OrdaenMinimap", ns)
	return ns
end

describe("IsMinimapButtonName", function()
	local ns = loadAddonFile("addons/OrdaenMinimap/Names.lua")

	it("accepts typical addon minimap button names", function()
		for _, name in ipairs({
			"LibDBIcon10_Details",
			"AtlasLootMinimapButton",
			"Bagnon_MinimapFrame",
			"Foo-Minimap-Button",
			"SomeAddonMinimap",
		}) do
			assert.is_true(ns.IsMinimapButtonName(name), name)
		end
	end)

	it("rejects names ending in digits", function()
		assert.is_false(ns.IsMinimapButtonName("HandyNotesPin12"))
		assert.is_false(ns.IsMinimapButtonName("SomeMinimapButton3"))
	end)

	it("rejects unrelated and missing names", function()
		assert.is_false(ns.IsMinimapButtonName("MinimapZoomIn"))
		assert.is_false(ns.IsMinimapButtonName(""))
		assert.is_false(ns.IsMinimapButtonName(nil))
	end)

	it("accepts the two buttons that ignore the square shape", function()
		assert.is_true(ns.IsMinimapButtonName("AltoholicMinimapButton"))
		assert.is_true(ns.IsMinimapButtonName("AutoBiographer_MinimapButton"))
	end)

	it("rejects map pins and waypoints", function()
		assert.is_false(ns.IsMinimapButtonName("Questie_MinimapFrame"))
		assert.is_false(ns.IsMinimapButtonName("HandyNotes_Minimap"))
		assert.is_false(ns.IsMinimapButtonName("TomTomMinimapIcon"))
		assert.is_false(ns.IsMinimapButtonName("GatherLiteMinimapIcon"))
	end)

	it("accepts TomCats buttons even though they end in the year", function()
		assert.is_true(ns.IsMinimapButtonName("TomCats-MinimapButton2026"))
	end)
end)

describe("LibDBIconObjectName", function()
	local ns = {}
	assert(loadfile("addons/OrdaenMinimap/Names.lua"))("OrdaenMinimap", ns)

	it("extracts the data object name", function()
		assert.equals("Details", ns.LibDBIconObjectName("LibDBIcon10_Details"))
		assert.is_nil(ns.LibDBIconObjectName("AltoholicMinimapButton"))
		assert.is_nil(ns.LibDBIconObjectName(nil))
	end)
end)

describe("ButtonAddonName", function()
	local ns = loadAddonFile("addons/OrdaenMinimap/Names.lua")

	it("names the addon behind a minimap button, so one addon gets one square in the drawer", function()
		assert.equals("Details", ns.ButtonAddonName("LibDBIcon10_Details"))
		assert.equals("Altoholic", ns.ButtonAddonName("AltoholicMinimapButton"))
		assert.equals("AutoBiographer", ns.ButtonAddonName("AutoBiographer_MinimapButton"))
		assert.equals("Questie", ns.ButtonAddonName("Questie-Minimap-Icon"))
		assert.equals("Foo", ns.ButtonAddonName("Foo_MinimapIcon"))
		assert.equals("Bar", ns.ButtonAddonName("BarMinimap"))
		assert.is_nil(ns.ButtonAddonName("MinimapButton"))
		assert.is_nil(ns.ButtonAddonName(nil))
	end)
end)
