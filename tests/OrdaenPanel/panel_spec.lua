-- Ordaen Panel on the fake client, as built: Blizzard's own buttons it embeds (the micro menu over our cells, the bag
-- buttons) each get their own place in the panel. Several frames embedded from one call site in a loop are told
-- apart: none takes another's place, and none goes back to Blizzard's layout. Blizzard's bag bar, left with what the
-- panel doesn't show, is hidden.
local Fake = require("tests.fake.wow")

local DIST = ".ordaen/check/dist"

-- Blizzard's frames the panel takes, made the way FrameXML has them before any addon loads
local BLIZZARD = {
	"CharacterMicroButton", "ProfessionMicroButton", "SpellbookMicroButton", "TalentMicroButton", "LegacyMicroButton",
	"QuestLogMicroButton", "GuildMicroButton", "LFDMicroButton", "CollectionsMicroButton", "MainMenuMicroButton",
	"QuickJoinToastButton", "MainMenuBarBackpackButton", "CharacterBag0Slot", "CharacterBag1Slot", "CharacterBag2Slot",
	"CharacterBag3Slot",
}
local BAGS = { "MainMenuBarBackpackButton", "CharacterBag0Slot", "CharacterBag1Slot", "CharacterBag2Slot",
	"CharacterBag3Slot" }

describe("Ordaen Panel", function()
	local wow, home

	setup(function()
		wow = Fake.New({ dist = DIST, addons = { "OrdaenCore", "OrdaenPanel" } })
		home = wow.env.CreateFrame("Frame", "BagsBar", wow.env.UIParent)
		for _, name in ipairs(BLIZZARD) do
			local f = wow.env.CreateFrame("Button", name, home)
			f:SetSize(45, 45)
			f:SetPoint("CENTER", home, "CENTER", 0, 0)
		end
		wow:Login()
		wow:Tick()
	end)

	it("raises no Lua errors", function()
		assert.are.same({}, wow.errors)
	end)

	it("hides what stays in Blizzard's bag bar", function()
		assert.is_false(home:IsShown())
	end)

	it("embeds every bag button in its own place in the panel", function()
		local seen = {}
		for _, name in ipairs(BAGS) do
			local f = wow.env[name]
			assert.are_not.equal(home, f:GetParent(), name .. " stayed in Blizzard's bag bar")
			assert.is_true(f:IsShown(), name .. " is hidden")
			local _, rel, _, x, y = f:GetPoint(1)
			local at = tostring(rel) .. " " .. x .. "," .. y
			assert.is_nil(seen[at], name .. " sits where " .. tostring(seen[at]) .. " does")
			seen[at] = name
		end
	end)
end)
