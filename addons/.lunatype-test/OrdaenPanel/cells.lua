-- Made by lunatype from OrdaenPanel/cells.luna: change the source, not this file.
local R = LunaType
local __get, __getKey, __cell, __computed, __class, __inherit, __el, __attr, __bind, __template, __when = R.get, R.getKey, R.cell, R.computed, R.class, R.inherit, R.el, R.attr, R.bind, R.template, R.when
local __Ordaen_core = R.addon("Ordaen")["core"]
local __game__Frames_CharacterMicroButton = R.game.Frames.CharacterMicroButton
local __Ordaen_module_Component = R.addon("Ordaen")["module"].Component
local M = {}
R.addon("OrdaenPanel")["cells"] = M
local CELL_HEIGHT, CELL_WIDTH, FACE, ICON, ICON_LEFT, ICON_TOP, GOLD, WHITE, BADGE, BADGE_PAD, BOLD, MenuCell, FaceCell, BagCell

local function __c1(self)
	local __t2
	if __get(self.gold) then
		__t2 = GOLD
	else
		__t2 = WHITE
	end
	return __t2
end

local function __c3(self)
	return __get(self.count) > 0
end

local function __b6(self)
	return __getKey(__Ordaen_core.theme, "panel").cell
end

local function __b8(self)
	return __get(self.gold)
end

local function __b9(self)
	return __get(self.tint)
end

local function __b11(self)
	return __get(self.counted)
end

local function __b14(self)
	return __getKey(__Ordaen_core.theme, "panel").countBadge
end

local function __b16(self)
	return { __get(self.count) }
end

local function __b17(self)
	return __getKey(__Ordaen_core.theme, "font").numbers
end

local function __d12(self, parent)
	local __e13 = __el(parent, "box")
	__attr(__e13, "position", "absolute")
	__attr(__e13, "right", 6.836999999999999)
	__attr(__e13, "bottom", 7.420000000000001)
	__attr(__e13, "height", 13.333333333333334)
	__attr(__e13, "minWidth", 13.333333333333334)
	__attr(__e13, "padding", BADGE_PAD)
	__attr(__e13, "xAlign", "center")
	__attr(__e13, "yAlign", "center")
	__bind(__e13, "background", __b14, self)
	local __e15 = __el(__e13, "text")
	__attr(__e15, "value", "%d")
	__bind(__e15, "arguments", __b16, self)
	__attr(__e15, "textSize", 9.166666666666668)
	__attr(__e15, "textColor", WHITE)
	__bind(__e15, "textFamily", __b17, self)
	__attr(__e15, "textShadow", BOLD)
	__attr(__e15, "wrap", false)
end

local __w10 = { __b11, __d12 }

local function __b19(self)
	return __get(self.frame)
end

local function __d4(self, parent)
	local __e5 = __el(parent, "box")
	__attr(__e5, "width", 56.974999999999994)
	__attr(__e5, "height", 53)
	__bind(__e5, "background", __b6, self)
	local __e7 = __el(__e5, "box")
	__attr(__e7, "position", "absolute")
	__attr(__e7, "left", 10.987499999999997)
	__attr(__e7, "top", ICON_TOP)
	__attr(__e7, "width", 35)
	__attr(__e7, "height", 35)
	__attr(__e7, "background", self.icon)
	__bind(__e7, "desaturate", __b8, self)
	__bind(__e7, "tint", __b9, self)
	__attr(__e7, "stateFromParent", true)
	__when(__e5, __w10, self)
	local __e18 = __el(__e5, "embed")
	__bind(__e18, "frame", __b19, self)
	__attr(__e18, "position", "absolute")
	__attr(__e18, "left", 0)
	__attr(__e18, "top", 0)
	__attr(__e18, "width", 56.974999999999994)
	__attr(__e18, "height", 53)
	__attr(__e18, "opacity", 0)
end

local function __b22(self)
	return __getKey(__Ordaen_core.theme, "panel").cell
end

local function __b24(self)
	return __getKey(__Ordaen_core.theme, "panel").faceRound
end

local function __b26(self)
	return __get(__game__Frames_CharacterMicroButton)
end

local function __d20(self, parent)
	local __e21 = __el(parent, "box")
	__attr(__e21, "width", 56.974999999999994)
	__attr(__e21, "height", 53)
	__bind(__e21, "background", __b22, self)
	local __e23 = __el(__e21, "box")
	__attr(__e23, "position", "absolute")
	__attr(__e23, "left", 11.82083333333333)
	__attr(__e23, "top", 9.833333333333332)
	__attr(__e23, "width", 33.333333333333336)
	__attr(__e23, "height", 33.333333333333336)
	__attr(__e23, "portrait", "player")
	__bind(__e23, "mask", __b24, self)
	local __e25 = __el(__e21, "embed")
	__bind(__e25, "frame", __b26, self)
	__attr(__e25, "position", "absolute")
	__attr(__e25, "left", 0)
	__attr(__e25, "top", 0)
	__attr(__e25, "width", 56.974999999999994)
	__attr(__e25, "height", 53)
	__attr(__e25, "opacity", 0)
end

local function __c27(self)
	return __get(self.free) > 0
end

local function __b30(self)
	return __getKey(__Ordaen_core.theme, "panel").cell
end

local function __b32(self)
	return __get(self.frame)
end

local function __b34(self)
	return __get(self.counted)
end

local function __b38(self)
	return { __get(self.free) }
end

local function __b39(self)
	return __getKey(__Ordaen_core.theme, "font").numbers
end

local function __d35(self, parent)
	local __e36 = __el(parent, "box")
	__attr(__e36, "position", "absolute")
	__attr(__e36, "right", 4.487499999999997)
	__attr(__e36, "bottom", 0.8333333333333334)
	__attr(__e36, "zLevel", 1)
	local __e37 = __el(__e36, "text")
	__attr(__e37, "value", "%d")
	__bind(__e37, "arguments", __b38, self)
	__attr(__e37, "textSize", 11.666666666666668)
	__attr(__e37, "textColor", WHITE)
	__bind(__e37, "textFamily", __b39, self)
	__attr(__e37, "textOutline", 1)
	__attr(__e37, "wrap", false)
end

local __w33 = { __b34, __d35 }

local function __d28(self, parent)
	local __e29 = __el(parent, "box")
	__attr(__e29, "width", 56.974999999999994)
	__attr(__e29, "height", 53)
	__bind(__e29, "background", __b30, self)
	local __e31 = __el(__e29, "embed")
	__bind(__e31, "frame", __b32, self)
	__attr(__e31, "position", "absolute")
	__attr(__e31, "left", 1.9874999999999972)
	__attr(__e31, "top", 0)
	__attr(__e31, "width", 53)
	__attr(__e31, "height", 53)
	__attr(__e31, "look", "icon")
	__when(__e29, __w33, self)
end

CELL_HEIGHT = 53
CELL_WIDTH = 56.974999999999994
FACE = 33.333333333333336
ICON = 35
ICON_LEFT = 10.987499999999997
ICON_TOP = { default = 9, pressed = 9.833333333333334 }
GOLD = { r = 1, g = 0.722, b = 0.278, a = 1 }
WHITE = { r = 1, g = 1, b = 1, a = 1 }
BADGE = 13.333333333333334
BADGE_PAD = { right = 3.3333333333333335, left = 3.3333333333333335 }
BOLD = { color = WHITE, x = 1, y = 0 }

MenuCell = __class({})

function MenuCell.new(__owner, icon, frame, gold, count)
	local self = setmetatable({}, MenuCell)
	R.adopt(__owner, self)
	if count == nil then count = __cell(0) end
	self.icon = icon
	self.frame = frame
	self.gold = gold
	self.count = count
	self.tint = __computed(self, __c1, self)
	self.counted = __computed(self, __c3, self)
	return self
end

function MenuCell:render()
	return __template(__d4, self)
end

FaceCell = __class({})

function FaceCell.new(__owner)
	local self = setmetatable({}, FaceCell)
	R.adopt(__owner, self)
	return self
end

function FaceCell:render()
	return __template(__d20, self)
end

BagCell = __class({})

function BagCell.new(__owner, frame, free)
	local self = setmetatable({}, BagCell)
	R.adopt(__owner, self)
	if free == nil then free = __cell(0) end
	self.frame = frame
	self.free = free
	self.counted = __computed(self, __c27, self)
	return self
end

function BagCell:render()
	return __template(__d28, self)
end
__inherit(MenuCell, { __Ordaen_module_Component })
__inherit(FaceCell, { __Ordaen_module_Component })
__inherit(BagCell, { __Ordaen_module_Component })

M.CELL_HEIGHT = CELL_HEIGHT
M.CELL_WIDTH = CELL_WIDTH
M.FACE = FACE
M.ICON = ICON
M.ICON_LEFT = ICON_LEFT
M.ICON_TOP = ICON_TOP
M.GOLD = GOLD
M.WHITE = WHITE
M.BADGE = BADGE
M.BADGE_PAD = BADGE_PAD
M.BOLD = BOLD
M.MenuCell = MenuCell
M.FaceCell = FaceCell
M.BagCell = BagCell
