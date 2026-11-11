-- Made by lunatype from OrdaenMinimap/main.luna: change the source, not this file.
local R = LunaType
local __get, __getKey, __len, __set, __setKey, __cell, __computed, __listen, __class, __inherit, __el, __attr, __bind, __on, __template, __draw, __when, __each = R.get, R.getKey, R.len, R.set, R.setKey, R.cell, R.computed, R.listen, R.class, R.inherit, R.el, R.attr, R.bind, R.on, R.template, R.draw, R.when, R.each
local __x = {
	Ordaen_settings_Settings = R.addon("Ordaen")["settings"].Settings,
	OrdaenMinimap_locales_TAB_MAP = R.addon("OrdaenMinimap")["locales"].TAB_MAP,
	OrdaenMinimap_settings_MapPage = R.addon("OrdaenMinimap")["settings"].MapPage,
	OrdaenMinimap_locales_TAB_DRAWER = R.addon("OrdaenMinimap")["locales"].TAB_DRAWER,
	OrdaenMinimap_settings_DrawerPage = R.addon("OrdaenMinimap")["settings"].DrawerPage,
	Ordaen_core = R.addon("Ordaen")["core"],
	game__Minimap_coords = R.game.Minimap.coords,
	game__Clock_invites = R.game.Clock.invites,
	game__Minimap_buttons = R.game.Minimap.buttons,
	game__Minimap_entries = R.game.Minimap.entries,
	math_max = R.math.max,
	math_ceil = R.math.ceil,
	OrdaenMinimap_ring_DRAWER_BUTTON = R.addon("OrdaenMinimap")["ring"].DRAWER_BUTTON,
	game__Minimap_square = R.game.Minimap.square,
	game__Minimap_wheelZoom = R.game.Minimap.wheelZoom,
	game__Situation_combat = R.game.Situation.combat,
	game__Situation_taxi = R.game.Situation.taxi,
	game__Situation_vehicle = R.game.Situation.vehicle,
	game__Location_pvp = R.game.Location.pvp,
	OrdaenMinimap_locales_ZONE_SANCTUARY = R.addon("OrdaenMinimap")["locales"].ZONE_SANCTUARY,
	OrdaenMinimap_locales_ZONE_FACTION = R.addon("OrdaenMinimap")["locales"].ZONE_FACTION,
	OrdaenMinimap_locales_ZONE_CONTESTED = R.addon("OrdaenMinimap")["locales"].ZONE_CONTESTED,
	OrdaenMinimap_locales_ZONE_COMBAT = R.addon("OrdaenMinimap")["locales"].ZONE_COMBAT,
	math_rad = R.math.rad,
	math_sin = R.math.sin,
	math_cos = R.math.cos,
	math_min = R.math.min,
	math_abs = R.math.abs,
	math_floor = R.math.floor,
	math_deg = R.math.deg,
	math_atan2 = R.math.atan2,
	game__Input_shiftDown = R.game.Input.shiftDown,
	game__Minimap_sendCoords = R.game.Minimap.sendCoords,
	game__Clock_toggleCalendar = R.game.Clock.toggleCalendar,
	game__Location_realZone = R.game.Location.realZone,
	game__Clock_text = R.game.Clock.text,
	OrdaenMinimap_locales_DRAWER_TITLE = R.addon("OrdaenMinimap")["locales"].DRAWER_TITLE,
	OrdaenMinimap_locales_COORDS_TIP = R.addon("OrdaenMinimap")["locales"].COORDS_TIP,
	OrdaenMinimap_locales_CLOCK_TIP = R.addon("OrdaenMinimap")["locales"].CLOCK_TIP,
	OrdaenMinimap_locales_ORDAEN_TIP_DEV = R.addon("OrdaenMinimap")["locales"].ORDAEN_TIP_DEV,
	OrdaenMinimap_locales_ORDAEN_TIP = R.addon("OrdaenMinimap")["locales"].ORDAEN_TIP,
	OrdaenMinimap_locales_DRAWER_TIP = R.addon("OrdaenMinimap")["locales"].DRAWER_TIP,
	OrdaenMinimap_ring_ORDAEN_BUTTON = R.addon("OrdaenMinimap")["ring"].ORDAEN_BUTTON,
	game__Frames_MinimapCluster = R.game.Frames.MinimapCluster,
	game__Frames_MinimapBackdrop = R.game.Frames.MinimapBackdrop,
	game__Frames_OrdaenDevButton = R.game.Frames.OrdaenDevButton,
	Ordaen_placed_Placed = R.addon("Ordaen")["placed"].Placed,
	OrdaenMinimap_locales_MINIMAP_TITLE = R.addon("OrdaenMinimap")["locales"].MINIMAP_TITLE,
	game__Minimap_frame = R.game.Minimap.frame,
	game__Location_zone = R.game.Location.zone,
	OrdaenMinimap_ring_RING = R.addon("OrdaenMinimap")["ring"].RING,
	OrdaenMinimap_ring_RingButton = R.addon("OrdaenMinimap")["ring"].RingButton,
	OrdaenMinimap_drawer_DrawerEntry = R.addon("OrdaenMinimap")["drawer"].DrawerEntry,
	OrdaenLibrary_tip_Tip = R.addon("OrdaenLibrary")["tip"].Tip,
	Ordaen_module_Module = R.addon("Ordaen")["module"].Module,
}
local M = {}
R.addon("OrdaenMinimap")["main"] = M
local MAP, STRIP, RING_OUT, CELL, CELL_GAP, DRAWER_PAD, GOLD, INK, PENDING, ENGRAVED, RULE, RULE_BELOW, RULE_ABOVE, HOME, Minimap

local __f = {}

function __f.d1(self, parent)
	local __c2 = __x.OrdaenMinimap_settings_MapPage.new(parent, self.settings)
	__draw(parent, __c2, nil)
end

function __f.d3(self, parent)
	local __c4 = __x.OrdaenMinimap_settings_DrawerPage.new(parent, self.settings)
	__draw(parent, __c4, nil)
end

function __f.c5(self)
	return __getKey(__x.Ordaen_core.theme, "frame").small.width + __getKey(__x.Ordaen_core.theme, "frame").small.inset
end

function __f.c6(self)
	return 218.33333333333334 * __getKey(self.settings.values, "scale")
end

function __f.c7(self)
	local __t8
	if __getKey(self.settings.values, "showZone") then
		__t8 = 25
	else
		__t8 = 0
	end
	return __t8
end

function __f.c9(self)
	return __getKey(self.settings.values, "showCoords") or __getKey(self.settings.values, "showClock")
end

function __f.c10(self)
	local __t11
	if __get(self.hasFoot) then
		__t11 = 25
	else
		__t11 = 0
	end
	return __t11
end

function __f.c12(self)
	return __get(self.size) + 2 * __get(self.out)
end

function __f.c13(self)
	return __get(self.size) + 2 * __get(self.out) + __get(self.headHeight) + __get(self.footHeight)
end

function __f.c14(self)
	return __get(self.frameWidth) + 55
end

function __f.c15(self)
	return __get(self.frameHeight) + 55
end

function __f.c16(self)
	return 27.5 - __getKey(__x.Ordaen_core.theme, "frame").small.reach.left * __getKey(__x.Ordaen_core.theme, "frame").small.scale
end

function __f.c17(self)
	return 27.5 - __getKey(__x.Ordaen_core.theme, "frame").small.reach.top * __getKey(__x.Ordaen_core.theme, "frame").small.scale
end

function __f.c18(self)
	return __get(self.out) + __get(self.headHeight)
end

function __f.c19(self)
	return __getKey(self.settings.values, "showCoords") and __get(__x.game__Minimap_coords) ~= ""
end

function __f.c20(self)
	return self:colorOf()
end

function __f.c21(self)
	local __t22
	if __get(__x.game__Clock_invites) > 0 then
		__t22 = PENDING
	else
		__t22 = INK
	end
	return __t22
end

function __f.c23(self)
	return not self:hiddenNow()
end

function __f.c24(self)
	return __len(__x.game__Minimap_buttons) + __len(__x.game__Minimap_entries)
end

function __f.c25(self)
	return __getKey(self.settings.values, "drawerOn") and __get(self.drawerOpen)
end

function __f.c26(self)
	return __getKey(self.settings.values, "drawerOn") and not __get(self.drawerOpen)
end

function __f.c27(self)
	return 10 + 2 * __getKey(__x.Ordaen_core.theme, "frame").small.width
end

function __f.c28(self)
	return __getKey(self.settings.values, "drawerColumns") * 28.333333333333336 + (__getKey(self.settings.values, "drawerColumns") - 1) * 3.3333333333333335 + __get(self.drawerEdge)
end

function __f.c29(self)
	return __x.math_max(1, __x.math_ceil(__get(self.held) / __getKey(self.settings.values, "drawerColumns")))
end

function __f.c30(self)
	return __get(self.drawerRows) * 28.333333333333336 + (__get(self.drawerRows) - 1) * 3.3333333333333335 + __get(self.drawerEdge)
end

function __f.c31(self)
	return self:ringLeft(__x.OrdaenMinimap_ring_DRAWER_BUTTON) + 28.333333333333336 - __get(self.drawerWidth)
end

function __f.c32(self)
	return self:ringTop(__x.OrdaenMinimap_ring_DRAWER_BUTTON) + 28.333333333333336 + 1.6666666666666667
end

function __f.c33(self)
	return __get(self.hint) ~= "none"
end

function __f.c34(self)
	return self:titleOf()
end

function __f.c35(self)
	return self:textOf()
end

function __f.c36(self)
	return self:leftOf()
end

function __f.c37(self)
	return self:topOf()
end

function __f.b46(self)
	return __get(__x.game__Frames_MinimapCluster)
end

function __f.b48(self)
	return __get(__x.game__Frames_MinimapBackdrop)
end

function __f.b50(self)
	return __get(__x.Ordaen_core.devButton)
end

function __f.b53(self)
	return __get(__x.game__Frames_OrdaenDevButton)
end

function __f.d51(self, parent)
	local __e52 = __el(parent, "frame")
	__bind(__e52, "of", __f.b53, self)
	__attr(__e52, "shown", false)
end

__f.w49 = { __f.b50, __f.d51 }

function __f.b55(self)
	return __get(self.shown)
end

function __f.b60(self)
	return __get(self.wholeWidth)
end

function __f.b61(self)
	return __get(self.wholeHeight)
end

function __f.b63(self)
	return __get(self.frameLeft)
end

function __f.b64(self)
	return __get(self.frameTop)
end

function __f.b65(self)
	return __get(self.frameWidth)
end

function __f.b66(self)
	return __get(self.frameHeight)
end

function __f.b67(self)
	return __getKey(__x.Ordaen_core.theme, "frame").small
end

function __f.b68(self)
	return __getKey(__x.Ordaen_core.theme, "window").wood
end

function __f.b70(self)
	return __get(__x.game__Minimap_frame)
end

function __f.b71(self)
	return __get(self.out)
end

function __f.b72(self)
	return __get(self.mapTop)
end

function __f.b73(self)
	return __get(self.size)
end

function __f.b74(self)
	return __get(self.size)
end

function __f.b76(self)
	return __getKey(self.settings.values, "showZone")
end

function __f.b79(self)
	return __get(self.out)
end

function __f.b80(self)
	return __get(self.out)
end

function __f.b81(self)
	return __get(self.size)
end

function __f.b82(self)
	return __getKey(__x.Ordaen_core.theme, "window").wood
end

function __f.b85(self)
	return __get(__x.game__Location_zone)
end

function __f.b86(self)
	return __get(self.zoneColor)
end

function __f.d77(self, parent)
	local __e78 = __el(parent, "box")
	__attr(__e78, "position", "absolute")
	__bind(__e78, "left", __f.b79, self)
	__bind(__e78, "top", __f.b80, self)
	__bind(__e78, "width", __f.b81, self)
	__attr(__e78, "height", 25)
	__bind(__e78, "background", __f.b82, self)
	__attr(__e78, "border", RULE_BELOW)
	__attr(__e78, "xAlign", "center")
	__attr(__e78, "yAlign", "center")
	local __e83 = __el(__e78, "box")
	__on(__e83, "enter", self, self.onZoneEnter)
	__on(__e83, "leave", self, self.onHintLeave)
	local __e84 = __el(__e83, "text")
	__bind(__e84, "value", __f.b85, self)
	__bind(__e84, "textColor", __f.b86, self)
	__attr(__e84, "textSize", 12.5)
	__attr(__e84, "textShadow", ENGRAVED)
	__attr(__e84, "wrap", false)
end

__f.w75 = { __f.b76, __f.d77 }

function __f.b88(self)
	return __get(self.hasFoot)
end

function __f.b91(self)
	return __get(self.out)
end

function __f.b92(self)
	return __get(self.out)
end

function __f.b93(self)
	return __get(self.size)
end

function __f.b94(self)
	return __getKey(__x.Ordaen_core.theme, "window").wood
end

function __f.b96(self)
	return __get(self.showsCoords)
end

function __f.b100(self)
	return __get(__x.game__Minimap_coords)
end

function __f.b101(self)
	return __getKey(__x.Ordaen_core.theme, "font").numbers
end

function __f.d97(self, parent)
	local __e98 = __el(parent, "box")
	__on(__e98, "click", self, self.onCoordsClick)
	__on(__e98, "enter", self, self.onCoordsEnter)
	__on(__e98, "leave", self, self.onHintLeave)
	local __e99 = __el(__e98, "text")
	__bind(__e99, "value", __f.b100, self)
	__attr(__e99, "textColor", INK)
	__attr(__e99, "textSize", 12.5)
	__attr(__e99, "textShadow", ENGRAVED)
	__bind(__e99, "textFamily", __f.b101, self)
	__attr(__e99, "wrap", false)
end

function __f.d102(self, parent)
	local __e103 = __el(parent, "box")
	__attr(__e103, "width", 1)
end

__f.w95 = { __f.b96, __f.d97, false, __f.d102 }

function __f.b105(self)
	return __getKey(self.settings.values, "showClock")
end

function __f.b109(self)
	return __get(__x.game__Clock_text)
end

function __f.b110(self)
	return __get(self.clockColor)
end

function __f.b111(self)
	return __getKey(__x.Ordaen_core.theme, "font").numbers
end

function __f.d106(self, parent)
	local __e107 = __el(parent, "box")
	__on(__e107, "click", self, self.onClockClick)
	__on(__e107, "enter", self, self.onClockEnter)
	__on(__e107, "leave", self, self.onHintLeave)
	local __e108 = __el(__e107, "text")
	__bind(__e108, "value", __f.b109, self)
	__bind(__e108, "textColor", __f.b110, self)
	__attr(__e108, "textSize", 12.5)
	__attr(__e108, "textShadow", ENGRAVED)
	__bind(__e108, "textFamily", __f.b111, self)
	__attr(__e108, "wrap", false)
end

__f.w104 = { __f.b105, __f.d106 }

function __f.d89(self, parent)
	local __e90 = __el(parent, "box")
	__attr(__e90, "position", "absolute")
	__bind(__e90, "left", __f.b91, self)
	__bind(__e90, "bottom", __f.b92, self)
	__bind(__e90, "width", __f.b93, self)
	__attr(__e90, "height", 25)
	__bind(__e90, "background", __f.b94, self)
	__attr(__e90, "border", RULE_ABOVE)
	__attr(__e90, "columns", { { fr = 1 }, "auto" })
	__attr(__e90, "padding", { left = 8.333333333333334, right = 8.333333333333334 })
	__attr(__e90, "yAlign", "center")
	__when(__e90, __f.w95, self)
	__when(__e90, __f.w104, self)
end

__f.w87 = { __f.b88, __f.d89 }

function __f.b112(self)
	return __x.OrdaenMinimap_ring_RING
end

function __f.d113(self, parent, spec)
	local __c114 = __x.OrdaenMinimap_ring_RingButton.new(parent, spec, self)
	__draw(parent, __c114, nil)
end

function __f.b116(self)
	return __get(self.drawerShown)
end

function __f.b119(self)
	return __get(self.drawerLeft)
end

function __f.b120(self)
	return __get(self.drawerTop)
end

function __f.b121(self)
	return __get(self.drawerWidth)
end

function __f.b122(self)
	return __get(self.drawerHeight)
end

function __f.b123(self)
	return __getKey(self.settings.values, "drawerColumns")
end

function __f.b124(self)
	return __getKey(__x.Ordaen_core.theme, "frame").small
end

function __f.b125(self)
	return __getKey(__x.Ordaen_core.theme, "window").wood
end

function __f.b126(self)
	return __get(__x.game__Minimap_buttons)
end

function __f.b129(self, button)
	return __get(button)
end

function __f.d127(self, parent, button)
	local __e128 = __el(parent, "embed")
	__bind(__e128, "frame", __f.b129, self, button)
	__attr(__e128, "width", 28.333333333333336)
	__attr(__e128, "height", 28.333333333333336)
	__attr(__e128, "look", "icon")
end

function __f.b130(self)
	return __get(__x.game__Minimap_entries)
end

function __f.d131(self, parent, entry)
	local __c132 = __x.OrdaenMinimap_drawer_DrawerEntry.new(parent, entry)
	__listen(__c132.hover, self, self.onEntryHover)
	__listen(__c132.leave, self, self.onHintLeave)
	__draw(parent, __c132, nil)
end

function __f.d117(self, parent)
	local __e118 = __el(parent, "box")
	__attr(__e118, "position", "absolute")
	__bind(__e118, "left", __f.b119, self)
	__bind(__e118, "top", __f.b120, self)
	__bind(__e118, "width", __f.b121, self)
	__bind(__e118, "height", __f.b122, self)
	__bind(__e118, "columns", __f.b123, self)
	__attr(__e118, "gap", 3.3333333333333335)
	__attr(__e118, "padding", 5)
	__bind(__e118, "border", __f.b124, self)
	__bind(__e118, "background", __f.b125, self)
	__attr(__e118, "artOrigin", true)
	__attr(__e118, "zLevel", 20)
	__each(__e118, __f.b126, nil, __f.d127, 1, 0, true, self)
	__each(__e118, __f.b130, nil, __f.d131, 1, 0, true, self)
end

function __f.b133(self)
	return __get(self.drawerParked)
end

function __f.b136(self)
	return __get(__x.game__Minimap_buttons)
end

function __f.b139(self, button)
	return __get(button)
end

function __f.d137(self, parent, button)
	local __e138 = __el(parent, "embed")
	__bind(__e138, "frame", __f.b139, self, button)
	__attr(__e138, "width", 28.333333333333336)
	__attr(__e138, "height", 28.333333333333336)
	__attr(__e138, "look", "icon")
end

function __f.d134(self, parent)
	local __e135 = __el(parent, "box")
	__attr(__e135, "position", "absolute")
	__attr(__e135, "left", 0)
	__attr(__e135, "top", 0)
	__attr(__e135, "width", 0)
	__attr(__e135, "height", 0)
	__attr(__e135, "opacity", 0)
	__each(__e135, __f.b136, nil, __f.d137, 1, 0, true, self)
end

__f.w115 = { __f.b116, __f.d117, __f.b133, __f.d134 }

function __f.b141(self)
	return __get(self.hintShown)
end

function __f.d142(self, parent)
	local __c143 = __x.OrdaenLibrary_tip_Tip.new(parent, self.hintTitle, self.hintText, self.hintLeft, self.hintTop)
	__draw(parent, __c143, nil)
end

__f.w140 = { __f.b141, __f.d142 }

function __f.d58(self, parent)
	local __e59 = __el(parent, "box")
	__bind(__e59, "width", __f.b60, self)
	__bind(__e59, "height", __f.b61, self)
	__attr(__e59, "hoverWithin", true)
	__on(__e59, "enter", self, self.onEnter)
	__on(__e59, "leave", self, self.onLeave)
	local __e62 = __el(__e59, "box")
	__attr(__e62, "position", "absolute")
	__bind(__e62, "left", __f.b63, self)
	__bind(__e62, "top", __f.b64, self)
	__bind(__e62, "width", __f.b65, self)
	__bind(__e62, "height", __f.b66, self)
	__bind(__e62, "border", __f.b67, self)
	__bind(__e62, "background", __f.b68, self)
	__attr(__e62, "artOrigin", true)
	local __e69 = __el(__e62, "embed")
	__bind(__e69, "frame", __f.b70, self)
	__attr(__e69, "position", "absolute")
	__bind(__e69, "left", __f.b71, self)
	__bind(__e69, "top", __f.b72, self)
	__bind(__e69, "width", __f.b73, self)
	__bind(__e69, "height", __f.b74, self)
	__when(__e62, __f.w75, self)
	__when(__e62, __f.w87, self)
	__each(__e59, __f.b112, nil, __f.d113, 1, 0, false, self)
	__when(__e59, __f.w115, self)
	__when(__e59, __f.w140, self)
end

function __f.d56(self, parent)
	local __c57 = __x.Ordaen_placed_Placed.new(parent, "OrdaenMinimap.map", __x.OrdaenMinimap_locales_MINIMAP_TITLE, __cell(HOME))
	__draw(parent, __c57, { self = self, [""] = __f.d58 })
end

__f.w54 = { __f.b55, __f.d56 }

function __f.d44(self, parent)
	local __e45 = __el(parent, "frame")
	__bind(__e45, "of", __f.b46, self)
	__attr(__e45, "shown", false)
	local __e47 = __el(parent, "frame")
	__bind(__e47, "of", __f.b48, self)
	__attr(__e47, "shown", false)
	__when(parent, __f.w49, self)
	__when(parent, __f.w54, self)
end

MAP = 218.33333333333334
STRIP = 25
RING_OUT = 13.333333333333334
CELL = 28.333333333333336
CELL_GAP = 3.3333333333333335
DRAWER_PAD = 5
GOLD = { r = 1, g = 0.820, b = 0, a = 1 }
INK = { r = 0.953, g = 0.882, b = 0.722, a = 1 }
PENDING = { r = 1, g = 0.604, b = 0.180, a = 1 }
ENGRAVED = { color = { r = 0, g = 0, b = 0, a = 0.902 }, x = -1, y = 1 }
RULE = { r = 0.071, g = 0.047, b = 0.024, a = 1 }
RULE_BELOW = { width = 1.6666666666666667, color = RULE, sides = { "bottom" } }
RULE_ABOVE = { width = 1.6666666666666667, color = RULE, sides = { "top" } }
HOME = { point = "TOPRIGHT" }

Minimap = __class({})

function Minimap.new(__owner)
	local self = setmetatable({ title = "Ordaen Minimap" }, Minimap)
	R.adopt(__owner, self)
	self.settings = __x.Ordaen_settings_Settings.new(self, { scale = 1, showZone = true, showClock = true, showCoords = true, buttonsHover = true, hide = "never", drawerOn = true, drawerColumns = 4 }, "account")
	self.pages = { { title = __x.OrdaenMinimap_locales_TAB_MAP, content = __template(__f.d1, self) }, { title = __x.OrdaenMinimap_locales_TAB_DRAWER, content = __template(__f.d3, self) } }
	self.angles = __cell({})
	self.hovered = __cell(false)
	self.drawerOpen = __cell(false)
	self.dragging = __cell(nil)
	self.dragAngle = __cell(0)
	self.dragLeft = 0
	self.dragTop = 0
	self.hint = __cell("none")
	self.entryName = __cell("")
	self.out = __computed(self, __f.c5, self)
	self.size = __computed(self, __f.c6, self)
	self.headHeight = __computed(self, __f.c7, self)
	self.hasFoot = __computed(self, __f.c9, self)
	self.footHeight = __computed(self, __f.c10, self)
	self.frameWidth = __computed(self, __f.c12, self)
	self.frameHeight = __computed(self, __f.c13, self)
	self.wholeWidth = __computed(self, __f.c14, self)
	self.wholeHeight = __computed(self, __f.c15, self)
	self.frameLeft = __computed(self, __f.c16, self)
	self.frameTop = __computed(self, __f.c17, self)
	self.mapTop = __computed(self, __f.c18, self)
	self.showsCoords = __computed(self, __f.c19, self)
	self.zoneColor = __computed(self, __f.c20, self)
	self.clockColor = __computed(self, __f.c21, self)
	self.shown = __computed(self, __f.c23, self)
	self.held = __computed(self, __f.c24, self)
	self.drawerShown = __computed(self, __f.c25, self)
	self.drawerParked = __computed(self, __f.c26, self)
	self.drawerEdge = __computed(self, __f.c27, self)
	self.drawerWidth = __computed(self, __f.c28, self)
	self.drawerRows = __computed(self, __f.c29, self)
	self.drawerHeight = __computed(self, __f.c30, self)
	self.drawerLeft = __computed(self, __f.c31, self)
	self.drawerTop = __computed(self, __f.c32, self)
	self.hintShown = __computed(self, __f.c33, self)
	self.hintTitle = __computed(self, __f.c34, self)
	self.hintText = __computed(self, __f.c35, self)
	self.hintLeft = __computed(self, __f.c36, self)
	self.hintTop = __computed(self, __f.c37, self)
	__x.game__Minimap_square(true)
	__x.game__Minimap_wheelZoom()
	return self
end

Minimap["$destructor"] = function(self)
	__x.game__Minimap_square(false)
end

function Minimap:hiddenNow()
	local __s38 = __getKey(self.settings.values, "hide")
	if __s38 == "combat" then
		return __get(__x.game__Situation_combat)
	elseif __s38 == "transport" then
		return __get(__x.game__Situation_taxi) or __get(__x.game__Situation_vehicle)
	elseif __s38 == "never" then
		return false
	end
	return false
end

function Minimap:colorOf()
	local pvp = __get(__x.game__Location_pvp)
	if pvp == nil then
		return GOLD
	end
	if pvp == "sanctuary" then
		return { r = 0.412, g = 0.800, b = 0.941, a = 1 }
	elseif pvp == "friendly" then
		return { r = 0.102, g = 1, b = 0.102, a = 1 }
	elseif pvp == "hostile" or pvp == "combat" then
		return { r = 1, g = 0.102, b = 0.102, a = 1 }
	elseif pvp == "contested" then
		return { r = 1, g = 0.702, b = 0, a = 1 }
	end
	return GOLD
end

function Minimap:zoneLabel()
	local pvp = __get(__x.game__Location_pvp)
	if pvp == nil then
		return ""
	end
	if pvp == "sanctuary" then
		return __x.OrdaenMinimap_locales_ZONE_SANCTUARY
	elseif pvp == "friendly" or pvp == "hostile" then
		return __x.OrdaenMinimap_locales_ZONE_FACTION
	elseif pvp == "contested" then
		return __x.OrdaenMinimap_locales_ZONE_CONTESTED
	elseif pvp == "combat" then
		return __x.OrdaenMinimap_locales_ZONE_COMBAT
	end
	return ""
end

function Minimap:angle(spec)
	if __get(self.dragging) == spec.id then
		return __get(self.dragAngle)
	end
	return __getKey(self.angles, spec.id) or spec.angle
end

function Minimap:offset(spec)
	local t = __x.math_rad(self:angle(spec))
	local x = __x.math_sin(t)
	local y = -__x.math_cos(t)
	local halfWidth = __get(self.frameWidth) / 2 + 13.333333333333334
	local halfHeight = __get(self.frameHeight) / 2 + 13.333333333333334
	local k = __x.math_min(halfWidth / __x.math_max(__x.math_abs(x), 1e-9), halfHeight / __x.math_max(__x.math_abs(y), 1e-9))
	return __x.math_floor(x * k * 100 + 0.5) / 100, __x.math_floor(y * k * 100 + 0.5) / 100
end

function Minimap:ringLeft(spec)
	local x, y = self:offset(spec)
	return 27.5 + __get(self.frameWidth) / 2 + x - 14.166666666666668
end

function Minimap:ringTop(spec)
	local x, y = self:offset(spec)
	return 27.5 + __get(self.frameHeight) / 2 + y - 14.166666666666668
end

function Minimap:ringOpacity()
	if not __getKey(self.settings.values, "buttonsHover") or __get(self.hovered) or __get(self.drawerOpen) or __get(self.dragging) ~= nil then
		return 1
	end
	return 0
end

function Minimap:isDrawerOpen()
	return __get(self.drawerOpen)
end

function Minimap:isDrawerOn()
	return __getKey(self.settings.values, "drawerOn")
end

function Minimap:holds()
	return __get(self.held)
end

function Minimap:startDrag(spec)
	self.dragLeft = self:ringLeft(spec)
	self.dragTop = self:ringTop(spec)
	__set(self.dragAngle, self:angle(spec))
	__set(self.dragging, spec.id)
	__set(self.hint, "none")
end

function Minimap:dragTo(x, y)
	local cx = self.dragLeft + x - 27.5 - __get(self.frameWidth) / 2
	local cy = self.dragTop + y - 27.5 - __get(self.frameHeight) / 2
	__set(self.dragAngle, __x.math_floor((__x.math_deg(__x.math_atan2(cx, -cy)) + 360) % 360 + 0.5))
end

function Minimap:stopDrag(spec)
	__setKey(self.angles, spec.id, __get(self.dragAngle))
	__set(self.dragging, nil)
end

function Minimap:toggleDrawer()
	__set(self.drawerOpen, not __get(self.drawerOpen))
end

function Minimap:showHint(hint)
	__set(self.hint, hint)
end

function Minimap:onEnter()
	__set(self.hovered, true)
end

function Minimap:onLeave()
	__set(self.hovered, false)
end

function Minimap:onZoneEnter()
	__set(self.hint, "zone")
end

function Minimap:onCoordsEnter()
	__set(self.hint, "coords")
end

function Minimap:onClockEnter()
	__set(self.hint, "clock")
end

function Minimap:onHintLeave()
	__set(self.hint, "none")
end

function Minimap:onEntryHover(name)
	__set(self.entryName, name)
	__set(self.hint, "entry")
end

function Minimap:onCoordsClick(click)
	if click.button == "LeftButton" and __x.game__Input_shiftDown() then
		__x.game__Minimap_sendCoords()
	end
end

function Minimap:onClockClick(click)
	if click.button == "RightButton" then
		__x.Ordaen_core.toggleSettings("minimap")
	else
		__x.game__Clock_toggleCalendar()
	end
end

function Minimap:titleOf()
	local __s39 = __get(self.hint)
	if __s39 == "zone" then
		return __get(__x.game__Location_realZone)
	elseif __s39 == "coords" then
		return __get(__x.game__Minimap_coords)
	elseif __s39 == "clock" then
		return __get(__x.game__Clock_text)
	elseif __s39 == "ordaen" then
		return __x.Ordaen_core.title
	elseif __s39 == "drawer" then
		return __x.OrdaenMinimap_locales_DRAWER_TITLE
	elseif __s39 == "entry" then
		return __get(self.entryName)
	elseif __s39 == "none" then
		return ""
	end
	return ""
end

function Minimap:textOf()
	local __s40 = __get(self.hint)
	if __s40 == "zone" then
		return self:zoneLabel()
	elseif __s40 == "coords" then
		return __x.OrdaenMinimap_locales_COORDS_TIP
	elseif __s40 == "clock" then
		return __x.OrdaenMinimap_locales_CLOCK_TIP
	elseif __s40 == "ordaen" then
		local __t41
		if __get(__x.Ordaen_core.dev) then
			__t41 = __x.OrdaenMinimap_locales_ORDAEN_TIP_DEV
		else
			__t41 = __x.OrdaenMinimap_locales_ORDAEN_TIP
		end
		return __t41
	elseif __s40 == "drawer" then
		return __x.OrdaenMinimap_locales_DRAWER_TIP
	elseif __s40 == "entry" or __s40 == "none" then
		return ""
	end
	return ""
end

function Minimap:leftOf()
	local __s42 = __get(self.hint)
	if __s42 == "ordaen" then
		return self:ringLeft(__x.OrdaenMinimap_ring_ORDAEN_BUTTON) + 28.333333333333336
	elseif __s42 == "drawer" or __s42 == "entry" then
		return self:ringLeft(__x.OrdaenMinimap_ring_DRAWER_BUTTON) + 28.333333333333336
	else
		return 27.5 + __get(self.frameWidth) + 3.3333333333333335
	end
end

function Minimap:topOf()
	local __s43 = __get(self.hint)
	if __s43 == "zone" then
		return 27.5
	elseif __s43 == "ordaen" then
		return self:ringTop(__x.OrdaenMinimap_ring_ORDAEN_BUTTON)
	elseif __s43 == "drawer" then
		return self:ringTop(__x.OrdaenMinimap_ring_DRAWER_BUTTON)
	elseif __s43 == "entry" then
		return self:ringTop(__x.OrdaenMinimap_ring_DRAWER_BUTTON) + 28.333333333333336
	else
		return 27.5 + __get(self.frameHeight) - 25
	end
end

function Minimap:render()
	return __template(__f.d44, self)
end

Minimap["onCoordsClick$Click"] = function(self, __click_button, __click_x, __click_y)
	if __click_button == "LeftButton" and __x.game__Input_shiftDown() then
		__x.game__Minimap_sendCoords()
	end
end

Minimap["onClockClick$Click"] = function(self, __click_button, __click_x, __click_y)
	if __click_button == "RightButton" then
		__x.Ordaen_core.toggleSettings("minimap")
	else
		__x.game__Clock_toggleCalendar()
	end
end
__inherit(Minimap, { __x.Ordaen_module_Module })

M.MAP = MAP
M.STRIP = STRIP
M.RING_OUT = RING_OUT
M.CELL = CELL
M.CELL_GAP = CELL_GAP
M.DRAWER_PAD = DRAWER_PAD
M.GOLD = GOLD
M.INK = INK
M.PENDING = PENDING
M.ENGRAVED = ENGRAVED
M.RULE = RULE
M.RULE_BELOW = RULE_BELOW
M.RULE_ABOVE = RULE_ABOVE
M.HOME = HOME
M.Minimap = Minimap
