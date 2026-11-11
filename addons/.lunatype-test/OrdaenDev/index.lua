-- Made by lunatype from OrdaenDev/index.luna: change the source, not this file.
local R = LunaType
local __get, __set, __cell, __computed, __watch, __listen, __class, __inherit, __el, __attr, __bind, __template, __draw, __when, __each = R.get, R.set, R.cell, R.computed, R.watch, R.listen, R.class, R.inherit, R.el, R.attr, R.bind, R.template, R.draw, R.when, R.each
local __insert = table.insert
local __OrdaenDev_dev_available = R.addon("OrdaenDev")["dev"].available
local __Ordaen_core = R.addon("Ordaen")["core"]
local __OrdaenDev_dev_channels = R.addon("OrdaenDev")["dev"].channels
local __OrdaenDev_dev_addons = R.addon("OrdaenDev")["dev"].addons
local __OrdaenDev_dev_hasDump = R.addon("OrdaenDev")["dev"].hasDump
local __game__Clock_seconds = R.game.Clock.seconds
local __OrdaenDev_dev_queued = R.addon("OrdaenDev")["dev"].queued
local __OrdaenDev_dev_errors = R.addon("OrdaenDev")["dev"].errors
local __OrdaenDev_dev_sendState = R.addon("OrdaenDev")["dev"].sendState
local __OrdaenDev_dev_artPreview = R.addon("OrdaenDev")["dev"].artPreview
local __OrdaenDev_dev_clearDump = R.addon("OrdaenDev")["dev"].clearDump
local __OrdaenDev_dev_dumpApi = R.addon("OrdaenDev")["dev"].dumpApi
local __OrdaenLibrary_window_Window = R.addon("OrdaenLibrary")["window"].Window
local __OrdaenLibrary_pushButton_PushButton = R.addon("OrdaenLibrary")["pushButton"].PushButton
local __OrdaenDev_item_Item = R.addon("OrdaenDev")["item"].Item
local __Ordaen_module_Module = R.addon("Ordaen")["module"].Module
local M = {}
R.addon("OrdaenDev")["index"] = M
local WIDTH, HEIGHT, BUTTON, INK, DIM, DevWindow

local function __c1(self)
	return self:statusNow()
end

local function __c2(self)
	return not __OrdaenDev_dev_available
end

local function __c3(self)
	local __t4
	if __get(self.dumped) then
		__t4 = "Clear the API dump"
	else
		__t4 = "Dump the game API"
	end
	return __t4
end

local function __b10(self)
	return __get(__Ordaen_core.dev)
end

local function __b16(self)
	return __get(self.missing)
end

local function __d17(self, parent)
	local __e18 = __el(parent, "text")
	__attr(__e18, "value", "The dev addon (OrdaenCore_Debug) isn't loaded.")
	__attr(__e18, "textColor", DIM)
	__attr(__e18, "textSize", 10.833333333333334)
end

local function __b19(self)
	return __get(self.tab) == 1
end

local function __b23(self)
	return __get(self.status)
end

local function __d20(self, parent)
	local __e21 = __el(parent, "box")
	__attr(__e21, "gap", 8.333333333333334)
	local __e22 = __el(__e21, "text")
	__bind(__e22, "value", __b23, self)
	__attr(__e22, "textColor", INK)
	__attr(__e22, "textSize", 10.833333333333334)
	local __c24 = __OrdaenLibrary_pushButton_PushButton.new(__e21, __cell("Send state"), __cell(125), nil, nil)
	__listen(__c24.click, self, self.onSend)
	__draw(__e21, __c24, nil)
end

local function __b25(self)
	return __get(self.tab) == 2
end

local function __b29(self)
	return __get(self.channels)
end

local function __d30(self, parent, name)
	local __c31 = __OrdaenDev_item_Item.new(parent, name)
	__draw(parent, __c31, nil)
end

local function __d26(self, parent)
	local __e27 = __el(parent, "box")
	__attr(__e27, "gap", 3.3333333333333335)
	local __c28 = __OrdaenDev_item_Item.new(__e27, __cell("recorder:all"))
	__draw(__e27, __c28, nil)
	__each(__e27, __b29, nil, __d30, 1, 0, true, self)
end

local function __b32(self)
	return __get(self.tab) == 3
end

local function __b35(self)
	return __get(self.logging)
end

local function __d36(self, parent, name)
	local __c37 = __OrdaenDev_item_Item.new(parent, name)
	__draw(parent, __c37, nil)
end

local function __d33(self, parent)
	local __e34 = __el(parent, "box")
	__attr(__e34, "gap", 3.3333333333333335)
	__each(__e34, __b35, nil, __d36, 1, 0, true, self)
end

local function __b38(self)
	return __get(self.tab) == 4
end

local function __d39(self, parent)
	local __e40 = __el(parent, "box")
	__attr(__e40, "gap", 3.3333333333333335)
	local __c41 = __OrdaenDev_item_Item.new(__e40, __cell("perf:sampling"))
	__draw(__e40, __c41, nil)
	local __c42 = __OrdaenDev_item_Item.new(__e40, __cell("perf:stripStats"))
	__draw(__e40, __c42, nil)
end

local function __d43(self, parent)
	local __e44 = __el(parent, "box")
	__attr(__e44, "gap", 8.333333333333334)
	local __c45 = __OrdaenLibrary_pushButton_PushButton.new(__e44, self.dumpLabel, __cell(125), nil, nil)
	__listen(__c45.click, self, self.onDump)
	__draw(__e44, __c45, nil)
	local __c46 = __OrdaenDev_item_Item.new(__e44, __cell("tools:artRecord"))
	__draw(__e44, __c46, nil)
	local __c47 = __OrdaenLibrary_pushButton_PushButton.new(__e44, __cell("Art preview"), __cell(125), nil, nil)
	__listen(__c47.click, self, self.onPreview)
	__draw(__e44, __c47, nil)
end

local __w15 = { __b16, __d17, __b19, __d20, __b25, __d26, __b32, __d33, __b38, __d39, false, __d43 }

local function __d13(self, parent)
	local __e14 = __el(parent, "box")
	__attr(__e14, "padding", 11.666666666666668)
	__attr(__e14, "gap", 8.333333333333334)
	__when(__e14, __w15, self)
end

local function __d11(self, parent)
	local __c12 = __OrdaenLibrary_window_Window.new(parent, self.tabs, self.tab, self.placing, nil, nil, nil, nil)
	__listen(__c12.close, self, self.onClose)
	__draw(parent, __c12, { self = self, [""] = __d13 })
end

local __w9 = { __b10, __d11 }

local function __d7(self, parent)
	local __e8 = __el(parent, "box")
	__when(__e8, __w9, self)
end

WIDTH = 433.33333333333337
HEIGHT = 350
BUTTON = 125
INK = { r = 0.910, g = 0.863, b = 0.769, a = 1 }
DIM = { r = 0.639, g = 0.592, b = 0.498, a = 1 }

DevWindow = __class({})

function DevWindow.new(__owner)
	local self = setmetatable({ title = "Ordaen Dev" }, DevWindow)
	R.adopt(__owner, self)
	self.pages = {}
	self.tabs = __cell({ { title = "Status" }, { title = "Recorder" }, { title = "Logging" }, { title = "Performance" }, { title = "Tools" } })
	self.tab = __cell(1)
	self.placing = __cell({ x = 0, y = 0, width = 433.33333333333337, height = 350 })
	self.channels = __cell({})
	self.logging = __cell({})
	self.dumped = __cell(false)
	self.status = __computed(self, __c1, self)
	self.missing = __computed(self, __c2, self)
	self.dumpLabel = __computed(self, __c3, self)
	__watch(self, self.fill, self)
	return self
end

function DevWindow:fill()
	if not __get(__Ordaen_core.dev) then
		return
	end
	__set(self.channels, __OrdaenDev_dev_channels())
	local names = {}
	local __l6 = __OrdaenDev_dev_addons()
	for __i5 = 1, #__l6 do
		local name = __l6[__i5]
		__insert(names, "logging:" .. name)
	end
	__set(self.logging, names)
	__set(self.dumped, __OrdaenDev_dev_hasDump())
end

function DevWindow:statusNow()
	local _ = __get(__game__Clock_seconds)
	return __OrdaenDev_dev_queued() .. " messages wait to be sent, " .. __OrdaenDev_dev_errors() .. " errors this session"
end

function DevWindow:onClose()
	__Ordaen_core.toggleDev()
end

function DevWindow:onSend()
	__OrdaenDev_dev_sendState()
end

function DevWindow:onPreview()
	__OrdaenDev_dev_artPreview()
end

function DevWindow:onDump()
	if __get(self.dumped) then
		__OrdaenDev_dev_clearDump()
	else
		__OrdaenDev_dev_dumpApi()
	end
	__set(self.dumped, __OrdaenDev_dev_hasDump())
end

function DevWindow:render()
	return __template(__d7, self)
end
__inherit(DevWindow, { __Ordaen_module_Module })

M.WIDTH = WIDTH
M.HEIGHT = HEIGHT
M.BUTTON = BUTTON
M.INK = INK
M.DIM = DIM
M.DevWindow = DevWindow
