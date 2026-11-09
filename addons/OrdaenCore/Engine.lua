-- The engine (design: development/framework/component, effects, transaction): component instances, their setup and
-- effects, transactions and who owns them, mounting and unmounting, and the handles that reach a public part.
--
-- Records: every transaction is four slots in its owner's `rec` array (revert function and three arguments), so
-- applying one makes no table. An owner is an effect run (its own `rec`, reverted when it runs again) or the
-- instance (setup and handlers, reverted at unmount). Reverts run newest first.
local _, ns = ...

local Tracking, Scheduler = ns.Tracking, ns.Scheduler
local NewValue = ns.NewValue
local xpcall, type, pairs, rawget, rawset, error, getmetatable = xpcall, type, pairs, rawget, rawset, error, getmetatable

---@class OrdaenEngine
---@field owner table|nil the effect or instance whose code runs now (holder of its transactions)
---@field setupInstance OrdaenInstance|nil the instance whose setup runs now (for Define.Persistent/Ephemeral)
local Engine = {}
ns.Engine = Engine

local function OnError(message)
	geterrorhandler()(message)
	return message
end
ns.OnError = OnError

-- Records ------------------------------------------------------------------------------------------------------

local function Push(holder, revert, a, b, c)
	local rec, n = holder.rec, holder.nRec
	if not rec then -- made on the first record: most instances and effects never record anything
		rec = {}
		holder.rec = rec
	end
	rec[n + 1], rec[n + 2], rec[n + 3], rec[n + 4] = revert, a, b, c
	holder.nRec = n + 4
end
Engine.Push = Push

--- Revert the holder's records down to `mark` (0: all), newest first; a revert that fails is reported.
local function RevertTo(holder, mark)
	local rec = holder.rec
	for i = holder.nRec - 3, mark + 1, -4 do
		local revert, a, b, c = rec[i], rec[i + 1], rec[i + 2], rec[i + 3]
		rec[i], rec[i + 1], rec[i + 2], rec[i + 3] = nil, nil, nil, nil
		holder.nRec = i - 1
		xpcall(revert, OnError, a, b, c)
	end
	holder.nRec = mark
end

-- Handles: a public part reached by reference or by module name --------------------------------------------------

local function noop() end
local NO_PUBLIC = {} -- the public part of a component that offers nothing: mounted, with no entries

-- What every entry of a handle reads while nothing is mounted: callable (a function doing nothing), readable (a
-- signal reading nil), an event no one fires, a slot drawing nowhere.
local NULL = setmetatable({}, {
	__call = noop,
	__index = { Get = noop, Peek = noop, Subscribe = noop, Unsubscribe = noop, isNull = true },
})
ns.NULL = NULL
local NULL_SLOTS = setmetatable({}, { __index = function() return NULL end })

local HandleMeta = {}
HandleMeta.__index = function(handle, key)
	rawget(handle, "_mounted"):Get() -- an effect touching a handle re-runs when its target comes or goes
	local public = rawget(handle, "_public")
	if public then
		local value = public[key]
		if value ~= nil then
			return value
		end
	end
	return key == "slots" and NULL_SLOTS or NULL
end

---@return table
function Engine.NewHandle()
	return setmetatable({ _public = false, _mounted = NewValue(false) }, HandleMeta)
end

local function Bind(handle, public)
	rawset(handle, "_public", public or false)
	rawget(handle, "_mounted"):Set(public and true or false)
end
Engine.BindHandle = Bind

-- Effects --------------------------------------------------------------------------------------------------------

---@class OrdaenEffect
local Effect = {}
local EffectMeta = { __index = Effect }

local seq = 0

local function NewEffect(instance, fn, isRender, immediate)
	seq = seq + 1
	return setmetatable({
		instance = instance, fn = fn, isRender = isRender, immediate = immediate or nil,
		-- the scheduler's order, one number: parents first (depth), then creation order (seq < 2^32)
		order = instance._depth * 4294967296 + seq, dirty = false, alive = true,
		sources = {}, nSources = 0, nRec = 0, -- rec: made on the first record (Push)
	}, EffectMeta)
end

--- The scheduler runs what it queued by its Run: an effect's is the engine's RunEffect (a binding has its own).
function Effect:Run()
	Engine:RunEffect(self)
end

function Effect:Mark()
	if self.dirty or not self.alive then
		return
	end
	self.dirty = true
	if self.immediate and Engine.owner ~= self then
		Engine:RunEffect(self)
	else
		Scheduler.Queue(self)
	end
end

local UnmountRecord -- the revert of self:Mount, kept for reuse across a watch's runs

--- Run an effect: revert its last run (children it mounted are kept for reuse), track what it reads, roll back if
--- it fails.
---@param effect OrdaenEffect
function Engine:RunEffect(effect)
	effect.dirty = false
	local instance = effect.instance
	-- keep last run's mounted children to land the same calls on them (identity by call site and key)
	local reuse, nReuse = effect.reuse, 0
	local rec = effect.rec
	for i = effect.nRec - 3, 1, -4 do
		local revert, a, b, c = rec[i], rec[i + 1], rec[i + 2], rec[i + 3]
		rec[i], rec[i + 1], rec[i + 2], rec[i + 3] = nil, nil, nil, nil
		if revert == UnmountRecord then
			if not reuse then
				reuse = {}
				effect.reuse = reuse
			end
			nReuse = nReuse + 1
			reuse[nReuse] = b
		else
			xpcall(revert, OnError, a, b, c)
		end
	end
	effect.nRec = 0
	effect.nReuse = nReuse
	Tracking.Clear(effect)
	local previousObserver, previousOwner = Tracking.observer, Engine.owner
	Tracking.observer, Engine.owner = effect, effect
	local ok
	if effect.isRender then
		local Draw = ns.Draw
		Draw:BeginRun(instance)
		ok = xpcall(effect.fn, OnError, instance._game, instance)
		Draw:EndRun(instance)
	else
		ok = xpcall(effect.fn, OnError)
	end
	Tracking.observer, Engine.owner = previousObserver, previousOwner
	if not ok then
		RevertTo(effect, 0)
	end
	-- children last run mounted and this run didn't
	if nReuse > 0 then
		for i = 1, effect.nReuse do
			local child = reuse[i]
			reuse[i] = nil
			if child then
				UnmountRecord(instance, child)
			end
		end
	end
	effect.nReuse = 0
end

local function KillEffect(effect)
	if not effect.alive then
		return
	end
	effect.alive = false
	Tracking.Clear(effect)
	RevertTo(effect, 0)
	if effect.isRender then
		ns.Draw:ReleaseInstance(effect.instance)
	end
end

-- Instances ------------------------------------------------------------------------------------------------------

---@class OrdaenInstance
---@field _declaration table
---@field _parent OrdaenInstance|nil
---@field _depth integer
---@field _game table
---@field _alive boolean
local Instance = {}
local InstanceMeta = { __index = Instance }
ns.InstanceMeta = InstanceMeta

-- Names a setup may not return: the instance's own members.
local RESERVED = { state = true, attributes = true, module = true, public = true }

local AttributesMeta = {
	__index = function(attributes, name)
		local signal = NewValue(nil)
		attributes[name] = signal
		return signal
	end,
}

--- The holder of a transaction `instance` makes now: its running effect, else the instance itself.
local function Holder(instance, method)
	if not instance._alive then
		error("Ordaen: " .. method .. " on an unmounted component", 3)
	end
	local owner = Engine.owner
	if owner and owner ~= instance and getmetatable(owner) == EffectMeta and owner.instance == instance then
		if owner.isRender then
			error("Ordaen: " .. method .. " in a render: a render only reads and draws", 3)
		end
		return owner
	end
	return instance
end

--- Set a child's attributes from its parent's call: only changed ones notify. Names the call binds (`bound`, its
--- bind map) are its bindings' to write: the static table, which lacks them, leaves them alone.
---@param instance OrdaenInstance
---@param values table|nil
---@param bound table|nil
function Engine.SetAttributes(instance, values, bound)
	local attributes = instance.attributes
	for name, signal in pairs(attributes) do
		if (values == nil or values[name] == nil) and not (bound and bound[name]) then
			signal:Set(nil)
		end
	end
	if values then
		for name, value in pairs(values) do
			attributes[name]:Set(value)
		end
	end
end

--- Set a child's slot content; a different table re-renders it (hoisted slot tables never do).
function Engine.SetSlots(instance, slots, owner)
	if instance._slots ~= slots then
		instance._slots = slots
		instance._slotOwner = owner
		local render = instance._render
		if render then
			render:Mark()
		end
	end
end

local function MergeReturn(instance, result)
	if type(result) ~= "table" then
		return
	end
	for name, value in pairs(result) do
		if name ~= "public" then
			if RESERVED[name] or Instance[name] or rawget(instance, name) ~= nil then
				error("Ordaen: setup returns `" .. name .. "`, a name the component already has", 0)
			end
			instance[name] = value
		end
	end
	local public = result.public
	if public then
		local flat = {}
		for kind, entries in pairs(public) do
			if kind == "slots" then
				flat.slots = entries
				instance.slots = entries
			else
				for name, value in pairs(entries) do
					flat[name] = value
					instance[name] = value
				end
			end
		end
		instance._public = flat
	end
end

--- Mount a component: its setup, its watches in order, then its render. All or nothing: a failure reverts what it
--- applied and returns nil.
---@param parent OrdaenInstance|nil
---@param declaration table Define.Component or Define.Module
---@param site any its call site (identity)
---@param data table|nil the call's { key, ref, attributes, slots }
---@param container table where its render's output goes (Draw)
---@param module table the module context (self.module)
---@param game table
---@param slotOwner OrdaenInstance|nil whose render passed the slot functions
---@return OrdaenInstance|nil
function Engine:Mount(parent, declaration, site, data, container, module, game, slotOwner)
	local key = data and data.key
	local instance = setmetatable({
		_declaration = declaration, _parent = parent, _depth = parent and parent._depth + 1 or 0,
		_site = site, _key = key, _game = game, _alive = true, _nEffects = 0, -- _effects: made by the first Watch
		_slots = data and data.slots, _slotOwner = slotOwner,
		nRec = 0, -- rec: made on the first record (Push)
		module = module,
		attributes = setmetatable({}, AttributesMeta),
		-- state: made by the first Define.Persistent or Define.Ephemeral (State.Declare)
	}, InstanceMeta)
	if data and data.attributes then
		Engine.SetAttributes(instance, data.attributes)
	end
	ns.Draw:NewInstance(instance, container)

	local previousObserver, previousOwner, previousSetup = Tracking.observer, Engine.owner, Engine.setupInstance
	Tracking.observer, Engine.owner, Engine.setupInstance = nil, instance, instance
	instance._pending = true -- watches made in setup wait for it to finish
	local ok, result = true, nil
	if declaration.Setup then
		ok, result = xpcall(declaration.Setup, OnError, game, instance)
	end
	if ok then
		ok = xpcall(MergeReturn, OnError, instance, result)
	end
	Tracking.observer, Engine.owner, Engine.setupInstance = previousObserver, previousOwner, previousSetup
	instance._pending = nil
	if not ok then
		self:Unmount(instance)
		return nil
	end
	for i = 1, instance._nEffects do
		local effect = instance._effects[i]
		if effect.alive then
			self:RunEffect(effect)
		end
	end
	if declaration.Render and instance._alive then
		local render = NewEffect(instance, declaration.Render, true)
		instance._render = render
		self:RunEffect(render)
	end
	if data and data.ref then
		instance._ref = data.ref
		Bind(data.ref, instance._public or NO_PUBLIC)
	end
	return instance
end

--- Unmount: its render's output released, its effects stopped, everything it holds reverted, newest first.
---@param instance OrdaenInstance
function Engine:Unmount(instance)
	if not instance._alive then
		return
	end
	if instance._ref then
		Bind(instance._ref, nil)
		instance._ref = nil
	end
	local render = instance._render
	if render then
		KillEffect(render)
	else
		ns.Draw:ReleaseInstance(instance)
	end
	local effects = instance._effects
	for i = instance._nEffects, 1, -1 do
		KillEffect(effects[i])
	end
	RevertTo(instance, 0)
	instance._alive = false
end

--- Run a handler: protected, untracked, its transactions owned by `instance` (nil for the backend's input calls,
--- whose functions only change state). A failure rolls back what it applied.
---@param instance OrdaenInstance|false|nil
---@param fn function
function Engine:Run(instance, fn, ...)
	if instance and not instance._alive then
		return
	end
	local previousObserver, previousOwner = Tracking.observer, Engine.owner
	Tracking.observer, Engine.owner = nil, instance or nil
	local mark = instance and instance.nRec
	local ok = xpcall(fn, OnError, ...)
	Tracking.observer, Engine.owner = previousObserver, previousOwner
	if not ok and instance then
		RevertTo(instance, mark)
	end
end

--- The backend's door for input: `OnClick`, `OnEnter`, `OnLeave` functions.
function Engine:Handle(fn, ...)
	self:Run(nil, fn, ...)
end

-- Transaction methods (design: development/framework/component#instance-methods) --------------------------------

local function Unsubscribe(signal, fn, instance)
	signal:Unsubscribe(fn, instance)
end

--- Run `handler(...)` after `signal` fires (an event signal, or a raw game event name).
---@param signal table|string
---@param handler function
function Instance:On(signal, handler)
	local holder = Holder(self, "On")
	if type(signal) == "string" then
		signal = ns.Game.RawEvent(signal)
	end
	if signal.isNull then
		return
	end
	signal:Subscribe(handler, self)
	Push(holder, Unsubscribe, signal, handler, self)
	if signal.sticky and signal.fired then
		Engine:Run(self, handler)
	end
end

local function KillWatch(effect)
	KillEffect(effect)
end

--- An effect: runs after setup (or now, made later), then whenever what it read changes.
---@param fn fun()
---@param options { immediate: boolean? }|nil
function Instance:Watch(fn, options)
	local holder = Holder(self, "Watch")
	local effect = NewEffect(self, fn, false, options and options.immediate)
	local n = self._nEffects + 1
	self._nEffects = n
	local effects = self._effects
	if not effects then
		effects = {}
		self._effects = effects
	end
	effects[n] = effect
	Push(holder, KillWatch, effect)
	if not self._pending then
		Engine:RunEffect(effect)
	end
end

local function CancelTicker(ticker)
	ticker:Cancel()
end

--- A repeating timer while the owner holds it.
---@param seconds number
---@param handler fun()
function Instance:Every(seconds, handler)
	local holder = Holder(self, "Every")
	local instance = self
	local ticker = C_Timer.NewTicker(seconds, function()
		Engine:Run(instance, handler)
	end)
	Push(holder, CancelTicker, ticker)
end

UnmountRecord = function(parent, child)
	if child._alive then
		Engine:Unmount(child)
	end
	ns.Draw:DetachMounted(parent, child)
end

--- Mount a child with no place in a view (it draws, if it draws, into this component's place). `site` is stamped by
--- the build; a watch running again lands the same call on the same child.
---@param site any
---@param component table
---@param data table|nil
function Instance:Mount(site, component, data)
	local holder = Holder(self, "Mount")
	local key = data and data.key
	if holder.reuse then
		local reuse = holder.reuse
		for i = 1, holder.nReuse do
			local child = reuse[i]
			if child and child._site == site and child._key == key and child._declaration == component then
				reuse[i] = false
				Engine.SetAttributes(child, data and data.attributes)
				Push(holder, UnmountRecord, self, child)
				return
			end
		end
	end
	local child = Engine:Mount(self, component, site, data, ns.Draw:PlaceOf(self), self.module, self._game, self)
	if child then
		ns.Draw:AttachMounted(self, child)
		Push(holder, UnmountRecord, self, child)
	end
end
