-- Made by lunatype from OrdaenLibrary/tabs.luna: change the source, not this file.
local R = LunaType
local __get, __set, __computed, __class, __inherit, __el, __attr, __bind, __on, __template, __draw, __when, __each = R.get, R.set, R.computed, R.class, R.inherit, R.el, R.attr, R.bind, R.on, R.template, R.draw, R.when, R.each
local __insert = table.insert
local __Ordaen_module_Component = R.addon("Ordaen")["module"].Component
local M = {}
R.addon("OrdaenLibrary")["tabs"] = M
local TEXT, LINE, NAME, WHITE, CLEAR, SHADE, PICKED, OUTLINE, PADDING, LIGHT, Tab, Tabs

local function __c1(self)
	return __get(self.selected) == self.index
end

local function __c2(self)
	local __t3
	if __get(self.picked) then
		__t3 = PICKED
	else
		__t3 = SHADE
	end
	return __t3
end

local function __c4(self)
	local __t5
	if __get(self.picked) then
		__t5 = OUTLINE
	else
		__t5 = nil
	end
	return __t5
end

local function __c6(self)
	local __t7
	if __get(self.picked) then
		__t7 = WHITE
	else
		__t7 = NAME
	end
	return __t7
end

local function __b10(self)
	return __get(self.background)
end

local function __b11(self)
	return __get(self.border)
end

local function __b13(self)
	return __get(self.picked)
end

local function __d14(self, parent)
	local __e15 = __el(parent, "box")
	__attr(__e15, "position", "absolute")
	__attr(__e15, "left", 0.8333333333333334)
	__attr(__e15, "right", 0.8333333333333334)
	__attr(__e15, "top", 0.8333333333333334)
	__attr(__e15, "height", 1.6666666666666667)
	__attr(__e15, "background", LIGHT)
end

local __w12 = { __b13, __d14 }

local function __b17(self)
	return __get(self.label)
end

local function __b18(self)
	return __get(self.color)
end

local function __d8(self, parent)
	local __e9 = __el(parent, "box")
	__attr(__e9, "padding", PADDING)
	__bind(__e9, "background", __b10, self)
	__bind(__e9, "border", __b11, self)
	__on(__e9, "click", self, self.pick)
	__when(__e9, __w12, self)
	local __e16 = __el(__e9, "text")
	__bind(__e16, "value", __b17, self)
	__bind(__e16, "textColor", __b18, self)
	__attr(__e16, "textSize", 12.5)
	__attr(__e16, "stateFromParent", true)
	__attr(__e16, "wrap", false)
end

local function __c19(self)
	return self:tracks()
end

local function __b24(self)
	return __get(self.columns)
end

local function __b26(self)
	return __get(self.tabs)
end

local function __d27(self, parent, index, name)
	local __c28 = Tab.new(parent, name, index, self.selected)
	__draw(parent, __c28, nil)
end

local function __d22(self, parent)
	local __e23 = __el(parent, "box")
	__bind(__e23, "columns", __b24, self)
	__attr(__e23, "gap", 3.3333333333333335)
	local __e25 = __el(__e23, "box")
	__attr(__e25, "position", "absolute")
	__attr(__e25, "left", 0)
	__attr(__e25, "right", 0)
	__attr(__e25, "bottom", 0)
	__attr(__e25, "height", 0.8333333333333334)
	__attr(__e25, "background", LINE)
	__each(__e23, __b26, nil, __d27, 2, 1, true, self)
end

TEXT = 12.5
LINE = { r = 0.243, g = 0.184, b = 0.114, a = 1 }
NAME = { default = { r = 0.639, g = 0.592, b = 0.498, a = 1 }, hover = { r = 0.910, g = 0.863, b = 0.769, a = 1 } }
WHITE = { r = 1, g = 1, b = 1, a = 1 }
CLEAR = { r = 0, g = 0, b = 0, a = 0 }
SHADE = { default = CLEAR, hover = { r = 0, g = 0, b = 0, a = 0.200 } }
PICKED = { r = 0, g = 0, b = 0, a = 0.349 }
OUTLINE = { width = 0.8333333333333334, color = LINE, sides = { "top", "left", "right" } }
PADDING = { top = 5.833333333333334, right = 11.666666666666668, bottom = 5, left = 11.666666666666668 }
LIGHT = { r = 0.839, g = 0.647, b = 0.420, a = 1 }

Tab = __class({})

function Tab.new(__owner, label, index, selected)
	local self = setmetatable({}, Tab)
	R.adopt(__owner, self)
	self.label = label
	self.index = index
	self.selected = selected
	self.picked = __computed(self, __c1, self)
	self.background = __computed(self, __c2, self)
	self.border = __computed(self, __c4, self)
	self.color = __computed(self, __c6, self)
	return self
end

function Tab:pick()
	__set(self.selected, self.index)
end

function Tab:render()
	return __template(__d8, self)
end

Tabs = __class({})

function Tabs.new(__owner, tabs, selected)
	local self = setmetatable({}, Tabs)
	R.adopt(__owner, self)
	self.tabs = tabs
	self.selected = selected
	self.columns = __computed(self, __c19, self)
	return self
end

function Tabs:tracks()
	local list = {}
	local __l21 = __get(self.tabs)
	for __i20 = 1, #__l21 do
		local name = __l21[__i20]
		__insert(list, "auto")
	end
	__insert(list, { fr = 1 })
	return list
end

function Tabs:render()
	return __template(__d22, self)
end
__inherit(Tab, { __Ordaen_module_Component })
__inherit(Tabs, { __Ordaen_module_Component })

M.TEXT = TEXT
M.LINE = LINE
M.NAME = NAME
M.WHITE = WHITE
M.CLEAR = CLEAR
M.SHADE = SHADE
M.PICKED = PICKED
M.OUTLINE = OUTLINE
M.PADDING = PADDING
M.LIGHT = LIGHT
M.Tab = Tab
M.Tabs = Tabs
