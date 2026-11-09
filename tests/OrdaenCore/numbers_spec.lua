-- game.Numbers:Format (addons/OrdaenCore/Numbers.lua) on the fake client, against the design's rules
-- (settings/index.md, «Numbers»; the design site's theme/numbers.js gives the same strings).
local Fake = require("tests.fake.wow")

describe("game.Numbers:Format", function()
	local ns, settings, NBSP

	before_each(function()
		local wow = Fake.New({ dist = ".ordaen/check/dist", addons = { "OrdaenCore" } })
		wow:Login()
		ns = wow.addons.OrdaenCore.ns
		settings = ns.Game.Settings
		NBSP = string.char(194, 160)
	end)

	local function f(n)
		return ns.Game.Numbers:Format(n)
	end

	it("groups with a no-break space, keeps at most 2 decimals and drops trailing zeros", function()
		assert.are.equal("1" .. NBSP .. "234" .. NBSP .. "567.09", f(1234567.0912))
		assert.are.equal("1" .. NBSP .. "795", f(1795))
		assert.are.equal("2.5", f(2.5))
		assert.are.equal("999", f(999))
		assert.are.equal("0", f(0))
	end)

	it("keeps 2 significant digits under 1, rounding or not, and the sign unless it rounds to 0", function()
		assert.are.equal("0.25", f(0.25))
		assert.are.equal("0.004", f(0.004))
		settings.numberRound:Set(true)
		assert.are.equal("1" .. NBSP .. "795", f(1795.4))
		assert.are.equal("0.25", f(0.25))
		assert.are.equal("-3", f(-3.2))
		settings.numberRound:Set(false)
		assert.are.equal("0", f(-0.0001 * 0)) -- zero has no sign
	end)

	it("follows the separators and precision settings", function()
		settings.numberFormat:Set("comma")
		assert.are.equal("1,000,000.09", f(1000000.09))
		settings.numberFormat:Set("dot")
		assert.are.equal("1.000.000,09", f(1000000.09))
		settings.numberPrecision:Set(0)
		assert.are.equal("1.000.000", f(1000000.09))
	end)
end)
