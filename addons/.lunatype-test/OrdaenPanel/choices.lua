-- Made by lunatype from OrdaenPanel/choices.luna: change the source, not this file.
local R = LunaType
local M = {}
R.addon("OrdaenPanel")["choices"] = M
local DEFAULTS
DEFAULTS = { microOn = true, statusOn = true, bottomOn = true, microIcons = "upscaled", charButton = "portrait", outline = "none", shadow = true, edge = "bottom", fit = "full", height = 60, places = { ["micromenu"] = "left", ["social"] = "left", ["experience"] = "center", ["zone"] = "off", ["clock"] = "off", ["currencies"] = "right", ["bags"] = "right" }, show = "always", combat = "any", vehicle = true, petBattle = true, resting = false, fadedAlpha = 0 }

M.DEFAULTS = DEFAULTS
