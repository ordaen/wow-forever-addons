-- Records (design development/framework/state): one record per key of a choice, each entry's field a stored value of
-- its own: its field's default until set, only what differs stored, its label after the records' and the field's
-- names, and no entry missing or invented.
local Fake = require("tests.fake.wow")

local DIST = ".ordaen/check/dist"

describe("records", function()
	local ns

	setup(function()
		local wow = Fake.New({ dist = DIST, addons = { "OrdaenCore" } })
		wow:Login()
		ns = wow.addons.OrdaenCore.ns
	end)

	local SPEC = { type = "records", key = { type = "choice", choices = { One = "bar1", Two = "bar2" } },
		fields = { perRow = { type = "number", default = 12, min = 1, max = 12, step = 1 },
			keys = { type = "boolean", default = true } } }

	local function records(db)
		return ns.State.Stored({ name = "OrdaenPanel", db = db, charDb = {} }, "module", "bars", SPEC)
	end

	it("gives every entry its fields' defaults, and stores only what differs", function()
		local db = {}
		local bars = records(db)
		assert.are.equal(12, bars:Field("bar1", "perRow"):Get())
		assert.is_true(bars:Field("bar2", "keys"):Get())
		bars:Field("bar2", "perRow"):Set(6)
		assert.are.equal(6, bars:Field("bar2", "perRow"):Get())
		assert.are.equal(12, bars:Field("bar1", "perRow"):Get())
		assert.are.same({ ["module/bars/bar2"] = { perRow = 6 } }, db)
		bars:Field("bar2", "perRow"):Set(12) -- back to the default: nothing stored
		assert.is_nil(db["module/bars/bar2"] and db["module/bars/bar2"].perRow)
	end)

	it("hands out one value per entry and field, kept across reads and a reload", function()
		local db = {}
		local bars = records(db)
		assert.are.equal(bars:Field("bar1", "perRow"), bars:Field("bar1", "perRow"))
		bars:Field("bar1", "keys"):Set(false)
		assert.is_false(records(db):Field("bar1", "keys"):Get())
	end)

	it("refuses a key that isn't one of its choices, and a field it doesn't declare", function()
		local bars = records({})
		assert.has_error(function()
			bars:Field("bar9", "perRow")
		end)
		assert.has_error(function()
			bars:Field("bar1", "colour")
		end)
	end)

	it("labels a field after the records and the field (PANEL_BARS_PERROW)", function()
		local field = records({}):Field("bar1", "perRow")
		assert.are.equal("PANEL_BARS_PERROW", field.spec.label)
	end)
end)
