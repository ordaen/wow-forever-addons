describe("OrdaenMinimap drawer data", function()
	local ns

	before_each(function()
		ns = {}
		assert(loadfile("addons/OrdaenMinimap/DrawerData.lua"))("OrdaenMinimap", ns)
	end)

	describe("DrawerGrid", function()
		it("fills rows left to right, top to bottom by default", function()
			local offsets, width, height = ns.DrawerGrid(5, 3, 32, 4, false, false)
			assert.same({ 0, 0 }, offsets[1])
			assert.same({ 72, 0 }, offsets[3])
			assert.same({ 0, -36 }, offsets[4])
			assert.equals(3 * 32 + 2 * 4, width)
			assert.equals(2 * 32 + 4, height)
		end)

		it("mirrors when growing left and up", function()
			local offsets = ns.DrawerGrid(4, 3, 32, 4, true, true)
			assert.same({ -36, 0 }, offsets[2])
			assert.same({ 0, 36 }, offsets[4])
		end)

		it("is narrower than the column count when there are fewer items", function()
			local _, width, height = ns.DrawerGrid(2, 6, 32, 4, false, false)
			assert.equals(68, width)
			assert.equals(32, height)
		end)

		it("is empty for no items", function()
			local offsets, width, height = ns.DrawerGrid(0, 6, 32, 4, false, false)
			assert.same({}, offsets)
			assert.equals(0, width)
			assert.equals(0, height)
		end)
	end)

	describe("MergeCompartmentEntries", function()
		local toc = {
			{ addon = "Details", title = "|cffffaa00Details!|r" },
			{ addon = "Pawn", title = "Pawn" },
		}

		it("keeps TOC entries and drops runtime twins Blizzard made from a TOC", function()
			local merged = ns.MergeCompartmentEntries(toc, { { text = "Pawn" }, { text = "Baganator" } }, {})
			assert.equals(3, #merged)
			assert.equals("toc", merged[1].kind)
			assert.equals("toc", merged[2].kind)
			assert.equals("runtime", merged[3].kind)
			assert.equals("Baganator", merged[3].entry.text)
		end)

		it("hides an entry whose addon already shows a minimap button in the drawer", function()
			local shown = { [ns.CompartmentKey("Details")] = true, [ns.CompartmentKey("Baganator")] = true }
			local merged = ns.MergeCompartmentEntries(toc, { { text = "Baganator" } }, shown)
			assert.equals(1, #merged)
			assert.equals("Pawn", merged[1].entry.addon)
		end)

		it("ignores colors, case and spaces when matching", function()
			assert.equals(ns.CompartmentKey("details!"), ns.CompartmentKey("|cffffaa00Details!|r"))
			assert.equals(ns.CompartmentKey("Dialogue UI"), ns.CompartmentKey("DialogueUI"))
		end)
	end)
end)
