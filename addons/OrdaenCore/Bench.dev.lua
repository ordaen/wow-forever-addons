-- Dev-only doors for the benchmark module (OrdaenBench): release builds leave out *.dev.lua, so players never get
-- them. Not module API; nothing else calls them.
local _, ns = ...

local Core = ns.Core

--- Flush now: the bench times a change together with its flush.
Core._Flush = ns.Scheduler.Flush

--- Swap the drawing backend and return the one before: the bench runs the framework against a stub that draws
--- nothing, and the difference is the backend's share. Only while nothing the swapped-out backend drew is mounted
--- below the screen layer's own node.
---@param backend table
---@return table
function Core._SwapBackend(backend)
	local old = ns.Backend
	ns.Backend = backend
	return old
end

-- The bench's own drawing: the top nodes the bench module's instances drew, in tree order (other modules draw on the
-- screen layer too, the Panel say; what they drew isn't the bench's).
local roots = {}

local function TopNodes(instance, n)
	local f = instance._fragment
	local cur = f.cur
	for i = 1, f.n do
		local e = cur[i]
		if e.kind == "comp" then
			if e.instance then
				n = TopNodes(e.instance, n)
			end
		elseif e.kind ~= "frame" and e.node then -- a taken Blizzard frame isn't drawn by us
			n = n + 1
			roots[n] = e.node
		end
	end
	local mounted = instance._mounted
	for i = 1, instance._nMounted do
		n = TopNodes(mounted[i], n)
	end
	return n
end

local function Roots()
	local module = ns.App.Module("OrdaenBench")
	local n = module and module.root and TopNodes(module.root, 0) or 0
	for i = n + 1, #roots do
		roots[i] = nil
	end
	return roots, n
end

--- The texts the bench drew, in tree order, into `out` (the bench checks the framework drew what it was told).
--- Returns how many.
---@param out string[]
---@return integer
function Core._ScreenTexts(out)
	local n = 0
	local function Walk(node)
		if node.kind == "text" then
			n = n + 1
			out[n] = node.fs:GetText()
		end
		local children = node.children
		if children then
			for i = 1, node.count or 0 do
				Walk(children[i])
			end
		end
	end
	local top, count = Roots()
	for i = 1, count do
		Walk(top[i])
	end
	for i = n + 1, #out do
		out[i] = nil
	end
	return n
end

--- The first node of `kind` ("box" or "text") the bench drew, in tree order (the bench's probes inspect a backend
--- node's tables).
---@param kind string
---@return table|nil
function Core._ScreenNode(kind)
	local function Find(node)
		if node.kind == kind then
			return node
		end
		local children = node.children
		if children then
			for i = 1, node.count or 0 do
				local found = Find(children[i])
				if found then
					return found
				end
			end
		end
	end
	local top, count = Roots()
	for i = 1, count do
		local found = Find(top[i])
		if found then
			return found
		end
	end
end

--- Fire a game event into the engine as if the game had sent it (the bench's event bursts).
---@param name string
function Core._FireEvent(name, ...)
	ns.Game.RawEvent(name):Fire(...)
end

--- Every node of `kind` the bench drew, in tree order, into `out` (the bench drives their frames' scripts: a hover
--- without a cursor). Returns how many.
---@param kind string
---@param out table[]
---@return integer
function Core._ScreenNodes(kind, out)
	local n = 0
	local function Walk(node)
		if node.kind == kind then
			n = n + 1
			out[n] = node
		end
		local children = node.children
		if children then
			for i = 1, node.count or 0 do
				Walk(children[i])
			end
		end
	end
	local top, count = Roots()
	for i = 1, count do
		Walk(top[i])
	end
	for i = n + 1, #out do
		out[i] = nil
	end
	return n
end

--- Instances the engine mounts while tracking is on, in a weak-keyed set: what a full collection leaves in it after
--- a close is still referenced from somewhere. Used after a round's measured plan (it wraps Mount while on, so never
--- around a timed call).
local tracked = setmetatable({}, { __mode = "k" })
local mount

---@param on boolean
function Core._TrackInstances(on)
	local Engine = ns.Engine
	if on and not mount then
		mount = Engine.Mount
		Engine.Mount = function(...)
			local instance = mount(...)
			if instance then
				tracked[instance] = true
			end
			return instance
		end
	elseif not on and mount then
		Engine.Mount = mount
		mount = nil
	end
end

--- The tracked instances a full collection left: a description (unmounted ones by component name, and how many are
--- still mounted) and how many unmounted ones are kept.
---@return string, integer
function Core._SurvivingInstances()
	collectgarbage("collect")
	collectgarbage("collect")
	local dead, alive, kept = {}, 0, 0
	for instance in pairs(tracked) do
		if instance._alive then
			alive = alive + 1
		else
			local name = instance._declaration and instance._declaration.name or "?"
			dead[name] = (dead[name] or 0) + 1
			kept = kept + 1
		end
	end
	local parts = {}
	for name, n in pairs(dead) do
		parts[#parts + 1] = name .. " " .. n
	end
	table.sort(parts)
	return string.format("%d mounted; unmounted but kept: %s", alive, #parts > 0 and table.concat(parts, ", ") or "none"),
		kept
end

--- What the engine holds alive on the screen layer, counted by walking it (no hooks, so nothing is added to the
--- timed code): component instances, and draw entries (one per box, text or component call). Fills `out`.
---@param out { instances: integer, entries: integer }
function Core._EngineStats(out)
	local instances, entries = 0, 0
	local WalkInstance
	local function WalkFragment(f)
		local list = f.cur
		for i = 1, f.n or 0 do
			local e = list[i]
			entries = entries + 1
			if e.instance then
				WalkInstance(e.instance)
			end
			if e.kids then
				WalkFragment(e.kids)
			end
		end
	end
	WalkInstance = function(instance)
		instances = instances + 1
		if instance._fragment then
			WalkFragment(instance._fragment)
		end
		for i = 1, instance._nMounted or 0 do
			WalkInstance(instance._mounted[i])
		end
	end
	local place = ns.Game.Layer.Screen
	for i = 1, place.n or 0 do
		local member = place.members[i]
		if member._fragment then
			WalkInstance(member)
		elseif member.cur then
			WalkFragment(member)
		end
	end
	out.instances, out.entries = instances, entries
	return out
end
