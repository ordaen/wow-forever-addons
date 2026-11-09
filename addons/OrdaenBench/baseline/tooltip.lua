-- tooltip, by hand at its best: one frame with 10 font strings made once; showing sets the lines, measures the widest
-- and sizes the frame; hiding hides the frame.
local FONT = import("bench/font")
local Words = import("bench/words")

local LINES, LINE, PAD = 10, 14, 8

local Tooltip = {}

local frame, texts = nil, {}

function Tooltip.Make()
	frame = CreateFrame("Frame", nil, UIParent)
	frame:SetPoint("TOPLEFT", 600, -200)
	local background = frame:CreateTexture(nil, "BACKGROUND")
	background:SetAllPoints()
	background:SetColorTexture(0.1, 0.1, 0.12, 0.9)
	for i = 1, LINES do
		local text = frame:CreateFontString(nil, "OVERLAY", FONT)
		text:SetPoint("TOPLEFT", PAD, -PAD - (i - 1) * (LINE + 1))
		texts[i] = text
	end
	frame:Hide()
end

function Tooltip.ShowWith(n)
	local pool, widest = Words.LINES, 0
	for i = 1, LINES do
		local text = texts[i]
		text:SetText(pool[(n + i * 7) % #pool + 1])
		local width = text:GetStringWidth()
		if width > widest then
			widest = width
		end
	end
	frame:SetSize(widest + PAD * 2, LINES * (LINE + 1) - 1 + PAD * 2)
	frame:Show()
end

function Tooltip.Hide()
	frame:Hide()
end

--- The frame the screen check reads (bench/screen.lua).
function Tooltip.Root()
	return frame
end

return Tooltip
