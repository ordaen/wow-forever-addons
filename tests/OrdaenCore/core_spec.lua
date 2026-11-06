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
		it("is one shared table for every addon, so players pay nothing per addon", function()
			assert.is_false(Core.debugMode)
			assert.are.equal(Core.NewDebug("TestAddon"), Core.NewDebug("OtherAddon"))
		end)

		it("records nothing and touches no settings", function()
			local Debug = Core.NewDebug("TestAddon")
			local db = {}
			Debug:Init(db, { slash = "/t" })
			Debug:Log("x")
			Debug:Logf("%s", "x")
			Debug:Dump()
			Debug:Warn("w")
			Debug:Warnf("%d", 1)
			Debug:Verbose("v")
			Debug:Verbosef("%d", 1)
			Debug:Trace("event", "ZONE_CHANGED")
			Debug:TraceFrame({})
			assert.is_false(Debug:IsEnabled())
			assert.is_false(Debug:TraceEnabled())
			assert.are.same({}, db)
		end)

		it("leaves functions unwrapped so errors take the normal path", function()
			local Debug = Core.NewDebug("TestAddon")
			local function fn() end
			assert.are.equal(fn, Debug:Wrap(fn))
			local t = {}
			assert.are.equal(t, Debug:Snapshot(t))
			assert.has_error(function()
				Debug:Call(error, "boom")
			end, "boom")
			local a, b = Debug:Call(function(x)
				return x, 2
			end, 1)
			assert.are.same({ 1, 2 }, { a, b })
		end)

		it("times nothing but still runs the timed function", function()
			local Debug = Core.NewDebug("TestAddon")
			local t = Debug:TimeStart()
			assert.are.equal(0, t)
			Debug:TimeEnd(t, "label")
			local seen
			Debug:Time("label", function(x, y)
				seen = x + y
			end, 1, 2)
			assert.are.equal(3, seen)
		end)

		it("adds no help lines and handles no commands", function()
			local Debug = Core.NewDebug("TestAddon")
			assert.are.same({}, Debug:HelpLines())
			assert.is_false(Debug:HandleSlash("debug"))
		end)
	end)
end)
