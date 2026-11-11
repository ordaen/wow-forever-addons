-- Made by lunatype from OrdaenLibrary/input.luna: change the source, not this file.
local R = LunaType
local __get, __cell, __class, __inherit, __el, __attr, __bind, __template, __input, __draw = R.get, R.cell, R.class, R.inherit, R.el, R.attr, R.bind, R.template, R.input, R.draw
local __OrdaenLibrary_settingRow_SettingRow = R.addon("OrdaenLibrary")["settingRow"].SettingRow
local __Ordaen_module_Component = R.addon("Ordaen")["module"].Component
local M = {}
R.addon("OrdaenLibrary")["input"] = M
local INK, FILL, EDGE, PADDING, Input

local function __b5(self)
	return __get(self.disabled)
end

local function __d3(self, parent)
	local __e4 = __el(parent, "input")
	__input(__e4, self.value)
	__attr(__e4, "width", 250)
	__attr(__e4, "height", 25)
	__attr(__e4, "padding", PADDING)
	__attr(__e4, "background", FILL)
	__attr(__e4, "border", EDGE)
	__attr(__e4, "textColor", INK)
	__attr(__e4, "textSize", 11.666666666666668)
	__attr(__e4, "maxLength", self.maxLength)
	__bind(__e4, "disabled", __b5, self)
end

local function __d1(self, parent)
	local __c2 = __OrdaenLibrary_settingRow_SettingRow.new(parent, self.label, self.hint, self.disabled)
	__draw(parent, __c2, { self = self, [""] = __d3 })
end

INK = { r = 0.910, g = 0.863, b = 0.769, a = 1 }
FILL = { r = 0.051, g = 0.039, b = 0.031, a = 1 }
EDGE = { width = 0.8333333333333334, color = { r = 0.290, g = 0.227, b = 0.141, a = 1 } }
PADDING = { right = 8.333333333333334, left = 8.333333333333334 }

Input = __class({})

function Input.new(__owner, label, value, maxLength, hint, disabled)
	local self = setmetatable({}, Input)
	R.adopt(__owner, self)
	if maxLength == nil then maxLength = nil end
	if hint == nil then hint = __cell("") end
	if disabled == nil then disabled = __cell(false) end
	self.label = label
	self.value = value
	self.maxLength = maxLength
	self.hint = hint
	self.disabled = disabled
	return self
end

function Input:render()
	return __template(__d1, self)
end
__inherit(Input, { __Ordaen_module_Component })

M.INK = INK
M.FILL = FILL
M.EDGE = EDGE
M.PADDING = PADDING
M.Input = Input
