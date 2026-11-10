-- Themes (design settings/, «Темы»): a theme is a preset of the look's values (fonts, accent, bar textures,
-- animations, the palette and class colours); every module draws with the active one. The presets are themes.jsonc's
-- (the build writes them as ns.THEMES). Three ship; a built-in theme stores only what the player changed, so a new
-- Ordaen version's preset reaches values they didn't touch, and «Сбросить» clears them. The player's own themes are
-- copies, at most MAX_OWN, each keeping every value it was copied with. All of it is account-wide in OrdaenCoreDB.
--   game.Themes:List()     built-ins first, then own (tracked: a copy or delete re-runs what lists them)
--   game.Themes:Get(id)    a theme, or nil
--   game.Themes:Active()   the theme every module draws with (game.Settings.theme; «Использовать» sets it)
--   theme.id, theme.builtin, theme:Name() (tracked)
--   theme.values.<key>     a stored value with the setting API (Get/Set/Reset/Label/Tip/Choices/ChoiceLabel), so the
--                          settings window edits it through its draft
--   theme:Copy() / theme:Rename(text) / theme:Delete() / theme:ResetAll()   applied at once (actions, not drafted)
-- The active theme's values are written into the backend's tokens (ns.Theme) once per flush that changed them, then
-- Stage.ThemeChanged fires and the backend redraws what's live.
local _, ns = ...

local State, Globals = ns.State, ns.Globals
local pairs, ipairs, setmetatable, type, tostring = pairs, ipairs, setmetatable, type, tostring
local format = string.format

---@class OrdaenThemes
local Themes = {}
ns.Themes = Themes

local MAX_OWN = 10 -- own themes: «Копировать» greys out at this many
local MAX_NAME = 24 -- a theme's name, in characters
local BUILTIN = { "ordaen", "blizzard", "minimal" }

local data -- ns.THEMES: { assets, values, themes }
local byId = {} -- id -> theme
local list = {} -- the themes in order
local listed -- a value signal bumped when the list changes (tracked by List); made at Load

---@class OrdaenTheme
---@field id string
---@field builtin boolean
---@field values table<string, OrdaenStoredValue>
local Theme = {}
local ThemeMeta = { __index = Theme }

-- the label key of a value: THEME_ + its key upper-cased, dots as underscores (THEME_PALETTE_RED)
local function LabelOf(key)
	return "THEME_" .. key:gsub("%.", "_"):upper()
end

-- One spec per value and default: a choice's members are its asset kind's ids, in menu order.
local function SpecFor(key, default)
	local kind = data.values[key]
	local spec = { default = default, label = LabelOf(key) }
	if kind == "color" or kind == "boolean" or kind == "number" then
		spec.type = kind
	else
		local choices = {}
		for id in pairs(data.assets[kind]) do
			choices[id] = id
		end
		spec.type, spec.choices, spec.order = "choice", choices, data.order.assets[kind]
		spec.choiceLabel = "THEME_" .. kind:upper()
	end
	return spec
end

-- the store's own table of themes: { own = { { id, name, values } } } (made on the first copy)
local function Db()
	return Globals.store.db
end

local function NewTheme(id, builtin, preset, record)
	local theme = setmetatable({ id = id, builtin = builtin, record = record, specs = {} }, ThemeMeta)
	theme.name = ns.NewValue(record and record.name or id)
	local path = "theme." .. id
	theme.values = setmetatable({}, {
		__index = function(t, key)
			if data.values[key] == nil then
				return nil
			end
			local value = State.Stored(Globals.store, path, key, SpecFor(key, preset[key]))
			t[key] = value
			return value
		end,
	})
	return theme
end

local function Add(theme)
	list[#list + 1] = theme
	byId[theme.id] = theme
end

--- Load the themes: the presets and the player's own (at Ordaen's ADDON_LOADED, after the global settings).
function Themes.Load()
	data = ns.THEMES
	listed = ns.NewValue(0)
	for _, id in ipairs(BUILTIN) do
		if data.themes[id] then
			Add(NewTheme(id, true, data.themes[id]))
		end
	end
	local own = Db().themes
	for _, record in ipairs(own and own.own or {}) do
		Add(NewTheme(record.id, false, record.values, record))
	end
end

--- The themes, built-ins first.
---@return OrdaenTheme[]
function Themes:List() -- luacheck: ignore 212
	listed:Get()
	return list
end

---@param id string
---@return OrdaenTheme|nil
function Themes:Get(id) -- luacheck: ignore 212
	listed:Get()
	return byId[id]
end

--- The theme every module draws with: game.Settings.theme's, or Ordaen's when that one is gone.
---@return OrdaenTheme
function Themes:Active() -- luacheck: ignore 212
	listed:Get()
	return byId[Globals.Get("theme"):Get()] or byId.ordaen
end

--- Its name: the theme's own for a player's theme, its locale label for a built-in one (THEME_NAME_ORDAEN).
function Theme:Name()
	return self.name:Get()
end

--- A copy of this theme's values as the player's own theme, or nil at MAX_OWN.
---@return OrdaenTheme|nil
function Theme:Copy()
	local db = Db()
	db.themes = db.themes or {}
	db.themes.own = db.themes.own or {}
	local own = db.themes.own
	if #own >= MAX_OWN then
		return nil
	end
	local n, id = 1, nil
	repeat
		id = "own" .. n
		n = n + 1
	until not byId[id]
	local values = {}
	for key in pairs(data.values) do
		local value = self.values[key]:Peek()
		values[key] = type(value) == "table" and { value[1], value[2], value[3] } or value
	end
	local record = { id = id, name = Themes.CleanName(self.name:Peek() .. " *", #own + 1), values = values }
	own[#own + 1] = record
	local theme = NewTheme(id, false, values, record)
	Add(theme)
	listed:Set(listed:Peek() + 1)
	return theme
end

--- A theme's name as the player typed it: trimmed, at most MAX_NAME characters, never empty («Тема N»).
---@param text string
---@param n integer the theme's number, for the fallback name
function Themes.CleanName(text, n)
	text = tostring(text or ""):match("^%s*(.-)%s*$")
	if #text == 0 then
		return format(ns.L.THEME_UNNAMED, n)
	end
	-- characters, not bytes: Russian takes two bytes a letter
	local count, cut = 0, #text
	for i = 1, #text do
		local byte = text:byte(i)
		if byte < 0x80 or byte >= 0xC0 then
			count = count + 1
			if count > MAX_NAME then
				cut = i - 1
				break
			end
		end
	end
	return text:sub(1, cut)
end

--- Rename a player's theme.
---@param text string
function Theme:Rename(text)
	if self.builtin then
		return
	end
	local name = Themes.CleanName(text, 1)
	self.record.name = name
	self.name:Set(name)
end

--- Delete a player's theme (the active one: Ordaen's becomes active).
function Theme:Delete()
	if self.builtin then
		return
	end
	local own = Db().themes.own
	for i = #own, 1, -1 do
		if own[i] == self.record then
			table.remove(own, i)
		end
	end
	Db()["theme." .. self.id] = nil -- its changes
	for i = #list, 1, -1 do
		if list[i] == self then
			table.remove(list, i)
		end
	end
	byId[self.id] = nil
	local active = Globals.Get("theme")
	if active:Peek() == self.id then
		active:Reset()
	end
	listed:Set(listed:Peek() + 1)
end

--- Every value back to the preset (a built-in theme's «Сбросить»).
function Theme:ResetAll()
	for key in pairs(data.values) do
		self.values[key]:Reset()
	end
end

-- Applying ---------------------------------------------------------------------------------------------------------

-- The active theme's values into the backend's tokens (ns.Theme): fonts as files, the accent, the palette and the
-- bar textures. Runs as a watch: it re-runs when the active theme or any of its values changes.
local tokens = {}

local FontFile -- below; game.Themes.FontFile(id, bold): a font asset's file (a theme's preview draws in it)
function Themes.FontFile(id, bold)
	return FontFile(id, bold)
end

function FontFile(id, bold)
	local font = data.assets.font[id]
	if not font then
		return nil
	end
	if font.standard then
		return STANDARD_TEXT_FONT
	end
	return bold and font.bold or font.file
end

local function Color(value)
	return { value[1], value[2], value[3], 1 }
end

local function Apply()
	local theme = Themes:Active()
	local v = theme.values
	local Theme = ns.Theme
	Theme["font.body"] = FontFile(v.font:Get())
	Theme["font.bodyBold"] = FontFile(v.font:Get(), true)
	Theme["font.header"] = FontFile(v.fontHeader:Get(), true)
	Theme["font.numbers"] = FontFile(v.fontNumbers:Get())
	Theme["color.accent"] = Color(v.accent:Get())
	Theme["bar.texture"] = data.assets.bar[v.barTexture:Get()].file
	Theme["bar.xpFill"] = v.xpFill:Get()
	Theme["bar.frame"] = v.barFrame:Get()
	Theme["motion.anim"] = v.anim:Get()
	Theme["text.classNames"] = v.classNames:Get()
	for _, c in ipairs(data.order.assets.paletteColor) do
		Theme["color.palette." .. c] = Color(v["palette." .. c]:Get())
		Theme["color.palette." .. c .. "Text"] = Color(v["palette." .. c .. "Text"]:Get())
	end
	for key in pairs(data.values) do
		local class = key:match("^class%.(.+)$")
		if class then
			tokens[class] = v[key]:Get()
		end
	end
	ns.Stage.ThemeChanged:Fire()
end

--- A class's colour in the active theme: the palette's text tone for it (e.g. for a name), or its bar tone.
---@param class string "WARRIOR"
---@param bar boolean|nil the bar tone
---@return table|nil { r, g, b, a }
function Themes.ClassColor(class, bar)
	local c = tokens[class]
	return c and ns.Theme["color.palette." .. c .. (bar and "" or "Text")]
end

--- Start applying the active theme (once, at Ordaen's ADDON_LOADED, after Load).
function Themes.Start()
	ns.Engine.Effect(Apply)
end
