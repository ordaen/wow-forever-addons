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

-- The highest frame level in a box's subtree (its own frame and every box under it).
local function deepest(node)
	local top = node.frame:GetFrameLevel()
	for i = 1, node.count or 0 do
		local child = node.children[i]
		if child.kind == "box" then
			local level = deepest(child)
			if level > top then
				top = level
			end
		end
	end
	return top
end

local function overlap(a, b)
	return a.x and b.x and a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

-- Paint order: a positioned box (absolute, fixed) draws over the siblings before it, their children included, where
-- they overlap (the CSS order the design pages draw in). One below a frame of a visible earlier sibling (an XP fill
-- over the tube's ring drawn after it) counts as an order error, and so does one on the same level as an earlier
-- sibling when both draw a background: frames on one level draw in an order WoW picks (a window tab's wood over its
-- rim). An invisible box (an embedded button at opacity 0) neither hides nor is hidden.
local function orderErrors(node, out)
	local children = node.children
	for j = 2, node.count or 0 do
		local later = children[j]
		if later.kind == "box" and (later.pos == "absolute" or later.pos == "fixed") and later.frame:GetAlpha() > 0 then
			local level = later.frame:GetFrameLevel()
			for i = 1, j - 1 do
				local earlier = children[i]
				local deep = earlier.kind == "box" and earlier.frame:GetAlpha() > 0 and overlap(earlier, later)
					and deepest(earlier)
				-- above it, or on its level with both drawing a background (WoW picks which of the two is on top)
				if deep and (deep > level or deep == level and earlier.lookBg ~= nil and later.lookBg ~= nil) then
					out.order_errors = out.order_errors + 1
					break
				end
			end
		end
	end
end

local function walk(node, out)
	local children = node.children
	orderErrors(node, out)
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
	"array", "level_errors", "order_errors" }

--- The backend's nodes now, into `out` (reused by the caller):
--- - live_box, live_text: nodes drawn under a layer; pool_box, pool_text: released nodes waiting in the pools;
---   created_box, created_text: their sums (a node detached but not released is in neither);
--- - hash, hash_slots, array: summed over those nodes and their own tables (attributes, arguments, children,
---   column and row arrays, border edges): hash entries, the hash slots Lua allocates for them (powers of two), and
---   array entries, from table.getcountinfo;
--- - level_errors: live boxes whose frame level isn't above the frame they sit in (0, or they draw under it).
--- - order_errors: live positioned boxes drawn under an earlier sibling's frames where they overlap (0, or a later
---   layer hides under an earlier one's children).
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

-- Inspecting ------------------------------------------------------------------------------------------------------

local format, tostring, concat = string.format, tostring, table.concat

-- A value as text: a theme reference by its path, a colour as its components, a function as "fn".
local function show(v)
	local kind = type(v)
	if kind == "table" then
		local path = rawget(v, "path")
		if path then
			return "@" .. path
		end
		local parts = {}
		for k, x in pairs(v) do
			parts[#parts + 1] = tostring(k) .. "=" .. (type(x) == "table" and "{..}" or tostring(x))
		end
		table.sort(parts)
		return "{" .. concat(parts, ",") .. "}"
	elseif kind == "function" then
		return "fn"
	end
	return tostring(v)
end

local function points(region)
	local list = {}
	for i = 1, region:GetNumPoints() do
		local p, rel, rp, x, y = region:GetPoint(i)
		local relName = rel and (rel:GetName() or (rawget(rel, "node") and "box" or rel:GetObjectType())) or "-"
		list[#list + 1] = format("%s>%s:%s %.1f,%.1f", p, relName, tostring(rp), x or 0, y or 0)
	end
	return concat(list, " ")
end

local function piece(tex)
	local l, t, _, _, _, _, r, b = tex:GetTexCoord()
	return format("%s %.1fx%.1f [%s] coords %.3f,%.3f-%.3f,%.3f", tex:IsShown() and "shown" or "hidden", tex:GetWidth(),
		tex:GetHeight(), points(tex), l, t, r or 0, b or 0)
end

local function label(node)
	local a = node.a or {}
	return format("%s %s %.0fx%.0f", node.kind, show(a.background or a.text or a.position or ""), node.w or 0,
		node.h or 0)
end

--- The windows on every layer, one short string each, for the recorder's snapshot channel (every 2 s while it's
--- ticked): its layer, rect in UI units, strata, level and raise order ("dialog 102,406 1118x601 DIALOG 2 r3").
---@return string
function Core._Layers()
	local out = {}
	for name, layer in pairs(Backend._layers) do
		for i = 1, layer.count or 0 do
			local node = layer.children[i]
			local f = node.frame
			if f and f:IsShown() then
				local l, b = f:GetLeft(), f:GetBottom()
				out[#out + 1] = string.format("%s %s,%s %sx%s %s %d%s", name, l and string.format("%.0f", l) or "?",
					b and string.format("%.0f", b) or "?", string.format("%.0f", f:GetWidth()),
					string.format("%.0f", f:GetHeight()), f:GetFrameStrata(), f:GetFrameLevel(),
					node.raised and (" r" .. node.raised) or "")
			end
		end
	end
	return table.concat(out, "; ")
end

-- One region's numbers for inspect: size, whether shown, points (and the layout's own w x h beside it).
local function fsMetrics(fs)
	local file, height, flags = fs:GetFont()
	return format("width=%.1f height=%.1f string=%.1fx%.1f unbounded=%.1f wordWrap=%s lines=%s maxLines=%s "
		.. "truncated=%s font=%s %s %s", fs:GetWidth(), fs:GetHeight(), fs:GetStringWidth(), fs:GetStringHeight(),
		fs:GetUnboundedStringWidth(), tostring(fs:CanWordWrap()), tostring(fs:GetNumLines()),
		tostring(fs:GetMaxLines()), tostring(fs:IsTruncated()), tostring(file), tostring(height), tostring(flags or ""))
end

--- What the drawing backend knows of `node` (dev mode's inspect): its attributes, layout, real size against the
--- layout's, stacking, art pieces, text metrics, state, parents and children, as plain text fields.
---@param node table
---@return table
function Core._InspectNode(node)
	local out = { kind = node.kind }
	local attrs = {}
	for k, v in pairs(node.a or {}) do
		attrs[#attrs + 1] = k .. "=" .. show(v)
	end
	table.sort(attrs)
	out.attributes = concat(attrs, " ")
	out.layout = format("x=%s y=%s w=%s h=%s placed %sx%s at %s,%s pos=%s", tostring(node.x), tostring(node.y),
		tostring(node.w), tostring(node.h), tostring(node.pW), tostring(node.pH), tostring(node.pX), tostring(node.pY),
		tostring(node.pos))
	local obj = node.frame or node.fs
	if obj then
		local w, h = obj:GetWidth(), obj:GetHeight()
		out.frame = format("%.1fx%.1f [%s] shown=%s visible=%s alpha=%.2f", w, h, points(obj), tostring(obj:IsShown()),
			tostring(obj:IsVisible()), obj:GetAlpha())
		-- the real size against the layout's: any difference is a box model bug
		local lw, lh = node.pW or node.w, node.pH or node.h
		if lw and lh and (math.abs(w - lw) > 0.05 or math.abs(h - lh) > 0.05) then
			out.mismatch = format("drawn %.2fx%.2f, laid out %.2fx%.2f", w, h, lw, lh)
		end
	end
	if node.frame then
		local f = node.frame
		out.stack = format("%s/%d depth=%s z=%s mouse=%s click=%s", f:GetFrameStrata(), f:GetFrameLevel(),
			tostring(node.depth), tostring(node.lookZ), tostring(f:IsMouseEnabled()),
			tostring(f.IsMouseClickEnabled and f:IsMouseClickEnabled()))
	end
	out.state = format("hovered=%s pressed=%s states=%s", tostring(node.hovered), tostring(node.pressed),
		tostring(node.states))
	if node.bg then
		out.bg = piece(node.bg)
	end
	for i, tex in ipairs(node.slices or {}) do
		out["slice" .. i] = piece(tex)
	end
	for i, tex in ipairs(node.glows or {}) do
		out["glow" .. i] = piece(tex)
	end
	for i, tex in ipairs(node.edges or {}) do
		if type(tex) == "table" and tex.GetTexCoord then
			out["edge" .. i] = piece(tex)
		end
	end
	if node.fs then
		out.text = format("%q size=%s", tostring(node.fs:GetText()), tostring(node.fontSize))
		out.textMetrics = fsMetrics(node.fs)
		out.textLayout = format("natW=%s minW=%s lineH=%s mW=%s mH=%s w=%s h=%s", tostring(node.natW),
			tostring(node.minW), tostring(node.lineH), tostring(node.mW), tostring(node.mH), tostring(node.w),
			tostring(node.h))
	end
	local chain, parent = {}, node.parent
	while parent and #chain < 12 do
		chain[#chain + 1] = label(parent)
		parent = parent.parent
	end
	out.parents = concat(chain, " < ")
	local kids = {}
	for i = 1, node.count or 0 do
		kids[i] = label(node.children[i])
	end
	out.children = concat(kids, " | ")
	return out
end

--- The box behind `frame`, or nil for a frame that isn't one of ours.
---@param frame table
---@return table?
function Core._NodeOf(frame)
	local node = type(frame) == "table" and rawget(frame, "node")
	return type(node) == "table" and type(node.a) == "table" and node or nil
end

--- What the drawing backend knows of the box behind `frame`; nil for a frame that isn't one of ours.
---@param frame table
---@return table?
function Core._Inspect(frame)
	local node = Core._NodeOf(frame)
	return node and Core._InspectNode(node)
end

-- Is the cursor (x, y in UI units) inside this node's drawn region?
local function contains(node, x, y)
	local obj = node.frame or node.fs
	if not obj or not obj:IsVisible() then
		return false
	end
	local l, b, w, h = obj:GetRect()
	return l and x >= l and x <= l + w and y >= b and y <= b + h
end

--- The deepest box under the cursor from `node` down (texts and art boxes too, which take no mouse), the later
--- sibling first, as it's drawn over the earlier.
---@param node table
---@param x number UI units
---@param y number
---@return table
function Core._NodeAt(node, x, y)
	for i = node.count or 0, 1, -1 do
		local child = node.children[i]
		if child and contains(child, x, y) then
			return Core._NodeAt(child, x, y)
		end
	end
	return node
end

--- A short line for a box: its kind, its text or background, its size.
---@param node table
---@return string
function Core._Label(node)
	return label(node)
end
