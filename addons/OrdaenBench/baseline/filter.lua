-- filter, by hand at its best: 500 font strings made once; a new filter hides the items it drops, shows the ones it
-- keeps, and re-anchors only those whose place changed.
local FONT = import("bench/font")

local ITEMS, LINE = 500, import("bench/line")

local Filter = {}

local list, texts, slotOf = nil, {}, {}

function Filter.Make()
	list = CreateFrame("Frame", nil, UIParent)
	list:SetSize(120, ITEMS * LINE)
	list:SetPoint("LEFT", 300, 0)
	for id = 1, ITEMS do
		local text = list:CreateFontString(nil, "OVERLAY", FONT)
		text:SetFormattedText("item %d", id)
		text:Hide() -- shown by the first filter
		texts[id] = text
	end
	Filter.SetShift(0)
end

function Filter.SetShift(shift)
	local slot = 0
	for id = 1, ITEMS do
		local text = texts[id]
		if (id + shift) % 3 ~= 0 then
			slot = slot + 1
			if slotOf[id] ~= slot then
				if not slotOf[id] then
					text:Show()
				end
				slotOf[id] = slot
				text:SetPoint("TOPLEFT", 0, -(slot - 1) * LINE)
			end
		elseif slotOf[id] then
			slotOf[id] = nil
			text:Hide()
		end
	end
end

function Filter.Hide()
	list:Hide()
end

--- The frame the screen check reads (bench/screen.lua).
-- bench: begin
function Filter.Root()
	return list
end
-- bench: end

return Filter
