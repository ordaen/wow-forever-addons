-- Made by lunatype from OrdaenLibrary/dropdown.luna: change the source, not this file.
local R = LunaType
local __get, __getKey, __set, __cell, __computed, __event, __listen, __emit, __class, __inherit, __el, __attr, __bind, __on, __template, __draw, __when, __each = R.get, R.getKey, R.set, R.cell, R.computed, R.event, R.listen, R.emit, R.class, R.inherit, R.el, R.attr, R.bind, R.on, R.template, R.draw, R.when, R.each
local __Ordaen_core = R.addon("Ordaen")["core"]
local __OrdaenLibrary_locales_SOON = R.addon("OrdaenLibrary")["locales"].SOON
local __OrdaenLibrary_settingRow_SettingRow = R.addon("OrdaenLibrary")["settingRow"].SettingRow
local __Ordaen_module_Component = R.addon("Ordaen")["module"].Component
local M = {}
R.addon("OrdaenLibrary")["dropdown"] = M
local WIDTH, HEIGHT, TEXT, GOLD, WHITE, DIM, BOLD, FACE_PAD, ARROW_SHADOW, MENU_BACK, MENU_EDGE, MENU_PAD, ITEM_PAD, CLEAR, LIGHT, DropdownItem, Dropdown

local function __c1(self)
	local __t2
	if __get(self.value) == self.choice.value then
		__t2 = __getKey(__Ordaen_core.theme, "ctl").radioOn
	else
		__t2 = __getKey(__Ordaen_core.theme, "ctl").radio
	end
	return __t2
end

local function __c3(self)
	local __t4
	if self.choice.soon == true then
		__t4 = self.choice.label .. " — " .. __OrdaenLibrary_locales_SOON
	else
		__t4 = self.choice.label
	end
	return __t4
end

local function __c5(self)
	local __t6
	if self.choice.soon == true then
		__t6 = DIM
	else
		__t6 = WHITE
	end
	return __t6
end

local function __c7(self)
	local __t8
	if self.choice.soon == true then
		__t8 = CLEAR
	else
		__t8 = LIGHT
	end
	return __t8
end

local function __b11(self)
	return __get(self.light)
end

local function __b13(self)
	return __get(self.mark)
end

local function __b15(self)
	return __get(self.text)
end

local function __b16(self)
	return __get(self.color)
end

local function __d9(self, parent)
	local __e10 = __el(parent, "box")
	__attr(__e10, "padding", ITEM_PAD)
	__bind(__e10, "background", __b11, self)
	__on(__e10, "click", self, self.onClick)
	local __e12 = __el(__e10, "box")
	__attr(__e12, "position", "absolute")
	__attr(__e12, "left", 8.333333333333334)
	__attr(__e12, "top", 7.5)
	__attr(__e12, "width", 9.166666666666668)
	__attr(__e12, "height", 9.166666666666668)
	__bind(__e12, "background", __b13, self)
	local __e14 = __el(__e10, "text")
	__bind(__e14, "value", __b15, self)
	__bind(__e14, "textColor", __b16, self)
	__attr(__e14, "textSize", 12.5)
end

local function __c17(self)
	return self:labelOf()
end

local function __b25(self)
	return __getKey(__Ordaen_core.theme, "ctl").button
end

local function __b27(self)
	return __get(self.shown)
end

local function __b29(self)
	return __getKey(__Ordaen_core.theme, "ctl").dropdownArrow
end

local function __b31(self)
	return __get(self.open)
end

local function __b34(self)
	return self.choices
end

local function __d35(self, parent, choice)
	local __c36 = DropdownItem.new(parent, choice, self.value)
	__listen(__c36.pick, self, self.onPick)
	__draw(parent, __c36, nil)
end

local function __d32(self, parent)
	local __e33 = __el(parent, "box")
	__attr(__e33, "position", "absolute")
	__attr(__e33, "left", 0)
	__attr(__e33, "top", 31.666666666666668)
	__attr(__e33, "width", 216.66666666666666)
	__attr(__e33, "zLevel", 50)
	__attr(__e33, "background", MENU_BACK)
	__attr(__e33, "border", MENU_EDGE)
	__attr(__e33, "padding", MENU_PAD)
	__attr(__e33, "columns", 1)
	__on(__e33, "clickOutside", self, self.close)
	__each(__e33, __b34, nil, __d35, 1, 0, false, self)
end

local __w30 = { __b31, __d32 }

local function __d22(self, parent)
	local __e23 = __el(parent, "box")
	__attr(__e23, "width", 200)
	__attr(__e23, "height", 28.333333333333336)
	local __e24 = __el(__e23, "box")
	__attr(__e24, "position", "absolute")
	__attr(__e24, "left", 0)
	__attr(__e24, "top", 0)
	__attr(__e24, "width", 200)
	__attr(__e24, "height", 28.333333333333336)
	__attr(__e24, "padding", FACE_PAD)
	__attr(__e24, "columns", { { fr = 1 }, 13.333333333333334 })
	__attr(__e24, "gap", 8.333333333333334)
	__attr(__e24, "yAlign", "center")
	__bind(__e24, "background", __b25, self)
	__on(__e24, "click", self, self.toggle)
	local __e26 = __el(__e24, "text")
	__bind(__e26, "value", __b27, self)
	__attr(__e26, "textColor", GOLD)
	__attr(__e26, "textSize", 12.5)
	__attr(__e26, "textShadow", BOLD)
	__attr(__e26, "wrap", false)
	local __e28 = __el(__e24, "box")
	__attr(__e28, "width", 13.333333333333334)
	__attr(__e28, "height", 13.333333333333334)
	__bind(__e28, "background", __b29, self)
	__attr(__e28, "shadow", ARROW_SHADOW)
	__when(__e23, __w30, self)
end

local function __d20(self, parent)
	local __c21 = __OrdaenLibrary_settingRow_SettingRow.new(parent, self.label, self.hint, self.disabled)
	__draw(parent, __c21, { self = self, [""] = __d22 })
end

WIDTH = 200
HEIGHT = 28.333333333333336
TEXT = 12.5
GOLD = { r = 0.941, g = 0.784, b = 0.376, a = 1 }
WHITE = { r = 1, g = 1, b = 1, a = 1 }
DIM = { r = 1, g = 1, b = 1, a = 0.451 }
BOLD = { color = GOLD, x = 0.8333333333333334, y = 0 }
FACE_PAD = { right = 10, left = 15 }
ARROW_SHADOW = { color = { r = 0.078, g = 0.078, b = 0.122, a = 0.800 }, x = 0.8333333333333334, y = 0.8333333333333334 }
MENU_BACK = { r = 0.039, g = 0.031, b = 0.024, a = 0.969 }
MENU_EDGE = { width = 0.8333333333333334, color = { r = 0.424, g = 0.333, b = 0.208, a = 1 } }
MENU_PAD = { top = 5, bottom = 5 }
ITEM_PAD = { top = 4.166666666666667, right = 11.666666666666668, bottom = 4.166666666666667, left = 25 }
CLEAR = { r = 0, g = 0, b = 0, a = 0 }
LIGHT = { default = CLEAR, hover = { r = 0.839, g = 0.647, b = 0.420, a = 0.180 } }

DropdownItem = __class({})

function DropdownItem.new(__owner, choice, value)
	local self = setmetatable({}, DropdownItem)
	R.adopt(__owner, self)
	self.choice = choice
	self.value = value
	self.pick = __event()
	self.mark = __computed(self, __c1, self)
	self.text = __computed(self, __c3, self)
	self.color = __computed(self, __c5, self)
	self.light = __computed(self, __c7, self)
	return self
end

function DropdownItem:onClick()
	if self.choice.soon ~= true then
		__emit(self.pick, self.choice.value)
	end
end

function DropdownItem:render()
	return __template(__d9, self)
end

Dropdown = __class({})

function Dropdown.new(__owner, label, value, choices, hint, disabled)
	local self = setmetatable({}, Dropdown)
	R.adopt(__owner, self)
	if hint == nil then hint = __cell("") end
	if disabled == nil then disabled = __cell(false) end
	self.label = label
	self.value = value
	self.choices = choices
	self.hint = hint
	self.disabled = disabled
	self.open = __cell(false)
	self.shown = __computed(self, __c17, self)
	return self
end

function Dropdown:labelOf()
	local __l19 = self.choices
	for __i18 = 1, #__l19 do
		local choice = __l19[__i18]
		if choice.value == __get(self.value) then
			return choice.label
		end
	end
	return ""
end

function Dropdown:toggle()
	if not __get(self.disabled) then
		__set(self.open, not __get(self.open))
	end
end

function Dropdown:close()
	__set(self.open, false)
end

function Dropdown:onPick(value)
	__set(self.value, value)
	__set(self.open, false)
end

function Dropdown:render()
	return __template(__d20, self)
end
__inherit(DropdownItem, { __Ordaen_module_Component })
__inherit(Dropdown, { __Ordaen_module_Component })

M.WIDTH = WIDTH
M.HEIGHT = HEIGHT
M.TEXT = TEXT
M.GOLD = GOLD
M.WHITE = WHITE
M.DIM = DIM
M.BOLD = BOLD
M.FACE_PAD = FACE_PAD
M.ARROW_SHADOW = ARROW_SHADOW
M.MENU_BACK = MENU_BACK
M.MENU_EDGE = MENU_EDGE
M.MENU_PAD = MENU_PAD
M.ITEM_PAD = ITEM_PAD
M.CLEAR = CLEAR
M.LIGHT = LIGHT
M.DropdownItem = DropdownItem
M.Dropdown = Dropdown
