-- Made by lunatype from OrdaenLibrary/tip.luna: change the source, not this file.
local R = LunaType
local __get, __getKey, __class, __inherit, __el, __attr, __bind, __template = R.get, R.getKey, R.class, R.inherit, R.el, R.attr, R.bind, R.template
local __Ordaen_core = R.addon("Ordaen")["core"]
local __Ordaen_module_Component = R.addon("Ordaen")["module"].Component
local M = {}
R.addon("OrdaenLibrary")["tip"] = M
local WIDTH, NAME, LABEL, Tip

local function __b3(self)
	return __get(self.left)
end

local function __b4(self)
	return __get(self.top)
end

local function __b5(self)
	return __getKey(__Ordaen_core.theme, "frame").small
end

local function __b6(self)
	return __getKey(__Ordaen_core.theme, "window").wood
end

local function __b8(self)
	return __get(self.title)
end

local function __b10(self)
	return __get(self.text)
end

local function __d1(self, parent)
	local __e2 = __el(parent, "box")
	__attr(__e2, "position", "absolute")
	__bind(__e2, "left", __b3, self)
	__bind(__e2, "top", __b4, self)
	__attr(__e2, "width", 261.6666666666667)
	__attr(__e2, "zLevel", 60)
	__bind(__e2, "border", __b5, self)
	__bind(__e2, "background", __b6, self)
	__attr(__e2, "artOrigin", true)
	__attr(__e2, "padding", 10)
	__attr(__e2, "columns", 1)
	__attr(__e2, "gap", 1.6666666666666667)
	local __e7 = __el(__e2, "text")
	__bind(__e7, "value", __b8, self)
	__attr(__e7, "textColor", NAME)
	__attr(__e7, "textSize", 15)
	local __e9 = __el(__e2, "text")
	__bind(__e9, "value", __b10, self)
	__attr(__e9, "textColor", LABEL)
	__attr(__e9, "textSize", 11.666666666666668)
end

WIDTH = 261.6666666666667
NAME = { r = 1, g = 1, b = 1, a = 1 }
LABEL = { r = 0.796, g = 0.725, b = 0.580, a = 1 }

Tip = __class({})

function Tip.new(__owner, title, text, left, top)
	local self = setmetatable({}, Tip)
	R.adopt(__owner, self)
	self.title = title
	self.text = text
	self.left = left
	self.top = top
	return self
end

function Tip:render()
	return __template(__d1, self)
end
__inherit(Tip, { __Ordaen_module_Component })

M.WIDTH = WIDTH
M.NAME = NAME
M.LABEL = LABEL
M.Tip = Tip
