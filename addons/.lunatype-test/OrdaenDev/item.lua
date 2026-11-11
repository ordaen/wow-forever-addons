-- Made by lunatype from OrdaenDev/item.luna: change the source, not this file.
local R = LunaType
local __get, __set, __cell, __computed, __watch, __class, __inherit, __template, __draw = R.get, R.set, R.cell, R.computed, R.watch, R.class, R.inherit, R.template, R.draw
local __OrdaenDev_dev_label = R.addon("OrdaenDev")["dev"].label
local __OrdaenDev_dev_tip = R.addon("OrdaenDev")["dev"].tip
local __OrdaenDev_dev_get = R.addon("OrdaenDev")["dev"].get
local __OrdaenDev_dev_set = R.addon("OrdaenDev")["dev"].set
local __OrdaenLibrary_switch_Switch = R.addon("OrdaenLibrary")["switch"].Switch
local __Ordaen_module_Component = R.addon("Ordaen")["module"].Component
local M = {}
R.addon("OrdaenDev")["item"] = M
local Item

local function __c1(self)
	return __OrdaenDev_dev_label(__get(self.name))
end

local function __c2(self)
	return __OrdaenDev_dev_tip(__get(self.name))
end

local function __d3(self, parent)
	local __c4 = __OrdaenLibrary_switch_Switch.new(parent, self.label, self.on, self.hint, nil)
	__draw(parent, __c4, nil)
end


Item = __class({})

function Item.new(__owner, name)
	local self = setmetatable({}, Item)
	R.adopt(__owner, self)
	self.name = name
	self.on = __cell(false)
	self.label = __computed(self, __c1, self)
	self.hint = __computed(self, __c2, self)
	__set(self.on, __OrdaenDev_dev_get(__get(self.name)))
	__watch(self, self.push, self)
	return self
end

function Item:push()
	__OrdaenDev_dev_set(__get(self.name), __get(self.on))
end

function Item:render()
	return __template(__d3, self)
end
__inherit(Item, { __Ordaen_module_Component })

M.Item = Item
