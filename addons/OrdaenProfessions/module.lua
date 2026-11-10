-- Ordaen Professions (design: wow-dev-tools design/professions): one window for the character's professions, in
-- place of Blizzard's. A tab per profession with its skill; under it the recipes in columns: the categories, the
-- category's recipes in their difficulty colour, and the chosen recipe with what it needs, its reagents (have / need)
-- and «Создать» with a count. The profession shown is Blizzard's open one (the game has one open at a time): a tab
-- opens its profession through the game, and the window shows while one is open. Blizzard's own window stays open
-- with it, invisible and off the screen: hiding it would close the profession.
local Define = import("@ordaen/define")
local S = import("style")

local WIDTH, HEIGHT = 900 * S.PX, 600 * S.PX
local COLUMNS = { columns = { 220 * S.PX, 280 * S.PX, "1fr" }, gap = 12 * S.PX, height = "100%" }
local LIST = { rows = "auto", overflow = "scroll", height = "100%" }
local DETAILS = { rows = "auto", gap = 8 * S.PX, overflow = "scroll", height = "100%" }

-- Blizzard's window while ours shows: open (closing it closes the profession), invisible, off the screen
local AWAY = { attributes = { opacity = 0, position = "absolute", left = -10000, top = 0 } }

local function Categories(game, self)
	game.TradeSkill.version:Get()
	local categories = game.TradeSkill.categories
	for i = 1, #categories do
		local c = categories[i]
		if c.parentID and self.counts[c.id] then
			game.ui:CategoryRow(self.categoryCalls[c.id])
		end
	end
end

local function Recipes(game, self)
	game.TradeSkill.version:Get()
	local recipes, category = game.TradeSkill.recipes, self.state.category
	for i = 1, #recipes do
		if recipes[i].categoryID == category then
			game.ui:RecipeRow(self.recipeCalls[recipes[i].id])
		end
	end
end

local function Details(game, self)
	game.ui:RecipeDetails(self.detailsCall)
end

local function Lists(game)
	game.ui:Box({ attributes = LIST, slots = { default = Categories } })
	game.ui:Box({ attributes = LIST, slots = { default = Recipes } })
	game.ui:Box({ attributes = DETAILS, slots = { default = Details } })
end

local function Body(game, self)
	game.ui:Tabs({ attributes = { tabs = self.tabNames, selected = self.state.tab, OnSelect = self.openTab } })
	game.ui:Box({ attributes = COLUMNS, slots = { default = Lists } })
end

local function Title(game, self)
	game.Professions.version:Get()
	local list = game.Professions.list
	return list[self.state.tab] and list[self.state.tab].name or ""
end

return Define.Module({
	title = "Ordaen Professions",
	icon = Define.Asset("Interface/Icons/Trade_BlackSmithing"),

	Setup = function(game, self)
		Define.Ephemeral({
			skillLine = { type = "number", default = 0 }, -- the open profession's
			tab = { type = "number", default = 0 }, -- its tab
			category = { type = "number", default = 0 },
			recipe = { type = "number", default = 0 },
			count = { type = "number", default = 1 },
		})
		-- each category's and recipe's row call, made once per id
		local categoryCalls = setmetatable({}, { __index = function(t, id)
			local call = { key = id, attributes = { id = id, chosen = Define.Signal(self.state.category),
				OnClick = function()
					self.state.category = id
					self.state.recipe = 0
				end } }
			t[id] = call
			return call
		end })
		local recipeCalls = setmetatable({}, { __index = function(t, id)
			local call = { key = id, attributes = { id = id, chosen = Define.Signal(self.state.recipe),
				OnClick = function()
					self.state.recipe = id
				end } }
			t[id] = call
			return call
		end })
		local tabNames, counts = {}, {}

		-- the profession tabs: each profession the character has, with its skill (`31 / 75`)
		self:Watch(function()
			game.Professions.version:Get()
			local list = game.Professions.list
			local tab = 0
			for i = 1, #list do
				tabNames[i] = list[i].name .. "  " .. list[i].rank .. " / " .. list[i].max
				if list[i].skillLine == self.state.skillLine then
					tab = i
				end
			end
			for i = #list + 1, #tabNames do
				tabNames[i] = nil
			end
			self.state.tab = tab
		end)
		-- the open profession: which categories have recipes; at first its first such category, and a category's first
		-- recipe
		self:Watch(function()
			local open = game.TradeSkill.open:Get()
			game.TradeSkill.version:Get()
			if type(open) == "number" and open ~= self.state.skillLine then
				self.state.skillLine = open
				self.state.category = 0
				self.state.recipe = 0
			end
			for k in pairs(counts) do
				counts[k] = nil
			end
			local recipes = game.TradeSkill.recipes
			for i = 1, #recipes do
				counts[recipes[i].categoryID] = true
			end
			if self.state.category == 0 then
				local categories = game.TradeSkill.categories
				for i = 1, #categories do
					if categories[i].parentID and counts[categories[i].id] then
						self.state.category = categories[i].id
						break
					end
				end
			end
			if self.state.recipe == 0 then
				local category = self.state.category
				for i = 1, #recipes do
					if recipes[i].categoryID == category then
						self.state.recipe = recipes[i].id
						break
					end
				end
			end
		end)

		-- the professions overview (the micro button, its key) opens this window on the first profession with
		-- recipes, or closes it, in place of Blizzard's overview
		self:On(game.Professions.Signal.BookToggled, function()
			game.Professions:CloseBook()
			if game.TradeSkill.open:Peek() then
				game.TradeSkill:Close()
				return
			end
			local list = game.Professions.list
			for i = 1, #list do
				if list[i].kind ~= game.Professions.Kind.Gathering then
					game.TradeSkill:Open(list[i].skillLine)
					return
				end
			end
		end)

		local function typedCount(text)
			local n = tonumber(text)
			if n and n >= 1 then
				self.state.count = math.floor(n)
			end
		end
		-- from the button's click: the game takes CraftRecipe only from one
		local function create()
			local recipe = game.TradeSkill:Recipe(self.state.recipe)
			if recipe and recipe.craftable > 0 then
				game.TradeSkill:Craft(recipe.id, math.min(self.state.count, recipe.craftable))
			end
		end
		return {
			tabNames = tabNames,
			counts = counts,
			categoryCalls = categoryCalls,
			recipeCalls = recipeCalls,
			detailsCall = { attributes = { recipe = Define.Signal(self.state.recipe),
				count = Define.Signal(self.state.count), OnCount = typedCount, OnCreate = create } },
			openTab = function(i)
				local p = game.Professions.list[i]
				if p and p.kind ~= game.Professions.Kind.Gathering then
					game.TradeSkill:Open(p.skillLine)
				end
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
		game.ui:Window({ attributes = { title = Title(game, self), width = WIDTH, height = HEIGHT, OnClose = self.close },
			slots = { default = Body } })
	end,
})
