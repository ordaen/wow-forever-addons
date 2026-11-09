-- The line pitch every hand-written list uses: the framework's, a text's line height in the bench font (the backend
-- takes ceil(GetStringHeight()) of a text: 12 for the 12-point font, whose string height is 11.73). Measured once,
-- so both sides stack lines the same distance apart and draw the same picture.
local FONT = import("bench/font")

local probe = UIParent:CreateFontString(nil, "OVERLAY", FONT)
probe:SetText("Ag")
local line = math.ceil(probe:GetStringHeight())
probe:Hide()
assert(line > 0, "the bench font has no height yet")

return line
