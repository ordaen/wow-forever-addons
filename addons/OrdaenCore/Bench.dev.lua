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
