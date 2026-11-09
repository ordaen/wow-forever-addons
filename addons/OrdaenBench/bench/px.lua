-- Whole screen pixels, as the backend draws: fixed sizes, gaps and paddings round to the nearest pixel, measured text
-- rounds up to the next one. The hand sides size with these, so both sides draw the same picture (and crisp hand
-- code does the same).
local _, physicalHeight = GetPhysicalScreenSize()
local px = UIParent:GetHeight() / physicalHeight

local Px = {}

--- `v` UI units at the nearest whole pixel.
function Px.Round(v)
	return math.floor(v / px + 0.5) * px
end

--- `v` UI units up to the next whole pixel (measured text).
function Px.Ceil(v)
	return math.ceil(v / px - 0.001) * px
end

return Px
