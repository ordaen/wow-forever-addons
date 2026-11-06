local helpers = require("tests.OrdaenCore.helpers")

-- A fresh Core (and so a fresh debug instance) for every test.
local function newDebug()
	return helpers.loadCore().NewDebug("TestAddon")
end

describe("OrdaenCore debug kit", function()
	local Debug, db, printed

	before_each(function()
		helpers.stubGlobals()
		Debug = newDebug()
		db = {}
		printed = {}
		Debug.Init(db, {
			slash = "/t",
			print = function(...)
				printed[#printed + 1] = table.concat({ ... }, " ")
			end,
		})
	end)

	describe("TrimLog", function()
		it("keeps the newest entries in order", function()
			local log = { 1, 2, 3, 4, 5 }
			Debug.TrimLog(log, 3)
			assert.are.same({ 3, 4, 5 }, log)
		end)

		it("leaves short logs alone", function()
			local log = { 1, 2 }
			Debug.TrimLog(log, 3)
			assert.are.same({ 1, 2 }, log)
		end)
	end)

	describe("Log", function()
		it("does nothing while debug is off", function()
			Debug.Log("hello")
			assert.are.equal(0, #db.debug.log)
		end)

		it("records timestamped lines while debug is on", function()
			Debug.HandleSlash("debug on")
			Debug.Log("hello", 42, nil)
			local last = db.debug.log[#db.debug.log]
			assert.truthy(last:match("^%d%d:%d%d:%d%d%.500 hello 42 nil$"), last)
		end)

		it("caps the log size", function()
			Debug.HandleSlash("debug on")
			local total = Debug.LOG_MAX + Debug.LOG_TRIM_SLACK + 1
			for i = 1, total do
				Debug.Log("line", i)
			end
			local log = db.debug.log
			assert.is_true(#log <= Debug.LOG_MAX + Debug.LOG_TRIM_SLACK)
			assert.truthy(log[#log]:match("line " .. total .. "$"))
		end)
	end)

	describe("Snapshot", function()
		it("keeps plain values and replaces functions", function()
			local snap = Debug.Snapshot({ a = 1, b = "x", c = true, f = print })
			assert.are.same({ a = 1, b = "x", c = true, f = "<function>" }, snap)
		end)

		it("cuts cycles and deep tables", function()
			local t = { deep = { deeper = { deepest = {} } } }
			t.self = t
			local snap = Debug.Snapshot(t, 2)
			assert.are.equal("<cycle>", snap.self)
			assert.are.equal("<table>", snap.deep.deeper)
		end)

		it("keeps tables shared by two branches", function()
			local shared = { v = 1 }
			local snap = Debug.Snapshot({ a = shared, b = shared })
			assert.are.same({ v = 1 }, snap.a)
			assert.are.same({ v = 1 }, snap.b)
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
				IsShown = function()
					return true
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
			assert.are.equal("LibDBIcon10_Test", snap.button.name)
			assert.are.equal("Minimap", snap.button.parent)
			assert.are.equal("31.33x31", snap.button.size)
			assert.are.same({ "TOPLEFT Minimap BOTTOMLEFT 1.25 -2" }, snap.button.points)
			assert.is_nil(snap.button.level)
		end)
	end)

	describe("errors", function()
		it("Call returns results, including nil holes", function()
			local a, b, c = Debug.Call(function(x)
				return x, nil, 3
			end, 1)
			assert.are.same({ 1, nil, 3 }, { a, b, c })
		end)

		it("Call records the error, notifies once and passes it on", function()
			local passedOn = {}
			rawset(_G, "geterrorhandler", function()
				return function(err)
					passedOn[#passedOn + 1] = err
				end
			end)
			local result = Debug.Call(error, "kaboom", 0)
			Debug.Call(error, "kaboom", 0)
			assert.is_nil(result)
			assert.are.equal(1, #db.debug.errors)
			local entry = db.debug.errors[1]
			assert.are.equal("kaboom", entry.message)
			assert.are.equal(2, entry.count)
			assert.truthy(entry.stack)
			assert.are.equal("1.2.3", entry.meta.addonVersion)
			assert.are.equal("1.2.3", entry.meta.core)
			assert.are.equal(2, #passedOn)
			local notices = 0
			for _, line in ipairs(printed) do
				if line:find("/t errors", 1, true) then
					notices = notices + 1
				end
			end
			assert.are.equal(1, notices)
		end)

		it("still passes the error on when recording it fails", function()
			local passedOn = {}
			rawset(_G, "geterrorhandler", function()
				return function(err)
					passedOn[#passedOn + 1] = err
				end
			end)
			rawset(_G, "date", nil) -- makes RecordError itself fail
			Debug.Call(error, "original", 0)
			assert.are.same({ "original" }, passedOn)
		end)

		it("caps the number of stored errors", function()
			for i = 1, Debug.ERRORS_MAX + 5 do
				Debug.RecordError("error " .. i)
			end
			assert.are.equal(Debug.ERRORS_MAX, #db.debug.errors)
			assert.are.equal("error 6", db.debug.errors[1].message)
		end)

		it("keeps errors raised before Init", function()
			local early = newDebug()
			early.RecordError("too early")
			local saved = {}
			early.Init(saved, { print = function() end })
			assert.are.equal("too early", saved.debug.errors[1].message)
		end)

		it("does not double-count when Init runs twice on the same table", function()
			Debug.RecordError("once")
			Debug.Init(db, { print = function() end })
			assert.are.equal(1, db.debug.errors[1].count)
		end)

		it("formats a report, newest first", function()
			Debug.RecordError("alpha message", "alpha stack")
			Debug.RecordError("beta message", "beta stack")
			local report = Debug.FormatReport()
			assert.truthy(report:find("Addon: TestAddon 1.2.3 (Ordaen Core 1.2.3)", 1, true))
			assert.truthy(report:find("interface 16001", 1, true))
			assert.truthy(report:find("beta message", 1, true) < report:find("alpha message", 1, true))
			assert.truthy(report:find("alpha stack", 1, true))
		end)

		it("says so when there are no errors", function()
			assert.truthy(Debug.FormatReport():find("No errors recorded.", 1, true))
		end)
	end)

	describe("HandleSlash", function()
		it("toggles debug and leaves other commands to the addon", function()
			assert.is_true(Debug.HandleSlash("debug"))
			assert.is_true(Debug.IsEnabled())
			assert.is_true(Debug.HandleSlash("  DEBUG off "))
			assert.is_false(Debug.IsEnabled())
			assert.is_false(Debug.HandleSlash("columns 4"))
			assert.is_false(Debug.HandleSlash("debug nonsense"))
		end)

		it("dumps the addon state", function()
			Debug.Init(db, {
				print = function() end,
				dump = function()
					return { columns = 4 }
				end,
			})
			assert.is_true(Debug.HandleSlash("dump"))
			assert.are.same({ columns = 4 }, db.debug.dump.state)
			assert.are.equal(16001, db.debug.dump.meta.interface)
		end)

		it("clears errors", function()
			Debug.RecordError("x")
			assert.is_true(Debug.HandleSlash("errors clear"))
			assert.are.equal(0, #db.debug.errors)
		end)
	end)
end)
