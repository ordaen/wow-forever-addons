-- resize, by hand at its best: the window's cells as regions on its frame (a texture and a font string each); a new
-- width resizes and re-places every cell by arithmetic.
local FONT = import("bench/font")
local Px = import("bench/px")

local CELLS, COLUMNS, HEIGHT, GAP, PAD = 200, 10, Px.Round(24), Px.Round(2), Px.Round(8)

local Resize = {}

local window, textures, texts

local function Place(width)
	local cell = (width - PAD * 2 - (COLUMNS - 1) * GAP) / COLUMNS
	for i = 1, CELLS do
		local x = PAD + (i - 1) % COLUMNS * (cell + GAP)
		local y = -(PAD + math.floor((i - 1) / COLUMNS) * (HEIGHT + GAP))
		local texture, text = textures[i], texts[i]
		texture:SetSize(cell, HEIGHT)
		texture:SetPoint("TOPLEFT", x, y)
		text:SetSize(cell, HEIGHT)
		text:SetPoint("TOPLEFT", x, y)
	end
	window:SetWidth(width)
end

function Resize.Make()
	window = CreateFrame("Frame", nil, UIParent)
	local rows = CELLS / COLUMNS
	window:SetHeight(PAD * 2 + rows * HEIGHT + (rows - 1) * GAP)
	window:SetPoint("CENTER")
	local background = window:CreateTexture(nil, "BACKGROUND")
	background:SetAllPoints()
	background:SetColorTexture(0.1, 0.1, 0.12, 0.9)
	textures, texts = {}, {}
	for i = 1, CELLS do
		local texture = window:CreateTexture(nil, "BORDER")
		texture:SetColorTexture(0.3, 0.3, 0.35, 1)
		local text = window:CreateFontString(nil, "OVERLAY", FONT)
		text:SetFormattedText("%d", i)
		textures[i], texts[i] = texture, text
	end
	Place(500)
end

function Resize.SetWidth(width)
	Place(width)
end

function Resize.Hide()
	window:Hide()
end

--- The frame the screen check reads (bench/screen.lua).
-- bench: begin
function Resize.Root()
	return window
end
-- bench: end

return Resize
