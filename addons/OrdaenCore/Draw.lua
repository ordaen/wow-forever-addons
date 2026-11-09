-- Drawing (design: development/framework/box, component#identity): game.ui's calls, identity by call site and key,
-- and what each render drew, in order, handed to the backend (ns.Backend, the contract in development/framework/mvp).
--
-- A fragment is what one owner drew into one container during its last run, in order: boxes, texts, frames taken
-- over, and child components (whose own fragments expand in their place). A container is a box (its children) or a
-- place (a layer: the module roots and what renders drew into it as a target). After a flush, each container whose
-- order changed gets its flattened list of nodes (Settle). Entries are pooled; a run makes no table once warm.
local _, ns = ...

local Engine = ns.Engine
local Scheduler = ns.Scheduler
local pairs, error, getmetatable = pairs, error, getmetatable

---@class OrdaenDraw
local Draw = {}
ns.Draw = Draw

local EMPTY = {}
local NULL = ns.NULL

-- Run stacks: the fragment being filled, the instance whose render runs, and the lexical self for slot functions.
local fragments, nFragments = {}, 0
local runs, nRuns = {}, 0
local lexical, nLexical = {}, 0
local bases, lexicalBases = {}, {} -- stack heights when each run began, to unwind after an error

-- Containers needing their children set (Settle).
local dirty, nDirty = {}, 0

local function MarkDirty(container)
	if container and not container.dirty then
		container.dirty = true
		nDirty = nDirty + 1
		dirty[nDirty] = container
		Scheduler.Request()
	end
end

-- Fragments ------------------------------------------------------------------------------------------------------

local function NewFragment(owner, container)
	return { owner = owner, container = container, cur = {}, old = {}, n = 0, oldN = 0, byId = {}, gen = 0 }
end

local function BeginFragment(f)
	f.gen = f.gen + 1
	f.old, f.cur = f.cur, f.old
	f.oldN, f.n = f.n, 0
end

local pool, nPool = {}, 0

local function Lookup(f, site, key)
	local slot = f.byId[site]
	if key == nil then
		return slot
	end
	return slot and slot[key]
end

local function Remember(f, e)
	if e.key == nil then
		f.byId[e.site] = e
	else
		local map = f.byId[e.site]
		if not map then
			map = {}
			f.byId[e.site] = map
		end
		map[e.key] = e
	end
end

local function Forget(f, e)
	if e.key == nil then
		if f.byId[e.site] == e then
			f.byId[e.site] = nil
		end
	else
		local map = f.byId[e.site]
		if map and map[e.key] == e then
			map[e.key] = nil
		end
	end
end

local function NewEntry(f, kind, site, key)
	local e
	if nPool > 0 then
		e = pool[nPool]
		pool[nPool] = nil
		nPool = nPool - 1
	else
		e = { last = {} }
	end
	e.kind, e.site, e.key, e.seen = kind, site, key, -1
	Remember(f, e)
	return e
end

local ReleaseEntries

local function Release(f, e)
	local kind, backend = e.kind, ns.Backend
	if kind == "comp" then
		local instance = e.instance
		e.instance, e.declaration = nil, nil
		if instance then
			Engine:Unmount(instance)
		end
	else
		local kids = e.kids
		if kids and kids.n > 0 then
			ReleaseEntries(kids)
		end
		if e.node then
			backend:Release(e.node)
		end
		e.node, e.frame, e.dirty = nil, nil, nil
	end
	Forget(f, e)
	local last = e.last
	for k in pairs(last) do
		last[k] = nil
	end
	if e.args then
		for i = #e.args, 1, -1 do
			e.args[i] = nil
		end
	end
	nPool = nPool + 1
	pool[nPool] = e
end

ReleaseEntries = function(f)
	local cur = f.cur
	for i = f.n, 1, -1 do
		local e = cur[i]
		cur[i] = nil
		Release(f, e)
	end
	f.n = 0
end

local function EndFragment(f)
	local cur, old, n, oldN = f.cur, f.old, f.n, f.oldN
	local changed = n ~= oldN
	if not changed then
		for i = 1, n do
			if cur[i] ~= old[i] then
				changed = true
				break
			end
		end
	end
	local gen = f.gen
	for i = 1, oldN do
		local e = old[i]
		old[i] = nil
		if e.seen ~= gen then
			Release(f, e)
		end
	end
	f.oldN = 0
	if changed then
		MarkDirty(f.container)
	end
end

local function Append(f, e)
	if e.seen == f.gen then
		error("Ordaen: the same call drawn twice in one run (a loop without a `key`, or a repeated key)", 3)
	end
	e.seen = f.gen
	local n = f.n + 1
	f.n = n
	f.cur[n] = e
end

-- Instances ------------------------------------------------------------------------------------------------------

--- A new instance's place: its fragment, in `container`.
function Draw:NewInstance(instance, container)
	instance._container = container
	instance._fragment = NewFragment(instance, container)
	instance._mounted, instance._nMounted = {}, 0
	if container.isPlace then
		local n = container.n + 1
		container.n = n
		container.members[n] = instance
	end
	MarkDirty(container)
end

---@return table the container a component's output goes into
function Draw:PlaceOf(instance)
	return instance._container
end

function Draw:AttachMounted(parent, child)
	local n = parent._nMounted + 1
	parent._nMounted = n
	parent._mounted[n] = child
	MarkDirty(parent._container)
end

local function RemoveMember(list, n, value)
	for i = 1, n do
		if list[i] == value then
			for j = i, n - 1 do
				list[j] = list[j + 1]
			end
			list[n] = nil
			return n - 1
		end
	end
	return n
end

function Draw:DetachMounted(parent, child)
	parent._nMounted = RemoveMember(parent._mounted, parent._nMounted, child)
	MarkDirty(parent._container)
end

--- Release everything an instance drew: its fragment and what it drew into targets.
function Draw:ReleaseInstance(instance)
	local f = instance._fragment
	if f.n > 0 then
		ReleaseEntries(f)
	end
	local targets = instance._targetList
	if targets then
		for i = #targets, 1, -1 do
			local tf = targets[i]
			targets[i] = nil
			ReleaseEntries(tf)
			local place = tf.container
			place.n = RemoveMember(place.members, place.n, tf)
			MarkDirty(place)
		end
		instance._targets = nil
	end
	local container = instance._container
	if container.isPlace then
		container.n = RemoveMember(container.members, container.n, instance)
	end
	MarkDirty(container)
end

-- Runs -----------------------------------------------------------------------------------------------------------

function Draw:BeginRun(instance)
	nRuns = nRuns + 1
	runs[nRuns] = instance
	bases[nRuns] = nFragments
	lexicalBases[nRuns] = nLexical
	nLexical = nLexical + 1
	lexical[nLexical] = instance
	local f = instance._fragment
	BeginFragment(f)
	nFragments = nFragments + 1
	fragments[nFragments] = f
	local targets = instance._targetList
	if targets then
		for i = 1, #targets do
			BeginFragment(targets[i])
		end
	end
end

function Draw:EndRun(instance)
	local base = bases[nRuns]
	-- unwind what an error left open, innermost first
	while nFragments > base do
		local f = fragments[nFragments]
		fragments[nFragments] = nil
		nFragments = nFragments - 1
		EndFragment(f)
	end
	local lexicalBase = lexicalBases[nRuns]
	while nLexical > lexicalBase do
		lexical[nLexical] = nil
		nLexical = nLexical - 1
	end
	local targets = instance._targetList
	if targets then
		for i = 1, #targets do
			EndFragment(targets[i])
		end
	end
	runs[nRuns], bases[nRuns], lexicalBases[nRuns] = nil, nil, nil
	nRuns = nRuns - 1
end

-- Targets --------------------------------------------------------------------------------------------------------

local PlaceMeta = {}

--- A layer of the screen: a place module roots and targeted draws go into.
---@param name "screen"|"dialog"|"tooltip"
function Draw:NewPlace(name)
	return setmetatable({ isTarget = true, isPlace = true, name = name, node = ns.Backend and ns.Backend:Layer(name), members = {}, n = 0 }, PlaceMeta)
end

local function TargetFragment(place)
	local instance = runs[nRuns]
	if not instance then
		error("Ordaen: drawing outside a render", 3)
	end
	local targets = instance._targets
	if not targets then
		targets = {}
		instance._targets = targets
		instance._targetList = {}
	end
	local f = targets[place]
	if not f then
		f = NewFragment(instance, place)
		targets[place] = f
		local list = instance._targetList
		list[#list + 1] = f
		local n = place.n + 1
		place.n = n
		place.members[n] = f
		BeginFragment(f)
	end
	return f
end

-- Attributes -----------------------------------------------------------------------------------------------------

local function Differs(last, attributes)
	for k, v in pairs(attributes) do
		if last[k] ~= v then
			return true
		end
	end
	for k in pairs(last) do
		if attributes[k] == nil then
			return true
		end
	end
	return false
end

local function Copy(last, attributes)
	for k in pairs(last) do
		if attributes[k] == nil then
			last[k] = nil
		end
	end
	for k, v in pairs(attributes) do
		last[k] = v
	end
end

-- `arguments` change in place (a refilled list): compared element by element against the entry's own copy.
local function ArgumentsDiffer(e, arguments)
	local args = e.args
	if not arguments then
		return args ~= nil and args[1] ~= nil
	end
	if not args then
		args = {}
		e.args = args
	end
	local changed = false
	for i = 1, #arguments do
		if args[i] ~= arguments[i] then
			args[i] = arguments[i]
			changed = true
		end
	end
	for i = #args, #arguments + 1, -1 do
		args[i] = nil
		changed = true
	end
	return changed
end

-- The calls ------------------------------------------------------------------------------------------------------

-- `game.ui:X(site, data)` draws into the run's place, `game.ui:X(site, target, data)` into a target.
local function Resolve(a, b)
	if b ~= nil then
		return a, b
	end
	if a ~= nil and (a.isTarget or a == NULL) then
		return a, nil
	end
	return nil, a
end

local function FragmentFor(target)
	if target == nil then
		local f = fragments[nFragments]
		if not f then
			error("Ordaen: drawing outside a render", 3)
		end
		return f
	end
	if target == NULL or target.isNull then
		return nil -- an absent module's slot: drawn nowhere
	end
	return TargetFragment(target)
end

---@class OrdaenUi
local UiBase = {}

function UiBase:Box(site, a, b)
	local target, data = Resolve(a, b)
	local f = FragmentFor(target)
	if not f then
		return
	end
	local key = data and data.key
	local e = Lookup(f, site, key)
	if e and e.kind ~= "box" then
		error("Ordaen: call site reused for another kind", 2)
	end
	if not e then
		e = NewEntry(f, "box", site, key)
		e.node = ns.Backend:Create("box")
		if not e.kids then
			e.kids = NewFragment(f.owner, e)
		else
			e.kids.owner, e.kids.container = f.owner, e
		end
	end
	Append(f, e)
	local attributes = data and data.attributes or EMPTY
	if Differs(e.last, attributes) then
		Copy(e.last, attributes)
		ns.Backend:Set(e.node, attributes)
	end
	local slots = data and data.slots
	local content = slots and slots.default
	local kids = e.kids
	if content then
		BeginFragment(kids)
		nFragments = nFragments + 1
		fragments[nFragments] = kids
		local self = lexical[nLexical]
		content(self._game, self)
		fragments[nFragments] = nil
		nFragments = nFragments - 1
		EndFragment(kids)
	elseif kids.n > 0 then
		BeginFragment(kids)
		EndFragment(kids)
	end
end

function UiBase:Text(site, a, b)
	local target, data = Resolve(a, b)
	local f = FragmentFor(target)
	if not f then
		return
	end
	local key = data and data.key
	local e = Lookup(f, site, key)
	if e and e.kind ~= "text" then
		error("Ordaen: call site reused for another kind", 2)
	end
	if not e then
		e = NewEntry(f, "text", site, key)
		e.node = ns.Backend:Create("text")
	end
	Append(f, e)
	local attributes = data and data.attributes or EMPTY
	local changed = Differs(e.last, attributes)
	if ArgumentsDiffer(e, attributes.arguments) then
		changed = true
	end
	if changed then
		Copy(e.last, attributes)
		ns.Backend:Set(e.node, attributes)
	end
end

--- Take over a Blizzard frame while this render draws it: `game.ui:Frame(game.Frame.CombinedBags, data)`.
function UiBase:Frame(site, reference, data)
	local f = fragments[nFragments]
	if not f then
		error("Ordaen: drawing outside a render", 2)
	end
	local frame = reference:Get()
	if not frame then
		return -- not there yet (a load-on-demand window): taken when a later run finds it
	end
	local e = Lookup(f, site, nil)
	if e and (e.kind ~= "frame" or e.frame ~= frame) then
		e = nil
	end
	if not e then
		e = NewEntry(f, "frame", site, nil)
		e.frame = frame
		e.node = ns.Backend:Take(frame)
	end
	Append(f, e)
	local attributes = data and data.attributes or EMPTY
	if Differs(e.last, attributes) then
		Copy(e.last, attributes)
		ns.Backend:Set(e.node, attributes)
	end
end

--- Where the caller's content for slot `name` goes.
function UiBase:Slot(site, name) -- luacheck: ignore 212
	local instance = runs[nRuns]
	local slots = instance and instance._slots
	local content = slots and slots[name]
	if not content then
		return
	end
	local owner = instance._slotOwner or instance
	nLexical = nLexical + 1
	lexical[nLexical] = owner
	content(owner._game, owner)
	lexical[nLexical] = nil
	nLexical = nLexical - 1
end

local function DrawComponent(ui, declaration, site, a, b)
	local target, data = Resolve(a, b)
	local f = FragmentFor(target)
	if not f then
		return
	end
	local key = data and data.key
	local e = Lookup(f, site, key)
	if e and (e.kind ~= "comp" or e.declaration ~= declaration or not e.instance or not e.instance._alive) then
		Forget(f, e) -- replaced: the old entry is released at the end of the run (not seen)
		e = nil
	end
	local owner = lexical[nLexical]
	if e then
		Append(f, e)
		local instance = e.instance
		Engine.SetAttributes(instance, data and data.attributes)
		Engine.SetSlots(instance, data and data.slots, owner)
		return
	end
	e = NewEntry(f, "comp", site, key)
	e.declaration = declaration
	Append(f, e)
	local parent = runs[nRuns]
	local instance = Engine:Mount(parent, declaration, site, data, f.container, parent.module, ui._game, owner)
	if instance then
		e.instance = instance
	else
		f.cur[f.n] = nil -- failed to mount: not drawn
		f.n = f.n - 1
		Forget(f, e)
		e.declaration = nil
		nPool = nPool + 1
		pool[nPool] = e
	end
end

local function LowerFirst(name)
	return name:sub(1, 1):lower() .. name:sub(2)
end

local UiMeta = {
	__index = function(ui, name)
		local base = UiBase[name]
		if base then
			return base
		end
		local module = rawget(ui, "_module")
		local declaration = module:Import("components/" .. LowerFirst(name))
		local method = function(_, site, a, b)
			return DrawComponent(ui, declaration, site, a, b)
		end
		rawset(ui, name, method)
		return method
	end,
}

--- A module's game.ui: the primitives, and its own components by name (`game.ui:BagGrid` is components/bagGrid).
function Draw.NewUi(module)
	return setmetatable({ _module = module }, UiMeta)
end

-- Settle ---------------------------------------------------------------------------------------------------------

local flat, flatMax = {}, 0

local ExpandInstance

local function Expand(f, n)
	local cur = f.cur
	for i = 1, f.n do
		local e = cur[i]
		local kind = e.kind
		if kind == "comp" then
			if e.instance then
				n = ExpandInstance(e.instance, n)
			end
		elseif kind ~= "frame" then
			n = n + 1
			flat[n] = e.node
		end
	end
	return n
end

ExpandInstance = function(instance, n)
	n = Expand(instance._fragment, n)
	local mounted = instance._mounted
	for i = 1, instance._nMounted do
		n = ExpandInstance(mounted[i], n)
	end
	return n
end

--- Hand each changed container its ordered children (end of every flush, before the backend lays out).
function Draw:Settle()
	local backend = ns.Backend
	local i = 1
	while i <= nDirty do -- a container may be marked while settling: the loop sees it
		local c = dirty[i]
		dirty[i] = nil
		c.dirty = false
		if c.node then
			local n = 0
			if c.isPlace then
				local members = c.members
				for j = 1, c.n do
					local m = members[j]
					if getmetatable(m) == ns.InstanceMeta then
						n = ExpandInstance(m, n)
					else
						n = Expand(m, n)
					end
				end
			else
				n = Expand(c.kids, n)
			end
			for j = n + 1, flatMax do
				flat[j] = nil
			end
			flatMax = n
			backend:SetChildren(c.node, flat, n)
		end
		i = i + 1
	end
	nDirty = 0
end
