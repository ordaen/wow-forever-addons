-- Colour settings on the settings page (Settings.lua): Blizzard's colour swatch (Settings.CreateColorSwatch) holds a
-- hex string "aarrggbb" and opens ColorPickerFrame; the store holds { r, g, b[, a] } and saves only the player's
-- choice. Blizzard's control code (Blizzard_SettingControls.lua) writes the value on every picker move, on Cancel
-- (the old colour) and on Defaults (the setting's default).
local helpers = require("tests.OrdaenCore.helpers")

local TOKENS = {
	assets = {},
	tokens = { ["color.accent"] = "color" },
	themes = { ordaen = { ["color.accent"] = { 0.72, 0.56, 0.34 } } },
}

local function schema()
	return {
		db = "TestDB",
		sections = { { keys = { "tint" } } },
		settings = {
			tint = { type = "color", theme = "color.accent", label = "TINT", tooltip = "TINT_TOOLTIP" },
		},
	}
end

describe("OrdaenCore settings page colours", function()
	local Core, Store, proxies, swatches

	before_each(function()
		proxies, swatches = {}, {}
		helpers.stubGlobals({
			Settings = {
				RegisterVerticalLayoutCategory = function(name)
					return { name = name }, nil
				end,
				RegisterProxySetting = function(_, variable, varType, name, default, get, set)
					local proxy = { variable = variable, varType = varType, name = name, default = default,
						get = get, set = set }
					proxies[variable] = proxy
					return proxy
				end,
				CreateColorSwatch = function(_, setting, tooltip)
					local init = { setting = setting, tooltip = tooltip }
					swatches[#swatches + 1] = init
					return init
				end,
				RegisterAddOnCategory = function() end,
			},
		})
		Core = helpers.loadCore()
		Store = Core._SettingsStore
		Store._Clear()
		Store.SetTokens(TOKENS)
	end)

	it("converts between our colours and the swatch's hex strings", function()
		local Page = Core.Settings
		assert.equals("ffb88f57", Page.ColorToHex({ 0.72, 0.56, 0.34 }))
		assert.equals("ff000000", Page.ColorToHex({ -1, 0, 0 })) -- clamped
		assert.equals("ffffffff", Page.ColorToHex({ 1, 1, 1, 0.5 })) -- no alpha on the swatch
		local c = Page.HexToColor("00ff8000", 0.5)
		assert.same({ 1, 128 / 255, 0, 0.5 }, c)
		assert.is_nil(Page.HexToColor("ff8000"))
		assert.is_nil(Page.HexToColor(nil))
	end)

	it("puts a colour setting on the page as Blizzard's swatch, writing through the store", function()
		local db = {}
		local store = Store.Bind(schema(), db)
		local addon = {
			name = "TestAddon",
			L = setmetatable({}, { __index = function(_, k) return k end }),
			_store = store,
			Debug = helpers.strictDebug(Core.NewDebug("TestAddon")),
		}
		Core.Settings.RegisterSchema(addon, schema())

		assert.equals(1, #swatches)
		local proxy = proxies.TestAddon_tint
		assert.equals("string", proxy.varType)
		assert.equals("TINT", proxy.name)
		assert.equals("TINT_TOOLTIP", swatches[1].tooltip)
		assert.equals("ffb88f57", proxy.default) -- the theme's colour
		assert.equals("ffb88f57", proxy.get())
		assert.is_nil(rawget(db, "tint"))

		-- picking a colour (Blizzard's colour string: alpha byte 00) saves it
		proxy.set("00ff0000")
		assert.same({ 1, 0, 0 }, rawget(db, "tint"))
		assert.equals("ffff0000", proxy.get())
		assert.is_true(store:IsChanged("tint"))

		-- the theme's colour again (Defaults, or Cancel back to it) is "not chosen": nothing saved
		proxy.set("ffb88f57")
		assert.is_nil(rawget(db, "tint"))
		assert.is_false(store:IsChanged("tint"))

		-- garbage is ignored
		proxy.set("nope")
		assert.is_nil(rawget(db, "tint"))
	end)

	it("keeps a saved colour's alpha when the swatch (which has none) changes it", function()
		local db = { tint = { 0, 0, 1, 0.4 } }
		local store = Store.Bind(schema(), db)
		local addon = {
			name = "TestAddon",
			L = setmetatable({}, { __index = function(_, k) return k end }),
			_store = store,
			Debug = helpers.strictDebug(Core.NewDebug("TestAddon")),
		}
		Core.Settings.RegisterSchema(addon, schema())
		proxies.TestAddon_tint.set("0000ff00")
		assert.same({ 0, 1, 0, 0.4 }, rawget(db, "tint"))
	end)
end)
