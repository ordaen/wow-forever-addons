-- Made by lunatype from OrdaenPanel/main.luna: change the source, not this file.
local R = LunaType
local __get, __getKey, __set, __cell, __computed, __class, __inherit, __el, __attr, __bind, __on, __template, __draw, __when = R.get, R.getKey, R.set, R.cell, R.computed, R.class, R.inherit, R.el, R.attr, R.bind, R.on, R.template, R.draw, R.when
local __insert = table.insert
local __x = {
	game__Clock_toggleCalendar = R.game.Clock.toggleCalendar,
	Ordaen_core = R.addon("Ordaen")["core"],
	OrdaenPanel_items_MicroLine = R.addon("OrdaenPanel")["items"].MicroLine,
	OrdaenPanel_items_SocialLine = R.addon("OrdaenPanel")["items"].SocialLine,
	OrdaenPanel_xpBar_XpBar = R.addon("OrdaenPanel")["xpBar"].XpBar,
	game__Location_zone = R.game.Location.zone,
	game__Clock_text = R.game.Clock.text,
	OrdaenPanel_items_MoneyLine = R.addon("OrdaenPanel")["items"].MoneyLine,
	OrdaenPanel_items_BagLine = R.addon("OrdaenPanel")["items"].BagLine,
	Ordaen_settings_Settings = R.addon("Ordaen")["settings"].Settings,
	OrdaenPanel_choices_DEFAULTS = R.addon("OrdaenPanel")["choices"].DEFAULTS,
	OrdaenPanel_locales_TAB_GENERAL = R.addon("OrdaenPanel")["locales"].TAB_GENERAL,
	OrdaenPanel_settings_GeneralPage = R.addon("OrdaenPanel")["settings"].GeneralPage,
	OrdaenPanel_locales_TAB_MICROMENU = R.addon("OrdaenPanel")["locales"].TAB_MICROMENU,
	OrdaenPanel_settings_MicroPage = R.addon("OrdaenPanel")["settings"].MicroPage,
	OrdaenPanel_locales_TAB_STATUS = R.addon("OrdaenPanel")["locales"].TAB_STATUS,
	OrdaenPanel_settings_StatusPage = R.addon("OrdaenPanel")["settings"].StatusPage,
	OrdaenPanel_locales_TAB_BOTTOM = R.addon("OrdaenPanel")["locales"].TAB_BOTTOM,
	OrdaenPanel_settings_BottomPage = R.addon("OrdaenPanel")["settings"].BottomPage,
	game__Clock_invites = R.game.Clock.invites,
	game__Situation_combat = R.game.Situation.combat,
	game__Situation_vehicle = R.game.Situation.vehicle,
	game__Situation_petBattle = R.game.Situation.petBattle,
	game__Situation_resting = R.game.Situation.resting,
	math_max = R.math.max,
	game__Frames_MicroMenuContainer = R.game.Frames.MicroMenuContainer,
	game__Frames_StoreMicroButton = R.game.Frames.StoreMicroButton,
	game__Frames_HelpMicroButton = R.game.Frames.HelpMicroButton,
	game__Frames_MainStatusTrackingBarContainer = R.game.Frames.MainStatusTrackingBarContainer,
	game__Frames_SecondaryStatusTrackingBarContainer = R.game.Frames.SecondaryStatusTrackingBarContainer,
	game__Frames_BagsBar = R.game.Frames.BagsBar,
	game__Frames_BackpackFreeSlots = R.game.Frames.BackpackFreeSlots,
	game__Frames_CharacterMicroButton = R.game.Frames.CharacterMicroButton,
	game__Player_level = R.game.Player.level,
	Ordaen_placed_Placed = R.addon("Ordaen")["placed"].Placed,
	OrdaenPanel_locales_PANEL_MICROMENU = R.addon("OrdaenPanel")["locales"].PANEL_MICROMENU,
	OrdaenPanel_locales_PANEL_SOCIAL = R.addon("OrdaenPanel")["locales"].PANEL_SOCIAL,
	OrdaenPanel_locales_PANEL_EXPERIENCE = R.addon("OrdaenPanel")["locales"].PANEL_EXPERIENCE,
	OrdaenPanel_locales_PANEL_CURRENCIES = R.addon("OrdaenPanel")["locales"].PANEL_CURRENCIES,
	OrdaenPanel_locales_PANEL_BAGS = R.addon("OrdaenPanel")["locales"].PANEL_BAGS,
	Ordaen_module_Component = R.addon("Ordaen")["module"].Component,
	Ordaen_module_Module = R.addon("Ordaen")["module"].Module,
}
local M = {}
R.addon("OrdaenPanel")["main"] = M
local INK, PENDING, TEXT, TEXT_SHADOW, NO_SHADOW, EDGE_ROOM, MOUSEOVER_LEAST, MICRO_HOME, SOCIAL_HOME, EXPERIENCE_HOME, MONEY_HOME, BAGS_HOME, THIRDS, FITTED, PORTRAIT_WIDTH, PORTRAIT_HEIGHT, PORTRAIT_ROOM, CORNER, GOLD, DOWN, ZoneBox, Panel

local __f = {}

function __f.c1(self)
	return self:alignOf()
end

function __f.c2(self)
	return self.panel:microIn(self.zone)
end

function __f.c3(self)
	return self.panel:socialIn(self.zone)
end

function __f.c4(self)
	return self.panel:experienceIn(self.zone) and not __get(self.panel.vertical)
end

function __f.c5(self)
	return self.panel:zoneIn(self.zone)
end

function __f.c6(self)
	return self.panel:clockIn(self.zone)
end

function __f.c7(self)
	return self.panel:moneyIn(self.zone)
end

function __f.c8(self)
	return self.panel:bagsIn(self.zone)
end

function __f.c9(self)
	local __t10
	if __get(self.panel.vertical) then
		__t10 = DOWN
	else
		__t10 = self:tracks()
	end
	return __t10
end

function __f.c11(self)
	local __t12
	if __get(self.panel.vertical) then
		__t12 = self:tracks()
	else
		__t12 = nil
	end
	return __t12
end

function __f.c13(self)
	local __t14
	if __get(self.panel.vertical) then
		__t14 = "center"
	else
		__t14 = __get(self.align)
	end
	return __t14
end

function __f.c15(self)
	local __t16
	if __get(self.panel.vertical) then
		__t16 = __get(self.align)
	else
		__t16 = "center"
	end
	return __t16
end

function __f.b24(self)
	return __get(self.columns)
end

function __f.b25(self)
	return __get(self.rows)
end

function __f.b26(self)
	return __getKey(__x.Ordaen_core.theme, "spacing").md
end

function __f.b27(self)
	return __get(self.along)
end

function __f.b28(self)
	return __get(self.across)
end

function __f.b30(self)
	return __get(self.micro)
end

function __f.b33(self)
	return __get(self.panel.portraitShown)
end

function __f.b36(self)
	return __getKey(__x.Ordaen_core.theme, "spacing").md
end

function __f.d34(self, parent)
	local __e35 = __el(parent, "box")
	__attr(__e35, "columns", PORTRAIT_ROOM)
	__bind(__e35, "gap", __f.b36, self)
	__attr(__e35, "yAlign", "center")
	local __e37 = __el(__e35, "box")
	__attr(__e37, "width", 128)
	__attr(__e37, "height", 1)
	local __c38 = __x.OrdaenPanel_items_MicroLine.new(__e35, self.panel.goldIcons, nil, __cell(false))
	__draw(__e35, __c38, nil)
end

function __f.d39(self, parent)
	local __c40 = __x.OrdaenPanel_items_MicroLine.new(parent, self.panel.goldIcons, self.panel.vertical, nil)
	__draw(parent, __c40, nil)
end

__f.w32 = { __f.b33, __f.d34, false, __f.d39 }

function __f.d31(self, parent)
	__when(parent, __f.w32, self)
end

__f.w29 = { __f.b30, __f.d31 }

function __f.b42(self)
	return __get(self.social)
end

function __f.d43(self, parent)
	local __c44 = __x.OrdaenPanel_items_SocialLine.new(parent, self.panel.goldIcons, self.panel.vertical)
	__draw(parent, __c44, nil)
end

__f.w41 = { __f.b42, __f.d43 }

function __f.b46(self)
	return __get(self.experience)
end

function __f.d47(self, parent)
	local __c48 = __x.OrdaenPanel_xpBar_XpBar.new(parent, nil)
	__draw(parent, __c48, nil)
end

__f.w45 = { __f.b46, __f.d47 }

function __f.b50(self)
	return __get(self.zoneName)
end

function __f.b53(self)
	return __get(__x.game__Location_zone)
end

function __f.b54(self)
	return __get(self.panel.outline)
end

function __f.b55(self)
	return __get(self.panel.shadow)
end

function __f.d51(self, parent)
	local __e52 = __el(parent, "text")
	__bind(__e52, "value", __f.b53, self)
	__attr(__e52, "textColor", INK)
	__attr(__e52, "textSize", 12)
	__bind(__e52, "textOutline", __f.b54, self)
	__bind(__e52, "textShadow", __f.b55, self)
	__attr(__e52, "wrap", false)
end

__f.w49 = { __f.b50, __f.d51 }

function __f.b57(self)
	return __get(self.clock)
end

function __f.b61(self)
	return __get(__x.game__Clock_text)
end

function __f.b62(self)
	return __get(self.panel.clockColor)
end

function __f.b63(self)
	return __get(self.panel.outline)
end

function __f.b64(self)
	return __get(self.panel.shadow)
end

function __f.d58(self, parent)
	local __e59 = __el(parent, "box")
	__on(__e59, "click", self, self.onClock)
	local __e60 = __el(__e59, "text")
	__bind(__e60, "value", __f.b61, self)
	__bind(__e60, "textColor", __f.b62, self)
	__attr(__e60, "textSize", 12)
	__bind(__e60, "textOutline", __f.b63, self)
	__bind(__e60, "textShadow", __f.b64, self)
	__attr(__e60, "wrap", false)
end

__f.w56 = { __f.b57, __f.d58 }

function __f.b66(self)
	return __get(self.money)
end

function __f.d67(self, parent)
	local __c68 = __x.OrdaenPanel_items_MoneyLine.new(parent, self.panel.outline, self.panel.shadow, self.panel.vertical)
	__draw(parent, __c68, nil)
end

__f.w65 = { __f.b66, __f.d67 }

function __f.b70(self)
	return __get(self.bags)
end

function __f.d71(self, parent)
	local __c72 = __x.OrdaenPanel_items_BagLine.new(parent, self.panel.vertical)
	__draw(parent, __c72, nil)
end

__f.w69 = { __f.b70, __f.d71 }

function __f.d22(self, parent)
	local __e23 = __el(parent, "box")
	__bind(__e23, "columns", __f.b24, self)
	__bind(__e23, "rows", __f.b25, self)
	__bind(__e23, "gap", __f.b26, self)
	__bind(__e23, "xAlign", __f.b27, self)
	__bind(__e23, "yAlign", __f.b28, self)
	__when(__e23, __f.w29, self)
	__when(__e23, __f.w41, self)
	__when(__e23, __f.w45, self)
	__when(__e23, __f.w49, self)
	__when(__e23, __f.w56, self)
	__when(__e23, __f.w65, self)
	__when(__e23, __f.w69, self)
end

function __f.d73(self, parent)
	local __c74 = __x.OrdaenPanel_settings_GeneralPage.new(parent, self.settings)
	__draw(parent, __c74, nil)
end

function __f.d75(self, parent)
	local __c76 = __x.OrdaenPanel_settings_MicroPage.new(parent, self.settings)
	__draw(parent, __c76, nil)
end

function __f.d77(self, parent)
	local __c78 = __x.OrdaenPanel_settings_StatusPage.new(parent, self.settings)
	__draw(parent, __c78, nil)
end

function __f.d79(self, parent)
	local __c80 = __x.OrdaenPanel_settings_BottomPage.new(parent, self.settings)
	__draw(parent, __c80, nil)
end

function __f.c81(self)
	return __getKey(self.settings.values, "microIcons") == "gold"
end

function __f.c82(self)
	return __getKey(self.settings.values, "charButton") == "portrait" and __getKey(self.settings.values, "microOn") and __getKey(self.settings.values, "bottomOn") and __getKey(self.settings.values, "edge") == "bottom" and self:at("micromenu") == "left"
end

function __f.c83(self)
	return __getKey(self.settings.values, "edge") == "left" or __getKey(self.settings.values, "edge") == "right"
end

function __f.c84(self)
	return self:outlineOf()
end

function __f.c85(self)
	local __t86
	if __getKey(self.settings.values, "shadow") then
		__t86 = TEXT_SHADOW
	else
		__t86 = NO_SHADOW
	end
	return __t86
end

function __f.c87(self)
	local __t88
	if __get(__x.game__Clock_invites) > 0 then
		__t88 = PENDING
	else
		__t88 = INK
	end
	return __t88
end

function __f.c89(self)
	return __getKey(self.settings.values, "microOn") and self:isFree("micromenu")
end

function __f.c90(self)
	return __getKey(self.settings.values, "microOn") and self:isFree("social")
end

function __f.c91(self)
	return __getKey(self.settings.values, "statusOn") and self:isFree("experience")
end

function __f.c92(self)
	return self:isFree("currencies")
end

function __f.c93(self)
	return self:isFree("bags")
end

function __f.c94(self)
	return self:hiddenNow()
end

function __f.c95(self)
	return __get(self.portraitShown) and __get(self.drawn)
end

function __f.c96(self)
	return __getKey(self.settings.values, "bottomOn") and not (__get(self.hidden) and __getKey(self.settings.values, "fadedAlpha") <= 0 and __getKey(self.settings.values, "show") ~= "mouseover")
end

function __f.c97(self)
	return self:opacityOf()
end

function __f.c98(self)
	return self:placeOf()
end

function __f.c99(self)
	local __t100
	if __getKey(self.settings.values, "fit") == "full" then
		__t100 = THIRDS
	else
		__t100 = FITTED
	end
	return __t100
end

function __f.c101(self)
	local __t102
	if __get(self.vertical) then
		__t102 = DOWN
	else
		__t102 = __get(self.thirds)
	end
	return __t102
end

function __f.c103(self)
	local __t104
	if __get(self.vertical) then
		__t104 = __get(self.thirds)
	else
		__t104 = nil
	end
	return __t104
end

function __f.c105(self)
	local __t106
	if __get(self.vertical) then
		__t106 = __getKey(self.settings.values, "height")
	else
		__t106 = nil
	end
	return __t106
end

function __f.c107(self)
	local __t108
	if __get(self.vertical) then
		__t108 = nil
	else
		__t108 = __getKey(self.settings.values, "height")
	end
	return __t108
end

function __f.c109(self)
	local __t110
	if __get(self.vertical) then
		__t110 = "center"
	else
		__t110 = "stretch"
	end
	return __t110
end

function __f.c111(self)
	local __t112
	if __get(self.vertical) then
		__t112 = "stretch"
	else
		__t112 = "center"
	end
	return __t112
end

function __f.b117(self)
	return __getKey(self.settings.values, "microOn")
end

function __f.b120(self)
	return __get(__x.game__Frames_MicroMenuContainer)
end

function __f.b123(self)
	return __get(__x.game__Frames_StoreMicroButton)
end

function __f.b125(self)
	return __get(__x.game__Frames_HelpMicroButton)
end

function __f.d118(self, parent)
	local __e119 = __el(parent, "frame")
	__bind(__e119, "of", __f.b120, self)
	__attr(__e119, "opacity", 0)
	local __e121 = __el(parent, "box")
	__attr(__e121, "width", 0)
	__attr(__e121, "height", 0)
	local __e122 = __el(__e121, "embed")
	__bind(__e122, "frame", __f.b123, self)
	__attr(__e122, "width", 0)
	__attr(__e122, "height", 0)
	__attr(__e122, "opacity", 0)
	local __e124 = __el(__e121, "embed")
	__bind(__e124, "frame", __f.b125, self)
	__attr(__e124, "width", 0)
	__attr(__e124, "height", 0)
	__attr(__e124, "opacity", 0)
end

__f.w116 = { __f.b117, __f.d118 }

function __f.b127(self)
	return __getKey(self.settings.values, "statusOn")
end

function __f.b130(self)
	return __get(__x.game__Frames_MainStatusTrackingBarContainer)
end

function __f.b132(self)
	return __get(__x.game__Frames_SecondaryStatusTrackingBarContainer)
end

function __f.d128(self, parent)
	local __e129 = __el(parent, "frame")
	__bind(__e129, "of", __f.b130, self)
	__attr(__e129, "shown", false)
	local __e131 = __el(parent, "frame")
	__bind(__e131, "of", __f.b132, self)
	__attr(__e131, "shown", false)
end

__f.w126 = { __f.b127, __f.d128 }

function __f.b134(self)
	return __get(__x.game__Frames_BagsBar)
end

function __f.b136(self)
	return __get(__x.game__Frames_BackpackFreeSlots)
end

function __f.b138(self)
	return __get(self.drawn)
end

function __f.b141(self)
	return __get(self.place)
end

function __f.b142(self)
	return __get(self.width)
end

function __f.b143(self)
	return __get(self.height)
end

function __f.b144(self)
	return __getKey(__x.Ordaen_core.theme, "panel").wood
end

function __f.b145(self)
	return __getKey(__x.Ordaen_core.theme, "panel").edge
end

function __f.b146(self)
	return __get(self.columns)
end

function __f.b147(self)
	return __get(self.rows)
end

function __f.b148(self)
	return __get(self.along)
end

function __f.b149(self)
	return __get(self.across)
end

function __f.b150(self)
	return __get(self.opacity)
end

function __f.d139(self, parent)
	local __e140 = __el(parent, "surface")
	__attr(__e140, "layer", "screen")
	__bind(__e140, "place", __f.b141, self)
	__bind(__e140, "width", __f.b142, self)
	__bind(__e140, "height", __f.b143, self)
	__bind(__e140, "background", __f.b144, self)
	__bind(__e140, "border", __f.b145, self)
	__attr(__e140, "padding", EDGE_ROOM)
	__bind(__e140, "columns", __f.b146, self)
	__bind(__e140, "rows", __f.b147, self)
	__bind(__e140, "xAlign", __f.b148, self)
	__bind(__e140, "yAlign", __f.b149, self)
	__bind(__e140, "opacity", __f.b150, self)
	__attr(__e140, "hoverWithin", true)
	__on(__e140, "enter", self, self.onEnter)
	__on(__e140, "leave", self, self.onLeave)
	local __c151 = ZoneBox.new(__e140, "left", self)
	__draw(__e140, __c151, nil)
	local __c152 = ZoneBox.new(__e140, "center", self)
	__draw(__e140, __c152, nil)
	local __c153 = ZoneBox.new(__e140, "right", self)
	__draw(__e140, __c153, nil)
end

__f.w137 = { __f.b138, __f.d139 }

function __f.b155(self)
	return __get(self.cornered)
end

function __f.b158(self)
	return __getKey(__x.Ordaen_core.theme, "panel").corner
end

function __f.b160(self)
	return __get(__x.game__Frames_CharacterMicroButton)
end

function __f.b162(self)
	return __getKey(__x.Ordaen_core.theme, "panel").badge
end

function __f.b164(self)
	return { __get(__x.game__Player_level) }
end

function __f.d156(self, parent)
	local __e157 = __el(parent, "surface")
	__attr(__e157, "layer", "screen")
	__attr(__e157, "place", CORNER)
	__attr(__e157, "width", 128)
	__attr(__e157, "height", 124)
	__attr(__e157, "portrait", "player")
	__bind(__e157, "mask", __f.b158, self)
	local __e159 = __el(__e157, "embed")
	__bind(__e159, "frame", __f.b160, self)
	__attr(__e159, "position", "absolute")
	__attr(__e159, "left", 0)
	__attr(__e159, "top", 0)
	__attr(__e159, "width", 128)
	__attr(__e159, "height", 124)
	__attr(__e159, "opacity", 0)
	local __e161 = __el(__e157, "box")
	__attr(__e161, "position", "absolute")
	__attr(__e161, "left", 86.7)
	__attr(__e161, "top", 5.3)
	__attr(__e161, "width", 36)
	__attr(__e161, "height", 36)
	__bind(__e161, "background", __f.b162, self)
	__attr(__e161, "xAlign", "center")
	__attr(__e161, "yAlign", "center")
	local __e163 = __el(__e161, "text")
	__attr(__e163, "value", "%d")
	__bind(__e163, "arguments", __f.b164, self)
	__attr(__e163, "textColor", GOLD)
	__attr(__e163, "textSize", 14)
	__attr(__e163, "wrap", false)
end

__f.w154 = { __f.b155, __f.d156 }

function __f.b166(self)
	return __get(self.freeMicro)
end

function __f.b171(self)
	return __getKey(__x.Ordaen_core.theme, "window").wood
end

function __f.b172(self)
	return __getKey(__x.Ordaen_core.theme, "frame").small
end

function __f.b173(self)
	return __getKey(__x.Ordaen_core.theme, "spacing").sm
end

function __f.d169(self, parent)
	local __e170 = __el(parent, "box")
	__bind(__e170, "background", __f.b171, self)
	__bind(__e170, "border", __f.b172, self)
	__bind(__e170, "padding", __f.b173, self)
	local __c174 = __x.OrdaenPanel_items_MicroLine.new(__e170, self.goldIcons, nil, nil)
	__draw(__e170, __c174, nil)
end

function __f.d167(self, parent)
	local __c168 = __x.Ordaen_placed_Placed.new(parent, "OrdaenPanel.micromenu", __x.OrdaenPanel_locales_PANEL_MICROMENU, __cell(MICRO_HOME))
	__draw(parent, __c168, { self = self, [""] = __f.d169 })
end

__f.w165 = { __f.b166, __f.d167 }

function __f.b176(self)
	return __get(self.freeSocial)
end

function __f.b181(self)
	return __getKey(__x.Ordaen_core.theme, "window").wood
end

function __f.b182(self)
	return __getKey(__x.Ordaen_core.theme, "frame").small
end

function __f.b183(self)
	return __getKey(__x.Ordaen_core.theme, "spacing").sm
end

function __f.d179(self, parent)
	local __e180 = __el(parent, "box")
	__bind(__e180, "background", __f.b181, self)
	__bind(__e180, "border", __f.b182, self)
	__bind(__e180, "padding", __f.b183, self)
	local __c184 = __x.OrdaenPanel_items_SocialLine.new(__e180, self.goldIcons, nil)
	__draw(__e180, __c184, nil)
end

function __f.d177(self, parent)
	local __c178 = __x.Ordaen_placed_Placed.new(parent, "OrdaenPanel.social", __x.OrdaenPanel_locales_PANEL_SOCIAL, __cell(SOCIAL_HOME))
	__draw(parent, __c178, { self = self, [""] = __f.d179 })
end

__f.w175 = { __f.b176, __f.d177 }

function __f.b186(self)
	return __get(self.freeExperience)
end

function __f.b191(self)
	return __getKey(__x.Ordaen_core.theme, "window").wood
end

function __f.b192(self)
	return __getKey(__x.Ordaen_core.theme, "frame").small
end

function __f.b193(self)
	return __getKey(__x.Ordaen_core.theme, "spacing").sm
end

function __f.d189(self, parent)
	local __e190 = __el(parent, "box")
	__attr(__e190, "width", 600)
	__bind(__e190, "background", __f.b191, self)
	__bind(__e190, "border", __f.b192, self)
	__bind(__e190, "padding", __f.b193, self)
	local __c194 = __x.OrdaenPanel_xpBar_XpBar.new(__e190, __cell(true))
	__draw(__e190, __c194, nil)
end

function __f.d187(self, parent)
	local __c188 = __x.Ordaen_placed_Placed.new(parent, "OrdaenPanel.experience", __x.OrdaenPanel_locales_PANEL_EXPERIENCE, __cell(EXPERIENCE_HOME))
	__draw(parent, __c188, { self = self, [""] = __f.d189 })
end

__f.w185 = { __f.b186, __f.d187 }

function __f.b196(self)
	return __get(self.freeMoney)
end

function __f.b201(self)
	return __getKey(__x.Ordaen_core.theme, "window").wood
end

function __f.b202(self)
	return __getKey(__x.Ordaen_core.theme, "frame").small
end

function __f.b203(self)
	return __getKey(__x.Ordaen_core.theme, "spacing").sm
end

function __f.d199(self, parent)
	local __e200 = __el(parent, "box")
	__bind(__e200, "background", __f.b201, self)
	__bind(__e200, "border", __f.b202, self)
	__bind(__e200, "padding", __f.b203, self)
	local __c204 = __x.OrdaenPanel_items_MoneyLine.new(__e200, self.outline, self.shadow, nil)
	__draw(__e200, __c204, nil)
end

function __f.d197(self, parent)
	local __c198 = __x.Ordaen_placed_Placed.new(parent, "OrdaenPanel.currencies", __x.OrdaenPanel_locales_PANEL_CURRENCIES, __cell(MONEY_HOME))
	__draw(parent, __c198, { self = self, [""] = __f.d199 })
end

__f.w195 = { __f.b196, __f.d197 }

function __f.b206(self)
	return __get(self.freeBags)
end

function __f.b211(self)
	return __getKey(__x.Ordaen_core.theme, "window").wood
end

function __f.b212(self)
	return __getKey(__x.Ordaen_core.theme, "frame").small
end

function __f.b213(self)
	return __getKey(__x.Ordaen_core.theme, "spacing").sm
end

function __f.d209(self, parent)
	local __e210 = __el(parent, "box")
	__bind(__e210, "background", __f.b211, self)
	__bind(__e210, "border", __f.b212, self)
	__bind(__e210, "padding", __f.b213, self)
	local __c214 = __x.OrdaenPanel_items_BagLine.new(__e210, nil)
	__draw(__e210, __c214, nil)
end

function __f.d207(self, parent)
	local __c208 = __x.Ordaen_placed_Placed.new(parent, "OrdaenPanel.bags", __x.OrdaenPanel_locales_PANEL_BAGS, __cell(BAGS_HOME))
	__draw(parent, __c208, { self = self, [""] = __f.d209 })
end

__f.w205 = { __f.b206, __f.d207 }

function __f.d115(self, parent)
	__when(parent, __f.w116, self)
	__when(parent, __f.w126, self)
	local __e133 = __el(parent, "frame")
	__bind(__e133, "of", __f.b134, self)
	__attr(__e133, "shown", false)
	local __e135 = __el(parent, "frame")
	__bind(__e135, "of", __f.b136, self)
	__attr(__e135, "shown", false)
	__when(parent, __f.w137, self)
	__when(parent, __f.w154, self)
	__when(parent, __f.w165, self)
	__when(parent, __f.w175, self)
	__when(parent, __f.w185, self)
	__when(parent, __f.w195, self)
	__when(parent, __f.w205, self)
end

INK = { r = 0.910, g = 0.863, b = 0.769, a = 1 }
PENDING = { r = 1, g = 0.600, b = 0.200, a = 1 }
TEXT = 12
TEXT_SHADOW = { color = { r = 0, g = 0, b = 0, a = 1 }, x = 1, y = -1 }
NO_SHADOW = { color = { r = 0, g = 0, b = 0, a = 0 }, x = 0, y = 0 }
EDGE_ROOM = { top = 4 }
MOUSEOVER_LEAST = 0.00392156862745098
MICRO_HOME = { point = "BOTTOMLEFT", x = 140, y = -10 }
SOCIAL_HOME = { point = "BOTTOMLEFT", x = 660, y = -10 }
EXPERIENCE_HOME = { point = "BOTTOM", x = 0, y = -20 }
MONEY_HOME = { point = "BOTTOMRIGHT", x = -330, y = -20 }
BAGS_HOME = { point = "BOTTOMRIGHT", x = -10, y = -10 }
THIRDS = { { fr = 1 }, { fr = 1 }, { fr = 1 } }
FITTED = { "auto", "auto", "auto" }
PORTRAIT_WIDTH = 128
PORTRAIT_HEIGHT = 124
PORTRAIT_ROOM = { 128, "auto" }
CORNER = { point = "BOTTOMLEFT" }
GOLD = { r = 1, g = 0.820, b = 0, a = 1 }
DOWN = { { fr = 1 } }

ZoneBox = __class({})

function ZoneBox.new(__owner, zone, panel)
	local self = setmetatable({}, ZoneBox)
	R.adopt(__owner, self)
	self.zone = zone
	self.panel = panel
	self.align = __computed(self, __f.c1, self)
	self.micro = __computed(self, __f.c2, self)
	self.social = __computed(self, __f.c3, self)
	self.experience = __computed(self, __f.c4, self)
	self.zoneName = __computed(self, __f.c5, self)
	self.clock = __computed(self, __f.c6, self)
	self.money = __computed(self, __f.c7, self)
	self.bags = __computed(self, __f.c8, self)
	self.columns = __computed(self, __f.c9, self)
	self.rows = __computed(self, __f.c11, self)
	self.along = __computed(self, __f.c13, self)
	self.across = __computed(self, __f.c15, self)
	return self
end

function ZoneBox:alignOf()
	if __get(self.experience) then
		return "stretch"
	end
	local __s17 = self.zone
	if __s17 == "left" then
		return "start"
	elseif __s17 == "center" then
		return "center"
	else
		return "end"
	end
end

function ZoneBox:tracks()
	local list = {}
	local __l19 = { __get(self.micro), __get(self.social) }
	for __i18 = 1, #__l19 do
		local here = __l19[__i18]
		if here then
			__insert(list, "auto")
		end
	end
	if __get(self.experience) then
		__insert(list, { fr = 1 })
	end
	local __l21 = { __get(self.zoneName), __get(self.clock), __get(self.money), __get(self.bags) }
	for __i20 = 1, #__l21 do
		local here = __l21[__i20]
		if here then
			__insert(list, "auto")
		end
	end
	return list
end

function ZoneBox:onClock()
	__x.game__Clock_toggleCalendar()
end

function ZoneBox:render()
	return __template(__f.d22, self)
end

Panel = __class({})

function Panel.new(__owner)
	local self = setmetatable({ title = "Ordaen Panel" }, Panel)
	R.adopt(__owner, self)
	self.settings = __x.Ordaen_settings_Settings.new(self, __x.OrdaenPanel_choices_DEFAULTS, "account")
	self.pages = { { title = __x.OrdaenPanel_locales_TAB_GENERAL, content = __template(__f.d73, self) }, { title = __x.OrdaenPanel_locales_TAB_MICROMENU, content = __template(__f.d75, self) }, { title = __x.OrdaenPanel_locales_TAB_STATUS, content = __template(__f.d77, self) }, { title = __x.OrdaenPanel_locales_TAB_BOTTOM, content = __template(__f.d79, self) } }
	self.hovered = __cell(false)
	self.goldIcons = __computed(self, __f.c81, self)
	self.portraitShown = __computed(self, __f.c82, self)
	self.vertical = __computed(self, __f.c83, self)
	self.outline = __computed(self, __f.c84, self)
	self.shadow = __computed(self, __f.c85, self)
	self.clockColor = __computed(self, __f.c87, self)
	self.freeMicro = __computed(self, __f.c89, self)
	self.freeSocial = __computed(self, __f.c90, self)
	self.freeExperience = __computed(self, __f.c91, self)
	self.freeMoney = __computed(self, __f.c92, self)
	self.freeBags = __computed(self, __f.c93, self)
	self.hidden = __computed(self, __f.c94, self)
	self.cornered = __computed(self, __f.c95, self)
	self.drawn = __computed(self, __f.c96, self)
	self.opacity = __computed(self, __f.c97, self)
	self.place = __computed(self, __f.c98, self)
	self.thirds = __computed(self, __f.c99, self)
	self.columns = __computed(self, __f.c101, self)
	self.rows = __computed(self, __f.c103, self)
	self.width = __computed(self, __f.c105, self)
	self.height = __computed(self, __f.c107, self)
	self.along = __computed(self, __f.c109, self)
	self.across = __computed(self, __f.c111, self)
	return self
end

function Panel:outlineOf()
	local __s113 = __getKey(self.settings.values, "outline")
	if __s113 == "none" then
		return 0
	elseif __s113 == "thin" then
		return 1
	elseif __s113 == "thick" then
		return 2
	end
end

function Panel:at(item)
	return __getKey(self.settings.values, "places")[item] or "off"
end

function Panel:isFree(item)
	return not __getKey(self.settings.values, "bottomOn") or self:at(item) == "off"
end

function Panel:microIn(zone)
	return __getKey(self.settings.values, "microOn") and self:at("micromenu") == zone
end

function Panel:socialIn(zone)
	return __getKey(self.settings.values, "microOn") and self:at("social") == zone
end

function Panel:experienceIn(zone)
	return __getKey(self.settings.values, "statusOn") and self:at("experience") == zone
end

function Panel:zoneIn(zone)
	return self:at("zone") == zone
end

function Panel:clockIn(zone)
	return self:at("clock") == zone
end

function Panel:moneyIn(zone)
	return self:at("currencies") == zone
end

function Panel:bagsIn(zone)
	return self:at("bags") == zone
end

function Panel:hiddenNow()
	if __getKey(self.settings.values, "show") == "never" then
		return true
	end
	local fighting = __get(__x.game__Situation_combat)
	if __getKey(self.settings.values, "combat") == "hide" and fighting then
		return true
	end
	if __getKey(self.settings.values, "combat") == "only" and not fighting then
		return true
	end
	if __getKey(self.settings.values, "vehicle") and __get(__x.game__Situation_vehicle) then
		return true
	end
	if __getKey(self.settings.values, "petBattle") and __get(__x.game__Situation_petBattle) then
		return true
	end
	if __getKey(self.settings.values, "resting") and __get(__x.game__Situation_resting) then
		return true
	end
	return __getKey(self.settings.values, "show") == "mouseover" and not __get(self.hovered)
end

function Panel:opacityOf()
	if not __get(self.hidden) then
		return 1
	end
	if __getKey(self.settings.values, "show") == "mouseover" then
		return __x.math_max(__getKey(self.settings.values, "fadedAlpha"), 0.00392156862745098)
	end
	return __getKey(self.settings.values, "fadedAlpha")
end

function Panel:placeOf()
	local whole = __getKey(self.settings.values, "fit") == "full"
	local __s114 = __getKey(self.settings.values, "edge")
	if __s114 == "bottom" then
		return { side = "bottom", whole = whole }
	elseif __s114 == "top" then
		return { side = "top", whole = whole }
	elseif __s114 == "left" then
		return { side = "left", whole = whole }
	elseif __s114 == "right" then
		return { side = "right", whole = whole }
	end
end

function Panel:onEnter()
	__set(self.hovered, true)
end

function Panel:onLeave()
	__set(self.hovered, false)
end

function Panel:render()
	return __template(__f.d115, self)
end
__inherit(ZoneBox, { __x.Ordaen_module_Component })
__inherit(Panel, { __x.Ordaen_module_Module })

M.INK = INK
M.PENDING = PENDING
M.TEXT = TEXT
M.TEXT_SHADOW = TEXT_SHADOW
M.NO_SHADOW = NO_SHADOW
M.EDGE_ROOM = EDGE_ROOM
M.MOUSEOVER_LEAST = MOUSEOVER_LEAST
M.MICRO_HOME = MICRO_HOME
M.SOCIAL_HOME = SOCIAL_HOME
M.EXPERIENCE_HOME = EXPERIENCE_HOME
M.MONEY_HOME = MONEY_HOME
M.BAGS_HOME = BAGS_HOME
M.THIRDS = THIRDS
M.FITTED = FITTED
M.PORTRAIT_WIDTH = PORTRAIT_WIDTH
M.PORTRAIT_HEIGHT = PORTRAIT_HEIGHT
M.PORTRAIT_ROOM = PORTRAIT_ROOM
M.CORNER = CORNER
M.GOLD = GOLD
M.DOWN = DOWN
M.ZoneBox = ZoneBox
M.Panel = Panel
