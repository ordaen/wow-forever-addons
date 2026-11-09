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

local function Check(spec, value, name)
	local kind = spec.type
	local ok
	if kind == "choice" then
		ok = false
		for _, member in pairs(spec.choices) do
			if member == value then
				ok = true
				break
			end
		end
	elseif kind == "number" then
		ok = type(value) == "number" and (not spec.min or value >= spec.min) and (not spec.max or value <= spec.max)
	elseif kind == "string" then
		ok = type(value) == "string" and (not spec.maxLength or #value <= spec.maxLength)
	else
		ok = type(value) == kind
	end
	if not ok then
		error("Ordaen: " .. name .. " can't be " .. tostring(value) .. " (" .. kind .. ")", 3)
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
		local follows = self.spec.follows
		if follows then
			return follows:Get() -- tracked too: a change of the global reaches what reads this
		end
		return self.spec.default
	end
	return value
end

function Plain:Peek()
	local value = Read(self)
	if value == nil then
		local follows = self.spec.follows
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
		if value == stored then
			return
		end
		TableFor(self)[self.name] = value
		Notify(self)
		return
	end
	if value == self:Peek() then
		return
	end
	if value == spec.default then
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

-- Declaring ------------------------------------------------------------------------------------------------------

local METAS = {
	boolean = PlainMeta, number = PlainMeta, string = PlainMeta, choice = PlainMeta,
	list = ListMeta, map = MapMeta,
}

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
		store[name] = setmetatable({ root = root, path = path, name = name, spec = s }, meta)
	end
end
