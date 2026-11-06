-- Ordaen Core: settings values. An addon's settings are declared in its settings.jsonc; the build turns that into
-- ns.SETTINGS_SCHEMA (docs/reference/settings.md). This file keeps the values: the SavedVariables table holds only
-- what the player changed, and every other read falls back to the current theme's default. Look settings default
-- to a theme token (`theme = "frame.border"`): their default is whatever the theme says (THEME_TOKENS, from
-- OrdaenCore/themes.jsonc), so addons never define their look.
--
--   db.borderStyle            -- the player's value, else the theme's default (one table lookup, no garbage)
--   store:Set("scale", 1.2)   -- validated against the schema, then announced
--   store:Reset("scale")      -- the theme's default again
--   Store.SetTheme("minimal") -- every untouched setting follows; changes are announced
--
-- How: the saved table and each nested table in it get a metatable whose __index is the matching table of
-- defaults[theme]. WoW saves only raw fields, so defaults never reach the SavedVariables file. A theme switch
-- points every __index at the new theme's defaults. Nested tables exist raw (empty if the player changed nothing
-- in them), so code that writes `db.buttonAngles.drawer = 90` writes the player's table, never the defaults.
local _, ns = ...

---@class OrdaenCoreAPI
local Core = ns.Core

local Store = {}
Core._SettingsStore = Store -- internal: addons use A:Get / A:Set (Addon.lua)

---@class OrdaenSettingsStore
---@field schema table ns.SETTINGS_SCHEMA of the addon
---@field db table the SavedVariables table (account)
---@field charDb table|nil per character, when the schema names one
---@field metas table[] { meta, scope, path } per raw table, to point at another theme
---@field onChange fun(key: string, value: any)|nil told after a value changed (a Set, a Reset, a theme switch)
local StoreMethods = {}
local StoreMeta = { __index = StoreMethods }

local stores = {} -- every bound store, for theme switches
local theme = "ordaen"
local tokens = { assets = {}, tokens = {}, themes = {} } -- THEME_TOKENS (Store.SetTokens)

-- Paths ------------------------------------------------------------------------------------------

-- "a.b.c" -> { "a", "b", "c" }; cached per key (keys are fixed strings from the schema).
local pathCache = {}
local function pathOf(key)
	local path = pathCache[key]
	if not path then
		path = {}
		for part in key:gmatch("[^.]+") do
			path[#path + 1] = part
		end
		pathCache[key] = path
	end
	return path
end

local function walk(root, path, last)
	local t = root
	for i = 1, last do
		if type(t) ~= "table" then
			return nil
		end
		t = t[path[i]]
	end
	return t
end

-- Validation ---------------------------------------------------------------------------------------

local function isColor(v)
	return type(v) == "table" and type(v[1]) == "number" and type(v[2]) == "number" and type(v[3]) == "number"
end

--- Whether `value` is valid for `setting` (a schema entry). Pure.
function Store.Valid(setting, value)
	local kind = setting.type
	if kind == "boolean" then
		return type(value) == "boolean"
	elseif kind == "number" then
		if type(value) ~= "number" or value ~= value then
			return false
		end
		if (setting.min and value < setting.min) or (setting.max and value > setting.max) then
			return false
		end
		return setting.step ~= 1 or value == math.floor(value)
	elseif kind == "choice" then
		for _, id in ipairs(setting.choices) do
			if id == value then
				return true
			end
		end
		return false
	elseif kind == "asset" then
		local kindAssets = tokens.assets[setting.of]
		return type(value) == "string" and kindAssets ~= nil and kindAssets[value] ~= nil
	elseif kind == "sound" then
		return type(value) == "string" -- a SOUNDKIT name, or "" for silent
	elseif kind == "color" then
		return isColor(value)
	elseif kind == "text" or kind == "keybinding" then
		return type(value) == "string" and (not setting.maxLength or #value <= setting.maxLength)
	elseif kind == "map" then
		if type(value) ~= "table" then
			return false
		end
		for k, v in pairs(value) do
			if type(k) ~= "string" or type(v) ~= setting.of then
				return false
			end
		end
		return true
	end
	return false -- action: no value
end

-- Binding ----------------------------------------------------------------------------------------

-- The default of one setting in theme `name`: its theme token's value there, else its plain default.
local function defaultOf(setting, name)
	if setting.theme then
		local values = tokens.themes[name] or tokens.themes.ordaen
		return values and values[setting.theme]
	end
	return setting.default
end

-- The defaults of a schema in theme `name`, nested like the saved table, for one scope; made once per schema,
-- theme and scope (at login and on a theme switch), then reused.
local function themeDefaults(schema, name, scope)
	local cache = schema._defaults
	if not cache then
		cache = {}
		schema._defaults = cache
	end
	local cacheKey = name .. "/" .. scope
	local out = cache[cacheKey]
	if out then
		return out
	end
	out = {}
	for key, setting in pairs(schema.settings) do
		if setting.type ~= "action" and (setting.scope or "account") == scope then
			local path = pathOf(key)
			local t = out
			for i = 1, #path - 1 do
				t[path[i]] = t[path[i]] or {}
				t = t[path[i]]
			end
			local value = defaultOf(setting, name)
			if setting.type == "map" and type(value) == "table" then
				local copy = {}
				for k, v in pairs(value) do
					copy[k] = v
				end
				value = copy
			end
			t[path[#path]] = value
		end
	end
	cache[cacheKey] = out
	return out
end

--- The shared part of every theme (ns.THEME_TOKENS, generated from OrdaenCore/themes.jsonc). Core sets it at
--- load; specs set their own.
function Store.SetTokens(themeTokens)
	tokens = themeTokens
end

--- A theme token's value in the current theme (e.g. "color.accent").
function Store.Token(name)
	local values = tokens.themes[theme] or tokens.themes.ordaen
	return values and values[name]
end

--- An asset by kind and id (e.g. "frame", "bronze-rim"): its data from the theme manifest, or nil.
function Store.Asset(kind, id)
	local kindAssets = tokens.assets[kind]
	return kindAssets and kindAssets[id]
end

-- Make `raw` (a saved table, or a nested table in it) fall back to `defaults`, and the nested tables the defaults
-- have, recursively. Map settings are leaves: their raw table falls back to the (usually empty) default map.
local function bindTable(store, raw, defaults, scope, path)
	local meta = { __index = defaults }
	setmetatable(raw, meta)
	store.metas[#store.metas + 1] = { meta = meta, scope = scope, path = path }
	for key, value in pairs(defaults) do
		if type(value) == "table" and not isColor(value) then
			local child = rawget(raw, key)
			if type(child) ~= "table" then
				child = {}
				rawset(raw, key, child)
			end
			local childPath = {}
			for i = 1, #path do
				childPath[i] = path[i]
			end
			childPath[#childPath + 1] = key
			bindTable(store, child, value, scope, childPath)
		end
	end
end

local function rootFor(store, setting)
	return setting.scope == "character" and store.charDb or store.db
end

-- Remove saved values the schema refuses (wrong type, unknown choice, out of range): the default applies.
local function clean(store)
	for key, setting in pairs(store.schema.settings) do
		if setting.type ~= "action" and setting.type ~= "map" then
			local path = pathOf(key)
			local parent = walk(rootFor(store, setting), path, #path - 1)
			local leaf = path[#path]
			if type(parent) == "table" then
				local value = rawget(parent, leaf)
				if value ~= nil and not Store.Valid(setting, value) then
					rawset(parent, leaf, nil)
				end
			end
		elseif setting.type == "map" then
			local path = pathOf(key)
			local map = walk(rootFor(store, setting), path, #path)
			if type(map) == "table" then
				for k, v in pairs(map) do
					if type(k) ~= "string" or type(v) ~= setting.of then
						map[k] = nil
					end
				end
			end
		end
	end
end

--- Bind an addon's SavedVariables to its schema: invalid saved values go, every read falls back to the current
--- theme's default. Call after migrations ran on the raw tables.
---@param schema table ns.SETTINGS_SCHEMA
---@param db table account SavedVariables (created by the caller when nil)
---@param charDb table|nil per-character SavedVariables
---@return OrdaenSettingsStore
function Store.Bind(schema, db, charDb)
	local store = setmetatable({ schema = schema, db = db, charDb = charDb, metas = {} }, StoreMeta)
	bindTable(store, db, themeDefaults(schema, theme, "account"), "account", {})
	if charDb then
		bindTable(store, charDb, themeDefaults(schema, theme, "character"), "character", {})
	end
	clean(store)
	stores[#stores + 1] = store
	return store
end

-- Reading and writing ------------------------------------------------------------------------------

--- The value of a (dotted) setting: the player's, else the theme's default.
---@param key string
function StoreMethods:Get(key)
	local setting = self.schema.settings[key]
	local path = pathOf(key)
	return walk(setting and rootFor(self, setting) or self.db, path, #path)
end

--- Whether the player chose this setting's value (it is saved), rather than the theme's default.
---@param key string
---@return boolean
function StoreMethods:IsChanged(key)
	local setting = self.schema.settings[key]
	local path = pathOf(key)
	local parent = walk(setting and rootFor(self, setting) or self.db, path, #path - 1)
	return type(parent) == "table" and rawget(parent, path[#path]) ~= nil
end

-- Values compare by value: a colour default is a different table in each theme, the same colour or not.
local function same(a, b)
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	for k, v in pairs(a) do
		if b[k] ~= v then
			return false
		end
	end
	for k in pairs(b) do
		if a[k] == nil then
			return false
		end
	end
	return true
end

local function announce(store, key, value)
	if store.onChange then
		store.onChange(key, value)
	end
end

--- Save the player's value for a setting, if the schema accepts it; tells onChange. Returns whether it was saved.
---@param key string
---@param value any
---@return boolean
function StoreMethods:Set(key, value)
	local setting = self.schema.settings[key]
	if not setting or not Store.Valid(setting, value) then
		return false
	end
	local path = pathOf(key)
	local parent = walk(rootFor(self, setting), path, #path - 1)
	if type(parent) ~= "table" then
		return false
	end
	local before = parent[path[#path]]
	rawset(parent, path[#path], value)
	if not same(before, value) then
		announce(self, key, value)
	end
	return true
end

--- Forget the player's value: the theme's default applies again. Tells onChange if the value changed.
---@param key string
function StoreMethods:Reset(key)
	local setting = self.schema.settings[key]
	if not setting then
		return
	end
	local path = pathOf(key)
	local parent = walk(rootFor(self, setting), path, #path - 1)
	if type(parent) ~= "table" then
		return
	end
	local before = parent[path[#path]]
	if setting.type == "map" then
		local map = rawget(parent, path[#path])
		if type(map) == "table" then
			for k in pairs(map) do
				map[k] = nil
			end
		end
	else
		rawset(parent, path[#path], nil)
	end
	local after = parent[path[#path]]
	if before ~= after or setting.type == "map" then
		announce(self, key, after)
	end
end

--- Forget every value the player chose (`/<slash> reset`). Keeps `_schema` (the migration count).
function StoreMethods:ResetAll()
	for key in pairs(self.schema.settings) do
		self:Reset(key)
	end
end

-- Themes -----------------------------------------------------------------------------------------

local function pointAt(store, name)
	local account = themeDefaults(store.schema, name, "account")
	local character = themeDefaults(store.schema, name, "character")
	for _, m in ipairs(store.metas) do
		m.meta.__index = walk(m.scope == "character" and character or account, m.path, #m.path)
	end
end

--- The theme whose defaults apply (Ordaen Core's ui.theme).
---@return string
function Store.Theme()
	return theme
end

--- Switch every bound addon to another theme's defaults. Each setting the player didn't change and whose
--- default differs is announced through its store's onChange. Rare (a settings change): may create tables.
---@param name string ordaen, blizzard or minimal
function Store.SetTheme(name)
	if name == theme then
		return
	end
	local changes = {}
	for i, store in ipairs(stores) do
		local before = {}
		for key, setting in pairs(store.schema.settings) do
			if setting.type ~= "action" and not store:IsChanged(key) then
				before[key] = store:Get(key)
			end
		end
		changes[i] = before
	end
	theme = name
	for i, store in ipairs(stores) do
		pointAt(store, name)
		for key, old in pairs(changes[i]) do
			local new = store:Get(key)
			if not same(new, old) then
				announce(store, key, new)
			end
		end
	end
end

--- For specs: forget every store and go back to the default theme.
function Store._Clear()
	stores = {}
	theme = "ordaen"
end
