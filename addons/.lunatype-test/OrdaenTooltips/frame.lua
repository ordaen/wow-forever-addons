-- Made by lunatype from OrdaenTooltips/frame.luna: change the source, not this file.
local R = LunaType
local __get, __getKey, __len, __set, __cell, __computed, __watch, __event, __emit, __class, __inherit, __el, __attr, __bind, __on, __template, __draw, __slot, __when, __each = R.get, R.getKey, R.len, R.set, R.cell, R.computed, R.watch, R.event, R.emit, R.class, R.inherit, R.el, R.attr, R.bind, R.on, R.template, R.draw, R.slot, R.when, R.each
local __insert = table.insert
local __Ordaen_core = R.addon("Ordaen")["core"]
local __OrdaenTooltips_locales_LOCKED_HINT = R.addon("OrdaenTooltips")["locales"].LOCKED_HINT
local __Ordaen_module_Component = R.addon("Ordaen")["module"].Component
local M = {}
R.addon("OrdaenTooltips")["frame"] = M
local PX, WIDTH, SIDE_WIDTH, ICON, SECTION, HEADING, LABEL, QUIET, QUIET_VALUE, BODY, FREE, BLACK, RULE, DIVIDER, GROOVE, RIM, FILL, WITH_ICON, ALONE, NAME_VALUE, OWN_WIDTH, SECTION_PAD, BAR_PAD, BAR_ROW, BAR_HEIGHT, TRACK, BAR_GOLD, UNDERLINE, BY_ITS_TEXT, CLOSE_ART, UNDER_TITLE, NO_PAD, CELL_PAD, CELL_PAD_LAST, INDENT, SPACED, TermText, PartText, FactCell, Row, TipFrame

local __f = {}

function __f.c1(self)
	return __get(self.locked) and self:opensSomething()
end

function __f.c2(self)
	return __get(self.lit) and __get(self.over)
end

function __f.b7(self)
	return __get(self.text)
end

function __f.b8(self)
	return __get(self.color)
end

function __f.b9(self)
	return __get(self.size)
end

function __f.b11(self)
	return __get(self.lit)
end

function __f.d12(self, parent)
	local __e13 = __el(parent, "box")
	__attr(__e13, "position", "absolute")
	__attr(__e13, "left", 0)
	__attr(__e13, "right", 0)
	__attr(__e13, "bottom", 0)
	__attr(__e13, "height", 0.8333333333333334)
	__attr(__e13, "background", UNDERLINE)
end

__f.w10 = { __f.b11, __f.d12 }

function __f.b15(self)
	return __get(self.lit)
end

function __f.d16(self, parent)
	local __e17 = __el(parent, "box")
	__attr(__e17, "position", "absolute")
	__attr(__e17, "left", 0)
	__attr(__e17, "top", 0)
	__attr(__e17, "right", 0)
	__attr(__e17, "bottom", 0)
	__attr(__e17, "cursor", "Interface/Cursor/QuestTurnIn")
	__on(__e17, "enter", self, self.onEnter)
	__on(__e17, "leave", self, self.onLeave)
end

__f.w14 = { __f.b15, __f.d16 }

function __f.b19(self)
	return __get(self.open)
end

function __f.b22(self)
	return __get(self.opens)
end

function __f.d20(self, parent)
	local __e21 = __el(parent, "surface")
	__attr(__e21, "layer", "tooltip")
	__attr(__e21, "place", BY_ITS_TEXT)
	__slot(__e21, self, "opened", nil, { __computed(__e21, __f.b22, self) })
end

__f.w18 = { __f.b19, __f.d20 }

function __f.d4(self, parent)
	local __e5 = __el(parent, "box")
	local __e6 = __el(__e5, "text")
	__bind(__e6, "value", __f.b7, self)
	__bind(__e6, "textColor", __f.b8, self)
	__bind(__e6, "textSize", __f.b9, self)
	__attr(__e6, "wrap", false)
	__when(__e5, __f.w10, self)
	__when(__e5, __f.w14, self)
	__when(__e5, __f.w18, self)
end

function __f.c23(self)
	return __get(self.index) > 1
end

function __f.c24(self)
	return __getKey(self.part, "color") or self.color
end

function __f.b27(self)
	return __get(self.notFirst)
end

function __f.d28(self, parent)
	local __e29 = __el(parent, "text")
	__attr(__e29, "value", " · ")
	__attr(__e29, "textColor", self.color)
	__attr(__e29, "textSize", 11.666666666666668)
	__attr(__e29, "wrap", false)
end

__f.w26 = { __f.b27, __f.d28 }

function __f.b31(self)
	return __getKey(self.part, "text")
end

function __f.b32(self)
	return __getKey(self.part, "opens")
end

function __f.b36(self, __v34)
	return __get(__v34[1])
end

function __f.d33(self, parent, __1, __2, __3, __v34)
	local __e35 = __el(parent, "box")
	__slot(__e35, self, "opened", nil, { __computed(__e35, __f.b36, self, __v34) }, __v34)
end

function __f.d25(self, parent)
	__when(parent, __f.w26, self)
	local __c30 = TermText.new(parent, __computed(parent, __f.b31, self), self.own, __cell(11.666666666666668), __computed(parent, __f.b32, self), self.locked)
	__draw(parent, __c30, { self = self, ["opened"] = __f.d33 })
end

function __f.c37(self)
	return __get(self.locked) and self:opensSomething()
end

function __f.c38(self)
	return __get(self.lit) and __get(self.over)
end

function __f.c39(self)
	local __t40
	if __get(self.index) > 1 then
		__t40 = DIVIDER
	else
		__t40 = nil
	end
	return __t40
end

function __f.c41(self)
	local __t42
	if __get(self.last) then
		__t42 = CELL_PAD_LAST
	else
		__t42 = CELL_PAD
	end
	return __t42
end

function __f.c43(self)
	return __getKey(self.fact, "glyph") ~= nil
end

function __f.c44(self)
	return __getKey(self.fact, "glyph") or ""
end

function __f.c45(self)
	return __getKey(self.fact, "tint") or BODY
end

function __f.c46(self)
	return __getKey(self.fact, "color") or BODY
end

function __f.b50(self)
	return __get(self.padding)
end

function __f.b51(self)
	return __get(self.divider)
end

function __f.b54(self)
	return __get(self.hasGlyph)
end

function __f.b57(self)
	return __get(self.glyph)
end

function __f.b58(self)
	return __get(self.tint)
end

function __f.d55(self, parent)
	local __e56 = __el(parent, "box")
	__attr(__e56, "width", 13.333333333333334)
	__attr(__e56, "height", 13.333333333333334)
	__bind(__e56, "background", __f.b57, self)
	__bind(__e56, "tint", __f.b58, self)
end

__f.w53 = { __f.b54, __f.d55 }

function __f.b61(self)
	return __getKey(self.fact, "text")
end

function __f.b62(self)
	return __get(self.color)
end

function __f.b64(self)
	return __get(self.lit)
end

function __f.d65(self, parent)
	local __e66 = __el(parent, "box")
	__attr(__e66, "position", "absolute")
	__attr(__e66, "left", 0)
	__attr(__e66, "right", 0)
	__attr(__e66, "bottom", 0)
	__attr(__e66, "height", 0.8333333333333334)
	__attr(__e66, "background", UNDERLINE)
end

__f.w63 = { __f.b64, __f.d65 }

function __f.b68(self)
	return __get(self.lit)
end

function __f.d69(self, parent)
	local __e70 = __el(parent, "box")
	__attr(__e70, "position", "absolute")
	__attr(__e70, "left", 0)
	__attr(__e70, "top", 0)
	__attr(__e70, "right", 0)
	__attr(__e70, "bottom", 0)
	__attr(__e70, "cursor", "Interface/Cursor/QuestTurnIn")
	__on(__e70, "enter", self, self.onEnter)
	__on(__e70, "leave", self, self.onLeave)
end

__f.w67 = { __f.b68, __f.d69 }

function __f.b72(self)
	return __get(self.open)
end

function __f.b75(self)
	return __getKey(self.fact, "opens")
end

function __f.d73(self, parent)
	local __e74 = __el(parent, "surface")
	__attr(__e74, "layer", "tooltip")
	__attr(__e74, "place", BY_ITS_TEXT)
	__slot(__e74, self, "opened", nil, { __computed(__e74, __f.b75, self) })
end

__f.w71 = { __f.b72, __f.d73 }

function __f.d48(self, parent)
	local __e49 = __el(parent, "box")
	__bind(__e49, "padding", __f.b50, self)
	__bind(__e49, "border", __f.b51, self)
	__attr(__e49, "xAlign", "center")
	local __e52 = __el(__e49, "box")
	__attr(__e52, "columns", { "auto", "auto" })
	__attr(__e52, "gap", 4.166666666666667)
	__attr(__e52, "yAlign", "center")
	__when(__e52, __f.w53, self)
	local __e59 = __el(__e52, "box")
	local __e60 = __el(__e59, "text")
	__bind(__e60, "value", __f.b61, self)
	__bind(__e60, "textColor", __f.b62, self)
	__attr(__e60, "textSize", 13.333333333333334)
	__attr(__e60, "wrap", false)
	__when(__e59, __f.w63, self)
	__when(__e49, __f.w67, self)
	__when(__e49, __f.w71, self)
end

function __f.c76(self)
	return __getKey(self.line, "right") ~= nil
end

function __f.c77(self)
	return __getKey(self.line, "right") or ""
end

function __f.c78(self)
	return self:opensSomething()
end

function __f.b82(self)
	return __get(self.paired)
end

function __f.b85(self)
	return __getKey(self.line, "padding")
end

function __f.b87(self)
	return __get(self.opening)
end

function __f.b91(self)
	return __getKey(self.line, "left")
end

function __f.b92(self)
	return __getKey(self.line, "leftColor")
end

function __f.b93(self)
	return __getKey(self.line, "size")
end

function __f.b94(self)
	return __getKey(self.line, "opens")
end

function __f.b98(self, __v96)
	return __get(__v96[1])
end

function __f.d95(self, parent, __1, __2, __3, __v96)
	local __e97 = __el(parent, "box")
	__slot(__e97, self, "opened", nil, { __computed(__e97, __f.b98, self, __v96) }, __v96)
end

function __f.d88(self, parent)
	local __e89 = __el(parent, "box")
	__attr(__e89, "columns", OWN_WIDTH)
	local __c90 = TermText.new(__e89, __computed(__e89, __f.b91, self), __computed(__e89, __f.b92, self), __computed(__e89, __f.b93, self), __computed(__e89, __f.b94, self), self.locked)
	__draw(__e89, __c90, { self = self, ["opened"] = __f.d95 })
end

function __f.b101(self)
	return __getKey(self.line, "left")
end

function __f.b102(self)
	return __getKey(self.line, "leftColor")
end

function __f.b103(self)
	return __getKey(self.line, "size")
end

function __f.d99(self, parent)
	local __e100 = __el(parent, "text")
	__bind(__e100, "value", __f.b101, self)
	__bind(__e100, "textColor", __f.b102, self)
	__bind(__e100, "textSize", __f.b103, self)
end

__f.w86 = { __f.b87, __f.d88, false, __f.d99 }

function __f.b105(self)
	return __get(self.right)
end

function __f.b106(self)
	return __getKey(self.line, "rightColor")
end

function __f.b107(self)
	return __getKey(self.line, "size")
end

function __f.d83(self, parent)
	local __e84 = __el(parent, "box")
	__attr(__e84, "columns", NAME_VALUE)
	__attr(__e84, "gap", 8.333333333333334)
	__bind(__e84, "padding", __f.b85, self)
	__when(__e84, __f.w86, self)
	local __e104 = __el(__e84, "text")
	__bind(__e104, "value", __f.b105, self)
	__bind(__e104, "textColor", __f.b106, self)
	__bind(__e104, "textSize", __f.b107, self)
	__attr(__e104, "wrap", false)
end

function __f.b110(self)
	return __getKey(self.line, "padding")
end

function __f.b112(self)
	return __get(self.opening)
end

function __f.b116(self)
	return __getKey(self.line, "left")
end

function __f.b117(self)
	return __getKey(self.line, "leftColor")
end

function __f.b118(self)
	return __getKey(self.line, "size")
end

function __f.b119(self)
	return __getKey(self.line, "opens")
end

function __f.b123(self, __v121)
	return __get(__v121[1])
end

function __f.d120(self, parent, __1, __2, __3, __v121)
	local __e122 = __el(parent, "box")
	__slot(__e122, self, "opened", nil, { __computed(__e122, __f.b123, self, __v121) }, __v121)
end

function __f.d113(self, parent)
	local __e114 = __el(parent, "box")
	__attr(__e114, "columns", OWN_WIDTH)
	local __c115 = TermText.new(__e114, __computed(__e114, __f.b116, self), __computed(__e114, __f.b117, self), __computed(__e114, __f.b118, self), __computed(__e114, __f.b119, self), self.locked)
	__draw(__e114, __c115, { self = self, ["opened"] = __f.d120 })
end

function __f.b126(self)
	return __getKey(self.line, "left")
end

function __f.b127(self)
	return __getKey(self.line, "leftColor")
end

function __f.b128(self)
	return __getKey(self.line, "size")
end

function __f.d124(self, parent)
	local __e125 = __el(parent, "text")
	__bind(__e125, "value", __f.b126, self)
	__bind(__e125, "textColor", __f.b127, self)
	__bind(__e125, "textSize", __f.b128, self)
end

__f.w111 = { __f.b112, __f.d113, false, __f.d124 }

function __f.d108(self, parent)
	local __e109 = __el(parent, "box")
	__bind(__e109, "padding", __f.b110, self)
	__when(__e109, __f.w111, self)
end

__f.w81 = { __f.b82, __f.d83, false, __f.d108 }

function __f.d80(self, parent)
	__when(parent, __f.w81, self)
end

function __f.c129(self)
	local __t130
	if __get(self.side) then
		__t130 = 220
	else
		__t130 = 261.6666666666667
	end
	return __t130
end

function __f.c131(self)
	return __getKey(self.model, "header") ~= nil
end

function __f.c132(self)
	return __getKey(self.model, "header") or ""
end

function __f.c133(self)
	return self:pictured()
end

function __f.c134(self)
	return self:iconArt()
end

function __f.c135(self)
	return self:faceUnit()
end

function __f.c136(self)
	local __t137
	if __get(self.hasIcon) then
		__t137 = WITH_ICON
	else
		__t137 = ALONE
	end
	return __t137
end

function __f.c138(self)
	return #__getKey(self.model, "desc") > 0
end

function __f.c139(self)
	return #__getKey(self.model, "info") > 0
end

function __f.c140(self)
	return self:tracks(#__getKey(self.model, "desc"))
end

function __f.c141(self)
	return self:tracks(#__getKey(self.model, "info"))
end

function __f.c142(self)
	return #__getKey(self.model, "facts")
end

function __f.c143(self)
	return __get(self.facts) > 0
end

function __f.c144(self)
	return self:rows(__getKey(self.model, "body"))
end

function __f.c145(self)
	return self:rows(__getKey(self.model, "more"))
end

function __f.c146(self)
	return self:notes()
end

function __f.c147(self)
	return self:hotkeys()
end

function __f.c148(self)
	return __len(self.body) > 0
end

function __f.c149(self)
	return __len(self.more) > 0
end

function __f.c150(self)
	return __len(self.foot) > 0
end

function __f.c151(self)
	return __len(self.keys) > 0
end

function __f.c152(self)
	return not __get(self.hasBody) and not __get(self.hasMore) and not __get(self.hasFoot) and not __get(self.hasKeys)
end

function __f.c153(self)
	local __t154
	if __get(self.hasFacts) or not __get(self.bandLast) or __get(self.hasHeader) then
		__t154 = UNDER_TITLE
	else
		__t154 = NO_PAD
	end
	return __t154
end

function __f.c155(self)
	local __t156
	if __get(self.hasFacts) then
		__t156 = RULE
	else
		__t156 = nil
	end
	return __t156
end

function __f.c157(self)
	local __t158
	if __get(self.charge) > 0 then
		__t158 = TRACK
	else
		__t158 = nil
	end
	return __t158
end

function __f.c159(self)
	return { percent = __get(self.charge) }
end

function __f.b171(self)
	return __get(self.width)
end

function __f.b172(self)
	return __getKey(__Ordaen_core.theme, "frame").small
end

function __f.b173(self)
	return __getKey(__Ordaen_core.theme, "window").wood
end

function __f.b175(self)
	return __get(self.hasHeader)
end

function __f.b180(self)
	return __get(self.header)
end

function __f.d176(self, parent)
	local __e177 = __el(parent, "box")
	__attr(__e177, "height", 29.166666666666668)
	__attr(__e177, "gap", 5)
	local __e178 = __el(__e177, "box")
	__attr(__e178, "xAlign", "center")
	local __e179 = __el(__e178, "text")
	__bind(__e179, "value", __f.b180, self)
	__attr(__e179, "textColor", HEADING)
	__attr(__e179, "textSize", 12.5)
	__attr(__e179, "wrap", false)
	local __e181 = __el(__e177, "box")
	__attr(__e181, "height", 1.6666666666666667)
	__attr(__e181, "border", GROOVE)
end

__f.w174 = { __f.b175, __f.d176 }

function __f.b183(self)
	return __get(self.titleColumns)
end

function __f.b184(self)
	return __get(self.titlePadding)
end

function __f.b186(self)
	return __get(self.hasIcon)
end

function __f.b190(self)
	return __get(self.icon)
end

function __f.b191(self)
	return __get(self.face)
end

function __f.d187(self, parent)
	local __e188 = __el(parent, "box")
	__attr(__e188, "width", 50)
	__attr(__e188, "height", 50)
	__attr(__e188, "border", RIM)
	__attr(__e188, "padding", 0.8333333333333334)
	__attr(__e188, "background", BLACK)
	__attr(__e188, "rows", FILL)
	local __e189 = __el(__e188, "box")
	__bind(__e189, "background", __f.b190, self)
	__bind(__e189, "portrait", __f.b191, self)
end

__f.w185 = { __f.b186, __f.d187 }

function __f.b194(self)
	return __getKey(self.model, "name")
end

function __f.b195(self)
	return __getKey(self.model, "nameColor")
end

function __f.b197(self)
	return __get(self.hasDesc)
end

function __f.b200(self)
	return __get(self.descColumns)
end

function __f.b201(self)
	return __getKey(self.model, "desc")
end

function __f.b207(self, index, part, __v205)
	return __get(__v205[1])
end

function __f.d204(self, parent, index, part, __3, __v205)
	local __e206 = __el(parent, "box")
	__slot(__e206, self, "opened", nil, { __computed(__e206, __f.b207, self, index, part, __v205) }, index, part, __v205)
end

function __f.d202(self, parent, index, part)
	local __c203 = PartText.new(parent, __cell(part), __cell(index), LABEL, self.locked)
	__draw(parent, __c203, { self = self, a = index, b = part, ["opened"] = __f.d204 })
end

function __f.d198(self, parent)
	local __e199 = __el(parent, "box")
	__bind(__e199, "columns", __f.b200, self)
	__attr(__e199, "height", 15)
	__attr(__e199, "yAlign", "center")
	__each(__e199, __f.b201, nil, __f.d202, 2, 1, false, self)
end

__f.w196 = { __f.b197, __f.d198 }

function __f.b209(self)
	return __get(self.hasInfo)
end

function __f.b212(self)
	return __get(self.infoColumns)
end

function __f.b213(self)
	return __getKey(self.model, "info")
end

function __f.b219(self, index, part, __v217)
	return __get(__v217[1])
end

function __f.d216(self, parent, index, part, __3, __v217)
	local __e218 = __el(parent, "box")
	__slot(__e218, self, "opened", nil, { __computed(__e218, __f.b219, self, index, part, __v217) }, index, part, __v217)
end

function __f.d214(self, parent, index, part)
	local __c215 = PartText.new(parent, __cell(part), __cell(index), QUIET, self.locked)
	__draw(parent, __c215, { self = self, a = index, b = part, ["opened"] = __f.d216 })
end

function __f.d210(self, parent)
	local __e211 = __el(parent, "box")
	__bind(__e211, "columns", __f.b212, self)
	__attr(__e211, "height", 15)
	__attr(__e211, "yAlign", "center")
	__each(__e211, __f.b213, nil, __f.d214, 2, 1, false, self)
end

__f.w208 = { __f.b209, __f.d210 }

function __f.b221(self)
	return __get(self.hasFacts)
end

function __f.b224(self)
	return __get(self.facts)
end

function __f.b225(self)
	return __getKey(self.model, "facts")
end

function __f.b231(self, index, fact, __v229)
	return __get(__v229[1])
end

function __f.d228(self, parent, index, fact, __3, __v229)
	local __e230 = __el(parent, "box")
	__slot(__e230, self, "opened", nil, { __computed(__e230, __f.b231, self, index, fact, __v229) }, index, fact, __v229)
end

function __f.d226(self, parent, index, fact)
	local __c227 = FactCell.new(parent, __cell(fact), __cell(index), self.bandLast, self.locked)
	__draw(parent, __c227, { self = self, a = index, b = fact, ["opened"] = __f.d228 })
end

function __f.d222(self, parent)
	local __e223 = __el(parent, "box")
	__bind(__e223, "columns", __f.b224, self)
	__attr(__e223, "border", RULE)
	__each(__e223, __f.b225, nil, __f.d226, 2, 1, false, self)
end

__f.w220 = { __f.b221, __f.d222 }

function __f.b233(self)
	return __get(self.hasBody)
end

function __f.b236(self)
	return __get(self.bodyRule)
end

function __f.b237(self)
	return __get(self.body)
end

function __f.b243(self, line, __v241)
	return __get(__v241[1])
end

function __f.d240(self, parent, line, __2, __3, __v241)
	local __e242 = __el(parent, "box")
	__slot(__e242, self, "opened", nil, { __computed(__e242, __f.b243, self, line, __v241) }, line, __v241)
end

function __f.d238(self, parent, line)
	local __c239 = Row.new(parent, line, self.locked)
	__draw(parent, __c239, { self = self, a = line, ["opened"] = __f.d240 })
end

function __f.d234(self, parent)
	local __e235 = __el(parent, "box")
	__attr(__e235, "gap", 1.6666666666666667)
	__attr(__e235, "padding", SECTION_PAD)
	__bind(__e235, "border", __f.b236, self)
	__each(__e235, __f.b237, nil, __f.d238, 1, 0, true, self)
end

__f.w232 = { __f.b233, __f.d234 }

function __f.b245(self)
	return __get(self.hasMore)
end

function __f.b248(self)
	return __get(self.more)
end

function __f.b254(self, line, __v252)
	return __get(__v252[1])
end

function __f.d251(self, parent, line, __2, __3, __v252)
	local __e253 = __el(parent, "box")
	__slot(__e253, self, "opened", nil, { __computed(__e253, __f.b254, self, line, __v252) }, line, __v252)
end

function __f.d249(self, parent, line)
	local __c250 = Row.new(parent, line, self.locked)
	__draw(parent, __c250, { self = self, a = line, ["opened"] = __f.d251 })
end

function __f.d246(self, parent)
	local __e247 = __el(parent, "box")
	__attr(__e247, "gap", 1.6666666666666667)
	__attr(__e247, "padding", SECTION_PAD)
	__attr(__e247, "border", RULE)
	__each(__e247, __f.b248, nil, __f.d249, 1, 0, true, self)
end

__f.w244 = { __f.b245, __f.d246 }

function __f.b256(self)
	return __get(self.hasFoot)
end

function __f.b259(self)
	return __get(self.foot)
end

function __f.b265(self, line, __v263)
	return __get(__v263[1])
end

function __f.d262(self, parent, line, __2, __3, __v263)
	local __e264 = __el(parent, "box")
	__slot(__e264, self, "opened", nil, { __computed(__e264, __f.b265, self, line, __v263) }, line, __v263)
end

function __f.d260(self, parent, line)
	local __c261 = Row.new(parent, line, self.locked)
	__draw(parent, __c261, { self = self, a = line, ["opened"] = __f.d262 })
end

function __f.d257(self, parent)
	local __e258 = __el(parent, "box")
	__attr(__e258, "gap", 1.6666666666666667)
	__attr(__e258, "padding", SECTION_PAD)
	__attr(__e258, "border", RULE)
	__each(__e258, __f.b259, nil, __f.d260, 1, 0, true, self)
end

__f.w255 = { __f.b256, __f.d257 }

function __f.b267(self)
	return __get(self.hasKeys)
end

function __f.b270(self)
	return __get(self.keys)
end

function __f.b276(self, line, __v274)
	return __get(__v274[1])
end

function __f.d273(self, parent, line, __2, __3, __v274)
	local __e275 = __el(parent, "box")
	__slot(__e275, self, "opened", nil, { __computed(__e275, __f.b276, self, line, __v274) }, line, __v274)
end

function __f.d271(self, parent, line)
	local __c272 = Row.new(parent, line, self.locked)
	__draw(parent, __c272, { self = self, a = line, ["opened"] = __f.d273 })
end

function __f.d268(self, parent)
	local __e269 = __el(parent, "box")
	__attr(__e269, "gap", 1.6666666666666667)
	__attr(__e269, "padding", SECTION_PAD)
	__attr(__e269, "border", RULE)
	__each(__e269, __f.b270, nil, __f.d271, 1, 0, true, self)
end

__f.w266 = { __f.b267, __f.d268 }

function __f.b278(self)
	return __get(self.main)
end

function __f.b283(self)
	return __get(self.locked)
end

function __f.d284(self, parent)
	local __e285 = __el(parent, "text")
	__attr(__e285, "value", __OrdaenTooltips_locales_LOCKED_HINT)
	__attr(__e285, "textColor", QUIET)
	__attr(__e285, "textSize", 10.833333333333334)
	__attr(__e285, "wrap", false)
end

function __f.b288(self)
	return __get(self.track)
end

function __f.b290(self)
	return __get(self.filled)
end

function __f.d286(self, parent)
	local __e287 = __el(parent, "box")
	__attr(__e287, "height", 2.5)
	__bind(__e287, "background", __f.b288, self)
	local __e289 = __el(__e287, "box")
	__attr(__e289, "position", "absolute")
	__attr(__e289, "left", 0)
	__attr(__e289, "top", 0)
	__attr(__e289, "bottom", 0)
	__bind(__e289, "width", __f.b290, self)
	__attr(__e289, "background", BAR_GOLD)
end

__f.w282 = { __f.b283, __f.d284, false, __f.d286 }

function __f.d279(self, parent)
	local __e280 = __el(parent, "box")
	__attr(__e280, "padding", BAR_PAD)
	local __e281 = __el(__e280, "box")
	__attr(__e281, "height", 13.333333333333334)
	__attr(__e281, "yAlign", "center")
	__when(__e281, __f.w282, self)
end

__f.w277 = { __f.b278, __f.d279 }

function __f.b292(self)
	return __get(self.locked)
end

function __f.d293(self, parent)
	local __e294 = __el(parent, "box")
	__attr(__e294, "position", "absolute")
	__attr(__e294, "right", 1.6666666666666667)
	__attr(__e294, "top", 1.6666666666666667)
	__attr(__e294, "width", 20)
	__attr(__e294, "height", 20)
	__attr(__e294, "background", CLOSE_ART)
	__on(__e294, "click", self, self.onClose)
end

__f.w291 = { __f.b292, __f.d293 }

function __f.d169(self, parent)
	local __e170 = __el(parent, "box")
	__attr(__e170, "width", "min")
	__bind(__e170, "minWidth", __f.b171, self)
	__attr(__e170, "padding", 10)
	__bind(__e170, "border", __f.b172, self)
	__bind(__e170, "background", __f.b173, self)
	__when(__e170, __f.w174, self)
	local __e182 = __el(__e170, "box")
	__bind(__e182, "columns", __f.b183, self)
	__attr(__e182, "gap", 8.333333333333334)
	__attr(__e182, "yAlign", "center")
	__bind(__e182, "padding", __f.b184, self)
	__when(__e182, __f.w185, self)
	local __e192 = __el(__e182, "box")
	__attr(__e192, "gap", 1.6666666666666667)
	__attr(__e192, "yAlign", "center")
	local __e193 = __el(__e192, "text")
	__bind(__e193, "value", __f.b194, self)
	__bind(__e193, "textColor", __f.b195, self)
	__attr(__e193, "textSize", 15)
	__attr(__e193, "wrap", false)
	__when(__e192, __f.w196, self)
	__when(__e192, __f.w208, self)
	__when(__e170, __f.w220, self)
	__when(__e170, __f.w232, self)
	__when(__e170, __f.w244, self)
	__when(__e170, __f.w255, self)
	__when(__e170, __f.w266, self)
	__when(__e170, __f.w277, self)
	__when(__e170, __f.w291, self)
end

PX = 0.8333333333333334
WIDTH = 261.6666666666667
SIDE_WIDTH = 220
ICON = 50
SECTION = 6.666666666666667
HEADING = { r = 1, g = 0.820, b = 0, a = 1 }
LABEL = { r = 0.796, g = 0.725, b = 0.580, a = 1 }
QUIET = { r = 0.522, g = 0.478, b = 0.400, a = 1 }
QUIET_VALUE = { r = 0.639, g = 0.596, b = 0.514, a = 1 }
BODY = { r = 0.953, g = 0.906, b = 0.800, a = 1 }
FREE = { r = 0.902, g = 0.863, b = 0.776, a = 1 }
BLACK = { r = 0, g = 0, b = 0, a = 1 }
RULE = { width = 0.8333333333333334, color = { r = 0.839, g = 0.647, b = 0.420, a = 0.180 }, sides = { "top" } }
DIVIDER = { width = 0.8333333333333334, color = { r = 0.839, g = 0.647, b = 0.420, a = 0.180 }, sides = { "left" } }
GROOVE = { width = 0.8333333333333334, color = { r = 0, g = 0, b = 0, a = 0.851 }, sides = { "top", "bottom" } }
RIM = { width = 0.8333333333333334, color = { r = 0.424, g = 0.333, b = 0.208, a = 1 } }
FILL = { { fr = 1 } }
WITH_ICON = { 50, { fr = 1 } }
ALONE = { { fr = 1 } }
NAME_VALUE = { { fr = 1 }, "auto" }
OWN_WIDTH = { "auto", { fr = 1 } }
SECTION_PAD = { top = 6.666666666666667, bottom = 6.666666666666667 }
BAR_PAD = { top = 6.666666666666667 }
BAR_ROW = 13.333333333333334
BAR_HEIGHT = 2.5
TRACK = { r = 0, g = 0, b = 0, a = 0.451 }
BAR_GOLD = { r = 0.839, g = 0.647, b = 0.420, a = 0.502 }
UNDERLINE = { r = 1, g = 0.820, b = 0, a = 0.702 }
BY_ITS_TEXT = { beside = "parent" }
CLOSE_ART = "Interface/Buttons/UI-Panel-MinimizeButton-Up"
UNDER_TITLE = { bottom = 6.666666666666667 }
NO_PAD = {}
CELL_PAD = { top = 6.666666666666667, right = 8.333333333333334, bottom = 6.666666666666667, left = 8.333333333333334 }
CELL_PAD_LAST = { top = 6.666666666666667, right = 8.333333333333334, left = 8.333333333333334 }
INDENT = { left = 10 }
SPACED = { top = 5 }

TermText = __class({})

function TermText.new(__owner, text, color, size, opens, locked)
	local self = setmetatable({}, TermText)
	R.adopt(__owner, self)
	self.text = text
	self.color = color
	self.size = size
	self.opens = opens
	self.locked = locked
	self.over = __cell(false)
	self.lit = __computed(self, __f.c1, self)
	self.open = __computed(self, __f.c2, self)
	__watch(self, self.forgetCursor, self)
	return self
end

function TermText:opensSomething()
	local opens = __get(self.opens)
	local __s3 = opens[1] or opens
	if __s3 == "None" then
		return false
	else
		return true
	end
end

function TermText:forgetCursor()
	if not __get(self.lit) then
		__set(self.over, false)
	end
end

function TermText:onEnter()
	__set(self.over, true)
end

function TermText:onLeave()
	__set(self.over, false)
end

function TermText:render()
	return __template(__f.d4, self)
end

PartText = __class({})

function PartText.new(__owner, part, index, color, locked)
	local self = setmetatable({}, PartText)
	R.adopt(__owner, self)
	if locked == nil then locked = __cell(false) end
	self.part = part
	self.index = index
	self.color = color
	self.locked = locked
	self.notFirst = __computed(self, __f.c23, self)
	self.own = __computed(self, __f.c24, self)
	return self
end

function PartText:render()
	return __template(__f.d25, self)
end

FactCell = __class({})

function FactCell.new(__owner, fact, index, last, locked)
	local self = setmetatable({}, FactCell)
	R.adopt(__owner, self)
	if locked == nil then locked = __cell(false) end
	self.fact = fact
	self.index = index
	self.last = last
	self.locked = locked
	self.over = __cell(false)
	self.lit = __computed(self, __f.c37, self)
	self.open = __computed(self, __f.c38, self)
	self.divider = __computed(self, __f.c39, self)
	self.padding = __computed(self, __f.c41, self)
	self.hasGlyph = __computed(self, __f.c43, self)
	self.glyph = __computed(self, __f.c44, self)
	self.tint = __computed(self, __f.c45, self)
	self.color = __computed(self, __f.c46, self)
	__watch(self, self.forgetCursor, self)
	return self
end

function FactCell:opensSomething()
	local opens = __getKey(self.fact, "opens")
	local __s47 = opens[1] or opens
	if __s47 == "None" then
		return false
	else
		return true
	end
end

function FactCell:forgetCursor()
	if not __get(self.lit) then
		__set(self.over, false)
	end
end

function FactCell:onEnter()
	__set(self.over, true)
end

function FactCell:onLeave()
	__set(self.over, false)
end

function FactCell:render()
	return __template(__f.d48, self)
end

Row = __class({})

function Row.new(__owner, line, locked)
	local self = setmetatable({}, Row)
	R.adopt(__owner, self)
	if locked == nil then locked = __cell(false) end
	self.line = line
	self.locked = locked
	self.paired = __computed(self, __f.c76, self)
	self.right = __computed(self, __f.c77, self)
	self.opening = __computed(self, __f.c78, self)
	return self
end

function Row:opensSomething()
	local opens = __getKey(self.line, "opens")
	local __s79 = opens[1] or opens
	if __s79 == "None" then
		return false
	else
		return true
	end
end

function Row:render()
	return __template(__f.d80, self)
end

TipFrame = __class({})

function TipFrame.new(__owner, model, side, main, charge, locked)
	local self = setmetatable({}, TipFrame)
	R.adopt(__owner, self)
	if side == nil then side = __cell(false) end
	if main == nil then main = __cell(false) end
	if charge == nil then charge = __cell(0) end
	if locked == nil then locked = __cell(false) end
	self.model = model
	self.side = side
	self.main = main
	self.charge = charge
	self.locked = locked
	self.width = __computed(self, __f.c129, self)
	self.hasHeader = __computed(self, __f.c131, self)
	self.header = __computed(self, __f.c132, self)
	self.hasIcon = __computed(self, __f.c133, self)
	self.icon = __computed(self, __f.c134, self)
	self.face = __computed(self, __f.c135, self)
	self.titleColumns = __computed(self, __f.c136, self)
	self.hasDesc = __computed(self, __f.c138, self)
	self.hasInfo = __computed(self, __f.c139, self)
	self.descColumns = __computed(self, __f.c140, self)
	self.infoColumns = __computed(self, __f.c141, self)
	self.facts = __computed(self, __f.c142, self)
	self.hasFacts = __computed(self, __f.c143, self)
	self.body = __computed(self, __f.c144, self)
	self.more = __computed(self, __f.c145, self)
	self.foot = __computed(self, __f.c146, self)
	self.keys = __computed(self, __f.c147, self)
	self.hasBody = __computed(self, __f.c148, self)
	self.hasMore = __computed(self, __f.c149, self)
	self.hasFoot = __computed(self, __f.c150, self)
	self.hasKeys = __computed(self, __f.c151, self)
	self.bandLast = __computed(self, __f.c152, self)
	self.titlePadding = __computed(self, __f.c153, self)
	self.bodyRule = __computed(self, __f.c155, self)
	self.track = __computed(self, __f.c157, self)
	self.filled = __computed(self, __f.c159, self)
	self.close = __event()
	return self
end

function TipFrame:onClose()
	__emit(self.close)
end

function TipFrame:pictured()
	local picture = __getKey(self.model, "picture")
	local __s160 = picture[1] or picture
	if __s160 == "None" then
		return false
	else
		return true
	end
end

function TipFrame:iconArt()
	local picture = __getKey(self.model, "picture")
	local __s161 = picture[1] or picture
	if __s161 == "Icon" then
		return picture.art
	else
		return nil
	end
end

function TipFrame:faceUnit()
	local picture = __getKey(self.model, "picture")
	local __s162 = picture[1] or picture
	if __s162 == "Face" then
		return picture.unit
	else
		return nil
	end
end

function TipFrame:tracks(pieces)
	local list = {}
	for i = 1, pieces do
		if i > 1 then
			__insert(list, "auto")
		end
		__insert(list, "auto")
	end
	__insert(list, { fr = 1 })
	return list
end

function TipFrame:rows(lines)
	local list = {}
	local pairedBefore = false
	for index = 1, #lines do
		local line = lines[index]
		local paired = line.right ~= nil
		local size = 11.666666666666668
		if line.indent ~= true and paired then
			size = 13.333333333333334
		elseif line.indent ~= true and line.desc == true then
			size = 12.5
		end
		local padding = NO_PAD
		if line.indent == true then
			padding = INDENT
		elseif index > 1 and paired ~= pairedBefore then
			padding = SPACED
		end
		local __t163
		if paired or line.desc == true then
			__t163 = BODY
		else
			__t163 = FREE
		end
		local plain = __t163
		__insert(list, { left = line.left, right = line.right, leftColor = line.color or plain, rightColor = line.rightColor or line.color or BODY, size = size, padding = padding, opens = line.opens })
		pairedBefore = paired
	end
	return list
end

function TipFrame:notes()
	local list = {}
	local __l165 = __getKey(self.model, "foot")
	for __i164 = 1, #__l165 do
		local note = __l165[__i164]
		local alone = note.right == nil
		local __t166
		if alone then
			__t166 = note.valueColor or QUIET
		else
			__t166 = QUIET
		end
		__insert(list, { left = note.left, right = note.right, leftColor = __t166, rightColor = note.valueColor or QUIET_VALUE, size = 11.666666666666668, padding = NO_PAD, opens = note.opens })
	end
	return list
end

function TipFrame:hotkeys()
	local list = {}
	local __l168 = __getKey(self.model, "keys")
	for __i167 = 1, #__l168 do
		local key = __l168[__i167]
		__insert(list, { left = key, right = nil, leftColor = QUIET, rightColor = QUIET, size = 11.666666666666668, padding = NO_PAD, opens = "None" })
	end
	return list
end

function TipFrame:render()
	return __template(__f.d169, self)
end
__inherit(TermText, { __Ordaen_module_Component })
__inherit(PartText, { __Ordaen_module_Component })
__inherit(FactCell, { __Ordaen_module_Component })
__inherit(Row, { __Ordaen_module_Component })
__inherit(TipFrame, { __Ordaen_module_Component })

M.PX = PX
M.WIDTH = WIDTH
M.SIDE_WIDTH = SIDE_WIDTH
M.ICON = ICON
M.SECTION = SECTION
M.HEADING = HEADING
M.LABEL = LABEL
M.QUIET = QUIET
M.QUIET_VALUE = QUIET_VALUE
M.BODY = BODY
M.FREE = FREE
M.BLACK = BLACK
M.RULE = RULE
M.DIVIDER = DIVIDER
M.GROOVE = GROOVE
M.RIM = RIM
M.FILL = FILL
M.WITH_ICON = WITH_ICON
M.ALONE = ALONE
M.NAME_VALUE = NAME_VALUE
M.OWN_WIDTH = OWN_WIDTH
M.SECTION_PAD = SECTION_PAD
M.BAR_PAD = BAR_PAD
M.BAR_ROW = BAR_ROW
M.BAR_HEIGHT = BAR_HEIGHT
M.TRACK = TRACK
M.BAR_GOLD = BAR_GOLD
M.UNDERLINE = UNDERLINE
M.BY_ITS_TEXT = BY_ITS_TEXT
M.CLOSE_ART = CLOSE_ART
M.UNDER_TITLE = UNDER_TITLE
M.NO_PAD = NO_PAD
M.CELL_PAD = CELL_PAD
M.CELL_PAD_LAST = CELL_PAD_LAST
M.INDENT = INDENT
M.SPACED = SPACED
M.TermText = TermText
M.PartText = PartText
M.FactCell = FactCell
M.Row = Row
M.TipFrame = TipFrame
