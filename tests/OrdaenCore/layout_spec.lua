-- The drawing backend's layout (addons/OrdaenCore/Backend/Layout.lua): pure grid math over node tables, with a fake
-- text measurer. Nodes are built here the way the backend fills them from attributes.
local function load()
	local ns = {}
	assert(loadfile("addons/OrdaenCore/Backend/Layout.lua"))("OrdaenCore", ns)
	return ns.Layout
end

local Layout = load()

-- Fake fonts: every character is 6 px wide, a line is 12 px high; text wraps at word boundaries.
local CHAR, LINE = 6, 12
local measured = 0
local function measure(node, width)
	measured = measured + 1
	local lines, current = 1, 0
	for word in node.text:gmatch("%S+") do
		local w = #word * CHAR
		if current == 0 then
			current = w
		elseif current + CHAR + w <= width then
			current = current + CHAR + w
		else
			lines, current = lines + 1, w
		end
	end
	return lines * LINE
end

local placedCount = 0
local ctx = {
	measure = measure,
	place = function()
		placedCount = placedCount + 1
	end,
	screenW = 1000,
	screenH = 800,
}

local identity = function(v)
	return v
end

local function attach(parent, children)
	parent.children, parent.count = children, #children
	for _, child in ipairs(children) do
		child.parent = parent
	end
end

local function resolveAs(_, v)
	return v
end

-- A box from attributes, filled as the backend fills it (Layout.Apply, one pixel = one unit).
local function box(a, children)
	local node = { kind = "box" }
	Layout.Apply(node, a or {}, resolveAs, identity, 1)
	attach(node, children or {})
	return node
end

local function text(s, a)
	a = a or {}
	local node = { kind = "text", text = s, natW = #s * CHAR, lineH = LINE, wrap = a.wrap, span = a.columnSpan,
		pos = a.position, children = {}, count = 0 }
	node.wKind, node.wAmount = Layout.Size(a.width)
	node.offL, node.offR, node.offT, node.offB = a.left, a.right, a.top, a.bottom
	return node
end

local function root(children)
	local node = { kind = "root", w = 1000, h = 800 }
	attach(node, children)
	return node
end

local function run(node)
	Layout.Relayout(Layout.Invalidate(node, true), ctx)
end

local function rect(node)
	return { node.x, node.y, node.w, node.h }
end

describe("backend layout", function()
	describe("attributes", function()
		-- A value for each layout attribute that differs from its default.
		local SAMPLE = {
			width = 10, height = 10, columnSpan = 2, position = "absolute", top = 5, right = 5, bottom = 5, left = 5,
			columns = { "auto", 20 }, gap = 3, padding = 4, xAlign = "center", yAlign = "end", border = { width = 1 },
		}

		it("reads every layout attribute into its fields", function()
			for _, attribute in ipairs(Layout.ATTRIBUTES) do
				local plain, set = { kind = "box" }, { kind = "box" }
				Layout.Apply(plain, {}, resolveAs, identity, 1)
				Layout.Apply(set, { [attribute.key] = SAMPLE[attribute.key] }, resolveAs, identity, 1)
				local differs = false
				for _, field in ipairs(attribute.fields) do
					differs = differs or plain[field] ~= set[field]
				end
				assert(SAMPLE[attribute.key] ~= nil, "no sample for " .. attribute.key)
				assert(differs, attribute.key .. " fills none of its fields")
			end
		end)

		it("puts sizes, gaps and padding on whole pixels", function()
			local node = { kind = "box" }
			Layout.Apply(node, { width = 36, gap = 1, padding = 2, columns = { 50 } }, resolveAs, identity, 768 / 720)
			local px = 768 / 720
			for _, v in ipairs({ node.wAmount, node.gapC, node.padT, node.colAmount[1] }) do
				local pixels = v / px
				assert.is_true(math.abs(pixels - math.floor(pixels + 0.5)) < 1e-9, tostring(v) .. " isn't whole pixels")
			end
		end)
	end)

	describe("sizes", function()
		it("parses numbers, auto, percentages and fr", function()
			assert.same({ "fixed", 24 }, { Layout.Size(24) })
			assert.same({ "auto", 0 }, { Layout.Size("auto") })
			assert.same({ "pct", 0.5 }, { Layout.Size("50%") })
			assert.same({ "fill", 1 }, { Layout.Size("1fr") })
			assert.same({ "fr", 2 }, { Layout.Size("2fr", true) })
			assert.same({ nil, 0 }, { Layout.Size(nil) })
		end)

		it("reads columns as a list, a count or one fr track", function()
			local node = {}
			Layout.Columns(node, { "auto", "1fr", 120 }, identity)
			assert.same({ 3, { "auto", "fr", "fixed" }, { 0, 1, 120 } }, { node.ncols, node.colKind, node.colAmount })
			Layout.Columns(node, 2, identity)
			assert.equal(2, node.ncols)
			assert.same({ "fr", "fr" }, { node.colKind[1], node.colKind[2] })
			Layout.Columns(node, nil, identity)
			assert.equal(1, node.ncols)
		end)
	end)

	describe("a layer's children", function()
		it("are centred and sized by their content", function()
			local label = text("hello")
			local win = box({ padding = 4 }, { label })
			run(root({ win }))
			assert.same({ 0, 0, 38, 20 }, { win.x and 0, 0, win.w, win.h })
			assert.same({ 481, 390, 38, 20 }, rect(win))
			assert.same({ 4, 4, 30, 12 }, rect(label))
		end)

		it("take offsets from the edges they name", function()
			local a = box({ width = 100, height = 50, position = "absolute", right = 10, bottom = 20 })
			run(root({ a }))
			assert.same({ 890, 730, 100, 50 }, rect(a))
		end)
	end)

	describe("columns", function()
		it("fixed, auto and fr share the width", function()
			local a, b, c = box({ height = 10 }), text("abcd"), box({ height = 10 })
			local win = box({ width = 300, columns = { 50, "auto", "1fr" }, gap = 10 }, { a, b, c })
			run(root({ win }))
			assert.same({ 0, 0, 50, 10 }, rect(a))
			assert.same({ 60, 0, 24, 12 }, rect(b))
			assert.same({ 94, 0, 206, 10 }, rect(c))
		end)

		it("takes a percentage width of its cell, not of the whole content box", function()
			local a, b, c = box({ height = 10 }), box({ width = "100%", height = 10 }), box({ width = "50%", height = 10 })
			local win = box({ width = 300, columns = { "1fr", "1fr", "1fr" } }, { a, b, c })
			run(root({ win }))
			assert.same({ 100, 0, 100, 10 }, rect(b))
			assert.same({ 200, 0, 50, 10 }, rect(c))
		end)

		it("gives an auto-width box fr columns at their content's width", function()
			local a, b = text("aaaaaaaaaa"), text("bb")
			local win = box({ columns = { "1fr", "1fr" } }, { a, b })
			run(root({ win }))
			assert.equal(120, win.w)
			assert.equal(12, a.h) -- no wrap
			assert.equal(60, b.x)
		end)

		it("wraps to the next row and spans columns", function()
			local a, b, c = text("a"), text("b"), text("wide", { columnSpan = 2 })
			local win = box({ width = 100, columns = 2, gap = { 4, 0 } }, { a, b, c })
			run(root({ win }))
			assert.same({ 1, 1, 2, 1 }, { win.cRow[a.idx], win.cCol[a.idx], win.cCol[b.idx], win.cCol[c.idx] })
			assert.same({ 0, 16, 100, 12 }, rect(c))
		end)

		it("shrinks auto columns when there is too little room, not below 8", function()
			local a, b = text("aaaaaaaaaa"), text("bbbbbbbbbb")
			local win = box({ width = 60, columns = { "auto", "auto" } }, { a, b })
			run(root({ win }))
			assert.equal(30, a.w)
			assert.equal(30, b.x)
		end)

		it("keeps fr columns at 8 at least", function()
			local a, b = text("aaaaaaaaaa"), box({ height = 4 })
			local win = box({ width = 40, columns = { "auto", "1fr" } }, { a, b })
			run(root({ win }))
			assert.equal(8, b.w)
			assert.equal(32, a.w)
		end)
	end)

	describe("text", function()
		it("wraps to its cell and the row grows", function()
			local t = text("one two three four")
			local win = box({ width = 60 }, { t })
			run(root({ win }))
			assert.same({ 60, 24 }, { t.w, t.h })
			assert.equal(24, win.h)
		end)

		it("stays on one line with wrap false, and its box grows", function()
			local t = text("one two three four", { wrap = false })
			local win = box({ columns = { "auto" } }, { t })
			run(root({ win }))
			assert.same({ 108, 12 }, { t.w, t.h })
			assert.equal(108, win.w)
		end)

		it("measures a wrapped width once", function()
			local t = text("one two three four")
			local win = box({ width = 60 }, { t })
			local r = root({ win })
			run(r)
			local before = measured
			run(win)
			Layout.Relayout(Layout.Invalidate(r, true), ctx)
			assert.equal(before, measured)
		end)
	end)

	describe("alignment", function()
		it("stretches by default and places items with xAlign", function()
			local a = box({ height = 10 })
			local win = box({ width = 100, padding = 0 }, { a })
			run(root({ win }))
			assert.equal(100, a.w)
			local t = text("ab")
			local centred = box({ width = 100, xAlign = "center" }, { t })
			run(root({ centred }))
			assert.same({ 44, 12 }, { t.x, t.w })
		end)

		it("stretches boxes to their row's height unless yAlign places them", function()
			local tall, short = box({ width = 10, height = 40 }), box({ width = 10 })
			local row = box({ columns = { "auto", "auto" } }, { tall, short })
			run(root({ row }))
			assert.equal(40, short.h)
			local short2 = box({ width = 10, height = 10 })
			local tall2 = box({ width = 10, height = 40 })
			local centred = box({ columns = { "auto", "auto" }, yAlign = "center" }, { tall2, short2 })
			run(root({ centred }))
			assert.same({ 15, 10 }, { short2.y, short2.h })
		end)

		it("puts the rows of a fixed-height box at its yAlign", function()
			local t = text("x")
			local win = box({ width = 50, height = 100, yAlign = "end" }, { t })
			run(root({ win }))
			assert.equal(88, t.y)
		end)

		it("spreads columns with spaceBetween when no fr takes the room", function()
			local a, b = box({ width = 10, height = 5 }), box({ width = 10, height = 5 })
			local win = box({ width = 100, columns = { "auto", "auto" }, xAlign = "spaceBetween" }, { a, b })
			run(root({ win }))
			assert.same({ 0, 90 }, { a.x, b.x })
		end)
	end)

	describe("padding and border", function()
		it("offsets content by both", function()
			local t = text("x")
			local win = box({ padding = { 1, 2, 3, 4 }, border = { width = 1 } }, { t })
			run(root({ win }))
			assert.same({ 5, 2 }, { t.x, t.y })
			assert.same({ 6 + 4 + 2 + 2, 12 + 1 + 3 + 2 }, { win.w, win.h })
		end)
	end)

	describe("percentages and absolute children", function()
		it("sizes a percentage width from the parent's content box", function()
			local half = box({ width = "50%", height = 10 })
			local win = box({ width = 220, padding = 10 }, { half })
			run(root({ win }))
			assert.equal(100, half.w)
		end)

		it("places an absolute child over the content, out of the grid", function()
			local a = text("A")
			local badge = text("9", { position = "absolute", right = 0, bottom = 0 })
			local icon = box({ width = 40, height = 40 }, { a, badge })
			run(root({ icon }))
			assert.same({ 34, 28, 6, 12 }, rect(badge))
			assert.same({ 0, 0 }, { a.x, a.y })
		end)
	end)

	describe("placing order", function()
		-- The backend gives every node one anchor point to its parent and replaces a reused node's old point when it's
		-- placed; that's safe only if a parent is always placed before its children (else a child could anchor to a
		-- frame still anchored to it).
		local function recordingCtx()
			local order, at = {}, {}
			local c = setmetatable({ place = function(node)
				order[#order + 1] = node
				at[node] = #order
			end }, { __index = ctx })
			return c, order, at
		end

		local function assertParentsFirst(order, at)
			for _, node in ipairs(order) do
				local parent = node.parent
				if parent and at[parent] then
					assert(at[parent] < at[node], "a child was placed before its parent")
				end
			end
		end

		it("places every parent before its children", function()
			local leaves = {}
			local function level(depth)
				if depth == 0 then
					local t = text("leaf")
					leaves[#leaves + 1] = t
					return t
				end
				return box({ padding = 1, columns = 2 }, { level(depth - 1), level(depth - 1) })
			end
			local r = root({ level(4), box({ width = 50, height = 20, position = "absolute", left = 5, top = 5 },
				{ level(2) }) })
			local c, order, at = recordingCtx()
			Layout.Relayout(Layout.Invalidate(r, true), c)
			assert.is_true(#order > 30)
			assertParentsFirst(order, at)
		end)

		it("places a stretched box before its content", function()
			local inner = box({}, { text("x") })
			local short = box({ width = 10 }, { inner })
			local row = box({ columns = { "auto", "auto" } }, { box({ width = 10, height = 40 }), short })
			local c, order, at = recordingCtx()
			Layout.Relayout(Layout.Invalidate(root({ row }), true), c)
			assertParentsFirst(order, at)
			assert.equal(40, short.h)
		end)
	end)

	describe("invalidation", function()
		it("stops at a box of its own size", function()
			local count = text("1")
			local icon = box({ width = 40, height = 40 }, { count })
			local grid = box({ columns = 4 }, { icon })
			local r = root({ grid })
			run(r)
			assert.equal(icon, Layout.Invalidate(count))
		end)

		it("goes up to the root through content-sized boxes", function()
			local t = text("1")
			local inner = box({}, { t })
			local r = root({ box({}, { inner }) })
			run(r)
			assert.equal(r.children[1], Layout.Invalidate(t)) -- a layer's child is free: placed on its own
		end)

		it("moves a free box by its offsets without laying its content out again", function()
			local cells = {}
			for i = 1, 20 do
				cells[i] = box({ width = 36, height = 36 })
			end
			local window = box({ columns = 10, gap = 2, position = "absolute", left = 200, top = 200 }, cells)
			run(root({ window }))
			placedCount = 0
			window.offL, window.offT = 300, 250
			assert.equal(window, Layout.Offsets(window))
			assert.is_true(window.valid) -- still laid out: only its place changes
			assert.is_true(window.natValid)
			Layout.Relayout(window, ctx)
			assert.equal(1, placedCount)
			assert.same({ 300, 250 }, { window.x, window.y })
		end)

		it("treats offsets that size a box as a size change", function()
			local panel = box({ position = "absolute", left = 10, right = 10, height = 20 })
			run(root({ panel }))
			panel.offR = 100
			assert.equal(panel, Layout.Offsets(panel))
			assert.is_false(panel.valid)
			Layout.Relayout(panel, ctx)
			assert.equal(1000 - 110, panel.w)
		end)

		it("ignores offsets on a flow node", function()
			local child = box({ width = 10, height = 10 })
			run(root({ box({}, { child }) }))
			child.offL = 5
			assert.is_nil(Layout.Offsets(child))
		end)

		it("returns nil for a detached node", function()
			assert.is_nil(Layout.Invalidate(text("x")))
		end)

		it("re-lays out a changed count without moving its siblings", function()
			local counts, icons = {}, {}
			for i = 1, 8 do
				counts[i] = text("1", { position = "absolute", right = 0, bottom = 0 })
				icons[i] = box({ width = 40, height = 40 }, { counts[i] })
			end
			local grid = box({ columns = 4, gap = 2 }, icons)
			local r = root({ grid })
			run(r)
			placedCount = 0
			counts[3].text, counts[3].natW = "123", 18
			Layout.Relayout(Layout.Invalidate(counts[3]), ctx)
			assert.equal(1, placedCount)
			assert.same({ 22, 28 }, { counts[3].x, counts[3].y })
		end)

		it("lays out nothing again when nothing changed", function()
			local items = {}
			for i = 1, 20 do
				items[i] = box({ columns = { "auto", "1fr" } }, { text("name " .. i), text(tostring(i)) })
			end
			local list = box({ width = 200 }, items)
			local r = root({ list })
			run(r)
			placedCount = 0
			Layout.Relayout(r, ctx)
			assert.equal(0, placedCount)
		end)
	end)
end)
