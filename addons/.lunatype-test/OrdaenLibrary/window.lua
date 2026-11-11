-- Made by lunatype from OrdaenLibrary/window.luna: change the source, not this file.
local R = LunaType
local __get, __getKey, __peek, __set, __setKey, __cell, __computed, __event, __listen, __emit, __class, __inherit, __el, __attr, __bind, __on, __template, __draw, __slot, __when, __each = R.get, R.getKey, R.peek, R.set, R.setKey, R.cell, R.computed, R.event, R.listen, R.emit, R.class, R.inherit, R.el, R.attr, R.bind, R.on, R.template, R.draw, R.slot, R.when, R.each
local __insert = table.insert
local __Ordaen_core = R.addon("Ordaen")["core"]
local __math_max = R.math.max
local __math_min = R.math.min
local __Ordaen_module_Component = R.addon("Ordaen")["module"].Component
local M = {}
R.addon("OrdaenLibrary")["window"] = M
local TAB, TAB_DESC, DROP, TITLE_OPEN, TITLE_CLOSED, DESC, SHADE, WHITE, SHADOW, LABEL_PAD, MIN_TAB, INSET, PADDING, BODY_ROWS, MIN_W, MIN_H, BODY_LEVEL, OPEN_LEVEL, WindowTab, Window

local __f = {}

function __f.c1(self)
	return __get(self.selected) == self.index
end

function __f.c2(self)
	local __t3
	if not __get(self.open) then
		__t3 = __getKey(__Ordaen_core.theme, "frame").tab
	else
		local __t4
		if self.index > 1 then
			__t4 = __getKey(__Ordaen_core.theme, "frame").tabOpen
		else
			__t4 = __getKey(__Ordaen_core.theme, "frame").tabOpenFirst
		end
		__t3 = __t4
	end
	return __t3
end

function __f.c5(self)
	return __getKey(__Ordaen_core.theme, "frame").tab.reach.top * __getKey(__Ordaen_core.theme, "frame").tab.scale
end

function __f.c6(self)
	return __getKey(__Ordaen_core.theme, "frame").tab.curves.flare * __getKey(__Ordaen_core.theme, "frame").tab.scale
end

function __f.c7(self)
	return __getKey(__Ordaen_core.theme, "frame").tab.lineStart * __getKey(__Ordaen_core.theme, "frame").tab.scale
end

function __f.c8(self)
	local __t9
	if __get(self.open) then
		__t9 = __get(self.height)
	else
		__t9 = __get(self.height) - 4.166666666666667
	end
	return __t9
end

function __f.c10(self)
	return __get(self.whole) - __get(self.reachTop)
end

function __f.c11(self)
	local __t12
	if __get(self.open) then
		__t12 = 10
	else
		__t12 = 0
	end
	return __t12
end

function __f.c13(self)
	local __t14
	if __get(self.open) then
		__t14 = WHITE
	else
		__t14 = SHADE
	end
	return __t14
end

function __f.c15(self)
	local __t16
	if __get(self.open) then
		__t16 = TITLE_OPEN
	else
		__t16 = TITLE_CLOSED
	end
	return __t16
end

function __f.c17(self)
	return __getKey(self.tab, "icon") ~= nil
end

function __f.c18(self)
	return __getKey(self.tab, "desc") ~= nil
end

function __f.c19(self)
	return __getKey(self.tab, "icon") or ""
end

function __f.c20(self)
	return __getKey(self.tab, "desc") or ""
end

function __f.c21(self)
	return __get(self.height) - __get(self.flare)
end

function __f.c22(self)
	local __t23
	if __get(self.open) then
		__t23 = __get(self.iconRight) + __get(self.lineStart)
	else
		__t23 = __get(self.whole)
	end
	return __t23
end

function __f.c24(self)
	local __t25
	if __get(self.open) then
		__t25 = __getKey(__Ordaen_core.theme, "frame").tabIconLineOpen
	else
		__t25 = __getKey(__Ordaen_core.theme, "frame").tabIconLine
	end
	return __t25
end

function __f.c26(self)
	return __get(self.iconRight) - __get(self.lineStart)
end

function __f.c27(self)
	return __get(self.flare) - __getKey(__Ordaen_core.theme, "frame").tabIconLine.reach.left * __getKey(__Ordaen_core.theme, "frame").tabIconLine.scale + 1
end

function __f.c28(self)
	return __get(self.iconRight) - __get(self.lineStart)
end

function __f.c29(self)
	return __get(self.flare) - __getKey(__Ordaen_core.theme, "frame").tabIconUnder.reach.top * __getKey(__Ordaen_core.theme, "frame").tabIconUnder.scale
end

function __f.c30(self)
	return self:paddingOf()
end

function __f.b33(self)
	return __get(self.given)
end

function __f.b34(self)
	return __get(self.frame)
end

function __f.b35(self)
	return __getKey(__Ordaen_core.theme, "window").wood
end

function __f.b36(self)
	return __get(self.tint)
end

function __f.b37(self)
	return __get(self.padding)
end

function __f.b38(self)
	return __get(self.level)
end

function __f.b40(self)
	return __get(self.hasIcon)
end

function __f.b43(self)
	return __get(self.iconRight)
end

function __f.b44(self)
	return __get(self.pictureHeight)
end

function __f.b45(self)
	return __get(self.icon)
end

function __f.b46(self)
	return __get(self.tint)
end

function __f.b47(self)
	return __getKey(__Ordaen_core.theme, "frame").tabIconClip
end

function __f.b49(self)
	return __get(self.open)
end

function __f.b52(self)
	return __get(self.iconRight)
end

function __f.b53(self)
	return __get(self.underWidth)
end

function __f.b54(self)
	return __get(self.underHeight)
end

function __f.b55(self)
	return __getKey(__Ordaen_core.theme, "frame").tabIconUnder
end

function __f.d50(self, parent)
	local __e51 = __el(parent, "box")
	__attr(__e51, "position", "absolute")
	__attr(__e51, "left", 0)
	__bind(__e51, "top", __f.b52, self)
	__bind(__e51, "width", __f.b53, self)
	__bind(__e51, "height", __f.b54, self)
	__bind(__e51, "border", __f.b55, self)
end

__f.w48 = { __f.b49, __f.d50 }

function __f.b57(self)
	return __get(self.lineLeft)
end

function __f.b58(self)
	return __get(self.lineWidth)
end

function __f.b59(self)
	return __get(self.whole)
end

function __f.b60(self)
	return __get(self.iconLine)
end

function __f.d41(self, parent)
	local __e42 = __el(parent, "box")
	__attr(__e42, "position", "absolute")
	__attr(__e42, "left", 0)
	__attr(__e42, "top", 0)
	__bind(__e42, "width", __f.b43, self)
	__bind(__e42, "height", __f.b44, self)
	__bind(__e42, "background", __f.b45, self)
	__bind(__e42, "tint", __f.b46, self)
	__bind(__e42, "border", __f.b47, self)
	__when(parent, __f.w48, self)
	local __e56 = __el(parent, "box")
	__attr(__e56, "position", "absolute")
	__bind(__e56, "left", __f.b57, self)
	__attr(__e56, "top", 0)
	__bind(__e56, "width", __f.b58, self)
	__bind(__e56, "height", __f.b59, self)
	__bind(__e56, "border", __f.b60, self)
end

__f.w39 = { __f.b40, __f.d41 }

function __f.b63(self)
	return __getKey(self.tab, "title")
end

function __f.b64(self)
	return __get(self.titleColor)
end

function __f.b66(self)
	return __get(self.hasDesc)
end

function __f.b69(self)
	return __get(self.desc)
end

function __f.d67(self, parent)
	local __e68 = __el(parent, "text")
	__bind(__e68, "value", __f.b69, self)
	__attr(__e68, "textSize", 9.166666666666668)
	__attr(__e68, "wrap", false)
	__attr(__e68, "textColor", DESC)
	__attr(__e68, "textShadow", SHADOW)
end

__f.w65 = { __f.b66, __f.d67 }

function __f.d31(self, parent)
	local __e32 = __el(parent, "box")
	__attr(__e32, "minWidth", 100)
	__bind(__e32, "height", __f.b33, self)
	__bind(__e32, "border", __f.b34, self)
	__bind(__e32, "background", __f.b35, self)
	__bind(__e32, "tint", __f.b36, self)
	__bind(__e32, "padding", __f.b37, self)
	__attr(__e32, "rows", BODY_ROWS)
	__bind(__e32, "zLevel", __f.b38, self)
	__on(__e32, "click", self, self.pick)
	__on(__e32, "dragStart", self, self.onGrab)
	__on(__e32, "drag", self, self.onMove)
	__on(__e32, "dragStop", self, self.onDrop)
	__when(__e32, __f.w39, self)
	local __e61 = __el(__e32, "box")
	__attr(__e61, "xAlign", "center")
	__attr(__e61, "yAlign", "center")
	__attr(__e61, "gap", 0.8333333333333334)
	local __e62 = __el(__e61, "text")
	__bind(__e62, "value", __f.b63, self)
	__attr(__e62, "textSize", 12.5)
	__attr(__e62, "wrap", false)
	__bind(__e62, "textColor", __f.b64, self)
	__attr(__e62, "textShadow", SHADOW)
	__when(__e61, __f.w65, self)
end

function __f.c70(self)
	return self:tabHeightOf()
end

function __f.c71(self)
	return __getKey(__Ordaen_core.theme, "frame").tabOpen.curves.flare * __getKey(__Ordaen_core.theme, "frame").tabOpen.scale
end

function __f.c72(self)
	return __get(self.tabHeight) + __get(self.lineTop)
end

function __f.c73(self)
	return self:tabColumns()
end

function __f.c74(self)
	return self:placeOf()
end

function __f.c75(self)
	local __t76
	if __get(self.full) then
		__t76 = nil
	else
		__t76 = __getKey(self.placing, "width")
	end
	return __t76
end

function __f.c77(self)
	local __t78
	if __get(self.full) then
		__t78 = nil
	else
		__t78 = __get(self.tabHeight) + __getKey(self.placing, "height")
	end
	return __t78
end

function __f.c79(self)
	return not __get(self.full)
end

function __f.c80(self)
	local __t81
	if __get(self.full) then
		__t81 = __getKey(__Ordaen_core.theme, "ctl").cornerContract
	else
		__t81 = __getKey(__Ordaen_core.theme, "ctl").cornerExpand
	end
	return __t81
end

function __f.c82(self)
	return self:gripOf()
end

function __f.b89(self)
	return __get(self.place)
end

function __f.b90(self)
	return __get(self.width)
end

function __f.b91(self)
	return __get(self.height)
end

function __f.b93(self)
	return __get(self.tabHeight)
end

function __f.b95(self)
	return __get(self.tabHeight)
end

function __f.b96(self)
	return __getKey(__Ordaen_core.theme, "frame").small
end

function __f.b97(self)
	return __getKey(__Ordaen_core.theme, "window").wood
end

function __f.b99(self)
	return __get(self.hovered)
end

function __f.b103(self)
	return __get(self.fullArt)
end

function __f.b105(self)
	return __getKey(__Ordaen_core.theme, "ctl").cornerClose
end

function __f.d100(self, parent)
	local __e101 = __el(parent, "box")
	__attr(__e101, "position", "absolute")
	__attr(__e101, "top", 4.583333333333334)
	__attr(__e101, "right", 4.166666666666667)
	__attr(__e101, "width", 52.5)
	__attr(__e101, "height", 26.666666666666668)
	__attr(__e101, "overflow", "hidden")
	local __e102 = __el(__e101, "box")
	__attr(__e102, "position", "absolute")
	__attr(__e102, "left", 0)
	__attr(__e102, "top", 0)
	__attr(__e102, "width", 53.333333333333336)
	__attr(__e102, "height", 26.666666666666668)
	__bind(__e102, "background", __f.b103, self)
	__on(__e102, "click", self, self.toggleFull)
	local __e104 = __el(__e101, "box")
	__attr(__e104, "position", "absolute")
	__attr(__e104, "left", 29.166666666666668)
	__attr(__e104, "top", 0)
	__attr(__e104, "width", 53.333333333333336)
	__attr(__e104, "height", 26.666666666666668)
	__bind(__e104, "background", __f.b105, self)
	__on(__e104, "click", self, self.onClose)
end

__f.w98 = { __f.b99, __f.d100 }

function __f.b107(self)
	return __get(self.sized)
end

function __f.b110(self)
	return __get(self.grip)
end

function __f.d108(self, parent)
	local __e109 = __el(parent, "box")
	__attr(__e109, "position", "absolute")
	__attr(__e109, "right", 1.6666666666666667)
	__attr(__e109, "bottom", 1.6666666666666667)
	__attr(__e109, "width", 13.333333333333334)
	__attr(__e109, "height", 13.333333333333334)
	__bind(__e109, "background", __f.b110, self)
	__on(__e109, "dragStart", self, self.onGrab)
	__on(__e109, "drag", self, self.onSize)
end

__f.w106 = { __f.b107, __f.d108 }

function __f.b112(self)
	return __get(self.columns)
end

function __f.b113(self)
	return __get(self.tabs)
end

function __f.d114(self, parent, index, tab)
	local __c115 = WindowTab.new(parent, tab, index, self.selected, self.openTab)
	__listen(__c115.grab, self, self.onGrab)
	__listen(__c115.move, self, self["onMove$Drag"])
	__draw(parent, __c115, nil)
end

function __f.d87(self, parent)
	local __e88 = __el(parent, "surface")
	__attr(__e88, "layer", "dialog")
	__bind(__e88, "place", __f.b89, self)
	__bind(__e88, "width", __f.b90, self)
	__bind(__e88, "height", __f.b91, self)
	__attr(__e88, "clamp", true)
	__attr(__e88, "raise", true)
	__on(__e88, "escape", self, self.onClose)
	local __e92 = __el(__e88, "box")
	__attr(__e92, "position", "absolute")
	__attr(__e92, "left", 0)
	__attr(__e92, "right", 0)
	__attr(__e92, "top", 0)
	__bind(__e92, "height", __f.b93, self)
	__on(__e92, "dragStart", self, self.onGrab)
	__on(__e92, "drag", self, self.onMove)
	local __e94 = __el(__e88, "box")
	__attr(__e94, "position", "absolute")
	__attr(__e94, "left", 0)
	__attr(__e94, "right", 0)
	__bind(__e94, "top", __f.b95, self)
	__attr(__e94, "bottom", 0)
	__bind(__e94, "border", __f.b96, self)
	__bind(__e94, "background", __f.b97, self)
	__attr(__e94, "padding", PADDING)
	__attr(__e94, "rows", BODY_ROWS)
	__attr(__e94, "zLevel", 5)
	__attr(__e94, "hoverWithin", true)
	__on(__e94, "enter", self, self.onEnter)
	__on(__e94, "leave", self, self.onLeave)
	__slot(__e94, self, "", nil, nil)
	__when(__e94, __f.w98, self)
	__when(__e94, __f.w106, self)
	local __e111 = __el(__e88, "box")
	__attr(__e111, "position", "absolute")
	__attr(__e111, "left", 0)
	__attr(__e111, "top", 0)
	__bind(__e111, "columns", __f.b112, self)
	__attr(__e111, "gap", 10)
	__attr(__e111, "yAlign", "end")
	__each(__e111, __f.b113, nil, __f.d114, 2, 1, true, self)
end

TAB = 30
TAB_DESC = 41.66666666666667
DROP = 4.166666666666667
TITLE_OPEN = { r = 1, g = 0.820, b = 0, a = 1 }
TITLE_CLOSED = { r = 0.702, g = 0.651, b = 0.565, a = 1 }
DESC = { r = 0.561, g = 0.518, b = 0.439, a = 1 }
SHADE = { r = 0.600, g = 0.600, b = 0.600, a = 1 }
WHITE = { r = 1, g = 1, b = 1, a = 1 }
SHADOW = { color = { r = 0, g = 0, b = 0, a = 0.800 }, x = 0.8333333333333334, y = -0.8333333333333334 }
LABEL_PAD = 8.333333333333334
MIN_TAB = 100
INSET = 2.5
PADDING = { top = 14.166666666666668, right = 12.5, bottom = 12.5, left = 12.5 }
BODY_ROWS = { { fr = 1 } }
MIN_W = 266.6666666666667
MIN_H = 166.66666666666669
BODY_LEVEL = 5
OPEN_LEVEL = 10

WindowTab = __class({})

function WindowTab.new(__owner, tab, index, selected, height)
	local self = setmetatable({}, WindowTab)
	R.adopt(__owner, self)
	self.tab = tab
	self.index = index
	self.selected = selected
	self.height = height
	self.grab = __event()
	self.move = __event()
	self.drop = __event()
	self.open = __computed(self, __f.c1, self)
	self.frame = __computed(self, __f.c2, self)
	self.reachTop = __computed(self, __f.c5, self)
	self.flare = __computed(self, __f.c6, self)
	self.lineStart = __computed(self, __f.c7, self)
	self.whole = __computed(self, __f.c8, self)
	self.given = __computed(self, __f.c10, self)
	self.level = __computed(self, __f.c11, self)
	self.tint = __computed(self, __f.c13, self)
	self.titleColor = __computed(self, __f.c15, self)
	self.hasIcon = __computed(self, __f.c17, self)
	self.hasDesc = __computed(self, __f.c18, self)
	self.icon = __computed(self, __f.c19, self)
	self.desc = __computed(self, __f.c20, self)
	self.iconRight = __computed(self, __f.c21, self)
	self.pictureHeight = __computed(self, __f.c22, self)
	self.iconLine = __computed(self, __f.c24, self)
	self.lineLeft = __computed(self, __f.c26, self)
	self.lineWidth = __computed(self, __f.c27, self)
	self.underWidth = __computed(self, __f.c28, self)
	self.underHeight = __computed(self, __f.c29, self)
	self.padding = __computed(self, __f.c30, self)
	return self
end

function WindowTab:paddingOf()
	if not __get(self.hasIcon) then
		return { left = 8.333333333333334, right = 8.333333333333334 }
	end
	local line = __getKey(__Ordaen_core.theme, "frame").tabIconLine
	local frame = __getKey(__Ordaen_core.theme, "frame").tab
	local lineEnd = line.width + line.reach.left * line.scale
	local frameEnd = frame.width + frame.reach.left * frame.scale
	local left = __get(self.height) - __get(self.flare) + lineEnd - frameEnd + 8.333333333333334
	return { left = left, right = 8.333333333333334 }
end

function WindowTab:pick()
	__set(self.selected, self.index)
end

function WindowTab:onGrab()
	__emit(self.grab)
end

function WindowTab:onMove(drag)
	__emit(self.move, drag.x, drag.y, drag.dx, drag.dy)
end

function WindowTab:onDrop()
	__emit(self.drop)
end

function WindowTab:render()
	return __template(__f.d31, self)
end

WindowTab["onMove$Drag"] = function(self, __1, __2, __3, __4)
	return self.onMove(self, { ["x"] = __1, ["y"] = __2, ["dx"] = __3, ["dy"] = __4 })
end

Window = __class({})

function Window.new(__owner, tabs, selected, placing, minWidth, minHeight, maxWidth, maxHeight)
	local self = setmetatable({}, Window)
	R.adopt(__owner, self)
	if minWidth == nil then minWidth = 266.6666666666667 end
	if minHeight == nil then minHeight = 166.66666666666669 end
	if maxWidth == nil then maxWidth = nil end
	if maxHeight == nil then maxHeight = nil end
	self.tabs = tabs
	self.selected = selected
	self.placing = placing
	self.minWidth = minWidth
	self.minHeight = minHeight
	self.maxWidth = maxWidth
	self.maxHeight = maxHeight
	self.close = __event()
	self.full = __cell(false)
	self.hovered = __cell(false)
	self.x0 = 0
	self.y0 = 0
	self.w0 = 0
	self.h0 = 0
	self.tabHeight = __computed(self, __f.c70, self)
	self.lineTop = __computed(self, __f.c71, self)
	self.openTab = __computed(self, __f.c72, self)
	self.columns = __computed(self, __f.c73, self)
	self.place = __computed(self, __f.c74, self)
	self.width = __computed(self, __f.c75, self)
	self.height = __computed(self, __f.c77, self)
	self.sized = __computed(self, __f.c79, self)
	self.fullArt = __computed(self, __f.c80, self)
	self.grip = __computed(self, __f.c82, self)
	return self
end

function Window:tabHeightOf()
	local __l84 = __get(self.tabs)
	for __i83 = 1, #__l84 do
		local tab = __l84[__i83]
		if tab.desc ~= nil then
			return 41.66666666666667
		end
	end
	return 30
end

function Window:tabColumns()
	local list = {}
	local __l86 = __get(self.tabs)
	for __i85 = 1, #__l86 do
		local tab = __l86[__i85]
		__insert(list, "auto")
	end
	return list
end

function Window:placeOf()
	if __get(self.full) then
		return "fill"
	end
	return { point = "TOPLEFT", to = "CENTER", x = __getKey(self.placing, "x") - __getKey(self.placing, "width") / 2, y = __getKey(self.placing, "y") - (__get(self.tabHeight) + __getKey(self.placing, "height")) / 2 }
end

function Window:gripOf()
	return { default = __getKey(__Ordaen_core.theme, "ctl").grip, hover = __getKey(__Ordaen_core.theme, "ctl").gripHover, pressed = __getKey(__Ordaen_core.theme, "ctl").gripDown }
end

function Window:onEnter()
	__set(self.hovered, true)
end

function Window:onLeave()
	__set(self.hovered, false)
end

function Window:toggleFull()
	__set(self.full, not __get(self.full))
end

function Window:onClose()
	__emit(self.close)
end

function Window:onGrab()
	self.x0 = __peek(self.placing).x
	self.y0 = __peek(self.placing).y
	self.w0 = __peek(self.placing).width
	self.h0 = __peek(self.placing).height
end

function Window:onMove(drag)
	if __get(self.full) then
		return
	end
	__setKey(self.placing, "x", self.x0 + drag.dx)
	__setKey(self.placing, "y", self.y0 + drag.dy)
end

function Window:onSize(drag)
	local width = __math_max(self.minWidth, self.w0 + drag.dx)
	local height = __math_max(self.minHeight, self.h0 + drag.dy)
	if self.maxWidth ~= nil then
		width = __math_min(self.maxWidth, width)
	end
	if self.maxHeight ~= nil then
		height = __math_min(self.maxHeight, height)
	end
	__setKey(self.placing, "width", width)
	__setKey(self.placing, "height", height)
	__setKey(self.placing, "x", self.x0 + (width - self.w0) / 2)
	__setKey(self.placing, "y", self.y0 + (height - self.h0) / 2)
end

function Window:render()
	return __template(__f.d87, self)
end

Window["onMove$Drag"] = function(self, __drag_x, __drag_y, __drag_dx, __drag_dy)
	if __get(self.full) then
		return
	end
	__setKey(self.placing, "x", self.x0 + __drag_dx)
	__setKey(self.placing, "y", self.y0 + __drag_dy)
end

Window["onSize$Drag"] = function(self, __drag_x, __drag_y, __drag_dx, __drag_dy)
	local width = __math_max(self.minWidth, self.w0 + __drag_dx)
	local height = __math_max(self.minHeight, self.h0 + __drag_dy)
	if self.maxWidth ~= nil then
		width = __math_min(self.maxWidth, width)
	end
	if self.maxHeight ~= nil then
		height = __math_min(self.maxHeight, height)
	end
	__setKey(self.placing, "width", width)
	__setKey(self.placing, "height", height)
	__setKey(self.placing, "x", self.x0 + (width - self.w0) / 2)
	__setKey(self.placing, "y", self.y0 + (height - self.h0) / 2)
end
__inherit(WindowTab, { __Ordaen_module_Component })
__inherit(Window, { __Ordaen_module_Component })

M.TAB = TAB
M.TAB_DESC = TAB_DESC
M.DROP = DROP
M.TITLE_OPEN = TITLE_OPEN
M.TITLE_CLOSED = TITLE_CLOSED
M.DESC = DESC
M.SHADE = SHADE
M.WHITE = WHITE
M.SHADOW = SHADOW
M.LABEL_PAD = LABEL_PAD
M.MIN_TAB = MIN_TAB
M.INSET = INSET
M.PADDING = PADDING
M.BODY_ROWS = BODY_ROWS
M.MIN_W = MIN_W
M.MIN_H = MIN_H
M.BODY_LEVEL = BODY_LEVEL
M.OPEN_LEVEL = OPEN_LEVEL
M.WindowTab = WindowTab
M.Window = Window
