-- Ordaen's global settings (addons/OrdaenCore/Globals.lua) on the fake client, as built: read as game.Settings.<name>,
-- stored account-wide in OrdaenCoreDB only when they differ, followed by a module's look setting
-- (`follows = Define.Global.<name>`), reset by `/ordaen ordaen reset`.
local Fake = require("tests.fake.wow")

local DIST = ".ordaen/check/dist"

describe("Ordaen's global settings", function()
	local wow, ns

	before_each(function()
		wow = Fake.New({ dist = DIST, addons = { "OrdaenCore" } })
		wow:Login()
		ns = wow.addons.OrdaenCore.ns
	end)

	it("reads the defaults, stores only what differs in OrdaenCoreDB, and refuses a name it doesn't have", function()
		local settings = ns.Game.Settings
		assert.are.equal(1, settings.scale:Get())
		assert.are.equal("24", settings.clock:Get())
		settings.scale:Set(0.8)
		settings.clock:Set("24")
		assert.are.same({ global = { scale = 0.8 } }, wow.env.OrdaenCoreDB)
		assert.are.equal(settings.scale, ns.Define.Global.scale) -- one value, however it's reached
		assert.has_error(function()
			local _ = ns.Define.Global.textSize
		end)
	end)

	it("is followed by a module's look setting until that has its own value", function()
		local module = { name = "OrdaenSpec", ns = {}, cache = {}, db = {}, charDb = {}, Import = function()
			return nil
		end }
		local instance = ns.Engine:Mount(nil, ns.Define.Component({ Setup = function()
			ns.Define.Persistent({ scale = { type = "number", default = 1, min = 0.7, max = 1.5, setting = true,
				follows = ns.Define.Global.scale } })
		end }), 0, {}, ns.Game.Layer.Screen, module, ns.Game.ForModule(module))
		local own = instance.state.persistent.scale
		ns.Game.Settings.scale:Set(1.2)
		assert.are.equal(1.2, own:Peek())
		own:Set(0.9)
		assert.are.equal(0.9, own:Peek())
		assert.are.same({}, wow.errors)
	end)

	it("lists each choice's values in its menu order, the enum's members exactly", function()
		for name, spec in pairs(ns.Globals.spec) do
			if spec.type == "choice" then
				local members, listed = {}, {}
				for _, value in pairs(spec.choices) do
					members[value] = true
				end
				for _, value in ipairs(spec.order) do
					listed[value] = true
				end
				assert.are.same(members, listed, name)
				assert.are.equal(spec.order, ns.Game.Settings[name]:Choices())
			end
		end
	end)

	it("goes back to its defaults with /ordaen ordaen reset", function()
		ns.Game.Settings.sounds:Set(false)
		assert.is_true(wow:Slash("/ordaen ordaen reset"))
		assert.is_true(ns.Game.Settings.sounds:Peek())
		assert.is_nil(wow.env.OrdaenCoreDB.global.sounds)
	end)
end)
