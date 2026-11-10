-- Ordaen Professions (design: wow-dev-tools design/professions): one window for the character's professions, in
-- place of Blizzard's. The window's tabs are the professions (icon, name, skill); under its top line the skill bar,
-- then the profession's own tabs («Рецепты», «Лагерь» while it has camp recipes), then the recipes' side (the search,
-- and the categories beside the category's recipes, in one framed panel) and the chosen recipe on dark marble beside
-- it. The profession shown is Blizzard's open one (the game has one open at a time): a tab opens its profession through
-- the game, and the window shows while one is open. Blizzard's own window stays open with it, invisible and off the
-- screen: hiding it would close the profession.
local Define = import("@ordaen/define")
local L = import("locales")
local S = import("style")

-- the profession's own tabs: which page shows
---@enum OrdaenProfessionsPage
local Page = { Recipes = 1, Camp = 2 }

-- the body: the window's, less the window's padding (14 + 3 px above, 12 + 3 below: Window's PADDING), so its rows
-- can share a known height (the window's body is placed by its edges, which a share can't be taken of)
local BODY = { rows = { "auto", "auto", "1fr" }, gap = 8 * S.PX, height = S.HEIGHT - 32 * S.PX }
-- the recipes' side and the chosen recipe: what's left of the body under the skill bar (30 px), the page tabs (29 px)
-- and their two gaps. A height, since a row's "1fr" doesn't stretch a box to it.
local GRID_H = S.HEIGHT - (32 + 30 + 29 + 16) * S.PX
local GRID = { columns = { S.LEFT, "1fr" }, gap = S.GAP, height = GRID_H }
local SEARCH_H = 30 * S.PX
local LISTS_H = GRID_H - SEARCH_H - 8 * S.PX -- under the search and its gap
local LEFT = { rows = { "auto", "auto" }, gap = 8 * S.PX }
local LISTS = { columns = { S.CATEGORIES, "1fr" }, height = LISTS_H, border = { width = 1 * S.PX, color = S.LINE },
	background = S.LISTS_BG }
local CAMP_LISTS = { columns = { "1fr" }, height = LISTS_H, border = { width = 1 * S.PX, color = S.LINE },
	background = S.LISTS_BG }
local CATEGORY_COLUMN = { rows = "auto", overflow = "scroll", height = "100%" }
local RECIPE_COLUMN = { rows = "auto", overflow = "scroll", height = "100%",
	border = { width = 1 * S.PX, sides = { "left" }, color = S.LINE } }
local CAMP_COLUMN = { rows = "auto", overflow = "scroll", height = "100%" }
local SEARCH_EDGE = { width = 1 * S.PX, color = { 0.29, 0.227, 0.141, 1 } } -- #4a3a24
local SEARCH_BG = { 0, 0, 0, 0.5 }
local SEARCH_PAD = { 0, 10 * S.PX, 0, 10 * S.PX }

-- Blizzard's window while ours shows: open (closing it closes the profession), invisible, off the screen
local AWAY = { attributes = { opacity = 0, position = "absolute", left = -10000, top = 0 } }

-- the camp category («Отдых в лагере»): the first category under the profession's header, as Forever orders them
-- (by its place, never its name)
local function CampID(game)
	local categories = game.TradeSkill.categories
	for i = 1, #categories do
		if categories[i].parentID then
			return categories[i].id
		end
	end
	return nil
end

-- whether a recipe shows: the search finds it by name
local function Matches(self, recipe)
	local search = self.state.search
	return search == "" or recipe.name:lower():find(search:lower(), 1, true) ~= nil
end

local function Categories(game, self)
	game.TradeSkill.version:Get()
	local categories, first = game.TradeSkill.categories, true
	local camp = CampID(game)
	for i = 1, #categories do
		local c = categories[i]
		if c.parentID and c.id ~= camp and self.counts[c.id] then
			local call = self.categoryCalls[c.id]
			call.attributes.first = first
			first = false
			game.ui:CategoryRow(call)
		end
	end
end

local function Recipes(game, self)
	game.TradeSkill.version:Get()
	local recipes = game.TradeSkill.recipes
	local category = self.state.page == Page.Camp and CampID(game) or self.state.category
	local first = true
	for i = 1, #recipes do
		local r = recipes[i]
		if r.categoryID == category and Matches(self, r) then
			local call = self.recipeCalls[r.id]
			call.attributes.first = first
			first = false
			game.ui:RecipeRow(call)
		end
	end
end

local function Lists(game, self)
	if self.state.page == Page.Camp then
		game.ui:Box({ attributes = CAMP_COLUMN, slots = { default = Recipes } })
		return
	end
	game.ui:Box({ attributes = CATEGORY_COLUMN, slots = { default = Categories } })
	game.ui:Box({ attributes = RECIPE_COLUMN, slots = { default = Recipes } })
end

local function Placeholder(game, self)
	if self.state.search == "" then
		game.ui:Text({ attributes = { text = L.SEARCH, textSize = S.TEXT, textColor = S.DIM, wrap = false } })
	end
end

local function SearchField(game, self)
	game.ui:Box({ attributes = { kind = "input", height = SEARCH_H, padding = SEARCH_PAD, textSize = S.TEXT,
		textColor = S.INK, background = SEARCH_BG, border = SEARCH_EDGE, text = self.state.search,
		OnChange = self.typedSearch } })
	game.ui:Box({ attributes = { position = "absolute", left = 0, top = 0, right = 0, bottom = 0, padding = SEARCH_PAD,
		yAlign = "center", columns = 1 }, slots = { default = Placeholder } })
end

local function Left(game, self)
	game.ui:Box({ attributes = { columns = 1, height = SEARCH_H }, slots = { default = SearchField } })
	game.ui:Box({ attributes = self.state.page == Page.Camp and CAMP_LISTS or LISTS, slots = { default = Lists } })
end

local function Grid(game, self)
	game.ui:Box({ attributes = LEFT, slots = { default = Left } })
	game.ui:RecipeDetails(self.detailsCall)
end

local function Parts(game, self)
	game.ui:SkillBar({ attributes = { skillLine = self.state.skillLine, fill = self.state.xpFill } })
	game.ui:Tabs({ attributes = { tabs = self.pageNames, selected = self.state.page, OnSelect = self.pickPage } })
	game.ui:Box({ attributes = GRID, slots = { default = Grid } })
end

local function Body(game)
	game.ui:Box({ attributes = BODY, slots = { default = Parts } })
end

return Define.Module({
	title = "Ordaen Professions",
	icon = Define.Asset("Interface/Icons/Trade_BlackSmithing"),

	Setup = function(game, self)
		Define.Ephemeral({
			skillLine = { type = "number", default = 0 }, -- the open profession's
			tab = { type = "number", default = 0 }, -- its window tab
			page = { type = "number", default = Page.Recipes },
			category = { type = "number", default = 0 },
			recipe = { type = "number", default = 0 },
			count = { type = "number", default = 1 },
			search = { type = "string", default = "" },
			-- the skill bar's fill: the theme's experience-bar fill, as the panel's experience bar draws it
			xpFill = { type = "asset", kind = "xpFill", follows = Define.Theme.xpFill },
		})
		-- each category's and recipe's row call, made once per id
		local categoryCalls = setmetatable({}, { __index = function(t, id)
			local call = { key = id, attributes = { id = id, first = false, chosen = Define.Signal(self.state.category),
				OnClick = function()
					self.state.category = id
					self.state.recipe = 0
				end } }
			t[id] = call
			return call
		end })
		local recipeCalls = setmetatable({}, { __index = function(t, id)
			local call = { key = id, attributes = { id = id, first = false, chosen = Define.Signal(self.state.recipe),
				OnClick = function()
					self.state.recipe = id
				end } }
			t[id] = call
			return call
		end })
		local tabs, counts, pageNames = {}, {}, { L.TAB_RECIPES }

		-- the window's tabs: each profession the character has, its icon, name and skill (`31 / 75`)
		self:Watch(function()
			game.Professions.version:Get()
			local list = game.Professions.list
			local tab = 0
			for i = 1, #list do
				local t = tabs[i] or {}
				tabs[i] = t
				t.title, t.desc, t.icon = list[i].name, list[i].rank .. " / " .. list[i].max, list[i].icon
				if list[i].skillLine == self.state.skillLine then
					tab = i
				end
			end
			for i = #list + 1, #tabs do
				tabs[i] = nil
			end
			self.state.tab = tab
		end)
		-- the open profession: which categories have recipes, whether it has camp recipes; at first its first category
		-- with recipes, and a category's first recipe
		self:Watch(function()
			local open = game.TradeSkill.open:Get()
			game.TradeSkill.version:Get()
			if type(open) == "number" and open ~= self.state.skillLine then
				self.state.skillLine = open
				self.state.category = 0
				self.state.recipe = 0
				self.state.page = Page.Recipes
			end
			for k in pairs(counts) do
				counts[k] = nil
			end
			local recipes = game.TradeSkill.recipes
			for i = 1, #recipes do
				counts[recipes[i].categoryID] = true
			end
			local camp = CampID(game)
			pageNames[Page.Camp] = camp and counts[camp] and L.TAB_CAMP or nil
			if self.state.category == 0 then
				local categories = game.TradeSkill.categories
				for i = 1, #categories do
					local c = categories[i]
					if c.parentID and c.id ~= camp and counts[c.id] then
						self.state.category = c.id
						break
					end
				end
			end
			if self.state.recipe == 0 then
				local category = self.state.page == Page.Camp and camp or self.state.category
				for i = 1, #recipes do
					if recipes[i].categoryID == category then
						self.state.recipe = recipes[i].id
						break
					end
				end
			end
		end)

		-- from the button's click: the game takes CraftRecipe only from one
		local function create()
			local recipe = game.TradeSkill:Recipe(self.state.recipe)
			if recipe and recipe.craftable > 0 then
				game.TradeSkill:Craft(recipe.id, math.min(self.state.count, recipe.craftable))
			end
		end
		return {
			tabs = tabs,
			counts = counts,
			pageNames = pageNames,
			categoryCalls = categoryCalls,
			recipeCalls = recipeCalls,
			detailsCall = { attributes = { recipe = Define.Signal(self.state.recipe),
				count = Define.Signal(self.state.count), OnCreate = create,
				OnLess = function()
					self.state.count = math.max(1, self.state.count - 1)
				end,
				OnMore = function()
					self.state.count = self.state.count + 1
				end } },
			openTab = function(i)
				local p = game.Professions.list[i]
				if p and p.kind ~= game.Professions.Kind.Gathering then
					game.TradeSkill:Open(p.skillLine)
				end
			end,
			pickPage = function(i)
				self.state.page = i
				self.state.recipe = 0
			end,
			typedSearch = function(text)
				self.state.search = text or ""
			end,
			close = function()
				game.TradeSkill:Close()
			end,
		}
	end,

	Render = function(game, self)
		if not game.TradeSkill.open:Get() then
			return
		end
		game.ui:Frame(game.Frame.Professions, AWAY)
		game.ui:Window({ attributes = { tabs = self.tabs, selected = self.state.tab, OnSelect = self.openTab,
			width = S.WIDTH, height = S.HEIGHT, OnClose = self.close }, slots = { default = Body } })
	end,
})
