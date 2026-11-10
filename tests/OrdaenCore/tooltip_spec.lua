-- Blizzard's tooltips taken by a module (addons/OrdaenCore/Tooltip.lua) on the fake client, as built: each show the
-- module draws keeps Blizzard's at alpha 0 and bumps `shown` with the data and owner; one it doesn't want stays
-- Blizzard's; hiding gives it back; an addon's fade reaches the view, never Blizzard's.
local Fake = require("tests.fake.wow")

local DIST = ".ordaen/check/dist"
local ITEM = { type = 0, id = 2589, lines = { { type = 22, leftText = "Linen Cloth" } } }
local SPELL = { type = 1, id = 6673, lines = { { type = 13, leftText = "Battle Shout" } } }

describe("Blizzard's tooltips", function()
	local wow, ns, tip, native

	before_each(function()
		wow = Fake.New({ dist = DIST, addons = { "OrdaenCore" } })
		wow:MakeTooltips()
		wow:Login()
		ns = wow.addons.OrdaenCore.ns
		tip = ns.Game.Tooltip.GameTooltip
		native = wow.env.GameTooltip
		tip:Take(function(t)
			return t.data.type == 0 -- items only
		end)
	end)

	it("hides Blizzard's for a show the module draws, with its data, owner and point", function()
		local button = wow.env.CreateFrame("Button", nil, wow.env.UIParent)
		wow:ShowTooltip("GameTooltip", ITEM, button)
		assert.is_true(tip.shown:Peek() > 0)
		assert.are.equal(0, native:GetAlpha())
		assert.are.equal(2589, tip.data.id)
		assert.are.equal(button, tip.owner)
		assert.are.equal("BOTTOMRIGHT", tip.point)
		native:SetAlpha(1) -- Blizzard resets it, or another addon fades it
		assert.are.equal(0, native:GetAlpha())
	end)

	it("leaves a show it doesn't want to Blizzard, and gives it back when hidden or released", function()
		wow:ShowTooltip("GameTooltip", ITEM)
		local first = tip.shown:Peek()
		wow:ShowTooltip("GameTooltip", SPELL)
		assert.are.equal(0, tip.shown:Peek())
		assert.are.equal(1, native:GetAlpha())
		wow:ShowTooltip("GameTooltip", ITEM)
		assert.is_true(tip.shown:Peek() > first)
		native:Hide()
		assert.are.equal(0, tip.shown:Peek())
		assert.are.equal(1, native:GetAlpha())
		wow:ShowTooltip("GameTooltip", ITEM)
		tip:Release()
		assert.are.equal(1, native:GetAlpha())
		assert.are.same({}, wow.errors)
	end)
end)
