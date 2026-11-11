-- A module's window (design development/framework/module, «Windows»): a toggle (open on a page, close on the same,
-- go to another), and where the player left it and its size, kept in the module's db across a reload.
local Fake = require("tests.fake.wow")

local DIST = ".ordaen/check/dist"

describe("a module's window", function()
	local ns

	before_each(function()
		local wow = Fake.New({ dist = DIST, addons = { "OrdaenCore" } })
		wow:Login()
		ns = wow.addons.OrdaenCore.ns
	end)

	it("toggles: opens on a page, closes on the same or none, goes to another", function()
		local w = ns.NewWindow({ db = {}, charDb = {} }, "main", {})
		w:Toggle("a")
		assert.is_true(w.shown:Peek())
		assert.are.equal("a", w.page:Peek())
		w:Toggle("b")
		assert.is_true(w.shown:Peek())
		assert.are.equal("b", w.page:Peek())
		w:Toggle("b")
		assert.is_false(w.shown:Peek())
		w:Toggle()
		assert.is_true(w.shown:Peek())
		w:Toggle()
		assert.is_false(w.shown:Peek())
	end)

	it("closes only when its guard lets it", function()
		local w = ns.NewWindow({ db = {}, charDb = {} }, "main", {})
		local allow = false
		w:Guard(function()
			return allow
		end)
		w:Open()
		w:Close()
		assert.is_true(w.shown:Peek())
		allow = true
		w:Close()
		assert.is_false(w.shown:Peek())
	end)

	it("starts at its declared size, and where the player left it after a reload", function()
		local db = {}
		local w = ns.NewWindow({ db = db, charDb = {} }, "main", { width = 600, height = 400 })
		assert.are.same({ 0, 0, 600, 400 }, { w:Place() })
		w:SetPlace(-120, 40, 700, 450)
		-- a reload: the same saved table, a new module and window
		local again = ns.NewWindow({ db = db, charDb = {} }, "main", { width = 600, height = 400 })
		assert.are.same({ -120, 40, 700, 450 }, { again:Place() })
	end)
end)
