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

--- The texts drawn on the screen layer, in tree order, into `out` (the bench checks the framework drew what it was
--- told). Returns how many.
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
	Walk(ns.Game.Layer.Screen.node)
	for i = n + 1, #out do
		out[i] = nil
	end
	return n
end

--- The first drawn node of `kind` ("box" or "text") on the screen layer, in tree order (the bench's probes inspect a
--- backend node's tables).
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
	local layer = ns.Game.Layer.Screen.node -- the layer itself isn't one of the drawn nodes
	for i = 1, layer.count or 0 do
		local found = Find(layer.children[i])
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

--- Every drawn node of `kind` on the screen layer, in tree order, into `out` (the bench drives their frames' scripts:
--- a hover without a cursor). Returns how many.
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
	local layer = ns.Game.Layer.Screen.node
	for i = 1, layer.count or 0 do
		Walk(layer.children[i])
	end
	for i = n + 1, #out do
		out[i] = nil
	end
	return n
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
