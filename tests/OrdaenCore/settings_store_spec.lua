-- Ordaen Core's settings store (SettingsStore.lua): only the player's values are saved, every other read is the
-- current theme's default, and a theme switch moves every untouched setting (docs/reference/settings.md).
local helpers = require("tests.OrdaenCore.helpers")

local function schema()
	return {
		db = "TestDB",
		sections = { { keys = { "style", "scale", "enabled", "columns", "visibility.tracking", "angles", "tint" } } },
		settings = {
			style = { type = "choice", choices = { "rim", "gold", "thin" }, themed = true },
			scale = { type = "number", min = 0.8, max = 1.6, step = 0.05 },
			enabled = { type = "boolean" },
			columns = { type = "number", min = 2, max = 12, step = 1 },
			["visibility.tracking"] = { type = "choice", choices = { "always", "hover", "hide" } },
			angles = { type = "map", of = "number", page = false },
			tint = { type = "color" },
		},
		defaults = {
			ordaen = { style = "rim", scale = 1, enabled = true, columns = 6, visibility = { tracking = "always" },
				angles = {}, tint = { 1, 1, 1 } },
			blizzard = { style = "gold", scale = 1, enabled = true, columns = 6, visibility = { tracking = "always" },
				angles = {}, tint = { 1, 1, 1 } },
			minimal = { style = "thin", scale = 1, enabled = true, columns = 6, visibility = { tracking = "hover" },
				angles = {}, tint = { 1, 1, 1 } },
		},
	}
end

-- What WoW writes to the SavedVariables file: raw fields only (no metatables), recursively.
local function saved(t)
	local out = {}
	for k, v in next, t do
		out[k] = type(v) == "table" and saved(v) or v
	end
	return out
end

describe("OrdaenCore settings store", function()
	local Store

	before_each(function()
		helpers.stubGlobals()
		Store = helpers.loadCore()._SettingsStore
		Store._Clear()
	end)

	it("reads the theme's default where the player chose nothing, and saves nothing", function()
		local db = {}
		Store.Bind(schema(), db)
		assert.equals("rim", db.style)
		assert.equals(6, db.columns)
		assert.equals("always", db.visibility.tracking)
		assert.same({ visibility = {}, angles = {} }, saved(db))
	end)

	it("keeps what the player chose, through a theme switch, and moves the rest", function()
		local db = { scale = 1.2 }
		local store = Store.Bind(schema(), db)
		local told = {}
		store.onChange = function(key, value)
			told[#told + 1] = key .. "=" .. tostring(value)
		end
		Store.SetTheme("minimal")
		assert.equals("thin", db.style)
		assert.equals("hover", db.visibility.tracking)
		assert.equals(1.2, db.scale)
		table.sort(told)
		assert.same({ "style=thin", "visibility.tracking=hover" }, told)
		assert.same({ scale = 1.2, visibility = {}, angles = {} }, saved(db))
	end)

	it("validates what it saves and drops saved values the schema refuses", function()
		local db = { style = "neon", columns = 6.5, enabled = "yes", angles = { drawer = 90, bad = "x" } }
		local store = Store.Bind(schema(), db)
		assert.equals("rim", db.style)
		assert.equals(6, db.columns)
		assert.is_true(db.enabled)
		assert.same({ drawer = 90 }, saved(db).angles)
		assert.is_false(store:Set("scale", 3))
		assert.is_false(store:Set("style", "neon"))
		assert.is_true(store:Set("style", "gold"))
		assert.equals("gold", db.style)
		assert.is_true(store:IsChanged("style"))
	end)

	it("writes into the player's own nested tables, never into the defaults", function()
		local db = {}
		Store.Bind(schema(), db)
		db.angles.drawer = 120
		db.visibility.tracking = "hide"
		local other = {}
		Store.Bind(schema(), other)
		assert.is_nil(other.angles.drawer)
		assert.equals("always", other.visibility.tracking)
	end)

	it("resets one setting or all of them to the theme's default, keeping the migration count", function()
		local db = { _schema = 2, style = "gold", columns = 9, angles = { drawer = 10 } }
		local store = Store.Bind(schema(), db)
		store:Reset("style")
		assert.equals("rim", db.style)
		store:ResetAll()
		assert.equals(6, db.columns)
		assert.is_nil(db.angles.drawer)
		assert.equals(2, db._schema)
	end)

	it("gets dotted keys", function()
		local store = Store.Bind(schema(), {})
		assert.equals("always", store:Get("visibility.tracking"))
		assert.is_false(store:IsChanged("visibility.tracking"))
	end)
end)
