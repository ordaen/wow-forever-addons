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

	it("reuses its result tables (no garbage per layout)", function()
		local block = { { text = "a" } }
		local first = Layout.Run(block, nil, ctx())
		local second = Layout.Run(block, nil, ctx())
		assert.equals(first, second)
		assert.equals(first.items[1], second.items[1])
	end)
end)
