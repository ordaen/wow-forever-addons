-- Made by lunatype from OrdaenProfessions/skillBar.luna: change the source, not this file.
local R = LunaType
local __get, __getKey, __computed, __class, __inherit, __el, __attr, __bind, __template, __each = R.get, R.getKey, R.computed, R.class, R.inherit, R.el, R.attr, R.bind, R.template, R.each
local __math_min = R.math.min
local __OrdaenProfessions_locales_RANK_75 = R.addon("OrdaenProfessions")["locales"].RANK_75
local __OrdaenProfessions_locales_RANK_150 = R.addon("OrdaenProfessions")["locales"].RANK_150
local __OrdaenProfessions_locales_RANK_225 = R.addon("OrdaenProfessions")["locales"].RANK_225
local __OrdaenProfessions_locales_RANK_300 = R.addon("OrdaenProfessions")["locales"].RANK_300
local __string_format = R.string.format
local __Ordaen_core = R.addon("Ordaen")["core"]
local __OrdaenProfessions_style_WHITE = R.addon("OrdaenProfessions")["style"].WHITE
local __OrdaenProfessions_style_SHADOW = R.addon("OrdaenProfessions")["style"].SHADOW
local __Ordaen_module_Component = R.addon("Ordaen")["module"].Component
local M = {}
R.addon("OrdaenProfessions")["skillBar"] = M
local HEIGHT, RIM, PADDING, TROUGH, RIM_COLOR, CELLS, NOTCH, FILL, SkillBar

local function __c1(self)
	return { percent = self:shareOf() * 100 }
end

local function __c2(self)
	return self:labelOf()
end

local function __b7(self)
	return __get(self.share)
end

local function __b8(self)
	return __getKey(__Ordaen_core.theme, "panel").xpFill
end

local function __b10(self)
	return CELLS
end

local function __d11(self, parent, cell)
	local __e12 = __el(parent, "box")
	__attr(__e12, "border", NOTCH)
end

local function __b16(self)
	return __get(self.label)
end

local function __b17(self)
	return __getKey(__Ordaen_core.theme, "font").numbers
end

local function __d3(self, parent)
	local __e4 = __el(parent, "box")
	__attr(__e4, "height", 25)
	__attr(__e4, "padding", PADDING)
	__attr(__e4, "background", RIM_COLOR)
	__attr(__e4, "rows", FILL)
	local __e5 = __el(__e4, "box")
	__attr(__e5, "background", TROUGH)
	__attr(__e5, "overflow", "hidden")
	local __e6 = __el(__e5, "box")
	__attr(__e6, "position", "absolute")
	__attr(__e6, "left", 0)
	__attr(__e6, "top", 0)
	__attr(__e6, "bottom", 0)
	__bind(__e6, "width", __b7, self)
	__bind(__e6, "background", __b8, self)
	local __e9 = __el(__e5, "box")
	__attr(__e9, "position", "absolute")
	__attr(__e9, "left", 0)
	__attr(__e9, "right", 0)
	__attr(__e9, "top", 0)
	__attr(__e9, "bottom", 0)
	__attr(__e9, "columns", 10)
	__attr(__e9, "rows", FILL)
	__each(__e9, __b10, nil, __d11, 1, 0, false, self)
	local __e13 = __el(__e9, "box")
	local __e14 = __el(__e5, "box")
	__attr(__e14, "position", "absolute")
	__attr(__e14, "left", 0)
	__attr(__e14, "right", 0)
	__attr(__e14, "top", 0)
	__attr(__e14, "bottom", 0)
	__attr(__e14, "xAlign", "center")
	__attr(__e14, "yAlign", "center")
	local __e15 = __el(__e14, "text")
	__bind(__e15, "value", __b16, self)
	__attr(__e15, "textSize", 11.666666666666668)
	__attr(__e15, "textColor", __OrdaenProfessions_style_WHITE)
	__attr(__e15, "textShadow", __OrdaenProfessions_style_SHADOW)
	__bind(__e15, "textFamily", __b17, self)
	__attr(__e15, "wrap", false)
end

HEIGHT = 25
RIM = 2.5
PADDING = { right = 2.5, bottom = 2.5, left = 2.5 }
TROUGH = { r = 0.043, g = 0.031, b = 0.020, a = 1 }
RIM_COLOR = { r = 0.239, g = 0.153, b = 0.063, a = 1 }
CELLS = { 1, 2, 3, 4, 5, 6, 7, 8, 9 }
NOTCH = { width = 0.8333333333333334, color = { r = 0, g = 0, b = 0, a = 0.749 }, sides = { "right" } }
FILL = { { fr = 1 } }

SkillBar = __class({})

function SkillBar.new(__owner, profession)
	local self = setmetatable({}, SkillBar)
	R.adopt(__owner, self)
	self.profession = profession
	self.share = __computed(self, __c1, self)
	self.label = __computed(self, __c2, self)
	return self
end

function SkillBar:shareOf()
	local profession = __get(self.profession)
	if profession == nil or profession.max <= 0 then
		return 0
	end
	return __math_min(1, profession.rank / profession.max)
end

function SkillBar:rankOf(most)
	if most == 75 then
		return __OrdaenProfessions_locales_RANK_75
	elseif most == 150 then
		return __OrdaenProfessions_locales_RANK_150
	elseif most == 225 then
		return __OrdaenProfessions_locales_RANK_225
	elseif most == 300 then
		return __OrdaenProfessions_locales_RANK_300
	else
		return ""
	end
end

function SkillBar:labelOf()
	local profession = __get(self.profession)
	if profession == nil then
		return ""
	end
	local skill = __string_format("%d / %d", profession.rank, profession.max)
	local rank = self:rankOf(profession.max)
	if rank == "" then
		return skill
	end
	return rank .. " · " .. skill
end

function SkillBar:render()
	return __template(__d3, self)
end
__inherit(SkillBar, { __Ordaen_module_Component })

M.HEIGHT = HEIGHT
M.RIM = RIM
M.PADDING = PADDING
M.TROUGH = TROUGH
M.RIM_COLOR = RIM_COLOR
M.CELLS = CELLS
M.NOTCH = NOTCH
M.FILL = FILL
M.SkillBar = SkillBar
