-- Signals (design: development/framework/signal): value, computed and event signals, read tracking, and the one
-- scheduler that re-runs what depends on a changed value, once a frame, parents first.
--
-- Cost: a read checks one field (is something tracking) and, while tracked, records itself once per run; a write
-- marks each dependant once. Nothing is allocated per read or write after the first run: dependants are table keys
-- (made on first use), a run's sources a reused array, the queue two reused arrays.
local _, ns = ...

local pairs, sort = pairs, table.sort

---@class OrdaenTracking
---@field observer table|nil the effect or computed value recording its reads now
local Tracking = { observer = nil }
ns.Tracking = Tracking

-- An observer (effect or computed) has `sources` (array), `nSources` and a `Mark` method. A source has `observers`
-- (set, made on its first tracked read).

---@param source table
local function Track(source)
	local o = Tracking.observer
	local observers = source.observers
	if not observers then
		observers = {}
		source.observers = observers
	elseif observers[o] then
		return
	end
	observers[o] = true
	local n = o.nSources + 1
	o.nSources = n
	o.sources[n] = source
end
Tracking.Track = Track

--- Forget what `o` read, before it runs again or when it ends.
---@param o table
function Tracking.Clear(o)
	local sources = o.sources
	for i = 1, o.nSources do
		sources[i].observers[o] = nil
		sources[i] = nil
	end
	o.nSources = 0
end

--- Mark everything that read `source`.
---@param source table
local function Notify(source)
	local observers = source.observers
	if observers then
		for o in pairs(observers) do
			o:Mark()
		end
	end
end
Tracking.Notify = Notify

-- Value signals --------------------------------------------------------------------------------------------------

---@class OrdaenValueSignal
---@field value any
---@field observers table|nil
local Value = {}
local ValueMeta = { __index = Value }
ns.ValueMeta = ValueMeta

---@param initial any
---@return OrdaenValueSignal
function ns.NewValue(initial)
	return setmetatable({ value = initial }, ValueMeta)
end

--- The value; recorded as a dependency of the effect or computed value running.
function Value:Get()
	if Tracking.observer then
		Track(self)
	end
	return self.value
end

--- The value, not recorded.
function Value:Peek()
	return self.value
end

--- Set it; a value equal to the current one (==) notifies nobody.
function Value:Set(value)
	if value == self.value then
		return
	end
	self.value = value
	Notify(self)
end

-- Computed values ------------------------------------------------------------------------------------------------

---@class OrdaenComputed : OrdaenValueSignal
---@field fn fun(): any
---@field dirty boolean
---@field sources table[]
---@field nSources integer
local Computed = {}
local ComputedMeta = { __index = Computed }

---@param fn fun(): any its reads are tracked
---@return OrdaenComputed
function ns.NewComputed(fn)
	return setmetatable({ fn = fn, dirty = true, sources = {}, nSources = 0 }, ComputedMeta)
end

function Computed:Mark()
	if not self.dirty then
		self.dirty = true
		Notify(self)
	end
end

local function Recompute(self)
	Tracking.Clear(self)
	local previous = Tracking.observer
	Tracking.observer = self
	local ok, value = pcall(self.fn)
	Tracking.observer = previous
	self.dirty = false
	if ok then
		self.value = value
	else
		geterrorhandler()(value)
	end
end

function Computed:Get()
	if self.dirty then
		Recompute(self)
	end
	if Tracking.observer then
		Track(self)
	end
	return self.value
end

function Computed:Peek()
	if self.dirty then
		Recompute(self)
	end
	return self.value
end

-- Event signals --------------------------------------------------------------------------------------------------

---@class OrdaenEvent
---@field n integer subscribers
---@field fns (function|false)[] false: removed while firing, compacted after
---@field owners table[]
---@field firing integer
---@field sticky boolean|nil fires at once for a subscriber added after it fired (the app's stages)
---@field fired boolean|nil
---@field onFirst fun(event: OrdaenEvent)|nil the first subscriber came (a game event registers)
---@field onLast fun(event: OrdaenEvent)|nil the last one left
local Event = {}
local EventMeta = { __index = Event }
ns.EventMeta = EventMeta

---@param onFirst fun(event: OrdaenEvent)|nil
---@param onLast fun(event: OrdaenEvent)|nil
---@return OrdaenEvent
function ns.NewEvent(onFirst, onLast)
	return setmetatable({ n = 0, fns = {}, owners = {}, firing = 0, onFirst = onFirst, onLast = onLast }, EventMeta)
end

---@param fn function
---@param owner table|false the instance whose handler it is
function Event:Subscribe(fn, owner)
	local n = self.n + 1
	self.n = n
	self.fns[n] = fn
	self.owners[n] = owner
	if n == 1 and self.onFirst then
		self:onFirst()
	end
end

local function Compact(self)
	local fns, owners, j = self.fns, self.owners, 0
	for i = 1, self.n do
		if fns[i] then
			j = j + 1
			fns[j], owners[j] = fns[i], owners[i]
		end
	end
	for i = j + 1, self.n do
		fns[i], owners[i] = nil, nil
	end
	self.n = j
	if j == 0 and self.onLast then
		self:onLast()
	end
end

---@param fn function
---@param owner table|false
function Event:Unsubscribe(fn, owner)
	local fns, owners = self.fns, self.owners
	for i = self.n, 1, -1 do
		if fns[i] == fn and owners[i] == owner then
			fns[i] = false
			if self.firing == 0 then
				Compact(self)
			end
			return
		end
	end
end

--- Run every handler with the payload, each in its own protected call, untracked.
function Event:Fire(...)
	self.fired = true
	if self.n == 0 then
		return
	end
	local Engine = ns.Engine
	self.firing = self.firing + 1
	local fns, owners = self.fns, self.owners
	for i = 1, self.n do
		local fn = fns[i]
		if fn then
			Engine:Run(owners[i], fn, ...)
		end
	end
	self.firing = self.firing - 1
	if self.firing == 0 then
		for i = 1, self.n do
			if not fns[i] then
				Compact(self)
				return
			end
		end
	end
end

--- The app's stages (design: development/framework/app#stages), offered as game.Stage and fired by the app; a
--- listener added after Login or Ready passed runs at once.
ns.Stage = { Login = ns.NewEvent(), Ready = ns.NewEvent(), Shutdown = ns.NewEvent() }
ns.Stage.Login.sticky = true
ns.Stage.Ready.sticky = true

-- The scheduler --------------------------------------------------------------------------------------------------

local MAX_PASSES = 100 -- an effect that keeps writing what it reads stops here

---@class OrdaenScheduler
local Scheduler = {}
ns.Scheduler = Scheduler

local queue, queued, spare = {}, 0, {}
local frame -- made on the first change: one OnUpdate, set only while something waits
local pending = false

local function Before(a, b)
	if a.depth ~= b.depth then
		return a.depth < b.depth
	end
	return a.seq < b.seq
end

local function OnUpdate()
	Scheduler.Flush()
end

--- Make sure a flush runs on the next frame (something was drawn or marked).
function Scheduler.Request()
	if not pending then
		pending = true
		if not frame then
			frame = CreateFrame("Frame")
		end
		frame:SetScript("OnUpdate", OnUpdate)
	end
end

--- Queue a marked effect for the next flush.
---@param effect table
function Scheduler.Queue(effect)
	queued = queued + 1
	queue[queued] = effect
	Scheduler.Request()
end

--- Re-run the marked effects, parents first, then settle what was drawn and let the backend lay it out.
function Scheduler.Flush()
	pending = false
	if frame then
		frame:SetScript("OnUpdate", nil)
	end
	local Engine = ns.Engine
	local passes = 0
	while queued > 0 do
		passes = passes + 1
		if passes > MAX_PASSES then
			for i = 1, queued do
				queue[i].dirty = false
				queue[i] = nil
			end
			queued = 0
			geterrorhandler()("Ordaen: effects kept re-running each other (an effect writes what it reads)")
			break
		end
		local list, n = queue, queued
		queue, queued, spare = spare, 0, list
		if n > 1 then
			sort(list, Before)
		end
		for i = 1, n do
			local effect = list[i]
			list[i] = nil
			if effect.dirty and effect.alive then
				Engine:RunEffect(effect)
			end
		end
	end
	ns.Draw:Settle()
	local backend = ns.Backend
	if backend then
		backend:Flush()
	end
end
