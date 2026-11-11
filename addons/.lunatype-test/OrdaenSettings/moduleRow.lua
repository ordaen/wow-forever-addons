-- Made by lunatype from OrdaenSettings/moduleRow.luna: change the source, not this file.
local R = LunaType
local __get, __getKey, __cell, __computed, __event, __listen, __emit, __class, __inherit, __el, __attr, __bind, __on, __template, __draw = R.get, R.getKey, R.cell, R.computed, R.event, R.listen, R.emit, R.class, R.inherit, R.el, R.attr, R.bind, R.on, R.template, R.draw
local __Ordaen_core = R.addon("Ordaen")["core"]
local __string_sub = R.string.sub
local __OrdaenLibrary_listTab_ListTab = R.addon("OrdaenLibrary")["listTab"].ListTab
local __Ordaen_module_Component = R.addon("Ordaen")["module"].Component
local M = {}
R.addon("OrdaenSettings")["moduleRow"] = M
local WIDTH, HEIGHT, KNOB, KNOB_TOP, KNOB_OFF, KNOB_ON, PREFIX, ModuleSwitch, ModuleRow

local function __c1(self)
	local __t2
	if __get(self.entry.on) then
		__t2 = __getKey(__Ordaen_core.theme, "ctl").switchOn
	else
		__t2 = __getKey(__Ordaen_core.theme, "ctl").switchOff
	end
	return __t2
end

local function __c3(self)
	local __t4
	if __get(self.entry.on) then
		__t4 = __getKey(__Ordaen_core.theme, "ctl").knobOn
	else
		__t4 = __getKey(__Ordaen_core.theme, "ctl").knobOff
	end
	return __t4
end

local function __c5(self)
	local __t6
	if __get(self.entry.on) then
		__t6 = 12.5
	else
		__t6 = -2.5
	end
	return __t6
end

local function __b9(self)
	return __get(self.track)
end

local function __b11(self)
	return __get(self.knobLeft)
end

local function __b12(self)
	return __get(self.knob)
end

local function __d7(self, parent)
	local __e8 = __el(parent, "box")
	__attr(__e8, "width", 31.666666666666668)
	__attr(__e8, "height", 16.666666666666668)
	__bind(__e8, "background", __b9, self)
	__on(__e8, "click", self, self.flip)
	local __e10 = __el(__e8, "box")
	__attr(__e10, "position", "absolute")
	__bind(__e10, "left", __b11, self)
	__attr(__e10, "top", -2.5)
	__attr(__e10, "width", 21.666666666666668)
	__attr(__e10, "height", 21.666666666666668)
	__bind(__e10, "background", __b12, self)
end

local function __c13(self)
	return self:nameOf()
end

local function __c14(self)
	return __get(self.shown) == self.entry.folder
end

local function __c15(self)
	return not __get(self.entry.on)
end

local function __d18(self, parent)
	local __c19 = ModuleSwitch.new(parent, self.entry)
	__draw(parent, __c19, nil)
end

local function __d16(self, parent)
	local __c17 = __OrdaenLibrary_listTab_ListTab.new(parent, self.name, self.selected, __cell(self.entry.icon), self.off)
	__listen(__c17.pick, self, self.onPick)
	__draw(parent, __c17, { self = self, [""] = __d18 })
end

WIDTH = 31.666666666666668
HEIGHT = 16.666666666666668
KNOB = 21.666666666666668
KNOB_TOP = -2.5
KNOB_OFF = -2.5
KNOB_ON = 12.5
PREFIX = "Ordaen "

ModuleSwitch = __class({})

function ModuleSwitch.new(__owner, entry)
	local self = setmetatable({}, ModuleSwitch)
	R.adopt(__owner, self)
	self.entry = entry
	self.track = __computed(self, __c1, self)
	self.knob = __computed(self, __c3, self)
	self.knobLeft = __computed(self, __c5, self)
	return self
end

function ModuleSwitch:flip()
	self.entry:enable(not __get(self.entry.on))
end

function ModuleSwitch:render()
	return __template(__d7, self)
end

ModuleRow = __class({})

function ModuleRow.new(__owner, entry, shown)
	local self = setmetatable({}, ModuleRow)
	R.adopt(__owner, self)
	self.entry = entry
	self.shown = shown
	self.pick = __event()
	self.name = __computed(self, __c13, self)
	self.selected = __computed(self, __c14, self)
	self.off = __computed(self, __c15, self)
	return self
end

function ModuleRow:nameOf()
	local title = self.entry.title
	if __string_sub(title, 1, #"Ordaen ") == "Ordaen " then
		return __string_sub(title, #"Ordaen " + 1)
	end
	return title
end

function ModuleRow:onPick()
	__emit(self.pick, self.entry.folder)
end

function ModuleRow:render()
	return __template(__d16, self)
end
__inherit(ModuleSwitch, { __Ordaen_module_Component })
__inherit(ModuleRow, { __Ordaen_module_Component })

M.WIDTH = WIDTH
M.HEIGHT = HEIGHT
M.KNOB = KNOB
M.KNOB_TOP = KNOB_TOP
M.KNOB_OFF = KNOB_OFF
M.KNOB_ON = KNOB_ON
M.PREFIX = PREFIX
M.ModuleSwitch = ModuleSwitch
M.ModuleRow = ModuleRow
