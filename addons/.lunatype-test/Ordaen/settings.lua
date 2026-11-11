-- Made by lunatype from Ordaen/settings.luna: change the source, not this file.
local R = LunaType
local __get, __peek, __set, __cell, __computed, __watch, __listen, __class = R.get, R.peek, R.set, R.cell, R.computed, R.watch, R.listen, R.class
local __runtime_differing = R.runtime.differing
local __Ordaen_drafts = R.addon("Ordaen")["drafts"]
local __runtime_restored = R.runtime.restored
local __runtime_copy = R.runtime.copy
local __runtime_store = R.runtime.store
local M = {}
R.addon("Ordaen")["settings"] = M
local Settings

local function __c1(self)
	return __runtime_differing(__get(self.draft), __get(self.values))
end


Settings = __class({})

function Settings.new(__owner, defaults, scope)
	local self = setmetatable({}, Settings)
	R.adopt(__owner, self)
	self.changed = __computed(self, __c1, self)
	self.before = nil
	self.replaced = nil
	self.defaults = defaults
	self.scope = scope
	self.name = __Ordaen_drafts.nameNow()
	local name = self.name
	local __t2
	if name ~= nil then
		__t2 = __runtime_restored(scope == "character", name, defaults)
	else
		__t2 = __runtime_copy(defaults)
	end
	local start = __t2
	self.draft = __cell(__runtime_copy(start))
	self.values = __cell(start)
	self.id = __Ordaen_drafts.join()
	__listen(__Ordaen_drafts.saving, self, self.save)
	__listen(__Ordaen_drafts.saved, self, self.settle)
	__listen(__Ordaen_drafts.discarding, self, self.discard)
	__listen(__Ordaen_drafts.rollingBack, self, self.rollback)
	__watch(self, self.tell, self)
	return self
end

Settings["$destructor"] = function(self)
	__Ordaen_drafts.leave(self.id)
end

function Settings:tell()
	__Ordaen_drafts.count(self.id, __get(self.changed))
end

function Settings:keep()
	local name = self.name
	if name ~= nil then
		__runtime_store(self.scope == "character", name, __peek(self.values))
	end
end

function Settings:save()
	self.replaced = nil
	if __peek(self.changed) == 0 then
		return
	end
	self.replaced = __runtime_copy(__peek(self.values))
	__set(self.values, __runtime_copy(__peek(self.draft)))
	self:keep()
	__Ordaen_drafts.changed()
end

function Settings:settle()
	self.before = self.replaced
	self.replaced = nil
end

function Settings:discard()
	__set(self.draft, __runtime_copy(__peek(self.values)))
end

function Settings:rollback()
	local was = self.before
	if was == nil then
		return
	end
	__set(self.values, __runtime_copy(was))
	__set(self.draft, __runtime_copy(was))
	self.before = nil
	self:keep()
end

function Settings:reset()
	__set(self.values, __runtime_copy(self.defaults))
	__set(self.draft, __runtime_copy(self.defaults))
	self:keep()
end

M.Settings = Settings
