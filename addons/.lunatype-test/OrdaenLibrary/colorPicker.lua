-- Made by lunatype from OrdaenLibrary/colorPicker.luna: change the source, not this file.
local R = LunaType
local __get, __set, __cell, __listen, __class, __inherit, __el, __attr, __bind, __on, __template, __draw = R.get, R.set, R.cell, R.listen, R.class, R.inherit, R.el, R.attr, R.bind, R.on, R.template, R.draw
local __game__ColorPicker_picked = R.game.ColorPicker.picked
local __game__ColorPicker_cancelled = R.game.ColorPicker.cancelled
local __game__ColorPicker_open = R.game.ColorPicker.open
local __OrdaenLibrary_settingRow_SettingRow = R.addon("OrdaenLibrary")["settingRow"].SettingRow
local __Ordaen_module_Component = R.addon("Ordaen")["module"].Component
local M = {}
R.addon("OrdaenLibrary")["colorPicker"] = M
local EDGE, ColorPicker

local function __b5(self)
	return __get(self.value)
end

local function __d3(self, parent)
	local __e4 = __el(parent, "box")
	__attr(__e4, "width", 36.66666666666667)
	__attr(__e4, "height", 18.333333333333336)
	__attr(__e4, "border", EDGE)
	__bind(__e4, "background", __b5, self)
	__on(__e4, "click", self, self.open)
end

local function __d1(self, parent)
	local __c2 = __OrdaenLibrary_settingRow_SettingRow.new(parent, self.label, self.hint, self.disabled)
	__draw(parent, __c2, { self = self, [""] = __d3 })
end

EDGE = { width = 0.8333333333333334, color = { r = 0.424, g = 0.333, b = 0.208, a = 1 } }

ColorPicker = __class({})

function ColorPicker.new(__owner, label, value, hint, disabled)
	local self = setmetatable({ ticket = 0 }, ColorPicker)
	R.adopt(__owner, self)
	if hint == nil then hint = __cell("") end
	if disabled == nil then disabled = __cell(false) end
	self.label = label
	self.value = value
	self.hint = hint
	self.disabled = disabled
	self.before = nil
	__listen(__game__ColorPicker_picked, self, self["onPicked$PickedColor"])
	__listen(__game__ColorPicker_cancelled, self, self.onCancelled)
	return self
end

function ColorPicker:open()
	if __get(self.disabled) then
		return
	end
	self.before = __get(self.value)
	self.ticket = __game__ColorPicker_open(__get(self.value))
end

function ColorPicker:onPicked(picked)
	if picked.ticket == self.ticket then
		__set(self.value, picked.color)
	end
end

function ColorPicker:onCancelled(ticket)
	local before = self.before
	if ticket == self.ticket and before ~= nil then
		__set(self.value, before)
	end
end

function ColorPicker:render()
	return __template(__d1, self)
end

ColorPicker["onPicked$PickedColor"] = function(self, __picked_ticket, __picked_color)
	if __picked_ticket == self.ticket then
		__set(self.value, __picked_color)
	end
end
__inherit(ColorPicker, { __Ordaen_module_Component })

M.EDGE = EDGE
M.ColorPicker = ColorPicker
