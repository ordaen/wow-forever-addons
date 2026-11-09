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

---@class OrdaenStoredValue
local Plain = {}
local PlainMeta = { __index = Plain }

function Plain:Get()
	if Tracking.observer then
		Track(self)
	end
	local value = Read(self)
	if value == nil then
		return self.spec.default
	end
	return value
end

function Plain:Peek()
	local value = Read(self)
	if value == nil then
		return self.spec.default
	end
	return value
end

function Plain:Set(value)
	local spec = self.spec
	Check(spec, value, self.name)
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

function Plain:Reset()
	self:Set(self.spec.default)
end

-- Lists ----------------------------------------------------------------------------------------------------------

---@class OrdaenStoredList
local List = {}
local ListMeta = { __index = List }

function List:Get(index)
	if Tracking.observer then
		Track(self)
	end
	local list = Read(self)
	return list and list[index]
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
	end
	Notify(self)
end

function List:Remove(index)
	local list = Read(self)
	if list and list[index] ~= nil then
		tremove(list, index)
		Notify(self)
	end
end

function List:Reset()
	local t = self.root[self.path]
	if t and t[self.name] then
		t[self.name] = nil
		Notify(self)
	end
end

-- Maps -----------------------------------------------------------------------------------------------------------

---@class OrdaenStoredMap
local Map = {}
local MapMeta = { __index = Map }

function Map:Get(key)
	if Tracking.observer then
		Track(self)
	end
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
			count = count - 1
		end
		self.count = count
	end
	Notify(self)
end

function Map:Remove(key)
	local map = Read(self)
	if map and map[key] ~= nil then
		map[key] = nil
		if self.count then
			self.count = self.count - 1
		end
		Notify(self)
	end
end

function Map:Reset()
	local t = self.root[self.path]
	if t and t[self.name] then
		t[self.name] = nil
		self.count = 0
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
	local store = persistent and instance.state.persistent or instance.state.ephemeral
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
			path = instance._path
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
