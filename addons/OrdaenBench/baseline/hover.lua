-- hover, by hand at its best: 100 cell frames made once, each with a background and a highlight texture; OnEnter
-- shows the highlight and names the item in the line above, OnLeave hides both. The bench calls the scripts.
local FONT = import("bench/font")

local CELLS, SIZE, GAP, COLUMNS = 100, 30, 2, 10

local Hover = {}

local holder, label
local cells = {}

local function OnEnter(cell)
	cell.highlight:Show()
	label:SetFormattedText("Item %d", cell.index)
	label:Show()
end

local function OnLeave(cell)
	cell.highlight:Hide()
	label:Hide()
end

function Hover.Make()
	holder = CreateFrame("Frame", nil, UIParent)
	holder:SetSize(COLUMNS * (SIZE + GAP) - GAP, 20 + (CELLS / COLUMNS) * (SIZE + GAP))
	holder:SetPoint("TOPLEFT", 300, -300)
	label = holder:CreateFontString(nil, "OVERLAY", FONT)
	label:SetPoint("TOPLEFT")
	label:Hide()
	for i = 1, CELLS do
		local cell = CreateFrame("Frame", nil, holder)
		cell:SetSize(SIZE, SIZE)
		local column, row = (i - 1) % COLUMNS, math.floor((i - 1) / COLUMNS)
		cell:SetPoint("TOPLEFT", column * (SIZE + GAP), -20 - row * (SIZE + GAP))
		local background = cell:CreateTexture(nil, "BACKGROUND")
		background:SetAllPoints()
		background:SetColorTexture(0.06, 0.06, 0.08, 0.92)
		local highlight = cell:CreateTexture(nil, "ARTWORK")
		highlight:SetAllPoints()
		highlight:SetColorTexture(0.14, 0.14, 0.18, 0.95)
		highlight:Hide()
		cell.highlight, cell.index = highlight, i
		cell:SetScript("OnEnter", OnEnter)
		cell:SetScript("OnLeave", OnLeave)
		cells[i] = cell
	end
end

--- How many highlights show (the bench's check: one).
function Hover.Lit()
	local n = 0
	for i = 1, #cells do
		if cells[i].highlight:IsShown() then
			n = n + 1
		end
	end
	return n
end

--- The frames the bench hovers, in order.
function Hover.Cells()
	return cells
end

function Hover.Hide()
	holder:Hide()
end

--- The frame the screen check reads (bench/screen.lua).
function Hover.Root()
	return holder
end

return Hover
