-- Buttons around the minimap, pure part: where a button at a given angle sits outside the border,
-- and the saved angles. No WoW API, so specs can load it.
--
-- Angles are in degrees, 0 = right, counter-clockwise (like the Ordaen Dev gear button and LibDBIcon).
-- The top (90) and bottom (270) hold the zone name and the coordinates/clock, so defaults stay on the sides.
local _, ns = ...

-- Default angle per button id. Blizzard indicators that are hidden most of the time (mail, crafting
-- orders) share the right side; ours and tracking sit on the left, apart from the dev gear button (200).
ns.RING_DEFAULT_ANGLES = {
	tracking = 160,
	drawer = 225,
	mail = 25,
	craftingOrder = 5,
	landing = 330,
}

ns.RING_GAP = 2 -- px between the border and a button

--- Offset from the map center for a button at `angle`, just outside a square border.
---@param angle number degrees
---@param halfWidth number half the map width
---@param halfHeight number half the map height
---@param outset number how far the border reaches past the map edge
---@param buttonHalf number half the button size
---@return number x, number y
function ns.RingOffset(angle, halfWidth, halfHeight, outset, buttonHalf)
	local rad = math.rad(angle)
	local x, y = math.cos(rad), math.sin(rad)
	-- Project onto the square: the larger component touches its side.
	local m = math.max(math.abs(x), math.abs(y))
	x, y = x / m, y / m
	local extra = outset + ns.RING_GAP + buttonHalf
	return x * (halfWidth + extra), y * (halfHeight + extra)
end

--- Angle (degrees, 0..360) of a point relative to the map center.
---@param dx number
---@param dy number
---@return number
function ns.RingAngle(dx, dy)
	if dx == 0 and dy == 0 then
		return 0
	end
	local a = math.deg(math.atan2(dy, dx))
	if a < 0 then
		a = a + 360
	end
	return a
end

--- The saved angle for a button, or its default.
---@param angles table|nil db.buttonAngles
---@param id string
---@return number
function ns.ButtonAngle(angles, id)
	local saved = angles and angles[id]
	if type(saved) == "number" then
		return saved
	end
	return ns.RING_DEFAULT_ANGLES[id] or 180
end

--- Keep only known ids with numeric angles, normalized to 0..360. Returns a table (new if needed).
---@param angles any
---@return table
function ns.SanitizeAngles(angles)
	if type(angles) ~= "table" then
		return {}
	end
	for id, value in pairs(angles) do
		if ns.RING_DEFAULT_ANGLES[id] == nil or type(value) ~= "number" or value ~= value then
			angles[id] = nil
		else
			angles[id] = value % 360
		end
	end
	return angles
end
