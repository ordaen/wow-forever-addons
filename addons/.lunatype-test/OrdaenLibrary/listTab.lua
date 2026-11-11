-- Made by lunatype from OrdaenLibrary/listTab.luna: change the source, not this file.
local R = LunaType
local __get, __cell, __computed, __event, __emit, __class, __inherit, __el, __attr, __bind, __on, __template, __slot, __when = R.get, R.cell, R.computed, R.event, R.emit, R.class, R.inherit, R.el, R.attr, R.bind, R.on, R.template, R.slot, R.when
local __Ordaen_module_Component = R.addon("Ordaen")["module"].Component
local M = {}
R.addon("OrdaenLibrary")["listTab"] = M
local INK, WHITE, OFF, CLEAR, SHADE, SELECTED, DIM, LIGHT, PADDING, WITH_ICON, NO_ICON, ListTab

local function __c1(self)
	return __get(self.icon) ~= ""
end

local function __c2(self)
	local __t3
	if __get(self.hasIcon) then
		__t3 = WITH_ICON
	else
		__t3 = NO_ICON
	end
	return __t3
end

local function __c4(self)
	local __t5
	if __get(self.selected) then
		__t5 = SELECTED
	else
		__t5 = SHADE
	end
	return __t5
end

local function __c6(self)
	local __t7
	if __get(self.selected) then
		__t7 = WHITE
	else
		local __t8
		if __get(self.off) then
			__t8 = OFF
		else
			__t8 = INK
		end
		__t7 = __t8
	end
	return __t7
end

local function __c9(self)
	local __t10
	if __get(self.off) then
		__t10 = DIM
	else
		__t10 = WHITE
	end
	return __t10
end

local function __b13(self)
	return __get(self.columns)
end

local function __b14(self)
	return __get(self.background)
end

local function __b16(self)
	return __get(self.selected)
end

local function __d17(self, parent)
	local __e18 = __el(parent, "box")
	__attr(__e18, "position", "absolute")
	__attr(__e18, "left", 0)
	__attr(__e18, "top", 0)
	__attr(__e18, "bottom", 0)
	__attr(__e18, "width", 2.5)
	__attr(__e18, "background", LIGHT)
end

local __w15 = { __b16, __d17 }

local function __b20(self)
	return __get(self.hasIcon)
end

local function __b23(self)
	return __get(self.icon)
end

local function __b24(self)
	return __get(self.tint)
end

local function __d21(self, parent)
	local __e22 = __el(parent, "box")
	__attr(__e22, "width", 18.333333333333336)
	__attr(__e22, "height", 18.333333333333336)
	__bind(__e22, "background", __b23, self)
	__bind(__e22, "tint", __b24, self)
end

local __w19 = { __b20, __d21 }

local function __b26(self)
	return __get(self.label)
end

local function __b27(self)
	return __get(self.color)
end

local function __d11(self, parent)
	local __e12 = __el(parent, "box")
	__bind(__e12, "columns", __b13, self)
	__attr(__e12, "gap", 8.333333333333334)
	__attr(__e12, "padding", PADDING)
	__attr(__e12, "yAlign", "center")
	__bind(__e12, "background", __b14, self)
	__on(__e12, "click", self, self.onClick)
	__when(__e12, __w15, self)
	__when(__e12, __w19, self)
	local __e25 = __el(__e12, "text")
	__bind(__e25, "value", __b26, self)
	__bind(__e25, "textColor", __b27, self)
	__attr(__e25, "textSize", 12.5)
	__attr(__e25, "wrap", false)
	local __e28 = __el(__e12, "box")
	__slot(__e28, self, "", nil, nil)
end

INK = { r = 0.910, g = 0.863, b = 0.769, a = 1 }
WHITE = { r = 1, g = 1, b = 1, a = 1 }
OFF = { r = 0.478, g = 0.439, b = 0.373, a = 1 }
CLEAR = { r = 0, g = 0, b = 0, a = 0 }
SHADE = { default = CLEAR, hover = { r = 0, g = 0, b = 0, a = 0.349 } }
SELECTED = { r = 0, g = 0, b = 0, a = 0.251 }
DIM = { r = 0.600, g = 0.600, b = 0.600, a = 1 }
LIGHT = { r = 0.839, g = 0.647, b = 0.420, a = 1 }
PADDING = { top = 5.833333333333334, right = 10, bottom = 5.833333333333334, left = 13.333333333333334 }
WITH_ICON = { 18.333333333333336, { fr = 1 }, "auto" }
NO_ICON = { { fr = 1 }, "auto" }

ListTab = __class({})

function ListTab.new(__owner, label, selected, icon, off)
	local self = setmetatable({}, ListTab)
	R.adopt(__owner, self)
	if icon == nil then icon = __cell("") end
	if off == nil then off = __cell(false) end
	self.label = label
	self.selected = selected
	self.icon = icon
	self.off = off
	self.pick = __event()
	self.hasIcon = __computed(self, __c1, self)
	self.columns = __computed(self, __c2, self)
	self.background = __computed(self, __c4, self)
	self.color = __computed(self, __c6, self)
	self.tint = __computed(self, __c9, self)
	return self
end

function ListTab:onClick()
	__emit(self.pick)
end

function ListTab:render()
	return __template(__d11, self)
end
__inherit(ListTab, { __Ordaen_module_Component })

M.INK = INK
M.WHITE = WHITE
M.OFF = OFF
M.CLEAR = CLEAR
M.SHADE = SHADE
M.SELECTED = SELECTED
M.DIM = DIM
M.LIGHT = LIGHT
M.PADDING = PADDING
M.WITH_ICON = WITH_ICON
M.NO_ICON = NO_ICON
M.ListTab = ListTab
