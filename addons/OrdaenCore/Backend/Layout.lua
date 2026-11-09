-- The drawing backend's layout (development/framework/box, "The renderer"): where every box and text goes. Pure Lua
-- (no WoW API), so busted specs drive it with a fake text measurer (tests/OrdaenCore/layout_spec.lua).
--
-- It works on node tables. The backend fills these fields from a node's attributes when they change (theme
-- references and per-state maps already resolved, see Layout.Size and Layout.Columns):
--   kind                      "box", "text" or "root" (a layer or a taken Blizzard frame: w and h come from WoW)
--   parent, children, count   the tree; children is an array, count its length
--   wKind, wAmount            width: "fixed" (amount in UI units), "auto" (content), "pct" (amount 0..1 of the
--   hKind, hAmount            parent's content box), "fill" (the cell), nil (stretch in its cell, unless the parent's
--                             xAlign places it; heights: content, stretched to the row by the parent's yAlign)
--   ncols, colKind, colAmount the grid's tracks: "fixed" | "auto" | "fr" (amount = weight)
--   gapC, gapR, padT, padR, padB, padL, bw   gaps, padding and border width (padding sits inside the border)
--   span                      columns covered in the parent's grid
--   xAlign, yAlign            "start" | "center" | "end" | "stretch" | "spaceBetween" | "spaceAround" | nil
--   pos                       "flow" | "absolute" | "fixed" (nil = flow); offL, offR, offT, offB its offsets
--   text: natW, lineH, wrap   its width on one line and that line's height (the backend measures them), wrap false
--                             keeps it on one line
-- and writes back x, y, w, h: the node's rectangle relative to its parent's top-left corner (y downwards), calling
-- ctx.place(node) when it changed. Free nodes (absolute, fixed, a root's children) are placed by their offsets,
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
function Layout.Columns(node, columns, resolve)
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

-- Flow children into cells, reading order, wrapping when a span doesn't fit the row. Returns the number of rows.
local function assignCells(node)
	local children, n = node.children, node.ncols or 1
	local col, row, rows = 1, 1, 0
	for i = 1, node.count or 0 do
		local child = children[i]
		if not isFree(child) then
			local span = child.span or 1
			if span > n then
				span = n
			elseif span < 1 then
				span = 1
			end
			if col + span - 1 > n then
				col, row = 1, row + 1
			end
			child.col, child.row, child.cspan = col, row, span
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
	local colW = scratch(node)
	assignCells(node)
	for c = 1, n do
		colW[c] = kinds[c] == "fixed" and amounts[c] or 0
	end
	local children = node.children
	for i = 1, node.count or 0 do
		local child = children[i]
		if not isFree(child) and child.cspan == 1 and kinds[child.col] ~= "fixed" then
			colW[child.col] = max(colW[child.col], natural(child))
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
		if not isFree(child) and child.cspan > 1 then
			local last = child.col + child.cspan - 1
			local have = node.gapC * (child.cspan - 1)
			for c = child.col, last do
				have = have + colW[c]
			end
			local need = natural(child) - have
			if need > 0 and not grow(node, child.col, last, "fr", need) and not grow(node, child.col, last, "auto", need) then
				colW[last] = colW[last] + need
			end
		end
	end
	local sum = node.gapC * (n - 1) + node.padL + node.padR + 2 * node.bw
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

local function setRect(node, x, y, w, h, ctx)
	if node.x ~= x or node.y ~= y or node.w ~= w or node.h ~= h then
		node.x, node.y, node.w, node.h = x, y, w, h
		ctx.place(node)
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

-- Make sure the last layout of `node` is the one at (w, h), so its children sit where they belong.
local function finalize(node, w, h, ctx)
	if not (node.valid and node.lw == w and node.lh == h) then
		layoutBox(node, w, h, ctx)
	end
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
		finalize(node, w, given, ctx)
	end
	local x = l or (r and refW - r - w) or floor((refW - w) / 2 + 0.5)
	local y = t or (b and refH - b - h) or floor((refH - h) / 2 + 0.5)
	setRect(node, x, y, w, h, ctx)
end

-- Size a flow child in its cell: width from its attributes, height at that width (given, or its content's).
-- Returns w, h and the height it was given (nil: its content decides).
local function sizeIn(child, cellW, parent, contentW, contentH, ctx)
	local wk, w = child.wKind, nil
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

-- Lay out a box's children at outer width W and, when given, outer height H. Returns its outer height.
function layoutBox(node, W, H, ctx)
	local n = node.ncols or 1
	local kinds = node.colKind
	local bw = node.bw
	local padT, padR, padB, padL = node.padT + bw, node.padR + bw, node.padB + bw, node.padL + bw
	local gapC, gapR = node.gapC, node.gapR
	local colW, colX, rowH, rowY = scratch(node)
	local children, count = node.children, node.count or 0
	local rows = assignCells(node)
	local contentW = W - padL - padR
	local contentH = H and H - padT - padB or nil

	-- Pass 1: column widths.
	local amounts = node.colAmount
	for c = 1, n do
		colW[c] = kinds[c] == "fixed" and amounts[c] or 0
	end
	for i = 1, count do
		local child = children[i]
		if not isFree(child) and child.cspan == 1 and kinds[child.col] == "auto" then
			colW[child.col] = max(colW[child.col], natural(child))
		end
	end
	for i = 1, count do
		local child = children[i]
		if not isFree(child) and child.cspan > 1 then
			local last = child.col + child.cspan - 1
			local have = gapC * (child.cspan - 1)
			local hasFr = false
			for c = child.col, last do
				have = have + colW[c]
				hasFr = hasFr or kinds[c] == "fr"
			end
			local need = natural(child) - have
			if need > 0 and not hasFr and not grow(node, child.col, last, "auto", need) then
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
	for r = 1, rows do
		rowH[r] = 0
	end
	for i = 1, count do
		local child = children[i]
		if not isFree(child) then
			local cellW = (gapC + spread) * (child.cspan - 1)
			for c = child.col, child.col + child.cspan - 1 do
				cellW = cellW + colW[c]
			end
			child.cellW = cellW
			local w, h, given = sizeIn(child, cellW, node, contentW, contentH, ctx)
			child.tw, child.th, child.tgiven = w, h, given
			if h > rowH[child.row] then
				rowH[child.row] = h
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
		if not isFree(child) then
			local w, h, given = child.tw, child.th, child.tgiven
			local cx = colX[child.col]
			local free = child.cellW - w
			if free > 0 then
				if xa == "center" then
					cx = cx + floor(free / 2 + 0.5)
				elseif xa == "end" then
					cx = cx + free
				end
			end
			local cy, rh = rowY[child.row], rowH[child.row]
			if child.kind == "box" then
				if child.hKind == "fill" or (child.hKind == nil and stretchRows) then
					h, given = rh, rh
				end
				finalize(child, w, given, ctx)
			end
			local vfree = rh - h
			if vfree > 0 then
				if ya == "center" then
					cy = cy + floor(vfree / 2 + 0.5)
				elseif ya == "end" then
					cy = cy + vfree
				end
			end
			setRect(child, cx, cy, w, h, ctx)
		end
	end
	for i = 1, count do
		local child = children[i]
		if isFree(child) then
			placeFree(child, W, outH, ctx)
		end
	end

	if H == nil then
		node.nhW, node.nhH = W, outH
	end
	node.lw, node.lh, node.valid = W, H, true
	return outH
end

---Lay out again what Layout.Invalidate returned: a root's children, a free node in its parent, or a box of its own
---size inside its last rectangle. Does nothing for a node not laid out yet (its parent's layout will place it).
---@param node table
---@param ctx OrdaenLayoutContext
function Layout.Relayout(node, ctx)
	if node.kind == "root" then
		local children = node.children
		for i = 1, node.count or 0 do
			placeFree(children[i], node.w, node.h, ctx)
		end
		node.valid = true
		return
	end
	local parent = node.parent
	if isFree(node) then
		if parent and parent.w then
			placeFree(node, parent.w, parent.h, ctx)
		end
	elseif node.w and node.kind == "box" then
		finalize(node, node.w, node.lh, ctx)
	end
end
