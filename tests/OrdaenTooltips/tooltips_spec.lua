-- Ordaen Tooltips on the fake client, as built: Blizzard's tooltip shown with an item, a spell, an aura or a unit
-- becomes ours (design tooltips/: header, title, columns with glyphs, rows, footer; tooltips beside it), Blizzard's
-- kept at alpha 0; a type switched off stays Blizzard's; hidden, ours goes. The game's APIs are stubbed with what the
-- design pages show.
local Fake = require("tests.fake.wow")

local DIST = ".ordaen/check/dist"

local function Color(r, g, b)
	return { r = r, g = g, b = b }
end

local AXE = { type = 0, id = 2845, hyperlink = "item:2845", lines = {
	{ type = 22, leftText = "Copper Axe", quality = 2 },
	{ type = 20, leftText = "Binds when equipped", bonding = 7 },
	{ type = 21, leftText = "One-Hand", rightText = "Axe", isValidInvSlot = true, isValidItemType = false },
	{ type = 0, leftText = "Unique" },
	{ type = 0, leftText = "7 - 13 Damage", rightText = "Speed 2.60" },
	{ type = 0, leftText = "(3.8 damage per second)" },
	{ type = 0, leftText = "+3 Strength" },
	{ type = 44, leftText = "Use: Restores 66 health.", spellID = 746 },
	{ type = 0, leftText = "Durability 0 / 35" },
	{ type = 43, leftText = "Requires Level 9", usable = false },
	{ type = 11, leftText = "", price = 345 },
} }
local WORN = { type = 0, id = 1, hyperlink = "item:1", lines = {
	{ type = 22, leftText = "Rusty Axe", quality = 1 },
	{ type = 0, leftText = "+1 Strength" },
} }
local BANDAGE = { type = 1, id = 746, lines = {
	{ type = 13, leftText = "First Aid" },
	{ type = 0, leftText = "Instant", rightText = "Cooldown: 1 min." },
	{ type = 34, leftText = "Heals 66 damage over 6 sec." },
} }
local SHOUT = { type = 1, id = 6673, lines = {
	{ type = 13, leftText = "Battle Shout", rightText = "Rank 1" },
	{ type = 0, leftText = "Rage: 10", rightText = "Melee Range", leftColor = Color(1, 1, 1) }, -- Forever's form
	{ type = 0, leftText = "Instant", rightText = "Cooldown: 10 sec.", leftColor = Color(1, 1, 1) },
	{ type = 34, leftText = "The warrior shouts, increasing attack power by 15 for «Battle Shout»." },
} }
local CHARGE = { type = 1, id = 100, lines = {
	{ type = 13, leftText = "Charge" },
	{ type = 0, leftText = "Range: 8-25 yd." }, -- the range alone (no cost)
	{ type = 0, leftText = "Instant", rightText = "Cooldown: 15 sec." },
	{ type = 34, leftText = "Charges an enemy; then «Rend» bleeds it and «Charge» can't again." },
} }
local REND = { type = 1, id = 772, lines = {
	{ type = 13, leftText = "Rend" },
	{ type = 34, leftText = "Wounds the target for 15 damage over 9 sec." },
} }
local LIFE_TAP = { type = 1, id = 1454, lines = {
	{ type = 13, leftText = "Life Tap" },
	{ type = 0, leftText = "Health: 30" }, -- a cost in health
	{ type = 0, leftText = "Instant" },
	{ type = 34, leftText = "Converts 30 health into 30 mana." },
} }
local HEROIC = { type = 1, id = 78, lines = {
	{ type = 13, leftText = "Heroic Strike" },
	{ type = 0, leftText = "Rage: 15", rightText = "Melee Range" },
	{ type = 0, leftText = "Next melee" },
	{ type = 34, leftText = "A strong attack that increases melee damage by 11." },
} }
local GUARD = { type = 2, guid = "Creature-1", lines = {
	{ type = 2, leftText = "Stormwind Guard", unitToken = "mouseover" },
	{ type = 0, leftText = "Level 55" },
	{ type = 0, leftText = "Stormwind" },
	{ type = 0, leftText = "PvP" },
} }
local MIGHT = { type = 7, id = 19834, lines = {
	{ type = 0, leftText = "Blessing of Might" },
	{ type = 0, leftText = "ID 19834" },
	{ type = 0, leftText = "Increases attack power by 20." },
} }

describe("Ordaen Tooltips", function()
	local wow, ns, unitIsPlayer

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

	-- the first node on the tooltip layer `pred` accepts
	local function find(pred)
		local found
		local function walk(node)
			if not found and pred(node) then
				found = node
			end
			for i = 1, node.count or 0 do
				walk(node.children[i])
			end
		end
		walk(ns.Game.Layer.Tooltip.node)
		return found
	end

	local function has(shown, ...)
		for _, part in ipairs({ ... }) do
			assert.is_truthy(shown:find(part, 1, true), part .. " missing in:\n" .. shown)
		end
	end

	before_each(function()
		wow = Fake.New({ dist = DIST, addons = { "OrdaenCore", "OrdaenLibrary", "OrdaenTooltips" } })
		wow:MakeTooltips()
		local env = wow.env
		unitIsPlayer = false
		env.C_Item = {
			GetItemIconByID = function()
				return 135421
			end,
			GetItemInfo = function(id)
				return "x", "item:" .. id, 2, id == 1 and 5 or 12
			end,
			GetItemStats = function(link)
				return link == "item:1" and { ITEM_MOD_STRENGTH_SHORT = 1 } or { ITEM_MOD_STRENGTH_SHORT = 3 }
			end,
			GetItemLinkByGUID = function() end,
			GetItemMaxStackSizeByID = function()
				return 1
			end,
			GetItemCount = function()
				return 1
			end,
		}
		env.C_Container = { GetItemCooldown = function()
			return 0, 0
		end }
		env.C_Spell = {
			GetSpellTexture = function()
				return 132333
			end,
			GetSpellPowerCost = function(id)
				return id == 6673 and { { type = 1, cost = 10 } } or id == 1454 and { { type = -2, name = "HEALTH", cost = 30 } }
					or {}
			end,
			GetSpellCooldown = function()
				return { startTime = 0, duration = 0 }
			end,
		}
		env.C_TooltipInfo = { GetSpellByID = function(id)
			return id == 746 and BANDAGE or id == 772 and REND or nil
		end, GetItemByID = function() end, GetHyperlink = function() end }
		-- the spellbook: one line with Charge and Rend
		env.C_SpellBook = {
			GetNumSpellBookSkillLines = function()
				return 1
			end,
			GetSpellBookSkillLineInfo = function()
				return { itemIndexOffset = 0, numSpellBookItems = 2 }
			end,
			GetSpellBookItemInfo = function(slot)
				return slot == 1 and { name = "Charge", spellID = 100 } or { name = "Rend", spellID = 772 }
			end,
		}
		env.C_UnitAuras = { GetPlayerAuraBySpellID = function()
			return { isHarmful = false, applications = 3, expirationTime = 70, sourceUnit = "player",
				dispelName = "Magic" }
		end, GetAuraDataByAuraInstanceID = function() end }
		env.PowerBarColor = { [1] = Color(1, 0, 0) }
		env.ITEM_MOD_STRENGTH_SHORT = "Strength"
		env.GetMoneyString = function(copper)
			return copper .. "c"
		end
		env.SELL_PRICE = "Sell Price"
		env.ITEM_QUALITY_COLORS = { [1] = Color(1, 1, 1), [2] = Color(0.12, 1, 0) }
		env.UnitIsPlayer = function()
			return unitIsPlayer
		end
		env.UnitExists = function()
			return true
		end
		env.UnitName = function(unit)
			return unit == "player" and "Me" or "Stormwind Guard"
		end
		env.UnitReaction = function()
			return 5
		end
		env.UnitLevel = function()
			return 55
		end
		env.UnitIsTapDenied = function()
			return false
		end
		env.UnitCreatureType = function()
			return "Humanoid"
		end
		env.UnitIsDead = function()
			return false
		end
		env.UnitClassification = function()
			return "elite"
		end
		env.UnitFactionGroup = function()
			return "Alliance", "Alliance"
		end
		env.UnitClass = function()
			return "Warrior", "WARRIOR"
		end
		env.RAID_CLASS_COLORS = { WARRIOR = Color(0.78, 0.61, 0.43) }
		env.FACTION_BAR_COLORS = { [5] = Color(0, 0.6, 0.1) }
		env.GetTime = function()
			return 10
		end
		env.SECOND_ONELETTER_ABBR = "%d s"
		env.MINUTE_ONELETTER_ABBR = "%d m"
		-- Blizzard's format strings (enUS), from which the lines are read
		env.DAMAGE_TEMPLATE = "%s - %s Damage"
		env.DPS_TEMPLATE = "(%.1f damage per second)"
		env.ARMOR_TEMPLATE = "%s Armor"
		env.DURABILITY_TEMPLATE = "Durability %d / %d"
		env.CONTAINER_SLOTS = "%d Slot %s"
		env.ITEM_UNIQUE = "Unique"
		env.SPELL_CAST_TIME_INSTANT = "Instant"
		env.SPELL_RANGE = "%s yd range"
		env.SPELL_ON_NEXT_SWING = "Next melee"
		wow:Login()
		ns = wow.addons.OrdaenCore.ns
	end)

	it("draws an item: title, glyphed columns, stat rows, its use effect beside it, the footer", function()
		wow:ShowTooltip("GameTooltip", AXE)
		ns.Scheduler.Flush()
		local shown = texts()
		has(shown, "Copper Axe", "One-Hand\n · \nAxe\n · \nUnique", "Binds when equipped") -- the title's parts
		has(shown, "7–13", "2.6/s", "3.8 DPS")
		has(shown, "Item level\n12", "Strength\n+3")
		assert.is_falsy(shown:find("+3 Strength", 1, true)) -- the stat line became its row
		has(shown, "First Aid", "Heals |cffffffff66|r damage", "CD 1 min.") -- the use effect: its own tooltip beside
		has(shown, "Durability", "0 / 35", "Requires Level 9", "345c")
		assert.are.equal(0, wow.env.GameTooltip:GetAlpha())
		assert.are.same({}, wow.errors)
	end)

	it("compares the hovered item with the equipped one: «Equipped» over it, the difference on the hovered rows",
		function()
			wow:ShowTooltip("GameTooltip", AXE)
			wow:ShowTooltip("ShoppingTooltip1", WORN)
			ns.Scheduler.Flush()
			local shown = texts()
			has(shown, "Equipped", "Rusty Axe", "+3 |cff1eff00(▲2)|r")
			assert.are.same({}, wow.errors)
		end)

	it("draws a spell: the cost a dot, instant and the cooldown short, the description's numbers lit", function()
		wow:ShowTooltip("GameTooltip", SHOUT)
		ns.Scheduler.Flush()
		local shown = texts()
		has(shown, "Battle Shout", "Rank 1", "5 yd", "CD 10 sec.") -- melee range: its distance
		assert.is_falsy(shown:find("Melee range", 1, true))
		has(shown, "|cffffffff15|r", "|cffffd100«Battle Shout»|r")
		assert.is_falsy(shown:find("Cooldown:", 1, true)) -- the cooldown in short
		assert.is_falsy(shown:find("Rage:", 1, true)) -- the cost: its dot and number
		assert.are.same({}, wow.errors)
	end)

	it("draws any resource's cost as its dot: health green", function()
		wow:ShowTooltip("GameTooltip", LIFE_TAP)
		ns.Scheduler.Flush()
		assert.is_falsy(texts():find("Health:", 1, true))
		local dot = find(function(node)
			return node.a and type(node.a.tint) == "table"
		end)
		assert.is_truthy(dot)
		assert.is_true(dot.a.tint[2] > 0.8 and dot.a.tint[1] < 0.2) -- green
		assert.are.same({}, wow.errors)
	end)

	it("draws «next melee» as a cast: its glyph and the short word", function()
		wow:ShowTooltip("GameTooltip", HEROIC)
		ns.Scheduler.Flush()
		local shown = texts()
		has(shown, "Next")
		assert.is_falsy(shown:find("Next melee", 1, true))
		assert.are.same({}, wow.errors)
	end)

	it("draws an aura: buff, dispel type, yours; stacks and time in the band; who cast it", function()
		wow:ShowTooltip("GameTooltip", MIGHT)
		ns.Scheduler.Flush()
		local shown = texts()
		has(shown, "Blessing of Might", "Buff", "Magic", "Yours", "×3", "1 m", "Increases attack power by")
		has(shown, "Cast by", "You")
		assert.is_falsy(shown:find("ID 19834", 1, true)) -- Forever's own line goes
		assert.are.same({}, wow.errors)
	end)

	it("draws an NPC and a player, and leaves a type switched off to Blizzard", function()
		wow:ShowTooltip("GameTooltip", GUARD)
		ns.Scheduler.Flush()
		local shown = texts()
		has(shown, "Stormwind Guard", "Humanoid", "Level 55", "Elite", "Stormwind")
		unitIsPlayer = true
		wow.env.UnitPVPName = function()
			return "Sergeant Stormwind Guard"
		end
		wow.env.GetGuildInfo = function()
			return "Istanbul", "Officer"
		end
		wow.env.UnitRace = function()
			return "Human"
		end
		for _, name in ipairs({ "UnitIsDeadOrGhost", "UnitIsGhost", "UnitIsAFK", "UnitIsDND", "UnitIsPVP",
			"UnitInRaid", "UnitInParty" }) do
			wow.env[name] = function()
				return false
			end
		end
		wow.env.UnitGUID = function()
			return "Player-1"
		end
		wow.env.C_FriendList = { IsFriend = function()
			return false
		end, IsIgnored = function()
			return false
		end }
		wow:ShowTooltip("GameTooltip", GUARD)
		ns.Scheduler.Flush()
		shown = texts()
		has(shown, "Istanbul\n · \nOfficer", "Warrior", "Human", "Sergeant")
		local module = ns.App.Module("OrdaenTooltips")
		module.root.state.persistent.playersOn:Set(false)
		wow:ShowTooltip("GameTooltip", GUARD)
		ns.Scheduler.Flush()
		assert.are.equal(1, wow.env.GameTooltip:GetAlpha())
		assert.are.equal("", texts())
		assert.are.same({}, wow.errors)
	end)

	it("sits above any button it belongs to (whatever bar drew it), and in the game's place for a unit frame", function()
		local button = wow.env.CreateFrame("Frame", nil, wow.env.UIParent) -- any frame: another bar's button
		button:SetSize(40, 40)
		button:SetPoint("BOTTOMLEFT", wow.env.UIParent, "BOTTOMLEFT", 100, 10)
		wow:ShowTooltip("GameTooltip", SHOUT, button)
		ns.Scheduler.Flush()
		local view = ns.App.Module("OrdaenTooltips").root.anchors.GameTooltip
		assert.are.equal(button, view and view.to)
		assert.is_false(view.below) -- above it, the left edges lined up
		assert.is_false(view.right)
		local box = find(function(node)
			return node.a and node.a.position == "fixed"
		end)
		assert.are.equal("BOTTOMLEFT", box.a.anchor.point)
		assert.are.equal("TOPLEFT", box.a.anchor.relativePoint)
		assert.are.equal("end", box.a.yAlign) -- every tooltip's bottom on the owner
		-- in the screen's upper right: below it, the right edges lined up
		button:ClearAllPoints()
		button:SetPoint("TOPRIGHT", wow.env.UIParent, "TOPRIGHT", -10, -10)
		wow:ShowTooltip("GameTooltip", AXE, button)
		ns.Scheduler.Flush()
		ns.Scheduler.Flush()
		box = find(function(node)
			return node.a and node.a.position == "fixed"
		end)
		assert.are.equal("TOPRIGHT", box.a.anchor.point)
		assert.are.equal("BOTTOMRIGHT", box.a.anchor.relativePoint)
		assert.are.equal("start", box.a.yAlign)
		local unitFrame = wow.env.CreateFrame("Button", nil, wow.env.UIParent)
		unitFrame:SetSize(40, 40)
		unitFrame:SetPoint("CENTER")
		unitFrame:SetAttribute("unit", "player")
		wow:ShowTooltip("GameTooltip", SHOUT, unitFrame)
		ns.Scheduler.Flush()
		assert.is_nil(ns.App.Module("OrdaenTooltips").root.anchors.GameTooltip)
		assert.are.same({}, wow.errors)
	end)

	it("goes when Blizzard's tooltip hides", function()
		wow:ShowTooltip("GameTooltip", AXE)
		ns.Scheduler.Flush()
		wow.env.GameTooltip:Hide()
		ns.Scheduler.Flush()
		assert.are.equal("", texts())
	end)

	-- the lock (design «Tooltips in tooltips»): held 1 s, the tooltip locks and stays after Blizzard's goes; the mouse
	-- leaving it closes it after the grace, a new tooltip or the X at once
	describe("the lock", function()
		local function closeButton()
			return find(function(node)
				return node.a and node.a.OnClick -- the only click on the tooltip layer
			end)
		end
		local function group()
			return find(function(node)
				return node.a and node.a.OnLeave
			end)
		end
		local function wait(seconds)
			for _ = 1, math.ceil(seconds / wow.frameTime) do
				wow:Tick()
			end
			ns.Scheduler.Flush()
		end

		before_each(function()
			wow.env.GetTime = function()
				return wow.time
			end
		end)

		it("charges for a second, locks, and stays after Blizzard's tooltip hides", function()
			wow:ShowTooltip("GameTooltip", AXE)
			ns.Scheduler.Flush()
			wait(0.1)
			assert.is_nil(find(function(node) -- a passing mouse sees no bar: its track isn't drawn yet
				return node.a and type(node.a.background) == "table" and node.a.background[4] == 0.45
			end))
			wait(0.4)
			assert.is_nil(closeButton())
			-- the bar: the tooltip's last section (in the layout, not over it), partly full
			local fill = find(function(node)
				local w = node.a and node.a.position == "absolute" and type(node.a.width) == "string"
					and tonumber(node.a.width:match("^([%d.]+)%%$"))
				return w and w > 0 and w < 100
			end)
			assert.is_truthy(fill)
			wait(0.8)
			assert.is_truthy(closeButton())
			assert.is_truthy(find(function(node) -- locked: full, and it stays
				return node.a and node.a.position == "absolute" and node.a.width == "100%"
			end))
			wow.env.GameTooltip:Hide()
			ns.Scheduler.Flush()
			has(texts(), "Copper Axe")
			assert.are.same({}, wow.errors)
		end)

		it("keeps charging while Blizzard shows the same thing again (it refreshes a button's or bag item's tooltip)",
			function()
				for _ = 1, 4 do
					wow:ShowTooltip("GameTooltip", AXE)
					wait(0.25)
				end
				wait(0.3)
				assert.is_truthy(closeButton())
				wow:ShowTooltip("GameTooltip", AXE) -- shown again while locked: still locked
				ns.Scheduler.Flush()
				assert.is_truthy(closeButton())
				assert.are.same({}, wow.errors)
			end)

		it("keeps charging through Blizzard's refresh (hidden and shown again at once), not through a real leave",
			function()
				wow:ShowTooltip("GameTooltip", AXE)
				wait(0.5)
				wow.env.GameTooltip:Hide()
				wow:ShowTooltip("GameTooltip", AXE)
				wait(0.8)
				assert.is_truthy(closeButton())
				closeButton().a.OnClick()
				wow:ShowTooltip("GameTooltip", SHOUT)
				wait(0.5)
				wow.env.GameTooltip:Hide()
				wait(0.2) -- the mouse left: the charge ends
				wow:ShowTooltip("GameTooltip", SHOUT)
				wait(0.6)
				assert.is_nil(closeButton())
				assert.are.same({}, wow.errors)
			end)

		it("keeps the comparison in the locked group", function()
			wow:ShowTooltip("GameTooltip", AXE)
			wow:ShowTooltip("ShoppingTooltip1", WORN)
			wait(1.3)
			wow.env.ShoppingTooltip1:Hide()
			wow.env.GameTooltip:Hide()
			ns.Scheduler.Flush()
			has(texts(), "Copper Axe", "Rusty Axe", "Equipped")
			assert.are.same({}, wow.errors)
		end)

		it("closes when the mouse leaves it, after the grace, and not when it comes back in time", function()
			wow:ShowTooltip("GameTooltip", AXE)
			wait(1.3)
			wow.env.GameTooltip:Hide()
			ns.Scheduler.Flush()
			local g = group()
			g.a.OnLeave()
			wait(0.1)
			g.a.OnEnter()
			wait(0.3)
			has(texts(), "Copper Axe")
			g.a.OnLeave()
			wait(0.3)
			assert.are.equal("", texts())
			assert.are.same({}, wow.errors)
		end)

		it("closes on its X and when another tooltip starts", function()
			wow:ShowTooltip("GameTooltip", AXE)
			wait(1.3)
			wow.env.GameTooltip:Hide()
			ns.Scheduler.Flush()
			closeButton().a.OnClick()
			ns.Scheduler.Flush()
			assert.are.equal("", texts())
			wow:ShowTooltip("GameTooltip", AXE)
			wait(1.3)
			wow.env.GameTooltip:Hide()
			wow:ShowTooltip("GameTooltip", SHOUT)
			ns.Scheduler.Flush()
			local shown = texts()
			has(shown, "Battle Shout")
			assert.is_falsy(shown:find("Copper Axe", 1, true))
			assert.are.same({}, wow.errors)
		end)
		it("opens a cell's term once locked: the cost's resource with its amount; left, it goes", function()
			wow:ShowTooltip("GameTooltip", SHOUT)
			ns.Scheduler.Flush()
			local function cell()
				return find(function(node)
					return node.a and node.a.OnEnter and not node.a.hoverWithin
				end)
			end
			local function underline()
				return find(function(node)
					return node.a and type(node.a.background) == "table" and node.a.background.tile == true
				end)
			end
			assert.is_nil(cell()) -- not locked: the cells take no mouse
			assert.is_nil(underline()) -- and nothing is underlined
			wait(1.3)
			assert.is_truthy(underline()) -- locked: a term's text gets the gold dashes
			local c = cell()
			wow.mouseFocus = c.frame
			c.a.OnEnter()
			ns.Scheduler.Flush()
			has(texts(), "Rage: 10", "The ability's rage cost.")
			assert.is_truthy(wow.cursor and wow.cursor:find("QuestTurnIn", 1, true)) -- the help cursor on a term
			local at = find(function(node)
				return node.a and node.a.position == "fixed" and node.a.anchor and node.a.anchor.to == c.frame
			end)
			assert.is_truthy(at) -- the term's tooltip opens at the text it explains
			c.a.OnLeave()
			assert.is_nil(wow.cursor)
			wait(0.3)
			assert.is_falsy(texts():find("Rage: 10", 1, true))
			assert.are.same({}, wow.errors)
		end)

		it("links a description's spell names once locked; hovered, the spell's tooltip opens beside, left, it goes",
			function()
				wow:ShowTooltip("GameTooltip", CHARGE)
				ns.Scheduler.Flush()
				local shown = texts()
				has(shown, "|Hordaen:spell:772|h«Rend»|h") -- another spell of the book: a link
				has(shown, "|cffffd100«Charge»|r") -- its own name stays plain
				has(shown, "8-25 yd", "CD 15 sec.") -- the range alone, its label dropped; the cooldown short
				assert.is_falsy(shown:find("Range:", 1, true))
				assert.is_nil(find(function(node)
					return node.a and node.a.OnLink
				end)) -- not locked: no links
				wait(1.3)
				local row = find(function(node)
					return node.a and node.a.OnLink
				end)
				wow.mouseFocus = row.frame -- the text under the mouse: the tooltip opens at it
				row.a.OnLink("ordaen:spell:772", true)
				ns.Scheduler.Flush()
				has(texts(), "Wounds the target for")
				row.a.OnLink("ordaen:spell:772", false)
				wait(0.3)
				assert.is_falsy(texts():find("Wounds the target for", 1, true))
				has(texts(), "Charge")
				assert.are.same({}, wow.errors)
			end)
	end)
end)
