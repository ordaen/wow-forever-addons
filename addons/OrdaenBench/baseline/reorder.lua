-- reorder, by hand: one font string per row id, made once (removed ones pooled); after a change of order only the
-- rows whose position changed are anchored again.
local FONT = import("bench/font")
local ROWS, LINE = 500, import("bench/line")

local Reorder = {}

local frame
local ids, nextId = {}, ROWS + 1
local textOf, slotOf, pool = {}, {}, {}
local seed = 1

local function Text(id)
	local text = table.remove(pool)
	if not text then
		text = frame:CreateFontString(nil, "OVERLAY", FONT)
	end
	text:SetFormattedText("row %d", id)
	text:Show()
	textOf[id] = text
	return text
end

-- One anchor point per row, always TOPLEFT: SetPoint replaces it, so no ClearAllPoints.
local function Place()
	local SetPoint
	for i = 1, #ids do
		local id = ids[i]
		if slotOf[id] ~= i then
			slotOf[id] = i
			local text = textOf[id]
			SetPoint = SetPoint or text.SetPoint
			SetPoint(text, "TOPLEFT", 0, -(i - 1) * LINE)
		end
	end
end

function Reorder.Make()
	ids, nextId, textOf, slotOf, pool, seed = {}, ROWS + 1, {}, {}, {}, 1
	frame = CreateFrame("Frame", nil, UIParent)
	frame:SetSize(120, ROWS * LINE)
	frame:SetPoint("RIGHT", -40, 0)
	for i = 1, ROWS do
		ids[i] = i
		Text(i)
	end
	Place()
end

function Reorder.Reverse()
	local n = #ids
	for i = 1, math.floor(n / 2) do
		ids[i], ids[n - i + 1] = ids[n - i + 1], ids[i]
	end
	Place()
end

function Reorder.Rotate()
	table.insert(ids, table.remove(ids, 1))
	Place()
end

function Reorder.InsertFront()
	table.insert(ids, 1, nextId)
	Text(nextId)
	nextId = nextId + 1
	Place()
end

function Reorder.RemoveMiddle()
	local id = table.remove(ids, math.floor(#ids / 2))
	local text = textOf[id]
	text:Hide()
	textOf[id], slotOf[id] = nil, nil
	pool[#pool + 1] = text
	Place()
end

function Reorder.Shuffle()
	for i = #ids, 2, -1 do
		seed = (seed * 1103515245 + 12345) % 2147483648
		local j = seed % i + 1
		ids[i], ids[j] = ids[j], ids[i]
	end
	Place()
end

function Reorder.Show()
	frame:Show()
end

function Reorder.Hide()
	frame:Hide()
end

--- The frame the screen check reads (bench/screen.lua).
-- bench: begin
function Reorder.Root()
	return frame
end
-- bench: end

return Reorder
