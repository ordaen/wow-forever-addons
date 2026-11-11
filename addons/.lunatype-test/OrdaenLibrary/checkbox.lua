-- Made by lunatype from OrdaenLibrary/checkbox.luna: change the source, not this file.
local R = LunaType
local __get, __getKey, __set, __cell, __class, __inherit, __el, __attr, __bind, __on, __template, __draw, __when = R.get, R.getKey, R.set, R.cell, R.class, R.inherit, R.el, R.attr, R.bind, R.on, R.template, R.draw, R.when
local __OrdaenLibrary_settingRow_SettingRow = R.addon("OrdaenLibrary")["settingRow"].SettingRow
local __Ordaen_core = R.addon("Ordaen")["core"]
local __Ordaen_module_Component = R.addon("Ordaen")["module"].Component
local M = {}
R.addon("OrdaenLibrary")["checkbox"] = M
local SIZE, Checkbox

local function __b5(self)
	return __getKey(__Ordaen_core.theme, "ctl").check
end

local function __b7(self)
	return __get(self.value)
end

local function __b10(self)
	return __getKey(__Ordaen_core.theme, "ctl").tick
end

local function __d8(self, parent)
	local __e9 = __el(parent, "box")
	__attr(__e9, "position", "absolute")
	__attr(__e9, "left", 0)
	__attr(__e9, "top", 0)
	__attr(__e9, "width", 18.333333333333336)
	__attr(__e9, "height", 18.333333333333336)
	__bind(__e9, "background", __b10, self)
end

local __w6 = { __b7, __d8 }

local function __d3(self, parent)
	local __e4 = __el(parent, "box")
	__attr(__e4, "width", 18.333333333333336)
	__attr(__e4, "height", 18.333333333333336)
	__bind(__e4, "background", __b5, self)
	__on(__e4, "click", self, self.toggle)
	__when(__e4, __w6, self)
end

local function __d1(self, parent)
	local __c2 = __OrdaenLibrary_settingRow_SettingRow.new(parent, self.label, self.hint, self.disabled)
	__draw(parent, __c2, { self = self, [""] = __d3 })
end

SIZE = 18.333333333333336

Checkbox = __class({})

function Checkbox.new(__owner, label, value, hint, disabled)
	local self = setmetatable({}, Checkbox)
	R.adopt(__owner, self)
	if hint == nil then hint = __cell("") end
	if disabled == nil then disabled = __cell(false) end
	self.label = label
	self.value = value
	self.hint = hint
	self.disabled = disabled
	return self
end

function Checkbox:toggle()
	if not __get(self.disabled) then
		__set(self.value, not __get(self.value))
	end
end

function Checkbox:render()
	return __template(__d1, self)
end
__inherit(Checkbox, { __Ordaen_module_Component })

M.SIZE = SIZE
M.Checkbox = Checkbox
