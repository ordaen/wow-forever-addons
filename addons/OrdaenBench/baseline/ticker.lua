-- ticker, by hand: the font strings made once and placed one under the other; every frame sets each one's two
-- numbers with SetFormattedText (no Lua string made).
local FONT = import("bench/font")
local SIZES = { small = 50, large = 500 }
local LINE = import("bench/line")

local Ticker = {}

local frames, texts, ticks = {}, {}, {}

function Ticker.Make(size)
	local count = SIZES[size]
	local frame = CreateFrame("Frame", nil, UIParent)
	frame:SetSize(200, count * LINE)
	frame:SetPoint("LEFT", 40, 0)
	local list = {}
	for i = 1, count do
		local text = frame:CreateFontString(nil, "OVERLAY", FONT)
		text:SetPoint("TOPLEFT", 0, -(i - 1) * LINE)
		text:SetWidth(200) -- the framework's column is 200 wide, its texts left-aligned
		text:SetJustifyH("LEFT")
		list[i] = text
	end
	frames[size], texts[size], ticks[size] = frame, list, 0
end

function Ticker.Tick(size)
	local tick = ticks[size] + 1
	ticks[size] = tick
	local list = texts[size]
	local SetFormattedText = list[1].SetFormattedText -- looked up once: every font string shares it
	local a, b = tick * 0.1, tick * 0.2
	for i = 1, #list do
		SetFormattedText(list[i], "%.1f, %.1f", a + i, b - i)
	end
end

function Ticker.Show(size)
	frames[size]:Show()
end

function Ticker.Hide(size)
	frames[size]:Hide()
end

--- The frame the screen check reads (bench/screen.lua).
-- bench: begin
function Ticker.Root(size)
	return frames[size]
end
-- bench: end

return Ticker
