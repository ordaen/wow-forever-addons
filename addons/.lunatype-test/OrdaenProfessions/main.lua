-- Made by lunatype from OrdaenProfessions/main.luna: change the source, not this file.
local R = LunaType
local __get, __getKey, __peek, __set, __cell, __computed, __watch, __listen, __class, __inherit, __el, __attr, __bind, __template, __input, __draw, __when, __each = R.get, R.getKey, R.peek, R.set, R.cell, R.computed, R.watch, R.listen, R.class, R.inherit, R.el, R.attr, R.bind, R.template, R.input, R.draw, R.when, R.each
local __insert = table.insert
local __OrdaenProfessions_style_LINE = R.addon("OrdaenProfessions")["style"].LINE
local __game__TradeSkill_open = R.game.TradeSkill.open
local __game__TradeSkill_shownEmpty = R.game.TradeSkill.shownEmpty
local __game__Professions_list = R.game.Professions.list
local __string_format = R.string.format
local __game__TradeSkill_categories = R.game.TradeSkill.categories
local __game__TradeSkill_recipes = R.game.TradeSkill.recipes
local __OrdaenProfessions_locales_TAB_RECIPES = R.addon("OrdaenProfessions")["locales"].TAB_RECIPES
local __OrdaenProfessions_locales_TAB_CAMP = R.addon("OrdaenProfessions")["locales"].TAB_CAMP
local __string_lower = R.string.lower
local __string_contains = R.string.contains
local __game__TradeSkill_show = R.game.TradeSkill.show
local __game__TradeSkill_craft = R.game.TradeSkill.craft
local __game__TradeSkill_close = R.game.TradeSkill.close
local __game__Frames_Professions = R.game.Frames.Professions
local __OrdaenLibrary_window_Window = R.addon("OrdaenLibrary")["window"].Window
local __OrdaenProfessions_skillBar_SkillBar = R.addon("OrdaenProfessions")["skillBar"].SkillBar
local __OrdaenLibrary_tabs_Tabs = R.addon("OrdaenLibrary")["tabs"].Tabs
local __OrdaenProfessions_style_INK = R.addon("OrdaenProfessions")["style"].INK
local __OrdaenProfessions_locales_SEARCH = R.addon("OrdaenProfessions")["locales"].SEARCH
local __OrdaenProfessions_style_DIM = R.addon("OrdaenProfessions")["style"].DIM
local __OrdaenProfessions_style_LISTS_BACK = R.addon("OrdaenProfessions")["style"].LISTS_BACK
local __OrdaenProfessions_rows_RecipeRow = R.addon("OrdaenProfessions")["rows"].RecipeRow
local __OrdaenProfessions_rows_CategoryRow = R.addon("OrdaenProfessions")["rows"].CategoryRow
local __OrdaenProfessions_details_RecipeDetails = R.addon("OrdaenProfessions")["details"].RecipeDetails
local __Ordaen_module_Module = R.addon("Ordaen")["module"].Module
local M = {}
R.addon("OrdaenProfessions")["main"] = M
local RECIPES, CAMP, FILL, BODY, GRID, SIDE, LISTS, FRAME, COLUMN_RULE, SEARCH_HEIGHT, SEARCH_EDGE, SEARCH_BACK, SEARCH_PAD, Professions

local function __c1(self)
	return __get(__game__TradeSkill_open) ~= nil
end

local function __c2(self)
	return self:tabsOf()
end

local function __c3(self)
	return self:professionOf()
end

local function __c4(self)
	return self:campOf()
end

local function __c5(self)
	return __get(self.page) == 2
end

local function __c6(self)
	return self:pageNamesOf()
end

local function __c7(self)
	return self:categoriesOf()
end

local function __c8(self)
	return self:chosenCategoryOf()
end

local function __c9(self)
	local __t10
	if __get(self.onCamp) then
		__t10 = __get(self.camp)
	else
		__t10 = __get(self.chosenCategory)
	end
	return __t10
end

local function __c11(self)
	return self:recipesOf()
end

local function __c12(self)
	return self:chosenRecipeOf()
end

local function __c13(self)
	return self:shownOf()
end

local function __c14(self)
	return __get(self.search) ~= ""
end

local function __b36(self)
	return __get(self.isOpen)
end

local function __b39(self)
	return __get(__game__Frames_Professions)
end

local function __b50(self)
	return not __get(self.searching)
end

local function __d51(self, parent)
	local __e52 = __el(parent, "box")
	__attr(__e52, "position", "absolute")
	__attr(__e52, "left", 0)
	__attr(__e52, "top", 0)
	__attr(__e52, "right", 0)
	__attr(__e52, "bottom", 0)
	__attr(__e52, "padding", SEARCH_PAD)
	__attr(__e52, "yAlign", "center")
	local __e53 = __el(__e52, "text")
	__attr(__e53, "value", __OrdaenProfessions_locales_SEARCH)
	__attr(__e53, "textSize", 11.666666666666668)
	__attr(__e53, "textColor", __OrdaenProfessions_style_DIM)
	__attr(__e53, "wrap", false)
end

local __w49 = { __b50, __d51 }

local function __b55(self)
	return __get(self.onCamp)
end

local function __b59(self)
	return __get(self.recipes)
end

local function __b60(self, index, recipe)
	return __getKey(recipe, "id")
end

local function __d61(self, parent, index, recipe)
	local __c62 = __OrdaenProfessions_rows_RecipeRow.new(parent, recipe, __cell(index), self.chosenRecipe)
	__listen(__c62.pick, self, self.pickRecipe)
	__draw(parent, __c62, nil)
end

local function __d56(self, parent)
	local __e57 = __el(parent, "box")
	__attr(__e57, "rows", FILL)
	__attr(__e57, "border", FRAME)
	__attr(__e57, "background", __OrdaenProfessions_style_LISTS_BACK)
	local __e58 = __el(__e57, "box")
	__attr(__e58, "overflow", "scroll")
	__each(__e58, __b59, __b60, __d61, 2, 1, true, self)
end

local function __b66(self)
	return __get(self.categories)
end

local function __b67(self, index, category)
	return __getKey(category, "id")
end

local function __d68(self, parent, index, category)
	local __c69 = __OrdaenProfessions_rows_CategoryRow.new(parent, category, __cell(index), self.chosenCategory)
	__listen(__c69.pick, self, self.pickCategory)
	__draw(parent, __c69, nil)
end

local function __b71(self)
	return __get(self.recipes)
end

local function __b72(self, index, recipe)
	return __getKey(recipe, "id")
end

local function __d73(self, parent, index, recipe)
	local __c74 = __OrdaenProfessions_rows_RecipeRow.new(parent, recipe, __cell(index), self.chosenRecipe)
	__listen(__c74.pick, self, self.pickRecipe)
	__draw(parent, __c74, nil)
end

local function __d63(self, parent)
	local __e64 = __el(parent, "box")
	__attr(__e64, "columns", LISTS)
	__attr(__e64, "rows", FILL)
	__attr(__e64, "border", FRAME)
	__attr(__e64, "background", __OrdaenProfessions_style_LISTS_BACK)
	local __e65 = __el(__e64, "box")
	__attr(__e65, "overflow", "scroll")
	__each(__e65, __b66, __b67, __d68, 2, 1, true, self)
	local __e70 = __el(__e64, "box")
	__attr(__e70, "overflow", "scroll")
	__attr(__e70, "border", COLUMN_RULE)
	__each(__e70, __b71, __b72, __d73, 2, 1, true, self)
end

local __w54 = { __b55, __d56, false, __d63 }

local function __d41(self, parent)
	local __e42 = __el(parent, "box")
	__attr(__e42, "rows", BODY)
	__attr(__e42, "gap", 6.666666666666667)
	local __c43 = __OrdaenProfessions_skillBar_SkillBar.new(__e42, self.profession)
	__draw(__e42, __c43, nil)
	local __c44 = __OrdaenLibrary_tabs_Tabs.new(__e42, self.pageNames, self.page)
	__draw(__e42, __c44, nil)
	local __e45 = __el(__e42, "box")
	__attr(__e45, "columns", GRID)
	__attr(__e45, "rows", FILL)
	__attr(__e45, "gap", 10)
	local __e46 = __el(__e45, "box")
	__attr(__e46, "rows", SIDE)
	__attr(__e46, "gap", 6.666666666666667)
	local __e47 = __el(__e46, "box")
	__attr(__e47, "height", 25)
	__attr(__e47, "rows", FILL)
	local __e48 = __el(__e47, "input")
	__input(__e48, self.search)
	__attr(__e48, "padding", SEARCH_PAD)
	__attr(__e48, "textSize", 11.666666666666668)
	__attr(__e48, "textColor", __OrdaenProfessions_style_INK)
	__attr(__e48, "background", SEARCH_BACK)
	__attr(__e48, "border", SEARCH_EDGE)
	__when(__e47, __w49, self)
	__when(__e46, __w54, self)
	local __c75 = __OrdaenProfessions_details_RecipeDetails.new(__e45, self.shown, self.count)
	__listen(__c75.create, self, self.onCreate)
	__draw(__e45, __c75, nil)
end

local function __d37(self, parent)
	local __e38 = __el(parent, "frame")
	__bind(__e38, "of", __b39, self)
	__attr(__e38, "opacity", 0)
	__attr(__e38, "away", true)
	local __c40 = __OrdaenLibrary_window_Window.new(parent, self.tabs, self.tab, self.placing, nil, nil, nil, nil)
	__listen(__c40.close, self, self.onClose)
	__draw(parent, __c40, { self = self, [""] = __d41 })
end

local __w35 = { __b36, __d37 }

local function __d34(self, parent)
	__when(parent, __w35, self)
end

RECIPES = 1
CAMP = 2
FILL = { { fr = 1 } }
BODY = { "auto", "auto", { fr = 1 } }
GRID = { 441.6666666666667, { fr = 1 } }
SIDE = { "auto", { fr = 1 } }
LISTS = { 208.33333333333334, { fr = 1 } }
FRAME = { width = 0.8333333333333334, color = __OrdaenProfessions_style_LINE }
COLUMN_RULE = { width = 0.8333333333333334, color = __OrdaenProfessions_style_LINE, sides = { "left" } }
SEARCH_HEIGHT = 25
SEARCH_EDGE = { width = 0.8333333333333334, color = { r = 0.290, g = 0.227, b = 0.141, a = 1 } }
SEARCH_BACK = { r = 0, g = 0, b = 0, a = 0.502 }
SEARCH_PAD = { right = 8.333333333333334, left = 8.333333333333334 }

Professions = __class({})

function Professions.new(__owner)
	local self = setmetatable({ title = "Ordaen Professions" }, Professions)
	R.adopt(__owner, self)
	self.pages = {}
	self.tab = __cell(0)
	self.page = __cell(1)
	self.category = __cell(0)
	self.recipe = __cell(0)
	self.count = __cell(1)
	self.search = __cell("")
	self.placing = __cell({ x = 0, y = 0, width = 883.3333333333334, height = 583.3333333333334 })
	self.skillLine = 0
	self.isOpen = __computed(self, __c1, self)
	self.tabs = __computed(self, __c2, self)
	self.profession = __computed(self, __c3, self)
	self.camp = __computed(self, __c4, self)
	self.onCamp = __computed(self, __c5, self)
	self.pageNames = __computed(self, __c6, self)
	self.categories = __computed(self, __c7, self)
	self.chosenCategory = __computed(self, __c8, self)
	self.listed = __computed(self, __c9, self)
	self.recipes = __computed(self, __c11, self)
	self.chosenRecipe = __computed(self, __c12, self)
	self.shown = __computed(self, __c13, self)
	self.searching = __computed(self, __c14, self)
	__watch(self, self.followOpen, self)
	__watch(self, self.openPicked, self)
	__watch(self, self.onPage, self)
	__listen(__game__TradeSkill_shownEmpty, self, self.onShownEmpty)
	return self
end

function Professions:tabsOf()
	local list = {}
	local __l16 = __get(__game__Professions_list)
	for __i15 = 1, #__l16 do
		local profession = __l16[__i15]
		__insert(list, { title = profession.name, icon = profession.icon, desc = __string_format("%d / %d", profession.rank, profession.max) })
	end
	return list
end

function Professions:professionOf()
	local __l18 = __get(__game__Professions_list)
	for __i17 = 1, #__l18 do
		local profession = __l18[__i17]
		if profession.skillLine == __get(__game__TradeSkill_open) then
			return profession
		end
	end
	return nil
end

function Professions:campOf()
	local __l20 = __get(__game__TradeSkill_categories)
	for __i19 = 1, #__l20 do
		local category = __l20[__i19]
		if category.parentID ~= nil then
			return category.id
		end
	end
	return 0
end

function Professions:hasRecipes(category)
	local __l22 = __get(__game__TradeSkill_recipes)
	for __i21 = 1, #__l22 do
		local recipe = __l22[__i21]
		if recipe.categoryID == category then
			return true
		end
	end
	return false
end

function Professions:pageNamesOf()
	local names = { __OrdaenProfessions_locales_TAB_RECIPES }
	if __get(self.camp) ~= 0 and self:hasRecipes(__get(self.camp)) then
		__insert(names, __OrdaenProfessions_locales_TAB_CAMP)
	end
	return names
end

function Professions:categoriesOf()
	local list = {}
	local __l24 = __get(__game__TradeSkill_categories)
	for __i23 = 1, #__l24 do
		local category = __l24[__i23]
		if category.parentID ~= nil and category.id ~= __get(self.camp) and self:hasRecipes(category.id) then
			__insert(list, category)
		end
	end
	return list
end

function Professions:chosenCategoryOf()
	if __get(self.category) ~= 0 then
		return __get(self.category)
	end
	local first = __getKey(self.categories, 1)
	if first == nil then
		return 0
	end
	return first.id
end

function Professions:recipesOf()
	local list = {}
	local sought = __string_lower(__get(self.search))
	local __l26 = __get(__game__TradeSkill_recipes)
	for __i25 = 1, #__l26 do
		local recipe = __l26[__i25]
		if recipe.categoryID == __get(self.listed) and (sought == "" or __string_contains(__string_lower(recipe.name), sought)) then
			__insert(list, recipe)
		end
	end
	return list
end

function Professions:chosenRecipeOf()
	if __get(self.recipe) ~= 0 then
		return __get(self.recipe)
	end
	local __l28 = __get(__game__TradeSkill_recipes)
	for __i27 = 1, #__l28 do
		local recipe = __l28[__i27]
		if recipe.categoryID == __get(self.listed) then
			return recipe.id
		end
	end
	return 0
end

function Professions:shownOf()
	local __l30 = __get(__game__TradeSkill_recipes)
	for __i29 = 1, #__l30 do
		local recipe = __l30[__i29]
		if recipe.id == __get(self.chosenRecipe) then
			return recipe
		end
	end
	return nil
end

function Professions:followOpen()
	local open = __get(__game__TradeSkill_open)
	local at = 0
	local __l31 = __get(__game__Professions_list)
	for index = 1, #__l31 do
		local profession = __l31[index]
		if profession.skillLine == open then
			at = index
		end
	end
	__set(self.tab, at)
	if open ~= nil and open ~= self.skillLine then
		self.skillLine = open
		__set(self.category, 0)
		__set(self.recipe, 0)
		__set(self.page, 1)
	end
end

function Professions:openPicked()
	local picked = __peek(__game__Professions_list)[__get(self.tab)]
	if picked ~= nil and picked.skillLine ~= __peek(__game__TradeSkill_open) then
		__game__TradeSkill_show(picked.skillLine)
	end
end

function Professions:onPage()
	if __get(self.page) ~= 0 then
		__set(self.recipe, 0)
	end
end

function Professions:onShownEmpty()
	if __peek(__game__TradeSkill_open) ~= nil then
		return
	end
	local __l33 = __peek(__game__Professions_list)
	for __i32 = 1, #__l33 do
		local profession = __l33[__i32]
		if profession.kind ~= "gathering" then
			__game__TradeSkill_show(profession.skillLine)
			return
		end
	end
end

function Professions:pickCategory(id)
	__set(self.category, id)
	__set(self.recipe, 0)
end

function Professions:pickRecipe(id)
	__set(self.recipe, id)
end

function Professions:onCreate(count)
	__game__TradeSkill_craft(__get(self.chosenRecipe), count)
end

function Professions:onClose()
	__game__TradeSkill_close()
end

function Professions:render()
	return __template(__d34, self)
end
__inherit(Professions, { __Ordaen_module_Module })

M.RECIPES = RECIPES
M.CAMP = CAMP
M.FILL = FILL
M.BODY = BODY
M.GRID = GRID
M.SIDE = SIDE
M.LISTS = LISTS
M.FRAME = FRAME
M.COLUMN_RULE = COLUMN_RULE
M.SEARCH_HEIGHT = SEARCH_HEIGHT
M.SEARCH_EDGE = SEARCH_EDGE
M.SEARCH_BACK = SEARCH_BACK
M.SEARCH_PAD = SEARCH_PAD
M.Professions = Professions
