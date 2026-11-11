-- Made by lunatype from OrdaenApp/index.luna: change the source, not this file.
local R = LunaType
local __make, __class, __inherit = R.make, R.class, R.inherit
local __Ordaen_core = R.addon("Ordaen")["core"]
local __lang_App = R.lang.App
local M = {}
R.addon("OrdaenApp")["index"] = M
local OrdaenApp

OrdaenApp = __class({})

function OrdaenApp.new(__owner)
	local self = setmetatable({}, OrdaenApp)
	R.adopt(__owner, self)
	__Ordaen_core.register("OrdaenSettings", "Ordaen Settings", "Interface/Icons/Trade_Engineering", function()
		return __make("OrdaenSettings", "main", "Settings", self)
	end)
	__Ordaen_core.register("OrdaenMinimap", "Ordaen Minimap", "Interface/Icons/INV_Misc_Map_01", function()
		return __make("OrdaenMinimap", "main", "Minimap", self)
	end)
	__Ordaen_core.register("OrdaenPanel", "Ordaen Panel", "Interface/Icons/INV_Misc_Note_01", function()
		return __make("OrdaenPanel", "main", "Panel", self)
	end)
	__Ordaen_core.register("OrdaenProfessions", "Ordaen Professions", "Interface/Icons/Trade_BlackSmithing", function()
		return __make("OrdaenProfessions", "main", "Professions", self)
	end)
	__Ordaen_core.register("OrdaenTooltips", "Ordaen Tooltips", "Interface/Icons/INV_Misc_Book_09", function()
		return __make("OrdaenTooltips", "main", "Tooltips", self)
	end)
	__Ordaen_core.register("OrdaenDev", "Ordaen Dev", "Interface/Icons/INV_Misc_Gear_01", function()
		return __make("OrdaenDev", "index", "DevWindow", self)
	end)
	__Ordaen_core.start()
	return self
end
__inherit(OrdaenApp, { __lang_App })

M.OrdaenApp = OrdaenApp
R.run(OrdaenApp, "OrdaenApp")
