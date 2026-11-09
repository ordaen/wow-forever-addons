-- grid, as a typical addon writes it: a frame per cell, and an update that re-anchors the cell and sets its text
-- from string.format (a Lua string per call).
local floor, format = math.floor, string.format

local SIZES = { small = 200, large = 1000 }
local COLUMNS, CELL, GAP, PAD = 10, 36, 4, 8

local Grid = {}

local grids, cells = {}, {}

local function Update(grid, cell, i, value)
	cell:ClearAllPoints()
	cell:SetPoint("TOPLEFT", grid, "TOPLEFT", PAD + (i - 1) % COLUMNS * (CELL + GAP),
		-(PAD + floor((i - 1) / COLUMNS) * (CELL + GAP)))
	cell.count:SetText(format("%d", value))
end

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
		local cell = CreateFrame("Frame", nil, grid)
		cell:SetSize(CELL, CELL)
		local texture = cell:CreateTexture(nil, "BACKGROUND")
		texture:SetAllPoints()
		texture:SetColorTexture(0.3, 0.3, 0.35, 1)
		cell.count = cell:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		cell.count:SetAllPoints()
		Update(grid, cell, i, 0)
		list[i] = cell
	end
	grids[size], cells[size] = grid, list
end

function Grid.SetOne(size, i, value)
	Update(grids[size], cells[size][i], i, value)
end

function Grid.SetAll(size, base)
	local grid, list = grids[size], cells[size]
	for i = 1, #list do
		Update(grid, list[i], i, base + i)
	end
end

function Grid.Show(size)
	grids[size]:Show()
end

function Grid.Hide(size)
	grids[size]:Hide()
end

return Grid
