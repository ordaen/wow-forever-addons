-- Made by lunatype from OrdaenPanel/items.luna: change the source, not this file.
local R = LunaType
local __get, __cell, __computed, __class, __inherit, __el, __attr, __bind, __template, __draw, __when = R.get, R.cell, R.computed, R.class, R.inherit, R.el, R.attr, R.bind, R.template, R.draw, R.when
local __OrdaenPanel_cells_FaceCell = R.addon("OrdaenPanel")["cells"].FaceCell
local __OrdaenPanel_cells_MenuCell = R.addon("OrdaenPanel")["cells"].MenuCell
local __game__Frames_ProfessionMicroButton = R.game.Frames.ProfessionMicroButton
local __game__Frames_SpellbookMicroButton = R.game.Frames.SpellbookMicroButton
local __game__Frames_TalentMicroButton = R.game.Frames.TalentMicroButton
local __game__Frames_LegacyMicroButton = R.game.Frames.LegacyMicroButton
local __game__Frames_QuestLogMicroButton = R.game.Frames.QuestLogMicroButton
local __game__Frames_LFDMicroButton = R.game.Frames.LFDMicroButton
local __game__Frames_CollectionsMicroButton = R.game.Frames.CollectionsMicroButton
local __game__Frames_MainMenuMicroButton = R.game.Frames.MainMenuMicroButton
local __game__Frames_QuickJoinToastButton = R.game.Frames.QuickJoinToastButton
local __game__Friends_online = R.game.Friends.online
local __game__Frames_GuildMicroButton = R.game.Frames.GuildMicroButton
local __game__Money_format = R.game.Money.format
local __game__Money_amount = R.game.Money.amount
local __game__Money_tracked = R.game.Money.tracked
local __OrdaenPanel_cells_BagCell = R.addon("OrdaenPanel")["cells"].BagCell
local __game__Frames_MainMenuBarBackpackButton = R.game.Frames.MainMenuBarBackpackButton
local __game__Bags_free = R.game.Bags.free
local __game__Frames_CharacterBag0Slot = R.game.Frames.CharacterBag0Slot
local __game__Frames_CharacterBag1Slot = R.game.Frames.CharacterBag1Slot
local __game__Frames_CharacterBag2Slot = R.game.Frames.CharacterBag2Slot
local __game__Frames_CharacterBag3Slot = R.game.Frames.CharacterBag3Slot
local __Ordaen_module_Component = R.addon("Ordaen")["module"].Component
local M = {}
R.addon("OrdaenPanel")["items"] = M
local INK, TEXT, DOWN, MICRO, MICRO_FACED, PAIR, BAGS, MicroLine, SocialLine, MoneyLine, BagLine

local function __c1(self)
	local __t2
	if __get(self.vertical) then
		__t2 = DOWN
	else
		local __t3
		if __get(self.faced) then
			__t3 = MICRO_FACED
		else
			__t3 = MICRO
		end
		__t2 = __t3
	end
	return __t2
end

local function __b6(self)
	return __get(self.columns)
end

local function __b8(self)
	return __get(self.faced)
end

local function __d9(self, parent)
	local __c10 = __OrdaenPanel_cells_FaceCell.new(parent)
	__draw(parent, __c10, nil)
end

local __w7 = { __b8, __d9 }

local function __d4(self, parent)
	local __e5 = __el(parent, "box")
	__bind(__e5, "columns", __b6, self)
	__when(__e5, __w7, self)
	local __c11 = __OrdaenPanel_cells_MenuCell.new(__e5, "assets/micro-professions.tga", __game__Frames_ProfessionMicroButton, self.gold, nil)
	__draw(__e5, __c11, nil)
	local __c12 = __OrdaenPanel_cells_MenuCell.new(__e5, "assets/micro-spellbookabilities.tga", __game__Frames_SpellbookMicroButton, self.gold, nil)
	__draw(__e5, __c12, nil)
	local __c13 = __OrdaenPanel_cells_MenuCell.new(__e5, "assets/micro-spectalents.tga", __game__Frames_TalentMicroButton, self.gold, nil)
	__draw(__e5, __c13, nil)
	local __c14 = __OrdaenPanel_cells_MenuCell.new(__e5, "assets/micro-legacy.tga", __game__Frames_LegacyMicroButton, self.gold, nil)
	__draw(__e5, __c14, nil)
	local __c15 = __OrdaenPanel_cells_MenuCell.new(__e5, "assets/micro-questlog.tga", __game__Frames_QuestLogMicroButton, self.gold, nil)
	__draw(__e5, __c15, nil)
	local __c16 = __OrdaenPanel_cells_MenuCell.new(__e5, "assets/micro-groupfinder.tga", __game__Frames_LFDMicroButton, self.gold, nil)
	__draw(__e5, __c16, nil)
	local __c17 = __OrdaenPanel_cells_MenuCell.new(__e5, "assets/micro-collections.tga", __game__Frames_CollectionsMicroButton, self.gold, nil)
	__draw(__e5, __c17, nil)
	local __c18 = __OrdaenPanel_cells_MenuCell.new(__e5, "assets/micro-gamemenu.tga", __game__Frames_MainMenuMicroButton, self.gold, nil)
	__draw(__e5, __c18, nil)
end

local function __c19(self)
	local __t20
	if __get(self.vertical) then
		__t20 = DOWN
	else
		__t20 = PAIR
	end
	return __t20
end

local function __b23(self)
	return __get(self.columns)
end

local function __d21(self, parent)
	local __e22 = __el(parent, "box")
	__bind(__e22, "columns", __b23, self)
	local __c24 = __OrdaenPanel_cells_MenuCell.new(__e22, "assets/micro-social.tga", __game__Frames_QuickJoinToastButton, self.gold, __game__Friends_online)
	__draw(__e22, __c24, nil)
	local __c25 = __OrdaenPanel_cells_MenuCell.new(__e22, "assets/micro-guildcommunities.tga", __game__Frames_GuildMicroButton, self.gold, nil)
	__draw(__e22, __c25, nil)
end

local function __c26(self)
	return __game__Money_format(__get(__game__Money_amount))
end

local function __c27(self)
	return __get(__game__Money_tracked) ~= ""
end

local function __c28(self)
	local __t29
	if __get(self.vertical) then
		__t29 = DOWN
	else
		__t29 = PAIR
	end
	return __t29
end

local function __c30(self)
	local __t31
	if __get(self.vertical) then
		__t31 = 3.3333333333333335
	else
		__t31 = 10
	end
	return __t31
end

local function __c32(self)
	local __t33
	if __get(self.vertical) then
		__t33 = "center"
	else
		__t33 = "stretch"
	end
	return __t33
end

local function __b36(self)
	return __get(self.columns)
end

local function __b37(self)
	return __get(self.gap)
end

local function __b38(self)
	return __get(self.across)
end

local function __b40(self)
	return __get(self.money)
end

local function __b41(self)
	return __get(self.outline)
end

local function __b42(self)
	return __get(self.shadow)
end

local function __b44(self)
	return __get(self.tracks)
end

local function __b47(self)
	return __get(__game__Money_tracked)
end

local function __b48(self)
	return __get(self.outline)
end

local function __b49(self)
	return __get(self.shadow)
end

local function __d45(self, parent)
	local __e46 = __el(parent, "text")
	__bind(__e46, "value", __b47, self)
	__attr(__e46, "textColor", INK)
	__attr(__e46, "textSize", 12)
	__bind(__e46, "textOutline", __b48, self)
	__bind(__e46, "textShadow", __b49, self)
	__attr(__e46, "wrap", false)
end

local __w43 = { __b44, __d45 }

local function __d34(self, parent)
	local __e35 = __el(parent, "box")
	__bind(__e35, "columns", __b36, self)
	__bind(__e35, "gap", __b37, self)
	__bind(__e35, "xAlign", __b38, self)
	__attr(__e35, "yAlign", "center")
	local __e39 = __el(__e35, "text")
	__bind(__e39, "value", __b40, self)
	__attr(__e39, "textColor", INK)
	__attr(__e39, "textSize", 12)
	__bind(__e39, "textOutline", __b41, self)
	__bind(__e39, "textShadow", __b42, self)
	__attr(__e39, "wrap", false)
	__when(__e35, __w43, self)
end

local function __c50(self)
	local __t51
	if __get(self.vertical) then
		__t51 = DOWN
	else
		__t51 = BAGS
	end
	return __t51
end

local function __b54(self)
	return __get(self.columns)
end

local function __d52(self, parent)
	local __e53 = __el(parent, "box")
	__bind(__e53, "columns", __b54, self)
	local __c55 = __OrdaenPanel_cells_BagCell.new(__e53, __game__Frames_MainMenuBarBackpackButton, __game__Bags_free)
	__draw(__e53, __c55, nil)
	local __c56 = __OrdaenPanel_cells_BagCell.new(__e53, __game__Frames_CharacterBag0Slot, nil)
	__draw(__e53, __c56, nil)
	local __c57 = __OrdaenPanel_cells_BagCell.new(__e53, __game__Frames_CharacterBag1Slot, nil)
	__draw(__e53, __c57, nil)
	local __c58 = __OrdaenPanel_cells_BagCell.new(__e53, __game__Frames_CharacterBag2Slot, nil)
	__draw(__e53, __c58, nil)
	local __c59 = __OrdaenPanel_cells_BagCell.new(__e53, __game__Frames_CharacterBag3Slot, nil)
	__draw(__e53, __c59, nil)
end

INK = { r = 0.910, g = 0.863, b = 0.769, a = 1 }
TEXT = 12
DOWN = { "auto" }
MICRO = { "auto", "auto", "auto", "auto", "auto", "auto", "auto", "auto" }
MICRO_FACED = { "auto", "auto", "auto", "auto", "auto", "auto", "auto", "auto", "auto" }
PAIR = { "auto", "auto" }
BAGS = { "auto", "auto", "auto", "auto", "auto" }

MicroLine = __class({})

function MicroLine.new(__owner, gold, vertical, faced)
	local self = setmetatable({}, MicroLine)
	R.adopt(__owner, self)
	if vertical == nil then vertical = __cell(false) end
	if faced == nil then faced = __cell(true) end
	self.gold = gold
	self.vertical = vertical
	self.faced = faced
	self.columns = __computed(self, __c1, self)
	return self
end

function MicroLine:render()
	return __template(__d4, self)
end

SocialLine = __class({})

function SocialLine.new(__owner, gold, vertical)
	local self = setmetatable({}, SocialLine)
	R.adopt(__owner, self)
	if vertical == nil then vertical = __cell(false) end
	self.gold = gold
	self.vertical = vertical
	self.columns = __computed(self, __c19, self)
	return self
end

function SocialLine:render()
	return __template(__d21, self)
end

MoneyLine = __class({})

function MoneyLine.new(__owner, outline, shadow, vertical)
	local self = setmetatable({}, MoneyLine)
	R.adopt(__owner, self)
	if vertical == nil then vertical = __cell(false) end
	self.outline = outline
	self.shadow = shadow
	self.vertical = vertical
	self.money = __computed(self, __c26, self)
	self.tracks = __computed(self, __c27, self)
	self.columns = __computed(self, __c28, self)
	self.gap = __computed(self, __c30, self)
	self.across = __computed(self, __c32, self)
	return self
end

function MoneyLine:render()
	return __template(__d34, self)
end

BagLine = __class({})

function BagLine.new(__owner, vertical)
	local self = setmetatable({}, BagLine)
	R.adopt(__owner, self)
	if vertical == nil then vertical = __cell(false) end
	self.vertical = vertical
	self.columns = __computed(self, __c50, self)
	return self
end

function BagLine:render()
	return __template(__d52, self)
end
__inherit(MicroLine, { __Ordaen_module_Component })
__inherit(SocialLine, { __Ordaen_module_Component })
__inherit(MoneyLine, { __Ordaen_module_Component })
__inherit(BagLine, { __Ordaen_module_Component })

M.INK = INK
M.TEXT = TEXT
M.DOWN = DOWN
M.MICRO = MICRO
M.MICRO_FACED = MICRO_FACED
M.PAIR = PAIR
M.BAGS = BAGS
M.MicroLine = MicroLine
M.SocialLine = SocialLine
M.MoneyLine = MoneyLine
M.BagLine = BagLine
