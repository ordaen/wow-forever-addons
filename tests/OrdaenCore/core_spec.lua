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

	it("returns one debug instance per addon", function()
		local a = Core.NewDebug("TestAddon")
		assert.are.equal(a, Core.NewDebug("TestAddon"))
		assert.are_not.equal(a, Core.NewDebug("OtherAddon"))
	end)
end)
