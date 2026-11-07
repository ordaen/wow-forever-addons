-- OrdaenCore.Colors: the palette every Ordaen addon uses (addons/OrdaenCore/Colors.lua), read from Ordaen Core's
-- settings (CoreSettings.lua): the theme's defaults, the player's picks, each class's palette colour.
local helpers = require("tests.OrdaenCore.helpers")

describe("OrdaenCore.Colors", function()
	local Core, Colors

	local function fire(event, ...)
		for i = #helpers.created, 1, -1 do
			local frame = helpers.created[i]
			if frame.scripts.OnEvent then
				frame.scripts.OnEvent(frame, event, ...)
				return
			end
		end
		error("no event frame yet")
	end

	-- Ordaen Core's own addon object (its settings).
	local function coreAddon()
		for _, addon in ipairs(Core._addons) do
			if addon.name == "OrdaenCore" then
				return addon
			end
		end
	end

	local function load(saved)
		rawset(_G, "OrdaenCoreDB", saved)
		helpers.stubGlobals()
		Core = helpers.loadCore()
		Colors = Core.Colors
		fire("ADDON_LOADED", "OrdaenCore")
	end

	after_each(function()
		rawset(_G, "OrdaenCoreDB", nil)
	end)

	it("has the theme's eleven colours, a bar and a text tone each", function()
		load(nil)
		assert.same({ "red", "orange", "yellow", "green", "cyan", "blue", "violet", "pink", "tan", "white", "grey" },
			Colors:Names())
		local tokens = Core._SettingsStore
		for _, name in ipairs(Colors:Names()) do
			local bar, text = Colors:Get(name), Colors:Text(name)
			local barToken, textToken = tokens.Token("color.palette." .. name), tokens.Token("color.palette." .. name .. ".text")
			assert.same({ barToken[1], barToken[2], barToken[3] }, { bar[1], bar[2], bar[3] }, name)
			assert.same({ textToken[1], textToken[2], textToken[3] }, { text.r, text.g, text.b }, name)
		end
		assert.is_nil(Colors:Get("magenta"))
	end)

	it("gives each of Forever's nine classes its palette colour by default, and nothing for other classes", function()
		load(nil)
		local defaults = { WARRIOR = "tan", PALADIN = "pink", HUNTER = "green", ROGUE = "yellow", PRIEST = "white",
			SHAMAN = "blue", MAGE = "cyan", WARLOCK = "violet", DRUID = "orange" }
		for classFile, name in pairs(defaults) do
			assert.equals(name, Colors:ClassName(classFile))
			assert.equals(Colors:Get(name), Colors:Class(classFile), "the palette's own table")
			assert.equals(Colors:Text(name), Colors:ClassText(classFile))
		end
		assert.is_nil(Colors:Class("DEATHKNIGHT"), "not a class on Forever")
	end)

	it("uses the player's picks: a tone and a class's colour", function()
		load({ palette = { red = { 0.5, 0.1, 0.1 } }, class = { ROGUE = "orange" } })
		assert.same({ 0.5, 0.1, 0.1 }, { Colors:Get("red"):GetRGB() })
		assert.equals("ff801a1a", Colors:Get("red"):Hex())
		assert.equals(Colors:Get("orange"), Colors:Class("ROGUE"))
	end)

	it("updates the same tables in place when the player picks again, and tells the listeners", function()
		load(nil)
		local blue, mage = Colors:Get("blue"), Colors:ClassText("MAGE")
		local heard = 0
		local function onChange()
			heard = heard + 1
		end
		Colors:On("change", onChange)
		Colors:On("change", onChange) -- once only
		local A = coreAddon()
		assert.is_true(A:Set("palette.blue", { 0.1, 0.2, 0.9 }))
		assert.equals(1, heard)
		assert.equals(blue, Colors:Get("blue"), "same table: addons may keep it")
		assert.same({ 0.1, 0.2, 0.9 }, { blue[1], blue[2], blue[3] })
		assert.is_true(A:Set("class.MAGE", "violet"))
		assert.equals(Colors:Text("violet"), Colors:ClassText("MAGE"))
		assert.not_equals(mage, Colors:ClassText("MAGE"))
		A:Reset("palette.blue")
		local token = Core._SettingsStore.Token("color.palette.blue")
		assert.same({ token[1], token[2], token[3] }, { blue[1], blue[2], blue[3] }, "the theme's again")
		Colors:Off("change", onChange)
		A:Set("palette.red", { 1, 0, 0 })
		assert.equals(3, heard, "not after Off")
	end)

	it("changes only the tone the player picked (a picker drag writes several times a second)", function()
		load(nil)
		local before = {}
		for _, name in ipairs(Colors:Names()) do
			local bar, text = Colors:Get(name), Colors:Text(name)
			before[name] = { bar[1], bar[2], bar[3], text[1], text[2], text[3], bar:Hex(), text:Hex() }
		end
		local A = coreAddon()
		A:Set("palette.greenText", { 0.2, 0.9, 0.2 })
		for _, name in ipairs(Colors:Names()) do
			local bar, text = Colors:Get(name), Colors:Text(name)
			local now = { bar[1], bar[2], bar[3], text[1], text[2], text[3], bar:Hex(), text:Hex() }
			if name == "green" then
				assert.same(before[name][1], now[1], "green's bar tone stays")
				assert.same({ 0.2, 0.9, 0.2 }, { now[4], now[5], now[6] })
			else
				assert.same(before[name], now, name)
			end
		end
		A:Set("class.DRUID", "red")
		assert.equals("red", Colors:ClassName("DRUID"))
		assert.equals("yellow", Colors:ClassName("ROGUE"), "the other classes stay")
	end)

	it("doesn't restyle every Ordaen surface for a colour (only ui.* settings do)", function()
		load(nil)
		local restyled = 0
		Core.UI._SettingsChanged = function()
			restyled = restyled + 1
		end
		local A = coreAddon()
		A:Set("palette.blue", { 0.1, 0.2, 0.9 })
		A:Set("class.MAGE", "blue")
		assert.equals(0, restyled)
		A:Set("ui.textSize", 14)
		assert.equals(1, restyled)
	end)

	it("refuses a class colour that isn't in the palette (the default applies)", function()
		load({ class = { ROGUE = "magenta" } })
		assert.equals("yellow", Colors:ClassName("ROGUE"))
	end)
end)
