-- ticker, by hand: the font strings made once and placed one under the other; every frame sets each one's two
-- numbers with SetFormattedText (no Lua string made).
local SIZES = { small = 50, large = 500 }
local LINE = 14

local Ticker = {}

local frames, texts, ticks = {}, {}, {}

function Ticker.Make(size)
	local count = SIZES[size]
	local frame = CreateFrame("Frame", nil, UIParent)
	frame:SetSize(200, count * LINE)
	frame:SetPoint("LEFT", 40, 0)
	local list = {}
	for i = 1, count do
		local text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		text:SetPoint("TOPLEFT", 0, -(i - 1) * LINE)
		list[i] = text
	end
	frames[size], texts[size], ticks[size] = frame, list, 0
end

function Ticker.Tick(size)
	local tick = ticks[size] + 1
	ticks[size] = tick
	local list = texts[size]
	for i = 1, #list do
		list[i]:SetFormattedText("%.1f, %.1f", tick * 0.1 + i, tick * 0.2 - i)
	end
end

function Ticker.Hide(size)
	frames[size]:Hide()
end

return Ticker
