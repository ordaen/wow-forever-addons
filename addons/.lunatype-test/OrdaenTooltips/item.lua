-- Made by lunatype from OrdaenTooltips/item.luna: change the source, not this file.
local R = LunaType
local __insert = table.insert
local __x = {
	game__Strings_soulbound = R.game.Strings.soulbound,
	OrdaenTooltips_model_named = R.addon("OrdaenTooltips")["model"].named,
	game__Strings_bindOnEquip = R.game.Strings.bindOnEquip,
	game__Strings_bindOnPickup = R.game.Strings.bindOnPickup,
	math_floor = R.math.floor,
	string_format = R.string.format,
	string_unformat = R.string.unformat,
	OrdaenTooltips_colors_RED = R.addon("OrdaenTooltips")["colors"].RED,
	OrdaenTooltips_colors_YELLOW = R.addon("OrdaenTooltips")["colors"].YELLOW,
	game__Client_locale = R.game.Client.locale,
	OrdaenTooltips_text_form = R.addon("OrdaenTooltips")["text"].form,
	OrdaenTooltips_locales_COL_SLOTS_ONE = R.addon("OrdaenTooltips")["locales"].COL_SLOTS_ONE,
	OrdaenTooltips_locales_COL_SLOTS_FEW = R.addon("OrdaenTooltips")["locales"].COL_SLOTS_FEW,
	OrdaenTooltips_locales_COL_SLOTS_MANY = R.addon("OrdaenTooltips")["locales"].COL_SLOTS_MANY,
	string_split = R.string.split,
	OrdaenTooltips_locales_COUNT = R.addon("OrdaenTooltips")["locales"].COUNT,
	string_toNumber = R.string.toNumber,
	OrdaenTooltips_colors_WHITE = R.addon("OrdaenTooltips")["colors"].WHITE,
	game__Items_level = R.game.Items.level,
	OrdaenTooltips_locales_ITEM_LEVEL_ROW = R.addon("OrdaenTooltips")["locales"].ITEM_LEVEL_ROW,
	game__Items_stats = R.game.Items.stats,
	OrdaenTooltips_text_clean = R.addon("OrdaenTooltips")["text"].clean,
	game__Items_tooltip = R.game.Items.tooltip,
	game__Strings_sellPrice = R.game.Strings.sellPrice,
	game__Money_format = R.game.Money.format,
	game__Strings_itemMinSkill = R.game.Strings.itemMinSkill,
	game__Strings_itemMinLevel = R.game.Strings.itemMinLevel,
	OrdaenTooltips_locales_REQ_LEVEL = R.addon("OrdaenTooltips")["locales"].REQ_LEVEL,
	game__Spells_tooltip = R.game.Spells.tooltip,
	OrdaenTooltips_spell_spell = R.addon("OrdaenTooltips")["spell"].spell,
	game__Items_cooldown = R.game.Items.cooldown,
	OrdaenTooltips_text_duration = R.addon("OrdaenTooltips")["text"].duration,
	game__Strings_hours = R.game.Strings.hours,
	game__Strings_minutes = R.game.Strings.minutes,
	game__Strings_seconds = R.game.Strings.seconds,
	OrdaenTooltips_locales_READY_IN = R.addon("OrdaenTooltips")["locales"].READY_IN,
	OrdaenTooltips_colors_GREEN = R.addon("OrdaenTooltips")["colors"].GREEN,
	OrdaenTooltips_colors_colorOf = R.addon("OrdaenTooltips")["colors"].colorOf,
	game__Strings_itemSpellKnown = R.game.Strings.itemSpellKnown,
	OrdaenTooltips_colors_GREY = R.addon("OrdaenTooltips")["colors"].GREY,
	game__Strings_itemUnique = R.game.Strings.itemUnique,
	game__Strings_itemUniqueEquippable = R.game.Strings.itemUniqueEquippable,
	game__Strings_damageSchool = R.game.Strings.damageSchool,
	game__Strings_damage = R.game.Strings.damage,
	game__Strings_singleDamage = R.game.Strings.singleDamage,
	game__Strings_singleDamageSchool = R.game.Strings.singleDamageSchool,
	game__Strings_dps = R.game.Strings.dps,
	game__Strings_armor = R.game.Strings.armor,
	game__Strings_shieldBlock = R.game.Strings.shieldBlock,
	game__Strings_containerSlots = R.game.Strings.containerSlots,
	OrdaenTooltips_text_number = R.addon("OrdaenTooltips")["text"].number,
	game__Strings_durability = R.game.Strings.durability,
	game__Strings_classesAllowed = R.game.Strings.classesAllowed,
	game__Strings_spellReagents = R.game.Strings.spellReagents,
	OrdaenTooltips_locales_COL_DAMAGE = R.addon("OrdaenTooltips")["locales"].COL_DAMAGE,
	OrdaenTooltips_text_last = R.addon("OrdaenTooltips")["text"].last,
	OrdaenTooltips_locales_COL_SPEED = R.addon("OrdaenTooltips")["locales"].COL_SPEED,
	OrdaenTooltips_locales_COL_DPS = R.addon("OrdaenTooltips")["locales"].COL_DPS,
	OrdaenTooltips_model_namedWith = R.addon("OrdaenTooltips")["model"].namedWith,
	OrdaenTooltips_locales_DURABILITY = R.addon("OrdaenTooltips")["locales"].DURABILITY,
	OrdaenTooltips_locales_CLASSES = R.addon("OrdaenTooltips")["locales"].CLASSES,
	OrdaenTooltips_locales_KNOWN = R.addon("OrdaenTooltips")["locales"].KNOWN,
	OrdaenTooltips_locales_NOT_KNOWN = R.addon("OrdaenTooltips")["locales"].NOT_KNOWN,
	game__Items_maxStack = R.game.Items.maxStack,
	game__Items_inBags = R.game.Items.inBags,
	math_max = R.math.max,
	game__Items_owned = R.game.Items.owned,
	OrdaenTooltips_locales_IN_BAGS = R.addon("OrdaenTooltips")["locales"].IN_BAGS,
	OrdaenTooltips_locales_IN_BANK = R.addon("OrdaenTooltips")["locales"].IN_BANK,
	OrdaenTooltips_locales_STACK = R.addon("OrdaenTooltips")["locales"].STACK,
	OrdaenTooltips_colors_GOLD = R.addon("OrdaenTooltips")["colors"].GOLD,
	OrdaenTooltips_model_iconOf = R.addon("OrdaenTooltips")["model"].iconOf,
	game__Items_icon = R.game.Items.icon,
	OrdaenTooltips_colors_hex = R.addon("OrdaenTooltips")["colors"].hex,
	game__Items_statName = R.game.Items.statName,
}
local M = {}
R.addon("OrdaenTooltips")["item"] = M
local BLANK, SELL_PRICE, NESTED, BINDING, ITEM_SLOT, ITEM_NAME, TEACHES, SET_LINE, REQUIREMENT, USE, EQUIP, CHANCE, binding, shown, one, two, durabilityColor, slots, reagents, withNote, item, compare
BLANK = 1
SELL_PRICE = 11
NESTED = 19
BINDING = 20
ITEM_SLOT = 21
ITEM_NAME = 22
TEACHES = 38
SET_LINE = 42
REQUIREMENT = 43
USE = 44
EQUIP = 45
CHANCE = 46

function binding(text)
	if text == __x.game__Strings_soulbound then
		return __x.OrdaenTooltips_model_named("bound")
	end
	if text == __x.game__Strings_bindOnEquip then
		return __x.OrdaenTooltips_model_named("boe")
	end
	if text == __x.game__Strings_bindOnPickup then
		return __x.OrdaenTooltips_model_named("bop")
	end
	return "None"
end

function shown(n)
	if n == __x.math_floor(n) then
		return __x.string_format("%d", n)
	end
	return __x.string_format("%.1f", n)
end

function one(text, format)
	local parts = __x.string_unformat(text, format)
	if parts == nil then
		return nil
	end
	return parts[1]
end

function two(text, format)
	local parts = __x.string_unformat(text, format)
	if parts == nil then
		return nil, nil
	end
	return parts[1], parts[2]
end

function durabilityColor(current, most)
	if current <= 0 then
		return __x.OrdaenTooltips_colors_RED
	end
	if current <= most / 4 then
		return __x.OrdaenTooltips_colors_YELLOW
	end
	return nil
end

function slots(count)
	local __t1
	if __x.game__Client_locale == "ruRU" then
		__t1 = __x.OrdaenTooltips_text_form(count)
	else
		local __t2
		if count == 1 then
			__t2 = 1
		else
			__t2 = 3
		end
		__t1 = __t2
	end
	local which = __t1
	if which == 1 then
		return __x.string_format(__x.OrdaenTooltips_locales_COL_SLOTS_ONE, count)
	elseif which == 2 then
		return __x.string_format(__x.OrdaenTooltips_locales_COL_SLOTS_FEW, count)
	else
		return __x.string_format(__x.OrdaenTooltips_locales_COL_SLOTS_MANY, count)
	end
end

function reagents(text, body)
	local any = false
	local __l4 = __x.string_split(text, ",")
	for __i3 = 1, #__l4 do
		local part = __l4[__i3]
		local name, count = (part):match("^%s*(.-)%s*%((%d+)%)%s*$")
		if name ~= nil and count ~= nil and name ~= "" then
			__insert(body, { left = name, right = __x.string_format(__x.OrdaenTooltips_locales_COUNT, __x.math_floor(__x.string_toNumber(count) or 1)), opens = "None" })
			any = true
		end
	end
	return any
end

function withNote(model, note)
	local foot = {}
	local __l6 = model.foot
	for __i5 = 1, #__l6 do
		local kept = __l6[__i5]
		__insert(foot, kept)
	end
	__insert(foot, note)
	return { foot = foot, timer = true, kind = model.kind, header = model.header, picture = model.picture, name = model.name, nameColor = model.nameColor, desc = model.desc, info = model.info, facts = model.facts, body = model.body, more = model.more, keys = model.keys }
end

function item(data, options)
	local id = data.id
	local name = nil
	local nameColor = __x.OrdaenTooltips_colors_WHITE
	local desc = {}
	local info = {}
	local facts = {}
	local body = {}
	local foot = {}
	local sides = {}
	local makes = {}
	local stats = {}
	local timer = false
	local __t7
	if id ~= nil then
		__t7 = __x.game__Items_level(id)
	else
		__t7 = nil
	end
	local level = __t7
	if options.itemsIlvl and level ~= nil and level > 1 then
		__insert(body, { left = __x.OrdaenTooltips_locales_ITEM_LEVEL_ROW, right = shown(level), stat = "ilvl", opens = "None" })
		stats["ilvl"] = level
	end
	local hasStats = false
	local __l9 = __x.game__Items_stats(data)
	for __i8 = 1, #__l9 do
		local stat = __l9[__i8]
		stats[stat.key] = stat.value
		__insert(body, { left = stat.name, right = __x.string_format("%+d", stat.value), stat = stat.key, opens = "None" })
		hasStats = true
	end
	local nested = false
	local recipe = false
	local learned = false
	local setName = nil
	local setBody = {}
	local __l11 = data.lines
	for __i10 = 1, #__l11 do
		local line = __l11[__i10]
		repeat
			local kind = line.kind
			local left = __x.OrdaenTooltips_text_clean(line.left)
			if nested and kind == 38 then
				nested = false
			end
			if nested then
				break
			end
			local __t12
			if line.usable == false then
				__t12 = __x.OrdaenTooltips_colors_RED
			else
				__t12 = nil
			end
			local unmet = __t12
			if kind == 19 then
				recipe = true
				local makes_id = line.made
				local __t13
				if makes_id ~= nil then
					__t13 = __x.game__Items_tooltip(makes_id)
				else
					__t13 = nil
				end
				local made = __t13
				if made ~= nil then
					__insert(makes, made)
				end
				nested = true
			elseif kind == 22 then
				name = left
				nameColor = line.quality or __x.OrdaenTooltips_colors_WHITE
			elseif kind == 21 then
				local right = __x.OrdaenTooltips_text_clean(line.right)
				if left ~= nil then
					local __t14
					if line.validSlot == false then
						__t14 = __x.OrdaenTooltips_colors_RED
					else
						__t14 = nil
					end
					__insert(desc, { text = left, color = __t14, opens = "None" })
				end
				if right ~= nil then
					local __t15
					if line.validType == false then
						__t15 = __x.OrdaenTooltips_colors_RED
					else
						__t15 = nil
					end
					__insert(desc, { text = right, color = __t15, opens = "None" })
				end
			elseif kind == 20 then
				if left ~= nil then
					__insert(info, { text = left, opens = binding(left) })
				end
			elseif kind == 11 then
				local price = line.price
				if price ~= nil and price > 0 then
					__insert(foot, { left = __x.game__Strings_sellPrice, right = __x.game__Money_format(price), opens = "None" })
				end
			elseif kind == 43 then
				if left ~= nil then
					local skill, rank = two(left, __x.game__Strings_itemMinSkill)
					local needed = one(left, __x.game__Strings_itemMinLevel)
					if skill ~= nil and rank ~= nil then
						__insert(foot, { left = skill, right = rank, valueColor = unmet, opens = __x.OrdaenTooltips_model_named("prof") })
					elseif needed ~= nil then
						__insert(foot, { left = __x.OrdaenTooltips_locales_REQ_LEVEL, right = needed, valueColor = unmet, opens = __x.OrdaenTooltips_model_named("req") })
					else
						__insert(foot, { left = left, valueColor = unmet, opens = __x.OrdaenTooltips_model_named("req") })
					end
				end
			elseif kind == 44 then
				local cast = line.spell
				local __t16
				if cast ~= nil then
					__t16 = __x.game__Spells_tooltip(cast)
				else
					__t16 = nil
				end
				local used = __t16
				local __t17
				if used ~= nil then
					__t17 = __x.OrdaenTooltips_spell_spell(used, options)
				else
					__t17 = nil
				end
				local side = __t17
				if side ~= nil then
					local __t18
					if options.itemsCooldown and id ~= nil then
						__t18 = __x.game__Items_cooldown(id)
					else
						__t18 = nil
					end
					local wait = __t18
					if wait ~= nil then
						local ready = __x.OrdaenTooltips_text_duration(wait, __x.game__Strings_hours, __x.game__Strings_minutes, __x.game__Strings_seconds)
						__insert(sides, withNote(side, { left = __x.OrdaenTooltips_locales_READY_IN, right = ready, valueColor = __x.OrdaenTooltips_colors_YELLOW, opens = "None" }))
						timer = true
					else
						__insert(sides, side)
					end
				elseif left ~= nil then
					__insert(body, { left = left, color = __x.OrdaenTooltips_colors_GREEN, opens = "None" })
				end
			elseif kind == 38 then
				if left ~= nil and not recipe then
					__insert(body, { left = left, color = __x.OrdaenTooltips_colors_colorOf(line.leftColor), opens = "None" })
				end
			elseif kind == 45 or kind == 46 then
				if left ~= nil then
					__insert(body, { left = left, color = __x.OrdaenTooltips_colors_GREEN, opens = "None" })
				end
			elseif left ~= nil and left == __x.game__Strings_itemSpellKnown then
				learned = true
			elseif kind == 42 then
				if left ~= nil then
					if setName == nil then
						setName = left
					else
						__insert(setBody, { left = left, color = __x.OrdaenTooltips_colors_colorOf(line.leftColor) or __x.OrdaenTooltips_colors_GREY, opens = "None" })
					end
				end
			elseif kind == 1 or left == nil then
			elseif left == __x.game__Strings_itemUnique or left == __x.game__Strings_itemUniqueEquippable then
				__insert(desc, { text = left, opens = __x.OrdaenTooltips_model_named("uni") })
			else
				local lowSchool, highSchool = two(left, __x.game__Strings_damageSchool)
				local lowPlain, highPlain = two(left, __x.game__Strings_damage)
				local low = lowSchool or lowPlain
				local high = highSchool or highPlain
				local single = one(left, __x.game__Strings_singleDamageSchool) or one(left, __x.game__Strings_singleDamage)
				local dps = one(left, __x.game__Strings_dps)
				local armor = one(left, __x.game__Strings_armor)
				local block = one(left, __x.game__Strings_shieldBlock)
				local slotsA, slotsB = two(line.left or "", __x.game__Strings_containerSlots)
				local room = __x.OrdaenTooltips_text_number(slotsA or "") or __x.OrdaenTooltips_text_number(slotsB or "")
				local current, most = two(left, __x.game__Strings_durability)
				local classes = one(left, __x.game__Strings_classesAllowed)
				local needs = one(left, __x.game__Strings_spellReagents)
				if low ~= nil and high ~= nil then
					local from = __x.OrdaenTooltips_text_number(low) or 0
					local to = __x.OrdaenTooltips_text_number(high) or 0
					__insert(facts, { text = __x.string_format(__x.OrdaenTooltips_locales_COL_DAMAGE, shown(from), shown(to)), glyph = "glyphs/dmg", opens = __x.OrdaenTooltips_model_named("dmg") })
					stats["dmg"] = (from + to) / 2
					local speed = __x.OrdaenTooltips_text_last(__x.OrdaenTooltips_text_clean(line.right) or "")
					if speed ~= nil then
						__insert(facts, { text = __x.string_format(__x.OrdaenTooltips_locales_COL_SPEED, shown(speed)), glyph = "glyphs/spd", opens = __x.OrdaenTooltips_model_named("spd") })
						stats["spd"] = speed
					end
				elseif single ~= nil then
					__insert(facts, { text = shown(__x.OrdaenTooltips_text_number(single) or 0), glyph = "glyphs/dmg", opens = __x.OrdaenTooltips_model_named("dmg") })
				elseif dps ~= nil then
					local perSecond = __x.OrdaenTooltips_text_number(dps) or 0
					__insert(facts, { text = __x.string_format(__x.OrdaenTooltips_locales_COL_DPS, shown(perSecond)), opens = __x.OrdaenTooltips_model_named("dps") })
					stats["dps"] = perSecond
				elseif armor ~= nil then
					local worn = __x.OrdaenTooltips_text_number(armor) or 0
					__insert(facts, { text = shown(worn), color = __x.OrdaenTooltips_colors_colorOf(line.leftColor), glyph = "glyphs/arm", opens = __x.OrdaenTooltips_model_namedWith("arm", shown(worn)) })
					stats["arm"] = worn
				elseif block ~= nil then
					local blocked = __x.OrdaenTooltips_text_number(block) or 0
					__insert(facts, { text = shown(blocked), glyph = "glyphs/blk", opens = __x.OrdaenTooltips_model_namedWith("blk", shown(blocked)) })
					stats["blk"] = blocked
				elseif room ~= nil then
					__insert(facts, { text = slots(__x.math_floor(room)), opens = __x.OrdaenTooltips_model_namedWith("bag", tostring(__x.math_floor(room))) })
				elseif current ~= nil and most ~= nil then
					local now = __x.OrdaenTooltips_text_number(current) or 0
					local whole = __x.OrdaenTooltips_text_number(most) or 1
					__insert(foot, { left = __x.OrdaenTooltips_locales_DURABILITY, right = __x.string_format("%d / %d", now, whole), valueColor = durabilityColor(now, whole), opens = __x.OrdaenTooltips_model_named("dur") })
				elseif classes ~= nil then
					__insert(foot, { left = __x.OrdaenTooltips_locales_CLASSES, right = classes, valueColor = __x.OrdaenTooltips_colors_colorOf(line.leftColor), opens = __x.OrdaenTooltips_model_named("cls") })
				elseif needs ~= nil and reagents(needs, body) then
				elseif hasStats and (left):match("^[%+%-]%d") ~= nil and __x.OrdaenTooltips_colors_colorOf(line.leftColor) == nil then
				else
					__insert(body, { left = left, color = __x.OrdaenTooltips_colors_colorOf(line.leftColor), opens = "None" })
				end
			end
		until true
	end
	if name == nil then
		return nil
	end
	if recipe then
		local __t19
		if learned then
			__t19 = __x.OrdaenTooltips_locales_KNOWN
		else
			__t19 = __x.OrdaenTooltips_locales_NOT_KNOWN
		end
		local __t20
		if learned then
			__t20 = __x.OrdaenTooltips_colors_GREY
		else
			__t20 = nil
		end
		__insert(desc, { text = __t19, color = __t20, opens = "None" })
	end
	if id ~= nil and options.itemsId then
		__insert(info, { text = "ID " .. id, opens = "None" })
	end
	if id ~= nil then
		local stack = __x.game__Items_maxStack(id) or 1
		local bags = __x.game__Items_inBags(id)
		local everywhere = __x.math_max(__x.game__Items_owned(id), bags)
		if options.itemsCount and (stack > 1 or everywhere > 1) then
			if bags > 0 then
				__insert(foot, { left = __x.OrdaenTooltips_locales_IN_BAGS, right = shown(bags), opens = __x.OrdaenTooltips_model_named("own") })
			end
			if everywhere - bags > 0 then
				__insert(foot, { left = __x.OrdaenTooltips_locales_IN_BANK, right = shown(everywhere - bags), opens = __x.OrdaenTooltips_model_named("own") })
			end
		end
		if options.itemsStack and stack > 1 then
			__insert(foot, { left = __x.OrdaenTooltips_locales_STACK, right = shown(stack), opens = __x.OrdaenTooltips_model_named("stack") })
		end
	end
	if setName ~= nil then
		__insert(sides, { kind = "set", name = setName, nameColor = __x.OrdaenTooltips_colors_GOLD, desc = {}, info = {}, facts = {}, body = setBody, more = {}, foot = {}, keys = {}, picture = "None" })
	end
	local __t21
	if id ~= nil then
		__t21 = __x.game__Items_icon(id)
	else
		__t21 = nil
	end
	return { model = { kind = "item", picture = __x.OrdaenTooltips_model_iconOf(__t21), name = name, nameColor = nameColor, desc = desc, info = info, facts = facts, body = body, more = {}, foot = foot, keys = {}, timer = timer }, sides = sides, makes = makes, stats = stats }
end

function compare(target, better, worse, lacks)
	local body = {}
	local __l23 = target.body
	for __i22 = 1, #__l23 do
		local row = __l23[__i22]
		local key = row.stat
		local right = row.right
		local __t24
		if key ~= nil then
			__t24 = (better[key] or 0) - (worse[key] or 0)
		else
			__t24 = 0
		end
		local diff = __t24
		if right == nil or diff == 0 then
			__insert(body, row)
		else
			local __t25
			if diff > 0 then
				__t25 = "|c" .. __x.OrdaenTooltips_colors_hex(__x.OrdaenTooltips_colors_GREEN) .. "(▲" .. shown(diff) .. ")|r"
			else
				__t25 = "|c" .. __x.OrdaenTooltips_colors_hex(__x.OrdaenTooltips_colors_RED) .. "(▼" .. shown(-diff) .. ")|r"
			end
			local mark = __t25
			__insert(body, { right = right .. " " .. mark, left = row.left, color = row.color, rightColor = row.rightColor, desc = row.desc, indent = row.indent, stat = row.stat, opens = row.opens })
		end
	end
	if lacks then
		for key, value in pairs(worse) do
			if better[key] == nil and (key):match("^ITEM_MOD_") ~= nil then
				__insert(body, { left = __x.game__Items_statName(key) or key, right = "— |c" .. __x.OrdaenTooltips_colors_hex(__x.OrdaenTooltips_colors_RED) .. "(▼" .. shown(value) .. ")|r", color = __x.OrdaenTooltips_colors_GREY, opens = "None" })
			end
		end
	end
	return { body = body, kind = target.kind, header = target.header, picture = target.picture, name = target.name, nameColor = target.nameColor, desc = target.desc, info = target.info, facts = target.facts, more = target.more, foot = target.foot, keys = target.keys, timer = target.timer }
end

M.BLANK = BLANK
M.SELL_PRICE = SELL_PRICE
M.NESTED = NESTED
M.BINDING = BINDING
M.ITEM_SLOT = ITEM_SLOT
M.ITEM_NAME = ITEM_NAME
M.TEACHES = TEACHES
M.SET_LINE = SET_LINE
M.REQUIREMENT = REQUIREMENT
M.USE = USE
M.EQUIP = EQUIP
M.CHANCE = CHANCE
M.binding = binding
M.shown = shown
M.one = one
M.two = two
M.durabilityColor = durabilityColor
M.slots = slots
M.reagents = reagents
M.withNote = withNote
M.item = item
M.compare = compare
