-- Made by lunatype from OrdaenLibrary/zones.luna: change the source, not this file.
local R = LunaType
local __get, __getKey, __set, __setKey, __cell, __computed, __class, __inherit, __el, __attr, __bind, __on, __template, __draw, __when, __each = R.get, R.getKey, R.set, R.setKey, R.cell, R.computed, R.class, R.inherit, R.el, R.attr, R.bind, R.on, R.template, R.draw, R.when, R.each
local __OrdaenLibrary_tip_Tip = R.addon("OrdaenLibrary")["tip"].Tip
local __Ordaen_module_Component = R.addon("Ordaen")["module"].Component
local M = {}
R.addon("OrdaenLibrary")["zones"] = M
local DIM, CHIP_TEXT, BOX, BRONZE, DIVIDER, CHIP, CHIP_EDGE, CHIP_PAD, POOL, POOL_EDGE, ZoneChip, ZoneColumn, Zones

local function __c1(self)
	local __t2
	if __get(self.pooled) then
		__t2 = 0.8
	else
		__t2 = 1
	end
	return __t2
end

local function __b5(self)
	return __get(self.pooled)
end

local function __b6(self)
	return __get(self.opacity)
end

local function __b8(self)
	return __getKey(self.item, "label")
end

local function __d3(self, parent)
	local __e4 = __el(parent, "box")
	__attr(__e4, "padding", CHIP_PAD)
	__attr(__e4, "background", CHIP)
	__attr(__e4, "border", CHIP_EDGE)
	__bind(__e4, "desaturate", __b5, self)
	__bind(__e4, "opacity", __b6, self)
	__on(__e4, "dragStart", self, self.onGrab)
	__on(__e4, "dragStop", self, self.onRelease)
	__on(__e4, "enter", self, self.onEnter)
	__on(__e4, "leave", self, self.onLeave)
	local __e7 = __el(__e4, "text")
	__bind(__e7, "value", __b8, self)
	__attr(__e7, "textColor", CHIP_TEXT)
	__attr(__e7, "textSize", 11.666666666666668)
	__attr(__e7, "wrap", false)
end

local function __c9(self)
	return self:alignOf()
end

local function __c10(self)
	local __t11
	if __get(self.index) > 1 then
		__t11 = DIVIDER
	else
		__t11 = nil
	end
	return __t11
end

local function __c12(self)
	return not __get(self.pool)
end

local function __b15(self)
	return __get(self.align)
end

local function __b16(self)
	return __get(self.divider)
end

local function __b18(self)
	return __get(self.named)
end

local function __b21(self)
	return __getKey(self.zone, "label")
end

local function __d19(self, parent)
	local __e20 = __el(parent, "text")
	__bind(__e20, "value", __b21, self)
	__attr(__e20, "textColor", DIM)
	__attr(__e20, "textSize", 10)
end

local __w17 = { __b18, __d19 }

local function __b22(self)
	return self.items
end

local function __b25(self, item)
	return __getKey(self.value, item.key) == __getKey(self.zone, "value")
end

local function __d26(self, parent, item)
	local __c27 = ZoneChip.new(parent, __cell(item), self.dragging, self.hinted, self.pool)
	__draw(parent, __c27, nil)
end

local __w24 = { __b25, __d26 }

local function __d23(self, parent, item)
	__when(parent, __w24, self, item)
end

local function __d13(self, parent)
	local __e14 = __el(parent, "box")
	__attr(__e14, "columns", 1)
	__attr(__e14, "gap", 5)
	__attr(__e14, "padding", 6.666666666666667)
	__bind(__e14, "xAlign", __b15, self)
	__attr(__e14, "yAlign", "start")
	__bind(__e14, "border", __b16, self)
	__on(__e14, "drop", self, self.onDrop)
	__when(__e14, __w17, self)
	__each(__e14, __b22, nil, __d23, 1, 0, false, self)
end

local function __c28(self)
	local __t29 = self:hintedItem()
	local __t30
	if __t29 ~= nil then __t30 = __t29.label end
	return __t30 or ""
end

local function __c31(self)
	local __t32 = self:hintedItem()
	local __t33
	if __t32 ~= nil then __t33 = __t32.hint end
	return __t33 or ""
end

local function __c34(self)
	return __get(self.hintText) ~= ""
end

local function __b40(self)
	return self.zones
end

local function __d41(self, parent, index, zone)
	local __c42 = ZoneColumn.new(parent, __cell(zone), __cell(index), self.items, self.value, self.dragging, self.hinted, nil)
	__draw(parent, __c42, nil)
end

local function __b47(self)
	return __get(self.hintShown)
end

local function __d48(self, parent)
	local __c49 = __OrdaenLibrary_tip_Tip.new(parent, self.hintTitle, self.hintText, __cell(0), __cell(0))
	__draw(parent, __c49, nil)
end

local __w46 = { __b47, __d48 }

local function __d37(self, parent)
	local __e38 = __el(parent, "box")
	__attr(__e38, "columns", 1)
	__attr(__e38, "gap", 6.666666666666667)
	local __e39 = __el(__e38, "box")
	__attr(__e39, "columns", #self.zones)
	__attr(__e39, "background", BOX)
	__attr(__e39, "border", BRONZE)
	__each(__e39, __b40, nil, __d41, 2, 1, false, self)
	local __e43 = __el(__e38, "text")
	__attr(__e43, "value", self.off.label)
	__attr(__e43, "textColor", DIM)
	__attr(__e43, "textSize", 10.833333333333334)
	local __e44 = __el(__e38, "box")
	__attr(__e44, "columns", 1)
	__attr(__e44, "background", POOL)
	__attr(__e44, "border", POOL_EDGE)
	local __c45 = ZoneColumn.new(__e44, __cell(self.off), __cell(1), self.items, self.value, self.dragging, self.hinted, __cell(true))
	__draw(__e44, __c45, nil)
	__when(__e38, __w46, self)
end

DIM = { r = 0.639, g = 0.592, b = 0.498, a = 1 }
CHIP_TEXT = { r = 0.953, g = 0.882, b = 0.722, a = 1 }
BOX = { r = 0.165, g = 0.118, b = 0.063, a = 1 }
BRONZE = { width = 0.8333333333333334, color = { r = 0.424, g = 0.333, b = 0.208, a = 1 } }
DIVIDER = { width = 0.8333333333333334, color = { r = 0.243, g = 0.184, b = 0.114, a = 1 }, sides = { "left" } }
CHIP = { r = 0.353, g = 0.267, b = 0.157, a = 1 }
CHIP_EDGE = { width = 0.8333333333333334, color = { r = 0.102, g = 0.075, b = 0.024, a = 1 } }
CHIP_PAD = { top = 3.3333333333333335, right = 8.333333333333334, bottom = 3.3333333333333335, left = 8.333333333333334 }
POOL = { r = 0, g = 0, b = 0, a = 0.251 }
POOL_EDGE = { width = 0.8333333333333334, color = { r = 0.290, g = 0.227, b = 0.141, a = 1 } }

ZoneChip = __class({})

function ZoneChip.new(__owner, item, dragging, hinted, pooled)
	local self = setmetatable({}, ZoneChip)
	R.adopt(__owner, self)
	self.item = item
	self.dragging = dragging
	self.hinted = hinted
	self.pooled = pooled
	self.opacity = __computed(self, __c1, self)
	return self
end

function ZoneChip:onGrab()
	__set(self.dragging, __getKey(self.item, "key"))
	__set(self.hinted, nil)
end

function ZoneChip:onRelease()
	__set(self.dragging, nil)
end

function ZoneChip:onEnter()
	if __get(self.dragging) == nil then
		__set(self.hinted, __getKey(self.item, "key"))
	end
end

function ZoneChip:onLeave()
	__set(self.hinted, nil)
end

function ZoneChip:render()
	return __template(__d3, self)
end

ZoneColumn = __class({})

function ZoneColumn.new(__owner, zone, index, items, value, dragging, hinted, pool)
	local self = setmetatable({}, ZoneColumn)
	R.adopt(__owner, self)
	if pool == nil then pool = __cell(false) end
	self.zone = zone
	self.index = index
	self.items = items
	self.value = value
	self.dragging = dragging
	self.hinted = hinted
	self.pool = pool
	self.align = __computed(self, __c9, self)
	self.divider = __computed(self, __c10, self)
	self.named = __computed(self, __c12, self)
	return self
end

function ZoneColumn:alignOf()
	if __get(self.pool) then
		return "start"
	end
	if __get(self.index) == 2 then
		return "center"
	end
	if __get(self.index) == 3 then
		return "end"
	end
	return "start"
end

function ZoneColumn:onDrop()
	local key = __get(self.dragging)
	if key ~= nil and __getKey(self.value, key) ~= __getKey(self.zone, "value") then
		__setKey(self.value, key, __getKey(self.zone, "value"))
	end
end

function ZoneColumn:render()
	return __template(__d13, self)
end

Zones = __class({})

function Zones.new(__owner, items, zones, off, value)
	local self = setmetatable({}, Zones)
	R.adopt(__owner, self)
	self.items = items
	self.zones = zones
	self.off = off
	self.value = value
	self.dragging = __cell(nil)
	self.hinted = __cell(nil)
	self.hintTitle = __computed(self, __c28, self)
	self.hintText = __computed(self, __c31, self)
	self.hintShown = __computed(self, __c34, self)
	return self
end

function Zones:hintedItem()
	local key = __get(self.hinted)
	if key == nil then
		return nil
	end
	local __l36 = self.items
	for __i35 = 1, #__l36 do
		local item = __l36[__i35]
		if item.key == key then
			return item
		end
	end
	return nil
end

function Zones:render()
	return __template(__d37, self)
end
__inherit(ZoneChip, { __Ordaen_module_Component })
__inherit(ZoneColumn, { __Ordaen_module_Component })
__inherit(Zones, { __Ordaen_module_Component })

M.DIM = DIM
M.CHIP_TEXT = CHIP_TEXT
M.BOX = BOX
M.BRONZE = BRONZE
M.DIVIDER = DIVIDER
M.CHIP = CHIP
M.CHIP_EDGE = CHIP_EDGE
M.CHIP_PAD = CHIP_PAD
M.POOL = POOL
M.POOL_EDGE = POOL_EDGE
M.ZoneChip = ZoneChip
M.ZoneColumn = ZoneColumn
M.Zones = Zones
