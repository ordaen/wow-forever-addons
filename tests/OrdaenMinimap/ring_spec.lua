-- Pure math and saved angles of the buttons around the minimap (Ring.lua).
local function load()
	local ns = {}
	assert(loadfile("addons/OrdaenMinimap/Ring.lua"))("OrdaenMinimap", ns)
	return ns
end

describe("OrdaenMinimap ring", function()
	local ns

	before_each(function()
		ns = load()
	end)

	local function near(expected, actual)
		assert.is_true(math.abs(expected - actual) < 1e-9, ("expected %s, got %s"):format(expected, actual))
	end

	describe("RingOffset", function()
		-- Map 140x140, border outset 11, button 28 (half 14), gap 2: centers 70 + 11 + 2 + 14 = 97 out.
		it("puts a button on the middle of a side just outside the border", function()
			local x, y = ns.RingOffset(0, 70, 70, 11, 14)
			near(97, x)
			near(0, y)
			x, y = ns.RingOffset(90, 70, 70, 11, 14)
			near(0, x)
			near(97, y)
			x, y = ns.RingOffset(180, 70, 70, 11, 14)
			near(-97, x)
			near(0, y)
		end)

		it("follows the square, not a circle: a corner angle reaches the corner", function()
			local x, y = ns.RingOffset(45, 70, 70, 11, 14)
			near(97, x)
			near(97, y)
			x, y = ns.RingOffset(225, 70, 70, 0, 14)
			near(-86, x)
			near(-86, y)
		end)

		it("keeps the button outside the border at any angle", function()
			for angle = 0, 359, 7 do
				local x, y = ns.RingOffset(angle, 70, 70, 11, 14)
				assert.is_true(math.max(math.abs(x), math.abs(y)) >= 97 - 1e-9, "angle " .. angle)
			end
		end)
	end)

	describe("RingAngle", function()
		it("measures counter-clockwise from the right, 0..360", function()
			near(0, ns.RingAngle(10, 0))
			near(90, ns.RingAngle(0, 10))
			near(180, ns.RingAngle(-10, 0))
			near(270, ns.RingAngle(0, -10))
			near(0, ns.RingAngle(0, 0))
		end)

		it("is the inverse of RingOffset", function()
			for _, angle in ipairs({ 10, 60, 135, 200, 300 }) do
				local x, y = ns.RingOffset(angle, 70, 70, 11, 14)
				local back = ns.RingAngle(x, y)
				-- The square projection keeps the direction.
				near(angle, back)
			end
		end)
	end)

	describe("saved angles", function()
		it("uses the saved angle, else the default", function()
			assert.equals(10, ns.ButtonAngle({ tracking = 10 }, "tracking"))
			assert.equals(ns.RING_DEFAULT_ANGLES.tracking, ns.ButtonAngle({}, "tracking"))
			assert.equals(ns.RING_DEFAULT_ANGLES.drawer, ns.ButtonAngle(nil, "drawer"))
		end)

		it("keeps the defaults off the top and bottom, where the zone name and clock are", function()
			for id, angle in pairs(ns.RING_DEFAULT_ANGLES) do
				assert.is_true(math.abs(angle - 90) > 30 and math.abs(angle - 270) > 25, id)
			end
		end)

		it("drops unknown ids and bad values, and normalizes the rest", function()
			local angles = ns.SanitizeAngles({ tracking = 370, drawer = "x", nonsense = 10, mail = 0 / 0, lfg = -10 })
			assert.same({ tracking = 10, lfg = 350 }, angles)
			assert.same({}, ns.SanitizeAngles(nil))
			assert.same({}, ns.SanitizeAngles("junk"))
		end)
	end)
end)
