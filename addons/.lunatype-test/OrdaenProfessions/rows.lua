-- Made by lunatype from OrdaenProfessions/rows.luna: change the source, not this file.
local R = LunaType
local __get, __getKey, __computed, __event, __emit, __class, __inherit, __el, __attr, __bind, __on, __template, __when = R.get, R.getKey, R.computed, R.event, R.emit, R.class, R.inherit, R.el, R.attr, R.bind, R.on, R.template, R.when
local __OrdaenProfessions_style_ROW_CHOSEN = R.addon("OrdaenProfessions")["style"].ROW_CHOSEN
local __OrdaenProfessions_style_ROW_LIGHT = R.addon("OrdaenProfessions")["style"].ROW_LIGHT
local __OrdaenProfessions_style_ROW_RULE = R.addon("OrdaenProfessions")["style"].ROW_RULE
local __OrdaenProfessions_style_WHITE = R.addon("OrdaenProfessions")["style"].WHITE
local __OrdaenProfessions_style_DIM = R.addon("OrdaenProfessions")["style"].DIM
local __game__TradeSkill_recipes = R.game.TradeSkill.recipes
local __OrdaenProfessions_style_CHOSEN_EDGE = R.addon("OrdaenProfessions")["style"].CHOSEN_EDGE
local __OrdaenProfessions_style_GOLD = R.addon("OrdaenProfessions")["style"].GOLD
local __OrdaenProfessions_style_SHADOW = R.addon("OrdaenProfessions")["style"].SHADOW
local __Ordaen_core = R.addon("Ordaen")["core"]
local __OrdaenProfessions_style_difficultyColor = R.addon("OrdaenProfessions")["style"].difficultyColor
local __OrdaenProfessions_style_OFF = R.addon("OrdaenProfessions")["style"].OFF
local __string_format = R.string.format
local __OrdaenProfessions_style_RED = R.addon("OrdaenProfessions")["style"].RED
local __OrdaenProfessions_style_INK = R.addon("OrdaenProfessions")["style"].INK
local __OrdaenProfessions_style_BRONZE = R.addon("OrdaenProfessions")["style"].BRONZE
local __Ordaen_module_Component = R.addon("Ordaen")["module"].Component
local M = {}
R.addon("OrdaenProfessions")["rows"] = M
local NAME_COUNT, CATEGORY_PAD, RECIPE_PAD, SLOT, REAGENT, REAGENT_PAD, CategoryRow, RecipeRow, ReagentRow

local __f = {}

function __f.c1(self)
	return __get(self.chosen) == __getKey(self.category, "id")
end

function __f.c2(self)
	local __t3
	if __get(self.isChosen) then
		__t3 = __OrdaenProfessions_style_ROW_CHOSEN
	else
		__t3 = __OrdaenProfessions_style_ROW_LIGHT
	end
	return __t3
end

function __f.c4(self)
	local __t5
	if __get(self.index) > 1 then
		__t5 = __OrdaenProfessions_style_ROW_RULE
	else
		__t5 = nil
	end
	return __t5
end

function __f.c6(self)
	return self:count(false)
end

function __f.c7(self)
	return self:count(true)
end

function __f.c8(self)
	local __t9
	if __get(self.makeable) > 0 then
		__t9 = __OrdaenProfessions_style_WHITE
	else
		__t9 = __OrdaenProfessions_style_DIM
	end
	return __t9
end

function __f.b14(self)
	return __get(self.rule)
end

function __f.b15(self)
	return __get(self.background)
end

function __f.b17(self)
	return __get(self.isChosen)
end

function __f.d18(self, parent)
	local __e19 = __el(parent, "box")
	__attr(__e19, "position", "absolute")
	__attr(__e19, "left", 0)
	__attr(__e19, "top", 0)
	__attr(__e19, "bottom", 0)
	__attr(__e19, "width", 1.6666666666666667)
	__attr(__e19, "background", __OrdaenProfessions_style_CHOSEN_EDGE)
end

__f.w16 = { __f.b17, __f.d18 }

function __f.b21(self)
	return __getKey(self.category, "name")
end

function __f.b24(self)
	return { __get(self.total) }
end

function __f.b25(self)
	return __getKey(__Ordaen_core.theme, "font").numbers
end

function __f.b27(self)
	return { __get(self.makeable) }
end

function __f.b28(self)
	return __get(self.makeableColor)
end

function __f.b29(self)
	return __getKey(__Ordaen_core.theme, "font").numbers
end

function __f.d12(self, parent)
	local __e13 = __el(parent, "box")
	__attr(__e13, "columns", NAME_COUNT)
	__attr(__e13, "gap", 6.666666666666667)
	__attr(__e13, "padding", CATEGORY_PAD)
	__attr(__e13, "yAlign", "center")
	__bind(__e13, "border", __f.b14, self)
	__bind(__e13, "background", __f.b15, self)
	__on(__e13, "click", self, self.onClick)
	__when(__e13, __f.w16, self)
	local __e20 = __el(__e13, "text")
	__bind(__e20, "value", __f.b21, self)
	__attr(__e20, "textSize", 11.666666666666668)
	__attr(__e20, "textColor", __OrdaenProfessions_style_GOLD)
	__attr(__e20, "textShadow", __OrdaenProfessions_style_SHADOW)
	local __e22 = __el(__e13, "box")
	__attr(__e22, "columns", { "auto", "auto" })
	__attr(__e22, "gap", 2.5)
	__attr(__e22, "yAlign", "center")
	local __e23 = __el(__e22, "text")
	__attr(__e23, "value", "%d")
	__bind(__e23, "arguments", __f.b24, self)
	__attr(__e23, "textSize", 10)
	__attr(__e23, "textColor", __OrdaenProfessions_style_DIM)
	__attr(__e23, "wrap", false)
	__bind(__e23, "textFamily", __f.b25, self)
	local __e26 = __el(__e22, "text")
	__attr(__e26, "value", "(%d)")
	__bind(__e26, "arguments", __f.b27, self)
	__attr(__e26, "textSize", 10)
	__bind(__e26, "textColor", __f.b28, self)
	__attr(__e26, "wrap", false)
	__bind(__e26, "textFamily", __f.b29, self)
end

function __f.c30(self)
	return __get(self.chosen) == __getKey(self.recipe, "id")
end

function __f.c31(self)
	local __t32
	if __get(self.isChosen) then
		__t32 = __OrdaenProfessions_style_ROW_CHOSEN
	else
		__t32 = __OrdaenProfessions_style_ROW_LIGHT
	end
	return __t32
end

function __f.c33(self)
	local __t34
	if __get(self.index) > 1 then
		__t34 = __OrdaenProfessions_style_ROW_RULE
	else
		__t34 = nil
	end
	return __t34
end

function __f.c35(self)
	local __t36
	if __getKey(self.recipe, "learned") then
		__t36 = __OrdaenProfessions_style_difficultyColor(__getKey(self.recipe, "difficulty"))
	else
		__t36 = __OrdaenProfessions_style_OFF
	end
	return __t36
end

function __f.c37(self)
	local __t38
	if __getKey(self.recipe, "craftable") > 0 then
		__t38 = __string_format("[%d]", __getKey(self.recipe, "craftable"))
	else
		__t38 = ""
	end
	return __t38
end

function __f.b41(self)
	return __get(self.rule)
end

function __f.b42(self)
	return __get(self.background)
end

function __f.b44(self)
	return __get(self.isChosen)
end

function __f.d45(self, parent)
	local __e46 = __el(parent, "box")
	__attr(__e46, "position", "absolute")
	__attr(__e46, "left", 0)
	__attr(__e46, "top", 0)
	__attr(__e46, "bottom", 0)
	__attr(__e46, "width", 1.6666666666666667)
	__attr(__e46, "background", __OrdaenProfessions_style_CHOSEN_EDGE)
end

__f.w43 = { __f.b44, __f.d45 }

function __f.b48(self)
	return __getKey(self.recipe, "name")
end

function __f.b49(self)
	return __get(self.color)
end

function __f.b51(self)
	return __get(self.count)
end

function __f.b52(self)
	return __getKey(__Ordaen_core.theme, "font").numbers
end

function __f.d39(self, parent)
	local __e40 = __el(parent, "box")
	__attr(__e40, "columns", NAME_COUNT)
	__attr(__e40, "gap", 6.666666666666667)
	__attr(__e40, "padding", RECIPE_PAD)
	__attr(__e40, "yAlign", "center")
	__bind(__e40, "border", __f.b41, self)
	__bind(__e40, "background", __f.b42, self)
	__attr(__e40, "overflow", "hidden")
	__on(__e40, "click", self, self.onClick)
	__when(__e40, __f.w43, self)
	local __e47 = __el(__e40, "text")
	__bind(__e47, "value", __f.b48, self)
	__attr(__e47, "textSize", 10.833333333333334)
	__bind(__e47, "textColor", __f.b49, self)
	__attr(__e47, "textShadow", __OrdaenProfessions_style_SHADOW)
	__attr(__e47, "wrap", false)
	local __e50 = __el(__e40, "text")
	__bind(__e50, "value", __f.b51, self)
	__attr(__e50, "textSize", 10)
	__attr(__e50, "textColor", __OrdaenProfessions_style_WHITE)
	__attr(__e50, "wrap", false)
	__bind(__e50, "textFamily", __f.b52, self)
end

function __f.c53(self)
	local __t54
	if __get(self.index) > 1 then
		__t54 = __OrdaenProfessions_style_ROW_RULE
	else
		__t54 = nil
	end
	return __t54
end

function __f.c55(self)
	return __getKey(self.reagent, "icon")
end

function __f.c56(self)
	local __t57
	if __getKey(self.reagent, "have") < __getKey(self.reagent, "need") then
		__t57 = __OrdaenProfessions_style_RED
	else
		__t57 = __OrdaenProfessions_style_INK
	end
	return __t57
end

function __f.b60(self)
	return __get(self.rule)
end

function __f.b62(self)
	return __get(self.icon)
end

function __f.b64(self)
	return __getKey(self.reagent, "name")
end

function __f.b66(self)
	return { __getKey(self.reagent, "have"), __getKey(self.reagent, "need") }
end

function __f.b67(self)
	return __get(self.color)
end

function __f.b68(self)
	return __getKey(__Ordaen_core.theme, "font").numbers
end

function __f.d58(self, parent)
	local __e59 = __el(parent, "box")
	__attr(__e59, "columns", REAGENT)
	__attr(__e59, "gap", 6.666666666666667)
	__attr(__e59, "yAlign", "center")
	__attr(__e59, "padding", REAGENT_PAD)
	__bind(__e59, "border", __f.b60, self)
	local __e61 = __el(__e59, "box")
	__attr(__e61, "width", 26.666666666666668)
	__attr(__e61, "height", 26.666666666666668)
	__attr(__e61, "border", __OrdaenProfessions_style_BRONZE)
	__bind(__e61, "background", __f.b62, self)
	local __e63 = __el(__e59, "text")
	__bind(__e63, "value", __f.b64, self)
	__attr(__e63, "textSize", 10.833333333333334)
	__attr(__e63, "textColor", __OrdaenProfessions_style_INK)
	local __e65 = __el(__e59, "text")
	__attr(__e65, "value", "%d / %d")
	__bind(__e65, "arguments", __f.b66, self)
	__attr(__e65, "textSize", 10.833333333333334)
	__attr(__e65, "wrap", false)
	__bind(__e65, "textColor", __f.b67, self)
	__bind(__e65, "textFamily", __f.b68, self)
end

NAME_COUNT = { { fr = 1 }, "auto" }
CATEGORY_PAD = { top = 5.833333333333334, right = 8.333333333333334, bottom = 5.833333333333334, left = 8.333333333333334 }
RECIPE_PAD = { top = 5, right = 8.333333333333334, bottom = 5, left = 8.333333333333334 }
SLOT = 26.666666666666668
REAGENT = { 26.666666666666668, { fr = 1 }, "auto" }
REAGENT_PAD = { top = 2.5, right = 5, bottom = 2.5 }

CategoryRow = __class({})

function CategoryRow.new(__owner, category, index, chosen)
	local self = setmetatable({}, CategoryRow)
	R.adopt(__owner, self)
	self.category = category
	self.index = index
	self.chosen = chosen
	self.pick = __event()
	self.isChosen = __computed(self, __f.c1, self)
	self.background = __computed(self, __f.c2, self)
	self.rule = __computed(self, __f.c4, self)
	self.total = __computed(self, __f.c6, self)
	self.makeable = __computed(self, __f.c7, self)
	self.makeableColor = __computed(self, __f.c8, self)
	return self
end

function CategoryRow:count(makeableOnly)
	local n = 0
	local __l11 = __get(__game__TradeSkill_recipes)
	for __i10 = 1, #__l11 do
		local recipe = __l11[__i10]
		if recipe.categoryID == __getKey(self.category, "id") and (not makeableOnly or recipe.craftable > 0) then
			n = n + 1
		end
	end
	return n
end

function CategoryRow:onClick()
	__emit(self.pick, __getKey(self.category, "id"))
end

function CategoryRow:render()
	return __template(__f.d12, self)
end

RecipeRow = __class({})

function RecipeRow.new(__owner, recipe, index, chosen)
	local self = setmetatable({}, RecipeRow)
	R.adopt(__owner, self)
	self.recipe = recipe
	self.index = index
	self.chosen = chosen
	self.pick = __event()
	self.isChosen = __computed(self, __f.c30, self)
	self.background = __computed(self, __f.c31, self)
	self.rule = __computed(self, __f.c33, self)
	self.color = __computed(self, __f.c35, self)
	self.count = __computed(self, __f.c37, self)
	return self
end

function RecipeRow:onClick()
	__emit(self.pick, __getKey(self.recipe, "id"))
end

function RecipeRow:render()
	return __template(__f.d39, self)
end

ReagentRow = __class({})

function ReagentRow.new(__owner, reagent, index)
	local self = setmetatable({}, ReagentRow)
	R.adopt(__owner, self)
	self.reagent = reagent
	self.index = index
	self.rule = __computed(self, __f.c53, self)
	self.icon = __computed(self, __f.c55, self)
	self.color = __computed(self, __f.c56, self)
	return self
end

function ReagentRow:render()
	return __template(__f.d58, self)
end
__inherit(CategoryRow, { __Ordaen_module_Component })
__inherit(RecipeRow, { __Ordaen_module_Component })
__inherit(ReagentRow, { __Ordaen_module_Component })

M.NAME_COUNT = NAME_COUNT
M.CATEGORY_PAD = CATEGORY_PAD
M.RECIPE_PAD = RECIPE_PAD
M.SLOT = SLOT
M.REAGENT = REAGENT
M.REAGENT_PAD = REAGENT_PAD
M.CategoryRow = CategoryRow
M.RecipeRow = RecipeRow
M.ReagentRow = ReagentRow
