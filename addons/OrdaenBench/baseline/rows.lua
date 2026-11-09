-- rows, by hand at its best: 150 font strings made once and placed once; a new count shows the first n, hides the
-- rest (only those that change) and sets the list's height.
local FONT = import("bench/font")

local MOST, LINE, PAD = 150, import("bench/line"), 2

local Rows = {}

local list, texts, shown = nil, {}, 0

function Rows.Make()
	list = CreateFrame("Frame", nil, UIParent)
	list:SetWidth(120)
	list:SetPoint("RIGHT", -200, 0)
	local background = list:CreateTexture(nil, "BACKGROUND")
	background:SetAllPoints()
	background:SetColorTexture(0.1, 0.1, 0.12, 0.9)
	for i = 1, MOST do
		local text = list:CreateFontString(nil, "OVERLAY", FONT)
		text:SetPoint("TOPLEFT", PAD, -PAD - (i - 1) * LINE)
		text:SetFormattedText("row %d", i)
		text:Hide()
		texts[i] = text
	end
	shown = 0
	Rows.SetCount(100)
end

function Rows.SetCount(n)
	for i = shown + 1, n do
		texts[i]:Show()
	end
	for i = n + 1, shown do
		texts[i]:Hide()
	end
	shown = n
	list:SetHeight(PAD * 2 + n * LINE)
end

function Rows.Hide()
	list:Hide()
end

--- The frame the screen check reads (bench/screen.lua).
function Rows.Root()
	return list
end

return Rows
