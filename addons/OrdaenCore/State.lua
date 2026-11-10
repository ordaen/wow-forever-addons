-- State (design: development/framework/state): a component's persistent and ephemeral values, each a value signal
-- with :Get/:Set (lists and maps by index or key). Persistent values live in the module's SavedVariables
-- (<Module>DB, or <Module>CharDB for scope = "character") under the component's path; a value equal to its
-- default isn't stored, and a component's table is made on its first write. Ephemeral values live with the instance.
local _, ns = ...

local Tracking = ns.Tracking
local Track, Notify = Tracking.Track, Tracking.Notify
local type, pairs, next, error, tremove, tinsert = type, pairs, next, error, table.remove, table.insert

---@class OrdaenState
local State = {}
ns.State = State

local EMPTY = {}

-- Per-key reads. A list's or map's whole-container readers (Len, Ipairs, Pairs) track the container itself; a read of
-- one index or key tracks that entry's own source, so a write re-runs only what read that entry (and the whole-
-- container readers). Entry sources are made on a tracked read and held weakly: one no observer holds is collected,
-- so keys nobody reads cost nothing.
local WEAK_VALUES = { __mode = "v" }

local function EntrySource(self, key)
	local entries = self.entries
	if not entries then
		entries = setmetatable({}, WEAK_VALUES)
		self.entries = entries
	end
	local source = entries[key]
	if not source then
		source = {}
		entries[key] = source
	end
	return source
end

-- Mark what read `key` (if anything did).
local function NotifyEntry(self, key)
	local entries = self.entries
	local source = entries and entries[key]
	if source then
		Notify(source)
	end
end

-- Mark what read any entry: a change that moves or drops them all.
local function NotifyEntries(self, from)
	local entries = self.entries
	if entries then
		for key, source in pairs(entries) do
			if not from or (type(key) == "number" and key >= from) then
				Notify(source)
			end
		end
	end
end

local function Read(self)
	local t = self.root[self.path]
	return t and t[self.name]
end

local function TableFor(self)
	local root, path = self.root, self.path
	local t = root[path]
	if not t then
		t = {}
		root[path] = t
	end
	return t
end

-- Plain values: boolean, number, string, choice ------------------------------------------------------------------

-- Whether two values of a setting are the same: a colour by its components (a new table each time it's picked)
local function Same(a, b)
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	return a[1] == b[1] and a[2] == b[2] and a[3] == b[3]
end
State.Same = Same

-- What a value follows: another stored value (a global setting), or a theme value (`follows = Define.Theme.xpFill`:
-- the active theme's, so a change of theme reaches it too)
local function Followed(spec)
	local follows = spec.follows
	if follows and ns.IsThemeRef(follows) then
		return ns.Themes:Active().values[follows.path]
	end
	return follows
end

-- An asset kind's ids (themes.jsonc: xpFill, font, bar...), as a choice's members
local function AssetIds(kind)
	return ns.THEMES and ns.THEMES.assets[kind]
end

-- Whether `value` is one the setting can take (its type, range, choices, a macro condition the game parses)
local function Valid(spec, value)
	local kind = spec.type
	local ok
	if kind == "color" then -- { r, g, b } from 0 to 1
		ok = type(value) == "table"
		for i = 1, 3 do
			local c = ok and value[i]
			ok = ok and type(c) == "number" and c >= 0 and c <= 1
		end
	elseif kind == "asset" then -- one of its kind's ids
		local assets = AssetIds(spec.kind)
		ok = type(value) == "string" and assets ~= nil and assets[value] ~= nil
	elseif kind == "choice" then
		ok = false
		for _, member in pairs(spec.choices) do
			if member == value then
				ok = true
				break
			end
		end
		-- a choice listed but not built yet (`soon`, design: shown «в разработке», never picked)
		local soon = spec.soon
		if ok and soon then
			for i = 1, #soon do
				if soon[i] == value then
					ok = false
				end
			end
		end
	elseif kind == "number" then
		ok = type(value) == "number" and (not spec.min or value >= spec.min) and (not spec.max or value <= spec.max)
	elseif kind == "string" then
		ok = type(value) == "string" and (not spec.maxLength or #value <= spec.maxLength)
		-- a macro condition (a visibility rule, "[combat] hide; show"): the game's parser takes it
		if ok and spec.macro then
			ok = pcall(SecureCmdOptionParse, value)
		end
	else
		ok = type(value) == kind
	end
	return ok
end

local function Check(spec, value, name)
	if not Valid(spec, value) then
		error("Ordaen: " .. name .. " can't be " .. tostring(value) .. " (" .. spec.type .. ")", 3)
	end
end

-- A plain stored value; as a setting, what a control reads and writes (design: development/framework/state,
-- «Controls»): `spec` is its declaration (type, default, min/max/step, choices, unit, follows). A value that
-- `follows` a global setting (spec.follows, another stored value) stores nothing while it follows, and reads as the
-- global's value then.
---@class OrdaenStoredValue
---@field spec table its declaration
local Plain = {}
local PlainMeta = { __index = Plain }

function Plain:Get()
	if Tracking.observer then
		Track(self)
	end
	local value = Read(self)
	if value == nil then
		local follows = Followed(self.spec)
		if follows then
			return follows:Get() -- tracked too: a change of the global (or the theme) reaches what reads this
		end
		return self.spec.default
	end
	return value
end

function Plain:Peek()
	local value = Read(self)
	if value == nil then
		local follows = Followed(self.spec)
		if follows then
			return follows:Peek()
		end
		return self.spec.default
	end
	return value
end

--- Whether it follows its global setting now (stores nothing). False for a value that follows none.
function Plain:Follows()
	return self.spec.follows ~= nil and Read(self) == nil
end

--- Follow the global setting again: the stored value goes.
function Plain:Follow()
	if not self.spec.follows or Read(self) == nil then
		return
	end
	self.root[self.path][self.name] = nil
	Notify(self)
end

function Plain:Set(value)
	local spec = self.spec
	Check(spec, value, self.name)
	local stored = Read(self)
	if spec.follows then
		-- a value of its own, even one equal to the global's: following is chosen with Follow
		if Same(value, stored) then
			return
		end
		TableFor(self)[self.name] = value
		Notify(self)
		return
	end
	if Same(value, self:Peek()) then
		return
	end
	if Same(value, spec.default) then
		local t = self.root[self.path]
		if t then
			t[self.name] = nil
		end
	else
		TableFor(self)[self.name] = value
	end
	Notify(self)
end

--- Back to the default; for a value that follows a global, back to following it.
function Plain:Reset()
	if self.spec.follows then
		return self:Follow()
	end
	self:Set(self.spec.default)
end

-- Lists ----------------------------------------------------------------------------------------------------------

---@class OrdaenStoredList
local List = {}
local ListMeta = { __index = List }

function List:Get(index)
	if Tracking.observer then
		Track(EntrySource(self, index))
	end
	local list = Read(self)
	return list and list[index]
end

--- The entry at `index`, not recorded.
function List:Peek(index)
	local list = Read(self)
	return list and list[index]
end

--- Replace the entry at `index` (1 to Len()); nil is refused (Remove takes an entry out).
function List:Set(index, value)
	Check(self.spec.of, value, self.name)
	local list = Read(self)
	if not list or list[index] == nil then
		error("Ordaen: " .. self.name .. " has no entry " .. tostring(index) .. " to set (Insert adds one)", 2)
	end
	if list[index] == value then
		return
	end
	list[index] = value
	NotifyEntry(self, index)
	Notify(self)
end

function List:Len()
	if Tracking.observer then
		Track(self)
	end
	local list = Read(self)
	return list and #list or 0
end

function List:Ipairs()
	if Tracking.observer then
		Track(self)
	end
	return ipairs(Read(self) or EMPTY)
end

--- Append; past `cap` the oldest goes.
function List:Insert(value)
	Check(self.spec.of, value, self.name)
	local t = TableFor(self)
	local list = t[self.name]
	if not list then
		list = {}
		t[self.name] = list
	end
	tinsert(list, value)
	if #list > self.spec.cap then
		tremove(list, 1)
		NotifyEntries(self) -- every entry moved down one
	else
		NotifyEntry(self, #list)
	end
	Notify(self)
end

function List:Remove(index)
	local list = Read(self)
	if list and list[index] ~= nil then
		tremove(list, index)
		NotifyEntries(self, index) -- this entry and every one after it moved
		Notify(self)
	end
end

function List:Reset()
	local t = self.root[self.path]
	if t and t[self.name] then
		t[self.name] = nil
		NotifyEntries(self)
		Notify(self)
	end
end

-- Maps -----------------------------------------------------------------------------------------------------------

---@class OrdaenStoredMap
local Map = {}
local MapMeta = { __index = Map }

function Map:Get(key)
	if Tracking.observer then
		Track(EntrySource(self, key))
	end
	local map = Read(self)
	return map and map[key]
end

--- The entry at `key`, not recorded.
function Map:Peek(key)
	local map = Read(self)
	return map and map[key]
end

function Map:Pairs()
	if Tracking.observer then
		Track(self)
	end
	return next, Read(self) or EMPTY, nil
end

--- Set one entry; past `cap`, an entry other than this one goes (MVP: not the oldest, any).
function Map:Set(key, value)
	if value == nil then
		return self:Remove(key)
	end
	Check(self.spec.of, value, self.name)
	local t = TableFor(self)
	local map = t[self.name]
	if not map then
		map = {}
		t[self.name] = map
		self.count = 0
	end
	local old = map[key]
	if old == value then
		return
	end
	map[key] = value
	if old == nil then
		local count = self.count
		if not count then
			count = 0
			for _ in pairs(map) do
				count = count + 1
			end
		else
			count = count + 1
		end
		if count > self.spec.cap then
			local evict = next(map)
			if evict == key then
				evict = next(map, evict)
			end
			map[evict] = nil
			NotifyEntry(self, evict)
			count = count - 1
		end
		self.count = count
	end
	NotifyEntry(self, key)
	Notify(self)
end

function Map:Remove(key)
	local map = Read(self)
	if map and map[key] ~= nil then
		map[key] = nil
		if self.count then
			self.count = self.count - 1
		end
		NotifyEntry(self, key)
		Notify(self)
	end
end

function Map:Reset()
	local t = self.root[self.path]
	if t and t[self.name] then
		t[self.name] = nil
		self.count = 0
		NotifyEntries(self)
		Notify(self)
	end
end

-- Labels -------------------------------------------------------------------------------------------------------

-- A setting's texts by the locale-key convention the build checks (B15): module.lua's own `<PREFIX>_<NAME>`
-- (PANEL_HEIGHT), a component's `<COMPONENT>_<NAME>` (SELLJUNK_ON), a global's `GLOBAL_<NAME>` (GLOBAL_NUMBERFORMAT,
-- in the settings window's locales: the window shows them), each name upper-cased as it is; its tip `<label>_TIP`, a choice
-- member's `<label>_<VALUE>`. Keys are made once per value; a missing text reads as its key.
local SETTINGS_WINDOW = "OrdaenSettings"

local function LabelKey(self)
	local key = self.labelKey
	if not key then
		local module = self.module
		if self.spec.label then -- named by its declaration (a theme's value: THEME_PALETTE_RED)
			key = self.spec.label
		elseif self.path == "global" and module.name == "OrdaenCore" then
			key = "GLOBAL_" .. self.name:upper()
		elseif self.path == "module" then
			key = module.name:gsub("^Ordaen", ""):upper() .. "_" .. self.name:upper()
		else
			key = self.path:gsub("#.*$", ""):upper() .. "_" .. self.name:upper()
		end
		self.labelKey = key
	end
	return key
end

local function Text(self, key, shared)
	local module = self.module
	-- Ordaen's own (globals, themes) and the assets' names: the window that shows them has the texts
	if shared or module.name == "OrdaenCore" then
		module = ns.App.Module(SETTINGS_WINDOW)
	end
	local locales = module and module.ns and module.ns.locales
	return locales and locales[key] or key
end

--- The setting's label, for its row.
function Plain:Label()
	return Text(self, LabelKey(self))
end

--- The setting's tip, for its row's tooltip.
function Plain:Tip()
	local key = self.tipKey
	if not key then
		key = LabelKey(self) .. "_TIP"
		self.tipKey = key
	end
	return Text(self, key)
end

--- A choice member's label (`value` one of the setting's choices).
function Plain:ChoiceLabel(value)
	local keys = self.choiceKeys
	if not keys then
		keys = {}
		self.choiceKeys = keys
	end
	local key = keys[value]
	if not key then
		-- a choice named by its declaration's kind (THEME_FONT_FIRASANS: a font once, whichever role picks it)
		local spec = self.spec
		local prefix = spec.choiceLabel or (spec.type == "asset" and "THEME_" .. spec.kind:upper()) or LabelKey(self)
		key = prefix .. "_" .. tostring(value):upper()
		keys[value] = key
	end
	return Text(self, key, self.spec.type == "asset")
end

--- A choice's values in the order its enum declares them (`spec.order`: the build writes it from the enum's literal
--- table, which pairs() can't give back), for a menu.
---@return string[]
--- Whether `value` can be set (a control checks text before setting it: a wrong macro condition keeps the last
--- valid one).
function Plain:Valid(value)
	return Valid(self.spec, value) and true or false
end

function Plain:Choices()
	local spec = self.spec
	if spec.type == "asset" then -- its kind's ids, in themes.jsonc's order
		return ns.THEMES.order.assets[spec.kind]
	end
	return spec.order
end

--- Whether a choice is listed but not built yet (its declaration's `soon`): shown in development, never picked.
function Plain:Soon(value)
	local soon = self.spec.soon
	if soon then
		for i = 1, #soon do
			if soon[i] == value then
				return true
			end
		end
	end
	return false
end

--- A string's longest length (its declaration's maxLength), for its input field; nil when it has none.
---@return integer?
function Plain:MaxLength()
	return self.spec.maxLength
end

List.Label, List.Tip = Plain.Label, Plain.Tip -- a list setting (Chips) has a row too

-- Drafts ---------------------------------------------------------------------------------------------------------

-- The settings window's unsaved changes (design settings/, «Сохранить»): a draft stages writes to settings until its
-- Save, which applies them (nothing shows before), and its Rollback undoes the last Save. A control gets a view of a setting (`draft:Of(setting)`, `draft.Settings.<name>`) with the setting's own API,
-- so it neither knows nor can bypass the draft: Get is the staged value or the stored one, Set stages (the stored
-- value again unstages). The draft holds only the staged entries, keyed by the stored value.

---@class OrdaenDraft
---@field changed OrdaenValueSignal number: how many settings are staged (Save is off at 0)
---@field saved OrdaenValueSignal boolean: whether there's a last Save to roll back
---@field Settings table<string, OrdaenDraftView> the global settings through the draft
local Draft = {}
local DraftMeta = { __index = Draft }

---@class OrdaenDraftView
---@field spec table the setting's declaration
---@field name string
local View = {}
local ViewMeta = { __index = View }

--- A new draft, empty.
---@return OrdaenDraft
function State.NewDraft()
	local draft = setmetatable({
		staged = {}, views = {}, nStaged = 0, changed = ns.NewValue(0),
		before = {}, saved = ns.NewValue(false), -- what the last Save replaced: setting -> its value, or FOLLOWED
	}, DraftMeta)
	draft.Settings = setmetatable({}, {
		__index = function(t, name)
			local view = draft:Of(ns.Globals.Get(name))
			t[name] = view
			return view
		end,
	})
	return draft
end

--- `setting` through the draft (one view per setting).
---@param setting OrdaenStoredValue
---@return OrdaenDraftView
function Draft:Of(setting)
	local view = self.views[setting]
	if not view then
		view = setmetatable({ draft = self, setting = setting, spec = setting.spec, name = setting.name }, ViewMeta)
		self.views[setting] = view
	end
	return view
end

local function Stage(draft, setting, value)
	if Same(value, setting:Peek()) then
		value = nil -- the stored value: nothing to save
	end
	local staged = draft.staged
	local was = staged[setting]
	if Same(was, value) then
		return
	end
	staged[setting] = value
	draft.nStaged = draft.nStaged + (value ~= nil and 1 or 0) - (was ~= nil and 1 or 0)
	draft.changed:Set(draft.nStaged)
	Notify(draft)
end

local FOLLOWED = {} -- in `before`: the setting followed its global

--- Write every staged value to its setting (what they replace kept for Rollback), then empty the draft.
function Draft:Save()
	if self.nStaged == 0 then
		return
	end
	local staged, before = self.staged, self.before
	for setting in pairs(before) do
		before[setting] = nil
	end
	for setting, value in pairs(staged) do
		before[setting] = setting:Follows() and FOLLOWED or setting:Peek()
		setting:Set(value)
		staged[setting] = nil
	end
	self.nStaged = 0
	self.changed:Set(0)
	self.saved:Set(true)
	Notify(self)
end

--- Undo the last Save: its settings back to what they were (following their global again where they did); what's
--- staged is dropped.
function Draft:Rollback()
	local before = self.before
	for setting, value in pairs(before) do
		if value == FOLLOWED then
			setting:Follow()
		else
			setting:Set(value)
		end
		before[setting] = nil
	end
	self.saved:Set(false)
	self:Discard()
end

--- Drop every staged value.
function Draft:Discard()
	local staged = self.staged
	for setting in pairs(staged) do
		staged[setting] = nil
	end
	self.nStaged = 0
	self.changed:Set(0)
	Notify(self)
end

function View:Get()
	local draft = self.draft
	if Tracking.observer then
		Track(draft)
	end
	local value = draft.staged[self.setting]
	if value == nil then
		return self.setting:Get()
	end
	return value
end

function View:Peek()
	local value = self.draft.staged[self.setting]
	if value == nil then
		return self.setting:Peek()
	end
	return value
end

--- Stage `value` (checked as the setting checks it); the stored value again unstages.
function View:Set(value)
	Check(self.spec, value, self.name)
	Stage(self.draft, self.setting, value)
end

--- Stage the default.
function View:Reset()
	Stage(self.draft, self.setting, self.spec.default)
end

--- Whether it's staged (changed and not saved).
function View:Staged()
	return self.draft.staged[self.setting] ~= nil
end

function View:Label()
	return self.setting:Label()
end

function View:Tip()
	return self.setting:Tip()
end

function View:ChoiceLabel(value)
	return self.setting:ChoiceLabel(value)
end

function View:Valid(value)
	return self.setting:Valid(value)
end

function View:Choices()
	return self.setting:Choices()
end

function View:Soon(value)
	return self.setting:Soon(value)
end

function View:MaxLength()
	return self.setting:MaxLength()
end

-- Records --------------------------------------------------------------------------------------------------------

-- One record per key (`type = "records"`, `key = { type = "choice", choices = ... }`, `fields = { name = spec, ... }`:
-- design development/framework/state): each entry's field is a stored value of its own, made once and cached (the
-- path "<path>/<name>/<key>"), so a control binds one bar's setting and it stages, resets and stores only what differs
-- from its field's default like any other. Every key has its record by construction: no entry is ever missing.
---@class OrdaenStoredRecords
local Records = {}
local RecordsMeta = { __index = Records }

--- The entry `key`'s field `field`: a stored value with the setting API (label <PREFIX>_<NAME>_<FIELD>).
function Records:Field(key, field)
	local fields = self.fields
	if not fields then
		fields = {}
		self.fields = fields
	end
	local byKey = fields[key]
	if not byKey then
		if not Valid(self.spec.key, key) then
			error("Ordaen: " .. self.name .. " has no entry " .. tostring(key), 2)
		end
		byKey = {}
		fields[key] = byKey
	end
	local value = byKey[field]
	if not value then
		local base = self.spec.fields[field]
		if not base then
			error("Ordaen: " .. self.name .. " has no field " .. tostring(field), 2)
		end
		-- its spec: the field's, labelled after the records' own label and the field's name (made once)
		local specs = self.specs
		if not specs then
			specs = {}
			self.specs = specs
		end
		local spec = specs[field]
		if not spec then
			spec = { label = LabelKey(self) .. "_" .. field:upper() }
			for k, v in pairs(base) do
				spec[k] = v
			end
			spec.scope = self.spec.scope
			specs[field] = spec
		end
		value = State.Stored(self.module, self.path .. "/" .. self.name .. "/" .. tostring(key), field, spec)
		byKey[field] = value
	end
	return value
end

--- Every entry back to its fields' defaults.
function Records:Reset()
	for _, byKey in pairs(self.fields or EMPTY) do
		for _, value in pairs(byKey) do
			value:Reset()
		end
	end
	local root, prefix = self.root, self.path .. "/" .. self.name .. "/"
	for path in pairs(root) do
		if type(path) == "string" and path:sub(1, #prefix) == prefix then
			root[path] = nil
		end
	end
end

-- Declaring ------------------------------------------------------------------------------------------------------

local METAS = {
	boolean = PlainMeta, number = PlainMeta, string = PlainMeta, choice = PlainMeta, color = PlainMeta,
	asset = PlainMeta,
	list = ListMeta, map = MapMeta, records = RecordsMeta,
}

-- One stored value per module, component path and name, made on first use: what a mounted instance declares and what
-- a settings page binds (`Define.Signal(SellJunk.state.on)`) are the same object, so a write through either reaches
-- every reader.
function State.Stored(module, path, name, spec)
	local byPath = module.stored
	if not byPath then
		byPath = {}
		module.stored = byPath
	end
	local values = byPath[path]
	if not values then
		values = {}
		byPath[path] = values
	end
	local value = values[name]
	if not value then
		local root = spec.scope == "character" and module.charDb or module.db
		value = setmetatable({ root = root, path = path, name = name, spec = spec, module = module }, METAS[spec.type])
		values[name] = value
	end
	return value
end

--- A component's persistent value by its declaration, without mounting it (`Comp.state.on`): from the declaration
--- the build lifted onto the component (`persistent`); nil for a name it doesn't declare.
---@param declaration table
---@param name string
function State.OfDeclaration(declaration, name)
	local spec = declaration.persistent and declaration.persistent[name]
	local module = declaration.module
	if not spec or not module then
		return nil
	end
	if not module.db then
		error("Ordaen: " .. declaration.name .. "." .. name .. " read before its module loaded its settings", 3)
	end
	return State.Stored(module, declaration.name, name, spec)
end

--- Every setting of `module` back to its default (or to following its global): `/ordaen <module> reset`. Its other
--- persistent values (gold per character, say) stay. Every component file is imported first, so a setting of a
--- component not drawn yet is reset too; returns how many settings there are.
---@param module table
---@return integer
function State.ResetSettings(module)
	local count = 0
	for path, export in pairs(module.ns) do
		if type(export) == "function" or type(export) == "table" then
			if path == "module" or path:match("^components/") then
				local ok, declaration = pcall(module.Import, module, path)
				local persistent = ok and type(declaration) == "table" and declaration.persistent
				if persistent then
					for name, spec in pairs(persistent) do
						if spec.setting then
							State.OfDeclaration(declaration, name):Reset()
							count = count + 1
						end
					end
				end
			end
		end
	end
	return count
end

--- Define.Persistent / Define.Ephemeral, in the setup of `instance`.
---@param instance OrdaenInstance|nil
---@param spec table<string, table>
---@param persistent boolean
function State.Declare(instance, spec, persistent)
	if not instance then
		error("Ordaen: Define.Persistent and Define.Ephemeral belong directly in a setup", 3)
	end
	local state = instance.state
	if not state then -- made by the first declaration: an instance without state has none
		state = { persistent = {}, ephemeral = {} }
		instance.state = state
	end
	local store = persistent and state.persistent or state.ephemeral
	local module = instance.module
	for name, s in pairs(spec) do
		local meta = METAS[s.type]
		if not meta then
			error("Ordaen: " .. name .. " has type " .. tostring(s.type) .. ", not one the MVP builds", 3)
		end
		if (s.type == "list" or s.type == "map") and not s.cap then
			error("Ordaen: " .. name .. " can grow: it needs a cap", 3)
		end
		local root, path
		if persistent then
			root = s.scope == "character" and module.charDb or module.db
			-- the instance's path: its component, and its key when it has one
			local key = instance._key
			path = key ~= nil and (instance._declaration.name .. "#" .. tostring(key)) or instance._declaration.name
		else
			root = instance._ephemeral
			if not root then
				root = {}
				instance._ephemeral = root
			end
			path = "values"
		end
		if persistent then
			store[name] = State.Stored(module, path, name, s)
		else
			store[name] = setmetatable({ root = root, path = path, name = name, spec = s }, meta)
		end
	end
end
