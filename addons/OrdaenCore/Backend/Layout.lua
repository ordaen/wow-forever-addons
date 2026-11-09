-- The drawing backend's layout (development/framework/box, "The renderer"): where every box and text goes. Pure Lua
-- (no WoW API), so busted specs drive it with a fake text measurer (tests/OrdaenCore/layout_spec.lua).
--
-- It works on node tables. Layout.Apply fills these fields from a node's attributes when they change (the backend
-- passes its resolver for theme references and per-state maps); Layout.ATTRIBUTES lists which attribute fills which:
--   kind                      "box", "text" or "root" (a layer or a taken Blizzard frame: w and h come from WoW)
--   parent, children, count   the tree; children is an array, count its length; a child's place in its parent's grid
--                             is kept by the parent, in arrays indexed by the child's position (child.idx): cCol,
--                             cRow, cSpan, cW (cell width), cTw, cTh, cGiven (its size there and the height it was
--                             given); a box with one child in one column keeps none (the child is in column 1)
--   wKind, wAmount            width: "fixed" (amount in UI units), "auto" (content), "pct" (amount 0..1 of the
--   hKind, hAmount            parent's content box), "fill" (the cell), nil (stretch in its cell, unless the parent's
--                             xAlign places it; heights: content, stretched to the row by the parent's yAlign)
--   ncols, colKind, colAmount the grid's tracks: "fixed" | "auto" | "fr" (amount = weight)
--   gapC, gapR, padT, padR, padB, padL   gaps and padding (padding sits inside the border)
--   bwT, bwR, bwB, bwL        the border's width on each side: its width on the sides it names, 0 on the others
--   span                      columns covered in the parent's grid
--   xAlign, yAlign            "start" | "center" | "end" | "stretch" | "spaceBetween" | "spaceAround" | nil
--   pos                       "flow" | "absolute" | "fixed" (nil = flow); offL, offR, offT, offB its offsets
--   text: natW, lineH, wrap   its width on one line and that line's height (the backend measures them), wrap false
--                             keeps it on one line
-- and writes back x, y, w, h: the node's rectangle relative to its parent's top-left corner (y downwards). Once a
-- Relayout has computed every rectangle, it calls ctx.place(node) for those that changed, walking the tree from the
-- top, so a parent is always placed before its children (measuring a child's natural height lays it out early, and
-- only the walk decides the order). Free nodes (absolute, fixed, a root's children) are placed by their offsets,
-- centred without any; fixed ones relative to the screen (ctx.screenW, ctx.screenH).
--
-- Two passes per box, like CSS grid: column widths (fixed, then auto = widest content, then fr shares of what is left;
-- too little room shrinks auto columns, never below 8), then row heights from content wrapped to those widths. Results
-- are cached on the nodes (natural width, height at a width, the last layout's width and height), so laying out a
-- tree again visits only what Layout.Invalidate marked; nothing allocates.
local _, ns = ...

---@class OrdaenLayoutContext
---@field measure fun(node: table, width: number): number   -- a text node's height wrapped to width
---@field place fun(node: table)                             -- the node's x, y, w or h changed
---@field screenW number
---@field screenH number

local Layout = {}
ns.Layout = Layout

local MIN_COLUMN = 8 -- a column never shrinks below this

local floor, max, min, tonumber, type = math.floor, math.max, math.min, tonumber, type

-- Parsed size strings, so a Set never builds a string twice ("50%", "1fr" are constants in practice).
local sizeKind, sizeAmount = {}, {}

---A size attribute as kind and amount: 24 -> "fixed", 24; "auto"; "50%" -> "pct", 0.5; "1fr" -> "fill" (a size)
---or "fr", 1 (a column track, `track` true). nil stays nil (the default). Unknown strings read as "auto".
---@param value any
---@param track boolean?
---@return string? kind
---@return number amount
function Layout.Size(value, track)
	if value == nil then
		return nil, 0
	elseif type(value) == "number" then
		return "fixed", value
	end
	local kind = sizeKind[value]
	if not kind then
		kind, sizeAmount[value] = "auto", 0
		if type(value) == "string" then
			local pct = tonumber(value:match("^(%d*%.?%d+)%%$"))
			local fr = tonumber(value:match("^(%d*%.?%d+)fr$"))
			if pct then
				kind, sizeAmount[value] = "pct", pct / 100
			elseif fr then
				kind, sizeAmount[value] = "fr", fr
			end
		end
		sizeKind[value] = kind
	end
	if kind == "fr" and not track then
		return "fill", 1
	end
	return kind, sizeAmount[value]
end

---Fill node.ncols, node.colKind, node.colAmount from a `columns` attribute: a list of track sizes, a number (that
---many 1fr tracks) or nil (one 1fr track). `resolve` turns a theme reference in the list into its value.
---@param node table
---@param columns any
---@param resolve fun(value: any): any
function Layout.Columns(node, columns, resolve, px)
	local kinds, amounts = node.colKind, node.colAmount
	if not kinds then
		kinds, amounts = {}, {}
		node.colKind, node.colAmount = kinds, amounts
	end
	local n
	if type(columns) == "table" then
		n = #columns
		for c = 1, n do
			kinds[c], amounts[c] = Layout.Size(resolve(columns[c]), true)
			if kinds[c] == "pct" then
				kinds[c] = "auto"
			elseif kinds[c] == "fixed" and px then
				amounts[c] = floor(amounts[c] / px + 0.5) * px
			end
		end
	else
		n = type(columns) == "number" and columns >= 1 and floor(columns) or 1
		for c = 1, n do
			kinds[c], amounts[c] = "fr", 1
		end
	end
	if n == 0 then
		n, kinds[1], amounts[1] = 1, "fr", 1
	end
	node.ncols = n
end

---The layout attributes, in one place: what a change to each invalidates (`group`), the node fields Layout.Apply
---fills from it, and whether a text node takes it (`text`). The backend builds its attribute groups and key lists from
---this list, and the layout spec checks that Apply reads every entry.
Layout.ATTRIBUTES = {
	{ key = "width", group = "own", text = true, fields = { "wKind", "wAmount" } },
	{ key = "height", group = "own", fields = { "hKind", "hAmount" } },
	{ key = "columnSpan", group = "own", text = true, fields = { "span" } },
	{ key = "position", group = "position", text = true, fields = { "pos" } },
	{ key = "top", group = "offset", text = true, fields = { "offT" } },
	{ key = "right", group = "offset", text = true, fields = { "offR" } },
	{ key = "bottom", group = "offset", text = true, fields = { "offB" } },
	{ key = "left", group = "offset", text = true, fields = { "offL" } },
	{ key = "columns", group = "content", fields = { "ncols" } },
	{ key = "gap", group = "content", fields = { "gapR", "gapC" } },
	{ key = "padding", group = "content", fields = { "padT", "padR", "padB", "padL" } },
	{ key = "xAlign", group = "content", fields = { "xAlign" } },
	{ key = "yAlign", group = "content", fields = { "yAlign" } },
	{ key = "border", group = "border", fields = { "bwT", "bwR", "bwB", "bwL" } },
}

-- A length on whole pixels (px: one pixel in UI units), so sums of sizes, gaps and padding stay on the pixel grid
-- and equal steps stay equal on screen.
local function pixels(v, px)
	return floor(v / px + 0.5) * px
end

-- The Apply* functions fill the layout fields of `node` from its attributes `a`, one attribute group each (the groups
-- of Layout.ATTRIBUTES), so a change touches only its own group. `resolve(node, v)` turns a theme reference or
-- per-state map into its value now, `resolveRef(v)` a theme reference inside a list; `px` is one screen pixel in UI
-- units. Fixed sizes, gaps, padding and border widths land on whole pixels (a border at least one).

---The "own" and "position" groups: size, span and position.
function Layout.ApplySize(node, a, resolve, px)
	local wk, wa = Layout.Size(resolve(node, a.width))
	local hk, ha = Layout.Size(resolve(node, a.height))
	node.wKind, node.wAmount = wk, wk == "fixed" and pixels(wa, px) or wa
	node.hKind, node.hAmount = hk, hk == "fixed" and pixels(ha, px) or ha
	node.span = resolve(node, a.columnSpan)
	node.pos = resolve(node, a.position)
end

---The "offset" group.
-- An offset is a number of UI units; anything else is left out (as if unset) and named to the caller.
local OFFSETS = { "top", "right", "bottom", "left" }
local OFFSET_FIELDS = { top = "offT", right = "offR", bottom = "offB", left = "offL" }

---Returns the first offset that isn't a number (its attribute's name and value), or nothing: the caller reports it.
function Layout.ApplyOffsets(node, a, resolve)
	local badKey, badValue
	for i = 1, 4 do
		local key = OFFSETS[i]
		local v = resolve(node, a[key])
		if v ~= nil and type(v) ~= "number" then
			if not badKey then
				badKey, badValue = key, v
			end
			v = nil
		end
		node[OFFSET_FIELDS[key]] = v
	end
	return badKey, badValue
end

-- A border's sides: every side, or those its `sides` list names ("top", "right", "bottom", "left").
local function hasSide(sides, name)
	if sides == nil then
		return true
	end
	for i = 1, #sides do
		if sides[i] == name then
			return true
		end
	end
	return false
end

---The "border" group: the border's width on each side (a box's only).
function Layout.ApplyBorder(node, a, resolve, resolveRef, px)
	if node.kind ~= "box" then
		return
	end
	local border = resolve(node, a.border)
	local bw = type(border) == "table" and resolveRef(border.width) or 0
	bw = bw > 0 and max(px, pixels(bw, px)) or 0
	local sides = bw > 0 and border.sides or nil
	node.bwT = hasSide(sides, "top") and bw or 0
	node.bwR = hasSide(sides, "right") and bw or 0
	node.bwB = hasSide(sides, "bottom") and bw or 0
	node.bwL = hasSide(sides, "left") and bw or 0
end

---Every group at once.
---@param node table
---@param a table
---@param resolve fun(node: table, v: any): any
---@param resolveRef fun(v: any): any
---@param px number
function Layout.Apply(node, a, resolve, resolveRef, px)
	Layout.ApplySize(node, a, resolve, px)
	local badKey, badValue = Layout.ApplyOffsets(node, a, resolve)
	Layout.ApplyContent(node, a, resolve, resolveRef, px)
	Layout.ApplyBorder(node, a, resolve, resolveRef, px)
	return badKey, badValue
end

---The "content" group: the grid of a box's children (a box's only).
function Layout.ApplyContent(node, a, resolve, resolveRef, px)
	if node.kind ~= "box" then
		return
	end
	Layout.Columns(node, resolve(node, a.columns), resolveRef, px)
	local gap = resolve(node, a.gap)
	if type(gap) == "table" then
		node.gapR, node.gapC = pixels(resolveRef(gap[1]) or 0, px), pixels(resolveRef(gap[2]) or 0, px)
	else
		gap = pixels(gap or 0, px)
		node.gapR, node.gapC = gap, gap
	end
	local pad = resolve(node, a.padding)
	if type(pad) == "table" then
		node.padT, node.padR = pixels(resolveRef(pad[1]) or 0, px), pixels(resolveRef(pad[2]) or 0, px)
		node.padB, node.padL = pixels(resolveRef(pad[3]) or 0, px), pixels(resolveRef(pad[4]) or 0, px)
	else
		pad = pixels(pad or 0, px)
		node.padT, node.padR, node.padB, node.padL = pad, pad, pad, pad
	end
	node.xAlign, node.yAlign = resolve(node, a.xAlign), resolve(node, a.yAlign)
end

-- Whether a node sits outside its parent's grid. Inside a box's own loops (assignCells, boxNatural, layoutBox) the
-- parent is a box, so there it is only its position, tested inline (a call per child per pass is measurable).
local function isFree(node)
	local pos = node.pos
	if pos == "absolute" or pos == "fixed" then
		return true
	end
	local parent = node.parent
	return parent ~= nil and parent.kind == "root"
end

-- Items stretch across their cell unless the parent places them.
local function placed(align)
	return align == "start" or align == "center" or align == "end"
end

-- A box whose size never depends on its content: a change inside it stays inside it. Only a fixed height counts (a
-- stretched one is its row's, and the row takes its content's height); a default width counts for nothing either,
-- since an auto column takes its content's width.
local function ownSize(node)
	local wk = node.wKind
	return node.kind == "box" and node.hKind == "fixed" and (wk == "fixed" or wk == "pct" or wk == "fill")
end

---Mark `node` as changed: its cached sizes and its ancestors' up to the first one whose size can't change because
---of it. Returns that node, which Layout.Relayout lays out again (nil while the node isn't attached).
---`own` says the node's own size, span or offsets changed, so its parent's grid changes too.
---@param node table
---@param own boolean?
---@return table?
function Layout.Invalidate(node, own)
	if own then
		node.natValid, node.valid = false, false
		if node.kind == "root" then
			return node
		end
		local parent = node.parent
		if parent == nil then
			return nil
		elseif isFree(node) then
			return node
		end
		node = parent
	end
	while true do
		node.natValid, node.valid = false, false
		if node.kind == "root" then
			return node
		end
		local parent = node.parent
		if parent == nil then
			return nil
		elseif isFree(node) or ownSize(node) then
			return node
		end
		node = parent
	end
end

---A node's offsets changed. Returns what to lay out again: the node itself, placed again with its cached size, when
---it's free; nothing for a flow node (offsets don't apply to it). Offsets that size it (left and right, or top and
---bottom, with no width or height) change its size: then it's invalidated like a size change.
---@param node table
---@return table?
function Layout.Offsets(node)
	if node.kind == "root" or not isFree(node) then
		return nil
	end
	if (node.wKind == nil and node.offL and node.offR) or (node.hKind == nil and node.offT and node.offB) then
		return Layout.Invalidate(node, true)
	end
	return node
end

-- The columns a flow child's cell spans in its parent (first, last), or nil when that isn't known. A box laid out
-- by `single` (one child, one column) keeps no cell arrays: its child, idx 1, spans column 1.
local function cellColumns(parent, node)
	local idx = node.idx
	if not idx then
		return nil
	end
	local cCol = parent.cCol
	if cCol then
		local col = cCol[idx]
		return col, col + parent.cSpan[idx] - 1
	elseif idx == 1 and parent.count == 1 then
		return 1, 1
	end
	return nil
end

-- Whether a box's width is set from outside (its attributes, or a cell whose width no content decides).
local function widthGiven(node)
	while true do
		local wk = node.wKind
		if wk == "fixed" or wk == "pct" or wk == "fill" then
			return true
		elseif wk == "auto" or node.kind ~= "box" or isFree(node) then
			return false
		end
		local parent = node.parent
		if parent == nil or placed(parent.xAlign) then
			return false
		end
		local first, last = cellColumns(parent, node)
		if not first then
			return false
		end
		local kinds = parent.colKind
		for c = first, last do
			if kinds[c] ~= "fr" and kinds[c] ~= "fixed" then
				return false
			end
		end
		node = parent
	end
end

---Whether a text node's new size (natW, lineH; the old ones given) changes any layout. Text that keeps its line height
---and stays on one line in a cell no content sizes changes nothing: its rectangle stays the cell's.
---@param node table
---@param oldW number?
---@param oldH number?
---@return boolean
function Layout.TextResized(node, oldW, oldH)
	local natW, w = node.natW, node.w
	if natW == oldW and node.lineH == oldH then
		return false
	elseif w == nil or node.lineH ~= oldH or natW > w or (oldW or 0) > w then
		return true -- not laid out yet, another line height, or wrapping before or after
	end
	local parent = node.parent
	if parent == nil or isFree(node) or node.wrap == false or node.wKind ~= nil or placed(parent.xAlign) then
		return true
	end
	local first, last = cellColumns(parent, node)
	if not first then
		return true
	end
	local kinds = parent.colKind
	for c = first, last do
		if kinds[c] ~= "fr" and kinds[c] ~= "fixed" then
			return true
		end
	end
	return not widthGiven(parent)
end

-- The parent's arrays for its children's cells (made on first use).
local function cells(node)
	local cCol = node.cCol
	if not cCol then
		cCol = {}
		node.cCol, node.cRow, node.cSpan, node.cW, node.cTw, node.cTh, node.cGiven = cCol, {}, {}, {}, {}, {}, {}
	end
	return cCol, node.cRow, node.cSpan
end

-- Flow children into cells, reading order, wrapping when a span doesn't fit the row. Returns the number of rows.
local function assignCells(node)
	local children, n = node.children, node.ncols or 1
	local cCol, cRow, cSpan = cells(node)
	local col, row, rows = 1, 1, 0
	for i = 1, node.count or 0 do
		local child = children[i]
		if child.pos ~= "absolute" and child.pos ~= "fixed" then
			local span = child.span or 1
			if span > n then
				span = n
			elseif span < 1 then
				span = 1
			end
			if col + span - 1 > n then
				col, row = 1, row + 1
			end
			child.idx, cCol[i], cRow[i], cSpan[i] = i, col, row, span
			rows = row
			col = col + span
			if col > n then
				col, row = 1, row + 1
			end
		end
	end
	return rows
end

local function scratch(node)
	local colW = node.colW
	if not colW then
		colW = {}
		node.colW, node.colX, node.rowH, node.rowY = colW, {}, {}, {}
	end
	return colW, node.colX, node.rowH, node.rowY
end

-- Spread `amount` over columns first..last of `kind` (by weight for fr, evenly otherwise).
local function grow(node, first, last, kind, amount)
	local kinds, amounts, colW = node.colKind, node.colAmount, node.colW
	local total = 0
	for c = first, last do
		if kinds[c] == kind then
			total = total + (kind == "fr" and amounts[c] or 1)
		end
	end
	if total == 0 then
		return false
	end
	for c = first, last do
		if kinds[c] == kind then
			colW[c] = colW[c] + amount * (kind == "fr" and amounts[c] or 1) / total
		end
	end
	return true
end

-- Take up to `amount` from columns of `kind`, in proportion to their width, never below MIN_COLUMN.
local function shrink(node, n, kind, amount)
	local kinds, colW = node.colKind, node.colW
	local room = 0
	for c = 1, n do
		if kinds[c] == kind then
			room = room + max(0, colW[c] - MIN_COLUMN)
		end
	end
	if room <= 0 then
		return amount
	end
	local take = min(amount, room)
	for c = 1, n do
		if kinds[c] == kind then
			colW[c] = colW[c] - take * max(0, colW[c] - MIN_COLUMN) / room
		end
	end
	return amount - take
end

local natural -- forward

-- Natural (max-content) width of a box: its tracks at their content's width, fr tracks at one shared unit.
local function boxNatural(node)
	local n = node.ncols or 1
	local kinds, amounts = node.colKind, node.colAmount
	local children = node.children
	if n == 1 and node.count == 1 and children[1].pos ~= "absolute" and children[1].pos ~= "fixed" then
		-- one child in one column (cells, wrappers, nested levels): its natural width, or the fixed track's
		local v = kinds[1] == "fixed" and amounts[1] or natural(children[1])
		return v + node.padL + node.padR + node.bwL + node.bwR
	end
	local colW = scratch(node)
	assignCells(node)
	local cCol, cSpan = node.cCol, node.cSpan
	for c = 1, n do
		colW[c] = kinds[c] == "fixed" and amounts[c] or 0
	end
	for i = 1, node.count or 0 do
		local child = children[i]
		if child.pos ~= "absolute" and child.pos ~= "fixed" and cSpan[i] == 1 and kinds[cCol[i]] ~= "fixed" then
			colW[cCol[i]] = max(colW[cCol[i]], natural(child))
		end
	end
	local unit = 0
	for c = 1, n do
		if kinds[c] == "fr" then
			unit = max(unit, colW[c] / amounts[c])
		end
	end
	for c = 1, n do
		if kinds[c] == "fr" then
			colW[c] = unit * amounts[c]
		end
	end
	for i = 1, node.count or 0 do
		local child = children[i]
		if child.pos ~= "absolute" and child.pos ~= "fixed" and cSpan[i] > 1 then
			local col = cCol[i]
			local last = col + cSpan[i] - 1
			local have = node.gapC * (cSpan[i] - 1)
			for c = col, last do
				have = have + colW[c]
			end
			local need = natural(child) - have
			if need > 0 and not grow(node, col, last, "fr", need) and not grow(node, col, last, "auto", need) then
				colW[last] = colW[last] + need
			end
		end
	end
	local sum = node.gapC * (n - 1) + node.padL + node.padR + node.bwL + node.bwR
	for c = 1, n do
		sum = sum + colW[c]
	end
	return sum
end

---The width a node takes on its own, without wrapping.
function natural(node)
	local wk = node.wKind
	if wk == "fixed" then
		return node.wAmount
	elseif wk == "pct" or wk == "fill" then
		return 0
	elseif node.kind == "text" then
		return node.natW
	end
	if not node.natValid then
		node.natCache, node.natValid = boxNatural(node), true
	end
	return node.natCache
end

-- A text node's height at width w.
local function textHeight(node, w, ctx)
	if node.wrap == false or node.natW <= w then
		return node.lineH
	end
	if node.mW ~= w then
		node.mW, node.mH = w, ctx.measure(node, w)
	end
	return node.mH
end

-- Which Relayout laid a box out last: the placing walk goes into a box only if this one did.
local pass = 0

local function setRect(node, x, y, w, h)
	if node.x ~= x or node.y ~= y or node.w ~= w or node.h ~= h then
		node.x, node.y, node.w, node.h = x, y, w, h
		node.moved = true
	end
end

-- Place what moved, parents first: down from `node` through the boxes this pass laid out.
local function commit(node, ctx)
	if node.moved then
		node.moved = false
		ctx.place(node)
	end
	if node.pass == pass then
		local children = node.children
		for i = 1, node.count or 0 do
			commit(children[i], ctx)
		end
	end
end

local layoutBox -- forward

-- A box's height at width w when nothing gives it one: from the cache, or by laying it out.
local function autoHeight(node, w, ctx)
	if node.valid and node.nhW == w then
		return node.nhH
	end
	return layoutBox(node, w, nil, ctx)
end

-- Make sure the last layout of `node` is the one at (w, h), so its children sit where they belong. node.lh is the
-- height it was last laid out at; a box given exactly its natural height lays out as it did without one (unless a
-- child's height is a percentage, which only a given height sizes), so that isn't done twice.
local function finalize(node, w, h, ctx)
	if node.valid and node.lw == w then
		if h == nil then
			if node.nhW == w and node.lh == node.nhH then
				return
			end
		elseif node.lh == h and (node.lgiven or not node.pctH) then
			return
		end
	end
	layoutBox(node, w, h, ctx)
end

-- Place a free node in a reference box (its parent's border box, or the screen for "fixed").
local function placeFree(node, refW, refH, ctx)
	if node.pos == "fixed" then
		refW, refH = ctx.screenW, ctx.screenH
	end
	local l, r, t, b = node.offL, node.offR, node.offT, node.offB
	local wk, hk = node.wKind, node.hKind
	local w
	if wk == "fixed" then
		w = node.wAmount
	elseif wk == "pct" then
		w = node.wAmount * refW
	elseif wk == "fill" then
		w = refW
	elseif wk == nil and l and r then
		w = refW - l - r
	elseif node.kind == "text" and node.wrap == false then
		w = node.natW
	else
		w = min(natural(node), refW)
	end
	local h
	if node.kind == "text" then
		h = textHeight(node, w, ctx)
	else
		local given
		if hk == "fixed" then
			given = node.hAmount
		elseif hk == "pct" then
			given = node.hAmount * refH
		elseif hk == "fill" then
			given = refH
		elseif hk == nil and t and b then
			given = refH - t - b
		end
		h = given or autoHeight(node, w, ctx)
		local x = l or (r and refW - r - w) or floor((refW - w) / 2 + 0.5)
		local y = t or (b and refH - b - h) or floor((refH - h) / 2 + 0.5)
		setRect(node, x, y, w, h)
		finalize(node, w, given, ctx)
		return
	end
	local x = l or (r and refW - r - w) or floor((refW - w) / 2 + 0.5)
	local y = t or (b and refH - b - h) or floor((refH - h) / 2 + 0.5)
	setRect(node, x, y, w, h)
end

-- Size a flow child in its cell: width from its attributes, height at that width (given, or its content's).
-- Returns w, h and the height it was given (nil: its content decides).
local function sizeIn(child, cellW, parent, contentW, contentH, ctx)
	local wk = child.wKind
	local w
	if wk == "fixed" then
		w = child.wAmount
	elseif wk == "pct" then
		w = child.wAmount * contentW
	elseif wk == "fill" then
		w = cellW
	elseif wk == "auto" or placed(parent.xAlign) then
		if child.kind == "text" and child.wrap == false then
			w = child.natW
		else
			w = min(natural(child), cellW)
		end
	elseif child.kind == "text" and child.wrap == false then
		w = max(child.natW, cellW)
	else
		w = cellW
	end
	if child.kind == "text" then
		return w, textHeight(child, w, ctx), nil
	end
	local hk, given = child.hKind, nil
	if hk == "fixed" then
		given = child.hAmount
	elseif hk == "pct" and contentH then
		given = child.hAmount * contentH
	end
	return w, given or autoHeight(child, w, ctx), given
end

-- layoutBox for one flow child in one fr column (cells, wrappers, nested levels): the same result as the grid's
-- general path, computed directly. The cell is the content box (at least MIN_COLUMN), the one row is the child's
-- height.
local function single(node, child, W, H, padT, padB, padL, contentW, contentH, ctx)
	local cellW = contentW >= MIN_COLUMN and contentW or MIN_COLUMN
	child.idx = 1
	local cCol = node.cCol
	if cCol then -- arrays from a grid it laid out before stay true for whoever reads them
		cCol[1], node.cRow[1], node.cSpan[1], node.cW[1] = 1, 1, 1, cellW
	end
	local w, h, given = sizeIn(child, cellW, node, contentW, contentH, ctx)
	local ya = node.yAlign
	local y = padT
	if contentH then
		local free = contentH - h
		if free > 0 then
			if ya == "center" then
				y = y + floor(free / 2 + 0.5)
			elseif ya == "end" then
				y = y + free
			elseif ya == "spaceAround" then
				y = y + free / 2
			end
		end
	end
	local x = padL
	local free = cellW - w
	if free > 0 then
		local xa = node.xAlign
		if xa == "center" then
			x = x + floor(free / 2 + 0.5)
		elseif xa == "end" then
			x = x + free
		end
	end
	local box = child.kind == "box"
	if box and (child.hKind == "fill" or (child.hKind == nil and not placed(ya))) then
		given = h -- stretched to its row, which is its own height
	end
	setRect(child, x, y, w, h)
	if box then
		finalize(child, w, given, ctx)
	end
	local outH = H or (padT + h + padB)
	if H == nil then
		node.nhW, node.nhH = W, outH
	end
	node.lw, node.lh, node.lgiven, node.pctH, node.valid = W, outH, H ~= nil, child.hKind == "pct", true
	return outH
end

-- Lay out a box's children at outer width W and, when given, outer height H. Returns its outer height.
function layoutBox(node, W, H, ctx)
	node.pass = pass
	local n = node.ncols or 1
	local kinds = node.colKind
	local padT, padR, padB, padL = node.padT + node.bwT, node.padR + node.bwR, node.padB + node.bwB, node.padL + node.bwL
	local gapC, gapR = node.gapC, node.gapR
	local children, count = node.children, node.count or 0
	local contentW = W - padL - padR
	local contentH = H and H - padT - padB or nil
	local only = children[1]
	if n == 1 and count == 1 and kinds[1] == "fr" and only.pos ~= "absolute" and only.pos ~= "fixed" then
		return single(node, children[1], W, H, padT, padB, padL, contentW, contentH, ctx)
	end
	local colW, colX, rowH, rowY = scratch(node)
	local rows = assignCells(node)
	local cCol, cRow, cSpan = node.cCol, node.cRow, node.cSpan
	local cW, cTw, cTh, cGiven = node.cW, node.cTw, node.cTh, node.cGiven

	-- Pass 1: column widths.
	local amounts = node.colAmount
	for c = 1, n do
		colW[c] = kinds[c] == "fixed" and amounts[c] or 0
	end
	for i = 1, count do
		local child = children[i]
		if child.pos ~= "absolute" and child.pos ~= "fixed" and cSpan[i] == 1 and kinds[cCol[i]] == "auto" then
			colW[cCol[i]] = max(colW[cCol[i]], natural(child))
		end
	end
	for i = 1, count do
		local child = children[i]
		if child.pos ~= "absolute" and child.pos ~= "fixed" and cSpan[i] > 1 then
			local col = cCol[i]
			local last = col + cSpan[i] - 1
			local have = gapC * (cSpan[i] - 1)
			local hasFr = false
			for c = col, last do
				have = have + colW[c]
				hasFr = hasFr or kinds[c] == "fr"
			end
			local need = natural(child) - have
			if need > 0 and not hasFr and not grow(node, col, last, "auto", need) then
				colW[last] = colW[last] + need
			end
		end
	end
	local sum = 0
	for c = 1, n do
		sum = sum + colW[c]
	end
	local extra = contentW - gapC * (n - 1) - sum
	local offset, spread = 0, 0
	if extra > 0 then
		if not grow(node, 1, n, "fr", extra) then
			local xa = node.xAlign
			if xa == "center" then
				offset = floor(extra / 2 + 0.5)
			elseif xa == "end" then
				offset = extra
			elseif xa == "spaceBetween" then
				spread = n > 1 and extra / (n - 1) or 0
			elseif xa == "spaceAround" then
				spread = extra / n
				offset = spread / 2
			elseif xa ~= "start" then
				grow(node, 1, n, "auto", extra)
			end
		end
	elseif extra < 0 then
		shrink(node, n, "auto", -extra)
	end
	-- fr columns keep the minimum too; their room comes out of the auto columns.
	local deficit = 0
	for c = 1, n do
		if kinds[c] == "fr" and colW[c] < MIN_COLUMN then
			deficit = deficit + MIN_COLUMN - colW[c]
			colW[c] = MIN_COLUMN
		end
	end
	if deficit > 0 then
		shrink(node, n, "auto", deficit)
	end
	local x = padL + offset
	for c = 1, n do
		colX[c] = x
		x = x + colW[c] + gapC + spread
	end

	-- Pass 2: row heights from content sized in its cell.
	local pctH = false
	for r = 1, rows do
		rowH[r] = 0
	end
	for i = 1, count do
		local child = children[i]
		if child.pos ~= "absolute" and child.pos ~= "fixed" then
			local col = cCol[i]
			local cellW = (gapC + spread) * (cSpan[i] - 1)
			for c = col, col + cSpan[i] - 1 do
				cellW = cellW + colW[c]
			end
			cW[i] = cellW
			local w, h, given = sizeIn(child, cellW, node, contentW, contentH, ctx)
			cTw[i], cTh[i], cGiven[i] = w, h, given or false
			if child.hKind == "pct" then
				pctH = true
			end
			local row = cRow[i]
			if h > rowH[row] then
				rowH[row] = h
			end
		end
	end
	local used = rows > 1 and gapR * (rows - 1) or 0
	for r = 1, rows do
		used = used + rowH[r]
	end
	local y, rowSpread = padT, 0
	if contentH then
		local free = contentH - used
		if free > 0 then
			local ya = node.yAlign
			if ya == "center" then
				y = y + floor(free / 2 + 0.5)
			elseif ya == "end" then
				y = y + free
			elseif ya == "spaceBetween" then
				rowSpread = rows > 1 and free / (rows - 1) or 0
			elseif ya == "spaceAround" and rows > 0 then
				rowSpread = free / rows
				y = y + rowSpread / 2
			end
		end
	end
	for r = 1, rows do
		rowY[r] = y
		y = y + rowH[r] + gapR + rowSpread
	end
	local outH = H or (padT + used + padB)

	-- Place the flow children in their cells.
	local xa, ya = node.xAlign, node.yAlign
	local stretchRows = not placed(ya)
	for i = 1, count do
		local child = children[i]
		if child.pos ~= "absolute" and child.pos ~= "fixed" then
			local w, h, given = cTw[i], cTh[i], cGiven[i] or nil
			local cx = colX[cCol[i]]
			local free = cW[i] - w
			if free > 0 then
				if xa == "center" then
					cx = cx + floor(free / 2 + 0.5)
				elseif xa == "end" then
					cx = cx + free
				end
			end
			local cy, rh = rowY[cRow[i]], rowH[cRow[i]]
			local box = child.kind == "box"
			if box and (child.hKind == "fill" or (child.hKind == nil and stretchRows)) then
				h, given = rh, rh
			end
			local vfree = rh - h
			if vfree > 0 then
				if ya == "center" then
					cy = cy + floor(vfree / 2 + 0.5)
				elseif ya == "end" then
					cy = cy + vfree
				end
			end
			setRect(child, cx, cy, w, h)
			if box then
				finalize(child, w, given, ctx)
			end
		end
	end
	for i = 1, count do
		local child = children[i]
		if child.pos == "absolute" or child.pos == "fixed" then
			placeFree(child, W, outH, ctx)
		end
	end

	if H == nil then
		node.nhW, node.nhH = W, outH
	end
	node.lw, node.lh, node.lgiven, node.pctH, node.valid = W, outH, H ~= nil, pctH, true
	return outH
end

---Lay out again what Layout.Invalidate returned: a root's children, a free node in its parent, or a box of its own
---size inside its last rectangle. Does nothing for a node not laid out yet (its parent's layout will place it).
---@param node table
---@param ctx OrdaenLayoutContext
function Layout.Relayout(node, ctx)
	pass = pass + 1
	if node.kind == "root" then
		node.pass = pass
		local children = node.children
		for i = 1, node.count or 0 do
			placeFree(children[i], node.w, node.h, ctx)
		end
		node.valid = true
		commit(node, ctx)
		return
	end
	local parent = node.parent
	if isFree(node) then
		if parent and parent.w then
			placeFree(node, parent.w, parent.h, ctx)
			commit(node, ctx)
		end
	elseif node.w and node.kind == "box" then
		finalize(node, node.w, node.lh, ctx)
		commit(node, ctx)
	end
end
