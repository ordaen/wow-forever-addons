-- Made by lunatype from OrdaenMinimap/index.luna: change the source, not this file.
local R = LunaType
local __OrdaenMinimap_main_Minimap = R.addon("OrdaenMinimap")["main"].Minimap
local __OrdaenMinimap_settings_MapPage = R.addon("OrdaenMinimap")["settings"].MapPage
local __OrdaenMinimap_settings_DrawerPage = R.addon("OrdaenMinimap")["settings"].DrawerPage
local M = {}
R.addon("OrdaenMinimap")["index"] = M

M.Minimap = __OrdaenMinimap_main_Minimap
M.MapPage = __OrdaenMinimap_settings_MapPage
M.DrawerPage = __OrdaenMinimap_settings_DrawerPage
