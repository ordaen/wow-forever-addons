-- Settings as stored values (addons/OrdaenCore/State.lua; design: development/framework/state, «Settings» and
-- «Controls»), on the fake client: what a control reads and writes through `value`: nothing stored at the default,
-- per character or per account, a value that follows a global setting, reset.
local Fake = require("tests.fake.wow")

local DIST = ".ordaen/check/dist"

describe("settings as stored values", function()
	local wow, ns, module, instance

	local function mount(setup)
		module = { name = "OrdaenSpec", ns = {}, cache = {}, db = {}, charDb = {}, Import = function()
			return nil
		end }
		instance = ns.Engine:Mount(nil, ns.Define.Component({ Setup = setup }), 0, {}, ns.Game.Layer.Screen, module,
			ns.Game.ForModule(module))
		ns.Scheduler.Flush()
	end

	before_each(function()
		wow = Fake.New({ dist = DIST, addons = { "OrdaenCore" } })
		wow:Login()
		ns = wow.addons.OrdaenCore.ns
	end)

	-- the spec's component has no file, so its values sit under "component"
	it("stores nothing at the default, and only what differs, in the account's or the character's table", function()
		mount(function()
			ns.Define.Persistent({
				height = { type = "number", default = 60, min = 24, max = 96, step = 1, unit = "px", setting = true },
				compact = { type = "boolean", default = false, setting = true, scope = "character" },
			})
		end)
		local height, compact = instance.state.persistent.height, instance.state.persistent.compact
		assert.are.equal("px", height.spec.unit)
		assert.are.equal(60, height:Get())
		height:Set(60)
		assert.are.same({}, module.db)
		height:Set(80)
		compact:Set(true)
		assert.are.equal(80, height:Peek())
		assert.is_true(compact:Peek())
		assert.are.same({ component = { height = 80 } }, module.db)
		assert.are.same({ component = { compact = true } }, module.charDb)
		height:Reset()
		assert.are.equal(60, height:Peek())
		assert.is_nil(module.db.component.height)
		assert.has_error(function()
			height:Set(200) -- past max
		end)
	end)

	it("follows its global setting until it has a value of its own, and Reset follows again", function()
		local global = ns.NewValue(14)
		local reads = 0
		mount(function(game, self)
			ns.Define.Persistent({
				textSize = { type = "number", default = 12, min = 8, max = 32, setting = true, follows = global },
			})
			self:Watch(function()
				reads = reads + 1
				local _ = self.state.persistent.textSize:Get()
			end)
		end)
		local size = instance.state.persistent.textSize
		assert.is_true(size:Follows())
		assert.are.equal(14, size:Peek())
		local before = reads
		global:Set(16) -- the global changed: what reads the setting runs again
		ns.Scheduler.Flush()
		assert.are.equal(16, size:Peek())
		assert.are.equal(before + 1, reads)
		size:Set(16) -- a value of its own, though equal to the global's
		assert.is_false(size:Follows())
		assert.are.equal(16, module.db.component.textSize)
		global:Set(20)
		ns.Scheduler.Flush()
		assert.are.equal(16, size:Peek())
		size:Reset()
		assert.is_true(size:Follows())
		assert.are.equal(20, size:Peek())
		assert.is_nil(module.db.component.textSize)
		assert.are.same({}, wow.errors)
	end)
end)
