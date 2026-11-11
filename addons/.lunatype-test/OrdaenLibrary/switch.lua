-- Made by lunatype from OrdaenLibrary/switch.luna: change the source, not this file.
local R = LunaType
local __get, __getKey, __set, __cell, __computed, __class, __inherit, __el, __attr, __bind, __on, __template, __draw = R.get, R.getKey, R.set, R.cell, R.computed, R.class, R.inherit, R.el, R.attr, R.bind, R.on, R.template, R.draw
local __Ordaen_core = R.addon("Ordaen")["core"]
local __OrdaenLibrary_settingRow_SettingRow = R.addon("OrdaenLibrary")["settingRow"].SettingRow
local __Ordaen_module_Component = R.addon("Ordaen")["module"].Component
local M = {}
R.addon("OrdaenLibrary")["switch"] = M
local WIDTH, HEIGHT, KNOB, KNOB_TOP, KNOB_OFF, KNOB_ON, Toggle, Switch

local function __c1(self)
	local __t2
	if __get(self.value) then
		__t2 = __getKey(__Ordaen_core.theme, "ctl").switchOn
	else
		__t2 = __getKey(__Ordaen_core.theme, "ctl").switchOff
	end
	return __t2
end

local function __c3(self)
	local __t4
	if __get(self.value) then
		__t4 = __getKey(__Ordaen_core.theme, "ctl").knobOn
	else
		__t4 = __getKey(__Ordaen_core.theme, "ctl").knobOff
	end
	return __t4
end

local function __c5(self)
	local __t6
	if __get(self.value) then
		__t6 = 12.5
	else
		__t6 = -2.5
	end
	return __t6
end

local function __b9(self)
	return __get(self.track)
end

local function __b11(self)
	return __get(self.knobLeft)
end

local function __b12(self)
	return __get(self.knob)
end

local function __d7(self, parent)
	local __e8 = __el(parent, "box")
	__attr(__e8, "width", 31.666666666666668)
	__attr(__e8, "height", 16.666666666666668)
	__bind(__e8, "background", __b9, self)
	__on(__e8, "click", self, self.flip)
	local __e10 = __el(__e8, "box")
	__attr(__e10, "position", "absolute")
	__bind(__e10, "left", __b11, self)
	__attr(__e10, "top", -2.5)
	__attr(__e10, "width", 21.666666666666668)
	__attr(__e10, "height", 21.666666666666668)
	__bind(__e10, "background", __b12, self)
end

local function __d15(self, parent)
	local __c16 = Toggle.new(parent, self.value, self.disabled)
	__draw(parent, __c16, nil)
end

local function __d13(self, parent)
	local __c14 = __OrdaenLibrary_settingRow_SettingRow.new(parent, self.label, self.hint, self.disabled)
	__draw(parent, __c14, { self = self, [""] = __d15 })
end

WIDTH = 31.666666666666668
HEIGHT = 16.666666666666668
KNOB = 21.666666666666668
KNOB_TOP = -2.5
KNOB_OFF = -2.5
KNOB_ON = 12.5

Toggle = __class({})

function Toggle.new(__owner, value, disabled)
	local self = setmetatable({}, Toggle)
	R.adopt(__owner, self)
	if disabled == nil then disabled = __cell(false) end
	self.value = value
	self.disabled = disabled
	self.track = __computed(self, __c1, self)
	self.knob = __computed(self, __c3, self)
	self.knobLeft = __computed(self, __c5, self)
	return self
end

function Toggle:flip()
	if not __get(self.disabled) then
		__set(self.value, not __get(self.value))
	end
end

function Toggle:render()
	return __template(__d7, self)
end

Switch = __class({})

function Switch.new(__owner, label, value, hint, disabled)
	local self = setmetatable({}, Switch)
	R.adopt(__owner, self)
	if hint == nil then hint = __cell("") end
	if disabled == nil then disabled = __cell(false) end
	self.label = label
	self.value = value
	self.hint = hint
	self.disabled = disabled
	return self
end

function Switch:render()
	return __template(__d13, self)
end
__inherit(Toggle, { __Ordaen_module_Component })
__inherit(Switch, { __Ordaen_module_Component })

M.WIDTH = WIDTH
M.HEIGHT = HEIGHT
M.KNOB = KNOB
M.KNOB_TOP = KNOB_TOP
M.KNOB_OFF = KNOB_OFF
M.KNOB_ON = KNOB_ON
M.Toggle = Toggle
M.Switch = Switch
