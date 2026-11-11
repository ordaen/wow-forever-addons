-- Made by lunatype from Showcase/windowed.luna: change the source, not this file.
local R = LunaType
local __get, __set, __cell, __computed, __listen, __class, __inherit, __el, __attr, __bind, __template, __draw, __when = R.get, R.set, R.cell, R.computed, R.listen, R.class, R.inherit, R.el, R.attr, R.bind, R.template, R.draw, R.when
local __OrdaenLibrary_window_Window = R.addon("OrdaenLibrary")["window"].Window
local __Ordaen_module_Module = R.addon("Ordaen")["module"].Module
local M = {}
R.addon("Showcase")["windowed"] = M
local Windowed

local function __c1(self)
	local __t2
	if __get(self.tab) == 1 then
		__t2 = "the first tab's page"
	else
		__t2 = "the second tab's page"
	end
	return __t2
end

local function __b7(self)
	return __get(self.open)
end

local function __b13(self)
	return __get(self.body)
end

local function __d10(self, parent)
	local __e11 = __el(parent, "box")
	local __e12 = __el(__e11, "text")
	__bind(__e12, "value", __b13, self)
end

local function __d8(self, parent)
	local __c9 = __OrdaenLibrary_window_Window.new(parent, self.tabs, self.tab, self.placing, nil, nil, 600, nil)
	__listen(__c9.close, self, self.onClose)
	__draw(parent, __c9, { self = self, [""] = __d10 })
end

local __w6 = { __b7, __d8 }

local function __d3(self, parent)
	local __e4 = __el(parent, "box")
	__attr(__e4, "padding", 4)
	local __e5 = __el(__e4, "text")
	__attr(__e5, "value", "a page under the window")
	__when(__e4, __w6, self)
end


Windowed = __class({})

function Windowed.new(__owner)
	local self = setmetatable({ title = "Windowed" }, Windowed)
	R.adopt(__owner, self)
	self.pages = {}
	self.tabs = __cell({ { title = "Professions", desc = "Tailoring 75", icon = "icons/tailoring" }, { title = "Recipes" } })
	self.tab = __cell(1)
	self.placing = __cell({ x = 0, y = 0, width = 400, height = 300 })
	self.open = __cell(true)
	self.body = __computed(self, __c1, self)
	return self
end

function Windowed:onClose()
	__set(self.open, false)
end

function Windowed:render()
	return __template(__d3, self)
end
__inherit(Windowed, { __Ordaen_module_Module })

M.Windowed = Windowed
