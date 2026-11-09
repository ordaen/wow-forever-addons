-- The drawing backend (addons/OrdaenCore/Backend/Backend.lua) on the fake game: a box drawn from a frozen attribute
-- table (the build freezes static ones; the backend then shares one computed style) lays out exactly like the same
-- attributes in a plain table.
local Fake = dofile("tests/OrdaenCore/fake_game.lua")

local function ref(path)
	return { path = path } -- a theme reference: the only attribute value with a raw `path`
end

local FIELDS = { "wKind", "wAmount", "hKind", "hAmount", "span", "pos", "offT", "offR", "offB", "offL", "ncols", "gapR",
	"gapC", "padT", "padR", "padB", "padL", "xAlign", "yAlign", "bwT", "bwR", "bwB", "bwL", "x", "y", "w", "h", "pX", "pY",
	"pW", "pH" }

local function copy(t)
	local c = {}
	for k, v in pairs(t) do
		c[k] = v
	end
	return c
end

-- Draw a grid of cells, each holding a text, under the screen layer; returns the grid, its cells and their texts.
local function draw(Backend, grid, cell, n)
	local layer = Backend:Layer("screen")
	local g = Backend:Create("box")
	Backend:Set(g, grid)
	local cells, texts = {}, {}
	for i = 1, n do
		local c = Backend:Create("box")
		Backend:Set(c, cell)
		local t = Backend:Create("text")
		Backend:Set(t, { text = "%d", arguments = { i * 7 } })
		Backend:SetChildren(c, { t }, 1)
		cells[i], texts[i] = c, t
	end
	Backend:SetChildren(g, cells, n)
	Backend:SetChildren(layer, { g }, 1)
	Backend:Flush()
	return g, cells, texts
end

local function same(a, b, what)
	for _, f in ipairs(FIELDS) do
		assert.are.equal(b[f], a[f], what .. "." .. f)
	end
	local ka, kb = a.colKind, b.colKind
	if not kb then
		assert.is_nil(ka, what .. ".colKind")
		return
	end
	for c = 1, a.ncols or 1 do
		assert.are.equal(kb[c], ka[c], what .. ".colKind[" .. c .. "]")
		assert.are.equal(b.colAmount[c], a.colAmount[c], what .. ".colAmount[" .. c .. "]")
	end
end

describe("backend styles", function()
	local GRID = { columns = 10, gap = ref("spacing.xs"), padding = ref("spacing.md"), position = "absolute", left = 10,
		top = 10, background = ref("color.surface") }
	local CELL = { width = 36, height = 36, xAlign = "center", yAlign = "center", background = ref("color.border") }

	local function run(frozen, uiHeight)
		Fake.Install(uiHeight)
		local ns = Fake.LoadBackend()
		local grid, cell = copy(GRID), copy(CELL)
		if frozen then
			table.freeze(grid)
			table.freeze(cell)
		end
		return draw(ns.Backend, grid, cell, 25)
	end

	it("lays out a frozen grid and its cells exactly like plain tables", function()
		local pg, pcells, ptexts = run(false)
		local fg, fcells, ftexts = run(true)
		same(fg, pg, "grid")
		for i = 1, #pcells do
			same(fcells[i], pcells[i], "cell " .. i)
			same(ftexts[i], ptexts[i], "text " .. i)
		end
	end)

	it("centres a text in a frozen fixed cell", function()
		local _, cells, texts = run(true)
		local c, t = cells[1], texts[1]
		assert.are.equal("center", c.xAlign)
		assert.is_true(t.x > 0 and t.y > 0, "text at " .. tostring(t.x) .. "," .. tostring(t.y))
	end)

	it("keeps a frozen cell's layout when its node is reused from the pool", function()
		Fake.Install()
		local ns = Fake.LoadBackend()
		local Backend = ns.Backend
		local grid, cell = table.freeze(copy(GRID)), table.freeze(copy(CELL))
		local g, cells = draw(Backend, grid, cell, 5)
		for i = #cells, 1, -1 do
			Backend:Release(cells[i])
		end
		Backend:Release(g)
		local _, again, texts = draw(Backend, grid, cell, 5)
		local _, plain, ptexts = run(false)
		for i = 1, 5 do
			same(again[i], plain[i], "reused cell " .. i)
			same(texts[i], ptexts[i], "reused text " .. i)
		end
	end)

	it("rounds every node again when the pixel size changes", function()
		for _, frozen in ipairs({ false, true }) do
			local ui = Fake.Install()
			local ns = Fake.LoadBackend()
			local grid, cell = copy(GRID), copy(CELL)
			if frozen then
				table.freeze(grid)
				table.freeze(cell)
			end
			local g, cells, texts = draw(ns.Backend, grid, cell, 25)
			ui._h, ui._w = 1200, 1200 * 16 / 9 -- UI scale 0.64: one pixel is 1200 / 720 units
			local layer = ns.Backend:Layer("screen")
			layer.frame._scripts.OnSizeChanged(layer.frame, ui._w, ui._h)
			local fg, fcells, ftexts = run(frozen, 1200)
			same(g, fg, "grid")
			for i = 1, #cells do
				same(cells[i], fcells[i], "cell " .. i)
				same(texts[i], ftexts[i], "text " .. i)
			end
		end
	end)

	describe("Set and SetChildren skip only what can't have changed", function()
		local Backend
		before_each(function()
			Fake.Install()
			Backend = Fake.LoadBackend().Backend
		end)

		it("drops a key the new table leaves out", function()
			local b = Backend:Create("box")
			Backend:Set(b, { width = 10, background = ref("color.surface"), padding = 4 })
			Backend:Set(b, { width = 10 })
			assert.is_nil(b.a.background)
			assert.is_nil(b.a.padding)
			assert.are.equal(0, b.padT)
			assert.are.equal(1, b.na)
		end)

		it("applies a frozen table again after the node was released and reused", function()
			local clicks = function() end
			local A = table.freeze({ width = 10, OnClick = clicks })
			local layer = Backend:Layer("screen")
			local b = Backend:Create("box")
			Backend:Set(b, A)
			Backend:SetChildren(layer, { b }, 1)
			Backend:Flush()
			Backend:SetChildren(layer, {}, 0)
			Backend:Release(b)
			local again = Backend:Create("box")
			assert.are.equal(b, again)
			Backend:Set(again, A)
			assert.are.equal(clicks, again.a.OnClick)
			assert.is_true(again.mouse)
		end)

		it("keeps children sent again in the same order, and applies a new order", function()
			local layer = Backend:Layer("screen")
			local g = Backend:Create("box")
			Backend:Set(g, { columns = 2, position = "absolute", left = 0, top = 0 })
			local x, y = Backend:Create("box"), Backend:Create("box")
			Backend:Set(x, { width = 10, height = 10 })
			Backend:Set(y, { width = 20, height = 10 })
			Backend:SetChildren(g, { x, y }, 2)
			Backend:SetChildren(layer, { g }, 1)
			Backend:Flush()
			local xAt = x.x
			Backend:SetChildren(g, { x, y }, 2)
			assert.is_not_true(g.queued)
			Backend:SetChildren(g, { y, x }, 2)
			Backend:Flush()
			assert.are.equal(xAt, y.x)
			assert.is_true(x.x > y.x)
		end)
	end)

	it("keeps no cell arrays for a one-child cell, and still skips the layout for a text change inside it", function()
		Fake.Install()
		local ns = Fake.LoadBackend()
		local plain = table.freeze({ width = 36, height = 36 }) -- the text fills it (a centred one would move)
		local _, cells, texts = draw(ns.Backend, table.freeze(copy(GRID)), plain, 25)
		assert.is_nil(cells[1].cCol)
		local t = texts[1]
		local oldW, oldH = t.natW, t.lineH
		t.natW = oldW + 6 -- still narrower than the 36-unit cell
		assert.is_false(ns.Layout.TextResized(t, oldW, oldH))
	end)

	it("draws a panel strip: wood covering it, the metal edge along the top only, content below the edge", function()
		Fake.Install()
		local ns = Fake.LoadBackend()
		local Backend = ns.Backend
		local layer = Backend:Layer("screen")
		local strip = Backend:Create("box")
		Backend:Set(strip, table.freeze({ position = "fixed", left = 0, right = 0, bottom = 0, height = 60,
			background = ref("panel.wood"), border = ref("panel.edge") }))
		local cell = Backend:Create("box")
		Backend:Set(cell, { width = 40 })
		Backend:SetChildren(strip, { cell }, 1)
		Backend:SetChildren(layer, { strip }, 1)
		Backend:Flush()
		assert.is_true(strip.bwT > 0)
		assert.are.same({ 0, 0, 0 }, { strip.bwR, strip.bwB, strip.bwL })
		assert.are.equal(strip.bwT, cell.y) -- below the metal
		assert.are.equal(0, cell.x) -- flush left
		assert.are.equal(strip.bwT, strip.edgeArt._h)
		assert.are.equal("UI-Frame-GenericMetal-EdgeLeft", strip.edgeArt._atlas)
		assert.are.equal("UI-Character-Info-General-BG", strip.bg._atlas)
		-- the strip is far wider than the 2:1 art: its full width, a band of its height
		local l, r, t, b = unpack(strip.bg._coords)
		assert.are.same({ 0, 1 }, { l, r })
		assert.is_true(t > 0 and b < 1 and math.abs(t - (1 - b)) < 1e-9)
	end)
end)
