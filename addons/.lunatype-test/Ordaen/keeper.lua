-- Made by lunatype from Ordaen/keeper.luna: change the source, not this file.
local R = LunaType
local __provide, __get, __peek, __set, __setKey, __cell, __computed, __event, __emit, __class = R.provide, R.get, R.peek, R.set, R.setKey, R.cell, R.computed, R.event, R.emit, R.class
local M = {}
R.addon("Ordaen")["keeper"] = M
local Keeper

local function __c1(self)
	return self:sum()
end


Keeper = __class({})

function Keeper.new(__owner)
	local self = setmetatable({}, Keeper)
	R.adopt(__owner, self)
	self.unsaved = __computed(self, __c1, self)
	self.rollbackable = __cell(false)
	self.saving = __event()
	self.saved = __event()
	self.any = false
	self.discarding = __event()
	self.rollingBack = __event()
	self.counts = __cell({})
	self.last = 0
	self.name = "Ordaen"
	__provide(R.addon("Ordaen"), "drafts", {}, self, { "unsaved", "rollbackable", "saving", "saved", "discarding", "rollingBack" }, { "saveAll", "discardAll", "rollbackAll", "changed", "join", "count", "leave", "naming", "nameNow" })
	return self
end

function Keeper:sum()
	local total = 0
	for id, waiting in pairs(__get(self.counts)) do
		total = total + waiting
	end
	return total
end

function Keeper:join()
	self.last = self.last + 1
	return self.last
end

function Keeper:count(id, waiting)
	__setKey(self.counts, id, waiting)
end

function Keeper:leave(id)
	__setKey(self.counts, id, 0)
end

function Keeper:naming(name)
	self.name = name
end

function Keeper:nameNow()
	return self.name
end

function Keeper:changed()
	self.any = true
end

function Keeper:saveAll()
	self.any = false
	__emit(self.saving)
	if not self.any then
		return
	end
	__emit(self.saved)
	__set(self.rollbackable, true)
end

function Keeper:discardAll()
	__emit(self.discarding)
end

function Keeper:rollbackAll()
	if not __peek(self.rollbackable) then
		return
	end
	__emit(self.rollingBack)
	__set(self.rollbackable, false)
end

M.Keeper = Keeper
