-- Loads an addon file the way WoW does: as a chunk called with (addonName, namespaceTable).
local function loadInto(ns, path)
	assert(loadfile(path))("OrdaenMinimap", ns)
	return ns
end

describe("OrdaenMinimap borders", function()
	local ns

	before_each(function()
		ns = loadInto({}, "addons/OrdaenMinimap/Borders.lua")
	end)

	describe("BORDER_STYLES", function()
		it("has unique ids, a label and a sane outset for each style", function()
			local seen = {}
			for _, style in ipairs(ns.BORDER_STYLES) do
				assert.is_nil(seen[style.id], "duplicate id " .. tostring(style.id))
				seen[style.id] = true
				assert.is_string(style.label)
				if style.backdrop then
					assert.is_string(style.backdrop.edgeFile)
					assert.is_number(style.backdrop.edgeSize)
					assert.is_true((style.outset or 0) >= 0)
				end
			end
		end)

		it("includes the default style", function()
			assert.equals(ns.DEFAULTS.borderStyle, ns.GetBorderStyle(ns.DEFAULTS.borderStyle).id)
		end)
	end)

	describe("GetBorderStyle", function()
		it("returns the requested style", function()
			assert.equals("thin", ns.GetBorderStyle("thin").id)
			assert.equals("none", ns.GetBorderStyle("none").id)
		end)

		it("falls back to the default for unknown or missing ids", function()
			assert.equals(ns.DEFAULTS.borderStyle, ns.GetBorderStyle("removed-style").id)
			assert.equals(ns.DEFAULTS.borderStyle, ns.GetBorderStyle(nil).id)
		end)
	end)

	describe("ResolveBorderColor", function()
		it("leaves textured styles untinted for natural", function()
			assert.is_nil(ns.ResolveBorderColor(ns.GetBorderStyle("gold"), "natural"))
		end)

		it("uses the style's own natural color when it has one", function()
			assert.same({ 0, 0, 0 }, ns.ResolveBorderColor(ns.GetBorderStyle("thin"), "natural"))
		end)

		it("uses a named color", function()
			assert.same({ 1, 0.82, 0 }, ns.ResolveBorderColor(ns.GetBorderStyle("gold"), "gold"))
		end)

		it("uses the class color, and falls back to natural without one", function()
			local style = ns.GetBorderStyle("thin")
			assert.same({ 0.2, 0.4, 0.6 }, ns.ResolveBorderColor(style, "class", { 0.2, 0.4, 0.6 }))
			assert.same({ 0, 0, 0 }, ns.ResolveBorderColor(style, "class", nil))
		end)
	end)

	describe("ApplyDefaults", function()
		it("fills an empty table with the defaults", function()
			assert.same(ns.DEFAULTS, ns.ApplyDefaults({}))
		end)

		it("repairs unknown style/color ids and clamps the scale", function()
			local db = ns.ApplyDefaults({ borderStyle = "nope", borderColor = "nope", scale = 99 })
			assert.equals(ns.DEFAULTS.borderStyle, db.borderStyle)
			assert.equals(ns.DEFAULTS.borderColor, db.borderColor)
			assert.equals(ns.SCALE_MAX, db.scale)
			assert.equals(ns.SCALE_MIN, ns.ApplyDefaults({ scale = 0.1 }).scale)
			assert.equals(ns.DEFAULTS.scale, ns.ApplyDefaults({ scale = "big" }).scale)
		end)

		it("keeps valid values and data from other modules", function()
			local log = { "entry" }
			local db = ns.ApplyDefaults({ borderStyle = "thin", borderColor = "class", scale = 1.2, debugLog = log })
			assert.equals("thin", db.borderStyle)
			assert.equals("class", db.borderColor)
			assert.equals(1.2, db.scale)
			assert.equals(log, db.debugLog)
		end)
	end)
end)

describe("OrdaenMinimap locale", function()
	local ns = loadInto({}, "addons/OrdaenMinimap/Locale.lua")

	it("has a label for every border style and color", function()
		loadInto(ns, "addons/OrdaenMinimap/Borders.lua")
		for _, locale in ipairs({ "enUS", "ruRU" }) do
			local L = ns.BuildLocale(locale)
			for _, list in ipairs({ ns.BORDER_STYLES, ns.BORDER_COLORS }) do
				for _, entry in ipairs(list) do
					assert.are_not.equal(entry.label, L[entry.label], locale .. " misses " .. entry.label)
				end
			end
		end
	end)

	it("translates for ruRU and falls back to English elsewhere", function()
		assert.equals("Стиль рамки", ns.BuildLocale("ruRU").BORDER_STYLE)
		assert.equals("Border style", ns.BuildLocale("deDE").BORDER_STYLE)
		assert.equals("NO_SUCH_KEY", ns.BuildLocale("enUS").NO_SUCH_KEY)
	end)
end)
