-- The baseline: the bench's scenarios written by hand with WoW's own objects, the way a careful addon would (frames
-- made once and reused, values in plain tables, dependants called directly). Dev only: it uses WoW directly.
local floor = math.floor

local Baseline = {}

-- Signals: 1000 values, 100 sums of three, 300 watchers reading two values and a sum; a write calls its watchers.
local N, SUMS, WATCHERS = 1000, 100, 300
local values, watchersOf, sink

function Baseline.SignalsMake()
	values, watchersOf = {}, {}
	for i = 1, N do
		values[i] = 0
		watchersOf[i] = {}
	end
	local function Sum(c)
		return values[c] + values[c + 100] + values[c + 200]
	end
	for w = 1, WATCHERS do
		local a, b, c = w, (w * 7) % N + 1, (w % SUMS) + 1
		local function Watch()
			sink = values[a] + values[b] + Sum(c)
		end
		local list = watchersOf[a]
		list[#list + 1] = Watch
		list = watchersOf[b]
		list[#list + 1] = Watch
		for _, v in ipairs({ c, c + 100, c + 200 }) do
			list = watchersOf[v]
			list[#list + 1] = Watch
		end
	end
end

function Baseline.SignalsFrame(frame)
	for i = 1, 50 do
		local k = (frame * 50 + i * 37) % N + 1
		values[k] = values[k] + 1
		local list = watchersOf[k]
		for j = 1, #list do
			list[j]()
		end
	end
end

-- Grid: 200 cells of 36x36, a background and a count, in 10 columns.
local COUNT, COLUMNS, CELL, GAP, PAD = 200, 10, 36, 4, 8
local grid, counts

function Baseline.GridMake()
	grid = CreateFrame("Frame", nil, UIParent)
	local rows = floor((COUNT + COLUMNS - 1) / COLUMNS)
	grid:SetSize(PAD * 2 + COLUMNS * CELL + (COLUMNS - 1) * GAP, PAD * 2 + rows * CELL + (rows - 1) * GAP)
	grid:SetPoint("CENTER")
	local bg = grid:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0.1, 0.1, 0.12, 0.9)
	counts = {}
	for i = 1, COUNT do
		local cell = CreateFrame("Frame", nil, grid)
		cell:SetSize(CELL, CELL)
		local column, row = (i - 1) % COLUMNS, floor((i - 1) / COLUMNS)
		cell:SetPoint("TOPLEFT", PAD + column * (CELL + GAP), -(PAD + row * (CELL + GAP)))
		local tex = cell:CreateTexture(nil, "BACKGROUND")
		tex:SetAllPoints()
		tex:SetColorTexture(0.3, 0.3, 0.35, 1)
		local text = cell:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		text:SetAllPoints()
		text:SetFormattedText("%d", 0)
		counts[i] = text
	end
end

function Baseline.GridOne(i)
	counts[i]:SetFormattedText("%d", i)
end

function Baseline.GridAll(i)
	for k = 1, COUNT do
		counts[k]:SetFormattedText("%d", i + k)
	end
end

function Baseline.GridToggle()
	grid:Hide()
	grid:Show()
end

-- Ticker: 50 texts with two numbers each, changed every frame.
local TEXTS = 50
local ticker, texts, tick

function Baseline.TickerMake()
	ticker = CreateFrame("Frame", nil, UIParent)
	ticker:SetSize(200, TEXTS * 14)
	ticker:SetPoint("LEFT", 40, 0)
	texts, tick = {}, 0
	for i = 1, TEXTS do
		local text = ticker:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		text:SetPoint("TOPLEFT", 0, -(i - 1) * 14)
		texts[i] = text
	end
end

function Baseline.TickerFrame()
	tick = tick + 1
	for i = 1, TEXTS do
		texts[i]:SetFormattedText("%.1f, %.1f", tick * 0.1 + i, tick * 0.2 - i)
	end
end

function Baseline.HideAll()
	if grid then
		grid:Hide()
	end
	if ticker then
		ticker:Hide()
	end
end

return Baseline
