-- Made by lunatype from OrdaenLibrary/settingsTab.luna: change the source, not this file.
local R = LunaType
local __get, __cell, __class, __inherit, __el, __attr, __bind, __template, __slot = R.get, R.cell, R.class, R.inherit, R.el, R.attr, R.bind, R.template, R.slot
local __Ordaen_module_Component = R.addon("Ordaen")["module"].Component
local M = {}
R.addon("OrdaenLibrary")["settingsTab"] = M
local SettingsTab

local function __b3(self)
	return __get(self.shown)
end

local function __d1(self, parent)
	local __e2 = __el(parent, "box")
	__attr(__e2, "columns", 1)
	__attr(__e2, "gap", 11.666666666666668)
	__bind(__e2, "shown", __b3, self)
	__slot(__e2, self, "", nil, nil)
end


SettingsTab = __class({})

function SettingsTab.new(__owner, title, shown)
	local self = setmetatable({}, SettingsTab)
	R.adopt(__owner, self)
	if shown == nil then shown = __cell(true) end
	self.title = title
	self.shown = shown
	return self
end

function SettingsTab:render()
	return __template(__d1, self)
end
__inherit(SettingsTab, { __Ordaen_module_Component })

M.SettingsTab = SettingsTab
