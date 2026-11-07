-- Ordaen Core: the palette, one set of colours every Ordaen addon uses (chat, panel, meter, ...). Eleven named
-- colours, each in two tones: `bar` for fills (white text sits on it) and `text` for text on dark backgrounds. Each
-- class shows in one of them. Players pick every tone and each class's colour in Ordaen Core's settings; the
-- defaults are the theme's (themes.jsonc, made by art/palette.py). Blizzard's RAID_CLASS_COLORS stays untouched; our
-- addons just don't read it.
--
--   local Colors = OrdaenCore.Colors
--   bar.color = Colors:Get("blue")                -- { r, g, b } (also .r .g .b), one table per colour, kept
--   name:SetTextColor(Colors:ClassText("MAGE"):GetRGB())
--   Colors:On("change", onColors)                 -- a tone or a class's colour changed (or the theme): redraw
--
-- The tables are made once and updated in place, so an addon can keep them (in a UI spec, say); nothing is made
-- per call. Cost: a change refreshes 22 tables and tells the listeners; reading is a table lookup.
local _, ns = ...

---@class OrdaenCoreAPI
local Core = ns.Core

--- The palette's colour names, in the settings page's order.
local NAMES = { "red", "orange", "yellow", "green", "cyan", "blue", "violet", "pink", "tan", "white", "grey" }
--- WoW Forever's classes (class files, as UnitClass gives them).
local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }

---@class OrdaenColor
---@field [1] number
---@field [2] number
---@field [3] number
---@field r number
---@field g number
---@field b number
---@field hex string "ffRRGGBB"
local Color = {}
local ColorMeta = { __index = Color }

--- r, g, b (for SetTextColor, SetVertexColor, SetStatusBarColor).
---@return number, number, number
function Color:GetRGB()
	return self.r, self.g, self.b
end

local byte -- below

--- "ffRRGGBB", for |c...|r in chat text (made on first use after a change, then kept).
---@return string
function Color:Hex()
	local hex = self.hex
	if not hex then
		hex = string.format("ff%02x%02x%02x", byte(self.r), byte(self.g), byte(self.b))
		self.hex = hex
	end
	return hex
end

local function newColor()
	return setmetatable({ 1, 1, 1, r = 1, g = 1, b = 1, hex = "ffffffff" }, ColorMeta)
end

function byte(v)
	return math.floor(math.max(0, math.min(1, v)) * 255 + 0.5)
end

local function assign(color, value)
	if type(value) ~= "table" then
		return
	end
	local r, g, b = value[1], value[2], value[3]
	color[1], color[2], color[3] = r, g, b
	color.r, color.g, color.b = r, g, b
	color.hex = nil -- Hex() makes it when asked: a picker drag changes a colour many times a second
end

---@class OrdaenColors
---@field package bar table<string, OrdaenColor> palette name -> its bar tone (internal: use :Get)
---@field package text table<string, OrdaenColor> palette name -> its text tone (internal: use :Text)
---@field package classOf table<string, string> class file -> palette name (internal: use :ClassName)
---@field package listeners function[]
local Colors = {}
local ColorsMeta = { __index = Colors }

local colors = setmetatable({ bar = {}, text = {}, classOf = {}, listeners = {} }, ColorsMeta)
for _, name in ipairs(NAMES) do
	colors.bar[name] = newColor()
	colors.text[name] = newColor()
end

--- A palette colour's bar tone (fills; white text on it), or nil for an unknown name.
---@param name string "red" ... "grey"
---@return OrdaenColor|nil
function Colors:Get(name)
	return self.bar[name]
end

--- A palette colour's text tone (text on dark backgrounds), or nil for an unknown name.
---@param name string
---@return OrdaenColor|nil
function Colors:Text(name)
	return self.text[name]
end

--- The palette colour a class shows in ("yellow" for ROGUE by default), or nil for a class Forever doesn't have.
---@param classFile string as UnitClass's second result ("MAGE")
---@return string|nil
function Colors:ClassName(classFile)
	return self.classOf[classFile]
end

--- A class's bar tone (its palette colour's), or nil.
---@param classFile string
---@return OrdaenColor|nil
function Colors:Class(classFile)
	local name = self.classOf[classFile]
	return name and self.bar[name]
end

--- A class's text tone (its palette colour's), or nil.
---@param classFile string
---@return OrdaenColor|nil
function Colors:ClassText(classFile)
	local name = self.classOf[classFile]
	return name and self.text[name]
end

--- The palette's colour names, in order (a shared list: don't change it).
---@return string[]
function Colors:Names()
	return NAMES
end

--- Hear of changes: "change" (a tone or a class's colour, or the theme). `fn()` runs after the tables changed.
---@param event "change"
---@param fn function
function Colors:On(event, fn)
	assert(event == "change", "OrdaenCore.Colors has one event: change")
	local list = self.listeners
	for i = 1, #list do
		if list[i] == fn then
			return
		end
	end
	list[#list + 1] = fn
end

---@param event "change"
---@param fn function
function Colors:Off(event, fn)
	assert(event == "change", "OrdaenCore.Colors has one event: change")
	local list = self.listeners
	for i = #list, 1, -1 do
		if list[i] == fn then
			table.remove(list, i)
		end
	end
end

local function tell(self)
	local list = self.listeners
	for i = 1, #list do
		Core._call(list[i])
	end
end

-- A setting key -> what it holds: { tones, name } for "palette.<name>" / "palette.<name>Text", { "class", file } for
-- "class.<CLASS>", false for anything else. Parsed once per key: a colour picker writes several times a second.
local parsed = {}

local function parse(self, key)
	local entry = parsed[key]
	if entry == nil then
		entry = false
		if key:find("^palette%.") then
			local rest = key:sub(9)
			if rest:sub(-4) == "Text" and self.text[rest:sub(1, -5)] then
				entry = { self.text, rest:sub(1, -5) }
			elseif self.bar[rest] then
				entry = { self.bar, rest }
			end
		elseif key:find("^class%.") then
			entry = { "class", key:sub(7) }
		end
		parsed[key] = entry
	end
	return entry
end

--- One of Ordaen Core's settings changed (CoreSettings.lua): update just what it holds, a tone or a class's colour,
--- and tell the listeners. Cheap: a picker being dragged calls it several times a second.
---@param key string
---@param get fun(key: string): any the settings' reader (A:Get of Ordaen Core)
function Colors:_Changed(key, get)
	local entry = parse(self, key)
	if not entry then
		return
	end
	if entry[1] == "class" then
		local name = get(key)
		self.classOf[entry[2]] = self.bar[name] and name or nil
	else
		assign(entry[1][entry[2]], get(key))
	end
	tell(self)
end

--- Read the whole palette from Ordaen Core's settings (CoreSettings.lua: at load and on a theme switch) and tell
--- the listeners.
---@param get fun(key: string): any the settings' reader (A:Get of Ordaen Core)
function Colors:_Refresh(get)
	for _, name in ipairs(NAMES) do
		assign(self.bar[name], get("palette." .. name))
		assign(self.text[name], get("palette." .. name .. "Text"))
	end
	for _, classFile in ipairs(CLASSES) do
		local name = get("class." .. classFile)
		self.classOf[classFile] = self.bar[name] and name or nil
	end
	tell(self)
end

ns.Colors = colors
Core.Colors = colors
