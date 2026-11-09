-- Bindings (addons/OrdaenCore/Binding.lua) on the fake client, as built: drawing calls in the form the build compiles
-- them to, `game.ui:Text(site, nil, call, key)` with a frozen call table whose `bind` maps fields to shared
-- expressions. A change to what an expression read rewrites its fields without re-running the render; one
-- expression feeding two fields runs once; a released entry's bindings stop.
local Fake = require("tests.fake.wow")

local DIST = ".ordaen/check/dist"

describe("bindings", function()
	local wow, ns, values, renders, runs, freeze, instance

	local function mount(declaration)
		local module = { name = "OrdaenSpec", ns = {}, cache = {}, Import = function()
			return nil
		end }
		instance = ns.Engine:Mount(nil, declaration, 0, {}, ns.Game.Layer.Screen, module, ns.Game.ForModule(module))
		ns.Scheduler.Flush()
	end

	local function texts()
		local out = {}
		local function walk(node)
			if node.kind == "text" then
				out[#out + 1] = node.fs:GetText()
			end
			for i = 1, node.count or 0 do
				walk(node.children[i])
			end
		end
		walk(ns.Game.Layer.Screen.node)
		return out
	end

	before_each(function()
		wow = Fake.New({ dist = DIST, addons = { "OrdaenCore" } })
		wow:Login()
		ns = wow.addons.OrdaenCore.ns
		freeze = wow.env.table.freeze
		values, renders, runs = {}, 0, 0
		for i = 1, 5 do
			values[i] = ns.NewValue(i * 10)
		end
	end)

	it("keeps each keyed text current without re-running the render", function()
		local expr = function(_, _, item)
			runs = runs + 1
			return tostring(values[item]:Get())
		end
		local CALL = freeze({ attributes = freeze({ textSize = 12 }), bind = freeze({ text = expr }) })
		mount(ns.Define.Component({
			Render = function(game)
				renders = renders + 1
				for i = 1, #values do
					game.ui:Text(1, nil, CALL, i)
				end
			end,
		}))
		assert.are.same({ "10", "20", "30", "40", "50" }, texts())
		assert.are.equal(1, renders)
		assert.are.equal(5, runs)
		values[3]:Set(99)
		ns.Scheduler.Flush()
		assert.are.same({ "10", "20", "99", "40", "50" }, texts())
		assert.are.equal(1, renders) -- the render didn't run
		assert.are.equal(6, runs) -- only the third text's expression did
		assert.are.same({}, wow.errors)
	end)

	it("runs an expression that feeds two fields once, and writes both", function()
		local size = ns.NewValue(30)
		local expr = function()
			runs = runs + 1
			return size:Get()
		end
		local CALL = freeze({ attributes = freeze({ background = "Interface\\Buttons\\WHITE8X8" }),
			bind = freeze({ width = expr, height = expr }) })
		local node
		local Create = ns.Backend.Create
		ns.Backend.Create = function(backend, kind)
			local n = Create(backend, kind)
			node = node or n
			return n
		end
		mount(ns.Define.Component({
			Render = function(game)
				renders = renders + 1
				game.ui:Box(1, nil, CALL)
			end,
		}))
		ns.Backend.Create = Create
		assert.are.equal(1, runs)
		assert.are.equal(30, node.a.width)
		assert.are.equal(30, node.a.height)
		size:Set(50)
		ns.Scheduler.Flush()
		assert.are.equal(2, runs)
		assert.are.equal(50, node.a.width)
		assert.are.equal(50, node.a.height)
		assert.are.equal(1, renders)
		assert.are.same({}, wow.errors)
	end)

	it("stops a released entry's binding", function()
		local shown = ns.NewValue(5)
		local expr = function(_, _, item)
			runs = runs + 1
			return tostring(values[item]:Get())
		end
		local CALL = freeze({ attributes = freeze({ textSize = 12 }), bind = freeze({ text = expr }) })
		mount(ns.Define.Component({
			Render = function(game)
				for i = 1, shown:Get() do
					game.ui:Text(1, nil, CALL, i)
				end
			end,
		}))
		shown:Set(2) -- texts 3 to 5 released
		ns.Scheduler.Flush()
		assert.are.same({ "10", "20" }, texts())
		local before = runs
		values[4]:Set(1)
		values[5]:Set(1)
		ns.Scheduler.Flush()
		assert.are.equal(before, runs) -- nobody read them any more
		values[1]:Set(7)
		ns.Scheduler.Flush()
		assert.are.same({ "7", "20" }, texts())
		assert.are.same({}, wow.errors)
	end)
end)
