-- Made by lunatype from Showcase/tinted.luna: change the source, not this file.
local R = LunaType
local __cell, __lens, __class, __inherit, __el, __attr, __template, __draw = R.cell, R.lens, R.class, R.inherit, R.el, R.attr, R.template, R.draw
local __OrdaenLibrary_colorPicker_ColorPicker = R.addon("OrdaenLibrary")["colorPicker"].ColorPicker
local __Ordaen_module_Component = R.addon("Ordaen")["module"].Component
local M = {}
R.addon("Showcase")["tinted"] = M
local Tinted

local function __d1(self, parent)
	local __e2 = __el(parent, "box")
	__attr(__e2, "columns", 1)
	__attr(__e2, "gap", 8)
	local __c3 = __OrdaenLibrary_colorPicker_ColorPicker.new(__e2, __cell("The frame"), __lens(__e2, self.tints, "frame"), __cell("Its metal."), nil)
	__draw(__e2, __c3, nil)
	local __c4 = __OrdaenLibrary_colorPicker_ColorPicker.new(__e2, __cell("The text"), __lens(__e2, self.tints, "text"), nil, nil)
	__draw(__e2, __c4, nil)
	local __c5 = __OrdaenLibrary_colorPicker_ColorPicker.new(__e2, __cell("Greyed"), __lens(__e2, self.tints, "text"), nil, __cell(true))
	__draw(__e2, __c5, nil)
end


Tinted = __class({})

function Tinted.new(__owner)
	local self = setmetatable({}, Tinted)
	R.adopt(__owner, self)
	self.tints = __cell({ frame = { r = 0.502, g = 0.251, b = 0.125, a = 1 }, text = { r = 0.953, g = 0.882, b = 0.722, a = 1 } })
	return self
end

function Tinted:render()
	return __template(__d1, self)
end
__inherit(Tinted, { __Ordaen_module_Component })

M.Tinted = Tinted
