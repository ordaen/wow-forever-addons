-- reorder, as a typical addon writes it: after any change every row is re-anchored (ClearAllPoints + SetPoint) and
-- its text set again from string.format.
local FONT = import("bench/font")
local format = string.format

local ROWS, LINE = 500, 14

local Reorder = {}

local frame
local ids, nextId = {}, ROWS + 1
local textOf, pool = {}, {}
local seed = 1 -- the same shuffles as the other sides

local function Refresh()
	for i = 1, #ids do
		local id = ids[i]
		local text = textOf[id]
		if not text then
			text = table.remove(pool) or frame:CreateFontString(nil, "OVERLAY", FONT)
			textOf[id] = text
			text:Show()
		end
		text:ClearAllPoints()
		text:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -(i - 1) * LINE)
		text:SetText(format("row %d", id))
	end
end

function Reorder.Make()
	frame = CreateFrame("Frame", nil, UIParent)
	frame:SetSize(120, ROWS * LINE)
	frame:SetPoint("RIGHT", -40, 0)
	for i = 1, ROWS do
		ids[i] = i
	end
	Refresh()
end

function Reorder.Reverse()
	local n = #ids
	for i = 1, math.floor(n / 2) do
		ids[i], ids[n - i + 1] = ids[n - i + 1], ids[i]
	end
	Refresh()
end

function Reorder.Rotate()
	table.insert(ids, table.remove(ids, 1))
	Refresh()
end

function Reorder.InsertFront()
	table.insert(ids, 1, nextId)
	nextId = nextId + 1
	Refresh()
end

function Reorder.RemoveMiddle()
	local id = table.remove(ids, math.floor(#ids / 2))
	textOf[id]:Hide()
	pool[#pool + 1] = textOf[id]
	textOf[id] = nil
	Refresh()
end

function Reorder.Shuffle()
	for i = #ids, 2, -1 do
		seed = (seed * 1103515245 + 12345) % 2147483648
		local j = seed % i + 1
		ids[i], ids[j] = ids[j], ids[i]
	end
	Refresh()
end

function Reorder.Hide()
	frame:Hide()
end

return Reorder
