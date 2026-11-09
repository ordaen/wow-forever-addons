-- The drawing backend (addons/OrdaenCore/Backend/) on the fake client (tests/fake/wow.lua), as built: frozen attribute
-- tables (the build freezes static ones; the backend shares one computed style) lay out exactly like plain ones, a
-- new pixel size rounds every node again, Set and SetChildren skip only what can't have changed, and the Panel's
-- parts: art backgrounds, borders on named sides, embedded Blizzard frames, portraits under a mask.
local Fake = require("tests.fake.wow")

local DIST = ".ordaen/check/dist"

-- A logged-in client running the built Ordaen Core; returns it and the Core's namespace.
local function client(uiScale)
	local wow = Fake.New({ dist = DIST, addons = { "OrdaenCore" }, uiScale = uiScale })
	wow:Login()
	return wow, wow.addons.OrdaenCore.ns
end

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

	-- The grid of 25 cells drawn on a new client, from frozen or plain tables.
	local function run(frozen, uiScale)
		local wow, ns = client(uiScale)
		local grid, cell = copy(GRID), copy(CELL)
		if frozen then
			wow.env.table.freeze(grid)
			wow.env.table.freeze(cell)
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
		local wow, ns = client()
		local Backend = ns.Backend
		local grid, cell = wow.env.table.freeze(copy(GRID)), wow.env.table.freeze(copy(CELL))
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
			local wow, ns = client()
			local grid, cell = copy(GRID), copy(CELL)
			if frozen then
				wow.env.table.freeze(grid)
				wow.env.table.freeze(cell)
			end
			local g, cells, texts = draw(ns.Backend, grid, cell, 25)
			wow:SetScreen(wow.physW, wow.physH, 0.8) -- the player changed the UI scale
			local fg, fcells, ftexts = run(frozen, 0.8)
			same(g, fg, "grid")
			for i = 1, #cells do
				same(cells[i], fcells[i], "cell " .. i)
				same(texts[i], ftexts[i], "text " .. i)
			end
		end
	end)

	describe("Set and SetChildren skip only what can't have changed", function()
		local wow, Backend
		before_each(function()
			local ns
			wow, ns = client()
			Backend = ns.Backend
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
			local A = wow.env.table.freeze({ width = 10, OnClick = clicks })
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
		local wow, ns = client()
		local plain = wow.env.table.freeze({ width = 36, height = 36 }) -- the text fills it (a centred one would move)
		local _, cells, texts = draw(ns.Backend, wow.env.table.freeze(copy(GRID)), plain, 25)
		assert.is_nil(cells[1].cCol)
		local t = texts[1]
		local oldW, oldH = t.natW, t.lineH
		t.natW = oldW + 1 -- still narrower than the 36-unit cell
		assert.is_false(ns.Layout.TextResized(t, oldW, oldH))
	end)

	it("draws a panel strip: wood covering it, the metal edge along the top only, content below the edge", function()
		local wow, ns = client()
		local Backend = ns.Backend
		local layer = Backend:Layer("screen")
		local strip = Backend:Create("box")
		Backend:Set(strip, wow.env.table.freeze({ position = "fixed", left = 0, right = 0, bottom = 0, height = 60,
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

	describe("an embedded Blizzard frame", function()
		local wow, Backend, layer, row, bag, home
		before_each(function()
			local ns
			wow, ns = client()
			Backend = ns.Backend
			home = wow.env.CreateFrame("Frame", nil, wow.env.UIParent)
			bag = wow.env.CreateFrame("Button", nil, home)
			bag:SetSize(30, 30)
			bag:SetPoint("BOTTOMRIGHT", home, "BOTTOMRIGHT", -4, 4)
			layer = Backend:Layer("screen")
			row = Backend:Create("box")
			Backend:Set(row, { columns = 2, position = "absolute", left = 100, top = 50 })
		end)

		local function drawRow()
			local before = Backend:Create("box")
			Backend:Set(before, { width = 40, height = 20 })
			local cell = Backend:Embed(bag)
			Backend:Set(cell, { width = 24, height = 24 })
			Backend:SetChildren(row, { before, cell }, 2)
			Backend:SetChildren(layer, { row }, 1)
			Backend:Flush()
			return cell
		end

		it("sits in its cell: our parent, one TOPLEFT point, our size", function()
			local cell = drawRow()
			assert.are.equal(row.frame, bag:GetParent())
			assert.are.equal(1, bag:GetNumPoints())
			local point, rel, _, x = bag:GetPoint(1)
			assert.are.equal("TOPLEFT", point)
			assert.are.equal(row.frame, rel)
			assert.is_true(x >= 40)
			assert.are.same({ cell.pW, cell.pH }, { bag._w, bag._h })
			assert.is_true(bag:IsShown())
		end)

		it("goes back where it was after Blizzard moves it", function()
			drawRow()
			local _, _, _, x, y = bag:GetPoint(1)
			bag:ClearAllPoints()
			bag:SetPoint("CENTER", wow.env.UIParent, "CENTER", 0, 0)
			local point, rel, _, x2, y2 = bag:GetPoint(1)
			assert.are.same({ "TOPLEFT", row.frame, x, y }, { point, rel, x2, y2 })
		end)

		it("waits for combat to end when protected", function()
			bag._protected = true
			wow.combat = true
			drawRow()
			assert.are.equal(home, bag:GetParent())
			assert.are.equal("BOTTOMRIGHT", (bag:GetPoint(1)))
			wow.combat = false
			wow:Fire("PLAYER_REGEN_ENABLED")
			assert.are.equal(row.frame, bag:GetParent())
			assert.are.equal("TOPLEFT", (bag:GetPoint(1)))
		end)

		it("is given back as it was on release", function()
			local cell = drawRow()
			Backend:SetChildren(row, {}, 0)
			Backend:Release(cell)
			assert.are.equal(home, bag:GetParent())
			local point, rel, _, x, y = bag:GetPoint(1)
			assert.are.same({ "BOTTOMRIGHT", home, -4, 4 }, { point, rel, x, y })
			assert.are.same({ 30, 30 }, { bag._w, bag._h })
			bag:SetPoint("CENTER", wow.env.UIParent, "CENTER", 0, 0) -- Blizzard moving it now isn't undone
			assert.are.equal("CENTER", (bag:GetPoint(1)))
		end)
	end)

	it("draws a unit's face under a mask, redraws it on the portrait events, and stops when released", function()
		local wow, ns = client()
		local Backend = ns.Backend
		local layer = Backend:Layer("screen")
		local corner = Backend:Create("box")
		Backend:Set(corner, wow.env.table.freeze({ position = "fixed", left = 0, bottom = 0, width = 128, height = 124,
			background = ref("color.surface"), portrait = "player", mask = ref("panel.corner") }))
		Backend:SetChildren(layer, { corner }, 1)
		Backend:Flush()
		assert.are.equal("player", corner.face._portrait)
		assert.is_true(corner.face._masks[corner.maskTex])
		assert.is_true(corner.bg._masks[corner.maskTex])
		assert.is_true(corner.rimTex:IsShown())
		assert.is_false(corner.mouse) -- no handler: it takes no clicks
		local drawn = wow.faces
		wow:Fire("UNIT_PORTRAIT_UPDATE", "player")
		assert.are.equal(drawn + 1, wow.faces)
		wow:Fire("UNIT_PORTRAIT_UPDATE", "target")
		assert.are.equal(drawn + 1, wow.faces)
		Backend:SetChildren(layer, {}, 0)
		Backend:Release(corner)
		wow:Fire("PORTRAITS_UPDATED")
		assert.are.equal(drawn + 1, wow.faces)
	end)
end)
