-- Ordaen Core's settings store (SettingsStore.lua): only the player's values are saved, every other read is the
-- current theme's default, and a theme switch moves every untouched setting (docs/reference/settings.md).
local helpers = require("tests.OrdaenCore.helpers")

-- The shared part of the themes (THEME_TOKENS, from OrdaenCore/themes.jsonc), as the build generates it.
local TOKENS = {
	assets = { frame = { rim = {}, gold = {}, thin = {} } },
	tokens = { ["frame.border"] = "frame", ["color.accent"] = "color", ["motion.fade"] = "number" },
	themes = {
		ordaen = { ["frame.border"] = "rim", ["color.accent"] = { 0.72, 0.56, 0.34 }, ["motion.fade"] = 0.15 },
		blizzard = { ["frame.border"] = "gold", ["color.accent"] = { 1, 0.82, 0 }, ["motion.fade"] = 0.2 },
		minimal = { ["frame.border"] = "thin", ["color.accent"] = { 1, 0.82, 0 }, ["motion.fade"] = 0 },
	},
}

-- An addon's SETTINGS_SCHEMA as the build generates it: look settings follow theme tokens, the rest have plain
-- defaults.
local function schema()
	return {
		db = "TestDB",
		sections = { { keys = { "style", "scale", "enabled", "columns", "visibility.tracking", "angles", "tint",
			"fade" } } },
		settings = {
			style = { type = "asset", of = "frame", theme = "frame.border" },
			scale = { type = "number", min = 0.8, max = 1.6, step = 0.05, default = 1 },
			enabled = { type = "boolean", default = true },
			columns = { type = "number", min = 2, max = 12, step = 1, default = 6 },
			["visibility.tracking"] = { type = "choice", choices = { "always", "hover", "hide" }, default = "always" },
			angles = { type = "map", of = "number", default = {}, page = false },
			tint = { type = "color", theme = "color.accent" },
			fade = { type = "number", min = 0, max = 1, step = 0.05, theme = "motion.fade" },
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
		Store.SetTokens(TOKENS)
	end)

	it("reads the theme's default where the player chose nothing, and saves nothing", function()
		local db = {}
		Store.Bind(schema(), db)
		assert.equals("rim", db.style) -- the theme's frame
		assert.equals(0.15, db.fade)
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
		assert.equals(0, db.fade)
		assert.equals(1.2, db.scale)
		table.sort(told)
		-- Blizzard's and minimal's accents are the same colour: not announced.
		assert.same({ "fade=0", "style=thin", "tint=table" }, (function()
			for i, t in ipairs(told) do
				told[i] = t:gsub("table: .*", "table")
			end
			return told
		end)())
		assert.same({ scale = 1.2, visibility = {}, angles = {} }, saved(db))
	end)

	it("validates what it saves and drops saved values the schema refuses", function()
		local db = { style = "neon", columns = 6.5, enabled = "yes", angles = { drawer = 90, bad = "x" } } -- no "neon" frame
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

	it("lets the player pick another theme's asset for one addon, kept through theme switches", function()
		local db = {}
		local store = Store.Bind(schema(), db)
		assert.is_true(store:Set("style", "gold")) -- Blizzard's frame while the theme is ordaen
		Store.SetTheme("minimal")
		assert.equals("gold", db.style)
		store:Reset("style")
		assert.equals("thin", db.style)
	end)

	it("reads theme tokens and assets for code that draws", function()
		assert.same({ 0.72, 0.56, 0.34 }, Store.Token("color.accent"))
		assert.is_table(Store.Asset("frame", "rim"))
		assert.is_nil(Store.Asset("frame", "neon"))
	end)
end)
