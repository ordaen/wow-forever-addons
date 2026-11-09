-- Dev-only: the drawing backend's node counts, for the benchmark module (OrdaenBench reads them before and after an
-- open to see what reopening a window allocates). Release builds leave out *.dev.lua, so players never get it, and
-- nothing here runs unless the bench calls it. Untimed: it walks every node.
local _, ns = ...

local Backend, Core = ns.Backend, ns.Core
local getcountinfo, rawget, type, ipairs, pairs = table.getcountinfo, rawget, type, ipairs, pairs

-- A node's own tables, measured with it.
local OWN_TABLES = { "a", "args", "children", "colKind", "colAmount", "colW", "colX", "rowH", "rowY", "edges", "cCol",
	"cRow", "cSpan", "cW", "cTw", "cTh", "cGiven" }

-- Hash slots Lua allocates for `n` hash entries: the next power of two.
local function slots(n)
	local s = 1
	while s < n do
		s = s * 2
	end
	return n > 0 and s or 0
end

local function measure(t, out)
	local entries, integers = getcountinfo(t)
	local hash = entries - integers
	out.hash = out.hash + hash
	out.hash_slots = out.hash_slots + slots(hash)
	out.array = out.array + integers
end

local function count(node, out)
	measure(node, out)
	for _, key in ipairs(OWN_TABLES) do
		local t = rawget(node, key)
		if type(t) == "table" then
			measure(t, out)
		end
	end
end

local function walk(node, out)
	local children = node.children
	for i = 1, node.count or 0 do
		local child = children[i]
		if child.kind == "text" then
			out.live_text = out.live_text + 1
		else
			out.live_box = out.live_box + 1
			-- a box must draw above the frame it sits in (Backend.lua sets a level only when it isn't)
			if child.frame:GetFrameLevel() <= node.frame:GetFrameLevel() then
				out.level_errors = out.level_errors + 1
			end
		end
		count(child, out)
		walk(child, out)
	end
end

local FIELDS = { "created_box", "created_text", "live_box", "live_text", "pool_box", "pool_text", "hash", "hash_slots",
	"array", "level_errors" }

--- The backend's nodes now, into `out` (reused by the caller):
--- - live_box, live_text: nodes drawn under a layer; pool_box, pool_text: released nodes waiting in the pools;
---   created_box, created_text: their sums (a node detached but not released is in neither);
--- - hash, hash_slots, array: summed over those nodes and their own tables (attributes, arguments, children,
---   column and row arrays, border edges): hash entries, the hash slots Lua allocates for them (powers of two), and
---   array entries, from table.getcountinfo;
--- - level_errors: live boxes whose frame level isn't above the frame they sit in (0, or they draw under it).
---@param out table
---@return table out
function Core._BackendStats(out)
	for _, field in ipairs(FIELDS) do
		out[field] = 0
	end
	for _, layer in pairs(Backend._layers) do
		walk(layer, out)
	end
	for _, node in ipairs(Backend._boxPool) do
		out.pool_box = out.pool_box + 1
		count(node, out)
	end
	for _, node in ipairs(Backend._textPool) do
		out.pool_text = out.pool_text + 1
		count(node, out)
	end
	out.created_box = out.live_box + out.pool_box
	out.created_text = out.live_text + out.pool_text
	return out
end
