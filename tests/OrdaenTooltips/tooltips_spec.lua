-- Ordaen Tooltips on the fake client, as built: Blizzard's tooltip shown with an item, a spell or a unit becomes ours
-- (the one skeleton: title, description, info, body, footer) where Blizzard placed it, Blizzard's kept at alpha 0; a
-- type switched off stays Blizzard's; hidden, ours goes.
local Fake = require("tests.fake.wow")

local DIST = ".ordaen/check/dist"

local function Color(r, g, b)
	return { r = r, g = g, b = b }
end

local MACE = { type = 0, id = 2845, lines = {
	{ type = 22, leftText = "Copper Axe", quality = 2 },
	{ type = 20, leftText = "Binds when equipped", bonding = 7 },
	{ type = 21, leftText = "One-Hand", rightText = "Axe", isValidInvSlot = true, isValidItemType = false },
	{ type = 0, leftText = "Unique" },
	{ type = 0, leftText = "7 - 13 Damage", rightText = "Speed 2.60" },
	{ type = 0, leftText = "(3.8 damage per second)" },
	{ type = 0, leftText = "+3 Strength" },
	{ type = 0, leftText = "Durability 0 / 35" },
	{ type = 43, leftText = "Requires Level 9", usable = false },
	{ type = 11, leftText = "", price = 345 },
} }
local SHOUT = { type = 1, id = 6673, lines = {
	{ type = 13, leftText = "Battle Shout", rightText = "Rank 1" },
	{ type = 0, leftText = "10 Rage", rightText = "Melee range", leftColor = Color(1, 1, 1) },
	{ type = 34, leftText = "The warrior shouts, increasing attack power." },
} }
local GUARD = { type = 2, guid = "Creature-1", lines = {
	{ type = 2, leftText = "Stormwind Guard", unitToken = "mouseover" },
	{ type = 0, leftText = "Level 55" },
	{ type = 0, leftText = "Stormwind" },
} }

describe("Ordaen Tooltips", function()
	local wow, ns

	local function texts()
		local out = {}
		local function walk(node)
			if node.kind == "text" and node.fs:IsVisible() then
				out[#out + 1] = node.fs:GetText()
			end
			for i = 1, node.count or 0 do
				walk(node.children[i])
			end
		end
		walk(ns.Game.Layer.Tooltip.node)
		return table.concat(out, "\n")
	end

	before_each(function()
		wow = Fake.New({ dist = DIST, addons = { "OrdaenCore", "OrdaenLibrary", "OrdaenTooltips" } })
		wow:MakeTooltips()
		local env = wow.env
		env.C_Item = { GetItemIconByID = function()
			return 135421
		end }
		env.C_Spell = { GetSpellTexture = function()
			return 132333
		end }
		env.GetMoneyString = function(copper)
			return copper .. "c"
		end
		env.SELL_PRICE = "Sell Price"
		env.ITEM_QUALITY_COLORS = { [2] = Color(0.12, 1, 0) }
		env.UnitIsPlayer = function()
			return false
		end
		env.UnitReaction = function()
			return 5
		end
		env.FACTION_BAR_COLORS = { [5] = Color(0, 0.6, 0.1) }
		-- Blizzard's format strings (enUS), from which the lines are read
		env.DAMAGE_TEMPLATE = "%s - %s Damage"
		env.DPS_TEMPLATE = "(%.1f damage per second)"
		env.ARMOR_TEMPLATE = "%s Armor"
		env.DURABILITY_TEMPLATE = "Durability %d / %d"
		env.CONTAINER_SLOTS = "%d Slot %s"
		env.ITEM_UNIQUE = "Unique"
		env.C_Item.GetItemInfo = function()
			return "Copper Axe", nil, 2, 12
		end
		wow:Login()
		ns = wow.addons.OrdaenCore.ns
	end)

	it("draws an item in the skeleton where Blizzard placed its tooltip, Blizzard's invisible", function()
		wow:ShowTooltip("GameTooltip", MACE)
		ns.Scheduler.Flush()
		assert.is_true(ns.Game.Tooltip.GameTooltip.shown:Peek() > 0, "not taken")
		assert.are.same({}, wow.errors)
		local shown = texts()
		assert.is_truthy(shown:find("Copper Axe", 1, true), shown)
		assert.is_truthy(shown:find("One-Hand · |cffff3f3fAxe|r", 1, true), shown) -- a type this class can't use: red
		assert.is_truthy(shown:find("Binds when equipped", 1, true))
		assert.is_truthy(shown:find("Axe|r · Unique", 1, true), shown) -- «Уникальный» joins the description
		assert.is_truthy(shown:find("7–13", 1, true) and shown:find("2.6/s", 1, true) and shown:find("3.8 DPS", 1, true), shown)
		assert.is_truthy(shown:find("Item level\n12\n", 1, true), shown) -- the first stat row
		assert.is_truthy(shown:find("Durability", 1, true) and shown:find("0 / 35", 1, true))
		assert.is_falsy(shown:find("Damage", 1, true)) -- read into the columns, not a line
		assert.is_truthy(shown:find("+3 Strength", 1, true))
		assert.is_truthy(shown:find("Requires Level 9", 1, true))
		assert.is_truthy(shown:find("345c", 1, true))
		assert.are.equal(0, wow.env.GameTooltip:GetAlpha())
		assert.are.same({}, wow.errors)
	end)

	it("draws a spell and a unit, and leaves a type switched off to Blizzard", function()
		wow:ShowTooltip("GameTooltip", SHOUT)
		ns.Scheduler.Flush()
		local shown = texts()
		assert.is_truthy(shown:find("Battle Shout", 1, true) and shown:find("Rank 1", 1, true), shown)
		assert.is_truthy(shown:find("10 Rage", 1, true) and shown:find("Melee range", 1, true))
		assert.is_truthy(shown:find("increasing attack power", 1, true))
		wow:ShowTooltip("GameTooltip", GUARD)
		ns.Scheduler.Flush()
		shown = texts()
		assert.is_truthy(shown:find("Stormwind Guard", 1, true) and not shown:find("Battle Shout", 1, true), shown)
		local module = ns.App.Module("OrdaenTooltips")
		module.root.state.persistent.npcsOn:Set(false)
		wow:ShowTooltip("GameTooltip", GUARD)
		ns.Scheduler.Flush()
		assert.are.equal(1, wow.env.GameTooltip:GetAlpha())
		assert.are.equal("", texts())
		assert.are.same({}, wow.errors)
	end)

	it("goes when Blizzard's tooltip hides", function()
		wow:ShowTooltip("GameTooltip", MACE)
		ns.Scheduler.Flush()
		wow.env.GameTooltip:Hide()
		ns.Scheduler.Flush()
		assert.are.equal("", texts())
	end)
end)
