-- Made by lunatype from OrdaenLibrary/section.luna: change the source, not this file.
local R = LunaType
local __get, __getKey, __class, __inherit, __el, __attr, __bind, __template, __slot = R.get, R.getKey, R.class, R.inherit, R.el, R.attr, R.bind, R.template, R.slot
local __Ordaen_core = R.addon("Ordaen")["core"]
local __Ordaen_module_Component = R.addon("Ordaen")["module"].Component
local M = {}
R.addon("OrdaenLibrary")["section"] = M
local GOLD, BOLD, Section

local function __b5(self)
	return __get(self.title)
end

local function __b7(self)
	return __getKey(__Ordaen_core.theme, "ctl").rule
end

local function __d1(self, parent)
	local __e2 = __el(parent, "box")
	__attr(__e2, "columns", 1)
	__attr(__e2, "gap", 11.666666666666668)
	local __e3 = __el(__e2, "box")
	__attr(__e3, "columns", { "auto", { fr = 1 } })
	__attr(__e3, "gap", 8.333333333333334)
	__attr(__e3, "yAlign", "center")
	local __e4 = __el(__e3, "text")
	__bind(__e4, "value", __b5, self)
	__attr(__e4, "textColor", GOLD)
	__attr(__e4, "textSize", 12.5)
	__attr(__e4, "textShadow", BOLD)
	__attr(__e4, "wrap", false)
	local __e6 = __el(__e3, "box")
	__attr(__e6, "height", 0.8333333333333334)
	__bind(__e6, "background", __b7, self)
	__slot(__e2, self, "", nil, nil)
end

GOLD = { r = 0.910, g = 0.765, b = 0.353, a = 1 }
BOLD = { color = GOLD, x = 0.8333333333333334, y = 0 }

Section = __class({})

function Section.new(__owner, title)
	local self = setmetatable({}, Section)
	R.adopt(__owner, self)
	self.title = title
	return self
end

function Section:render()
	return __template(__d1, self)
end
__inherit(Section, { __Ordaen_module_Component })

M.GOLD = GOLD
M.BOLD = BOLD
M.Section = Section
