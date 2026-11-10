-- What a Blizzard tooltip shows, as Ordaen Tooltips' one skeleton (design tooltips/: header, title, columns, body,
-- footer, hotkeys): read from the game's tooltip data (api/forever/tooltip-data.md: kinds and line types measured
-- on Forever), never by changing Blizzard's tooltip. One model per tooltip view, refilled on every show: its lists
-- keep their tables and only their counts change, so a show makes no tables after the first ones.
--   model.kind      "item" | "spell" | "aura" | "unit" | "object" (Read returns false for what we don't draw)
--   model.icon      a texture (file ID or path), or nil: no icon; model.portrait: a unit token for a face instead
--   model.name, model.nameColor
--   model.desc[], model.info[]   the title's second and third lines, parts joined with « · »
--   model.cols[]    { text, color }       one cell per fact
--   model.body[]    { left, right, color, free }   rows (left and right) or free text (wraps)
--   model.foot[]    { left, right, color, valueColor }   label and value lines
--   model.keys[]    hotkey lines
local Read = {}

local format, tonumber, select = string.format, tonumber, select

-- Colours as the draw takes them, { r, g, b, 1 }: one table per colour, made once and never changed, so a text drawn
-- in another colour gets another table (the draw compares tables, not their contents)
local colors = {}
local function Rgb(r, g, b)
	local key = math.floor(r * 255 + 0.5) * 65536 + math.floor(g * 255 + 0.5) * 256 + math.floor(b * 255 + 0.5)
	local color = colors[key]
	if not color then
		color = { r, g, b, 1 }
		colors[key] = color
	end
	return color
end
Read.Rgb = Rgb

local isSecret = issecretvalue or function()
	return false
end

-- Forever's tooltip data types (Enum.TooltipDataType, measured: the dump lists the enum without values)
local KIND = { [0] = "item", [1] = "spell", [2] = "unit", [4] = "object", [7] = "aura" }
-- line types (Enum.TooltipDataLineType, measured)
local LINE = {
	Blank = 1, UnitName = 2, SellPrice = 11, SpellName = 13, UnitOwner = 16, NestedBlock = 19, Binding = 20,
	ItemSlot = 21, ItemName = 22, Passive = 33, Description = 34, Flavor = 37, Teaches = 38, SetLine = 42,
	Requirement = 43, Use = 44, Equip = 45, Chance = 46,
}
Read.LINE = LINE

local RED = { 1, 0.25, 0.25, 1 }
local GOLD = { 1, 0.82, 0, 1 }

-- a list kept across shows: entries reused, `n` the count in use
local function List()
	return { n = 0 }
end

local function Push(list)
	local n = list.n + 1
	list.n = n
	local entry = list[n]
	if not entry then
		entry = {}
		list[n] = entry
	end
	entry.left, entry.right, entry.color, entry.valueColor, entry.free, entry.text = nil, nil, nil, nil, nil, nil
	return entry
end

--- A new model for one tooltip view (made once).
function Read.NewModel()
	return { desc = List(), info = List(), cols = List(), body = List(), foot = List(), keys = List() }
end

local function Clear(model)
	model.desc.n, model.info.n, model.cols.n, model.body.n, model.foot.n, model.keys.n = 0, 0, 0, 0, 0, 0
	model.icon, model.portrait, model.name, model.header = nil, nil, nil, nil
	model.nameColor = Rgb(1, 1, 1)
end


-- a line's colour (its ColorMixin), or nil for white and unreadable ones
local function ColorOf(color)
	if type(color) ~= "table" or isSecret(color) then
		return nil
	end
	local r, g, b = color.r, color.g, color.b
	if type(r) ~= "number" or (r > 0.95 and g > 0.95 and b > 0.95) then
		return nil
	end
	return Rgb(r, g, b)
end

-- The game's grammar codes, which Forever leaves in some lines (api/forever/tooltip-data.md): the plural code
-- `|4one:few:many;` takes the form for the number before it, the case code `|3-6(word)` is the word. A line without
-- either is returned as it is (no string made).
-- the Russian plural rule (the game's codes follow it): 1 one (1, 21), 2 few (2–4, 22–24), 3 many (the rest, 11–14 too)
local function Form(n)
	local mod10, mod100 = n % 10, n % 100
	if mod10 == 1 and mod100 ~= 11 then
		return 1
	elseif mod10 >= 2 and mod10 <= 4 and (mod100 < 12 or mod100 > 14) then
		return 2
	end
	return 3
end

local function PluralForm(n, forms)
	local one, few, many = forms:match("^([^:]*):([^:]*):?(.*)$")
	if not one then
		return forms
	end
	local form = Form(n)
	return form == 1 and one or form == 2 and few or (many ~= "" and many or few)
end

local function Grammar(text)
	if not text:find("|[34]") then
		return text
	end
	text = text:gsub("(%d+)([^|%d]*)|4([^;]*);", function(n, between, forms)
		return n .. between .. PluralForm(tonumber(n), forms)
	end)
	return (text:gsub("|3%-%d+%((.-)%)", "%1"))
end
Read.Grammar = Grammar

local function Text(value)
	if type(value) ~= "string" or isSecret(value) or value == "" then
		return nil
	end
	return Grammar(value)
end

local function Part(list, text, color)
	if text then
		local part = Push(list)
		part.text, part.color = text, color
	end
end

local function Body(model, line, free)
	local left = Text(line.leftText)
	if not left then
		return
	end
	local row = Push(model.body)
	row.left, row.right, row.free = left, Text(line.rightText), free
	row.color = ColorOf(line.leftColor)
end

local function Foot(model, left, right, valueColor)
	local row = Push(model.foot)
	row.left, row.right, row.valueColor = left, right, valueColor
end

-- Items ------------------------------------------------------------------------------------------------------------

-- A Blizzard format string as a Lua pattern, made once per string: %s and %d capture, a number format (%.1f) captures
-- a number, a grammar code (|4one:few:many;) matches any word; the whole line, start to end.
local patterns = {}
local function Pattern(format)
	if type(format) ~= "string" then
		return nil
	end
	local pattern = patterns[format]
	if pattern == nil then
		local p = format:gsub("|4[^;]*;", "\001") -- the plural code: one word
		p = p:gsub("%%%%", "\002") -- a literal percent sign
		p = p:gsub("%%[%d%$]*%.?%d*[sdf]", "\003") -- a format code: a capture
		p = p:gsub("([%^%$%(%)%.%[%]%*%+%-%?])", "%%%1") -- the rest literally
		p = p:gsub("\003", "(.-)"):gsub("\001", "%%S+"):gsub("\002", "%%%%")
		pattern = "^" .. p .. "$"
		patterns[format] = pattern
	end
	return pattern
end
Read.Pattern = Pattern

local function Match(text, format)
	local pattern = Pattern(format)
	if pattern and text then
		return text:match(pattern)
	end
end

-- a number as the game wrote it ("2,60", "1 234"), or nil
local function Number(text)
	if not text then
		return nil
	end
	return tonumber((text:gsub("[%s\194\160]", ""):gsub(",", ".")))
end

-- the right side's number (a weapon's speed: "Скорость 2,60")
local function Last(text)
	return text and Number(text:match("([%d%.,]+)%s*$"))
end

local function Cell(model, text, color)
	local cell = Push(model.cols)
	cell.text, cell.color = text, color
end

local GREEN = { 0.12, 1, 0, 1 }
local YELLOW = { 1, 0.82, 0, 1 }

-- durability's colour: red when broken, yellow at a quarter or less, else the footer's quiet value
local function DurabilityColor(current, maximum)
	if current <= 0 then
		return RED
	elseif current <= maximum / 4 then
		return YELLOW
	end
	return nil
end

local function Item(model, data, ctx)
	local id = type(data.id) == "number" and not isSecret(data.id) and data.id or nil
	model.icon = id and C_Item.GetItemIconByID(id) or nil
	local L, numbers = ctx.L, ctx.numbers
	local level = id and select(4, C_Item.GetItemInfo(id))
	if ctx.itemsIlvl and type(level) == "number" and level > 1 then
		local row = Push(model.body)
		row.left, row.right = L.ITEM_LEVEL_ROW, numbers:Format(level)
	end
	local lines = data.lines
	for i = 1, #lines do
		local line = lines[i]
		local kind = line.type
		local left = Text(line.leftText)
		if kind == LINE.ItemName then
			model.name = left
			local quality = line.quality
			local color = type(quality) == "number" and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
			if color then
				model.nameColor = Rgb(color.r, color.g, color.b)
			end
		elseif kind == LINE.ItemSlot then
			Part(model.desc, left, line.isValidInvSlot == false and RED or nil)
			Part(model.desc, Text(line.rightText), line.isValidItemType == false and RED or nil)
		elseif kind == LINE.Binding then
			Part(model.info, left)
		elseif kind == LINE.SellPrice then
			local price = line.price
			if type(price) == "number" and not isSecret(price) and price > 0 then
				Foot(model, SELL_PRICE, GetMoneyString(price, true))
			end
		elseif kind == LINE.Requirement then
			if left then
				Foot(model, left, nil, line.usable == false and RED or nil)
			end
		elseif kind == LINE.Blank or kind == LINE.NestedBlock or not left then -- luacheck: ignore 542
			-- nothing to draw
		elseif left == ITEM_UNIQUE or left == ITEM_UNIQUE_EQUIPPABLE then
			Part(model.desc, left) -- «Уникальный» joins the description
		else
			-- the columns: damage and speed, damage per second, armor, block, a bag's slots
			local low, high = Match(left, DAMAGE_TEMPLATE_WITH_SCHOOL) -- the school is the item's type already
			if not low then
				low, high = Match(left, DAMAGE_TEMPLATE)
			end
			local single = not low and (Match(left, SINGLE_DAMAGE_TEMPLATE_WITH_SCHOOL) or
				Match(left, SINGLE_DAMAGE_TEMPLATE))
			local dps = Match(left, DPS_TEMPLATE)
			local armor = Match(left, ARMOR_TEMPLATE)
			local block = Match(left, SHIELD_BLOCK_TEMPLATE)
			local slotsA, slotsB = Match(line.leftText, CONTAINER_SLOTS) -- the raw line: the plural code still in it
			local slots = Number(slotsA) or Number(slotsB)
			local current, maximum = Match(left, DURABILITY_TEMPLATE)
			local classes = Match(left, ITEM_CLASSES_ALLOWED)
			if low and high then
				Cell(model, format(L.COL_DAMAGE, numbers:Format(Number(low) or 0), numbers:Format(Number(high) or 0)))
				local speed = Last(Text(line.rightText))
				if speed then
					Cell(model, format(L.COL_SPEED, numbers:Format(speed)))
				end
			elseif single then
				Cell(model, numbers:Format(Number(single) or 0))
			elseif dps then
				Cell(model, format(L.COL_DPS, numbers:Format(Number(dps) or 0)))
			elseif armor then
				-- bonus armor is in the total, green as the game shows it
				Cell(model, format(L.COL_ARMOR, numbers:Format(Number(armor) or 0)), ColorOf(line.leftColor))
			elseif block then
				Cell(model, format(L.COL_BLOCK, numbers:Format(Number(block) or 0)))
			elseif slots then
				Cell(model, Read.Plural(L, "COL_SLOTS", slots))
			elseif current and maximum then
				local c, m = Number(current) or 0, Number(maximum) or 1
				Foot(model, L.DURABILITY, format("%d / %d", c, m), DurabilityColor(c, m))
			elseif classes then
				Foot(model, L.CLASSES, classes)
			else
				Body(model, line, true)
			end
		end
	end
	if id and ctx.itemsId then
		Part(model.info, "ID " .. id)
	end
	return model.name ~= nil
end

local SUFFIX = { "_ONE", "_FEW", "_MANY" }
--- `L[<key>_ONE|_FEW|_MANY]` for n: the Russian plural rule on ruRU, one and the rest elsewhere (English).
function Read.Plural(L, key, n)
	local form = GetLocale() == "ruRU" and Form(n) or (n == 1 and 1 or 3)
	return format(L[key .. SUFFIX[form]], n)
end

-- Spells and auras ---------------------------------------------------------------------------------------------------

local function Spell(model, data, settings, aura)
	local id = type(data.id) == "number" and not isSecret(data.id) and data.id or nil
	model.icon = id and C_Spell.GetSpellTexture(id) or nil
	local lines = data.lines
	for i = 1, #lines do
		local line = lines[i]
		local kind = line.type
		if (kind == LINE.SpellName or (aura and i == 1)) and not model.name then
			model.name = Text(line.leftText)
			Part(model.desc, Text(line.rightText)) -- the rank, an aura's dispel type
			if aura then
				model.nameColor = Rgb(GOLD[1], GOLD[2], GOLD[3])
			end
		elseif kind == LINE.Requirement then
			local text = Text(line.leftText)
			if text then
				Foot(model, text, nil, line.usable == false and RED or nil)
			end
		elseif kind == LINE.Description then
			Body(model, line, true)
		elseif kind == LINE.Passive then
			Part(model.desc, Text(line.leftText))
		elseif kind ~= LINE.Blank then
			-- cost and range, cast and cooldown: Forever's two-sided lines, cells of the band
			local left, right = Text(line.leftText), Text(line.rightText)
			if aura and left and left:find("^ID ") then -- Forever's own spell ID line: on the info line if wanted
				left = nil
			end
			if left and right then
				Push(model.cols).text = left
				Push(model.cols).text = right
			elseif left then
				if line.leftColor and not aura and i <= 3 then
					Push(model.cols).text = left
				else
					Body(model, line, true)
				end
			end
		end
	end
	if id and (aura and settings.aurasId or not aura and settings.spellsId) then
		Part(model.info, "ID " .. id)
	end
	return model.name ~= nil
end

-- Units ------------------------------------------------------------------------------------------------------------

local function Unit(model, data)
	local lines = data.lines
	local unit
	for i = 1, #lines do
		local line = lines[i]
		if line.type == LINE.UnitName then
			model.name = Text(line.leftText)
			unit = Text(line.unitToken)
		elseif i > 1 and line.type ~= LINE.Blank then
			local text = Text(line.leftText)
			if text then
				local list = model.desc.n < 1 and model.desc or model.info
				Part(list, text, ColorOf(line.leftColor))
			end
		end
	end
	if unit then
		model.portrait = unit
		local color
		if UnitIsPlayer(unit) then
			local _, class = UnitClass(unit)
			color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
		else
			local reaction = UnitReaction(unit, "player")
			color = reaction and FACTION_BAR_COLORS and FACTION_BAR_COLORS[reaction]
		end
		if color then
			model.nameColor = Rgb(color.r, color.g, color.b)
		end
	end
	return model.name ~= nil
end

-- Objects (signs, nodes, chests): the name in gold, the rest as the game wrote it
local function Object(model, data)
	local lines = data.lines
	for i = 1, #lines do
		local line = lines[i]
		if i == 1 then
			model.name = Text(line.leftText)
			model.nameColor = Rgb(GOLD[1], GOLD[2], GOLD[3])
		elseif line.type ~= LINE.Blank then
			Body(model, line, true)
		end
	end
	return model.name ~= nil
end

--- The kind of a tooltip's data ("item", "spell", ...) or nil for one Ordaen Tooltips leaves to Blizzard.
function Read.Kind(data)
	local t = data and data.type
	return type(t) == "number" and not isSecret(t) and KIND[t] or nil
end

--- Fill `model` from the tooltip data; false when it can't be read (that show stays Blizzard's).
---@param ctx table the module's settings read plainly (itemsId, itemsIlvl, spellsId, aurasId), `numbers` (game.Numbers)
--- and `L` (its locales)
function Read.Fill(model, data, ctx)
	Clear(model)
	local kind = Read.Kind(data)
	local lines = data and data.lines
	if not kind or type(lines) ~= "table" or isSecret(lines) then
		return false
	end
	model.kind = kind
	if kind == "item" then
		return Item(model, data, ctx)
	elseif kind == "spell" then
		return Spell(model, data, ctx, false)
	elseif kind == "aura" then
		return Spell(model, data, ctx, true)
	elseif kind == "unit" then
		return Unit(model, data)
	end
	return Object(model, data)
end

return Read
