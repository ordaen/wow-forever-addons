-- Made by lunatype from OrdaenLibrary/dialog.luna: change the source, not this file.
local R = LunaType
local __get, __getKey, __cell, __computed, __class, __inherit, __el, __attr, __bind, __on, __template, __slot, __when = R.get, R.getKey, R.cell, R.computed, R.class, R.inherit, R.el, R.attr, R.bind, R.on, R.template, R.slot, R.when
local __Ordaen_core = R.addon("Ordaen")["core"]
local __Ordaen_module_Component = R.addon("Ordaen")["module"].Component
local M = {}
R.addon("OrdaenLibrary")["dialog"] = M
local TITLE, SHADOW, SHADE, PLAIN, TITLED, Dialog

local function __c1(self)
	return __get(self.title) ~= ""
end

local function __c2(self)
	local __t3
	if __get(self.titled) then
		__t3 = TITLED
	else
		__t3 = PLAIN
	end
	return __t3
end

local function __b7(self)
	return __get(self.width)
end

local function __b8(self)
	return __getKey(__Ordaen_core.theme, "frame").small
end

local function __b9(self)
	return __getKey(__Ordaen_core.theme, "window").wood
end

local function __b10(self)
	return __get(self.padding)
end

local function __b15(self)
	return __get(self.titled)
end

local function __b19(self)
	return __get(self.title)
end

local function __d16(self, parent)
	local __e17 = __el(parent, "box")
	__attr(__e17, "position", "absolute")
	__attr(__e17, "left", 0)
	__attr(__e17, "right", 0)
	__attr(__e17, "top", 11.666666666666668)
	__attr(__e17, "xAlign", "center")
	local __e18 = __el(__e17, "text")
	__bind(__e18, "value", __b19, self)
	__attr(__e18, "textColor", TITLE)
	__attr(__e18, "textSize", 12.5)
	__attr(__e18, "textShadow", SHADOW)
	__attr(__e18, "wrap", false)
end

local __w14 = { __b15, __d16 }

local function __d4(self, parent)
	local __e5 = __el(parent, "surface")
	__attr(__e5, "layer", "dialog")
	__attr(__e5, "place", "fill")
	__attr(__e5, "zLevel", 100)
	__attr(__e5, "background", SHADE)
	__attr(__e5, "xAlign", "center")
	__attr(__e5, "yAlign", "center")
	__on(__e5, "click", self, self.swallow)
	local __e6 = __el(__e5, "box")
	__bind(__e6, "width", __b7, self)
	__bind(__e6, "border", __b8, self)
	__bind(__e6, "background", __b9, self)
	__attr(__e6, "artOrigin", true)
	__attr(__e6, "columns", 1)
	__attr(__e6, "gap", 11.666666666666668)
	__bind(__e6, "padding", __b10, self)
	__slot(__e6, self, "", nil, nil)
	local __e11 = __el(__e6, "box")
	__attr(__e11, "columns", { { fr = 1 }, "auto" })
	local __e12 = __el(__e11, "box")
	local __e13 = __el(__e11, "box")
	__attr(__e13, "columns", { "auto", "auto", "auto" })
	__attr(__e13, "gap", 6.666666666666667)
	__slot(__e13, self, "buttons", nil, nil)
	__when(__e6, __w14, self)
end

TITLE = { r = 1, g = 0.820, b = 0, a = 1 }
SHADOW = { color = { r = 0, g = 0, b = 0, a = 0.702 }, x = 0.8333333333333334, y = -0.8333333333333334 }
SHADE = { r = 0, g = 0, b = 0, a = 0.549 }
PLAIN = { top = 20, right = 20, bottom = 20, left = 20 }
TITLED = { top = 36.66666666666667, right = 20, bottom = 20, left = 20 }

Dialog = __class({})

function Dialog.new(__owner, width, title)
	local self = setmetatable({}, Dialog)
	R.adopt(__owner, self)
	if title == nil then title = __cell("") end
	self.width = width
	self.title = title
	self.titled = __computed(self, __c1, self)
	self.padding = __computed(self, __c2, self)
	return self
end

function Dialog:swallow()
end

function Dialog:render()
	return __template(__d4, self)
end
__inherit(Dialog, { __Ordaen_module_Component })

M.TITLE = TITLE
M.SHADOW = SHADOW
M.SHADE = SHADE
M.PLAIN = PLAIN
M.TITLED = TITLED
M.Dialog = Dialog
