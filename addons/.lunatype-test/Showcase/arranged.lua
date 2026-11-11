-- Made by lunatype from Showcase/arranged.luna: change the source, not this file.
local R = LunaType
local __cell, __class, __inherit, __template, __draw = R.cell, R.class, R.inherit, R.template, R.draw
local __OrdaenLibrary_zones_Zones = R.addon("OrdaenLibrary")["zones"].Zones
local __Ordaen_module_Component = R.addon("Ordaen")["module"].Component
local M = {}
R.addon("Showcase")["arranged"] = M
local PARTS, ZONES, OFF, Arranged

local function __d1(self, parent)
	local __c2 = __OrdaenLibrary_zones_Zones.new(parent, PARTS, ZONES, OFF, self.places)
	__draw(parent, __c2, nil)
end

PARTS = { { key = "clock", label = "Clock", hint = "The time of day." }, { key = "money", label = "Money" }, { key = "friends", label = "Friends", hint = "How many are online." } }
ZONES = { { value = "left", label = "Left" }, { value = "middle", label = "Middle" }, { value = "right", label = "Right" } }
OFF = { value = "off", label = "Not on the panel" }

Arranged = __class({})

function Arranged.new(__owner)
	local self = setmetatable({}, Arranged)
	R.adopt(__owner, self)
	self.places = __cell({ ["clock"] = "left", ["money"] = "right", ["friends"] = "off" })
	return self
end

function Arranged:render()
	return __template(__d1, self)
end
__inherit(Arranged, { __Ordaen_module_Component })

M.PARTS = PARTS
M.ZONES = ZONES
M.OFF = OFF
M.Arranged = Arranged
