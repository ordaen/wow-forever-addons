-- OrdaenCore.UI layout engine (OrdaenCore_UI/Layout.lua): pure grid math, with a fake text measurer.
local function load()
	local ns = {}
	assert(loadfile("addons/OrdaenCore/OrdaenCore_UI/Layout.lua"))("OrdaenCore_UI", ns)
	return ns.Layout
end

-- Fake fonts: every character is 6 px wide, a line is 12 px high; text wraps at word boundaries.
local CHAR, LINE = 6, 12
local function measure(el, width)
	local text = el.text
	local natural = #text * CHAR
	if not width or natural <= width then
		return natural, LINE
	end
	local lines, current = 1, 0
	for word in text:gmatch("%S+") do
		local w = #word * CHAR
		if current == 0 then
			current = w
		elseif current + CHAR + w <= width then
			current = current + CHAR + w
		else
			lines, current = lines + 1, w
		end
	end
	return width, lines * LINE
end

local function ctx(defaults)
	return {
		measure = measure,
		defaults = function(style)
			return defaults and defaults[style] or {}
		end,
	}
end

describe("OrdaenCore.UI layout", function()
	local Layout

	before_each(function()
		Layout = load()
	end)

	it("lays an onTop child over the content, without a cell of its own (a count on an icon)", function()
		local count = { text = "23", onTop = true, align = "right", valign = "bottom" }
		local block = { padding = 2, columns = { "auto" }, { image = "bag", size = 40 }, count }
		local r = Layout.Run(block, nil, ctx())
		assert.equals(2 + 40 + 2, r.width) -- the count adds no column or row
		assert.equals(2 + 40 + 2, r.height)
		assert.equals(2, r.count) -- the icon, then the count (drawn after: on top)
		local item = r.items[2]
		assert.equals(count, item.node)
		assert.equals(2 + 40 - 2 * CHAR, item.x)
		assert.equals(2 + 40 - LINE, item.y)
		-- default placement: top left of the content
		count.align, count.valign = nil, nil
		r = Layout.Run(block, nil, ctx())
		assert.equals(2, r.items[2].x)
		assert.equals(2, r.items[2].y)
		-- hidden: nothing
		count.hidden = true
		assert.equals(1, Layout.Run(block, nil, ctx()).count)
	end)

	it("puts an onTop child in its block's final box when a stretching row makes the block taller", function()
		-- a 10 px icon cell beside a 40 px one in a row that stretches: the small cell becomes 40 high, and its
		-- count sits in the bottom-right corner of those 40, not of the 10 it had before
		local count = { text = "3", onTop = true, align = "right", valign = "bottom" }
		local small = { columns = { "auto" }, { image = "bag", size = 10 }, count }
		local row = { rowAlign = "stretch", columns = { "auto", "auto" }, small, { image = "big", size = 40 } }
		Layout.Run(row, nil, ctx())
		local r = Layout.ResultOf(small)
		assert.equals(40, r.height)
		local item = r.items[r.count]
		assert.equals(count, item.node)
		assert.equals(10 - CHAR, item.x)
		assert.equals(40 - LINE, item.y)
	end)

	it("shrinks a single-column block to its widest line, with padding and row gaps", function()
		local block = { padding = 8, gap = 2, { text = "Elwynn Forest" }, { text = "Goldshire" } }
		local r = Layout.Run(block, nil, ctx())
		assert.equals(8 + 13 * CHAR + 8, r.width)
		assert.equals(8 + LINE + 2 + LINE + 8, r.height)
		assert.same({ 8, 8 }, { r.items[1].x, r.items[1].y })
		assert.same({ 8, 8 + LINE + 2 }, { r.items[2].x, r.items[2].y })
	end)

	it("takes padding and gap from the style's defaults unless the block sets them", function()
		local block = { style = "tooltip", { text = "abc" } }
		local r = Layout.Run(block, nil, ctx({ tooltip = { padding = 10, gap = 3 } }))
		assert.equals(10 + 3 * CHAR + 10, r.width)
		block.padding = 0
		r = Layout.Run(block, nil, ctx({ tooltip = { padding = 10 } }))
		assert.equals(3 * CHAR, r.width)
	end)

	it("places label/value rows in an auto and a fr column, values right-aligned", function()
		local block = {
			columns = { "auto", "1fr" },
			gap = { 10, 0 },
			{ text = "Mail" }, { text = "3", align = "right" },
			{ text = "Auctions" }, { text = "12", align = "right" },
		}
		local r = Layout.Run(block, 200, ctx())
		assert.equals(200, r.width)
		-- auto column = widest label (8 chars), the fr column takes the rest.
		local valueColumnX = 8 * CHAR + 10
		assert.equals(0, r.items[1].x)
		assert.equals(200 - 1 * CHAR, r.items[2].x) -- right edge of the block
		assert.equals(200 - 2 * CHAR, r.items[4].x)
		assert.is_true(r.items[2].x >= valueColumnX)
		assert.equals(LINE, r.items[3].y)
	end)

	it("wraps text that is wider than the block's maxWidth, and the row grows", function()
		local block = { maxWidth = 60, { text = "one two three four" } } -- 18 chars = 108 px
		local r = Layout.Run(block, nil, ctx())
		assert.equals(60, r.width)
		assert.equals(2 * LINE, r.height) -- "one two" / "three four" at 60 px: 42 + 60
		assert.equals(60, r.items[1].w)
	end)

	it("never truncates: a long word just overflows its line, the text still gets a line", function()
		local block = { width = 20, { text = "extraordinary" } }
		local r = Layout.Run(block, nil, ctx())
		assert.equals(LINE, r.height)
	end)

	it("shares free space by fr weight and keeps fixed columns fixed", function()
		local block = { columns = { 20, "1fr", "3fr" }, gap = 0,
			{ text = "a" }, { text = "b" }, { text = "c" } }
		local r = Layout.Run(block, 100, ctx())
		local res = Layout.ResultOf(block)
		assert.equals(20, res.colWidth[1])
		assert.equals(20, res.colWidth[2])
		assert.equals(60, res.colWidth[3])
		assert.equals(20, r.items[2].x)
		assert.equals(40, r.items[3].x)
	end)

	it("lets a title span every column and widens the block to fit it", function()
		local block = {
			columns = { "auto", "auto" },
			gap = { 4, 0 },
			{ text = "A rather long title", colSpan = 2 }, -- 19 chars = 114 px
			{ text = "a" }, { text = "b" },
		}
		local r = Layout.Run(block, nil, ctx())
		assert.equals(19 * CHAR, r.width)
		assert.equals(LINE, r.items[2].y)
	end)

	it("places a block child left, centred or right in a wide cell, at its content's width", function()
		local function side(align)
			return { align = align, columns = { "auto", "auto" }, gap = 0, padding = 0, { text = "ab" },
				{ text = "cd" } }
		end
		local l, c, rt = side("left"), side("center"), side("right")
		local root = { columns = { "1fr" }, width = 200, padding = 0, gap = 0, l, c, rt }
		Layout.Run(root, nil, ctx())
		local items = Layout.ResultOf(root).items
		assert.same({ 0, 24 }, { items[1].x, items[1].w })
		assert.same({ 88, 24 }, { items[2].x, items[2].w })
		assert.same({ 176, 24 }, { items[3].x, items[3].w })
	end)

	it("centres children in their row and rows in a fixed height (rowAlign), a child may differ (valign)", function()
		local tall = { image = "x", width = 10, height = 30 }
		local short = { text = "ab" }
		local low = { text = "cd", valign = "bottom" }
		local root = { columns = { "auto", "auto", "auto" }, rowAlign = "center", height = 50, padding = 0, gap = 0,
			tall, short, low }
		local r = Layout.Run(root, nil, ctx())
		-- the row is 30 high; the block 50, so the row starts at 10
		assert.same({ 10, 19, 28 }, { r.items[1].y, r.items[2].y, r.items[3].y })
		assert.equals(50, r.height)
	end)

	it("stretches child blocks to their row's height (rowAlign stretch), their content centred in it", function()
		local cost = { text = "30 Mana cost" } -- wraps to two lines in its 60 px column
		local range = { text = "35 yd" }
		local a = { rowAlign = "center", padding = 0, cost }
		local b = { rowAlign = "center", padding = 0, range }
		local root = { columns = { 60, 60 }, rowAlign = "stretch", padding = 0, gap = 0, a, b }
		local r = Layout.Run(root, nil, ctx())
		assert.same({ 2 * LINE, 2 * LINE }, { r.items[1].h, r.items[2].h }, "both as tall as the row")
		assert.equals(2 * LINE, Layout.ResultOf(b).height, "the short one's own box too (its edges are full height)")
		assert.equals(LINE / 2, Layout.ResultOf(b).items[1].y, "its text in the middle")
		assert.equals(0, Layout.ResultOf(a).items[1].y)
	end)

	it("skips hidden children without leaving a gap", function()
		local invites = { text = "invites!", hidden = true }
		local block = { gap = 5, invites, { text = "Click: calendar" } }
		local r = Layout.Run(block, nil, ctx())
		assert.equals(LINE, r.height)
		assert.equals(1, r.count)
		invites.hidden = false
		r = Layout.Run(block, nil, ctx())
		assert.equals(LINE + 5 + LINE, r.height)
		assert.equals(2, r.count)
	end)

	it("lays out nested blocks in their cell and records their own result", function()
		local inner = { padding = 2, { text = "xx" } }
		local outer = { columns = { "auto", "1fr" }, gap = 0, { image = "icon", size = 16 }, inner }
		local r = Layout.Run(outer, 100, ctx())
		assert.equals(16, r.items[2].x)
		assert.equals(84, r.items[2].w)
		local innerResult = Layout.ResultOf(inner)
		assert.equals(84, innerResult.width)
		assert.equals(2 + LINE + 2, innerResult.height)
		assert.equals(16, r.height) -- the icon is taller than the nested text block
	end)

	it("shrinks fr columns first, then auto columns, when there is too little room", function()
		local block = { columns = { "auto", "1fr" }, gap = 0, width = 40,
			{ text = "abcdefghij" }, { text = "klmno" } } -- natural 60 + 0 (fr starts empty with a width)
		Layout.Run(block, nil, ctx())
		local res = Layout.ResultOf(block)
		assert.is_true(res.colWidth[2] >= 8)
		assert.equals(40, res.colWidth[1] + res.colWidth[2])
	end)

	describe("never lets content overflow", function()
		local function pad(block)
			local p = block.padding or 0
			if type(p) == "number" then
				return p, p, p, p
			end
			return p[1], p[2], p[3], p[4]
		end

		-- Every item inside its block's content box, every text at least as tall as it wraps to at its width,
		-- recursively through nested blocks.
		local function check(block, result, path)
			local top, right, bottom, left = pad(block)
			for i = 1, result.count do
				local item = result.items[i]
				local where = path .. "[" .. i .. "]" .. (item.node.text and (" " .. item.node.text) or "")
				assert.is_true(item.x >= left and item.x + item.w <= result.width - right + 1e-9,
					where .. " sticks out sideways")
				assert.is_true(item.y >= top and item.y + item.h <= result.height - bottom + 1e-9,
					where .. " sticks out at the bottom")
				if item.node.text then
					local _, needed = measure(item.node, item.w)
					assert.is_true(needed <= item.h, where .. " wraps to more lines than it got room for")
				elseif not item.node.image then
					check(item.node, Layout.ResultOf(item.node), where)
				end
			end
		end

		local LONG = "the quick brown fox jumps over the lazy dog again and again"

		local cases = {
			["a tooltip whose text is wider than its maxWidth"] = {
				{ maxWidth = 120, padding = 10, gap = 2, { text = "Title" }, { text = LONG }, { text = "hint" } },
			},
			["label/value rows in a narrow block"] = {
				{ width = 90, columns = { "auto", "1fr" }, gap = { 6, 2 }, padding = 4,
					{ text = "A long label here" }, { text = LONG, align = "right" },
					{ text = "Mail" }, { text = "3", align = "right" } },
			},
			["a spanning title longer than its columns, under a maxWidth"] = {
				{ maxWidth = 100, columns = { "auto", "auto" }, gap = 4,
					{ text = LONG, colSpan = 2 }, { text = "a" }, { text = "b" } },
			},
			["a nested block with padding in a fr column"] = {
				{ width = 150, columns = { 20, "1fr" }, gap = 0, padding = 3,
					{ image = "icon", size = 16 },
					{ padding = 5, gap = 1, { text = LONG }, { text = "second line of the nested block" } } },
			},
			["an image wider than its column"] = {
				{ width = 60, columns = { "1fr", "1fr" }, gap = 0, { image = "big", width = 50 }, { text = "x" } },
			},
			["shrink-to-fit with auto and fr columns and a maxWidth"] = {
				{ maxWidth = 140, columns = { "auto", "2fr", "1fr" }, gap = 3, padding = { 2, 4, 6, 8 },
					{ text = "Key" }, { text = LONG }, { text = "end" },
					{ text = LONG, colSpan = 3 } },
			},
		}

		for name, case in pairs(cases) do
			it(name, function()
				local block = case[1]
				check(block, Layout.Run(block, nil, ctx()), "root")
			end)
		end
	end)

	it("reuses its result tables (no garbage per layout)", function()
		local block = { { text = "a" } }
		local first = Layout.Run(block, nil, ctx())
		local second = Layout.Run(block, nil, ctx())
		assert.equals(first, second)
		assert.equals(first.items[1], second.items[1])
	end)

	describe("design scale and stretch elements", function()
		local TOKENS = { xs = 2, sm = 4, md = 8, lg = 12, xl = 16 }
		local function scaled(extra)
			local c = ctx()
			c.space = function(value)
				if type(value) == "string" then
					return TOKENS[value] or 0
				end
				return value
			end
			c.element = function(el)
				return el.width or 0, el.bar ~= nil and 6 or 9
			end
			for k, v in pairs(extra or {}) do
				c[k] = v
			end
			return c
		end

		it("reads spacing tokens in padding and gap, numbers still work", function()
			local r = Layout.Run({ padding = { "md", "lg", 3, "xs" }, gap = "sm", { text = "ab" }, { text = "cd" } }, nil,
				scaled())
			assert.equals(2 + 12 + 12, r.width) -- left xs + text + right lg
			assert.equals(8 + LINE + 4 + LINE + 3, r.height)
			assert.same({ 8, 12, 3, 2 }, { r.padTop, r.padRight, r.padBottom, r.padLeft })
		end)

		it("stretches separators and bars over the whole cell", function()
			local r = Layout.Run({
				columns = { "auto", "1fr" },
				{ text = "Label" },
				{ text = "Value" },
				{ separator = "rule", colSpan = 2 },
				{ bar = 0.5, colSpan = 2 },
			}, 200, scaled())
			assert.equals(200, r.items[3].w)
			assert.equals(9, r.items[3].h)
			assert.equals(200, r.items[4].w)
			assert.equals(6, r.items[4].h)
		end)

		it("shows shift rows only while Shift is held, and their opposites only while it isn't", function()
			local block = { { text = "always" }, { text = "more", shift = true }, { text = "hint", shift = false } }
			local up = Layout.Run(block, nil, scaled({ shift = false }))
			assert.equals(2, up.count)
			assert.equals("hint", up.items[2].node.text)
			local down = Layout.Run(block, nil, scaled({ shift = true }))
			assert.equals(2, down.count)
			assert.equals("more", down.items[2].node.text)
		end)
	end)

	describe("embedded components", function()
		local function withEmbeds()
			local c = ctx()
			c.embed = function(el)
				return el.embed.w, el.embed.h
			end
			return c
		end

		it("size their block like any child, side by side, and skip hidden ones", function()
			local a, b, c = { w = 80, h = 24 }, { w = 120, h = 24 }, { w = 999, h = 24 }
			local r = Layout.Run({ columns = { "auto", "auto", "auto" }, gap = 4, padding = 10,
				{ embed = a }, { embed = b }, { embed = c, hidden = true } }, nil, withEmbeds())
			assert.equals(10 + 80 + 4 + 120 + 4 + 10, r.width) -- the hidden one takes no cell; its column is empty
			assert.equals(24 + 20, r.height)
			assert.equals(2, r.count)
			assert.equals(10 + 80 + 4, r.items[2].x)
		end)

		it("make a block grow to fit them: the row is never narrower than its buttons", function()
			local r = Layout.Run({ minWidth = 100,
				{ text = "Short" },
				{ columns = { "auto", "auto" }, { embed = { w = 150, h = 20 } }, { embed = { w = 150, h = 20 } } },
			}, nil, withEmbeds())
			assert.is_true(r.width >= 300)
		end)
	end)
end)
