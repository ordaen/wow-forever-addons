-- Made by lunatype from OrdaenLibrary/pushButton.luna: change the source, not this file.
local R = LunaType
local __get, __getKey, __cell, __computed, __event, __emit, __class, __inherit, __el, __attr, __bind, __on, __template = R.get, R.getKey, R.cell, R.computed, R.event, R.emit, R.class, R.inherit, R.el, R.attr, R.bind, R.on, R.template
local __Ordaen_core = R.addon("Ordaen")["core"]
local __Ordaen_module_Component = R.addon("Ordaen")["module"].Component
local M = {}
R.addon("OrdaenLibrary")["pushButton"] = M
local HEIGHT, LABEL, GREY, SHADOW, DOWN, PushButton

local function __c1(self)
	local __t2
	if __get(self.disabled) then
		__t2 = __getKey(__Ordaen_core.theme, "ctl").buttonDisabled
	else
		local __t3
		if __get(self.accent) then
			__t3 = __getKey(__Ordaen_core.theme, "ctl").buttonAccent
		else
			__t3 = __getKey(__Ordaen_core.theme, "ctl").button
		end
		__t2 = __t3
	end
	return __t2
end

local function __c4(self)
	local __t5
	if __get(self.disabled) then
		__t5 = GREY
	else
		__t5 = LABEL
	end
	return __t5
end

local function __b8(self)
	return __get(self.width)
end

local function __b9(self)
	return __get(self.art)
end

local function __b12(self)
	return __get(self.label)
end

local function __b13(self)
	return __get(self.color)
end

local function __d6(self, parent)
	local __e7 = __el(parent, "box")
	__bind(__e7, "width", __b8, self)
	__attr(__e7, "height", 28.333333333333336)
	__bind(__e7, "background", __b9, self)
	__on(__e7, "click", self, self.onClick)
	local __e10 = __el(__e7, "box")
	__attr(__e10, "position", "absolute")
	__attr(__e10, "left", 0)
	__attr(__e10, "right", 0)
	__attr(__e10, "top", DOWN)
	__attr(__e10, "height", 28.333333333333336)
	__attr(__e10, "xAlign", "center")
	__attr(__e10, "yAlign", "center")
	__attr(__e10, "stateFromParent", true)
	local __e11 = __el(__e10, "text")
	__bind(__e11, "value", __b12, self)
	__bind(__e11, "textColor", __b13, self)
	__attr(__e11, "textSize", 12.5)
	__attr(__e11, "textShadow", SHADOW)
	__attr(__e11, "wrap", false)
	__attr(__e11, "stateFromParent", true)
end

HEIGHT = 28.333333333333336
LABEL = { default = { r = 1, g = 0.820, b = 0, a = 1 }, hover = { r = 1, g = 1, b = 1, a = 1 } }
GREY = { r = 0.502, g = 0.502, b = 0.502, a = 1 }
SHADOW = { color = { r = 0, g = 0, b = 0, a = 1 }, x = 0.8333333333333334, y = -0.8333333333333334 }
DOWN = { default = 0, pressed = 1.6666666666666667 }

PushButton = __class({})

function PushButton.new(__owner, label, width, accent, disabled)
	local self = setmetatable({}, PushButton)
	R.adopt(__owner, self)
	if accent == nil then accent = __cell(false) end
	if disabled == nil then disabled = __cell(false) end
	self.label = label
	self.width = width
	self.accent = accent
	self.disabled = disabled
	self.click = __event()
	self.art = __computed(self, __c1, self)
	self.color = __computed(self, __c4, self)
	return self
end

function PushButton:onClick()
	if not __get(self.disabled) then
		__emit(self.click)
	end
end

function PushButton:render()
	return __template(__d6, self)
end
__inherit(PushButton, { __Ordaen_module_Component })

M.HEIGHT = HEIGHT
M.LABEL = LABEL
M.GREY = GREY
M.SHADOW = SHADOW
M.DOWN = DOWN
M.PushButton = PushButton
