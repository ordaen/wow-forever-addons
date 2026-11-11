-- Made by lunatype from Ordaen/placed.luna: change the source, not this file.
local R = LunaType
local __get, __peek, __set, __cell, __computed, __class, __inherit, __el, __attr, __bind, __on, __template, __slot, __when = R.get, R.peek, R.set, R.cell, R.computed, R.class, R.inherit, R.el, R.attr, R.bind, R.on, R.template, R.slot, R.when
local __Ordaen_core = R.addon("Ordaen")["core"]
local __Ordaen_module_Component = R.addon("Ordaen")["module"].Component
local M = {}
R.addon("Ordaen")["placed"] = M
local GOLD, SHADE, OUTLINE, Placed

local function __c1(self)
	return __Ordaen_core.moved(self.id)
end

local function __c2(self)
	return __get(self.dragged) or __get(self.kept) or __get(self.home)
end

local function __b5(self)
	return __get(self.place)
end

local function __b7(self)
	return __get(__Ordaen_core.placing)
end

local function __d8(self, parent)
	local __e9 = __el(parent, "box")
	__attr(__e9, "position", "absolute")
	__attr(__e9, "left", 0)
	__attr(__e9, "top", 0)
	__attr(__e9, "right", 0)
	__attr(__e9, "bottom", 0)
	__attr(__e9, "zLevel", 20)
	__attr(__e9, "background", SHADE)
	__attr(__e9, "border", OUTLINE)
	__attr(__e9, "xAlign", "center")
	__attr(__e9, "yAlign", "center")
	__on(__e9, "dragStart", self, self.onGrab)
	__on(__e9, "drag", self, self.onDrag)
	__on(__e9, "dragStop", self, self.onDrop)
	__on(__e9, "click", self, self.onClick)
	local __e10 = __el(__e9, "text")
	__attr(__e10, "value", self.title)
	__attr(__e10, "textColor", GOLD)
	__attr(__e10, "wrap", false)
end

local __w6 = { __b7, __d8 }

local function __d3(self, parent)
	local __e4 = __el(parent, "surface")
	__attr(__e4, "layer", "screen")
	__bind(__e4, "place", __b5, self)
	__attr(__e4, "clamp", true)
	__slot(__e4, self, "", nil, nil)
	__when(__e4, __w6, self)
end

GOLD = { r = 1, g = 0.820, b = 0, a = 1 }
SHADE = { r = 0, g = 0, b = 0, a = 0.451 }
OUTLINE = { width = 1, color = GOLD }

Placed = __class({})

function Placed.new(__owner, id, title, home)
	local self = setmetatable({}, Placed)
	R.adopt(__owner, self)
	self.id = id
	self.title = title
	self.home = home
	self.kept = __computed(self, __c1, self)
	self.place = __computed(self, __c2, self)
	self.from = { point = "CENTER" }
	self.dragged = __cell(nil)
	return self
end

function Placed:onGrab()
	self.from = __peek(self.kept) or __peek(self.home)
	__set(self.dragged, self.from)
end

function Placed:onDrag(drag)
	__set(self.dragged, { point = self.from.point, to = self.from.to, x = (self.from.x or 0) + drag.dx, y = (self.from.y or 0) + drag.dy })
end

function Placed:onDrop()
	local at = __peek(self.dragged)
	if at ~= nil then
		__Ordaen_core.putAt(self.id, at)
	end
	__set(self.dragged, nil)
end

function Placed:onClick(click)
	if click.button == "RightButton" then
		__Ordaen_core.putAt(self.id, nil)
	end
end

function Placed:render()
	return __template(__d3, self)
end

Placed["onDrag$Drag"] = function(self, __drag_x, __drag_y, __drag_dx, __drag_dy)
	__set(self.dragged, { point = self.from.point, to = self.from.to, x = (self.from.x or 0) + __drag_dx, y = (self.from.y or 0) + __drag_dy })
end

Placed["onClick$Click"] = function(self, __click_button, __click_x, __click_y)
	if __click_button == "RightButton" then
		__Ordaen_core.putAt(self.id, nil)
	end
end
__inherit(Placed, { __Ordaen_module_Component })

M.GOLD = GOLD
M.SHADE = SHADE
M.OUTLINE = OUTLINE
M.Placed = Placed
