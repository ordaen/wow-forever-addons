local helpers = require("tests.OrdaenCore.helpers")

describe("OrdaenCore", function()
	local Core

	before_each(function()
		helpers.stubGlobals()
		Core = helpers.loadCore()
	end)

	it("publishes the global API", function()
		assert.are.equal(Core, rawget(_G, "OrdaenCore"))
		assert.are.equal("1.2.3", Core.version)
	end)

	it("is a dev build in a git checkout (packager token not replaced)", function()
		assert.is_true(Core.isDevBuild)
	end)

	describe("CompareVersions", function()
		it("compares numerically, part by part", function()
			assert.are.equal(0, Core.CompareVersions("1.2.3", "1.2.3"))
			assert.are.equal(-1, Core.CompareVersions("0.9.0", "0.10.0"))
			assert.are.equal(1, Core.CompareVersions("2.0.0", "1.99.99"))
			assert.are.equal(0, Core.CompareVersions("1.2", "1.2.0"))
			assert.are.equal(-1, Core.CompareVersions("1.2", "1.2.1"))
		end)
	end)

	describe("IsCompatible", function()
		local messages

		before_each(function()
			messages = {}
			rawset(_G, "DEFAULT_CHAT_FRAME", {
				AddMessage = function(_, msg)
					messages[#messages + 1] = msg
				end,
			})
			Core.isDevBuild = false -- behave like a packaged release
		end)

		it("passes when the addon declares no minimum", function()
			assert.is_true(Core.IsCompatible("TestAddon"))
		end)

		it("passes when the Core is new enough", function()
			helpers.metadata.TestAddon["X-Ordaen-MinCore"] = "1.2.0"
			assert.is_true(Core.IsCompatible("TestAddon"))
		end)

		it("fails and warns once when the Core is too old", function()
			helpers.metadata.TestAddon["X-Ordaen-MinCore"] = "1.10.0"
			assert.is_false(Core.IsCompatible("TestAddon"))
			assert.is_false(Core.IsCompatible("TestAddon"))
			assert.are.equal(1, #messages)
			assert.truthy(messages[1]:find("Test Addon needs Ordaen Core 1.10.0", 1, true))
		end)

		it("always passes in a dev checkout", function()
			Core.isDevBuild = true
			helpers.metadata.TestAddon["X-Ordaen-MinCore"] = "99.0.0"
			assert.is_true(Core.IsCompatible("TestAddon"))
		end)
	end)

	describe("debug API without the debug module (players)", function()
		local Debug, printed

		before_each(function()
			printed = {}
			Debug = Core.NewDebug("TestAddon")
			Debug.Init({}, {
				slash = "/t",
				print = function(msg)
					printed[#printed + 1] = msg
				end,
			})
		end)

		it("is off and records nothing", function()
			assert.is_false(Core.debugMode)
			assert.is_false(Debug.IsEnabled())
			local db = {}
			Debug.Init(db, {})
			Debug.Log("x")
			Debug.RecordError("x")
			Debug.Dump()
			assert.are.same({}, db)
		end)

		it("leaves functions unwrapped so errors take the normal path", function()
			local function fn() end
			assert.are.equal(fn, Debug.Wrap(fn))
			assert.has_error(function()
				Debug.Call(error, "boom")
			end, "boom")
			local a, b = Debug.Call(function(x)
				return x, 2
			end, 1)
			assert.are.same({ 1, 2 }, { a, b })
		end)

		it("answers debug commands with a hint and leaves the rest to the addon", function()
			assert.is_true(Debug.HandleSlash("errors"))
			assert.truthy(printed[1]:find("Ordaen Core - Debug", 1, true))
			assert.is_false(Debug.HandleSlash("columns 4"))
			assert.is_false(Debug.HandleSlash(""))
			assert.truthy(Debug.HelpLines()[1]:find("/t debug", 1, true))
		end)
	end)
end)
