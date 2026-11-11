-- Made by lunatype from OrdaenMinimap/ring.luna: change the source, not this file.
local R = LunaType
local __get, __getKey, __computed, __class, __inherit, __el, __attr, __bind, __on, __template, __when = R.get, R.getKey, R.computed, R.class, R.inherit, R.el, R.attr, R.bind, R.on, R.template, R.when
local __Ordaen_core = R.addon("Ordaen")["core"]
local __string_of = R.string.of
local __game__Frames_MinimapTrackingButton = R.game.Frames.MinimapTrackingButton
local __game__Frames_MinimapMail = R.game.Frames.MinimapMail
local __game__Frames_MinimapCraftingOrder = R.game.Frames.MinimapCraftingOrder
local __game__Frames_ExpansionLandingPageMinimapButton = R.game.Frames.ExpansionLandingPageMinimapButton
local __game__Minimap_press = R.game.Minimap.press
local __game__Minimap_hover = R.game.Minimap.hover
local __Ordaen_module_Component = R.addon("Ordaen")["module"].Component
local M = {}
R.addon("OrdaenMinimap")["ring"] = M
local BUTTON, ROOM, ORDAEN_BUTTON, DRAWER_BUTTON, RING, GOLD, COUNT_SHADOW, RingButton

local function __c1(self)
	return self.map:ringLeft(self.spec)
end

local function __c2(self)
	return self.map:ringTop(self.spec)
end

local function __c3(self)
	return self.map:ringOpacity()
end

local function __c4(self)
	return self:frameOf()
end

local function __c5(self)
	return self:shownNow()
end

local function __c6(self)
	local __t7
	if self.spec.id == "drawer" and self.map:isDrawerOpen() then
		__t7 = __getKey(__Ordaen_core.theme, "minimap").ringLit
	else
		__t7 = __getKey(__Ordaen_core.theme, "minimap").ring
	end
	return __t7
end

local function __c8(self)
	return __string_of(self.map:holds())
end

local function __b14(self)
	return __get(self.visible)
end

local function __b17(self)
	return __get(self.theirs) ~= nil
end

local function __b20(self)
	return __get(self.theirs)
end

local function __b21(self)
	return __get(self.left)
end

local function __b22(self)
	return __get(self.top)
end

local function __d18(self, parent)
	local __e19 = __el(parent, "embed")
	__bind(__e19, "frame", __b20, self)
	__attr(__e19, "position", "absolute")
	__bind(__e19, "left", __b21, self)
	__bind(__e19, "top", __b22, self)
	__attr(__e19, "width", 28.333333333333336)
	__attr(__e19, "height", 28.333333333333336)
	__attr(__e19, "opacity", 0)
end

local __w16 = { __b17, __d18 }

local function __b24(self)
	return __get(self.left)
end

local function __b25(self)
	return __get(self.top)
end

local function __b26(self)
	return __get(self.opacity)
end

local function __b27(self)
	return __get(self.art)
end

local function __b29(self)
	return self.spec.id == "ordaen"
end

local function __b32(self)
	return __getKey(__Ordaen_core.theme, "panel").faceRound
end

local function __d30(self, parent)
	local __e31 = __el(parent, "box")
	__attr(__e31, "width", 18.333333333333336)
	__attr(__e31, "height", 18.333333333333336)
	__attr(__e31, "background", __Ordaen_core.icon)
	__bind(__e31, "mask", __b32, self)
end

local function __b33(self)
	return self.spec.id == "drawer"
end

local function __b36(self)
	return __get(self.count)
end

local function __b37(self)
	return __getKey(__Ordaen_core.theme, "font").numbers
end

local function __d34(self, parent)
	local __e35 = __el(parent, "text")
	__bind(__e35, "value", __b36, self)
	__attr(__e35, "textColor", GOLD)
	__attr(__e35, "textSize", 11.666666666666668)
	__bind(__e35, "textFamily", __b37, self)
	__attr(__e35, "textShadow", COUNT_SHADOW)
	__attr(__e35, "wrap", false)
end

local function __b38(self)
	return self.spec.glyph ~= nil
end

local function __d39(self, parent)
	local __e40 = __el(parent, "box")
	__attr(__e40, "width", self.spec.glyphWidth)
	__attr(__e40, "height", self.spec.glyphHeight)
	__attr(__e40, "background", self.spec.glyph)
end

local __w28 = { __b29, __d30, __b33, __d34, __b38, __d39 }

local function __d15(self, parent)
	__when(parent, __w16, self)
	local __e23 = __el(parent, "box")
	__attr(__e23, "position", "absolute")
	__bind(__e23, "left", __b24, self)
	__bind(__e23, "top", __b25, self)
	__attr(__e23, "width", 28.333333333333336)
	__attr(__e23, "height", 28.333333333333336)
	__bind(__e23, "opacity", __b26, self)
	__attr(__e23, "xAlign", "center")
	__attr(__e23, "yAlign", "center")
	__bind(__e23, "background", __b27, self)
	__on(__e23, "click", self, self.onClick)
	__on(__e23, "dragStart", self, self.onDragStart)
	__on(__e23, "drag", self, self.onDrag)
	__on(__e23, "dragStop", self, self.onDragStop)
	__on(__e23, "enter", self, self.onEnter)
	__on(__e23, "leave", self, self.onLeave)
	__when(__e23, __w28, self)
end

local __w13 = { __b14, __d15 }

local function __d12(self, parent)
	__when(parent, __w13, self)
end

BUTTON = 28.333333333333336
ROOM = 27.5
ORDAEN_BUTTON = { id = "ordaen", angle = 250, glyphWidth = 0, glyphHeight = 0 }
DRAWER_BUTTON = { id = "drawer", angle = 225, glyphWidth = 0, glyphHeight = 0 }
RING = { { id = "tracking", angle = 290, glyph = "ui-hud-minimap-tracking-up", glyphWidth = 13.333333333333334, glyphHeight = 12.5 }, ORDAEN_BUTTON, DRAWER_BUTTON, { id = "mail", angle = 65, glyph = "ui-hud-minimap-mail-up", glyphWidth = 15, glyphHeight = 11.25 }, { id = "craftingOrder", angle = 85, glyphWidth = 0, glyphHeight = 0 }, { id = "landing", angle = 120, glyphWidth = 0, glyphHeight = 0 } }
GOLD = { r = 1, g = 0.820, b = 0, a = 1 }
COUNT_SHADOW = { color = { r = 0, g = 0, b = 0, a = 1 }, x = 1, y = -1 }

RingButton = __class({})

function RingButton.new(__owner, spec, map)
	local self = setmetatable({}, RingButton)
	R.adopt(__owner, self)
	self.spec = spec
	self.map = map
	self.left = __computed(self, __c1, self)
	self.top = __computed(self, __c2, self)
	self.opacity = __computed(self, __c3, self)
	self.theirs = __computed(self, __c4, self)
	self.visible = __computed(self, __c5, self)
	self.art = __computed(self, __c6, self)
	self.count = __computed(self, __c8, self)
	return self
end

function RingButton:frameOf()
	local __s9 = self.spec.id
	if __s9 == "tracking" then
		return __get(__game__Frames_MinimapTrackingButton)
	elseif __s9 == "mail" then
		return __get(__game__Frames_MinimapMail)
	elseif __s9 == "craftingOrder" then
		return __get(__game__Frames_MinimapCraftingOrder)
	elseif __s9 == "landing" then
		return __get(__game__Frames_ExpansionLandingPageMinimapButton)
	elseif __s9 == "ordaen" or __s9 == "drawer" then
		return nil
	end
	return nil
end

function RingButton:shownNow()
	local __s10 = self.spec.id
	if __s10 == "ordaen" or __s10 == "tracking" then
		return true
	elseif __s10 == "drawer" then
		return self.map:isDrawerOn() and self.map:holds() > 0
	else
		local frame = __get(self.theirs)
		return frame ~= nil and frame:IsShown()
	end
	return true
end

function RingButton:onClick(click)
	local frame = __get(self.theirs)
	local __s11 = self.spec.id
	if __s11 == "ordaen" then
		if click.button == "RightButton" then
			__Ordaen_core.toggleDev()
		else
			__Ordaen_core.toggleSettings()
		end
	elseif __s11 == "drawer" then
		self.map:toggleDrawer()
	else
		if frame ~= nil then
			__game__Minimap_press(frame, click.button)
		end
	end
end

function RingButton:onEnter()
	local frame = __get(self.theirs)
	if frame ~= nil then
		__game__Minimap_hover(frame, true)
	elseif self.spec.id == "drawer" then
		self.map:showHint("drawer")
	else
		self.map:showHint("ordaen")
	end
end

function RingButton:onLeave()
	local frame = __get(self.theirs)
	if frame ~= nil then
		__game__Minimap_hover(frame, false)
	else
		self.map:showHint("none")
	end
end

function RingButton:onDragStart()
	self.map:startDrag(self.spec)
end

function RingButton:onDrag(drag)
	self.map:dragTo(drag.x, drag.y)
end

function RingButton:onDragStop()
	self.map:stopDrag(self.spec)
end

function RingButton:render()
	return __template(__d12, self)
end

RingButton["onClick$Click"] = function(self, __click_button, __click_x, __click_y)
	local frame = __get(self.theirs)
	local __s41 = self.spec.id
	if __s41 == "ordaen" then
		if __click_button == "RightButton" then
			__Ordaen_core.toggleDev()
		else
			__Ordaen_core.toggleSettings()
		end
	elseif __s41 == "drawer" then
		self.map:toggleDrawer()
	else
		if frame ~= nil then
			__game__Minimap_press(frame, __click_button)
		end
	end
end

RingButton["onDrag$Drag"] = function(self, __drag_x, __drag_y, __drag_dx, __drag_dy)
	self.map:dragTo(__drag_x, __drag_y)
end
__inherit(RingButton, { __Ordaen_module_Component })

M.BUTTON = BUTTON
M.ROOM = ROOM
M.ORDAEN_BUTTON = ORDAEN_BUTTON
M.DRAWER_BUTTON = DRAWER_BUTTON
M.RING = RING
M.GOLD = GOLD
M.COUNT_SHADOW = COUNT_SHADOW
M.RingButton = RingButton
