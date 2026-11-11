-- Made by lunatype from OrdaenProfessions/details.luna: change the source, not this file.
local R = LunaType
local __get, __getKey, __set, __cell, __computed, __event, __listen, __emit, __class, __inherit, __el, __attr, __bind, __template, __draw, __when, __each = R.get, R.getKey, R.set, R.cell, R.computed, R.event, R.listen, R.emit, R.class, R.inherit, R.el, R.attr, R.bind, R.template, R.draw, R.when, R.each
local __OrdaenProfessions_style_LINE = R.addon("OrdaenProfessions")["style"].LINE
local __OrdaenProfessions_style_difficultyColor = R.addon("OrdaenProfessions")["style"].difficultyColor
local __OrdaenProfessions_style_RED = R.addon("OrdaenProfessions")["style"].RED
local __game__TradeSkill_description = R.game.TradeSkill.description
local __game__TradeSkill_reagents = R.game.TradeSkill.reagents
local __OrdaenProfessions_locales_NOT_LEARNED = R.addon("OrdaenProfessions")["locales"].NOT_LEARNED
local __OrdaenProfessions_locales_DIFFICULTY_0 = R.addon("OrdaenProfessions")["locales"].DIFFICULTY_0
local __OrdaenProfessions_locales_DIFFICULTY_1 = R.addon("OrdaenProfessions")["locales"].DIFFICULTY_1
local __OrdaenProfessions_locales_DIFFICULTY_2 = R.addon("OrdaenProfessions")["locales"].DIFFICULTY_2
local __OrdaenProfessions_locales_DIFFICULTY_3 = R.addon("OrdaenProfessions")["locales"].DIFFICULTY_3
local __game__TradeSkill_requirements = R.game.TradeSkill.requirements
local __OrdaenProfessions_locales_TOOLS = R.addon("OrdaenProfessions")["locales"].TOOLS
local __math_max = R.math.max
local __math_min = R.math.min
local __Ordaen_core = R.addon("Ordaen")["core"]
local __OrdaenProfessions_style_BRONZE = R.addon("OrdaenProfessions")["style"].BRONZE
local __OrdaenProfessions_style_WHITE = R.addon("OrdaenProfessions")["style"].WHITE
local __OrdaenProfessions_style_SHADOW = R.addon("OrdaenProfessions")["style"].SHADOW
local __OrdaenProfessions_style_INK = R.addon("OrdaenProfessions")["style"].INK
local __OrdaenProfessions_style_DIM = R.addon("OrdaenProfessions")["style"].DIM
local __OrdaenProfessions_rows_ReagentRow = R.addon("OrdaenProfessions")["rows"].ReagentRow
local __OrdaenLibrary_pushButton_PushButton = R.addon("OrdaenLibrary")["pushButton"].PushButton
local __OrdaenProfessions_locales_CREATE = R.addon("OrdaenProfessions")["locales"].CREATE
local __Ordaen_module_Component = R.addon("Ordaen")["module"].Component
local M = {}
R.addon("OrdaenProfessions")["details"] = M
local RIM, PANEL, SLOT, HEAD, MAKE, STEP, NOTHING, RecipeDetails

local function __c1(self)
	return __get(self.recipe) ~= nil
end

local function __c2(self)
	return __get(self.recipe) or NOTHING
end

local function __c3(self)
	return __getKey(self.shown, "icon")
end

local function __c4(self)
	return self:skillOf()
end

local function __c5(self)
	local __t6
	if __getKey(self.shown, "learned") then
		__t6 = __OrdaenProfessions_style_difficultyColor(__getKey(self.shown, "difficulty"))
	else
		__t6 = __OrdaenProfessions_style_RED
	end
	return __t6
end

local function __c7(self)
	return __game__TradeSkill_description(__getKey(self.shown, "id"))
end

local function __c8(self)
	return self:needsOf()
end

local function __c9(self)
	return __game__TradeSkill_reagents(__getKey(self.shown, "id"))
end

local function __c10(self)
	return __getKey(self.shown, "craftable") < 1
end

local function __b16(self)
	return __getKey(__Ordaen_core.theme, "window").marble
end

local function __b18(self)
	return __get(self.has)
end

local function __b22(self)
	return __get(self.icon)
end

local function __b25(self)
	return __getKey(self.shown, "name")
end

local function __b27(self)
	return __get(self.skill)
end

local function __b28(self)
	return __get(self.skillColor)
end

local function __b30(self)
	return __get(self.description)
end

local function __b32(self)
	return __get(self.needs)
end

local function __b34(self)
	return __get(self.reagents)
end

local function __d35(self, parent, index, reagent)
	local __c36 = __OrdaenProfessions_rows_ReagentRow.new(parent, reagent, __cell(index))
	__draw(parent, __c36, nil)
end

local function __b40(self)
	return { __get(self.count) }
end

local function __b41(self)
	return __getKey(__Ordaen_core.theme, "font").numbers
end

local function __d19(self, parent)
	local __e20 = __el(parent, "box")
	__attr(__e20, "columns", HEAD)
	__attr(__e20, "gap", 8.333333333333334)
	__attr(__e20, "yAlign", "center")
	local __e21 = __el(__e20, "box")
	__attr(__e21, "width", 43.333333333333336)
	__attr(__e21, "height", 43.333333333333336)
	__attr(__e21, "border", __OrdaenProfessions_style_BRONZE)
	__bind(__e21, "background", __b22, self)
	local __e23 = __el(__e20, "box")
	__attr(__e23, "gap", 1.6666666666666667)
	local __e24 = __el(__e23, "text")
	__bind(__e24, "value", __b25, self)
	__attr(__e24, "textSize", 14.166666666666668)
	__attr(__e24, "textColor", __OrdaenProfessions_style_WHITE)
	__attr(__e24, "textShadow", __OrdaenProfessions_style_SHADOW)
	local __e26 = __el(__e23, "text")
	__bind(__e26, "value", __b27, self)
	__attr(__e26, "textSize", 10)
	__bind(__e26, "textColor", __b28, self)
	local __e29 = __el(parent, "text")
	__bind(__e29, "value", __b30, self)
	__attr(__e29, "textSize", 10.833333333333334)
	__attr(__e29, "textColor", __OrdaenProfessions_style_INK)
	local __e31 = __el(parent, "text")
	__bind(__e31, "value", __b32, self)
	__attr(__e31, "textSize", 10.833333333333334)
	__attr(__e31, "textColor", __OrdaenProfessions_style_DIM)
	local __e33 = __el(parent, "box")
	__attr(__e33, "overflow", "scroll")
	__each(__e33, __b34, nil, __d35, 2, 1, true, self)
	local __e37 = __el(parent, "box")
	__attr(__e37, "columns", MAKE)
	__attr(__e37, "gap", 6.666666666666667)
	__attr(__e37, "yAlign", "center")
	local __c38 = __OrdaenLibrary_pushButton_PushButton.new(__e37, __cell("−"), __cell(25), nil, nil)
	__listen(__c38.click, self, self.less)
	__draw(__e37, __c38, nil)
	local __e39 = __el(__e37, "text")
	__attr(__e39, "value", "%d")
	__bind(__e39, "arguments", __b40, self)
	__attr(__e39, "textSize", 11.666666666666668)
	__attr(__e39, "textColor", __OrdaenProfessions_style_WHITE)
	__bind(__e39, "textFamily", __b41, self)
	__attr(__e39, "wrap", false)
	local __c42 = __OrdaenLibrary_pushButton_PushButton.new(__e37, __cell("+"), __cell(25), nil, nil)
	__listen(__c42.click, self, self.more)
	__draw(__e37, __c42, nil)
	local __e43 = __el(__e37, "box")
	__attr(__e43, "height", 1)
	local __c44 = __OrdaenLibrary_pushButton_PushButton.new(__e37, __cell(__OrdaenProfessions_locales_CREATE), __cell(116.66666666666667), nil, self.cannot)
	__listen(__c44.click, self, self.onCreate)
	__draw(__e37, __c44, nil)
end

local __w17 = { __b18, __d19 }

local function __d14(self, parent)
	local __e15 = __el(parent, "box")
	__attr(__e15, "rows", PANEL)
	__attr(__e15, "gap", 6.666666666666667)
	__attr(__e15, "padding", 10)
	__attr(__e15, "border", RIM)
	__bind(__e15, "background", __b16, self)
	__attr(__e15, "overflow", "hidden")
	__when(__e15, __w17, self)
end

RIM = { width = 0.8333333333333334, color = __OrdaenProfessions_style_LINE }
PANEL = { "auto", "auto", "auto", { fr = 1 }, "auto" }
SLOT = 43.333333333333336
HEAD = { 43.333333333333336, { fr = 1 } }
MAKE = { "auto", "auto", "auto", { fr = 1 }, "auto" }
STEP = 25
NOTHING = { id = 0, name = "", icon = "", categoryID = 0, learned = false, difficulty = 3, craftable = 0 }

RecipeDetails = __class({})

function RecipeDetails.new(__owner, recipe, count)
	local self = setmetatable({}, RecipeDetails)
	R.adopt(__owner, self)
	self.recipe = recipe
	self.count = count
	self.create = __event()
	self.has = __computed(self, __c1, self)
	self.shown = __computed(self, __c2, self)
	self.icon = __computed(self, __c3, self)
	self.skill = __computed(self, __c4, self)
	self.skillColor = __computed(self, __c5, self)
	self.description = __computed(self, __c7, self)
	self.needs = __computed(self, __c8, self)
	self.reagents = __computed(self, __c9, self)
	self.cannot = __computed(self, __c10, self)
	return self
end

function RecipeDetails:skillOf()
	if not __getKey(self.shown, "learned") then
		return __OrdaenProfessions_locales_NOT_LEARNED
	end
	local __s11 = __getKey(self.shown, "difficulty")
	if __s11 == 0 then
		return __OrdaenProfessions_locales_DIFFICULTY_0
	elseif __s11 == 1 then
		return __OrdaenProfessions_locales_DIFFICULTY_1
	elseif __s11 == 2 then
		return __OrdaenProfessions_locales_DIFFICULTY_2
	elseif __s11 == 3 then
		return __OrdaenProfessions_locales_DIFFICULTY_3
	end
end

function RecipeDetails:needsOf()
	local text = ""
	local __l13 = __game__TradeSkill_requirements(__getKey(self.shown, "id"))
	for __i12 = 1, #__l13 do
		local need = __l13[__i12]
		local line = __OrdaenProfessions_locales_TOOLS .. ": " .. need.name
		if not need.met then
			line = "|cffff4040" .. line .. "|r"
		end
		if text ~= "" then
			text = text .. "\n"
		end
		text = text .. line
	end
	return text
end

function RecipeDetails:less()
	__set(self.count, __math_max(1, __get(self.count) - 1))
end

function RecipeDetails:more()
	__set(self.count, __get(self.count) + 1)
end

function RecipeDetails:onCreate()
	if __getKey(self.shown, "craftable") > 0 then
		__emit(self.create, __math_min(__get(self.count), __getKey(self.shown, "craftable")))
	end
end

function RecipeDetails:render()
	return __template(__d14, self)
end
__inherit(RecipeDetails, { __Ordaen_module_Component })

M.RIM = RIM
M.PANEL = PANEL
M.SLOT = SLOT
M.HEAD = HEAD
M.MAKE = MAKE
M.STEP = STEP
M.NOTHING = NOTHING
M.RecipeDetails = RecipeDetails
