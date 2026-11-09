-- sections, by hand at its best: a header and 10 row font strings per section, made once; a toggle shows or hides
-- the section's rows and re-anchors the sections below it.
local FONT = import("bench/font")

local SECTIONS, ROWS, LINE = 20, 10, 14

local Sections = {}

local holder, headers, rows, open = nil, {}, {}, {}

local function Place(from)
	local y = 0
	for s = 1, SECTIONS do
		if s >= from then
			headers[s]:SetPoint("TOPLEFT", 0, -y)
		end
		y = y + LINE
		if open[s] then
			local list = rows[s]
			for r = 1, ROWS do
				if s >= from then
					list[r]:SetPoint("TOPLEFT", 0, -y)
				end
				y = y + LINE
			end
		end
	end
end

function Sections.Make()
	holder = CreateFrame("Frame", nil, UIParent)
	holder:SetSize(160, SECTIONS * (ROWS + 1) * LINE)
	holder:SetPoint("TOPRIGHT", -40, -40)
	for s = 1, SECTIONS do
		local header = holder:CreateFontString(nil, "OVERLAY", FONT)
		header:SetFormattedText("Section %d", s)
		headers[s] = header
		local list = {}
		for r = 1, ROWS do
			local row = holder:CreateFontString(nil, "OVERLAY", FONT)
			row:SetFormattedText("  row %d.%d", s, r)
			list[r] = row
		end
		rows[s], open[s] = list, true
	end
	Place(1)
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
	Place(s + 1)
end

function Sections.Hide()
	holder:Hide()
end

return Sections
