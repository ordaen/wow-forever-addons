-- events, by hand at its best: the handler counts per bag and marks the bag dirty; once per frame the dirty bags'
-- texts are set (the bench calls the handler as the game's OnEvent would).
local FONT = import("bench/font")

local BAGS, LINE = 5, 14

local Events = {}

local holder, texts, counts, dirty = nil, {}, {}, {}
local anyDirty = false

function Events.Make()
	holder = CreateFrame("Frame", nil, UIParent)
	holder:SetSize(120, BAGS * LINE)
	holder:SetPoint("TOPLEFT", 40, -300)
	for bag = 1, BAGS do
		local text = holder:CreateFontString(nil, "OVERLAY", FONT)
		text:SetPoint("TOPLEFT", 0, -(bag - 1) * LINE)
		text:SetFormattedText("bag %d: %d updates", bag, 0)
		texts[bag], counts[bag] = text, 0
	end
end

--- What the game's OnEvent would call for BAG_UPDATE.
function Events.OnBagUpdate(bag)
	counts[bag] = counts[bag] + 1
	dirty[bag] = true
	anyDirty = true
end

--- The frame's work: the dirty bags' texts.
function Events.Flush()
	if not anyDirty then
		return
	end
	anyDirty = false
	for bag = 1, BAGS do
		if dirty[bag] then
			dirty[bag] = false
			texts[bag]:SetFormattedText("bag %d: %d updates", bag, counts[bag])
		end
	end
end

function Events.Hide()
	holder:Hide()
end

--- The frame the screen check reads (bench/screen.lua).
function Events.Root()
	return holder
end

return Events
