-- What the bench is doing, on screen: one line at the top ("measured · block 7/40 · grid large"). It changes only
-- between blocks, in an untimed frame, so during a measurement it is one unchanging text on every side.
local Progress = {}

local frame, text

--- Show `line` (made on first use).
function Progress.Set(line)
	if not frame then
		frame = CreateFrame("Frame", nil, UIParent)
		frame:SetFrameStrata("DIALOG")
		frame:SetSize(600, 24)
		frame:SetPoint("TOP", 0, -12)
		text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		text:SetAllPoints()
	end
	text:SetText("Ordaen Bench: " .. line)
	frame:Show()
end

function Progress.Hide()
	if frame then
		frame:Hide()
	end
end

return Progress
