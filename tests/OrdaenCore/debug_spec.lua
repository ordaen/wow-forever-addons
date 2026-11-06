local helpers = require("tests.OrdaenCore.helpers")

describe("OrdaenCore_Debug per-addon kit (dev mode)", function()
	local Core, Store, Debug, printed

	before_each(function()
		helpers.stubGlobals()
		Core = helpers.loadCore(true)
		Store = helpers.debugNs.Store
		Store.Load(nil, {})
		printed = {}
		Debug = Core.NewDebug("TestAddon")
		Debug.Init({}, {
			slash = "/t",
			print = function(...)
				printed[#printed + 1] = table.concat({ ... }, " ")
			end,
		})
	end)

	it("replaces the stand-in, one instance per addon", function()
		assert.is_true(Core.debugMode)
		assert.are.equal(Debug, Core.NewDebug("TestAddon"))
		assert.are_not.equal(Debug, Core.NewDebug("OtherAddon"))
		assert.are.equal(Debug, helpers.debugNs.instances.TestAddon)
	end)

	it("keeps the addon's own SavedVariables clean", function()
		local db = {}
		Debug.Init(db, {})
		Debug.Log("x")
		Debug.Dump()
		assert.are.same({}, db)
	end)

	describe("Log", function()
		it("records timestamped lines, on by default", function()
			assert.is_true(Debug.IsEnabled())
			Debug.Log("hello", 42, nil)
			local log = Store.Addon("TestAddon").log
			assert.truthy(log[#log]:match("^%d%d:%d%d:%d%d%.500 hello 42 nil$"), log[#log])
		end)

		it("does nothing while switched off, and echoes to chat when asked", function()
			local addon = Store.Addon("TestAddon")
			addon.logging = false
			local before = #addon.log
			Debug.Log("quiet")
			Debug.Logf("%s", "quiet")
			assert.are.equal(before, #addon.log)
			addon.logging, addon.echo = true, true
			Debug.Logf("loud %d", 1)
			assert.truthy(printed[#printed]:find("loud 1", 1, true))
		end)
	end)

	describe("Call and Wrap", function()
		it("return results, including nil holes", function()
			local a, b, c = Debug.Call(function(x)
				return x, nil, 3
			end, 1)
			assert.are.same({ 1, nil, 3 }, { a, b, c })
			assert.are.equal(5, Debug.Wrap(function(x)
				return x + 1
			end)(4))
		end)

		it("record an error once and hand it on once", function()
			local result = Debug.Call(error, "kaboom", 0)
			assert.is_nil(result)
			assert.are.equal("kaboom", Store.Get().errors[1].message)
			assert.are.same({ "kaboom" }, helpers.forwarded)
		end)
	end)

	describe("Snapshot and Dump", function()
		it("keeps plain values, cuts cycles and deep tables, keeps shared tables", function()
			local shared = { v = 1 }
			local t = { a = 1, f = print, deep = { deeper = { deepest = {} } }, s1 = shared, s2 = shared }
			t.self = t
			local snap = Debug.Snapshot(t, 2)
			assert.are.equal(1, snap.a)
			assert.are.equal("<function>", snap.f)
			assert.are.equal("<cycle>", snap.self)
			assert.are.equal("<table>", snap.deep.deeper)
			assert.are.same({ v = 1 }, snap.s1)
			assert.are.same({ v = 1 }, snap.s2)
		end)

		it("describes widgets instead of copying them", function()
			local parent = {
				GetObjectType = function()
					return "Frame"
				end,
				GetName = function()
					return "Minimap"
				end,
			}
			local button = {
				GetObjectType = function()
					return "Button"
				end,
				GetName = function()
					return "LibDBIcon10_Test"
				end,
				GetParent = function()
					return parent
				end,
				GetSize = function()
					return 31.333, 31
				end,
				GetNumPoints = function()
					return 1
				end,
				GetPoint = function()
					return "TOPLEFT", parent, "BOTTOMLEFT", 1.25, -2
				end,
				GetFrameLevel = function()
					error("boom")
				end,
			}
			local snap = Debug.Snapshot({ button = button })
			assert.are.equal("Button", snap.button.widget)
			assert.are.equal("Minimap", snap.button.parent)
			assert.are.equal("31.33x31", snap.button.size)
			assert.are.same({ "TOPLEFT Minimap BOTTOMLEFT 1.25 -2" }, snap.button.points)
			assert.is_nil(snap.button.level)
		end)

		it("stores the addon's dump in the dev data", function()
			Debug.Init({}, {
				dump = function()
					return { columns = 4 }
				end,
			})
			Debug.Dump()
			local dump = Store.Addon("TestAddon").dump
			assert.are.same({ columns = 4 }, dump.state)
			assert.are.equal(Store.Session(), dump.session)
		end)

		it("records a failing dump instead of raising", function()
			Debug.Init({}, {
				dump = function()
					error("no state", 0)
				end,
			})
			assert.are.equal("dump failed: no state", Debug.Dump().state)
		end)
	end)

	describe("HandleSlash", function()
		it("opens the window on 'debug' and leaves the rest to the addon", function()
			assert.is_true(Debug.HandleSlash("  DEBUG"))
			assert.is_true(rawget(_G, "OrdaenDevWindow"):IsShown())
			assert.is_false(Debug.HandleSlash("reset"))
			assert.is_false(Debug.HandleSlash(""))
			assert.truthy(Debug.HelpLines()[1]:find("/t debug", 1, true))
		end)
	end)
end)
