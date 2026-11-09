-- Signals (design: development/framework/signal): value, computed and event signals, read tracking, and the one
-- scheduler that re-runs what depends on a changed value, once a frame, parents first.
--
-- Cost: a read checks one field (is something tracking) and, while tracked, records itself once per run; a write
-- marks each dependant once, and a further write before any of them ran marks nobody (the source remembers it
-- notified). Nothing is allocated per read or write after the first run: dependants are table keys (made on first
-- use), a run's sources a reused array, the queue a reused array.
local _, ns = ...

local pairs = pairs

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
	source.notified = nil -- a new dependant: the next write has someone unmarked to mark
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

--- Mark everything that read `source`. Once it has, every dependant stays marked until it runs, and running it
--- tracks its reads again (which clears `notified`): until then a further write has nothing to mark.
---@param source table
local function Notify(source)
	if source.notified then
		return
	end
	local observers = source.observers
	if observers then
		-- set first: an immediate effect runs inside this loop and tracks again, which clears it
		source.notified = true
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
ns.Stage = { Login = ns.NewEvent(), Ready = ns.NewEvent(), Shutdown = ns.NewEvent(), ThemeChanged = ns.NewEvent() }
ns.Stage.Login.sticky = true
ns.Stage.Ready.sticky = true

-- The scheduler --------------------------------------------------------------------------------------------------

local MAX_RUNS = 100 -- runs of one effect in one flush: past it, it's writing what it reads (a loop)

---@class OrdaenScheduler
local Scheduler = {}
ns.Scheduler = Scheduler

-- The queue is a binary heap ordered parents first (depth, then creation order), reused: an effect marked during
-- the flush (a child whose attribute its parent just changed) is taken in the same flush, in tree order, however
-- deep the tree.
local heap, size = {}, 0
local flushes = 0 -- counts flushes: an effect's runs in this one are counted against MAX_RUNS
local frame -- made on the first change: its OnUpdate stays set and returns at once while nothing waits
local pending = false
local Debug -- Ordaen's debug kit, taken once the dev addon can have replaced the stand-in (after login)

local function Kit()
	if Debug then
		return Debug
	end
	local kit = ns.Core.NewDebug("OrdaenCore")
	if ns.Stage.Login.fired then
		Debug = kit
	end
	return kit
end

-- Set once and never removed: an idle frame costs one empty call (about 0.5 µs), a busy frame no SetScript on and off
-- (bench round 9: attaching per busy frame cost about 1.5 µs more per busy frame, and made writes 14x dearer)
local function OnUpdate()
	if pending then
		Scheduler.Flush()
	end
end

--- Make sure a flush runs on the next frame (something was drawn or marked).
function Scheduler.Request()
	if not pending then
		pending = true
		if not frame then
			frame = CreateFrame("Frame")
			frame:SetScript("OnUpdate", OnUpdate)
		end
	end
end

--- Queue a marked effect for the next flush (or for this one, while it runs).
---@param effect table
function Scheduler.Queue(effect)
	size = size + 1
	local i, order = size, effect.order
	while i > 1 do -- sift up
		local parent = (i - i % 2) / 2
		local above = heap[parent]
		if order >= above.order then
			break
		end
		heap[i] = above
		i = parent
	end
	heap[i] = effect
	Scheduler.Request()
end

local function Pop()
	local top = heap[1]
	local last = heap[size]
	heap[size] = nil
	size = size - 1
	if size > 0 then
		local i, order = 1, last.order
		while true do -- sift down
			local child = i * 2
			if child > size then
				break
			end
			if child < size and heap[child + 1].order < heap[child].order then
				child = child + 1
			end
			if heap[child].order >= order then
				break
			end
			heap[i] = heap[child]
			i = child
		end
		heap[i] = last
	end
	return top
end

-- What a looping effect is, for its report: its component and the values it reads, by name where they have one (a
-- stored value's), so the report says where to look. Built only when a loop happens.
local function Looping(effect)
	local instance = effect.instance or effect.owner -- an effect's instance; a binding's drawing component
	local declaration = instance and instance._declaration
	local module = instance and instance.module
	local where = (module and module.name or "?") .. "/" .. (declaration and declaration.name or "?")
	local names, n = {}, 0
	local sources = effect.sources
	for i = 1, effect.nSources do
		local name = sources[i].name
		if name then
			n = n + 1
			names[n] = name
		end
	end
	local kind = effect.isRender and "render" or (effect.fields and "binding") or "watch"
	return "Ordaen: effects kept re-running each other (an effect writes what it reads): the " .. kind .. " of "
		.. where .. (n > 0 and (", reading " .. table.concat(names, ", ")) or "")
end

--- Re-run the marked effects, parents first, then settle what was drawn and let the backend lay it out.
function Scheduler.Flush()
	pending = false
	local Debug = Kit()
	local t = Debug:TimeStart()
	flushes = flushes + 1
	local looped = false
	while size > 0 do
		local effect = Pop()
		if effect.dirty and effect.alive then
			if effect.flush ~= flushes then
				effect.flush, effect.runs = flushes, 0
			end
			local runs = effect.runs + 1
			effect.runs = runs
			if runs > MAX_RUNS then
				effect.dirty = false -- dropped for this flush: it runs again on its next change
				-- not run, so not tracked again: its sources must mark it on their next write
				local sources = effect.sources
				for s = 1, effect.nSources do
					sources[s].notified = nil
				end
				if not looped then
					looped = Looping(effect) -- the first: what to fix (one report a flush)
				end
			else
				effect:Run() -- an effect, or a binding (Binding.lua)
			end
		end
	end
	if looped then
		geterrorhandler()(looped)
	end
	Debug:TimeEnd(t, "flush: effects")
	t = Debug:TimeStart()
	ns.Draw:Settle()
	Debug:TimeEnd(t, "flush: settle")
	t = Debug:TimeStart()
	local backend = ns.Backend
	if backend then
		backend:Flush()
	end
	Debug:TimeEnd(t, "flush: backend")
end
