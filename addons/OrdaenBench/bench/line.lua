-- The line pitch every hand-written list uses: the framework's, a text's height in the bench font rounded up to the
-- next whole screen pixel (the backend's `ceil(v / px - 0.001) * px`: 11.73 units, 11 px, at 1280x720), so both
-- sides stack lines the same distance apart, every line on whole pixels. Measured once.
local FONT = import("bench/font")

local _, physicalHeight = GetPhysicalScreenSize()
local px = UIParent:GetHeight() / physicalHeight

local probe = UIParent:CreateFontString(nil, "OVERLAY", FONT)
probe:SetText("Ag")
local line = math.ceil(probe:GetStringHeight() / px - 0.001) * px
probe:Hide()
assert(line > 0, "the bench font has no height yet")

return line
