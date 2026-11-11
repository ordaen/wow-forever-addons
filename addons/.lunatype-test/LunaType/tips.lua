-- The client's own tooltips as the client fills them: `"$game"`'s `Tooltip`. The client and every addon keep filling
-- them as always; what one shows is read on each show and handed on as data, and while an addon draws a show
-- itself (`hide(true)`) the client's is kept unseen, at alpha 0.
--
-- Safe by refusal: in combat some values are secret and some frames forbidden. A show that can't be read stays the
-- client's: it is told as not shown. Hooks only (`hooksecurefunc`, `HookScript`): the client's code is untouched,
-- and nothing runs per frame.
--
-- Nothing here is the client's until `install` is called, so the file loads under plain Lua too.
local R = LunaType
local Tips = {}
R.tips = Tips

local type, pcall, tostring = type, pcall, tostring

local function secret(value)
	local test = issecretvalue
	return test ~= nil and test(value)
end

local function text(value)
	if type(value) == "string" and not secret(value) and value ~= "" then
		return value
	end
	return nil
end

local function number(value)
	if type(value) == "number" and not secret(value) then
		return value
	end
	return nil
end

local function flag(value)
	if type(value) == "boolean" and not secret(value) then
		return value
	end
	return nil
end

local function color(value)
	if type(value) ~= "table" or secret(value) then
		return nil
	end
	local r, g, b = number(value.r), number(value.g), number(value.b)
	if not r or not g or not b then
		return nil
	end
	return { r = r, g = g, b = b, a = 1 }
end

-- The client's tooltip data as `"$game"` has it; nil for what isn't data or can't be read.
function Tips.data(raw)
	if type(raw) ~= "table" or secret(raw) or type(raw.lines) ~= "table" then
		return nil
	end
	local id = number(raw.id)
	local data = {
		kind = number(raw.type), id = id,
		about = text(raw.hyperlink) or text(raw.guid) or (id and tostring(id)) or nil,
		lines = {},
	}
	local qualities = ITEM_QUALITY_COLORS
	for i = 1, #raw.lines do
		local line = raw.lines[i]
		local quality = number(line.quality)
		data.lines[i] = {
			left = text(line.leftText), right = text(line.rightText),
			leftColor = color(line.leftColor), rightColor = color(line.rightColor),
			kind = number(line.type) or 0, usable = flag(line.usable), unit = text(line.unitToken),
			completed = flag(line.completed), quality = quality and qualities and color(qualities[quality]) or nil,
			validSlot = flag(line.isValidInvSlot), validType = flag(line.isValidItemType), price = number(line.price),
			spell = number(line.spellID), made = number(line.tooltipID),
		}
	end
	return data
end

-- A tooltip that is only text (a button's title and lines, set with SetText and AddLine): its lines read from its
-- font strings. Nil when anything in it isn't text or can't be read.
local function plain(native, name)
	if (native.shownMoneyFrames or 0) > 0 or (type(native.insertedFrames) == "table" and #native.insertedFrames > 0) then
		return nil
	end
	local count = native:NumLines()
	if secret(count) or type(count) ~= "number" then
		return nil
	end
	local function side(font)
		if not font or not font:IsShown() then
			return nil, nil, true
		end
		local value = font:GetText()
		if secret(value) then
			return nil, nil, false
		end
		if type(value) ~= "string" or value == "" then
			return nil, nil, true
		end
		local r, g, b = font:GetTextColor()
		if secret(r) or secret(g) or secret(b) or type(r) ~= "number" then
			return nil, nil, false
		end
		return value, { r = r, g = g, b = b, a = 1 }, true
	end
	local lines = {}
	for i = 1, count do
		local left, leftColor, readLeft = side(_G[name .. "TextLeft" .. i])
		local right, rightColor, readRight = side(_G[name .. "TextRight" .. i])
		if not readLeft or not readRight then
			return nil
		end
		lines[i] = { left = left, right = right, leftColor = leftColor, rightColor = rightColor, kind = 0 }
	end
	return { plain = true, lines = lines }
end

-- What a tooltip can stand beside: the frame it belongs to (a button, a slot), on the screen; not the screen or the
-- world, and not a unit's frame, which keeps the client's place.
local function placeable(owner)
	if not owner or owner == UIParent or owner == WorldFrame or not owner.IsVisible or not owner:IsVisible() then
		return false
	end
	local unit = rawget(owner, "unit")
	if unit == nil and owner.GetAttribute then
		unit = owner:GetAttribute("unit")
	end
	return unit == nil and owner:GetCenter() ~= nil
end

local NOTHING = { shown = false, data = { lines = {} }, placeable = false, ownerHigh = false, ownerRight = false,
	below = false, right = false }

function Tips.install()
	local client = R.client
	local main, compared = R.cell(NOTHING), R.cell({})
	local unseen = false -- the addon draws the show there is
	local native = client.GameTooltip
	local setting = false -- the alpha is being set from here
	local alpha -- what another addon wanted the tooltip's alpha to be, for this show

	local function conceal()
		setting = true
		native:SetAlpha(unseen and 0 or (alpha or 1))
		setting = false
	end

	local function readable(tip)
		return tip ~= nil and not (tip.IsForbidden and tip:IsForbidden())
	end

	-- What a tooltip of the client's shows now: its data, or its text.
	local function dataOf(tip, name)
		local ok, raw = pcall(tip.GetTooltipData, tip)
		local data = ok and Tips.data(raw) or nil
		if data and #data.lines > 0 then
			-- The client's own table too: what a part of the game reads from it besides.
			data.raw = raw
			return data
		end
		return plain(tip, name)
	end

	local function readCompared()
		local list = {}
		for i = 1, 2 do
			local name = "ShoppingTooltip" .. i
			local tip = client[name]
			if readable(tip) and tip:IsShown() then
				local data = dataOf(tip, name)
				if data then
					list[#list + 1] = data
				end
			end
		end
		if #list ~= #R.peek(compared) or #list > 0 then
			R.set(compared, list)
		end
	end

	local function shown()
		local data = readable(native) and dataOf(native, "GameTooltip") or nil
		if not data then
			unseen = false
			conceal()
			R.set(main, NOTHING)
			return
		end
		local owner = native:GetOwner()
		if owner == nil or secret(owner) or type(owner) ~= "table" then
			owner = nil
		end
		local point = native:GetPoint(1)
		if type(point) ~= "string" or secret(point) then
			point = "TOPLEFT"
		end
		-- What the tooltip belongs to goes with its data: an aura's button knows its unit, a talent's its node.
		data.owner = owner
		local beside = placeable(owner)
		local high, right = false, false
		if beside then
			local x, y = owner:GetCenter()
			local scale = owner:GetEffectiveScale() / UIParent:GetEffectiveScale()
			high, right = y * scale > UIParent:GetHeight() / 2, x * scale > UIParent:GetWidth() * 2 / 3
		end
		R.set(main, {
			shown = true, data = data, owner = owner, ownerName = owner and owner.GetName and text(owner:GetName()) or nil,
			placeable = beside, ownerHigh = high, ownerRight = right, corner = native,
			-- It hangs by the corner the client anchored it by: by its top it stands below what it explains.
			below = point:find("TOP") ~= nil, right = point:find("RIGHT") ~= nil,
		})
		readCompared()
		conceal()
	end

	local function hidden()
		alpha = nil -- another addon's fade lasts one show
		unseen = false
		conceal()
		if R.peek(main).shown then
			R.set(main, NOTHING)
		end
		if #R.peek(compared) > 0 then
			R.set(compared, {})
		end
	end

	if readable(native) then
		-- Addons add lines and show again in the same frame: every show is read, never per frame.
		hooksecurefunc(native, "Show", shown)
		hooksecurefunc(native, "SetShown", function(_, on)
			if not secret(on) and on then
				shown()
			end
		end)
		native:HookScript("OnHide", hidden)
		native:HookScript("OnTooltipCleared", hidden)
		-- Another addon's fade is remembered, and the client's stays unseen.
		hooksecurefunc(native, "SetAlpha", function(_, wanted)
			if setting or not unseen then
				return
			end
			if not secret(wanted) and type(wanted) == "number" and wanted > 0 then
				alpha = wanted
			end
			conceal()
		end)
		-- A unit's tooltip fades inside the client, where no hook sees it: while an addon draws it, the client's is
		-- hidden at once instead.
		if native.FadeOut then
			hooksecurefunc(native, "FadeOut", function()
				if unseen then
					native:Hide()
				end
			end)
		end
		for i = 1, 2 do
			local tip = client["ShoppingTooltip" .. i]
			if readable(tip) then
				hooksecurefunc(tip, "Show", readCompared)
				tip:HookScript("OnHide", readCompared)
			end
		end
	end

	R.game.Tooltip = {
		main = main, compared = compared,
		hide = function(on)
			unseen = on and R.peek(main).shown
			conceal()
			for i = 1, 2 do
				local tip = client["ShoppingTooltip" .. i]
				if readable(tip) then
					tip:SetAlpha(unseen and 0 or 1)
				end
			end
		end,
	}
end

-- What the tooltips read of the client besides: `"$game"`'s `Strings`, `Client`, `Spells`, `Items`, `Units`, `Auras`,
-- `Talents` and `Character`. Each reads the client when it is asked and keeps nothing.
local STRINGS = {
	itemMinSkill = "ITEM_MIN_SKILL", spellReagents = "SPELL_REAGENTS", castInstant = "SPELL_CAST_TIME_INSTANT",
	castInstantNoMana = "SPELL_CAST_TIME_INSTANT_NO_MANA", castChanneled = "SPELL_CAST_CHANNELED",
	castTimeSec = "SPELL_CAST_TIME_SEC", castTimeMin = "SPELL_CAST_TIME_MIN", onNextSwing = "SPELL_ON_NEXT_SWING",
	onNextRanged = "SPELL_ON_NEXT_RANGED", meleeRange = "MELEE_RANGE", soulbound = "ITEM_SOULBOUND",
	bindOnEquip = "ITEM_BIND_ON_EQUIP", bindOnPickup = "ITEM_BIND_ON_PICKUP",
	timeRemainingMin = "SPELL_TIME_REMAINING_MIN", timeRemainingSec = "SPELL_TIME_REMAINING_SEC", pvp = "PVP",
	sellPrice = "SELL_PRICE", itemMinLevel = "ITEM_MIN_LEVEL", itemSpellKnown = "ITEM_SPELL_KNOWN",
	itemUnique = "ITEM_UNIQUE", itemUniqueEquippable = "ITEM_UNIQUE_EQUIPPABLE",
	damageSchool = "DAMAGE_TEMPLATE_WITH_SCHOOL", damage = "DAMAGE_TEMPLATE",
	singleDamageSchool = "SINGLE_DAMAGE_TEMPLATE_WITH_SCHOOL", singleDamage = "SINGLE_DAMAGE_TEMPLATE",
	dps = "DPS_TEMPLATE", armor = "ARMOR_TEMPLATE", shieldBlock = "SHIELD_BLOCK_TEMPLATE",
	containerSlots = "CONTAINER_SLOTS", durability = "DURABILITY_TEMPLATE", classesAllowed = "ITEM_CLASSES_ALLOWED",
	hours = "HOUR_ONELETTER_ABBR", minutes = "MINUTE_ONELETTER_ABBR", seconds = "SECOND_ONELETTER_ABBR",
}

-- Seconds until something on a cooldown is ready; nil when it is, or for the short pause every spell shares.
local function remaining(start, duration)
	if type(start) ~= "number" or type(duration) ~= "number" or secret(start) or secret(duration) or duration <= 1.5 then
		return nil
	end
	local left = start + duration - GetTime()
	return left > 0 and left or nil
end

local function rgb(c)
	return c and type(c.r) == "number" and { r = c.r, g = c.g, b = c.b, a = 1 } or nil
end

local function classColor(unit)
	local _, tag = UnitClass(unit)
	return tag and RAID_CLASS_COLORS and rgb(RAID_CLASS_COLORS[tag]) or nil
end

function Tips.parts()
	local Game = R.game

	local strings = {}
	for key, name in pairs(STRINGS) do
		local value = _G[name]
		strings[key] = type(value) == "string" and value or ""
	end
	Game.Strings = strings
	Game.Client = { locale = GetLocale() }

	-- The spellbook's tab of each of the player's spells: read when the spells change.
	local tabs = {}
	local function readSpellbook()
		for id in pairs(tabs) do
			tabs[id] = nil
		end
		local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
		for line = 1, C_SpellBook.GetNumSpellBookSkillLines() or 0 do
			local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
			local first, count = info and info.itemIndexOffset or 0, info and info.numSpellBookItems or 0
			for slot = first + 1, first + count do
				local item = C_SpellBook.GetSpellBookItemInfo(slot, bank)
				if item and type(item.spellID) == "number" then
					tabs[item.spellID] = info.name
				end
			end
		end
	end
	local owner = setmetatable({}, R.class({}))
	R.listen(R.events.SPELLS_CHANGED, owner, readSpellbook)
	R.listen(R.events.PLAYER_ENTERING_WORLD, owner, readSpellbook)

	Game.Spells = {
		texture = function(id)
			return C_Spell.GetSpellTexture(id)
		end,
		cost = function(id)
			local list = C_Spell.GetSpellPowerCost(id)
			local cost = type(list) == "table" and list[1]
			if not cost or type(cost.cost) ~= "number" or cost.cost <= 0 then
				return nil
			end
			local bar = PowerBarColor and (PowerBarColor[cost.name] or PowerBarColor[cost.type])
			return { amount = cost.cost, color = rgb(bar) }
		end,
		tab = function(id)
			return tabs[id]
		end,
		cooldown = function(id)
			local cd = C_Spell.GetSpellCooldown(id)
			return cd and remaining(cd.startTime, cd.duration) or nil
		end,
		known = function(id)
			return IsPlayerSpell(id) == true
		end,
		name = function(id)
			return C_Spell.GetSpellName(id)
		end,
		tooltip = function(id)
			return Tips.data(C_TooltipInfo.GetSpellByID(id))
		end,
	}

	local function linkOf(data)
		local raw = data.raw
		local link = raw and (text(raw.hyperlink) or (text(raw.guid) and C_Item.GetItemLinkByGUID(raw.guid)))
		if not link and data.id then
			local _
			_, link = C_Item.GetItemInfo(data.id)
		end
		return link
	end

	Game.Items = {
		count = function(name)
			return C_Item.GetItemCount(name) or 0
		end,
		icon = function(id)
			return C_Item.GetItemIconByID(id)
		end,
		level = function(id)
			local _, _, _, level = C_Item.GetItemInfo(id)
			return type(level) == "number" and level or nil
		end,
		stats = function(data)
			local list = {}
			local link = linkOf(data)
			local stats = link and C_Item.GetItemStats(link)
			if type(stats) == "table" then
				for key, value in pairs(stats) do
					local name = _G[key]
					if type(name) == "string" and type(value) == "number" then
						list[#list + 1] = { key = key, name = name, value = value }
					end
				end
				table.sort(list, function(a, b)
					return a.key < b.key
				end)
			end
			return list
		end,
		statName = function(key)
			local name = _G[key]
			return type(name) == "string" and name or nil
		end,
		tooltip = function(id)
			return Tips.data(C_TooltipInfo.GetItemByID(id))
		end,
		cooldown = function(id)
			return remaining(C_Container.GetItemCooldown(id))
		end,
		maxStack = function(id)
			return C_Item.GetItemMaxStackSizeByID(id)
		end,
		inBags = function(id)
			return C_Item.GetItemCount(id) or 0
		end,
		owned = function(id)
			return C_Item.GetItemCount(id, true) or 0
		end,
	}

	Game.Units = {
		of = function(unit)
			if type(unit) ~= "string" or not UnitExists(unit) then
				return nil
			end
			local name = UnitName(unit)
			local player = UnitIsPlayer(unit) == true
			local className = UnitClass(unit)
			local guild, guildRank = GetGuildInfo(unit)
			local level = UnitLevel(unit) or 0
			local reaction = UnitReaction(unit, "player")
			local difficulty = (reaction or 0) < 5 and level > 0 and GetQuestDifficultyColor and GetQuestDifficultyColor(level)
			local faction, factionName = UnitFactionGroup(unit)
			local target = unit .. "target"
			local raidIndex = UnitInRaid(unit)
			local raidGroup
			if raidIndex then
				local _
				_, _, raidGroup = GetRaidRosterInfo(raidIndex)
			end
			local friend = name ~= nil and player and C_FriendList.IsFriend(UnitGUID(unit)) == true
			local note = friend and C_FriendList.GetFriendInfo(name)
			return {
				name = name, player = player, titled = player and UnitPVPName(unit) or nil,
				className = player and className or nil, classColor = player and classColor(unit) or nil,
				guild = guild, guildRank = guildRank,
				dead = UnitIsDead(unit) == true, ghost = UnitIsGhost(unit) == true, afk = UnitIsAFK(unit) == true,
				dnd = UnitIsDND(unit) == true, pvp = UnitIsPVP(unit) == true,
				level = level, levelColor = rgb(difficulty or nil),
				race = player and UnitRace(unit) or nil,
				faction = faction, factionName = factionName, sameFaction = faction ~= nil and faction == UnitFactionGroup("player"),
				target = UnitExists(target) and { name = UnitName(target) or "",
					color = UnitIsPlayer(target) and classColor(target) or nil } or nil,
				raidGroup = raidGroup,
				inParty = UnitInParty(unit) == true and not UnitIsUnit(unit, "player"),
				friend = friend, friendNote = note and note.notes or nil,
				ignored = name ~= nil and C_FriendList.IsIgnored(name) == true,
				reactionColor = not player and reaction and FACTION_BAR_COLORS and rgb(FACTION_BAR_COLORS[reaction]) or nil,
				tapped = UnitIsTapDenied(unit) == true,
				creatureType = UnitCreatureType(unit),
				classification = UnitClassification(unit) or "normal",
			}
		end,
	}

	Game.Auras = {
		-- The aura on its unit: the owner's (the client's aura buttons know their unit and instance), else the player's.
		shown = function(data)
			local frame = data.owner
			local unit = frame and rawget(frame, "unit")
			local instance = frame and (rawget(frame, "auraInstanceID")
				or (type(rawget(frame, "buttonInfo")) == "table" and frame.buttonInfo.auraInstanceID))
			local aura
			if type(unit) == "string" and instance then
				aura = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, instance)
			else
				unit = "player"
				aura = data.id and C_UnitAuras.GetPlayerAuraBySpellID(data.id)
			end
			if type(aura) ~= "table" or secret(aura) then
				return nil
			end
			local dispel = text(aura.dispelName)
			local source = text(aura.sourceUnit)
			local known = source and UnitExists(source)
			local expires = number(aura.expirationTime)
			return {
				harmful = aura.isHarmful == true, dispel = dispel,
				dispelName = dispel and (_G["STRING_SCHOOL_" .. dispel:upper()] or dispel) or nil,
				source = source, sourceName = known and UnitName(source) or nil,
				sourceColor = known and classColor(source) or nil,
				stacks = number(aura.applications) or 0,
				left = expires and expires > 0 and math.max(0, expires - GetTime()) or nil,
				own = unit == "player", hostile = UnitCanAttack("player", unit) == true,
			}
		end,
	}

	Game.Talents = {
		-- The talent window's button owns the tooltip: it knows its node.
		shown = function(data)
			local frame = data.owner
			if not frame or not frame.GetNodeID then
				return nil
			end
			local config = C_ClassTalents.GetActiveConfigID()
			local nodeID = frame:GetNodeID()
			local node = config and nodeID and C_Traits.GetNodeInfo(config, nodeID)
			local spell = frame.GetSpellID and frame:GetSpellID() or data.id
			if not node or not spell then
				return nil
			end
			local rank, ranks = node.currentRank or 0, node.maxRanks or 1
			local entry = frame.GetEntryID and frame:GetEntryID()
				or node.activeEntry and node.activeEntry.entryID or node.entryIDs and node.entryIDs[1]
			local current, following
			if entry and rank > 0 and rank < ranks then
				current, following = text(C_Traits.GetTraitDescription(entry, rank)), text(C_Traits.GetTraitDescription(entry, rank + 1))
			end
			local conditions = {}
			if rank == 0 then
				for i = 1, node.conditionIDs and #node.conditionIDs or 0 do
					local info = C_Traits.GetConditionInfo(config, node.conditionIDs[i])
					local points = info and info.spentAmountRequired
					if type(points) == "number" and points > 0 then
						conditions[#conditions + 1] = { points = points, met = info.isMet ~= false }
					end
				end
			end
			return {
				spell = spell, rank = rank, ranks = ranks, current = current, next = following, conditions = conditions,
				locked = rank == 0 and (node.isAvailable == false or node.meetsEdgeRequirements == false),
			}
		end,
	}

	Game.Character = {
		itemLevel = function()
			local _, equipped = GetAverageItemLevel()
			return type(equipped) == "number" and equipped or nil
		end,
		durability = function()
			local least
			for slot = 1, 18 do
				local now, most = GetInventoryItemDurability(slot)
				if now and most and most > 0 and (not least or now / most < least) then
					least = now / most
				end
			end
			return least
		end,
		unspentTalents = function()
			return GetNumUnspentTalents and GetNumUnspentTalents() or 0
		end,
		achievementPoints = function()
			return GetTotalAchievementPoints and GetTotalAchievementPoints() or 0
		end,
		quests = function()
			local _, have = C_QuestLog.GetNumQuestLogEntries()
			return { have = have or 0, most = C_QuestLog.GetMaxNumQuestsCanAccept() or 0 }
		end,
		guild = function()
			if not IsInGuild() then
				return nil
			end
			local members, online = GetNumGuildMembers()
			return { online = online or 0, members = members or 0 }
		end,
	}
end

return Tips
