local helpers = require("tests.OrdaenCore.helpers")

describe("OrdaenCore_Debug Store", function()
	local Store

	before_each(function()
		helpers.stubGlobals()
		helpers.loadCore(true)
		Store = helpers.debugNs.Store
	end)

	describe("Load", function()
		it("starts a new session and keeps what was recorded before it", function()
			Store.AddError({ message = "early" })
			Store.AppendLog("TestAddon", "early line")
			local db = Store.Load({ session = 4 }, { client = "1.60.1" })
			assert.are.equal(5, db.session)
			assert.are.equal("1.60.1", db.sessions[5].client)
			assert.are.equal("early", db.errors[1].message)
			assert.are.equal(5, db.errors[1].session)
			assert.are.same({ "early line" }, db.addons.TestAddon.log)
		end)

		it("repairs a missing or broken table", function()
			local db = Store.Load("garbage", {})
			assert.are.equal(1, db.session)
			assert.are.same({}, db.errors)
		end)

		it("de-duplicates against errors saved in earlier sessions", function()
			Store.Load({ errors = { { id = 1, message = "old", count = 2, session = 1 } }, nextId = 1, session = 1 }, {})
			local entry, isNew = Store.AddError({ message = "old" })
			assert.is_false(isNew)
			assert.are.equal(3, entry.count)
			assert.are.equal(2, entry.lastSession)
		end)

		it("forgets sessions nothing refers to", function()
			local db = Store.Load({
				session = 3,
				sessions = { [1] = {}, [2] = {}, [3] = {} },
				errors = { { id = 1, message = "x", count = 1, session = 2 } },
				nextId = 1,
			}, {})
			assert.is_nil(db.sessions[1])
			assert.is_not_nil(db.sessions[2])
			assert.is_nil(db.sessions[3])
			assert.is_not_nil(db.sessions[4])
		end)
	end)

	describe("errors", function()
		before_each(function()
			Store.Load(nil, {})
		end)

		it("attributes errors to the Ordaen addon in the message or stack", function()
			assert.are.equal("OrdaenMinimap", Store.SourceOf("Interface/AddOns/OrdaenMinimap/Map.lua:3: x"))
			assert.are.equal("OrdaenCore", Store.SourceOf("boom", "[Interface\\AddOns\\OrdaenCore\\Core.lua]:1"))
			assert.are.equal("other", Store.SourceOf("Interface/AddOns/Details/x.lua:1: y", "[C]: ?"))
		end)

		it("counts repeats instead of storing them again", function()
			local first, isNew = Store.AddError({ message = "boom" })
			assert.is_true(isNew)
			assert.are.equal(first, Store.Repeat("boom"))
			assert.is_nil(Store.Repeat("other message"))
			assert.are.equal(2, first.count)
			assert.are.equal(1, #Store.Get().errors)
		end)

		it("keeps the newest ERRORS_MAX errors and forgets the dropped ones", function()
			for i = 1, Store.ERRORS_MAX + 3 do
				Store.AddError({ message = "error " .. i })
			end
			local errors = Store.Get().errors
			assert.are.equal(Store.ERRORS_MAX, #errors)
			assert.are.equal("error 4", errors[1].message)
			local _, isNew = Store.AddError({ message = "error 1" })
			assert.is_true(isNew)
		end)

		it("truncates huge stacks and locals", function()
			local entry = Store.AddError({ message = "big", stack = string.rep("s", 10000), locals = string.rep("l", 9000) })
			assert.is_true(#entry.stack < 7000)
			assert.is_true(#entry.locals < 5000)
		end)

		it("filters newest first", function()
			Store.AddError({ message = "Interface/AddOns/OrdaenMinimap/a.lua:1: ours" })
			Store.AddError({ message = "Interface/AddOns/Details/b.lua:1: theirs" })
			Store.AddError({ message = "OrdaenMinimap: call to x() was blocked", kind = "taint", source = "OrdaenMinimap" })
			local function messages(filter)
				local out = {}
				for _, e in ipairs(Store.Filter(filter)) do
					out[#out + 1] = e.message:match("[%w]+$")
				end
				return out
			end
			assert.are.same({ "blocked", "theirs", "ours" }, messages("all"))
			assert.are.same({ "ours" }, messages("ours"))
			assert.are.same({ "theirs" }, messages("other"))
			assert.are.same({ "blocked" }, messages("taint"))
		end)

		it("counts errors added since they were last seen", function()
			Store.AddError({ message = "a" })
			Store.AddError({ message = "b" })
			assert.are.equal(2, Store.NewCount())
			Store.MarkSeen()
			assert.are.equal(0, Store.NewCount())
			Store.AddError({ message = "c" })
			assert.are.equal(1, Store.NewCount())
			Store.ClearErrors()
			assert.are.equal(0, Store.NewCount())
			assert.are.same({}, Store.Filter("all"))
		end)

		it("tells listeners about new errors and repeats", function()
			local seen = {}
			Store.OnChange(function(entry, isNew)
				seen[#seen + 1] = { entry and entry.message, isNew }
			end)
			Store.AddError({ message = "x" })
			Store.AddError({ message = "x" })
			Store.ClearErrors()
			assert.are.same({ { "x", true }, { "x", false }, { nil, false } }, seen)
		end)

		it("formats an error with versions, stack and locals", function()
			Store.Load(nil, { client = "1.60.1", build = "70790", interface = 16001, locale = "ruRU", core = "0.1.0" })
			local entry = Store.AddError({
				message = "Interface/AddOns/OrdaenMinimap/Map.lua:9: boom",
				stack = "the stack",
				locals = "x = 1",
			})
			local text = Store.FormatError(entry)
			assert.truthy(text:find("Error in OrdaenMinimap: x1", 1, true))
			assert.truthy(text:find("Client 1.60.1 (build 70790", 1, true))
			assert.truthy(text:find("Ordaen Core 0.1.0", 1, true))
			assert.truthy(text:find("OrdaenMinimap 1.2.3", 1, true))
			assert.truthy(text:find("the stack", 1, true))
			assert.truthy(text:find("x = 1", 1, true))
		end)
	end)

	describe("logs and saves", function()
		before_each(function()
			Store.Load(nil, {})
		end)

		it("trims logs in batches, keeping the newest lines", function()
			local log = { 1, 2, 3, 4, 5 }
			Store.TrimLog(log, 3)
			assert.are.same({ 3, 4, 5 }, log)
			for i = 1, Store.LOG_MAX + Store.LOG_TRIM_SLACK + 1 do
				Store.AppendLog("TestAddon", i)
			end
			local saved = Store.Addon("TestAddon").log
			assert.are.equal(Store.LOG_MAX, #saved)
			assert.are.equal(Store.LOG_MAX + Store.LOG_TRIM_SLACK + 1, saved[#saved])
		end)

		it("keeps the newest SAVES_MAX saves with their notes", function()
			for i = 1, Store.SAVES_MAX + 2 do
				Store.AddSave({ note = "note " .. i, combat = false })
			end
			local saves = Store.Get().saves
			assert.are.equal(Store.SAVES_MAX, #saves)
			assert.are.equal("note " .. (Store.SAVES_MAX + 2), saves[#saves].note)
			assert.are.equal(Store.Session(), saves[#saves].session)
		end)
	end)
end)
