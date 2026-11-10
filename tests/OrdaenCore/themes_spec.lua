-- Themes (addons/OrdaenCore/Themes.lua) on the fake client, as built from themes.jsonc: the three presets, a built-in
-- theme storing only what changed, own themes as copies (capped, renamed, deleted), the active theme's values in the
-- backend's tokens, and a change re-applying them once.
local Fake = require("tests.fake.wow")

local DIST = ".ordaen/check/dist"

describe("themes", function()
	local wow, ns, Themes

	before_each(function()
		wow = Fake.New({ dist = DIST, addons = { "OrdaenCore" } })
		wow:Login()
		ns = wow.addons.OrdaenCore.ns
		Themes = ns.Game.Themes
	end)

	it("ships three, Ordaen's active, its values in the backend's tokens", function()
		local ids = {}
		for i, theme in ipairs(Themes:List()) do
			ids[i] = theme.id
		end
		assert.are.same({ "ordaen", "blizzard", "minimal" }, ids)
		assert.are.equal("ordaen", Themes:Active().id)
		assert.is_truthy(ns.Theme["font.body"]:find("FiraSans%-Regular"))
		assert.are.same({ 0.72, 0.56, 0.34, 1 }, ns.Theme["color.accent"])
		assert.are.same(ns.Theme["color.palette.tanText"], Themes.ClassColor("WARRIOR"))
		assert.are.same({}, wow.errors)
	end)

	it("stores only what the player changed in a built-in theme, and Сбросить clears it", function()
		local ordaen = Themes:Get("ordaen")
		ordaen.values.accent:Set({ 0.72, 0.56, 0.34 }) -- the preset's own: nothing stored
		assert.is_nil(wow.env.OrdaenCoreDB["theme.ordaen"])
		ordaen.values.font:Set("ptSans")
		assert.are.same({ font = "ptSans" }, wow.env.OrdaenCoreDB["theme.ordaen"])
		ns.Scheduler.Flush()
		assert.is_truthy(ns.Theme["font.body"]:find("PTSans%-Regular"))
		ordaen:ResetAll()
		assert.is_nil(next(wow.env.OrdaenCoreDB["theme.ordaen"] or {}))
		assert.has_error(function()
			ordaen.values.font:Set("comicSans")
		end)
	end)

	it("switches with the theme setting, re-applying once", function()
		local fired = 0
		ns.Stage.ThemeChanged:Subscribe(function()
			fired = fired + 1
		end, false)
		ns.Game.Settings.theme:Set("blizzard")
		ns.Scheduler.Flush()
		assert.are.equal(1, fired)
		assert.are.equal(wow.env.STANDARD_TEXT_FONT, ns.Theme["font.body"])
		assert.are.same({ 1, 0.82, 0, 1 }, ns.Theme["color.accent"])
	end)

	it("copies a theme as the player's own, renames and deletes it, at most ten", function()
		local copy = Themes:Get("blizzard"):Copy()
		assert.is_false(copy.builtin)
		assert.are.equal("blizzard", copy.values.barTexture:Get())
		ns.Game.Settings.theme:Set(copy.id)
		copy:Rename("   Моя очень длинная тема для рейдов и подземелий   ")
		assert.are.equal("Моя очень длинная тема д", copy:Name())
		copy:Rename("  ")
		assert.are.equal("Тема 1", copy:Name():gsub("Theme", "Тема"))
		copy:Delete()
		assert.is_nil(Themes:Get(copy.id))
		assert.are.equal("ordaen", Themes:Active().id)
		for _ = 1, 10 do
			assert.is_table(Themes:Get("ordaen"):Copy())
		end
		assert.is_nil(Themes:Get("ordaen"):Copy())
		assert.are.same({}, wow.errors)
	end)

	it("labels its values by the build's keys", function()
		local v = Themes:Get("ordaen").values
		assert.are.equal("THEME_PALETTE_RED", v["palette.red"]:Label())
		assert.are.equal("THEME_FONT_FIRASANS", v.fontHeader:ChoiceLabel("firaSans"))
		assert.are.equal("firaSans", v.font:Choices()[1])
	end)

	it("is followed by a module's asset setting until it has its own value", function()
		local module = { name = "OrdaenSpec", ns = { locales = {} }, cache = {}, db = {}, charDb = {},
			Import = function()
				return nil
			end }
		local instance = ns.Engine:Mount(nil, ns.Define.Component({ Setup = function()
			ns.Define.Persistent({ xpFill = { type = "asset", kind = "xpFill", setting = true,
				follows = ns.Define.Theme.xpFill } })
		end }), 0, {}, ns.Game.Layer.Screen, module, ns.Game.ForModule(module))
		local xpFill = instance.state.persistent.xpFill
		assert.are.equal("brushed", xpFill:Get())
		assert.is_true(xpFill:Follows())
		Themes:Get("ordaen").values.xpFill:Set("steel")
		assert.are.equal("steel", xpFill:Get())
		ns.Game.Settings.theme:Set("minimal")
		assert.are.equal("brushed", xpFill:Get()) -- the new theme's
		xpFill:Set("clouds")
		assert.is_false(xpFill:Follows())
		assert.are.equal("clouds", xpFill:Get())
		assert.has_error(function()
			xpFill:Set("velvet")
		end)
		assert.are.equal("deep", xpFill:Choices()[1])
		assert.are.equal("THEME_XPFILL_STEEL", xpFill:ChoiceLabel("steel"):gsub("Сталь", "THEME_XPFILL_STEEL"))
		xpFill:Follow()
		assert.are.equal("brushed", xpFill:Get())
		assert.are.same({}, wow.errors)
	end)
end)
