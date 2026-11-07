-- Ordaen Bags, categories: which tab an item goes in (the tabs on the window's left) and which section of that tab
-- (a caption with its grid of slots), from the item's class and subclass as the game gives them (the user's design,
-- 2026-11-07: tabs on the left, subcategories in the window, like Baganator).
--   junk     grey items, whatever their class (sold at a vendor: Ordaen QoL)
--   quest    quest items, also items the game marks as starting or belonging to a quest
--   by class equipment (weapons, armour, profession tools), consumables, trade goods (with reagents, gems,
--            enhancements), recipes; everything else is "other"
-- Labels are Blizzard's own translated words (bag filters, auction categories, item subclasses), so every client
-- language works with no strings of ours. Pure: no WoW calls but the item class names (cached), so specs drive it.
-- Cost: a lookup per item; section labels are read once per subclass.
local _, ns = ...

local Categories = {}
ns.Categories = Categories

local QUALITY_POOR = 0

-- Blizzard's item classes (Enum.ItemClass; its fields are stable WoW values), read once on first use.
local CLASS
local function classes()
	if not CLASS then
		local E = Enum.ItemClass
		CLASS = {
			consumable = E.Consumable, weapon = E.Weapon, armor = E.Armor, gem = E.Gem, reagent = E.Reagent,
			tradegoods = E.Tradegoods, enhancement = E.ItemEnhancement, recipe = E.Recipe, quest = E.Questitem,
			profession = E.Profession, miscellaneous = E.Miscellaneous,
		}
	end
	return CLASS
end

--- The tabs, in their order on the window's left: id, label (Blizzard's word), and the item classes they hold.
--- "all" shows every item; "junk", "quest" and "other" are decided by Categories.TabOf.
Categories.TABS = {
	{ id = "all", label = "ALL" },
	{ id = "equipment", label = "BAG_FILTER_EQUIPMENT", classes = { "weapon", "armor", "profession" } },
	{ id = "consumables", label = "BAG_FILTER_CONSUMABLES", classes = { "consumable" } },
	{ id = "tradegoods", label = "BAG_FILTER_PROFESSION_GOODS", classes = { "tradegoods", "reagent", "gem",
		"enhancement" } },
	{ id = "recipes", label = "AUCTION_CATEGORY_RECIPES", classes = { "recipe" } },
	{ id = "quest", label = "BAG_FILTER_QUEST_ITEMS", classes = { "quest" } },
	{ id = "junk", label = "BAG_FILTER_JUNK" },
	{ id = "other", label = "AUCTION_CATEGORY_MISCELLANEOUS" },
}

local tabOfClass -- classID -> tab id, built on first use
local function tabsByClass()
	if not tabOfClass then
		tabOfClass = {}
		local C = classes()
		for _, tab in ipairs(Categories.TABS) do
			for _, name in ipairs(tab.classes or {}) do
				local id = C[name]
				if id then
					tabOfClass[id] = tab.id
				end
			end
		end
	end
	return tabOfClass
end

--- The tab an item goes in.
---@param classID number|nil the item's class (C_Item.GetItemInfoInstant)
---@param quality number|nil
---@param isQuest boolean|nil the game marks it as a quest item (C_Container.GetContainerItemQuestInfo)
---@return string tab id
function Categories.TabOf(classID, quality, isQuest)
	if quality == QUALITY_POOR then
		return "junk"
	end
	if isQuest then
		return "quest"
	end
	return classID and tabsByClass()[classID] or "other"
end

--- The section of a tab an item goes in: one number per class and subclass (no strings), ordered by class, then
--- subclass, so sections keep a stable order.
---@param classID number|nil
---@param subClassID number|nil
---@return number
function Categories.SectionOf(classID, subClassID)
	return (classID or 99) * 1000 + (subClassID or 0)
end

local labels = {} -- section -> its caption
--- A section's caption: the subclass's name in the client's language (the class's when the subclass has none).
---@param section number
---@return string
function Categories.SectionLabel(section)
	local label = labels[section]
	if not label then
		local classID, subClassID = math.floor(section / 1000), section % 1000
		-- Miscellaneous' first subclass is called "Junk" by the game, though it holds the Hearthstone and such: it
		-- takes the class's name ("Junk" is the grey items' tab)
		if classID ~= classes().miscellaneous or subClassID ~= 0 then
			label = C_Item.GetItemSubClassInfo(classID, subClassID)
		end
		label = label or C_Item.GetItemClassInfo(classID) or ""
		labels[section] = label
	end
	return label
end
