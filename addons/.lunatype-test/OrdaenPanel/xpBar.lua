-- Made by lunatype from OrdaenPanel/xpBar.luna: change the source, not this file.
local R = LunaType
local __get, __getKey, __cell, __computed, __class, __inherit, __el, __attr, __bind, __template, __draw, __when, __each = R.get, R.getKey, R.cell, R.computed, R.class, R.inherit, R.el, R.attr, R.bind, R.template, R.draw, R.when, R.each
local __Ordaen_core = R.addon("Ordaen")["core"]
local __game__Player_xpMax = R.game.Player.xpMax
local __game__Reputation_name = R.game.Reputation.name
local __game__Player_xp = R.game.Player.xp
local __game__Player_rested = R.game.Player.rested
local __string_format = R.string.format
local __math_floor = R.math.floor
local __game__Reputation_standing = R.game.Reputation.standing
local __math_min = R.math.min
local __game__Reputation_max = R.game.Reputation.max
local __game__Reputation_min = R.game.Reputation.min
local __game__Reputation_value = R.game.Reputation.value
local __Ordaen_module_Component = R.addon("Ordaen")["module"].Component
local M = {}
R.addon("OrdaenPanel")["xpBar"] = M
local TUBE_HEIGHT, LEAST, MARGINS, INSET, RESTED, CLEAR, LABEL, LABEL_SHADOW, FILL, CELLS, MARK, NONE, Tube, XpBar

local function __b4(self)
	return __getKey(__Ordaen_core.theme, "panel").xpTrough
end

local function __b7(self)
	return __get(self.behind)
end

local function __b9(self)
	return __get(self.share)
end

local function __b11(self)
	return CELLS
end

local function __d12(self, parent, cell)
	local __e13 = __el(parent, "box")
	__attr(__e13, "border", MARK)
end

local function __b16(self)
	return __getKey(__Ordaen_core.theme, "panel").xpShine
end

local function __b18(self)
	return __getKey(__Ordaen_core.theme, "panel").xpTube
end

local function __b21(self)
	return __get(self.label)
end

local function __d1(self, parent)
	local __e2 = __el(parent, "box")
	__attr(__e2, "height", 25)
	local __e3 = __el(__e2, "box")
	__attr(__e3, "position", "absolute")
	__attr(__e3, "left", 0)
	__attr(__e3, "top", 0)
	__attr(__e3, "right", 0)
	__attr(__e3, "bottom", 0)
	__bind(__e3, "background", __b4, self)
	local __e5 = __el(__e2, "box")
	__attr(__e5, "position", "absolute")
	__attr(__e5, "left", 3.90625)
	__attr(__e5, "top", 3.90625)
	__attr(__e5, "right", 3.90625)
	__attr(__e5, "bottom", 3.90625)
	local __e6 = __el(__e5, "box")
	__attr(__e6, "position", "absolute")
	__attr(__e6, "left", 0)
	__attr(__e6, "top", 0)
	__attr(__e6, "bottom", 0)
	__bind(__e6, "width", __b7, self)
	__attr(__e6, "background", RESTED)
	local __e8 = __el(__e5, "box")
	__attr(__e8, "position", "absolute")
	__attr(__e8, "left", 0)
	__attr(__e8, "top", 0)
	__attr(__e8, "bottom", 0)
	__bind(__e8, "width", __b9, self)
	__attr(__e8, "background", self.fill)
	local __e10 = __el(__e5, "box")
	__attr(__e10, "position", "absolute")
	__attr(__e10, "left", 0)
	__attr(__e10, "top", 0)
	__attr(__e10, "right", 0)
	__attr(__e10, "bottom", 0)
	__attr(__e10, "columns", 10)
	__attr(__e10, "rows", FILL)
	__each(__e10, __b11, nil, __d12, 1, 0, false, self)
	local __e14 = __el(__e10, "box")
	local __e15 = __el(__e2, "box")
	__attr(__e15, "position", "absolute")
	__attr(__e15, "left", 0)
	__attr(__e15, "top", 0)
	__attr(__e15, "right", 0)
	__attr(__e15, "bottom", 0)
	__bind(__e15, "background", __b16, self)
	local __e17 = __el(__e2, "box")
	__attr(__e17, "position", "absolute")
	__attr(__e17, "left", 0)
	__attr(__e17, "top", 0)
	__attr(__e17, "right", 0)
	__attr(__e17, "bottom", 0)
	__bind(__e17, "background", __b18, self)
	local __e19 = __el(__e2, "box")
	__attr(__e19, "position", "absolute")
	__attr(__e19, "left", 0)
	__attr(__e19, "top", 0)
	__attr(__e19, "right", 0)
	__attr(__e19, "bottom", 0)
	__attr(__e19, "xAlign", "center")
	__attr(__e19, "yAlign", "center")
	local __e20 = __el(__e19, "text")
	__bind(__e20, "value", __b21, self)
	__attr(__e20, "textSize", 12.5)
	__attr(__e20, "textColor", LABEL)
	__attr(__e20, "textOutline", 1)
	__attr(__e20, "textShadow", LABEL_SHADOW)
	__attr(__e20, "wrap", false)
end

local function __c22(self)
	return __get(__game__Player_xpMax) > 0
end

local function __c23(self)
	return __get(__game__Reputation_name) ~= ""
end

local function __c24(self)
	return __get(self.watched) and (not __get(self.leveling) or __get(self.both))
end

local function __c25(self)
	return { percent = self:part(__get(__game__Player_xp)) }
end

local function __c26(self)
	return { percent = self:part(__get(__game__Player_xp) + __get(__game__Player_rested)) }
end

local function __c27(self)
	return __string_format("%d%%", __math_floor(self:part(__get(__game__Player_xp))))
end

local function __c28(self)
	return { percent = self:standingPart() }
end

local function __c29(self)
	return __string_format("%s: %s %d%%", __get(__game__Reputation_name), __get(__game__Reputation_standing), __math_floor(self:standingPart()))
end

local function __b33(self)
	return __get(self.leveling)
end

local function __d34(self, parent)
	local __c35 = Tube.new(parent, __getKey(__Ordaen_core.theme, "panel").xpFill, self.xpShare, self.xpLabel, self.restedShare)
	__draw(parent, __c35, nil)
end

local __w32 = { __b33, __d34 }

local function __b37(self)
	return __get(self.showsReputation)
end

local function __d38(self, parent)
	local __c39 = Tube.new(parent, __getKey(__Ordaen_core.theme, "panel").xpSteel, self.reputationShare, self.reputationLabel, nil)
	__draw(parent, __c39, nil)
end

local __w36 = { __b37, __d38 }

local function __d30(self, parent)
	local __e31 = __el(parent, "box")
	__attr(__e31, "minWidth", 240)
	__attr(__e31, "padding", MARGINS)
	__attr(__e31, "yAlign", "center")
	__attr(__e31, "gap", 5)
	__when(__e31, __w32, self)
	__when(__e31, __w36, self)
end

TUBE_HEIGHT = 25
LEAST = 240
MARGINS = { right = 32, left = 32 }
INSET = 3.90625
RESTED = { r = 0.431, g = 0.588, b = 0.820, a = 0.161 }
CLEAR = { r = 0, g = 0, b = 0, a = 0 }
LABEL = { r = 0.953, g = 0.906, b = 0.800, a = 1 }
LABEL_SHADOW = { color = { r = 0, g = 0, b = 0, a = 1 }, x = 1, y = -1 }
FILL = { { fr = 1 } }
CELLS = { 1, 2, 3, 4, 5, 6, 7, 8, 9 }
MARK = { width = 1, color = { r = 0, g = 0, b = 0, a = 0.502 }, sides = { "right" } }
NONE = { percent = 0 }

Tube = __class({})

function Tube.new(__owner, fill, share, label, behind)
	local self = setmetatable({}, Tube)
	R.adopt(__owner, self)
	if behind == nil then behind = __cell(NONE) end
	self.fill = fill
	self.share = share
	self.label = label
	self.behind = behind
	return self
end

function Tube:render()
	return __template(__d1, self)
end

XpBar = __class({})

function XpBar.new(__owner, both)
	local self = setmetatable({}, XpBar)
	R.adopt(__owner, self)
	if both == nil then both = __cell(false) end
	self.both = both
	self.leveling = __computed(self, __c22, self)
	self.watched = __computed(self, __c23, self)
	self.showsReputation = __computed(self, __c24, self)
	self.xpShare = __computed(self, __c25, self)
	self.restedShare = __computed(self, __c26, self)
	self.xpLabel = __computed(self, __c27, self)
	self.reputationShare = __computed(self, __c28, self)
	self.reputationLabel = __computed(self, __c29, self)
	return self
end

function XpBar:part(amount)
	local most = __get(__game__Player_xpMax)
	if most <= 0 then
		return 0
	end
	return 100 * __math_min(amount, most) / most
end

function XpBar:standingPart()
	local span = __get(__game__Reputation_max) - __get(__game__Reputation_min)
	if span <= 0 then
		return 100
	end
	return 100 * (__get(__game__Reputation_value) - __get(__game__Reputation_min)) / span
end

function XpBar:render()
	return __template(__d30, self)
end
__inherit(Tube, { __Ordaen_module_Component })
__inherit(XpBar, { __Ordaen_module_Component })

M.TUBE_HEIGHT = TUBE_HEIGHT
M.LEAST = LEAST
M.MARGINS = MARGINS
M.INSET = INSET
M.RESTED = RESTED
M.CLEAR = CLEAR
M.LABEL = LABEL
M.LABEL_SHADOW = LABEL_SHADOW
M.FILL = FILL
M.CELLS = CELLS
M.MARK = MARK
M.NONE = NONE
M.Tube = Tube
M.XpBar = XpBar
