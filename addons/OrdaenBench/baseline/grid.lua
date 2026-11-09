-- grid, by hand at its best: no frame per cell (cells take no mouse): each cell is a background texture and a count
-- font string on the grid's own frame, made once and placed by arithmetic; a change sets the one count with
-- SetFormattedText (no Lua string); opening and closing show and hide the grid.
local floor = math.floor

local SIZES = { small = 200, large = 1000 }
local COLUMNS, CELL, GAP, PAD = 10, 36, 4, 8

local Grid = {}

local grids, texts = {}, {}

function Grid.Make(size)
	local count = SIZES[size]
	local grid = CreateFrame("Frame", nil, UIParent)
	local rows = floor((count + COLUMNS - 1) / COLUMNS)
	grid:SetSize(PAD * 2 + COLUMNS * CELL + (COLUMNS - 1) * GAP, PAD * 2 + rows * CELL + (rows - 1) * GAP)
	grid:SetPoint("CENTER")
	local background = grid:CreateTexture(nil, "BACKGROUND")
	background:SetAllPoints()
	background:SetColorTexture(0.1, 0.1, 0.12, 0.9)
	local list = {}
	for i = 1, count do
		local x, y = PAD + (i - 1) % COLUMNS * (CELL + GAP), -(PAD + floor((i - 1) / COLUMNS) * (CELL + GAP))
		local texture = grid:CreateTexture(nil, "BORDER")
		texture:SetSize(CELL, CELL)
		texture:SetPoint("TOPLEFT", x, y)
		texture:SetColorTexture(0.3, 0.3, 0.35, 1)
		local text = grid:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		text:SetSize(CELL, CELL)
		text:SetPoint("TOPLEFT", x, y)
		text:SetFormattedText("%d", 0)
		list[i] = text
	end
	grids[size], texts[size] = grid, list
end

function Grid.SetOne(size, i, value)
	texts[size][i]:SetFormattedText("%d", value)
end

-- The method looked up once, not per cell: every font string shares it.
function Grid.SetAll(size, base)
	local list = texts[size]
	local SetFormattedText = list[1].SetFormattedText
	for i = 1, #list do
		SetFormattedText(list[i], "%d", base + i)
	end
end

function Grid.Show(size)
	grids[size]:Show()
end

function Grid.Hide(size)
	grids[size]:Hide()
end

return Grid
