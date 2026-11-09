-- deep, by hand: 100 frames nested one inside the other with a 1-pixel inset, a font string in the innermost; either
-- change sets that one font string.
local FONT = import("bench/font")
local DEPTH = 100

local Deep = {}

local outer, text
local value, source = 0, 0

function Deep.Make()
	value, source = 0, 0
	outer = CreateFrame("Frame", nil, UIParent)
	outer:SetSize(300, 300)
	outer:SetPoint("BOTTOM", 0, 80)
	local parent = outer
	for _ = 1, DEPTH do
		local level = CreateFrame("Frame", nil, parent)
		level:SetPoint("TOPLEFT", 1, -1)
		level:SetPoint("BOTTOMRIGHT", -1, 1)
		parent = level
	end
	text = parent:CreateFontString(nil, "OVERLAY", FONT)
	text:SetPoint("CENTER")
	text:SetFormattedText("%d / %d", value, source)
end

function Deep.SetValue(v)
	value = v
	text:SetFormattedText("%d / %d", value, source)
end

function Deep.SetSource(v)
	source = v
	text:SetFormattedText("%d / %d", value, source)
end

function Deep.Show()
	outer:Show()
end

function Deep.Hide()
	outer:Hide()
end

--- The frame the screen check reads (bench/screen.lua).
-- bench: begin
function Deep.Root()
	return outer
end
-- bench: end

return Deep
