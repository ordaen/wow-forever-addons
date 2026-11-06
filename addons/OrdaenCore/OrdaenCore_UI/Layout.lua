-- OrdaenCore.UI layout engine: where every block and element goes. Pure Lua (no WoW API), so specs drive it.
--
-- A block is a grid: its children are cells, placed left to right and wrapping to the next row.
--   block = {
--     style = "tooltip",            -- style role; the theme gives its look and its default padding/gap
--     columns = { "auto", "1fr" },  -- tracks: number (fixed), "auto" (fits content), "Nfr" (share of the rest)
--     gap = 4 | { column, row },
--     padding = 8 | { top, right, bottom, left },
--     width = n, minWidth = n, maxWidth = n,   -- optional; without width a top block shrinks to fit
--     height = n,                   -- optional fixed height
--     child, child, ...             -- blocks or elements
--   }
-- Every child may have: colSpan = n, hidden = true (skipped), align = "left" | "center" | "right" (default:
-- text left, blocks and images stretch/left).
-- Elements: { text = "...", style = "body" } or { format = "%d:%02d", args = { h, m } } (text drawn with WoW's
-- SetFormattedText, so values that change often create no Lua strings); { image = file } or { atlas = name },
-- with width = n, height = n (or size = n) and optional texCoord = { left, right, top, bottom }.
--
-- Text sizes come from `measure(element, width)`, supplied by the renderer: with width nil, the width of the text
-- on one line (its natural width) and that line's height; with a width, the height of the text wrapped to it.
-- Text always wraps; nothing is truncated.
--
-- Two passes, like CSS grid: column widths first (fixed, then auto = widest natural content, then fr shares of
-- what is left; too little room shrinks fr columns, then auto ones), then row heights from content wrapped to
-- those widths. Results are written into one reused table per block (no garbage per layout).
local _, ns = ...

local Layout = {}
ns.Layout = Layout

local MIN_COLUMN = 8 -- a column never shrinks below this
local DEFAULT_COLUMNS = { "1fr" }

local floor, max, min = math.floor, math.max, math.min

local function sides(value, default)
	value = value or default or 0
	if type(value) == "number" then
		return value, value, value, value
	end
	return value[1] or 0, value[2] or 0, value[3] or 0, value[4] or 0
end

local function gaps(value, default)
	value = value or default or 0
	if type(value) == "number" then
		return value, value
	end
	return value[1] or 0, value[2] or 0
end

-- "auto", 12, "2fr" -> kind, amount
local function track(spec)
	if type(spec) == "number" then
		return "fixed", spec
	elseif spec == "auto" then
		return "auto", 0
	end
	local weight = type(spec) == "string" and tonumber(spec:match("^(%d*%.?%d+)fr$"))
	if weight then
		return "fr", weight
	end
	return "auto", 0
end

local function isText(node)
	return node.text ~= nil or node.format ~= nil
end

local function isImage(node)
	return node.image ~= nil or node.atlas ~= nil
end

local function isBlock(node)
	return not isText(node) and not isImage(node)
end

local function imageSize(node)
	local w = node.width or node.size or 16
	local h = node.height or node.size or w
	return w, h
end

-- Reused per-block scratch and result tables (weak keys: blocks can be collected).
local results = setmetatable({}, { __mode = "k" })

local function resultFor(node)
	local r = results[node]
	if not r then
		r = { items = {}, colKind = {}, colAmount = {}, colWidth = {}, colX = {}, rowHeight = {}, rowY = {} }
		results[node] = r
	end
	return r
end

local layoutBlock -- forward

-- Natural (max-content) width of a child.
local function naturalWidth(child, ctx)
	if isText(child) then
		return (ctx.measure(child, nil))
	elseif isImage(child) then
		return (imageSize(child))
	end
	return layoutBlock(child, nil, ctx).width
end

-- Height of a child given its cell width; also the width it actually takes (text: its natural width, or the
-- whole cell when it has to wrap; `align` then places it inside the cell).
local function sizeIn(child, cellWidth, natural, ctx)
	if isText(child) then
		local _, h = ctx.measure(child, cellWidth)
		return min(natural, cellWidth), h
	elseif isImage(child) then
		local w, h = imageSize(child)
		return min(w, cellWidth), h
	end
	local r = layoutBlock(child, child.width or cellWidth, ctx)
	return r.width, r.height
end

-- Spread `amount` over columns first..last of `kind` (by weight for fr, evenly otherwise).
local function grow(r, first, last, kind, amount)
	local total = 0
	for c = first, last do
		if r.colKind[c] == kind then
			total = total + (kind == "fr" and r.colAmount[c] or 1)
		end
	end
	if total == 0 then
		return false
	end
	for c = first, last do
		if r.colKind[c] == kind then
			local share = (kind == "fr" and r.colAmount[c] or 1) / total
			r.colWidth[c] = r.colWidth[c] + amount * share
		end
	end
	return true
end

-- Take up to `amount` from columns of `kind`, proportionally to their width, never below MIN_COLUMN.
local function shrink(r, n, kind, amount)
	local room = 0
	for c = 1, n do
		if r.colKind[c] == kind then
			room = room + max(0, r.colWidth[c] - MIN_COLUMN)
		end
	end
	if room <= 0 then
		return amount
	end
	local take = min(amount, room)
	for c = 1, n do
		if r.colKind[c] == kind then
			local spare = max(0, r.colWidth[c] - MIN_COLUMN)
			r.colWidth[c] = r.colWidth[c] - take * spare / room
		end
	end
	return amount - take
end

--- Lay out `node` (a block). `width` nil = shrink to fit its content (clamped by minWidth/maxWidth).
--- Returns its result: { width, height, items = { { node, x, y, w, h }, ... } }, positions relative to the
--- block's top-left corner, y growing downwards. Nested blocks' results: Layout.ResultOf(child).
function layoutBlock(node, width, ctx)
	local r = resultFor(node)
	local defaults = ctx.defaults(node.style)
	local padTop, padRight, padBottom, padLeft = sides(node.padding, defaults.padding)
	local gapColumn, gapRow = gaps(node.gap, defaults.gap)
	local columns = node.columns or DEFAULT_COLUMNS
	local n = #columns

	-- Cells: reading order, wrapping when a span doesn't fit the row.
	local items = r.items
	local count, col, row = 0, 1, 1
	for i = 1, #node do
		local child = node[i]
		if not child.hidden then
			local span = min(max(1, child.colSpan or 1), n)
			if col + span - 1 > n then
				col, row = 1, row + 1
			end
			count = count + 1
			local item = items[count]
			if not item then
				item = {}
				items[count] = item
			end
			item.node, item.col, item.row, item.span = child, col, row, span
			item.natural = naturalWidth(child, ctx)
			col = col + span
			if col > n then
				col, row = 1, row + 1
			end
		end
	end
	for i = count + 1, #items do
		items[i] = nil
	end
	local rows = count > 0 and items[count].row or 0
	r.count, r.rows = count, rows

	-- Pass 1: column widths.
	local shrinkToFit = width == nil and node.width == nil
	for c = 1, n do
		local kind, amount = track(columns[c])
		r.colKind[c], r.colAmount[c] = kind, amount
		r.colWidth[c] = kind == "fixed" and amount or 0
	end
	for i = 1, count do
		local item = items[i]
		local c = item.col
		if item.span == 1 and (r.colKind[c] == "auto" or (r.colKind[c] == "fr" and shrinkToFit)) then
			r.colWidth[c] = max(r.colWidth[c], item.natural)
		end
	end
	-- Spanning items that need more than their columns give: grow fr, else auto, else the last column.
	for i = 1, count do
		local item = items[i]
		if item.span > 1 then
			local last = item.col + item.span - 1
			local have = gapColumn * (item.span - 1)
			for c = item.col, last do
				have = have + r.colWidth[c]
			end
			local need = item.natural - have
			if need > 0 and (shrinkToFit or not grow(r, item.col, last, "fr", 0)) then
				if not grow(r, item.col, last, "fr", need) and not grow(r, item.col, last, "auto", need) then
					r.colWidth[last] = r.colWidth[last] + need
				end
			end
		end
	end
	local sum = 0
	for c = 1, n do
		sum = sum + r.colWidth[c]
	end
	local outer = node.width or width or (sum + gapColumn * (n - 1) + padLeft + padRight)
	local minWidth = node.minWidth or defaults.minWidth
	local maxWidth = node.maxWidth or defaults.maxWidth
	if minWidth then
		outer = max(outer, minWidth)
	end
	if maxWidth then
		outer = min(outer, maxWidth)
	end
	local extra = outer - padLeft - padRight - gapColumn * (n - 1) - sum
	if extra > 0 then
		grow(r, 1, n, "fr", extra)
	elseif extra < 0 then
		extra = shrink(r, n, "fr", -extra)
		if extra > 0 then
			shrink(r, n, "auto", extra)
		end
	end
	-- fr columns keep the minimum too; their room comes out of the auto columns.
	local deficit = 0
	for c = 1, n do
		if r.colKind[c] == "fr" and r.colWidth[c] < MIN_COLUMN then
			deficit = deficit + MIN_COLUMN - r.colWidth[c]
			r.colWidth[c] = MIN_COLUMN
		end
	end
	if deficit > 0 then
		shrink(r, n, "auto", deficit)
	end
	local x = padLeft
	for c = 1, n do
		r.colX[c] = x
		x = x + r.colWidth[c] + gapColumn
	end

	-- Pass 2: heights, from content laid out in its cell.
	for rr = 1, rows do
		r.rowHeight[rr] = 0
	end
	for i = 1, count do
		local item = items[i]
		local cellWidth = gapColumn * (item.span - 1)
		for c = item.col, item.col + item.span - 1 do
			cellWidth = cellWidth + r.colWidth[c]
		end
		item.cellWidth = cellWidth
		item.w, item.h = sizeIn(item.node, cellWidth, item.natural, ctx)
		r.rowHeight[item.row] = max(r.rowHeight[item.row], item.h)
	end
	local y = padTop
	for rr = 1, rows do
		r.rowY[rr] = y
		y = y + r.rowHeight[rr] + (rr < rows and gapRow or 0)
	end
	for i = 1, count do
		local item = items[i]
		local align = item.node.align
		local left = r.colX[item.col]
		if align == "right" then
			left = left + item.cellWidth - item.w
		elseif align == "center" then
			left = left + floor((item.cellWidth - item.w) / 2 + 0.5)
		end
		item.x, item.y = left, r.rowY[item.row]
	end

	r.width = outer
	r.height = node.height or (y + padBottom)
	return r
end

--- Lay out a block tree. ctx = { measure = fn(element, width) -> w, h, defaults = fn(style) -> { padding, gap } }.
---@return table the root's result
function Layout.Run(root, width, ctx)
	return layoutBlock(root, width, ctx)
end

--- The result of a nested block from the last Run (same reused table every time).
function Layout.ResultOf(node)
	return results[node]
end

Layout.IsBlock = isBlock
Layout.IsText = isText
Layout.IsImage = isImage
