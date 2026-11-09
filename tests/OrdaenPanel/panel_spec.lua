-- Ordaen Panel on the fake client, as built: Blizzard's own buttons it embeds (the micro menu over our cells, the bag
-- buttons) each get their own place in the panel. Several frames embedded from one call site in a loop are told
-- apart: none takes another's place, and none goes back to Blizzard's layout. Blizzard's bag bar, left with what the
-- panel doesn't show, is hidden, and so are Blizzard's XP and reputation bars and the micro buttons the panel leaves
-- out; the micro menu's box stays shown (Blizzard's layout reads its buttons' positions) but invisible.
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

-- Blizzard's frames the panel draws its own of, left empty or unused
local REPLACED = { "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer", "StoreMicroButton",
	"HelpMicroButton" }

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
		for _, name in ipairs(REPLACED) do
			wow.env.CreateFrame("Frame", name, wow.env.UIParent)
		end
		wow.env.CreateFrame("Frame", "MicroMenuContainer", wow.env.UIParent)
		local count = wow.env.MainMenuBarBackpackButton:CreateFontString()
		wow.env.MainMenuBarBackpackButton.FreeSlots = count
		count:SetFont("Fonts\\ARIALN.TTF", 12, "")
		count:SetText("(23)")
		wow:Login()
		wow:Tick()
	end)

	it("hides Blizzard's XP and reputation bars and the micro buttons it leaves out", function()
		for _, name in ipairs(REPLACED) do
			assert.is_false(wow.env[name]:IsShown(), name .. " is shown")
		end
	end)

	it("shows the backpack's free slots in its slot, not Blizzard's count", function()
		assert.is_false(wow.env.MainMenuBarBackpackButton.FreeSlots:IsShown())
		local function shown(text)
			for frame in pairs(wow.allFrames) do
				for _, r in ipairs(frame._regions) do
					if r.GetText and r:GetText() == text and r:IsVisible() then
						return true
					end
				end
			end
			return false
		end
		assert.is_true(shown("23"), "no 23")
		wow.freeSlots = 7
		wow:Fire("BAG_UPDATE_DELAYED")
		wow:Tick()
		assert.is_true(shown("7"), "no 7")
		assert.is_false(shown("23"), "23 still shown")
	end)

	it("keeps Blizzard's micro menu box shown but invisible", function()
		assert.is_true(wow.env.MicroMenuContainer:IsShown())
		assert.are.equal(0, wow.env.MicroMenuContainer:GetAlpha())
	end)

	it("raises no Lua errors", function()
		assert.are.same({}, wow.errors)
	end)

	it("draws each positioned layer over the ones before it (the XP tube's ring over its fill)", function()
		local Core = wow.addons.OrdaenCore.ns.Core
		local stats = Core._BackendStats({})
		assert.are.equal(0, stats.order_errors)
	end)

	it("shows the money as it changes", function()
		wow.money = 12345
		wow:Fire("PLAYER_MONEY")
		wow:Tick()
		local shown = {}
		for frame in pairs(wow.allFrames) do
			for _, r in ipairs(frame._regions) do
				if r._text and r:IsVisible() then
					shown[r._text] = true
				end
			end
		end
		assert.is_true(shown["12345"], "the new amount isn't drawn")
		assert.is_nil(shown["0"], "the old amount is still drawn")
	end)

	it("counts the friends online on the social button", function()
		local shown = {}
		for frame in pairs(wow.allFrames) do
			for _, r in ipairs(frame._regions) do
				if r._text and r:IsVisible() then
					shown[r._text] = true
				end
			end
		end
		assert.is_true(shown["3"], "no \"3\" drawn")
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

describe("Ordaen Panel with the character button as a cell", function()
	it("puts Blizzard's character button in a micro menu cell, not over a corner portrait", function()
		local wow = Fake.New({ dist = DIST, addons = { "OrdaenCore", "OrdaenPanel" } })
		local home = wow.env.CreateFrame("Frame", "BagsBar", wow.env.UIParent)
		for _, name in ipairs(BLIZZARD) do
			local f = wow.env.CreateFrame("Button", name, home)
			f:SetSize(45, 45)
			f:SetPoint("CENTER", home, "CENTER", 0, 0)
		end
		wow.env.OrdaenPanelDB = { module = { charButton = "button" } }
		wow:Login()
		wow:Tick()
		assert.are.same({}, wow.errors)
		local button = wow.env.CharacterMicroButton
		assert.are_not.equal(home, button:GetParent())
		-- a cell's size (53 units high), not the portrait's (124)
		assert.is_true(math.abs(button._h - 53) < 1, "height " .. tostring(button._h))
	end)
end)

describe("Ordaen Panel with the gold micro menu icons", function()
	it("draws the micro menu's icons desaturated", function()
		local wow = Fake.New({ dist = DIST, addons = { "OrdaenCore", "OrdaenPanel" } })
		local home = wow.env.CreateFrame("Frame", "BagsBar", wow.env.UIParent)
		for _, name in ipairs(BLIZZARD) do
			wow.env.CreateFrame("Button", name, home):SetSize(45, 45)
		end
		wow.env.OrdaenPanelDB = { module = { microIcons = "gold" } }
		wow:Login()
		wow:Tick()
		assert.are.same({}, wow.errors)
		local gold = 0
		for frame in pairs(wow.allFrames) do
			for _, r in ipairs(frame._regions) do
				if r._desaturated and r:IsVisible() then
					gold = gold + 1
				end
			end
		end
		assert.is_true(gold >= 10, gold .. " desaturated textures; the micro menu has 10 icons")
	end)
end)
