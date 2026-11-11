-- Made by lunatype from OrdaenLibrary/settingRow.luna: change the source, not this file.
local R = LunaType
local __get, __set, __cell, __computed, __class, __inherit, __el, __attr, __bind, __on, __template, __draw, __slot, __when = R.get, R.set, R.cell, R.computed, R.class, R.inherit, R.el, R.attr, R.bind, R.on, R.template, R.draw, R.slot, R.when
local __OrdaenLibrary_tip_Tip = R.addon("OrdaenLibrary")["tip"].Tip
local __Ordaen_module_Component = R.addon("Ordaen")["module"].Component
local M = {}
R.addon("OrdaenLibrary")["settingRow"] = M
local LABEL_WIDTH, LABEL, SettingRow

local function __c1(self)
	return __get(self.hovered) and __get(self.hint) ~= ""
end

local function __c2(self)
	local __t3
	if __get(self.disabled) then
		__t3 = 0.45
	else
		__t3 = 1
	end
	return __t3
end

local function __b6(self)
	return __get(self.opacity)
end

local function __b9(self)
	return __get(self.label)
end

local function __b11(self)
	return __get(self.tipShown)
end

local function __d12(self, parent)
	local __c13 = __OrdaenLibrary_tip_Tip.new(parent, self.label, self.hint, __cell(233.33333333333334), __cell(0))
	__draw(parent, __c13, nil)
end

local __w10 = { __b11, __d12 }

local function __d4(self, parent)
	local __e5 = __el(parent, "box")
	__attr(__e5, "columns", { 233.33333333333334, { fr = 1 } })
	__attr(__e5, "gap", 15)
	__attr(__e5, "yAlign", "center")
	__bind(__e5, "opacity", __b6, self)
	local __e7 = __el(__e5, "box")
	__attr(__e7, "columns", 1)
	__on(__e7, "enter", self, self.onEnter)
	__on(__e7, "leave", self, self.onLeave)
	local __e8 = __el(__e7, "text")
	__bind(__e8, "value", __b9, self)
	__attr(__e8, "textColor", LABEL)
	__attr(__e8, "textSize", 12.5)
	__slot(__e5, self, "", nil, nil)
	__when(__e5, __w10, self)
end

LABEL_WIDTH = 233.33333333333334
LABEL = { r = 0.796, g = 0.725, b = 0.580, a = 1 }

SettingRow = __class({})

function SettingRow.new(__owner, label, hint, disabled)
	local self = setmetatable({}, SettingRow)
	R.adopt(__owner, self)
	if hint == nil then hint = __cell("") end
	if disabled == nil then disabled = __cell(false) end
	self.label = label
	self.hint = hint
	self.disabled = disabled
	self.hovered = __cell(false)
	self.tipShown = __computed(self, __c1, self)
	self.opacity = __computed(self, __c2, self)
	return self
end

function SettingRow:onEnter()
	__set(self.hovered, true)
end

function SettingRow:onLeave()
	__set(self.hovered, false)
end

function SettingRow:render()
	return __template(__d4, self)
end
__inherit(SettingRow, { __Ordaen_module_Component })

M.LABEL_WIDTH = LABEL_WIDTH
M.LABEL = LABEL
M.SettingRow = SettingRow
