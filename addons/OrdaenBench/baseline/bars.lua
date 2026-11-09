-- bars, by hand at its best: a track texture and a fill texture per bar on one frame; a new fill sets its width.
local BARS, WIDTH, HEIGHT, GAP = 20, 200, 12, 2

local Bars = {}

local holder, fills = nil, {}

function Bars.Make()
	holder = CreateFrame("Frame", nil, UIParent)
	holder:SetSize(WIDTH, BARS * (HEIGHT + GAP))
	holder:SetPoint("BOTTOMLEFT", 40, 200)
	for i = 1, BARS do
		local y = -(i - 1) * (HEIGHT + GAP)
		local track = holder:CreateTexture(nil, "BACKGROUND")
		track:SetSize(WIDTH, HEIGHT)
		track:SetPoint("TOPLEFT", 0, y)
		track:SetColorTexture(0.3, 0.3, 0.35, 1)
		local fill = holder:CreateTexture(nil, "BORDER")
		fill:SetHeight(HEIGHT)
		fill:SetPoint("TOPLEFT", 0, y)
		fill:SetColorTexture(0.85, 0.65, 0.3, 1)
		fills[i] = fill
		Bars.SetFill(i, 50)
	end
end

function Bars.SetFill(i, percent)
	fills[i]:SetWidth(math.max(WIDTH * percent / 100, 0.01))
end

function Bars.Hide()
	holder:Hide()
end

return Bars
