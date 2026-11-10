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
	return { desc = List(), info = List(), cols = List(), body = List(), foot = List(), keys = List(),
		nameColor = { 1, 1, 1, 1 } }
end

local function Clear(model)
	model.desc.n, model.info.n, model.cols.n, model.body.n, model.foot.n, model.keys.n = 0, 0, 0, 0, 0, 0
	model.icon, model.portrait, model.name, model.header = nil, nil, nil, nil
	local c = model.nameColor
	c[1], c[2], c[3] = 1, 1, 1
end

-- a line's colour as { r, g, b, 1 } into `into` (the line's ColorMixin), or nil for white and unreadable ones
local function ColorOf(color, into)
	if type(color) ~= "table" or isSecret(color) then
		return nil
	end
	local r, g, b = color.r, color.g, color.b
	if type(r) ~= "number" or (r > 0.95 and g > 0.95 and b > 0.95) then
		return nil
	end
	into = into or {}
	into[1], into[2], into[3], into[4] = r, g, b, 1
	return into
end

local function Text(value)
	if type(value) ~= "string" or isSecret(value) or value == "" then
		return nil
	end
	return value
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
	row.buf = row.buf or {}
	row.color = ColorOf(line.leftColor, row.buf)
end

local function Foot(model, left, right, valueColor)
	local row = Push(model.foot)
	row.left, row.right, row.valueColor = left, right, valueColor
end

-- Items ------------------------------------------------------------------------------------------------------------

local function Item(model, data, settings)
	local id = type(data.id) == "number" and not isSecret(data.id) and data.id or nil
	model.icon = id and C_Item.GetItemIconByID(id) or nil
	local lines = data.lines
	for i = 1, #lines do
		local line = lines[i]
		local kind = line.type
		if kind == LINE.ItemName then
			model.name = Text(line.leftText)
			local quality = line.quality
			local color = type(quality) == "number" and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
			if color then
				local c = model.nameColor
				c[1], c[2], c[3] = color.r, color.g, color.b
			end
		elseif kind == LINE.ItemSlot then
			Part(model.desc, Text(line.leftText), line.isValidInvSlot == false and RED or nil)
			Part(model.desc, Text(line.rightText), line.isValidItemType == false and RED or nil)
		elseif kind == LINE.Binding then
			Part(model.info, Text(line.leftText))
		elseif kind == LINE.SellPrice then
			local price = line.price
			if type(price) == "number" and not isSecret(price) and price > 0 then
				Foot(model, SELL_PRICE, GetMoneyString(price, true))
			end
		elseif kind == LINE.Requirement then
			local text = Text(line.leftText)
			if text then
				Foot(model, text, nil, line.usable == false and RED or nil)
			end
		elseif kind ~= LINE.Blank and kind ~= LINE.NestedBlock then
			Body(model, line, true)
		end
	end
	if id and settings.itemsId then
		Part(model.info, "ID " .. id)
	end
	return model.name ~= nil
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
				local c = model.nameColor
				c[1], c[2], c[3] = GOLD[1], GOLD[2], GOLD[3]
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
				Part(list, text)
				local part = list[list.n]
				part.buf = part.buf or {}
				part.color = ColorOf(line.leftColor, part.buf)
			end
		end
	end
	if unit then
		model.portrait = unit
		local c = model.nameColor
		if UnitIsPlayer(unit) then
			local _, class = UnitClass(unit)
			local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
			if color then
				c[1], c[2], c[3] = color.r, color.g, color.b
			end
		else
			local reaction = UnitReaction(unit, "player")
			local color = reaction and FACTION_BAR_COLORS and FACTION_BAR_COLORS[reaction]
			if color then
				c[1], c[2], c[3] = color.r, color.g, color.b
			end
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
			local c = model.nameColor
			c[1], c[2], c[3] = GOLD[1], GOLD[2], GOLD[3]
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
---@param settings table the module's settings, read plainly (spellsId, itemsId, aurasId)
function Read.Fill(model, data, settings)
	Clear(model)
	local kind = Read.Kind(data)
	local lines = data and data.lines
	if not kind or type(lines) ~= "table" or isSecret(lines) then
		return false
	end
	model.kind = kind
	if kind == "item" then
		return Item(model, data, settings)
	elseif kind == "spell" then
		return Spell(model, data, settings, false)
	elseif kind == "aura" then
		return Spell(model, data, settings, true)
	elseif kind == "unit" then
		return Unit(model, data)
	end
	return Object(model, data)
end

return Read
