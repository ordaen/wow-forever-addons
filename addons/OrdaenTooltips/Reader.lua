-- Ordaen Tooltips, reading: what a native tooltip (GameTooltip & co.) shows, as plain data our view draws. The
-- native tooltip stays the owner of its content: Blizzard and every other addon keep filling it as they always do
-- (SetOwner, AddLine, SetBagItem...); we only read its lines after it is shown.
--
-- Safe by refusal: in combat some values are secret (issecretvalue) and some frames are forbidden. Any of that,
-- and Read returns false: the caller leaves that tooltip native for this show. Reading never changes the tooltip.
--
-- Cost: one model per native tooltip, rows reused; text comes from the tooltip's own font strings (no new strings),
-- colours go into reused tables. A money line (sell price) needs one string from GetMoneyString per show.
local _, ns = ...

local Reader = {}
ns.Reader = Reader

Reader.MAX_ROWS = 40

-- Absent before the client had secret values; then nothing is secret.
local isSecret = issecretvalue or function()
	return false
end

---@class OrdaenTooltipsRow
---@field left string
---@field right string
---@field leftColor number[]|false false = the style's colour (white text)
---@field rightColor number[]|false
---@field blank boolean an empty line (a gap other addons put between their sections)
---@field colors number[][] two reused colour tables (left, right)

---@class OrdaenTooltipsModel
---@field count integer rows in use
---@field rows OrdaenTooltipsRow[]
---@field bar number|false the status bar's fill 0..1 (unit health), false when none is shown
---@field barColor number[]
---@field fingerprint string|nil the first line, to notice a change without reading everything
---@field kind number|false the tooltip data's type (Enum.TooltipDataType: Item, Spell, Unit, ...), false when unknown
---@field id number|false the item, spell, ... id in the tooltip data
---@field gameLines integer lines the game wrote (from the tooltip data); rows after them are other addons'
---@field priceRow integer|false the row holding the sell price

--- A new, empty model (one per native tooltip, made once).
---@return OrdaenTooltipsModel
function Reader.NewModel()
	local rows = {}
	for i = 1, Reader.MAX_ROWS do
		rows[i] = { left = "", right = "", leftColor = false, rightColor = false, blank = false, colors = { {}, {} } }
	end
	return {
		count = 0, rows = rows, bar = false, barColor = { 0, 1, 0 }, fingerprint = nil,
		kind = false, id = false, gameLines = 0, priceRow = false,
	}
end

--- Whether we may touch `frame` now: not forbidden, not protected in combat, nothing about it secret.
function Reader.CanModify(frame)
	if frame == nil or isSecret(frame) then
		return false
	end
	if frame.IsForbidden and frame:IsForbidden() then
		return false
	end
	return true
end

-- Near white is the style's own colour (body text); anything else is meaning (quality, red requirements, green
-- "Use:" lines) and is kept.
local function isWhite(r, g, b)
	return r > 0.95 and g > 0.95 and b > 0.95
end

-- Text and colour of one font string into row fields. Returns false on a secret.
local function readFont(fs, row, side)
	if not fs or not fs:IsShown() then
		row[side] = ""
		row[side .. "Color"] = false
		return true
	end
	local text = fs:GetText()
	if isSecret(text) then
		return false
	end
	row[side] = text or ""
	local r, g, b = fs:GetTextColor()
	if isSecret(r) or isSecret(g) or isSecret(b) then
		return false
	end
	if r and not isWhite(r, g, b) then
		local color = row.colors[side == "left" and 1 or 2]
		color[1], color[2], color[3] = r, g, b
		row[side .. "Color"] = color
	else
		row[side .. "Color"] = false
	end
	return true
end

--- The last tooltip data the game gave per kind (Enum.TooltipDataType value -> its table), for the dev dump's probe
--- of what Forever's tooltip lines carry (types, arguments: the base for tooltips inside tooltips, 2026-11-07).
Reader.lastData = {}
Reader.lastItems = {} -- the last PROBE_ITEMS item ids, newest first
local PROBE_ITEMS = 6

--- Whether a probe key ("item<id>") is one of the last items.
---@param key string
---@return boolean
function Reader.IsRecentItem(key)
	for _, id in ipairs(Reader.lastItems) do
		if key == "item" .. id then
			return true
		end
	end
	return false
end

local function safeNumber(value)
	return type(value) == "number" and not isSecret(value) and value or false
end

-- What the tooltip shows, from its data (the game's own description of it): its kind and id, how many lines are
-- the game's (the rest were added by other addons), and the sell price, which a money frame draws instead of a
-- line's text: it becomes the right side of its row.
local function readData(tooltip, model)
	model.kind, model.id, model.gameLines, model.priceRow = false, false, model.count, false
	if not tooltip.GetTooltipData then
		return
	end
	local data = tooltip:GetTooltipData()
	if isSecret(data) or type(data) ~= "table" then
		return
	end
	model.kind, model.id = safeNumber(data.type), safeNumber(data.id)
	if model.kind then
		-- The game's own table, kept for the dev dump's probe (no copy); items: the last few different ones.
		local key = model.kind
		if model.kind == 0 and model.id then
			local seen = Reader.lastItems
			if seen[1] ~= model.id then
				for i = #seen, 1, -1 do
					if seen[i] == model.id then
						table.remove(seen, i)
					end
				end
				table.insert(seen, 1, model.id)
				seen[PROBE_ITEMS + 1] = nil
			end
			key = "item" .. model.id
			for k in pairs(Reader.lastData) do
				if type(k) == "string" and not Reader.IsRecentItem(k) then
					Reader.lastData[k] = nil
				end
			end
		end
		Reader.lastData[key] = data
	end
	local lines = data.lines
	if isSecret(lines) or type(lines) ~= "table" then
		return
	end
	model.gameLines = math.min(#lines, model.count)
	for i, line in ipairs(lines) do
		local price = type(line) == "table" and safeNumber(line.price)
		local row = model.rows[i]
		if price and price > 0 and row and i <= model.count and GetMoneyString then
			row.right = GetMoneyString(price)
			-- The label only: on Forever the game's line also writes the coins into its text ("Sell Price: 10c"),
			-- which showed the price twice (2026-11-07).
			row.left = SELL_PRICE or row.left
			row.blank = false
			model.priceRow = i
		end
	end
end

local function readBar(tooltip, model)
	local bar = tooltip == GameTooltip and GameTooltipStatusBar or nil
	model.bar = false
	if not (bar and bar:IsShown()) then
		return true
	end
	local value = bar:GetValue()
	local low, high = bar:GetMinMaxValues()
	local r, g, b = bar:GetStatusBarColor()
	if isSecret(value) or isSecret(low) or isSecret(high) or isSecret(r) then
		return true -- the bar is unknown in combat: draw the rest without it
	end
	if high and low and high > low then
		model.bar = (value - low) / (high - low)
		model.barColor[1], model.barColor[2], model.barColor[3] = r, g, b
	end
	return true
end

--- Read `tooltip` into `model`. False when it can't be read safely (the caller keeps it native).
---@param tooltip GameTooltip
---@param model OrdaenTooltipsModel
---@return boolean
function Reader.Read(tooltip, model)
	if not Reader.CanModify(tooltip) then
		return false
	end
	local n = tooltip:NumLines()
	if isSecret(n) or type(n) ~= "number" then
		return false
	end
	n = math.min(n, Reader.MAX_ROWS)
	for i = 1, n do
		local row = model.rows[i]
		if not readFont(tooltip:GetLeftLine(i), row, "left") or not readFont(tooltip:GetRightLine(i), row, "right") then
			return false
		end
		row.blank = row.left == "" and row.right == ""
	end
	model.count = n
	model.fingerprint = n > 0 and model.rows[1].left or nil
	readData(tooltip, model)
	return readBar(tooltip, model)
end

--- Whether `tooltip` shows something else than `model` holds (a cheap check: line count and first line).
---@return boolean
function Reader.Changed(tooltip, model)
	if not Reader.CanModify(tooltip) then
		return false
	end
	local n = tooltip:NumLines()
	if isSecret(n) then
		return false
	end
	if math.min(n, Reader.MAX_ROWS) ~= model.count then
		return true
	end
	local first = n > 0 and tooltip:GetLeftLine(1)
	local text = first and first:GetText()
	return not isSecret(text) and (text or nil) ~= model.fingerprint
end
