local helpers = require("tests.OrdaenCore.helpers")

describe("OrdaenCore_Debug Capture", function()
	local Store, Capture

	local function load(overrides)
		helpers.stubGlobals(overrides)
		helpers.loadCore(true)
		Store, Capture = helpers.debugNs.Store, helpers.debugNs.Capture
		Store.Load(nil, {})
	end

	describe("as the global error handler", function()
		before_each(function()
			load()
		end)

		it("installs itself and keeps the previous handler", function()
			assert.are.equal("handler", Capture.Mode())
			assert.are.equal(Capture.Handler, helpers.errorHandler)
		end)

		it("records an error with stack and locals, then hands it on once", function()
			Capture.Handler("Interface/AddOns/OrdaenMinimap/Map.lua:12: boom")
			local entry = Store.Get().errors[1]
			assert.are.equal("OrdaenMinimap", entry.source)
			assert.truthy(entry.stack)
			assert.are.equal("x = 1", entry.locals)
			assert.are.same({ "Interface/AddOns/OrdaenMinimap/Map.lua:12: boom" }, helpers.forwarded)
		end)

		it("counts repeats without capturing the stack again", function()
			local stacks = 0
			rawset(_G, "debugstack", function()
				stacks = stacks + 1
				return "stack"
			end)
			for _ = 1, 5 do
				Capture.Handler("flood")
			end
			assert.are.equal(1, stacks)
			assert.are.equal(5, Store.Get().errors[1].count)
			assert.are.equal(5, #helpers.forwarded)
		end)

		it("reads locals one level deeper when the stack starts in C (error called directly)", function()
			local levels = {}
			rawset(_G, "debuglocals", function(level)
				levels[#levels + 1] = level
				return "level " .. level
			end)
			rawset(_G, "debugstack", function()
				return "[C]: ?\n[Interface/AddOns/TestAddon/Core.lua]:5: in function <...>"
			end)
			Capture.Handler("from C")
			rawset(_G, "debugstack", function()
				return "[Interface/AddOns/TestAddon/Core.lua]:5: in function <...>"
			end)
			Capture.Handler("from Lua")
			assert.are.same({ 4, 3 }, levels)
		end)

		it("still hands the error on when recording it fails", function()
			rawset(_G, "date", nil) -- makes Store.AddError fail
			Capture.Handler("original")
			assert.are.same({ "original" }, helpers.forwarded)
		end)

		it("records blocked and forbidden actions as taint", function()
			Capture.OnTaint("ADDON_ACTION_BLOCKED", "OrdaenMinimap", "Minimap:SetParent")
			Capture.OnTaint("ADDON_ACTION_FORBIDDEN", "SomeAddon", "CastSpellByName")
			local errors = Store.Get().errors
			assert.are.equal("taint", errors[1].kind)
			assert.are.equal("OrdaenMinimap", errors[1].source)
			assert.are.equal("OrdaenMinimap: call to Minimap:SetParent() was blocked", errors[1].message)
			assert.are.equal("other", errors[2].source)
			assert.truthy(errors[2].message:find("forbidden", 1, true))
		end)
	end)

	describe("when BugGrabber keeps the handler to itself", function()
		local callbacks

		before_each(function()
			callbacks = {}
			load({
				seterrorhandler = function() end, -- ignored, like a protected handler
				BugGrabber = {
					RegisterCallback = function(owner, event, fn)
						callbacks[event] = function(...)
							return fn(owner, ...)
						end
					end,
				},
			})
		end)

		it("takes errors from BugGrabber's callback", function()
			assert.are.equal("buggrabber", Capture.Mode())
			callbacks.BugGrabber_BugGrabbed({ message = "grabbed", stack = "s", locals = "l" })
			local entry = Store.Get().errors[1]
			assert.are.equal("grabbed", entry.message)
			assert.are.equal("s", entry.stack)
		end)

		it("does not record twice what it forwards itself", function()
			-- BugGrabber's handler fires its callback synchronously while we forward.
			helpers.errorHandler = function(err)
				callbacks.BugGrabber_BugGrabbed({ message = err })
			end
			Capture.Handler("once")
			assert.are.equal(1, Store.Get().errors[1].count)
		end)
	end)
end)
