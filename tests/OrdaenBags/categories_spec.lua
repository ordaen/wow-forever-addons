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
				return ({ ["0:1"] = "Potion", ["4:2"] = "Leather" })[classID .. ":" .. subClassID]
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
		assert.equals("Miscellaneous", Categories.SectionLabel(Categories.SectionOf(15, 0)), "the class's name")
	end)

	it("lists the tabs in their order, each with a Blizzard label", function()
		local ids = {}
		for i, tab in ipairs(Categories.TABS) do
			ids[i] = tab.id
			assert.is_string(tab.label)
		end
		assert.same({ "all", "equipment", "consumables", "tradegoods", "recipes", "quest", "junk", "other" }, ids)
	end)
end)
