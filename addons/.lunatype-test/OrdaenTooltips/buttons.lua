-- Made by lunatype from OrdaenTooltips/buttons.luna: change the source, not this file.
local R = LunaType
local __get = R.get
local __insert = table.insert
local __string_format = R.string.format
local __game__Bags_roomOfAll = R.game.Bags.roomOfAll
local __game__Bags_roomOf = R.game.Bags.roomOf
local __OrdaenTooltips_locales_EXTRA_FREE = R.addon("OrdaenTooltips")["locales"].EXTRA_FREE
local __game__Character_itemLevel = R.game.Character.itemLevel
local __OrdaenTooltips_locales_EXTRA_ILVL = R.addon("OrdaenTooltips")["locales"].EXTRA_ILVL
local __string_of = R.string.of
local __math_floor = R.math.floor
local __game__Character_durability = R.game.Character.durability
local __math_round = R.math.round
local __OrdaenTooltips_locales_EXTRA_DURABILITY = R.addon("OrdaenTooltips")["locales"].EXTRA_DURABILITY
local __OrdaenTooltips_colors_RED = R.addon("OrdaenTooltips")["colors"].RED
local __game__Character_unspentTalents = R.game.Character.unspentTalents
local __OrdaenTooltips_locales_EXTRA_TALENTS = R.addon("OrdaenTooltips")["locales"].EXTRA_TALENTS
local __game__Professions_list = R.game.Professions.list
local __game__Character_achievementPoints = R.game.Character.achievementPoints
local __OrdaenTooltips_locales_EXTRA_ACHIEVEMENTS = R.addon("OrdaenTooltips")["locales"].EXTRA_ACHIEVEMENTS
local __game__Character_quests = R.game.Character.quests
local __OrdaenTooltips_locales_EXTRA_QUESTS = R.addon("OrdaenTooltips")["locales"].EXTRA_QUESTS
local __game__Character_guild = R.game.Character.guild
local __OrdaenTooltips_locales_EXTRA_ONLINE = R.addon("OrdaenTooltips")["locales"].EXTRA_ONLINE
local M = {}
R.addon("OrdaenTooltips")["buttons"] = M
local BAGS, count, rowsOf, extras
BAGS = { ["MainMenuBarBackpackButton"] = 0, ["CharacterBag0Slot"] = 1, ["CharacterBag1Slot"] = 2, ["CharacterBag2Slot"] = 3, ["CharacterBag3Slot"] = 4 }

function count(have, most)
	return __string_format("%d / %d", have, most)
end

function rowsOf(owner)
	local rows = {}
	local bag = BAGS[owner]
	if bag ~= nil then
		local __t1
		if bag == 0 then
			__t1 = __game__Bags_roomOfAll()
		else
			__t1 = __game__Bags_roomOf(bag)
		end
		local room = __t1
		if room.slots > 0 then
			__insert(rows, { left = __OrdaenTooltips_locales_EXTRA_FREE, right = count(room.free, room.slots), opens = "None" })
		end
	elseif owner == "CharacterMicroButton" then
		local level = __game__Character_itemLevel()
		if level ~= nil and level > 0 then
			__insert(rows, { left = __OrdaenTooltips_locales_EXTRA_ILVL, right = __string_of(__math_floor(level)), opens = "None" })
		end
		local worn = __game__Character_durability()
		if worn ~= nil then
			local percent = __math_round(worn * 100)
			local __t2
			if percent < 25 then
				__t2 = __OrdaenTooltips_colors_RED
			else
				__t2 = nil
			end
			__insert(rows, { left = __OrdaenTooltips_locales_EXTRA_DURABILITY, right = percent .. "%", rightColor = __t2, opens = "None" })
		end
	elseif owner == "TalentMicroButton" then
		local points = __game__Character_unspentTalents()
		if points > 0 then
			__insert(rows, { left = __OrdaenTooltips_locales_EXTRA_TALENTS, right = __string_of(points), opens = "None" })
		end
	elseif owner == "ProfessionMicroButton" then
		local __l4 = __get(__game__Professions_list)
		for __i3 = 1, #__l4 do
			local profession = __l4[__i3]
			__insert(rows, { left = profession.name, right = count(profession.rank, profession.max), opens = "None" })
		end
	elseif owner == "AchievementMicroButton" then
		local points = __game__Character_achievementPoints()
		if points > 0 then
			__insert(rows, { left = __OrdaenTooltips_locales_EXTRA_ACHIEVEMENTS, right = __string_of(points), opens = "None" })
		end
	elseif owner == "QuestLogMicroButton" then
		local quests = __game__Character_quests()
		__insert(rows, { left = __OrdaenTooltips_locales_EXTRA_QUESTS, right = count(quests.have, quests.most), opens = "None" })
	elseif owner == "GuildMicroButton" then
		local guild = __game__Character_guild()
		if guild ~= nil then
			__insert(rows, { left = __OrdaenTooltips_locales_EXTRA_ONLINE, right = count(guild.online, guild.members), opens = "None" })
		end
	end
	return rows
end

function extras(owner, model)
	if owner == nil then
		return model
	end
	local added = rowsOf(owner)
	if #added == 0 then
		return model
	end
	local body = {}
	local __l6 = model.body
	for __i5 = 1, #__l6 do
		local line = __l6[__i5]
		__insert(body, line)
	end
	for __i7 = 1, #added do
		local row = added[__i7]
		__insert(body, row)
	end
	return { body = body, kind = model.kind, header = model.header, picture = model.picture, name = model.name, nameColor = model.nameColor, desc = model.desc, info = model.info, facts = model.facts, more = model.more, foot = model.foot, keys = model.keys, timer = model.timer }
end

M.BAGS = BAGS
M.count = count
M.rowsOf = rowsOf
M.extras = extras
