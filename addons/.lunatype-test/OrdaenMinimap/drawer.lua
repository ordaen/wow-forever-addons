-- Made by lunatype from OrdaenMinimap/drawer.luna: change the source, not this file.
local R = LunaType
local __get, __getKey, __computed, __event, __emit, __class, __inherit, __el, __attr, __bind, __on, __template = R.get, R.getKey, R.computed, R.event, R.emit, R.class, R.inherit, R.el, R.attr, R.bind, R.on, R.template
local __game__Minimap_runEntry = R.game.Minimap.runEntry
local __Ordaen_core = R.addon("Ordaen")["core"]
local __Ordaen_module_Component = R.addon("Ordaen")["module"].Component
local M = {}
R.addon("OrdaenMinimap")["drawer"] = M
local CELL, ICON, DrawerEntry

local function __c1(self)
	return __getKey(self.entry, "icon") or "Interface/Icons/INV_Misc_QuestionMark"
end

local function __b4(self)
	return __getKey(__Ordaen_core.theme, "panel").slotEdge
end

local function __b6(self)
	return __get(self.icon)
end

local function __d2(self, parent)
	local __e3 = __el(parent, "box")
	__attr(__e3, "width", 28.333333333333336)
	__attr(__e3, "height", 28.333333333333336)
	__attr(__e3, "xAlign", "center")
	__attr(__e3, "yAlign", "center")
	__bind(__e3, "border", __b4, self)
	__on(__e3, "click", self, self.onClick)
	__on(__e3, "enter", self, self.onEnter)
	__on(__e3, "leave", self, self.onLeave)
	local __e5 = __el(__e3, "box")
	__attr(__e5, "width", 25.000000000000004)
	__attr(__e5, "height", 25.000000000000004)
	__bind(__e5, "background", __b6, self)
end

CELL = 28.333333333333336
ICON = 25.000000000000004

DrawerEntry = __class({})

function DrawerEntry.new(__owner, entry)
	local self = setmetatable({}, DrawerEntry)
	R.adopt(__owner, self)
	self.entry = entry
	self.hover = __event()
	self.leave = __event()
	self.icon = __computed(self, __c1, self)
	return self
end

function DrawerEntry:onClick(click)
	__game__Minimap_runEntry(__get(self.entry), click.button)
end

function DrawerEntry:onEnter()
	__emit(self.hover, __getKey(self.entry, "text"))
end

function DrawerEntry:onLeave()
	__emit(self.leave)
end

function DrawerEntry:render()
	return __template(__d2, self)
end

DrawerEntry["onClick$Click"] = function(self, __click_button, __click_x, __click_y)
	__game__Minimap_runEntry(__get(self.entry), __click_button)
end
__inherit(DrawerEntry, { __Ordaen_module_Component })

M.CELL = CELL
M.ICON = ICON
M.DrawerEntry = DrawerEntry
