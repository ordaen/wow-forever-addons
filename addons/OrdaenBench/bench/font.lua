-- The one font every hand-written side draws with: the framework's body text (STANDARD_TEXT_FONT at 12, the theme's
-- text.body), so text costs the same to lay out on every side. Returns the font object's name, for
-- CreateFontString's template argument.
local NAME = "OrdaenBenchFont"

local font = CreateFont(NAME)
font:SetFont(STANDARD_TEXT_FONT, 12, "")

return NAME
