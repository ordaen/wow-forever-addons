-- Ordaen Bags, categories (Categories.lua): which tab and which section an item goes in, from its class, subclass,
-- quality and quest flag. Pure, so the module is loaded on its own with Blizzard's item classes faked.
describe("Ordaen Bags categories", function()
	local Categories

	before_each(function()
		-- Blizzard's Enum.ItemClass values (stable across WoW versions).
		rawset(_G, "Enum", { ItemClass = {
			Consumable = 0, Container = 1, Weapon = 2, Gem = 3, Armor = 4, Reagent = 5, Tradegoods = 7,
			ItemEnhancement = 8, Recipe = 9, Questitem = 12, Miscellaneous = 15, Profession = 19,
		} })
		rawset(_G, "C_Item", {
			GetItemSubClassInfo = function(classID, subClassID)
				-- as in the game: Miscellaneous' first subclass is called "Junk" (the Hearthstone is one)
				return ({ ["0:1"] = "Potion", ["4:2"] = "Leather", ["15:0"] = "Junk" })[classID .. ":" .. subClassID]
			end,
			GetItemClassInfo = function(classID)
				return ({ [15] = "Miscellaneous" })[classID]
			end,
		})
		local ns = {}
		assert(loadfile("addons/OrdaenBags/Categories.lua"))("OrdaenBags", ns)
		Categories = ns.Categories
	end)

	after_each(function()
		rawset(_G, "Enum", nil)
		rawset(_G, "C_Item", nil)
	end)

	it("puts items in a tab by their class: weapons and armour in equipment, potions in consumables", function()
		assert.equals("equipment", Categories.TabOf(2, 2))
		assert.equals("equipment", Categories.TabOf(4, 3))
		assert.equals("consumables", Categories.TabOf(0, 1))
		assert.equals("tradegoods", Categories.TabOf(5, 1), "reagents with trade goods")
		assert.equals("recipes", Categories.TabOf(9, 1))
	end)

	it("puts grey items in junk and quest items in quest, whatever their class", function()
		assert.equals("junk", Categories.TabOf(4, 0))
		assert.equals("quest", Categories.TabOf(15, 1, true), "the game marks it as a quest item")
		assert.equals("quest", Categories.TabOf(12, 1))
	end)

	it("puts what no tab holds in other", function()
		assert.equals("other", Categories.TabOf(15, 1))
		assert.equals("other", Categories.TabOf(nil, nil), "no item info yet")
	end)

	it("orders sections by class, then subclass, and names them in the client's words", function()
		local potion, leather = Categories.SectionOf(0, 1), Categories.SectionOf(4, 2)
		assert.is_true(potion < leather)
		assert.equals("Potion", Categories.SectionLabel(potion))
		assert.equals("Leather", Categories.SectionLabel(leather))
		assert.equals("Miscellaneous", Categories.SectionLabel(Categories.SectionOf(15, 0)),
			"the class's name: Blizzard's \"Junk\" subclass holds the Hearthstone, and junk is the grey items' tab")
	end)

	it("lists the tabs in their order, each with a Blizzard label", function()
		local ids = {}
		for i, tab in ipairs(Categories.TABS) do
			ids[i] = tab.id
			assert.is_string(tab.label)
		end
		assert.same({ "all", "equipment", "consumables", "tradegoods", "recipes", "quest", "junk", "other" }, ids)
	end)

	it("groups by type, equipment slot, quality or not at all, each in its own order and words", function()
		rawset(_G, "INVTYPE_HEAD", "Head")
		rawset(_G, "INVTYPE_CHEST", "Chest")
		rawset(_G, "ITEM_QUALITY4_DESC", "Epic")
		rawset(_G, "ITEM_QUALITY2_DESC", "Uncommon")
		rawset(_G, "AUCTION_CATEGORY_MISCELLANEOUS", "Miscellaneous")
		local helm = { section = Categories.SectionOf(4, 1), equipLoc = "INVTYPE_HEAD", quality = 2 }
		local robe = { section = Categories.SectionOf(4, 1), equipLoc = "INVTYPE_ROBE", quality = 4 }
		local potion = { section = Categories.SectionOf(0, 1), equipLoc = "", quality = 1 }
		assert.equals(helm.section, Categories.GroupKey(helm, nil), "type by default")
		local head, chest, other = Categories.GroupKey(helm, "slot"), Categories.GroupKey(robe, "slot"),
			Categories.GroupKey(potion, "slot")
		assert.is_true(head < chest and chest < other, "head before chest, what isn't worn last")
		assert.equals("Head", Categories.SectionLabel(head))
		assert.equals("Chest", Categories.SectionLabel(chest), "a robe is a chest piece")
		assert.equals("Miscellaneous", Categories.SectionLabel(other))
		local epic, uncommon = Categories.GroupKey(robe, "quality"), Categories.GroupKey(helm, "quality")
		assert.is_true(epic < uncommon, "the best first")
		assert.equals("Epic", Categories.SectionLabel(epic))
		assert.equals(Categories.GroupKey(helm, "none"), Categories.GroupKey(potion, "none"), "one group")
		assert.equals("", Categories.SectionLabel(Categories.GroupKey(helm, "none")), "no caption")
	end)
end)
