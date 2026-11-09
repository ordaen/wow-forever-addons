-- drag, by hand at its best: the window's cells as textures on its frame; moving it is one SetPoint.
local CELLS, COLUMNS, CELL, GAP, PAD = 200, 10, 36, 2, 8

local Drag = {}

local window

function Drag.Make()
	window = CreateFrame("Frame", nil, UIParent)
	local rows = CELLS / COLUMNS
	window:SetSize(PAD * 2 + COLUMNS * CELL + (COLUMNS - 1) * GAP, PAD * 2 + rows * CELL + (rows - 1) * GAP)
	local background = window:CreateTexture(nil, "BACKGROUND")
	background:SetAllPoints()
	background:SetColorTexture(0.1, 0.1, 0.12, 0.9)
	for i = 1, CELLS do
		local texture = window:CreateTexture(nil, "BORDER")
		texture:SetSize(CELL, CELL)
		texture:SetPoint("TOPLEFT", PAD + (i - 1) % COLUMNS * (CELL + GAP), -(PAD + math.floor((i - 1) / COLUMNS) * (CELL + GAP)))
		texture:SetColorTexture(0.3, 0.3, 0.35, 1)
	end
	Drag.Move(200, 200)
end

function Drag.Move(left, top)
	window:SetPoint("TOPLEFT", UIParent, "TOPLEFT", left, -top)
end

function Drag.Hide()
	window:Hide()
end

--- The frame the screen check reads (bench/screen.lua).
function Drag.Root()
	return window
end

return Drag
