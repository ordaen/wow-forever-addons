-- columns, by hand at its best: cells as regions on the window's frame; a new column count re-places every cell and
-- resizes the window by arithmetic.
local FONT = import("bench/font")

local CELLS, CELL, GAP, PAD = 200, 36, 2, 8

local Columns = {}

local window, textures, texts

local function Place(columns)
	for i = 1, CELLS do
		local x = PAD + (i - 1) % columns * (CELL + GAP)
		local y = -(PAD + math.floor((i - 1) / columns) * (CELL + GAP))
		textures[i]:SetPoint("TOPLEFT", x, y)
		texts[i]:SetPoint("TOPLEFT", x, y)
	end
	local rows = math.ceil(CELLS / columns)
	window:SetSize(PAD * 2 + columns * CELL + (columns - 1) * GAP, PAD * 2 + rows * CELL + (rows - 1) * GAP)
end

function Columns.Make()
	window = CreateFrame("Frame", nil, UIParent)
	window:SetPoint("CENTER")
	local background = window:CreateTexture(nil, "BACKGROUND")
	background:SetAllPoints()
	background:SetColorTexture(0.1, 0.1, 0.12, 0.9)
	textures, texts = {}, {}
	for i = 1, CELLS do
		local texture = window:CreateTexture(nil, "BORDER")
		texture:SetSize(CELL, CELL)
		texture:SetColorTexture(0.3, 0.3, 0.35, 1)
		local text = window:CreateFontString(nil, "OVERLAY", FONT)
		text:SetSize(CELL, CELL)
		text:SetFormattedText("%d", i)
		textures[i], texts[i] = texture, text
	end
	Place(10)
end

function Columns.SetColumns(n)
	Place(n)
end

function Columns.Hide()
	window:Hide()
end

--- The frame the screen check reads (bench/screen.lua).
function Columns.Root()
	return window
end

return Columns
