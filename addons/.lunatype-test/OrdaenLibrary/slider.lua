-- Made by lunatype from OrdaenLibrary/slider.luna: change the source, not this file.
local R = LunaType
local __get, __getKey, __set, __cell, __computed, __class, __inherit, __el, __attr, __bind, __on, __template, __draw = R.get, R.getKey, R.set, R.cell, R.computed, R.class, R.inherit, R.el, R.attr, R.bind, R.on, R.template, R.draw
local __string_format = R.string.format
local __math_round = R.math.round
local __string_of = R.string.of
local __math_max = R.math.max
local __math_min = R.math.min
local __OrdaenLibrary_settingRow_SettingRow = R.addon("OrdaenLibrary")["settingRow"].SettingRow
local __Ordaen_core = R.addon("Ordaen")["core"]
local __Ordaen_module_Component = R.addon("Ordaen")["module"].Component
local M = {}
R.addon("OrdaenLibrary")["slider"] = M
local LENGTH, BAND, GROOVE, EDGE, GROOVE_TOP, KNOB_W, KNOB_H, KNOB_SHADOW, WHITE, Slider

local function __c1(self)
	local __t2
	if self.most > self.least then
		__t2 = (__get(self.value) - self.least) / (self.most - self.least)
	else
		__t2 = 0
	end
	return __t2
end

local function __c3(self)
	return __get(self.fraction) * 198.33333333333334
end

local function __c4(self)
	return __get(self.fraction) * 200 - 6.666666666666667
end

local function __c5(self)
	return self:format()
end

local function __b13(self)
	return __getKey(__Ordaen_core.theme, "ctl").groove
end

local function __b15(self)
	return __get(self.fillWidth)
end

local function __b16(self)
	return __getKey(__Ordaen_core.theme, "ctl").sliderFill
end

local function __b18(self)
	return __get(self.knobLeft)
end

local function __b19(self)
	return __getKey(__Ordaen_core.theme, "ctl").sliderKnob
end

local function __b21(self)
	return __get(self.shown)
end

local function __d9(self, parent)
	local __e10 = __el(parent, "box")
	__attr(__e10, "columns", { 200, "auto" })
	__attr(__e10, "gap", 10)
	__attr(__e10, "yAlign", "center")
	local __e11 = __el(__e10, "box")
	__attr(__e11, "width", 200)
	__attr(__e11, "height", 16.666666666666668)
	__on(__e11, "click", self, self.onClick)
	__on(__e11, "dragStart", self, self.onDrag)
	__on(__e11, "drag", self, self.onDrag)
	local __e12 = __el(__e11, "box")
	__attr(__e12, "position", "absolute")
	__attr(__e12, "left", 0)
	__attr(__e12, "top", 5)
	__attr(__e12, "width", 200)
	__attr(__e12, "height", 6.666666666666667)
	__bind(__e12, "background", __b13, self)
	local __e14 = __el(__e11, "box")
	__attr(__e14, "position", "absolute")
	__attr(__e14, "left", 0.8333333333333334)
	__attr(__e14, "top", 5.833333333333333)
	__attr(__e14, "height", 5)
	__bind(__e14, "width", __b15, self)
	__bind(__e14, "background", __b16, self)
	local __e17 = __el(__e11, "box")
	__attr(__e17, "position", "absolute")
	__bind(__e17, "left", __b18, self)
	__attr(__e17, "top", -1.6666666666666667)
	__attr(__e17, "width", 13.333333333333334)
	__attr(__e17, "height", 26.666666666666668)
	__bind(__e17, "background", __b19, self)
	__attr(__e17, "shadow", KNOB_SHADOW)
	local __e20 = __el(__e10, "text")
	__bind(__e20, "value", __b21, self)
	__attr(__e20, "textColor", WHITE)
end

local function __d7(self, parent)
	local __c8 = __OrdaenLibrary_settingRow_SettingRow.new(parent, self.label, self.hint, self.disabled)
	__draw(parent, __c8, { self = self, [""] = __d9 })
end

LENGTH = 200
BAND = 16.666666666666668
GROOVE = 6.666666666666667
EDGE = 0.8333333333333334
GROOVE_TOP = 5
KNOB_W = 13.333333333333334
KNOB_H = 26.666666666666668
KNOB_SHADOW = { color = { r = 0, g = 0, b = 0, a = 0.549 }, x = 0, y = 1.6666666666666667, size = 2.5 }
WHITE = { r = 1, g = 1, b = 1, a = 1 }

Slider = __class({})

function Slider.new(__owner, label, value, least, most, step, unit, hint, disabled)
	local self = setmetatable({}, Slider)
	R.adopt(__owner, self)
	if step == nil then step = 1 end
	if unit == nil then unit = "none" end
	if hint == nil then hint = __cell("") end
	if disabled == nil then disabled = __cell(false) end
	self.label = label
	self.value = value
	self.least = least
	self.most = most
	self.step = step
	self.unit = unit
	self.hint = hint
	self.disabled = disabled
	self.fraction = __computed(self, __c1, self)
	self.fillWidth = __computed(self, __c3, self)
	self.knobLeft = __computed(self, __c4, self)
	self.shown = __computed(self, __c5, self)
	return self
end

function Slider:format()
	local __s6 = self.unit
	if __s6 == "percent" then
		return __string_format("%d%%", __math_round(__get(self.value) * 100))
	elseif __s6 == "px" then
		return __string_format("%d px", __get(self.value))
	elseif __s6 == "sec" then
		return __string_format("%s s", __string_of(__get(self.value)))
	elseif __s6 == "none" then
		return __string_of(__get(self.value))
	end
end

function Slider:setAt(x)
	if __get(self.disabled) then
		return
	end
	local t = __math_max(0, __math_min(1, x / 200))
	local steps = __math_round(t * (self.most - self.least) / self.step)
	__set(self.value, __math_min(self.most, self.least + steps * self.step))
end

function Slider:onClick(click)
	self:setAt(click.x)
end

function Slider:onDrag(drag)
	self:setAt(drag.x)
end

function Slider:render()
	return __template(__d7, self)
end

Slider["onClick$Click"] = function(self, __click_button, __click_x, __click_y)
	self:setAt(__click_x)
end

Slider["onDrag$Drag"] = function(self, __drag_x, __drag_y, __drag_dx, __drag_dy)
	self:setAt(__drag_x)
end
__inherit(Slider, { __Ordaen_module_Component })

M.LENGTH = LENGTH
M.BAND = BAND
M.GROOVE = GROOVE
M.EDGE = EDGE
M.GROOVE_TOP = GROOVE_TOP
M.KNOB_W = KNOB_W
M.KNOB_H = KNOB_H
M.KNOB_SHADOW = KNOB_SHADOW
M.WHITE = WHITE
M.Slider = Slider
