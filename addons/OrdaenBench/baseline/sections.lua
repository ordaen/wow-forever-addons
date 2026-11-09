-- sections, by hand at its best: a header and 10 row font strings per section, made once, each anchored below the one
-- before it (chained anchors); a toggle shows or hides the section's rows and re-anchors only the next header, and
-- WoW moves everything below it.
local FONT = import("bench/font")

local SECTIONS, ROWS = 20, 10

local Sections = {}

local holder, headers, rows, open = nil, {}, {}, {}

-- The next section's header goes under this section's last shown line.
local function AnchorNext(s)
	local next = headers[s + 1]
	if next then
		next:SetPoint("TOPLEFT", open[s] and rows[s][ROWS] or headers[s], "BOTTOMLEFT")
	end
end

function Sections.Make()
	holder = CreateFrame("Frame", nil, UIParent)
	holder:SetSize(160, SECTIONS * (ROWS + 1) * 14)
	holder:SetPoint("TOPRIGHT", -40, -40)
	for s = 1, SECTIONS do
		local header = holder:CreateFontString(nil, "OVERLAY", FONT)
		header:SetFormattedText("Section %d", s)
		headers[s] = header
		local list, above = {}, header
		for r = 1, ROWS do
			local row = holder:CreateFontString(nil, "OVERLAY", FONT)
			row:SetFormattedText("  row %d.%d", s, r)
			row:SetPoint("TOPLEFT", above, "BOTTOMLEFT")
			list[r], above = row, row
		end
		rows[s], open[s] = list, true
	end
	headers[1]:SetPoint("TOPLEFT")
	for s = 1, SECTIONS - 1 do
		AnchorNext(s)
	end
end

function Sections.Toggle(s)
	local now = not open[s]
	open[s] = now
	local list = rows[s]
	for r = 1, ROWS do
		if now then
			list[r]:Show()
		else
			list[r]:Hide()
		end
	end
	AnchorNext(s)
end

function Sections.Hide()
	holder:Hide()
end

--- The frame the screen check reads (bench/screen.lua).
function Sections.Root()
	return holder
end

return Sections
