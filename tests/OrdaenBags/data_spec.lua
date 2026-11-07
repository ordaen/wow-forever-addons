-- Ordaen Bags, the model (Data.lua): items from a scan counted per tab and grouped in sections, with reused tables.
-- Pure, so it is loaded with Categories.lua and Blizzard's item classes faked.
describe("Ordaen Bags model", function()
	local Data

	before_each(function()
		rawset(_G, "Enum", { ItemClass = {
			Consumable = 0, Container = 1, Weapon = 2, Gem = 3, Armor = 4, Reagent = 5, Tradegoods = 7,
			ItemEnhancement = 8, Recipe = 9, Questitem = 12, Miscellaneous = 15, Profession = 19,
		} })
		local ns = {}
		assert(loadfile("addons/OrdaenBags/Categories.lua"))("OrdaenBags", ns)
		assert(loadfile("addons/OrdaenBags/Data.lua"))("OrdaenBags", ns)
		Data = ns.Data
	end)

	after_each(function()
		rawset(_G, "Enum", nil)
	end)

	-- a scan: bag, slot, class, subclass, quality, quest
	local function scan(list)
		Data.Reset()
		for _, it in ipairs(list) do
			Data.Add(it[1], it[2], it[3], it[4], it[5], it[6])
		end
	end

	it("counts the items of each tab, and all of them", function()
		scan({ { 0, 1, 2, 7, 3 }, { 0, 2, 0, 1, 1 }, { 1, 1, 0, 1, 1 }, { 1, 2, 4, 2, 0 } })
		assert.equals(4, Data.counts.all)
		assert.equals(1, Data.counts.equipment)
		assert.equals(2, Data.counts.consumables)
		assert.equals(1, Data.counts.junk, "grey armour is junk")
		assert.equals(0, Data.counts.recipes)
	end)

	it("groups a tab's items in sections ordered by class and subclass, items in scan order", function()
		scan({ { 0, 1, 4, 2, 2 }, { 0, 2, 2, 7, 3 }, { 1, 5, 4, 2, 2 }, { 0, 3, 0, 1, 1 } })
		local out = {}
		local n = Data.Group("equipment", out)
		assert.equals(2, n)
		assert.equals(2 * 1000 + 7, out[1].section, "weapons (class 2) before armour (class 4)")
		assert.equals(4 * 1000 + 2, out[2].section)
		assert.equals(2, out[2].n)
		assert.same({ 0, 1 }, { out[2][1].bag, out[2][1].slot })
		assert.same({ 1, 5 }, { out[2][2].bag, out[2][2].slot })
		assert.equals(3, Data.Group("all", out), "all: every section")
	end)

	it("reuses its tables from one scan to the next, and clears what a smaller tab doesn't use", function()
		scan({ { 0, 1, 2, 7, 3 }, { 0, 2, 4, 2, 2 } })
		local out = {}
		Data.Group("all", out)
		local first, record = out[1], Data.Item(1)
		scan({ { 0, 1, 2, 7, 3 } })
		assert.equals(1, Data.Group("all", out))
		assert.is_nil(out[2])
		assert.equals(first, out[1], "the same group table")
		assert.equals(record, Data.Item(1), "the same item record")
		assert.equals(1, Data.Count())
	end)

	it("counts free slots of the bags and of the reagent bag apart", function()
		Data.Reset()
		Data.AddFree(4, false)
		Data.AddFree(3, false)
		Data.AddFree(10, true)
		assert.equals(7, Data.free.bags)
		assert.equals(10, Data.free.reagent)
	end)
end)
