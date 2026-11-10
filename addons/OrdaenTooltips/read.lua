-- What a Blizzard tooltip shows, as Ordaen Tooltips' one skeleton (design tooltips/: header, title, columns, body,
-- more, footer, hotkeys), read from the game's tooltip data (api/forever/tooltip-data.md: kinds and line types
-- measured on Forever) and the game's own APIs, never by changing Blizzard's tooltip. One model per tooltip view,
-- refilled on every show: its lists keep their tables and only their counts change.
--   model.kind      "item" | "spell" | "aura" | "unit" | "object" | "text" (a show without data: a button's text)
--   model.header    a heading above the title («Надето» on the equipped item of a comparison), or nil
--   model.icon      a texture, or nil; model.portrait: a unit token for a face instead
--   model.name, model.nameColor
--   model.desc[], model.info[]   the title's second and third lines, parts joined with « · »
--   model.cols[]    { text, color, glyph, tint }   one cell per fact, its glyph's name (glyphs.lua)
--   model.body[]    { left, right, color, rightColor }   rows (left and right) or free text (no right: wraps)
--   model.foot[]    { left, right, color, valueColor }   label and value lines
--   model.keys[]    hotkey lines
--   model.side[]    tooltips beside this one, open from the start (use effects, the set, the item a recipe makes)
--   model.timer     a value counts down while it shows (a cooldown, an aura's time): read again once a second
--   model.stats     an item's stats by key (GetItemStats), for the comparison
local Read = {}

local format, tonumber, select, floor, max = string.format, tonumber, select, math.floor, math.max
local pairs, type = pairs, type

local isSecret = issecretvalue or function()
	return false
end

-- Colours ----------------------------------------------------------------------------------------------------------

-- Colours as the draw takes them, { r, g, b, 1 }: one table per colour, made once and never changed, so a text drawn
-- in another colour gets another table (the draw compares tables, not their contents)
local colors = {}
local function Rgb(r, g, b)
	local key = floor(r * 255 + 0.5) * 65536 + floor(g * 255 + 0.5) * 256 + floor(b * 255 + 0.5)
	local color = colors[key]
	if not color then
		color = { r, g, b, 1 }
		colors[key] = color
	end
	return color
end
Read.Rgb = Rgb

local RED = Rgb(1, 0.25, 0.25)
local GREEN = Rgb(0.12, 1, 0)
local GOLD = Rgb(1, 0.82, 0)
local YELLOW = Rgb(1, 0.82, 0)
local GREY = Rgb(0.5, 0.5, 0.5)
local LABEL = Rgb(0.796, 0.725, 0.58)
local WHITE = Rgb(1, 1, 1)

local function Hex(c)
	return format("ff%02x%02x%02x", c[1] * 255, c[2] * 255, c[3] * 255)
end

-- a game colour (a ColorMixin or { r, g, b }), or nil for white and unreadable ones
local function ColorOf(color)
	if type(color) ~= "table" or isSecret(color) then
		return nil
	end
	local r, g, b = color.r or color[1], color.g or color[2], color.b or color[3]
	if type(r) ~= "number" or (r > 0.95 and g > 0.95 and b > 0.95) then
		return nil
	end
	return Rgb(r, g, b)
end

-- Data lines -------------------------------------------------------------------------------------------------------

-- Forever's tooltip data types (Enum.TooltipDataType, measured: the dump lists the enum without values)
local KIND = { [0] = "item", [1] = "spell", [2] = "unit", [4] = "object", [7] = "aura" }
-- line types (Enum.TooltipDataLineType, measured)
local LINE = {
	Blank = 1, UnitName = 2, SellPrice = 11, SpellName = 13, UnitOwner = 16, NestedBlock = 19, Binding = 20,
	ItemSlot = 21, ItemName = 22, Passive = 33, Description = 34, Flavor = 37, Teaches = 38, SetLine = 42,
	Requirement = 43, Use = 44, Equip = 45, Chance = 46,
}
Read.LINE = LINE

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

-- The game's grammar codes, which Forever leaves in some lines: the plural code `|4one:few:many;` takes the form for
-- the number before it, the case code `|3-6(word)` is the word. A line without either comes back as it is.
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

local SUFFIX = { "_ONE", "_FEW", "_MANY" }
--- `L[<key>_ONE|_FEW|_MANY]` for n: the Russian plural rule on ruRU, one and the rest elsewhere (English).
function Read.Plural(L, key, n)
	local form = GetLocale() == "ruRU" and Form(n) or (n == 1 and 1 or 3)
	return format(L[key .. SUFFIX[form]], n)
end

local function Text(value)
	if type(value) ~= "string" or isSecret(value) or value == "" then
		return nil
	end
	return Grammar(value)
end

local function Id(value)
	return type(value) == "number" and not isSecret(value) and value or nil
end

-- A Blizzard format string as a Lua pattern, made once per string: %s, %d and %.1f capture, a grammar code matches
-- any word; the whole line, start to end.
local patterns = {}
local function Pattern(fmt)
	if type(fmt) ~= "string" then
		return nil
	end
	local pattern = patterns[fmt]
	if pattern == nil then
		local p = fmt:gsub("|4[^;]*;", "\001") -- the plural code: one word
		p = p:gsub("%%%%", "\002") -- a literal percent sign
		p = p:gsub("%%[%d%$]*%.?%d*[sdf]", "\003") -- a format code: a capture
		p = p:gsub("([%^%$%(%)%.%[%]%*%+%-%?])", "%%%1") -- the rest literally
		p = p:gsub("\003", "(.-)"):gsub("\001", "%%S+"):gsub("\002", "%%%%")
		pattern = "^" .. p .. "$"
		patterns[fmt] = pattern
	end
	return pattern
end
Read.Pattern = Pattern

local function Match(text, fmt)
	local pattern = Pattern(fmt)
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

local function Last(text)
	return text and Number(text:match("([%d%.,]+)%s*$"))
end

-- Lists ------------------------------------------------------------------------------------------------------------

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
	entry.left, entry.right, entry.color, entry.rightColor, entry.valueColor = nil, nil, nil, nil, nil
	entry.text, entry.glyph, entry.tint, entry.stat = nil, nil, nil, nil
	return entry
end

--- A new model for one tooltip view (made once).
function Read.NewModel()
	return { desc = List(), info = List(), cols = List(), body = List(), more = List(), foot = List(), keys = List(),
		side = List(), stats = {} }
end

local function Clear(model)
	model.desc.n, model.info.n, model.cols.n, model.body.n, model.foot.n, model.keys.n = 0, 0, 0, 0, 0, 0
	model.more.n = 0
	model.side.n = 0
	model.icon, model.portrait, model.name, model.header, model.timer = nil, nil, nil, nil, nil
	model.nameColor, model.kind, model.id = WHITE, nil, nil
	local stats = model.stats
	for k in pairs(stats) do
		stats[k] = nil
	end
end

-- `term` (and `amount`, the number it speaks of): the glossary entry a locked tooltip opens from this part (design
-- tooltips «Tooltips in tooltips»; Read.Term)
local function Part(list, text, color, term, link)
	if text then
		local part = Push(list)
		part.text, part.color, part.term, part.link = text, color, term, link
	end
end

-- a free line of the body (wraps), in its own colour or the body's
local function Free(model, text, color)
	if text then
		local row = Push(model.body)
		row.left, row.right, row.color, row.rightColor, row.desc, row.term = text, nil, color, nil, nil, nil
		row.link, row.indent = nil, nil
	end
end

-- a spell's or aura's description (design .txt-body): a free line, larger than the footer, in the body's colour
local function Desc(model, text)
	if text then
		local row = Push(model.body)
		row.left, row.right, row.color, row.rightColor, row.desc, row.term = text, nil, nil, nil, true, nil
		row.link, row.indent = nil, nil
	end
end

-- a row of the body: the name on the left, the value on the right
local function Row(model, left, right, color, rightColor)
	local row = Push(model.body)
	row.left, row.right, row.color, row.rightColor, row.desc, row.term = left, right, color, rightColor, nil, nil
	row.link, row.indent = nil, nil
	return row
end

-- a footer line: its label on the left, its value on the right; a line the game writes «Label: value» («Требуется:
-- Оборонительная стойка») is split so (design TooltipFooter: every footer line a label and a value)
local function Foot(model, left, right, valueColor, term, amount, link)
	if not right and left then
		local label, value = left:match("^([^:|]+):%s+(.+)$")
		if label then
			left, right = label, value
		end
	end
	local row = Push(model.foot)
	row.left, row.right, row.valueColor, row.term, row.amount, row.link = left, right, valueColor, term, amount, link
	row.valueLink = nil
	return row
end

-- a cell of the band; its term is its glyph's unless given
local function Cell(model, text, color, glyph, tint, term, amount)
	local cell = Push(model.cols)
	cell.text, cell.color, cell.glyph, cell.tint = text, color, glyph, tint
	cell.term, cell.amount, cell.link = term or glyph, amount, nil
	return cell
end

-- a side tooltip (made once per slot of model.side): its own model
local function Side(model)
	local side = model.side
	local n = side.n + 1
	side.n = n
	local sub = side[n]
	if not sub then
		sub = Read.NewModel()
		side[n] = sub
	end
	Clear(sub)
	return sub
end

-- Time -------------------------------------------------------------------------------------------------------------

-- seconds as the game writes a duration: «12 сек.», «3 мин.», «1 ч.» (Blizzard's own abbreviations)
local function Duration(seconds)
	if seconds >= 3600 then
		return format(HOUR_ONELETTER_ABBR or "%d h", floor(seconds / 3600 + 0.5))
	elseif seconds >= 60 then
		return format(MINUTE_ONELETTER_ABBR or "%d m", floor(seconds / 60 + 0.5))
	end
	return format(SECOND_ONELETTER_ABBR or "%d s", floor(seconds + 0.5))
end
Read.Duration = Duration

-- how long until a cooldown (start, duration) is over, or nil when it's ready (the global cooldown doesn't count)
local function Remaining(start, duration)
	if type(start) ~= "number" or type(duration) ~= "number" or duration <= 1.5 or start <= 0 then
		return nil
	end
	local left = start + duration - GetTime()
	return left > 0 and left or nil
end

-- a binding line's term, by the game's own text for it
local BINDING = {}
for global, term in pairs({ ITEM_SOULBOUND = "bound", ITEM_BIND_ON_EQUIP = "boe", ITEM_BIND_ON_PICKUP = "bop" }) do
	local text = _G[global] -- luacheck: ignore 113
	if type(text) == "string" then
		BINDING[text] = term
	end
end

-- Terms -----------------------------------------------------------------------------------------------------------

--- A glossary entry as a tooltip (design tooltips «Tooltips in tooltips»: a part's term): its name in gold, its text;
--- both from the locales (TERM_<KEY>, TERM_<KEY>_TEXT), a «%s» in them the amount the part spoke of. False when the
--- locales have no such term.
-- other modules' glossary entries (the API's DefineTerm): key -> { name, text }
Read.terms = {}

function Read.Term(model, key, amount, L)
	local upper = "TERM_" .. key:upper()
	local own = Read.terms[key]
	local name, text = rawget(L, upper), rawget(L, upper .. "_TEXT")
	if own then
		name, text = own.name, own.text
	end
	if not name or not text then
		return false
	end
	Clear(model)
	model.kind = "term"
	local n = amount or ""
	model.name = name:find("%s", 1, true) and format(name, n) or name
	model.nameColor = GOLD
	Free(model, text:find("%s", 1, true) and format(text, n) or text)
	return true
end

-- Rich text --------------------------------------------------------------------------------------------------------

-- A description as the design draws it (colour only: a FontString has one font): numbers white, a spell's name in
-- «ёлочках» gold, and a link (|Hordaen:spell:ID|h) when it's a spell of the player's spellbook other than this one: a
-- locked tooltip opens it beside (design spells «Hovering a name»). Made once per spell and text (the raw text and the
-- spellbook compared on every show: a change re-parses it).
local rich = {}
local spellbook, book = {}, 0 -- spell name -> spellID; changes with each reading of the spellbook
local tabOf = {} -- spellID -> its spellbook tab's name (the title's second line, after the rank)
local current -- the spell whose text is parsed (its own name stays plain)

--- The player's spells by name (on SPELLS_CHANGED): the names their descriptions quote open their tooltips.
function Read.Spellbook()
	for name in pairs(spellbook) do
		spellbook[name] = nil
	end
	for id in pairs(tabOf) do
		tabOf[id] = nil
	end
	local banks = Enum and Enum.SpellBookSpellBank
	local bank = banks and banks.Player or 0
	for line = 1, C_SpellBook.GetNumSpellBookSkillLines() or 0 do
		local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
		local first, count = info and info.itemIndexOffset or 0, info and info.numSpellBookItems or 0
		for slot = first + 1, first + count do
			local item = C_SpellBook.GetSpellBookItemInfo(slot, bank)
			if item and type(item.name) == "string" and type(item.spellID) == "number" then
				spellbook[item.name] = item.spellID
				tabOf[item.spellID] = info and info.name or nil
			end
		end
	end
	book = book + 1
end

local function Quoted(name)
	local id = spellbook[name]
	if id and id ~= current then
		return "|cffffd100|Hordaen:spell:" .. id .. "|h«" .. name .. "»|h|r"
	end
	return "|cffffd100«" .. name .. "»|r"
end

-- the damage schools a description names, each a link to its term (design spells «How it's parsed»: the client's
-- phrases with their case forms, longest first; Lua patterns have no alternation): set from the locales (Read.Schools)
local schools = {} -- { phrase, key } longest first
-- each school's colour (design Tooltip.vue .school.<key>)
local SCHOOL_COLOR = { phys = "e0c9a0", fire = "ff8a3c", nature = "6ed04a", frost = "8fd2ff", shadow = "b48ae8",
	arcane = "e48af0", holy = "ffe680" }
local function ByLength(a, b)
	return #a[1] > #b[1]
end
--- The school phrases of the client's language: TERM_<SCHOOL>_WORDS, its forms separated by «|».
function Read.Schools(L)
	for _, key in ipairs({ "phys", "fire", "nature", "frost", "shadow", "arcane", "holy" }) do
		local words = rawget(L, "TERM_" .. key:upper() .. "_WORDS")
		for phrase in (words or ""):gmatch("[^|]+") do
			schools[#schools + 1] = { phrase, key }
		end
	end
	table.sort(schools, ByLength)
end
-- the schools linked in a text, each in its colour: a found phrase's run replaced so a shorter phrase in it isn't
-- linked again
local function Schools(text)
	for i = 1, #schools do
		local phrase, key = schools[i][1], schools[i][2]
		local at = text:find(phrase, 1, true)
		while at do
			local link = "|cff" .. SCHOOL_COLOR[key] .. "|Hordaen:term:" .. key .. ":|h" .. phrase .. "|h|r"
			text = text:sub(1, at - 1) .. link .. text:sub(at + #phrase)
			at = text:find(phrase, at + #link, true)
		end
	end
	return text
end

local function Rich(id, text)
	if not text then
		return nil
	end
	local entry = id and rich[id]
	if entry and entry.raw == text and entry.book == book then
		return entry.rich
	end
	current = id
	local out = Schools(text:gsub("(%d+[%.,]?%d*%%?)", "|cffffffff%1|r"):gsub("«(.-)»", Quoted))
	if id then
		rich[id] = { raw = text, rich = out, book = book }
	end
	return out
end
Read.Rich = Rich

--- A race's racial abilities (design players «Hovering the race»): the race in gold, then one line per racial, its
--- name in gold and its effect as the skills' rich text; a class's own variant only for that class (Read.racials:
--- raceID -> spellID, classMask pairs, generated from the client data). False for a race without any.
function Read.Race(model, raceID, classID, raceName)
	local list = Read.racials and Read.racials[raceID]
	if not list then
		return false
	end
	Clear(model)
	model.kind = "race"
	model.name, model.nameColor = raceName, GOLD
	local bit = classID and classID > 0 and 2 ^ (classID - 1) or 0
	for i = 1, #list, 2 do
		local id, mask = list[i], list[i + 1]
		if mask == 0 or bit > 0 and floor(mask / bit) % 2 == 1 then
			local name = C_Spell.GetSpellName(id)
			local text = C_Spell.GetSpellDescription(id)
			if name then
				Desc(model, "|cffffd100" .. name .. "|r" .. (text and text ~= "" and " — " .. Rich(id, text) or ""))
			end
		end
	end
	return true
end

--- An item stat's tooltip (design items «Stats are rows»: the character tab's wording, this character's numbers):
--- the stat and the item's amount, then what that amount gives. False for a stat without a text of ours.
function Read.Stat(model, key, amount, L)
	local name = _G[key] -- luacheck: ignore 113 (B8: the game's own stat names, by the keys it gives)
	if type(name) ~= "string" or not amount then
		return false
	end
	local text
	if key == "ITEM_MOD_STRENGTH_SHORT" then
		text = format(L.STAT_STR, GetAttackPowerForStat(1, amount) or amount * 2)
	elseif key == "ITEM_MOD_AGILITY_SHORT" then
		text = format(L.STAT_AGI, amount / 20, amount * 2, amount * 2, amount / 20)
	elseif key == "ITEM_MOD_STAMINA_SHORT" then
		text = format(L.STAT_STA, floor(amount * 10 * (GetUnitMaxHealthModifier("player") or 1) + 0.5))
	elseif key == "ITEM_MOD_INTELLECT_SHORT" then
		text = UnitPowerType("player") == 0 and format(L.STAT_INT, amount * 15)
			or "|cff808080" .. (STAT_USELESS_TOOLTIP or "") .. "|r"
	elseif key == "ITEM_MOD_SPIRIT_SHORT" then
		text = format(L.STAT_SPI, floor(amount * 1.2 + 0.5))
	end
	if not text then
		return false
	end
	Clear(model)
	model.kind = "stat"
	model.name, model.nameColor = format("%s %+d", name, amount), GOLD
	Desc(model, text)
	return true
end

--- A plain tooltip: a name in gold and one sentence (a camp building's full bonus). False without a text.
function Read.Text(model, name, text)
	if not text then
		return false
	end
	Clear(model)
	model.kind = "text"
	model.name, model.nameColor = name, GOLD
	Desc(model, Rich(nil, text))
	return true
end

-- Items ------------------------------------------------------------------------------------------------------------

-- durability's colour: red when broken, yellow at a quarter or less, else the footer's quiet value
local function DurabilityColor(current, maximum)
	if current <= 0 then
		return RED
	elseif current <= maximum / 4 then
		return YELLOW
	end
	return nil
end

local function ItemLink(data, id)
	local link = Text(data.hyperlink)
	if not link and Text(data.guid) then
		link = C_Item.GetItemLinkByGUID(data.guid)
	end
	if not link and id then
		link = select(2, C_Item.GetItemInfo(id))
	end
	return link
end

-- The item's stats as rows (GetItemStats: key and value), the name opening its tooltip; kept by key for the
-- comparison. The stat lines of the data are then left out (a stat line starts with its signed number).
local function Stats(model, link)
	local stats = link and C_Item.GetItemStats(link)
	if type(stats) ~= "table" then
		return false
	end
	local any = false
	for key, value in pairs(stats) do
		local name = _G[key] -- luacheck: ignore 113 (B8: the game's own stat names, by the keys it gives)
		if type(name) == "string" and type(value) == "number" then
			model.stats[key] = value
			local row = Row(model, name, format("%+d", value))
			row.stat = key
			row.link = "ordaen:stat:" .. key .. ":" .. value -- hovered: what it gives this character
			any = true
		end
	end
	return any
end

local function StatLine(text)
	return text:find("^[%+%-]%d") ~= nil
end

-- A side tooltip from the game's data for a spell (an item's use effect) or an item (what a recipe makes).
local Fill -- below

-- Reagents as one line («Толстая кожа (6), Цитрин (2)»): rows, the count on the right
local function Reagents(model, text, L)
	local any = false
	for name, count in text:gmatch("%s*([^,]-)%s*%((%d+)%)") do
		if name ~= "" then
			Row(model, name, format(L.COUNT, tonumber(count)))
			any = true
		end
	end
	return any
end

local function Item(model, data, ctx)
	local id = Id(data.id)
	model.id = id
	model.icon = id and C_Item.GetItemIconByID(id) or nil
	local L, numbers = ctx.L, ctx.numbers
	local link = ItemLink(data, id)
	local level = id and select(4, C_Item.GetItemInfo(id))
	if ctx.itemsIlvl and type(level) == "number" and level > 1 then
		Row(model, L.ITEM_LEVEL_ROW, numbers:Format(level)).stat = "ilvl"
		model.stats.ilvl = level
	end
	local hasStats = Stats(model, link)
	local lines = data.lines
	local nested = false -- inside the made item's lines (a recipe): they are its side tooltip
	local recipe, known = false, false -- a recipe (it nests the item it makes); whether you know it
	for i = 1, #lines do
		local line = lines[i]
		local kind = line.type
		local left = Text(line.leftText)
		if nested then
			if kind == LINE.Teaches then
				nested = false
			end
		end
		if nested then -- luacheck: ignore 542
			-- the made item's own lines: drawn in its tooltip beside
		elseif kind == LINE.NestedBlock then
			recipe = true
			local made = Id(line.tooltipID)
			local madeData = made and C_TooltipInfo.GetItemByID(made)
			if madeData then
				Fill(Side(model), madeData, ctx)
			end
			nested = true
		elseif kind == LINE.ItemName then
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
			Part(model.info, left, nil, left and BINDING[left])
		elseif kind == LINE.SellPrice then
			local price = Id(line.price)
			if price and price > 0 then
				Foot(model, SELL_PRICE, GetMoneyString(price, true))
			end
		elseif kind == LINE.Requirement then
			if left then
				local skill, rank = Match(left, ITEM_MIN_SKILL)
				if skill and rank then
					Foot(model, skill, rank, line.usable == false and RED or nil, "prof")
				else
					local level = Match(left, ITEM_MIN_LEVEL)
					if level then -- «Требуется 40-й уровень»: the required level as its label and value
						Foot(model, L.REQ_LEVEL, level, line.usable == false and RED or nil, "req")
					else
						Foot(model, left, nil, line.usable == false and RED or nil, "req")
					end
				end
			end
		elseif kind == LINE.Use then
			-- «Использование:» is a tooltip of its own beside the item: the spell with its cast and cooldown
			local spell = Id(line.spellID)
			local spellData = spell and C_TooltipInfo.GetSpellByID(spell)
			if spellData and Fill(Side(model), spellData, ctx) then
				local sub = model.side[model.side.n]
				if ctx.itemsCooldown and id then
					local start, duration = C_Container.GetItemCooldown(id)
					local left2 = Remaining(start, duration)
					if left2 then
						Foot(sub, L.READY_IN, Duration(left2), YELLOW, "ready")
						model.timer = true
					end
				end
			elseif left then
				Free(model, left, GREEN)
			end
		elseif kind == LINE.Teaches then
			-- a recipe's «Использование: Обучает…»: the made item beside it says it (design items «Recipes»)
			if left and not recipe then
				Free(model, left, ColorOf(line.leftColor))
			end
		elseif (kind == LINE.Equip or kind == LINE.Chance) and left then
			-- «Если на персонаже:», «Возможный эффект при попадании:»: green, opening the real spell once locked
			local spell = Id(line.spellID)
			Free(model, spell and "|Hspell:" .. spell .. "|h" .. left .. "|h" or left, GREEN)
		elseif left and left == ITEM_SPELL_KNOWN then
			known = true
		elseif kind == LINE.SetLine then
			-- the set: named only in its own tooltip beside the item
			local sub = model.setSide
			if not sub or model.side[model.side.n] ~= sub then
				sub = Side(model)
				model.setSide = sub
				sub.kind = "set"
				sub.name = left
				sub.nameColor = GOLD
			else
				Free(sub, left, ColorOf(line.leftColor) or GREY)
			end
		elseif kind == LINE.Blank or not left then -- luacheck: ignore 542
			-- nothing to draw
		elseif left == ITEM_UNIQUE or left == ITEM_UNIQUE_EQUIPPABLE then
			Part(model.desc, left, nil, "uni") -- «Уникальный» joins the description
		else
			-- the columns: damage and speed, damage per second, armor, block, a bag's slots; the footer's lines
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
			local reagents = Match(left, ITEM_REQ_SKILL and nil or SPELL_REAGENTS) -- «Реагенты: …»
			if low and high then
				Cell(model, format(L.COL_DAMAGE, numbers:Format(Number(low) or 0), numbers:Format(Number(high) or 0)),
					nil, "dmg")
				model.stats.dmg = ((Number(low) or 0) + (Number(high) or 0)) / 2
				local speed = Last(Text(line.rightText))
				if speed then
					Cell(model, format(L.COL_SPEED, numbers:Format(speed)), nil, "spd")
					model.stats.spd = speed
				end
			elseif single then
				Cell(model, numbers:Format(Number(single) or 0), nil, "dmg")
			elseif dps then
				Cell(model, format(L.COL_DPS, numbers:Format(Number(dps) or 0)), nil, nil, nil, "dps")
				model.stats.dps = Number(dps)
			elseif armor then
				-- bonus armor: green
				Cell(model, numbers:Format(Number(armor) or 0), ColorOf(line.leftColor), "arm", nil, nil, Number(armor))
				model.stats.arm = Number(armor)
			elseif block then
				Cell(model, numbers:Format(Number(block) or 0), nil, "blk", nil, nil, Number(block))
				model.stats.blk = Number(block)
			elseif slots then
				Cell(model, Read.Plural(L, "COL_SLOTS", slots), nil, nil, nil, "bag", slots)
			elseif current and maximum then
				local c, m = Number(current) or 0, Number(maximum) or 1
				Foot(model, L.DURABILITY, format("%d / %d", c, m), DurabilityColor(c, m), "dur")
			elseif classes then
				Foot(model, L.CLASSES, classes, ColorOf(line.leftColor), "cls")
			elseif reagents and Reagents(model, reagents, L) then -- luacheck: ignore 542
				-- a recipe's reagents: rows
			elseif hasStats and StatLine(left) and not ColorOf(line.leftColor) then -- luacheck: ignore 542
				-- a stat: its row is drawn from GetItemStats
			else
				Free(model, left, ColorOf(line.leftColor))
			end
		end
	end
	if recipe then -- «Изучено» / «Не изучено» joins the description
		Part(model.desc, known and L.KNOWN or L.NOT_KNOWN, known and GREY or nil)
	end
	if id and ctx.itemsId then
		Part(model.info, "ID " .. id)
	end
	if id then
		local stack = C_Item.GetItemMaxStackSizeByID(id)
		local bags = C_Item.GetItemCount(id) or 0
		local total = C_Item.GetItemCount(id, true) or bags
		if ctx.itemsCount and ((stack and stack > 1) or total > 1) then
			if bags > 0 then
				Foot(model, L.IN_BAGS, numbers:Format(bags), nil, "own")
			end
			if total - bags > 0 then
				Foot(model, L.IN_BANK, numbers:Format(total - bags), nil, "own")
			end
		end
		if ctx.itemsStack and stack and stack > 1 then
			Foot(model, L.STACK, numbers:Format(stack), nil, "stack")
		end
	end
	return model.name ~= nil
end

-- Spells and auras -------------------------------------------------------------------------------------------------

-- A spell's reagents (its «Реагенты: Руна телепортации, Порох (2)» line) as requirements, footer rows (design
-- spells «Reagents»): the reagent's name on the left (opening its item once the tooltip locks, when the game knows
-- it), «N шт.» on the right, red when you have fewer. True when the line was the reagents'.
local function SpellReagents(model, text, L)
	local list = Match(text, SPELL_REAGENTS)
	if not list then
		return false
	end
	for part in list:gmatch("[^,]+") do
		local name, count = part:match("^%s*(.-)%s*%((%d+)%)%s*$")
		name = name or part:match("^%s*(.-)%s*$")
		local need = tonumber(count) or 1
		if name ~= "" then
			local have = C_Item.GetItemCount(name) or 0
			local itemID = C_Item.GetItemInfoInstant(name)
			Foot(model, name, format(L.COUNT, need), have < need and RED or nil, nil, nil,
				itemID and "item:" .. itemID or nil)
		end
	end
	return true
end

-- A finishing move's description: its «1 прием: …» list as rows (design spells «combo point»): «1 приём · 46–66»,
-- the value the range the line names; the rest of the text the description. A description without the list: one
-- sentence.
-- a combo line's value: the range it names («46-66», «46 – 66» → «46–66»), else its first number
local function ComboValue(effect)
	local low, high = effect:match("(%d+)%s*%-%s*(%d+)")
	if not low then
		low, high = effect:match("(%d+)%s*–%s*(%d+)")
	end
	if low then
		return low .. "–" .. high
	end
	return effect:match("%d+")
end

local function Description(model, id, text, L)
	if not text then
		return
	end
	if not (text:find("^%s*%d%s") or text:find("\n%s*%d%s")) then -- no combo list: one description
		Desc(model, Rich(id, text))
		return
	end
	local start = model.body.n -- the body before this description: its rows go after the description
	local first, last -- the text before the list (the description)
	for line in text:gmatch("[^\n]+") do
		local points, effect = line:match("^%s*(%d)%s+[^%d:]-:%s*(.+)$")
		local value = effect and ComboValue(effect)
		if points and value then
			Row(model, Read.Plural(L, "COMBO", tonumber(points)), value).term = "combo"
		elseif not first then
			first = line
		else
			last = (last or first) .. "\n" .. line
		end
	end
	if first then
		Desc(model, Rich(id, last or first))
		local body = model.body
		local desc = body[body.n]
		for i = body.n, start + 2, -1 do
			body[i] = body[i - 1]
		end
		body[start + 1] = desc
	end
end

-- What follows a label's colon («Восстановление: 10 сек.» → «10 сек.»), or the text
local function Value(text)
	return text:match("^[^:]+:%s*(.+)$") or text
end

-- The band's cells from a spell's first lines (api/forever/tooltip-data.md «Spell»), in the design's short form: its
-- first line the cost («Ярость: 10» → a dot in the resource's colour and the number) or the range alone, with the
-- range on its right; then the cast («Мгновенно» with its glyph, a cast time, channelled, «Следующая» for the next
-- swing or shot) with the cooldown on its
-- right («Восстановление: 10 сек.» → «CD 10 сек.», the English abbreviation in every locale); a spell with neither
-- cost nor range starts with the cast. A range is its value only, its closing full stop dropped («Радиус действия:
-- 30 м.» → «30 м»). `first`: the spell's first band line; `right`: the line's right side; `cast`: its left side was
-- the cast (the right side is then the cooldown). Returns whether this was a cast.
local function SpellCell(model, text, first, right, L, cost, cast)
	local glyph, tint, term, amount
	local isCast = false
	local number = text:match("%d[%d%s\194\160]*")
	if text == SPELL_CAST_TIME_INSTANT or text == SPELL_CAST_TIME_INSTANT_NO_MANA then
		text, glyph, term, isCast = L.CAST_INSTANT, "castNow", "castNow", true
	elseif text == SPELL_CAST_CHANNELED or text:find(SPELL_CAST_CHANNELED or "\0", 1, true) then
		glyph, term, isCast = "castChan", "castChan", true
	elseif Match(text, SPELL_CAST_TIME_SEC) or Match(text, SPELL_CAST_TIME_MIN) then
		glyph, term, isCast = "castTime", "castTime", true
	elseif text == SPELL_ON_NEXT_SWING or text == SPELL_ON_NEXT_RANGED then
		-- «Следующая атака»: on the next swing or shot, its glyph and the short word
		text, glyph, term, isCast = L.CAST_NEXT, "castNext", "castNext", true
	elseif not right and first and cost and number and tonumber((number:gsub("%D", ""))) == cost.amount then
		glyph, tint, term = "cost", cost.color, cost.term
		text = number:gsub("%s+$", "")
		amount = text
	elseif right and cast then
		if number then
			text, term = "CD " .. Value(text), "cd"
		end
	elseif first then -- the range, on the cost's right or alone
		if text == MELEE_RANGE or text == L.MELEE_RANGE_TEXT then
			-- «Дистанция ближнего боя»: its distance, the full name in its term's tooltip
			text, term = L.MELEE_RANGE_SHORT, "melee"
		else
			text, term = (Value(text):gsub("%.$", "")), "range"
		end
	end
	Cell(model, text, nil, glyph, tint, term, amount)
	return isCast
end

-- a spell's cost (its first power cost): its amount, its resource's colour and term; nil without one. Every resource
-- a cost can be in: health (a green dot: Enum.PowerType.HealthCost, -2), mana, rage, focus, energy; its colour the
-- game's PowerBarColor by name (else by type), health's green. A table per spell, made once.
local POWER = {
	[-2] = { term = "health", color = Rgb(0.1, 0.85, 0.1) },
	[0] = { term = "mana" },
	[1] = { term = "rage" },
	[2] = { term = "focus" },
	[3] = { term = "energy" },
}
local function PowerColor(cost)
	local power = POWER[cost.type]
	if power and power.color then
		return power.color
	end
	local bar = PowerBarColor and (type(cost.name) == "string" and PowerBarColor[cost.name] or PowerBarColor[cost.type])
	return bar and Rgb(bar.r, bar.g, bar.b) or nil
end
local costs = {}
local function CostOf(id)
	local entry = id and costs[id]
	if entry ~= nil then
		return entry or nil
	end
	local list = id and C_Spell.GetSpellPowerCost(id)
	local cost = type(list) == "table" and list[1]
	local power = cost and POWER[cost.type]
	entry = cost and type(cost.cost) == "number" and cost.cost > 0 and {
		amount = cost.cost,
		color = PowerColor(cost),
		term = power and power.term or nil,
	} or false
	if id then
		costs[id] = entry
	end
	return entry or nil
end

local function Spell(model, data, ctx)
	local id = Id(data.id)
	model.id = id
	local L = ctx.L
	model.icon = id and C_Spell.GetSpellTexture(id) or nil
	local cost = CostOf(id)
	local band = 0 -- the band lines read so far
	local lines = data.lines
	for i = 1, #lines do
		local line = lines[i]
		local kind = line.type
		local left, right = Text(line.leftText), Text(line.rightText)
		if kind == LINE.SpellName and not model.name then
			model.name = left
			Part(model.desc, right) -- the rank
			Part(model.desc, id and tabOf[id]) -- its spellbook tab (none outside the spellbook)
		elseif kind == LINE.Requirement then
			if left then
				Foot(model, left, nil, line.usable == false and RED or nil)
			end
		elseif kind == LINE.Description then
			Description(model, id, left, L)
		elseif kind == LINE.Passive then
			Part(model.desc, left)
		elseif kind ~= LINE.Blank and (left or right) then
			-- cost and range, cast and cooldown: Forever's two-sided lines, cells of the band
			if left and not right and SpellReagents(model, left, L) then -- luacheck: ignore 542
				-- «Реагенты: …»: requirements, footer rows
			elseif left and right then
				band = band + 1
				local cast = SpellCell(model, left, band == 1, false, L, cost)
				SpellCell(model, right, band == 1, true, L, cost, cast)
			elseif left and i <= 4 and model.body.n == 0 then
				band = band + 1
				SpellCell(model, left, band == 1, false, L, cost)
			elseif left then
				Free(model, left, ColorOf(line.leftColor))
			end
		end
	end
	if id and ctx.spellsCooldown then
		local cd = C_Spell.GetSpellCooldown(id)
		local left = cd and Remaining(cd.startTime, cd.duration)
		if left then
			Foot(model, L.READY_IN, Duration(left), YELLOW, "ready")
			model.timer = true
		end
	end
	if id and ctx.spellsId then
		Part(model.info, "ID " .. id)
	end
	return model.name ~= nil
end

-- the dispel types' colours, lifted to read on the wood (design auras: Магия blue, Проклятие purple, Яд green,
-- Болезнь brown)
-- the dispel types in their colours (design data.js DISPEL: the game's DebuffTypeColor, lifted to read on the wood)
local DISPEL = {
	Magic = Rgb(0x3c / 255, 0x9c / 255, 1), Curse = Rgb(0xb4 / 255, 0x5c / 255, 1),
	Poison = Rgb(0x2f / 255, 0xbf / 255, 0x3f / 255), Disease = Rgb(0xc8 / 255, 0x90 / 255, 0x40 / 255),
}
local REMOVE_COLOR = Rgb(0x8f / 255, 0xd2 / 255, 1) -- the band's «remove by» cell (design #8fd2ff)

-- the spells that remove an effect of a dispel type, by class (design auras «Remove by your class»): the first known
-- names the band's cell. On an enemy's buff, the offensive dispel.
local REMOVE = {
	MAGE = { Curse = { 475 } },
	DRUID = { Curse = { 2782 }, Poison = { 2893, 8946 } },
	PRIEST = { Magic = { 527, 988 }, Disease = { 552, 528 } },
	PALADIN = { Magic = { 4987 }, Poison = { 4987, 1152 }, Disease = { 4987, 1152 } },
	SHAMAN = { Poison = { 526 }, Disease = { 2870 } },
}
local PURGE = { SHAMAN = { 8012, 370 }, PRIEST = { 988, 527 } }
local function Remover(list)
	for i = 1, list and #list or 0 do
		if IsPlayerSpell(list[i]) then
			return C_Spell.GetSpellName(list[i])
		end
	end
	return nil
end

-- The camp's bonuses (Forever's own effect, design auras «Camp bonuses»): its description's paragraphs after the
-- first, «Name: effect» each, as rows: the building's name on the left (opens the full sentence), the bonus in short
-- on the right (the locales' CAMP_<BUILDING>, matched by CAMP_<BUILDING>_NAME; else the sentence itself).
local BUILDINGS = { "WELL", "AQUA" }
local function CampShort(name, L)
	for i = 1, #BUILDINGS do
		if rawget(L, "CAMP_" .. BUILDINGS[i] .. "_NAME") == name then
			return rawget(L, "CAMP_" .. BUILDINGS[i])
		end
	end
	return nil
end
local CAMP = 1229741
local camp = {} -- the last camp effect's sentences by building (what its row's name opens)
Read.camp = camp
local function CampRows(model, text, L)
	local first = true
	for line in text:gmatch("[^\n]+") do
		if first then
			first = false -- «Получены следующие бонусы лагеря:»
		else
			local name, effect = line:match("^%s*([^:]+):%s*(.+)$")
			if name then
				camp[name] = effect
				local row = Row(model, name, CampShort(name, L) or effect)
				row.link = "ordaen:camp:" .. name
			end
		end
	end
end

-- What an effect over time will still deal or heal (design auras «Total over time»): «N ед. … каждые T сек.» in its
-- description × the ticks left × the stacks; nil when the description doesn't say so.
local function Total(text, left, stacks, L)
	local amount, period = text:match(L.TOTAL_PATTERN or "\0")
	amount, period = tonumber(amount), tonumber(period)
	if not amount or not period or period <= 0 or not left then
		return nil
	end
	local total = amount * math.floor(left / period) * (stacks or 1)
	if total <= 0 then
		return nil
	end
	local heal = L.HEAL_WORD and text:find(L.HEAL_WORD, 1, true)
	return heal and L.TOTAL_HEAL or L.TOTAL_DAMAGE, format(L.TOTAL_VALUE, total, Duration(left))
end

-- the aura on its unit: the owner's (Blizzard's aura buttons know their unit and instance), else the player's own
local function AuraData(owner, id)
	local unit = owner and rawget(owner, "unit")
	local instance = owner and (rawget(owner, "auraInstanceID") or
		(type(rawget(owner, "buttonInfo")) == "table" and owner.buttonInfo.auraInstanceID))
	if type(unit) == "string" and instance then
		return C_UnitAuras.GetAuraDataByAuraInstanceID(unit, instance), unit
	end
	return id and C_UnitAuras.GetPlayerAuraBySpellID(id), "player"
end

local function Aura(model, data, ctx, owner)
	local id = Id(data.id)
	model.id = id
	local L, numbers = ctx.L, ctx.numbers
	model.icon = id and C_Spell.GetSpellTexture(id) or nil
	local aura, unit = AuraData(owner, id)
	local lines = data.lines
	local description
	for i = 1, #lines do
		local line = lines[i]
		local left = Text(line.leftText)
		if i == 1 then
			model.name = left
		elseif left and line.type ~= LINE.Blank and not left:find("^ID ") and not Match(left, SPELL_TIME_REMAINING_MIN)
			and not Match(left, SPELL_TIME_REMAINING_SEC) and not left:find(L.REMAINING_WORD or "\0", 1, true) then
			-- Forever's own spell ID line and the time left go: the band has the time
			if id == CAMP then
				CampRows(model, left, L)
			else
				Desc(model, Rich(id, left))
			end
			description = description or left
		end
	end
	local harmful = aura and aura.isHarmful
	model.nameColor = harmful and RED or GOLD
	if id == CAMP then
		Part(model.desc, L.CAMP, nil, "camp")
	else
		Part(model.desc, harmful and L.AURA_DEBUFF or L.AURA_BUFF)
	end
	local dispel = aura and aura.dispelName
	if type(dispel) == "string" then
		Part(model.desc, _G["STRING_SCHOOL_" .. dispel:upper()] or L["DISPEL_" .. dispel:upper()] or dispel, -- luacheck: ignore 113
			DISPEL[dispel], dispel:lower())
	end
	local source = aura and aura.sourceUnit
	if source == "player" or source == "pet" then
		Part(model.desc, L.AURA_YOURS, GOLD, "mine")
	end
	if aura then
		local stacks = aura.applications
		if type(stacks) == "number" and stacks > 1 then
			Cell(model, "×" .. stacks, nil, nil, nil, "stacks")
		end
		local expires = aura.expirationTime
		if type(expires) == "number" and expires > 0 then
			Cell(model, Duration(max(0, expires - GetTime())), nil, "time")
			model.timer = true
		end
		-- what you can do about it: cancel your own buff, or the spell of your class that removes it
		local _, myClass = UnitClass("player")
		local remover
		if type(dispel) == "string" and harmful then
			remover = Remover(REMOVE[myClass] and REMOVE[myClass][dispel])
		elseif dispel == "Magic" and not harmful and type(unit) == "string" and UnitCanAttack("player", unit) then
			remover = Remover(PURGE[myClass])
		end
		if unit == "player" and not harmful then
			Cell(model, L.CANCEL_KEY, nil, nil, nil, "cancel")
		elseif remover then
			Cell(model, remover, REMOVE_COLOR, nil, nil, "removeBy")
		end
		if ctx.aurasCaster and type(source) == "string" and UnitExists(source) then
			local name = (source == "player") and L.YOU or UnitName(source)
			local _, class = UnitClass(source)
			local color = ctx.classNames and class and RAID_CLASS_COLORS[class]
			local row = Foot(model, L.CASTER, name, color and Rgb(color.r, color.g, color.b) or nil, "caster")
			row.valueLink = source ~= "player" and "unit:" .. source or nil -- hovered: the caster's own tooltip
		end
		if ctx.aurasTotal and description then
			local left = type(expires) == "number" and expires > 0 and expires - GetTime() or nil
			local label, value = Total(description, left, stacks, L)
			if label then
				Foot(model, label, value, nil, "total")
			end
		end
	end
	if id and ctx.aurasId then
		Part(model.info, "ID " .. id)
	end
	return model.name ~= nil
end

-- Units ------------------------------------------------------------------------------------------------------------

local function ClassColor(unit)
	local _, class = UnitClass(unit)
	local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	return color and Rgb(color.r, color.g, color.b) or nil
end

-- a player: title and name, guild · rank, class · status · PvP; level, race, faction; their target and relation
local function Player(model, unit, ctx)
	local L = ctx.L
	local name = UnitName(unit)
	local titled = UnitPVPName(unit)
	local color = ctx.classNames and ClassColor(unit) or WHITE
	if type(titled) == "string" and name and titled ~= name then
		-- the title quieter, the name in its class colour, in the order the locale puts them
		local at = titled:find(name, 1, true)
		if at then
			model.name = "|c" .. Hex(LABEL) .. titled:sub(1, at - 1) .. "|r|c" .. Hex(color) .. name .. "|r|c" ..
				Hex(LABEL) .. titled:sub(at + #name) .. "|r"
		else
			model.name = titled
		end
	else
		model.name = name
	end
	model.nameColor = color
	local guild, rank = GetGuildInfo(unit)
	if guild then
		Part(model.desc, guild, nil, "guild")
		Part(model.desc, rank, nil, "rank")
	end
	Part(model.info, (UnitClass(unit)), nil, "pclass")
	if UnitIsDeadOrGhost(unit) then
		Part(model.info, UnitIsGhost(unit) and L.GHOST or L.CORPSE, nil, "status")
	elseif UnitIsAFK(unit) then
		Part(model.info, L.AFK, nil, "status")
	elseif UnitIsDND(unit) then
		Part(model.info, L.DND, nil, "status")
	end
	if UnitIsPVP(unit) then
		Part(model.info, "PvP", nil, "pvp")
	end
	local level = UnitLevel(unit)
	Cell(model, level and level > 0 and format(L.LEVEL_CELL, level) or "??", nil, nil, nil, "plvl")
	-- the race: hovered, its racial abilities (for this player's class)
	local raceName, _, raceID = UnitRace(unit)
	local _, _, classID = UnitClass(unit)
	local race = Cell(model, raceName)
	race.link = raceID and "ordaen:race:" .. raceID .. ":" .. (classID or 0) .. ":" .. (raceName or "") or nil
	local faction, factionName = UnitFactionGroup(unit)
	if faction then
		Cell(model, factionName or faction, faction == UnitFactionGroup("player") and GREEN or RED,
			faction == "Alliance" and "alliance" or faction == "Horde" and "horde" or nil)
	end
	if ctx.playersTarget then
		local target = unit .. "target"
		if UnitExists(target) then
			local row = Foot(model, L.TARGET, UnitName(target), UnitIsPlayer(target) and ClassColor(target) or nil, "ptarget")
			row.valueLink = "unit:" .. target -- hovered: the target's own tooltip
		end
	end
	if ctx.playersInspect and ctx.inspect then
		-- their spec and gear, by inspecting them (the module's: on demand, cached in memory)
		local entry, status = ctx.inspect(unit)
		if entry then
			if entry.spec then
				Row(model, L.SPEC, entry.spec).term = "pspec"
			end
			if entry.gear then
				Row(model, L.GEAR, tostring(entry.gear)).term = "pgear"
			end
		elseif status then
			Row(model, L.SPEC, L["INSPECT_" .. status:upper()]).term = "pspec"
		end
	end
	if ctx.playersRelation then
		if UnitInRaid(unit) then
			local index = UnitInRaid(unit)
			local group = index and select(3, GetRaidRosterInfo(index))
			if group then
				Foot(model, L.RAID, format(L.RAID_GROUP, group), nil, "relation")
			end
		elseif UnitInParty(unit) and not UnitIsUnit(unit, "player") then
			Foot(model, L.PARTY, L.PARTY_YOURS, nil, "relation")
		end
		if name and C_FriendList.IsFriend(UnitGUID(unit)) then
			local info = C_FriendList.GetFriendInfo(name)
			Foot(model, L.FRIEND, info and info.notes or "", nil, "relation")
		end
		if name and C_FriendList.IsIgnored(name) then
			Foot(model, L.IGNORED, L.IGNORED_YES, RED, "relation")
		end
	end
end

-- the level's colour against yours (the game's rule), «??» far above
local function LevelCell(model, unit, L)
	local level = UnitLevel(unit)
	if not level or level <= 0 then
		Cell(model, "??", RED, nil, nil, "lvlColor")
		return
	end
	local friendly = UnitReaction(unit, "player")
	local color = (friendly or 0) < 5 and GetQuestDifficultyColor and GetQuestDifficultyColor(level)
	Cell(model, format(L.LEVEL_CELL, level), color and Rgb(color.r, color.g, color.b) or nil, nil, nil, "lvlColor")
end

-- Your standing with each faction you've met, by name (the reputation footer row): read again on UPDATE_FACTION.
local standings = {}
function Read.Factions()
	for name in pairs(standings) do
		standings[name] = nil
	end
	for i = 1, C_Reputation.GetNumFactions() or 0 do
		local faction = C_Reputation.GetFactionDataByIndex(i)
		if faction and not faction.isHeader and type(faction.name) == "string" then
			standings[faction.name] = faction.reaction
		end
	end
end
-- a standing's colour (design data.js REP_TONE): hated to hostile red, unfriendly orange, neutral yellow, friendly up
-- green
local STANDING_COLOR = { [1] = RED, [2] = RED, [3] = Rgb(1, 0.5, 0.25), [4] = YELLOW }
local STANDING_FRIENDLY = Rgb(0.25, 0.75, 0.25)

-- The quest lines of a unit's or object's tooltip data (design npcs «Quest objectives»): the quest's name in gold,
-- each objective a row with your counter (green when done), your party's under it, indented (QuestPlayer lines name
-- the member whose objectives follow). `party`: show them.
local QUEST_TITLE, QUEST_OBJECTIVE, QUEST_PLAYER = 17, 8, 18
local function Quests(model, lines, party)
	-- their own section under a rule (design «More»: quest objectives), drawn like the body
	local body = model.body
	model.body = model.more
	local member
	for i = 1, #lines do
		local line = lines[i]
		local text = Text(line.leftText)
		if text and line.type == QUEST_TITLE then
			member = nil
			Free(model, text, GOLD)
		elseif text and line.type == QUEST_PLAYER then
			member = text
		elseif text and line.type == QUEST_OBJECTIVE then
			local have, need = text:match("(%d+)%s*/%s*(%d+)")
			local label = text:gsub("%s*:?%s*%d+%s*/%s*%d+%s*", ""):gsub("^%s*%-%s*", "")
			local done = line.completed == true or have and tonumber(have) >= tonumber(need)
			local value = have and have .. "/" .. need or nil
			if member then
				if party then
					local row = Row(model, member, value, nil, done and GREEN or nil)
					row.indent, row.term = true, "quest"
				end
			else
				Row(model, label, value, nil, done and GREEN or nil).term = "quest"
			end
		end
	end
	model.body = body
end
Read.Quests = Quests

-- an NPC: the name in its reaction colour (grey tapped), its role, creature type and «Труп»; level, elite/rare, faction
local function Npc(model, unit, data, ctx)
	local L = ctx.L
	local reaction = UnitReaction(unit, "player")
	local color = reaction and FACTION_BAR_COLORS and FACTION_BAR_COLORS[reaction]
	if ctx.npcsLoot and UnitIsTapDenied(unit) then
		model.nameColor = GREY
	elseif color then
		model.nameColor = Rgb(color.r, color.g, color.b)
	end
	local level = UnitLevel(unit)
	local lines = data.lines
	local factionName
	for i = 2, #lines do
		local line = lines[i]
		local text = Text(line.leftText)
		if text and line.type ~= LINE.Blank then
			local role = text:match("^<(.+)>$")
			if role then
				Part(model.desc, role)
			elseif line.type == LINE.UnitOwner then
				-- a pet's owner: hovered, their own tooltip
				local owner = type(line.guid) == "string" and UnitTokenFromGUID(line.guid)
				Part(model.desc, text, nil, nil, owner and "unit:" .. owner or nil)
			elseif line.type == QUEST_TITLE or line.type == QUEST_OBJECTIVE or line.type == QUEST_PLAYER then -- luacheck: ignore 542
				-- quest lines: their own rows (Quests)
			elseif text == PVP or text:find("%d") and level and text:find(tostring(level), 1, true) and i <= 3 then -- luacheck: ignore 542
				-- «PvP» and the level line: the band has the level
			elseif i <= 4 and not factionName and UnitFactionGroup(unit) then
				factionName = text
			elseif i <= 4 and model.desc.n == 0 and not text:find("%d") and text ~= UnitCreatureType(unit) then
				Part(model.desc, text)
			elseif text ~= UnitCreatureType(unit) then
				Free(model, text, ColorOf(line.leftColor))
			end
		end
	end
	Part(model.info, UnitCreatureType(unit), nil, "beast")
	if UnitIsDead(unit) then
		Part(model.info, L.CORPSE, nil, "npcDead")
	end
	LevelCell(model, unit, L)
	local class = UnitClassification(unit)
	if class == "elite" or class == "worldboss" or class == "rareelite" then
		Cell(model, L.ELITE, GOLD, "elite")
	end
	if class == "rare" or class == "rareelite" then
		Cell(model, L.RARE, nil, "rare")
	end
	local faction = UnitFactionGroup(unit)
	if faction then
		Cell(model, factionName or faction, faction == UnitFactionGroup("player") and GREEN or RED, nil, nil,
			faction == "Alliance" and "alliance" or faction == "Horde" and "horde" or nil)
	end
	Quests(model, lines, ctx.npcsParty)
	-- the footer: someone else's loot; your reputation with its faction (factions you've met only)
	if ctx.npcsLoot and UnitIsTapDenied(unit) then
		Foot(model, L.TAPPED, "", nil, "tapped")
	end
	local standing = ctx.npcsRep and factionName and standings[factionName]
	if standing then
		Foot(model, factionName, _G["FACTION_STANDING_LABEL" .. standing] or tostring(standing), -- luacheck: ignore 113
			STANDING_COLOR[standing] or STANDING_FRIENDLY, "rep")
	end
end

local function Unit(model, data, ctx)
	local first = data.lines[1]
	local unit = first and first.type == LINE.UnitName and Text(first.unitToken)
	if not unit or not UnitExists(unit) then
		-- a unit gone: what the game wrote
		model.name = first and Text(first.leftText)
		for i = 2, #data.lines do
			Free(model, Text(data.lines[i].leftText), ColorOf(data.lines[i].leftColor))
		end
		return model.name ~= nil
	end
	model.portrait = unit
	model.name = Text(first.leftText)
	if UnitIsPlayer(unit) then
		Player(model, unit, ctx)
	else
		Npc(model, unit, data, ctx)
	end
	return model.name ~= nil
end

-- Objects (signs, nodes, chests): the name in gold, the rest as the game wrote it (a lock red when you can't)
-- An object (design objects/): its name in gold; a chest's lock in the footer, «Взлом замков 75» or «Нужен ключ» with
-- the key (it opens the key's item), red when you can't open it; a quest object's objectives as on NPCs; a sign is its
-- name alone.
local function Object(model, data, ctx)
	local L = ctx.L
	local lines = data.lines
	for i = 1, #lines do
		local line = lines[i]
		local text = Text(line.leftText)
		if i == 1 then
			model.name = text
			model.nameColor = GOLD
		elseif text and line.type ~= LINE.Blank and line.type ~= 17 and line.type ~= 8 and line.type ~= 18 then
			if line.type == LINE.Requirement then
				local skill, rank = Match(text, ITEM_MIN_SKILL)
				local red = line.usable == false and RED or nil
				if skill and rank then -- «Требуется: Взлом замков (75)»
					Foot(model, skill, rank, red, "lock")
				else -- a key: «Требуется Ключ от сундука Дефиаса»
					local key = text:match("^[^:]+:%s*(.+)$") or text:gsub("^%S+%s+", "")
					local itemID = C_Item.GetItemInfoInstant(key)
					local missing = (C_Item.GetItemCount(key) or 0) == 0
					local row = Foot(model, L.KEY_NEEDED, key, (red or missing) and RED or nil, "lock")
					row.valueLink = itemID and "item:" .. itemID or nil
				end
			else
				Free(model, text, ColorOf(line.leftColor))
			end
		end
	end
	Read.Quests(model, lines, ctx.npcsParty)
	return model.name ~= nil
end

-- Comparison -------------------------------------------------------------------------------------------------------

-- An item against the equipped one (design items «Comparison»): each stat row of `target` gets the difference
-- better - worse in brackets, green ▲ when positive, red ▼ when negative, none when equal. With `lacks`, the stats
-- only `worse` has follow as «—» with their loss (the hovered item against the one equipped).
function Read.Compare(target, better, worse, L, numbers, lacks)
	for i = 1, target.body.n do
		local row = target.body[i]
		local key = row.stat
		if key and row.right then
			local diff = (better.stats[key] or 0) - (worse.stats[key] or 0)
			if diff ~= 0 then
				row.right = format("%s |c%s(%s%s)|r", row.right, Hex(diff > 0 and GREEN or RED),
					diff > 0 and "▲" or "▼", numbers:Format(math.abs(diff)))
			end
		end
	end
	if not lacks then
		return
	end
	for key, value in pairs(worse.stats) do
		if better.stats[key] == nil and key:find("^ITEM_MOD_") then
			local name = _G[key] -- luacheck: ignore 113 (B8: the game's own stat names, by the keys it gives)
			Row(target, name or key, format("— |c%s(▼%s)|r", Hex(RED), numbers:Format(value)), GREY)
		end
	end
end

-- Entry ------------------------------------------------------------------------------------------------------------

--- The kind of a tooltip's data ("item", "spell", ...) or nil for one Ordaen Tooltips leaves to Blizzard.
function Read.Kind(data)
	if data and data.plain then -- what the tooltip shows as text (game.Tooltip tip:Lines)
		return "text"
	end
	local t = data and data.type
	return type(t) == "number" and not isSecret(t) and KIND[t] or nil
end

local Talent -- below (it reads a spell with Spell, then its talent parts)

--- Fill `model` from the tooltip data; false when it can't be read (that show stays Blizzard's).
---@param ctx table the module's settings read plainly, `numbers` (game.Numbers), `L` (its locales), `owner` (the
--- frame the tooltip belongs to)
function Fill(model, data, ctx)
	Clear(model)
	local kind = Read.Kind(data)
	local lines = data and data.lines
	if not kind or type(lines) ~= "table" or isSecret(lines) then
		return false
	end
	model.kind = kind
	local owner = ctx.owner
	if kind == "spell" and owner and type(owner.GetNodeID) == "function" then -- a talent's button
		return Talent(model, data, ctx, owner)
	elseif kind == "item" then
		return Item(model, data, ctx)
	elseif kind == "spell" then
		return Spell(model, data, ctx)
	elseif kind == "aura" then
		return Aura(model, data, ctx, ctx.owner)
	elseif kind == "unit" then
		return Unit(model, data, ctx)
	elseif kind == "text" then
		return Read.Plain(model, data, ctx)
	end
	return Object(model, data, ctx)
end
Read.Fill = Fill

-- Text ---------------------------------------------------------------------------------------------------------------

-- a binding at the end of a title, as Blizzard appends it (MicroButtonTooltipText, the backpack): « |cffffd200(C)|r»
local BOUND = "^(.-)%s*|c%x%x%x%x%x%x%x%x%(([^()]+)%)|r$"

-- a line's colour as ours draws it: white and the game's normal gold are the body's own (nil), others kept
local function Tint(color)
	local c = ColorOf(color)
	return c ~= GOLD and c or nil
end

--- A tooltip that is only text (design tooltips/text: a micro menu or bag button, any addon's SetText and AddLine):
--- its first line the title, the rest the body (a line with a right text a row, else a sentence), the title's binding
--- in the hotkeys («C: открыть»). No icon.
function Read.Plain(model, data, ctx)
	local lines = data.lines
	local first = lines[1]
	local title = first and first.leftText
	if not title then
		return false
	end
	local name, key = title:match(BOUND)
	if name and name ~= "" then
		title = name
		Push(model.keys).text = format(ctx.L.KEY_OPEN, key)
	end
	model.name = title
	model.nameColor = ColorOf(first.leftColor) or WHITE
	for i = 2, #lines do
		local line = lines[i]
		local left, right = line.leftText, line.rightText
		if left and right then
			Row(model, left, right, Tint(line.leftColor), Tint(line.rightColor))
		elseif left or right then
			local color = Tint(line.leftColor)
			if color then
				Free(model, left or right, color)
			else
				Desc(model, left or right)
			end
		end
	end
	return true
end

-- Talents -----------------------------------------------------------------------------------------------------------

-- the words of `next` that differ from `current` at the same place, lit green (design spells «The next rank diffs»: a
-- word diff; ranks of one talent differ in their numbers, word for word; a next rank is an improvement). A lit word
-- drops its own colour codes (the rich text's white numbers), or they would hide the green.
local LIT = "|cff40ff60"
local function Plain(word)
	return (word:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end
local function Diff(current, next)
	local words, n = {}, 0
	for word in current:gmatch("%S+") do
		n = n + 1
		words[n] = word
	end
	local out, i = {}, 0
	for word in next:gmatch("%S+") do
		i = i + 1
		out[i] = word == words[i] and word or LIT .. Plain(word) .. "|r"
	end
	return table.concat(out, " ")
end

-- A talent (the talent window's button owns the tooltip; design spells «Talents»): the spell as on skills (its band,
-- its description), «Талант · 2/5 · Оружие» on the second line; the next rank with what changes lit (the «Следующий уровень»
-- setting); an unlearned talent's requirements in the footer, red when not met. The talent frame writes the name and
-- rank lines itself: the data starts at the cost (api/forever/tooltip-data.md «Talent»), so the name is the spell's.
-- Forever's trait API has one tree per class and no tree names: the classic tab comes from the client data.
function Talent(model, data, ctx, owner)
	local L = ctx.L
	local configID = C_ClassTalents.GetActiveConfigID()
	local nodeID = owner:GetNodeID()
	local node = configID and nodeID and C_Traits.GetNodeInfo(configID, nodeID)
	local spellID = owner.GetSpellID and owner:GetSpellID() or Id(data.id)
	if not node or not spellID then
		return false
	end
	model.name = C_Spell.GetSpellName(spellID)
	if not Spell(model, data, ctx) then
		return false
	end
	model.icon = C_Spell.GetSpellTexture(spellID) or model.icon
	-- the second line: «Талант · 2/5» (the spell's own «Пассивная» and rank lines give way)
	model.desc.n = 0
	local rank, max = node.currentRank or 0, node.maxRanks or 1
	Part(model.desc, L.TALENT, nil, "talent")
	Part(model.desc, rank .. "/" .. max, rank >= max and GREEN or nil, "talent")
	-- its tree, as the classic talent window names it (talents.lua: spell -> tab, from the client data)
	local trees = Read.talents
	local tab = trees and trees.tab[spellID]
	local names = tab and trees.name[tab]
	Part(model.desc, names and (names[GetLocale()] or names.enUS) or nil)
	local entryID = owner.GetEntryID and owner:GetEntryID()
		or node.activeEntry and node.activeEntry.entryID or node.entryIDs and node.entryIDs[1]
	if ctx.spellsNext and entryID and rank > 0 and rank < max then
		local current = C_Traits.GetTraitDescription(entryID, rank)
		local next = C_Traits.GetTraitDescription(entryID, rank + 1)
		if type(current) == "string" and type(next) == "string" and next ~= "" then
			-- its own section under a rule (design «More»: the next rank), drawn like the body
			local body = model.body
			model.body = model.more
			Free(model, L.NEXT_RANK, GREY)
			Desc(model, Diff(Rich(nil, current), Rich(nil, next)))
			model.body = body
		end
	end
	if rank == 0 then
		-- what it still needs: each condition's points, red while not met
		local conditions = node.conditionIDs
		for i = 1, conditions and #conditions or 0 do
			local info = C_Traits.GetConditionInfo(configID, conditions[i])
			local points = info and info.spentAmountRequired
			if type(points) == "number" and points > 0 then
				Foot(model, L.TALENT_POINTS, tostring(points), info.isMet == false and RED or nil, "talent")
			end
		end
		if node.isAvailable == false or node.meetsEdgeRequirements == false then
			Foot(model, L.TALENT_LOCKED, nil, RED, "talent")
		end
	end
	return true
end

Read.WHITE = WHITE

return Read
