-- Made by lunatype from OrdaenTooltips/unit.luna: change the source, not this file.
local R = LunaType
local __insert = table.insert
local __OrdaenTooltips_colors_RED = R.addon("OrdaenTooltips")["colors"].RED
local __OrdaenTooltips_colors_YELLOW = R.addon("OrdaenTooltips")["colors"].YELLOW
local __string_split = R.string.split
local __string_sub = R.string.sub
local __OrdaenTooltips_colors_hex = R.addon("OrdaenTooltips")["colors"].hex
local __OrdaenTooltips_colors_LABEL = R.addon("OrdaenTooltips")["colors"].LABEL
local __OrdaenTooltips_colors_WHITE = R.addon("OrdaenTooltips")["colors"].WHITE
local __OrdaenTooltips_model_named = R.addon("OrdaenTooltips")["model"].named
local __OrdaenTooltips_locales_GHOST = R.addon("OrdaenTooltips")["locales"].GHOST
local __OrdaenTooltips_locales_CORPSE = R.addon("OrdaenTooltips")["locales"].CORPSE
local __OrdaenTooltips_locales_AFK = R.addon("OrdaenTooltips")["locales"].AFK
local __OrdaenTooltips_locales_DND = R.addon("OrdaenTooltips")["locales"].DND
local __string_format = R.string.format
local __OrdaenTooltips_locales_LEVEL_CELL = R.addon("OrdaenTooltips")["locales"].LEVEL_CELL
local __OrdaenTooltips_colors_GREEN = R.addon("OrdaenTooltips")["colors"].GREEN
local __OrdaenTooltips_model_side = R.addon("OrdaenTooltips")["model"].side
local __OrdaenTooltips_locales_TARGET = R.addon("OrdaenTooltips")["locales"].TARGET
local __OrdaenTooltips_locales_RAID = R.addon("OrdaenTooltips")["locales"].RAID
local __OrdaenTooltips_locales_RAID_GROUP = R.addon("OrdaenTooltips")["locales"].RAID_GROUP
local __OrdaenTooltips_locales_PARTY = R.addon("OrdaenTooltips")["locales"].PARTY
local __OrdaenTooltips_locales_PARTY_YOURS = R.addon("OrdaenTooltips")["locales"].PARTY_YOURS
local __OrdaenTooltips_locales_FRIEND = R.addon("OrdaenTooltips")["locales"].FRIEND
local __OrdaenTooltips_locales_IGNORED = R.addon("OrdaenTooltips")["locales"].IGNORED
local __OrdaenTooltips_locales_IGNORED_YES = R.addon("OrdaenTooltips")["locales"].IGNORED_YES
local __OrdaenTooltips_colors_GREY = R.addon("OrdaenTooltips")["colors"].GREY
local __OrdaenTooltips_text_clean = R.addon("OrdaenTooltips")["text"].clean
local __game__Strings_pvp = R.game.Strings.pvp
local __string_contains = R.string.contains
local __string_of = R.string.of
local __OrdaenTooltips_colors_colorOf = R.addon("OrdaenTooltips")["colors"].colorOf
local __OrdaenTooltips_locales_ELITE = R.addon("OrdaenTooltips")["locales"].ELITE
local __OrdaenTooltips_colors_GOLD = R.addon("OrdaenTooltips")["colors"].GOLD
local __OrdaenTooltips_locales_RARE = R.addon("OrdaenTooltips")["locales"].RARE
local __OrdaenTooltips_locales_TAPPED = R.addon("OrdaenTooltips")["locales"].TAPPED
local __game__Reputation_with = R.game.Reputation.with
local __OrdaenTooltips_quests_quests = R.addon("OrdaenTooltips")["quests"].quests
local __game__Units_of = R.game.Units.of
local M = {}
R.addon("OrdaenTooltips")["unit"] = M
local BLANK, UNIT_NAME, UNIT_OWNER, ORANGE, FRIENDLY, standingColor, titledName, player, npc, unit
BLANK = 1
UNIT_NAME = 2
UNIT_OWNER = 16
ORANGE = { r = 1, g = 0.502, b = 0.251, a = 1 }
FRIENDLY = { r = 0.251, g = 0.749, b = 0.251, a = 1 }

function standingColor(rank)
	if rank <= 2 then
		return __OrdaenTooltips_colors_RED
	end
	if rank == 3 then
		return ORANGE
	end
	if rank == 4 then
		return __OrdaenTooltips_colors_YELLOW
	end
	return FRIENDLY
end

function titledName(name, titled, color)
	if titled == nil or titled == name then
		return name
	end
	local around = __string_split(titled, name)
	local before = around[1]
	if #around < 2 or before == nil then
		return titled
	end
	local after = __string_sub(titled, #before + #name + 1)
	return "|c" .. __OrdaenTooltips_colors_hex(__OrdaenTooltips_colors_LABEL) .. before .. "|r|c" .. __OrdaenTooltips_colors_hex(color) .. name .. "|r|c" .. __OrdaenTooltips_colors_hex(__OrdaenTooltips_colors_LABEL) .. after .. "|r"
end

function player(who, options)
	local name = who.name
	if name == nil then
		return nil
	end
	local __t1
	if options.classNames then
		__t1 = who.classColor
	else
		__t1 = nil
	end
	local color = __t1 or __OrdaenTooltips_colors_WHITE
	local desc = {}
	local info = {}
	local facts = {}
	local foot = {}
	local guild = who.guild
	if guild ~= nil then
		__insert(desc, { text = guild, opens = __OrdaenTooltips_model_named("guild") })
		local rank = who.guildRank
		if rank ~= nil then
			__insert(desc, { text = rank, opens = __OrdaenTooltips_model_named("rank") })
		end
	end
	local className = who.className
	if className ~= nil then
		__insert(info, { text = className, opens = __OrdaenTooltips_model_named("pclass") })
	end
	if who.dead or who.ghost then
		local __t2
		if who.ghost then
			__t2 = __OrdaenTooltips_locales_GHOST
		else
			__t2 = __OrdaenTooltips_locales_CORPSE
		end
		__insert(info, { text = __t2, opens = __OrdaenTooltips_model_named("status") })
	elseif who.afk then
		__insert(info, { text = __OrdaenTooltips_locales_AFK, opens = __OrdaenTooltips_model_named("status") })
	elseif who.dnd then
		__insert(info, { text = __OrdaenTooltips_locales_DND, opens = __OrdaenTooltips_model_named("status") })
	end
	if who.pvp then
		__insert(info, { text = "PvP", opens = __OrdaenTooltips_model_named("pvp") })
	end
	local __t3
	if who.level > 0 then
		__t3 = __string_format(__OrdaenTooltips_locales_LEVEL_CELL, who.level)
	else
		__t3 = "??"
	end
	__insert(facts, { text = __t3, opens = __OrdaenTooltips_model_named("plvl") })
	local race = who.race
	if race ~= nil then
		__insert(facts, { text = race, opens = "None" })
	end
	local faction = who.faction
	if faction ~= nil then
		local __t4
		if who.sameFaction then
			__t4 = __OrdaenTooltips_colors_GREEN
		else
			__t4 = __OrdaenTooltips_colors_RED
		end
		local __t5
		if faction == "Alliance" then
			__t5 = "glyphs/alliance"
		else
			local __t6
			if faction == "Horde" then
				__t6 = "glyphs/horde"
			else
				__t6 = nil
			end
			__t5 = __t6
		end
		__insert(facts, { text = who.factionName or faction, color = __t4, glyph = __t5, opens = __OrdaenTooltips_model_side(faction) })
	end
	local target = who.target
	if options.playersTarget and target ~= nil then
		__insert(foot, { left = __OrdaenTooltips_locales_TARGET, right = target.name, valueColor = target.color, opens = __OrdaenTooltips_model_named("ptarget") })
	end
	if options.playersRelation then
		local group = who.raidGroup
		if group ~= nil then
			__insert(foot, { left = __OrdaenTooltips_locales_RAID, right = __string_format(__OrdaenTooltips_locales_RAID_GROUP, group), opens = __OrdaenTooltips_model_named("relation") })
		elseif who.inParty then
			__insert(foot, { left = __OrdaenTooltips_locales_PARTY, right = __OrdaenTooltips_locales_PARTY_YOURS, opens = __OrdaenTooltips_model_named("relation") })
		end
		if who.friend then
			__insert(foot, { left = __OrdaenTooltips_locales_FRIEND, right = who.friendNote or "", opens = __OrdaenTooltips_model_named("relation") })
		end
		if who.ignored then
			__insert(foot, { left = __OrdaenTooltips_locales_IGNORED, right = __OrdaenTooltips_locales_IGNORED_YES, valueColor = __OrdaenTooltips_colors_RED, opens = __OrdaenTooltips_model_named("relation") })
		end
	end
	return { kind = "unit", name = titledName(name, who.titled, color), nameColor = color, desc = desc, info = info, facts = facts, body = {}, more = {}, foot = foot, keys = {}, picture = "None" }
end

function npc(who, name, data, options)
	local nameColor = __OrdaenTooltips_colors_WHITE
	local reaction = who.reactionColor
	if options.npcsLoot and who.tapped then
		nameColor = __OrdaenTooltips_colors_GREY
	elseif reaction ~= nil then
		nameColor = reaction
	end
	local level = who.level
	local creature = who.creatureType
	local factionName = nil
	local desc = {}
	local info = {}
	local facts = {}
	local body = {}
	local foot = {}
	local __l7 = data.lines
	for i = 1, #__l7 do
		local line = __l7[i]
		repeat
			if i == 1 then
				break
			end
			local text = __OrdaenTooltips_text_clean(line.left)
			if text == nil or line.kind == 1 then
				break
			end
			if line.kind == 17 or line.kind == 8 or line.kind == 18 then
				break
			end
			if text == __game__Strings_pvp then
				break
			end
			local numbered = (text):match("%d") ~= nil
			if i <= 3 and level > 0 and numbered and __string_contains(text, __string_of(level)) then
				break
			end
			local role = (text):match("^<(.+)>$")
			if role ~= nil then
				__insert(desc, { text = role, opens = "None" })
			elseif line.kind == 16 then
				__insert(desc, { text = text, opens = "None" })
			elseif i <= 4 and factionName == nil and who.faction ~= nil then
				factionName = text
			elseif i <= 4 and #desc == 0 and not numbered and text ~= creature then
				__insert(desc, { text = text, opens = "None" })
			elseif text ~= creature then
				__insert(body, { left = text, color = __OrdaenTooltips_colors_colorOf(line.leftColor), opens = "None" })
			end
		until true
	end
	if creature ~= nil then
		__insert(info, { text = creature, opens = __OrdaenTooltips_model_named("beast") })
	end
	if who.dead then
		__insert(info, { text = __OrdaenTooltips_locales_CORPSE, opens = __OrdaenTooltips_model_named("npcdead") })
	end
	if level > 0 then
		__insert(facts, { text = __string_format(__OrdaenTooltips_locales_LEVEL_CELL, level), color = who.levelColor, opens = __OrdaenTooltips_model_named("lvlcolor") })
	else
		__insert(facts, { text = "??", color = __OrdaenTooltips_colors_RED, opens = __OrdaenTooltips_model_named("lvlcolor") })
	end
	local rank = who.classification
	if rank == "elite" or rank == "worldboss" or rank == "rareelite" then
		__insert(facts, { text = __OrdaenTooltips_locales_ELITE, color = __OrdaenTooltips_colors_GOLD, glyph = "glyphs/elite", opens = __OrdaenTooltips_model_named("elite") })
	end
	if rank == "rare" or rank == "rareelite" then
		__insert(facts, { text = __OrdaenTooltips_locales_RARE, opens = __OrdaenTooltips_model_named("rare") })
	end
	local faction = who.faction
	if faction ~= nil then
		local __t8
		if who.sameFaction then
			__t8 = __OrdaenTooltips_colors_GREEN
		else
			__t8 = __OrdaenTooltips_colors_RED
		end
		__insert(facts, { text = factionName or faction, color = __t8, opens = __OrdaenTooltips_model_side(faction) })
	end
	if options.npcsLoot and who.tapped then
		__insert(foot, { left = __OrdaenTooltips_locales_TAPPED, right = "", opens = __OrdaenTooltips_model_named("tapped") })
	end
	if options.npcsRep and factionName ~= nil then
		local standing = __game__Reputation_with(factionName)
		if standing ~= nil then
			__insert(foot, { left = factionName, right = standing.label, valueColor = standingColor(standing.rank), opens = "None" })
		end
	end
	return { kind = "unit", name = name, nameColor = nameColor, desc = desc, info = info, facts = facts, body = body, more = __OrdaenTooltips_quests_quests(data.lines, options.npcsParty), foot = foot, keys = {}, picture = "None" }
end

function unit(data, options)
	local first = data.lines[1]
	if first == nil then
		return nil
	end
	local name = __OrdaenTooltips_text_clean(first.left)
	local __t9
	if first.kind == 2 then
		__t9 = first.unit
	else
		__t9 = nil
	end
	local token = __t9
	local __t10
	if token ~= nil then
		__t10 = __game__Units_of(token)
	else
		__t10 = nil
	end
	local who = __t10
	if token == nil or who == nil then
		if name == nil then
			return nil
		end
		local body = {}
		local __l11 = data.lines
		for i = 1, #__l11 do
			local line = __l11[i]
			repeat
				if i == 1 then
					break
				end
				local text = __OrdaenTooltips_text_clean(line.left)
				if text ~= nil then
					__insert(body, { left = text, color = __OrdaenTooltips_colors_colorOf(line.leftColor), opens = "None" })
				end
			until true
		end
		return { kind = "unit", name = name, nameColor = __OrdaenTooltips_colors_WHITE, desc = {}, info = {}, facts = {}, body = body, more = {}, foot = {}, keys = {}, picture = "None" }
	end
	if who.player then
		local read = player(who, options)
		local __t12
		if read ~= nil then
			__t12 = { picture = { "Face", unit = token }, kind = read.kind, header = read.header, name = read.name, nameColor = read.nameColor, desc = read.desc, info = read.info, facts = read.facts, body = read.body, more = read.more, foot = read.foot, keys = read.keys, timer = read.timer }
		else
			__t12 = nil
		end
		return __t12
	end
	if name == nil then
		return nil
	end
	local __t13 = npc(who, name, data, options)
	return { picture = { "Face", unit = token }, kind = __t13.kind, header = __t13.header, name = __t13.name, nameColor = __t13.nameColor, desc = __t13.desc, info = __t13.info, facts = __t13.facts, body = __t13.body, more = __t13.more, foot = __t13.foot, keys = __t13.keys, timer = __t13.timer }
end

M.BLANK = BLANK
M.UNIT_NAME = UNIT_NAME
M.UNIT_OWNER = UNIT_OWNER
M.ORANGE = ORANGE
M.FRIENDLY = FRIENDLY
M.standingColor = standingColor
M.titledName = titledName
M.player = player
M.npc = npc
M.unit = unit
