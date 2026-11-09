-- grow, by hand at its best: each row is 5 nested frames around a font string; a new text sets it, measures its
-- width once, and sizes the 5 frames around it by arithmetic.
local FONT = import("bench/font")
local Words = import("bench/words")

local ROWS, DEPTH, PAD, LINE = 50, 5, 2, 14

local Grow = {}

local holder, texts, levels = nil, {}, {}

function Grow.Make()
	holder = CreateFrame("Frame", nil, UIParent)
	holder:SetSize(300, ROWS * (LINE + DEPTH * PAD * 2 + 2))
	holder:SetPoint("TOPLEFT", 40, -40)
	for r = 1, ROWS do
		local parent, frames = holder, {}
		for d = 1, DEPTH do
			local frame = CreateFrame("Frame", nil, parent)
			if d == 1 then
				frame:SetPoint("TOPLEFT", 0, -(r - 1) * (LINE + DEPTH * PAD * 2 + 2))
			else
				frame:SetPoint("TOPLEFT", PAD, -PAD)
			end
			local background = frame:CreateTexture(nil, "BACKGROUND")
			background:SetAllPoints()
			background:SetColorTexture(0.3, 0.3, 0.35, 0.5)
			frames[d], parent = frame, frame
		end
		local text = parent:CreateFontString(nil, "OVERLAY", FONT)
		text:SetPoint("TOPLEFT", PAD, -PAD)
		texts[r], levels[r] = text, frames
		Grow.SetLength(r, 1)
	end
end

function Grow.SetLength(r, n)
	local text = texts[r]
	text:SetText(Words.WORDS[n])
	local width = text:GetStringWidth()
	local frames = levels[r]
	for d = DEPTH, 1, -1 do
		local inset = (DEPTH - d + 1) * PAD * 2
		frames[d]:SetSize(width + inset, LINE + inset)
	end
end

function Grow.Hide()
	holder:Hide()
end

--- The frame the screen check reads (bench/screen.lua).
function Grow.Root()
	return holder
end

return Grow
