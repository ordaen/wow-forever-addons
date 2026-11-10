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

-- A region's TOPLEFT point's y offset (points come back in no fixed order).
local function topLeftY(region)
	for i = 1, region:GetNumPoints() do
		local point, _, _, _, y = region:GetPoint(i)
		if point == "TOPLEFT" then
			return y
		end
	end
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

	it("skips the layout of a content-sized grid for a text that isn't its column's widest, before and after", function()
		local wow, ns = client()
		local Backend = ns.Backend
		local layer = Backend:Layer("screen")
		local g = Backend:Create("box")
		Backend:Set(g, wow.env.table.freeze({ columns = 1, position = "absolute", left = 0, top = 0 }))
		local wide, short = Backend:Create("text"), Backend:Create("text")
		Backend:Set(wide, { text = "1000000000" })
		Backend:Set(short, { text = "1" })
		Backend:SetChildren(g, { wide, short }, 2)
		Backend:SetChildren(layer, { g }, 1)
		Backend:Flush()
		local gw, oldW, oldH = g.w, short.natW, short.lineH
		assert.are.equal(wide.natW, g.colNat[1])
		short.natW = wide.natW -- as wide as the widest: no column changes
		assert.is_false(ns.Layout.TextResized(short, oldW, oldH))
		short.natW = wide.natW + 1 -- wider: the column grows
		assert.is_true(ns.Layout.TextResized(short, oldW, oldH))
		wide.natW, short.natW = oldW, oldW -- the widest shrinks: the column may too
		assert.is_true(ns.Layout.TextResized(wide, g.colNat[1], oldH))
		-- drawn: a longer text that still fits keeps the grid and its cell
		short.natW = oldW
		wide.natW = g.colNat[1]
		Backend:Set(short, { text = "100" })
		Backend:Flush()
		assert.are.equal(gw, g.w)
		assert.are.equal(gw, short.w)
		assert.are.equal("100", short.fs:GetText())
	end)

	it("scrolls a box's children with the wheel within their extent, and clips them", function()
		local _, ns = client()
		local Backend = ns.Backend
		local layer = Backend:Layer("screen")
		local box = Backend:Create("box")
		Backend:Set(box, { position = "absolute", left = 0, top = 0, width = 100, height = 100, overflow = "scroll" })
		local rows = {}
		for i = 1, 10 do
			local row = Backend:Create("box")
			Backend:Set(row, { height = 30 })
			rows[i] = row
		end
		local label = Backend:Create("text")
		Backend:Set(label, { text = "end" })
		rows[11] = label
		Backend:SetChildren(box, rows, 11)
		Backend:SetChildren(layer, { box }, 1)
		Backend:Flush()
		local frame, inner = box.frame, box.inner
		assert.is_true(frame:DoesClipChildren())
		assert.is_true(frame:IsMouseWheelEnabled())
		assert.are.equal(inner, rows[1].frame:GetParent())
		assert.are.equal(inner, label.fs:GetParent():GetParent()) -- the texts' frame, above the rows, sits in it too
		local extent = label.y + label.h -- the last row's laid-out bottom
		assert.are.equal(extent, inner:GetHeight())
		local wheel = frame:GetScript("OnMouseWheel")
		wheel(frame, -1) -- down one notch
		assert.is_true(math.abs(box.scrollY - 40) < 1) -- one notch, on a whole pixel
		for _ = 1, 20 do
			wheel(frame, -1)
		end
		assert.is_true(math.abs(box.scrollY - (extent - 100)) < 1) -- held at the content's end, on a whole pixel
		wheel(frame, 50)
		assert.are.equal(0, box.scrollY)
		-- fewer children: the position is held within the new extent at the next layout
		for _ = 1, 20 do
			wheel(frame, -1)
		end
		Backend:SetChildren(box, { rows[1], rows[2], rows[3], rows[4] }, 4)
		Backend:Flush()
		assert.is_true(math.abs(box.scrollY - (rows[4].y + rows[4].h - 100)) < 1)
		-- back to visible: the children sit in the box's own frame again
		Backend:Set(box, { position = "absolute", left = 0, top = 0, width = 100, height = 100 })
		Backend:Flush()
		assert.is_nil(box.inner)
		assert.is_false(frame:DoesClipChildren())
		assert.are.equal(frame, rows[1].frame:GetParent())
	end)

	it("takes typed text in an input box: OnChange for typing, OnSubmit on Enter, focus, then a plain box", function()
		local wow, ns = client()
		local Backend = ns.Backend
		local layer = Backend:Layer("screen")
		local changes, submits = {}, {}
		local A = {
			kind = "input", position = "absolute", left = 0, top = 0, width = 200, height = 24, padding = 4,
			text = "Ordaen", textSize = 12, maxLength = 24, focus = true,
			OnChange = function(text)
				changes[#changes + 1] = text
			end,
			OnSubmit = function(text)
				submits[#submits + 1] = text
			end,
		}
		local box = Backend:Create("box")
		Backend:Set(box, A)
		Backend:SetChildren(layer, { box }, 1)
		Backend:Flush()
		local edit = box.edit
		assert.are.equal("Ordaen", edit:GetText())
		assert.are.equal(24, edit:GetMaxLetters())
		assert.is_true(edit:HasFocus())
		assert.are.same({}, changes) -- the render's own text is no change
		wow:Type(edit, "My theme")
		assert.are.same({ "My theme" }, changes)
		-- the render writes the typed text back: the box keeps it as typed
		Backend:Set(box, setmetatable({ text = "My theme" }, { __index = A }))
		assert.are.equal("My theme", edit:GetText())
		wow:Enter(edit)
		assert.are.same({ "My theme" }, submits)
		assert.is_false(edit:HasFocus())
		-- a plain box again: the edit box hides
		Backend:Set(box, { position = "absolute", left = 0, top = 0, width = 200, height = 24 })
		assert.is_false(edit:IsShown())
	end)

	it("drags a box: start, moves once a frame from where it began, stop; the wheel and the click's position", function()
		local wow, ns = client()
		local Backend = ns.Backend
		local layer = Backend:Layer("screen")
		local log = {}
		local box = Backend:Create("box")
		Backend:Set(box, { position = "absolute", left = 100, top = 100, width = 200, height = 20,
			OnDragStart = function(x, y)
				log[#log + 1] = { "start", x, y }
			end,
			OnDrag = function(x, y)
				log[#log + 1] = { "drag", x, y }
			end,
			OnDragStop = function(x, y)
				log[#log + 1] = { "stop", x, y }
			end,
			OnWheel = function(delta)
				log[#log + 1] = { "wheel", delta }
			end,
			OnClick = function(button, x)
				log[#log + 1] = { "click", button, x }
			end,
		})
		Backend:SetChildren(layer, { box }, 1)
		Backend:Flush()
		local frame = box.frame
		local scale = frame:GetEffectiveScale()
		local left, top = frame:GetLeft(), frame:GetTop()
		local function at(x, y) -- the cursor at (x, y) UI units from the box's top left, in screen pixels
			wow:MoveCursor((left + x) * scale, (top - y) * scale)
		end
		at(10, 5)
		wow:DragStart(frame)
		at(60, 5)
		wow:Tick()
		wow:Tick() -- the cursor didn't move: no second OnDrag
		at(90, 8)
		wow:DragStop(frame)
		local function near(a, b)
			return math.abs(a - b) < 0.01
		end
		assert.are.equal(3, #log)
		assert.are.equal("start", log[1][1])
		assert.is_true(near(log[1][2], 10) and near(log[1][3], 5))
		assert.are.equal("drag", log[2][1])
		assert.is_true(near(log[2][2], 60))
		assert.are.equal("stop", log[3][1])
		assert.is_true(near(log[3][2], 90) and near(log[3][3], 8))
		assert.is_nil(frame:GetScript("OnUpdate")) -- nothing runs per frame once the drag ends
		frame:GetScript("OnMouseWheel")(frame, 1)
		assert.are.same({ "wheel", 1 }, log[4])
		at(25, 5)
		frame:GetScript("OnClick")(frame, "LeftButton")
		assert.are.equal("click", log[5][1])
		assert.is_true(near(log[5][3], 25))
	end)

	it("draws a text in a theme font with a shadow, and drops the shadow", function()
		local _, ns = client()
		local Backend = ns.Backend
		local layer = Backend:Layer("screen")
		local t = Backend:Create("text")
		Backend:Set(t, { text = "7", textSize = 11, textFamily = ref("font.numbers"),
			textShadow = { color = { 1, 1, 1, 1 }, x = 1, y = 0 } })
		Backend:SetChildren(layer, { t }, 1)
		Backend:Flush()
		local font, size = t.fs:GetFont()
		assert.are.equal(ns.Theme["font.numbers"], font)
		assert.are.equal(11, size)
		local x, y = t.fs:GetShadowOffset()
		assert.is_true(x > 0)
		assert.are.equal(0, y)
		assert.are.same({ 1, 1, 1, 1 }, { t.fs:GetShadowColor() })
		Backend:Set(t, { text = "7", textSize = 11 })
		Backend:Flush()
		assert.are.equal(ns.Theme["font.body"], (t.fs:GetFont()))
		assert.are.same({ 0, 0 }, { t.fs:GetShadowOffset() })
	end)

	it("outlines a text and sets its lines where textYAlign says, and goes back to plain at the top", function()
		local wow, ns = client()
		local Backend = ns.Backend
		local layer = Backend:Layer("screen")
		local t = Backend:Create("text")
		Backend:Set(t, { position = "absolute", left = 0, right = 0, top = 0, bottom = 0, text = "85%",
			textOutline = "thin", textYAlign = "center" })
		Backend:SetChildren(layer, { t }, 1)
		Backend:Flush()
		local _, _, flags = t.fs:GetFont()
		assert.are.equal("OUTLINE", flags)
		assert.are.equal("MIDDLE", t.fs:GetJustifyV())
		Backend:Set(t, { text = "85%", textOutline = "thick", textYAlign = "end" })
		Backend:Flush()
		assert.are.equal("THICKOUTLINE", select(3, t.fs:GetFont()))
		assert.are.equal("BOTTOM", t.fs:GetJustifyV())
		Backend:Set(t, { text = "85%" })
		Backend:Flush()
		assert.are.equal("", select(3, t.fs:GetFont()))
		assert.are.equal("TOP", t.fs:GetJustifyV())
		assert.are.same({}, wow.errors)
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
		local top = strip.frameArt.top
		assert.are.equal("!UI-Frame-Metal-EdgeLeft", top._atlas)
		assert.is_true(topLeftY(top) > 0) -- its outer side above the strip
		assert.is_true(top._h > strip.bwT) -- the art at its own thickness, past the content's inset
		assert.is_nil(strip.frameArt.left) -- the strip draws only the top
		assert.is_nil(strip.frameArt.tlSide)
		assert.is_true(topLeftY(strip.bg) < 0) -- the wood starts under the metal
		assert.are.equal("UI-Character-Info-General-BG", strip.bg._atlas)
		-- the strip is far wider than the art (398 x 464): its full width, a band of its height
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

	it("draws the player's face round in a cell (panel.faceRound): masked, with its ring", function()
		local wow, ns = client()
		local Backend = ns.Backend
		local layer = Backend:Layer("screen")
		local face = Backend:Create("box")
		Backend:Set(face, wow.env.table.freeze({ position = "absolute", left = 0, top = 0, width = 40 / 1.2,
			height = 40 / 1.2, portrait = "player", mask = ref("panel.faceRound") }))
		Backend:SetChildren(layer, { face }, 1)
		Backend:Flush()
		assert.are.equal("player", face.face._portrait)
		assert.is_true(face.face._masks[face.maskTex])
		assert.is_true(face.rimTex:IsShown())
		assert.are.same({}, wow.errors)
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
		-- the pooled box reused without a portrait shows no face
		local again = Backend:Create("box")
		assert.are.equal(corner, again)
		Backend:Set(again, wow.env.table.freeze({ position = "fixed", left = 0, top = 0, width = 300, height = 200,
			background = ref("color.surface") }))
		Backend:SetChildren(layer, { again }, 1)
		Backend:Flush()
		assert.is_false(again.face:IsShown())
	end)

	it("a pooled box reused with a table draws as a fresh box given it: nothing of its last look stays", function()
		local wow, ns = client()
		local Backend = ns.Backend
		local layer = Backend:Layer("screen")
		local plain = wow.env.table.freeze({ position = "fixed", left = 0, top = 0, width = 300, height = 200,
			background = ref("color.surface") })
		local fresh = Backend:Create("box")
		Backend:Set(fresh, plain)
		-- another box with every look it can have, released, then reused for the plain table
		local used = Backend:Create("box")
		Backend:Set(used, wow.env.table.freeze({ position = "fixed", left = 0, bottom = 0, width = 128, height = 124,
			background = ref("color.surface"), portrait = "player", mask = ref("panel.corner"), tint = "#ff0000",
			desaturate = true, opacity = 0.5 }))
		Backend:SetChildren(layer, { fresh, used }, 2)
		Backend:Flush()
		Backend:SetChildren(layer, { fresh }, 1)
		Backend:Release(used)
		local again = Backend:Create("box")
		assert.are.equal(used, again)
		Backend:Set(again, plain)
		Backend:SetChildren(layer, { fresh, again }, 2)
		Backend:Flush()
		assert.is_false(again.face:IsShown())
		assert.are.equal(fresh.lookTint, again.lookTint)
		assert.are.equal(fresh.lookDesat, again.lookDesat)
		assert.are.equal(fresh.frame:GetAlpha(), again.frame:GetAlpha())
		assert.are.same(fresh.bg._masks or {}, again.bg._masks or {})
		wow:Fire("UNIT_PORTRAIT_UPDATE", "player") -- and no event of its old face redraws it
		assert.is_false(again.face:IsShown())
	end)

	it("draws a frame's metal on all four sides: the edges, the bottom corners, mitred top corners, the wood", function()
		local wow, ns = client()
		local Backend = ns.Backend
		local layer = Backend:Layer("screen")
		local window = Backend:Create("box")
		Backend:Set(window, wow.env.table.freeze({ position = "absolute", left = 100, top = 100, width = 400,
			height = 300, background = ref("panel.wood"), border = ref("frame.small") }))
		Backend:SetChildren(layer, { window }, 1)
		Backend:Flush()
		local art = window.frameArt
		for _, key in ipairs({ "top", "bottom", "left", "right", "bl", "br", "tlSide", "tlTop", "trSide", "trTop" }) do
			assert.is_truthy(art[key], key)
			assert.is_true(art[key]:IsShown(), key)
		end
		assert.are.equal("!UI-Frame-Metal-EdgeLeft", art.top._atlas)
		assert.are.equal("!UI-Frame-Metal-EdgeLeft", art.tlTop._atlas) -- the turned top's square
		assert.is_truthy(art.tlSideMask and art.tlTopMask and art.trSideMask and art.trTopMask)
		-- the top-right square sits lower than the top-left's (the right line meets the top line), its top piece shorter
		assert.is_true(select(5, art.trSide:GetPoint(1)) < select(5, art.tlSide:GetPoint(1))) -- each by its outer corner
		assert.is_true(art.trTop._coords[1] > 0) -- the turned top's art starts lower in it: drawn higher, in line
		assert.are.equal(0, art.tlTop._coords[1])
		-- the wood inside the art's inset on every side
		assert.is_true(window.fillTop > 0 and window.fillRight > 0 and window.fillBottom > 0 and window.fillLeft > 0)
		-- a plain border again: the art goes
		Backend:Set(window, { position = "absolute", left = 100, top = 100, width = 400, height = 300 })
		Backend:Flush()
		assert.is_false(art.top:IsShown())
		assert.is_false(art.tlSide:IsShown())
	end)

	it("raises a box with zLevel above what its parent's later siblings draw (a menu over the rows below)", function()
		local _, ns = client()
		local Backend = ns.Backend
		local layer = Backend:Layer("screen")
		local page = Backend:Create("box")
		Backend:Set(page, { position = "absolute", left = 0, top = 0, width = 300, columns = 1 })
		local row1, row2 = Backend:Create("box"), Backend:Create("box")
		Backend:Set(row1, { height = 30 })
		Backend:Set(row2, { height = 30 })
		local menu = Backend:Create("box")
		Backend:Set(menu, { position = "absolute", left = 0, top = 30, width = 100, height = 120, zLevel = 50 })
		local field = Backend:Create("box")
		Backend:Set(field, { height = 20, width = 100 })
		Backend:SetChildren(row1, { menu }, 1)
		Backend:SetChildren(row2, { field }, 1)
		Backend:SetChildren(page, { row1, row2 }, 2)
		Backend:SetChildren(layer, { page }, 1)
		Backend:Flush()
		assert.is_true(menu.frame:GetFrameLevel() > field.frame:GetFrameLevel())
		-- no zLevel again: back among its parent's children
		Backend:Set(menu, { position = "absolute", left = 0, top = 30, width = 100, height = 120 })
		assert.are.equal(row1.frame:GetFrameLevel() + 1, menu.frame:GetFrameLevel())
	end)

	it("greys and tints a texture background, the art's slices too, and gives them back", function()
		local _, ns = client()
		local Backend = ns.Backend
		local layer = Backend:Layer("screen")
		local GOLD = { 1, 0.85, 0.4, 1 }
		local icon = Backend:Create("box")
		Backend:Set(icon, { position = "absolute", left = 0, top = 0, width = 22, height = 22,
			background = "Interface/Icons/INV_Misc_Bag_08", desaturate = true, tint = GOLD })
		local plate = Backend:Create("box")
		Backend:Set(plate, { position = "absolute", left = 0, top = 40, width = 120, height = 28,
			background = ref("ctl.button"), desaturate = true })
		Backend:SetChildren(layer, { icon, plate }, 2)
		Backend:Flush()
		assert.is_true(icon.bg:IsDesaturated())
		assert.are.same(GOLD, icon.bg._vertex)
		for i = 1, 3 do
			assert.is_true(plate.slices[i]:IsDesaturated(), "slice " .. i) -- made at its first draw, after the look
		end
		Backend:Set(icon, { position = "absolute", left = 0, top = 0, width = 22, height = 22,
			background = "Interface/Icons/INV_Misc_Bag_08" })
		assert.is_false(icon.bg:IsDesaturated())
		assert.are.same({ 1, 1, 1, 1 }, icon.bg._vertex)
	end)

	it("keeps a hoverWithin box hovered over its children, and ends the hover once the cursor is out", function()
		local wow, ns = client()
		local Backend = ns.Backend
		local layer = Backend:Layer("screen")
		local leaves = 0
		local box = Backend:Create("box")
		Backend:Set(box, { position = "absolute", left = 100, top = 100, width = 200, height = 100, hoverWithin = true,
			OnLeave = function()
				leaves = leaves + 1
			end })
		local child = Backend:Create("box")
		Backend:Set(child, { width = 50, height = 50, OnClick = function() end })
		Backend:SetChildren(box, { child }, 1)
		Backend:SetChildren(layer, { box }, 1)
		Backend:Flush()
		local frame = box.frame
		local scale = frame:GetEffectiveScale()
		local function at(x, y)
			wow:MoveCursor((frame:GetLeft() + x) * scale, (frame:GetTop() - y) * scale)
		end
		at(150, 50)
		frame:GetScript("OnEnter")(frame)
		assert.is_true(box.hovered)
		at(10, 10) -- onto the child: WoW leaves the box
		frame:GetScript("OnLeave")(frame)
		assert.is_true(box.hovered)
		assert.are.equal(0, leaves)
		wow:Tick()
		assert.is_true(box.hovered)
		at(500, 500) -- out of the box (from the child: the box gets no event)
		for _ = 1, 10 do
			wow:Tick()
		end
		assert.is_false(box.hovered)
		assert.are.equal(1, leaves)
		assert.is_nil(frame:GetScript("OnUpdate")) -- nothing runs once it's out
	end)

	it("anchors a free box by its point to its parent's, moved from there by left and top; plain offsets again", function()
		local _, ns = client()
		local Backend = ns.Backend
		local layer = Backend:Layer("screen")
		local CENTER = { point = "CENTER", relativePoint = "CENTER" }
		local window = Backend:Create("box")
		Backend:Set(window, { position = "absolute", width = 400, height = 300, anchor = CENTER, left = 30, top = 20 })
		Backend:SetChildren(layer, { window }, 1)
		Backend:Flush()
		local frame = window.frame
		assert.are.equal(1, frame:GetNumPoints())
		local point, rel, relPoint, x, y = frame:GetPoint(1)
		assert.are.same({ "CENTER", "CENTER" }, { point, relPoint })
		assert.are.equal(layer.frame, rel)
		assert.is_true(math.abs(x - 30) < 1 and math.abs(y + 20) < 1) -- 30 right, 20 down
		-- dragged: only the offsets change, the anchor stays
		Backend:SetField(window, "left", 80)
		Backend:Flush()
		point, _, _, x = frame:GetPoint(1)
		assert.are.equal("CENTER", point)
		assert.is_true(math.abs(x - 80) < 1)
		-- no anchor: by its top left again
		Backend:Set(window, { position = "absolute", width = 400, height = 300, left = 10, top = 10 })
		Backend:Flush()
		assert.are.equal(1, frame:GetNumPoints())
		assert.are.equal("TOPLEFT", (frame:GetPoint(1)))
	end)

	it("draws one part of a file as a background (a glyph of an atlas)", function()
		local wow, ns = client()
		local Backend = ns.Backend
		local layer = Backend:Layer("screen")
		local glyph = Backend:Create("box")
		Backend:Set(glyph, { position = "absolute", width = 16, height = 16,
			background = { file = "Interface\AddOns\Spec\glyphs", coords = { 0.125, 0.25, 0, 0.25 } } })
		Backend:SetChildren(layer, { glyph }, 1)
		Backend:Flush()
		assert.are.same({ 0.125, 0.25, 0, 0.25 }, { glyph.bg:GetTexCoord() })
		assert.is_true(glyph.bg:IsShown())
		assert.are.same({}, wow.errors)
	end)

	it("anchors a free box to a Blizzard frame, given itself or by its global name, made later or now", function()
		local wow, ns = client()
		local Backend = ns.Backend
		local layer = Backend:Layer("tooltip")
		local view = Backend:Create("box")
		local anchor = { to = { global = "SpecTooltip" }, point = "BOTTOMRIGHT", relativePoint = "BOTTOMRIGHT" }
		Backend:Set(view, { position = "fixed", width = 200, height = 50, anchor = anchor })
		Backend:SetChildren(layer, { view }, 1)
		Backend:Flush() -- not made yet: left where it is, no error
		local native = wow.env.CreateFrame("Frame", "SpecTooltip", wow.env.UIParent)
		Backend:Set(view, { position = "fixed", width = 200, height = 50, anchor = anchor, left = 1 })
		Backend:Flush()
		local point, rel, relPoint = view.frame:GetPoint(1)
		assert.are.same({ "BOTTOMRIGHT", "BOTTOMRIGHT" }, { point, relPoint })
		assert.are.equal(native, rel)
		local other = wow.env.CreateFrame("Frame", nil, wow.env.UIParent)
		Backend:Set(view, { position = "fixed", width = 200, height = 50, anchor = { to = other, point = "TOPLEFT" } })
		Backend:Flush()
		assert.are.equal(other, select(2, view.frame:GetPoint(1)))
		assert.are.same({}, wow.errors)
	end)

	it("repeats a tiled background from the art's origin, so neighbouring boxes show one surface at any size", function()
		local _, ns = client()
		local Backend = ns.Backend
		local layer = Backend:Layer("screen")
		local WOOD = { file = "wood", size = { 512, 512 }, repeatSize = 100 }
		local window = Backend:Create("box")
		Backend:Set(window, { position = "absolute", left = 50, top = 50, width = 900, height = 600, artOrigin = true })
		local tab = Backend:Create("box")
		Backend:Set(tab, { position = "absolute", left = 20, top = 0, width = 60, height = 40, background = WOOD })
		local body = Backend:Create("box")
		Backend:Set(body, { position = "absolute", left = 0, top = 40, width = 900, height = 560, background = WOOD })
		Backend:SetChildren(window, { body, tab }, 2)
		Backend:SetChildren(layer, { window }, 1)
		Backend:Flush()
		local function near(a, b)
			return math.abs(a - b) < 0.02
		end
		local l, r, t, b = unpack(tab.bg._coords)
		assert.is_true(near(l, 0.2) and near(r, 0.8) and near(t, 0) and near(b, 0.4), "the tab's part of the first tile")
		l, r, t, b = unpack(body.bg._coords)
		assert.is_true(near(l, 0) and near(r, 9) and near(t, 0.4) and near(b, 6), "the body: nine tiles across, at scale")
		assert.are.equal("REPEAT", body.bg._wrapH)
	end)

	it("draws one picture across boxes: each box under artOrigin shows its part, wherever the layout puts it", function()
		local _, ns = client()
		local Backend = ns.Backend
		local layer = Backend:Layer("screen")
		local WOOD = { atlas = "UI-Character-Info-General-BG", fit = "origin" }
		local window = Backend:Create("box")
		Backend:Set(window, { position = "absolute", left = 50, top = 50, width = 398, height = 300, artOrigin = true })
		local tab = Backend:Create("box")
		Backend:Set(tab, { position = "absolute", left = 20, top = 0, width = 100, height = 40, background = WOOD })
		local body = Backend:Create("box")
		Backend:Set(body, { position = "absolute", left = 0, top = 36, width = 398, height = 264, background = WOOD })
		Backend:SetChildren(window, { body, tab }, 2)
		Backend:SetChildren(layer, { window }, 1)
		Backend:Flush()
		-- the atlas (398 x 464 in the fake) at the window's width: 1:1 here, so a part's coordinates are its place / size
		local function near(a, b)
			return math.abs(a - b) < 0.01
		end
		local l, r, t, b = unpack(tab.bg._coords)
		assert.is_true(near(l, tab.x / 398) and near(r, (tab.x + tab.w) / 398), "tab across")
		assert.is_true(near(t, 0) and near(b, tab.h / 464), "tab down")
		l, r, t, b = unpack(body.bg._coords)
		assert.is_true(near(l, 0) and near(r, 1), "body across")
		assert.is_true(near(t, body.y / 464) and near(b, (body.y + body.h) / 464), "body down")
		-- the tab moves: its part follows
		Backend:Set(tab, { position = "absolute", left = 140, top = 0, width = 100, height = 40, background = WOOD })
		Backend:Flush()
		l = tab.bg._coords[1]
		assert.is_true(near(l, tab.x / 398) and tab.x > 100)
	end)

	it("draws a switch: its track three-sliced with round caps, its knob whole (no caps), the row by its token", function()
		local _, ns = client()
		local Backend = ns.Backend
		local layer = Backend:Layer("screen")
		local track = Backend:Create("box")
		Backend:Set(track, { position = "absolute", left = 0, top = 0, width = 32, height = 17,
			background = ref("ctl.switchOn") })
		local knob = Backend:Create("box")
		Backend:Set(knob, { position = "absolute", left = 12.5, top = -2.5, width = 22, height = 22,
			background = ref("ctl.knobOn") })
		Backend:SetChildren(track, { knob }, 1)
		Backend:SetChildren(layer, { track }, 1)
		Backend:Flush()
		local s = track.slices
		assert.is_true(s[1]:IsShown() and s[2]:IsShown() and s[3]:IsShown())
		local _, _, top, bottom = s[2]:GetTexCoord()
		assert.are.equal(0.25, top) -- row 1 of 4: on
		assert.are.equal(0.5, bottom)
		local k = knob.slices
		assert.is_false(k[1]:IsShown()) -- no caps: the knob isn't stretched
		assert.is_false(k[3]:IsShown())
		assert.is_true(k[2]:IsShown())
		assert.is_true(k[1]:GetWidth() > 0) -- a hair's width, never 0 (the file's own size)
		local left, right, kTop = k[2]:GetTexCoord()
		assert.are.same({ 0, 1, 0.5 }, { left, right, kTop }) -- the whole width of row 1 of 2
	end)

	it("lets clicks through a box that only follows the cursor, and takes them where it handles a click", function()
		local wow, ns = client()
		local Backend = ns.Backend
		local layer = Backend:Layer("screen")
		local hover = Backend:Create("box")
		local fn = function() end
		Backend:Set(hover, { position = "absolute", left = 0, top = 0, width = 50, height = 50, hoverWithin = true,
			OnEnter = fn, OnLeave = fn })
		local click = Backend:Create("box")
		Backend:Set(click, { position = "absolute", left = 0, top = 0, width = 10, height = 10, OnClick = fn })
		Backend:SetChildren(layer, { hover, click }, 2)
		Backend:Flush()
		assert.is_true(hover.frame:IsMouseEnabled()) -- it still sees the cursor
		assert.is_false(hover.frame:IsMouseClickEnabled()) -- the minimap's ring room over the map
		assert.is_true(click.frame:IsMouseClickEnabled())
		assert.are.same({}, wow.errors)
	end)

	it("draws a panel cell three-sliced, following the Blizzard button inside it, its icon following it", function()
		local wow, ns = client()
		local Backend = ns.Backend
		local layer = Backend:Layer("screen")
		local cell = Backend:Create("box")
		Backend:Set(cell, wow.env.table.freeze({ position = "absolute", left = 0, top = 0, width = 56, height = 52,
			background = ref("panel.cell"), stateFrom = "child" }))
		local icon = Backend:Create("box")
		Backend:Set(icon, { width = 37, height = 37, stateFrom = "parent", top = { default = 0, pressed = 1 } })
		local micro = wow.env.CreateFrame("Button", nil, wow.env.UIParent)
		local button = Backend:Embed(micro)
		Backend:Set(button, { position = "absolute", left = 0, top = 0, width = 56, height = 52, opacity = 0 })
		Backend:SetChildren(cell, { icon, button }, 2)
		Backend:SetChildren(layer, { cell }, 1)
		Backend:Flush()
		-- the icon's state is the cell's, the cell's the button's: neither takes the mouse from the button under them
		assert.is_false(icon.frame:IsMouseEnabled())
		assert.is_false(cell.frame:IsMouseEnabled())
		local s = cell.slices
		assert.is_false(cell.bg:IsShown()) -- the three slices draw it
		assert.are.equal(cell.pH * 0.2 > 0 and s[1]._w, s[3]._w)
		local function row(list)
			local _, _, v0 = unpack(list[2]._coords)
			return v0 * 4
		end
		assert.are.equal(0, row(s))
		assert.is_true(not cell.glows or not cell.glows[1]:IsShown())
		micro._scripts.OnEnter(micro)
		assert.is_true(cell.hovered and icon.hovered)
		assert.is_true(cell.glows[1]:IsShown())
		assert.are.equal(1, row(cell.glows))
		micro._scripts.OnMouseDown(micro)
		assert.are.equal(2, row(s))
		assert.is_true(icon.pressed)
		assert.is_false(cell.glows[1]:IsShown())
		micro._scripts.OnMouseUp(micro)
		micro._scripts.OnLeave(micro)
		assert.are.equal(0, row(s))
		assert.is_false(icon.hovered or icon.pressed)
	end)

	it("hides an art background's pieces when the box has none any more (a pooled box reused)", function()
		local wow, ns = client()
		local Backend = ns.Backend
		local layer = Backend:Layer("screen")
		local b = Backend:Create("box")
		Backend:Set(b, { position = "absolute", left = 0, top = 0, width = 64, height = 32,
			background = ref("ctl.cornerClose") })
		Backend:SetChildren(layer, { b }, 1)
		Backend:Flush()
		assert.is_true(b.slices[2]:IsShown())
		Backend:Set(b, { position = "absolute", left = 0, top = 0, width = 400, height = 30 })
		Backend:Flush()
		for i = 1, 3 do
			assert.is_false(b.slices[i]:IsShown())
		end
		assert.are.same({}, wow.errors)
	end)

	it("shows a box by its visibleWhen condition, changed only out of combat, and dropped with it", function()
		local wow, ns = client()
		local Backend = ns.Backend
		local layer = Backend:Layer("screen")
		local b = Backend:Create("box")
		Backend:Set(b, { position = "absolute", left = 0, top = 0, width = 40, height = 20,
			visibleWhen = "[combat] hide; show" })
		Backend:SetChildren(layer, { b }, 1)
		Backend:Flush()
		assert.is_true(b.frame:IsShown())
		wow.combat = true
		wow:Drive()
		assert.is_false(b.frame:IsShown()) -- the driver hides it in combat
		-- a new condition in combat waits for its end
		Backend:Set(b, { position = "absolute", left = 0, top = 0, width = 40, height = 20, visibleWhen = "hide" })
		Backend:Flush()
		assert.are.equal("[combat] hide; show", b.frame._visibility)
		wow.combat = false
		wow:Fire("PLAYER_REGEN_ENABLED")
		assert.are.equal("hide", b.frame._visibility)
		assert.is_false(b.frame:IsShown())
		-- unset: no driver, shown as any box
		Backend:Set(b, { position = "absolute", left = 0, top = 0, width = 40, height = 20 })
		Backend:Flush()
		assert.is_nil(b.frame._visibility)
		assert.is_true(b.frame:IsShown())
		assert.are.same({}, wow.errors)
	end)

	it("draws a gradient background, from at the top", function()
		local wow, ns = client()
		local Backend = ns.Backend
		local layer = Backend:Layer("screen")
		local b = Backend:Create("box")
		Backend:Set(b, { position = "absolute", left = 0, top = 0, width = 40, height = 20,
			background = { from = { 1, 0, 0, 1 }, to = { 0, 0, 1, 1 }, direction = "vertical" } })
		Backend:SetChildren(layer, { b }, 1)
		Backend:Flush()
		local g = b.bg._gradient
		assert.are.equal("VERTICAL", g[1])
		assert.are.same({ 0, 0, 1, 1 }, g[2]) -- the bottom: to
		assert.are.same({ 1, 0, 0, 1 }, g[3]) -- the top: from
		assert.are.same({}, wow.errors)
	end)

	it("tiles the XP fill along its box, each copy as high as the box", function()
		local wow, ns = client()
		local Backend = ns.Backend
		local layer = Backend:Layer("screen")
		local fill = Backend:Create("box")
		Backend:Set(fill, wow.env.table.freeze({ position = "absolute", left = 0, top = 0, width = 640, height = 20,
			background = ref("panel.xpFill.brushed") }))
		Backend:SetChildren(layer, { fill }, 1)
		Backend:Flush()
		local _, r = unpack(fill.bg._coords)
		assert.is_true(math.abs(r - fill.pW / (1024 * fill.pH / 32)) < 1e-9)
	end)

	it("draws a box's text above its child boxes (a bar's label over the bar's art)", function()
		local _, ns = client()
		local Backend = ns.Backend
		local layer = Backend:Layer("screen")
		local tube = Backend:Create("box")
		Backend:Set(tube, { position = "absolute", left = 0, top = 0, width = 200, height = 20 })
		local ring = Backend:Create("box")
		Backend:Set(ring, { position = "absolute", left = 0, top = 0, width = 200, height = 20,
			background = ref("color.border") })
		local label = Backend:Create("text")
		Backend:Set(label, { text = "85%", position = "absolute", left = 0, right = 0, top = 0, bottom = 0 })
		Backend:SetChildren(tube, { ring, label }, 2)
		Backend:SetChildren(layer, { tube }, 1)
		Backend:Flush()
		local host = label.fs:GetParent()
		assert.are.equal(tube.textFrame, host)
		assert.is_true(host:GetFrameLevel() > ring.frame:GetFrameLevel())
		assert.is_true(label.fs:IsShown())
		-- the box loses its boxes: its texts go back to its own frame
		Backend:SetChildren(tube, { label }, 1)
		assert.are.equal(tube.frame, label.fs:GetParent())
	end)

	it("reports an offset that isn't a number and lays the box out without it", function()
		local wow, ns = client()
		local Backend = ns.Backend
		local layer = Backend:Layer("screen")
		local b = Backend:Create("box")
		Backend:Set(b, { position = "absolute", left = "10%", top = 4, width = 20, height = 20 })
		Backend:SetChildren(layer, { b }, 1)
		Backend:Flush()
		assert.is_nil(b.offL)
		assert.are.equal(4, b.offT)
		local said = table.concat(wow.errors, "\n")
		assert.is_truthy(said:find('left = "10%" is not a number', 1, true), said)
	end)

	it("shows only an embedded button's icon with look = icon, and gives its art back on release", function()
		local wow, ns = client()
		local Backend = ns.Backend
		local layer = Backend:Layer("screen")
		local bag = wow.env.CreateFrame("Button", nil, wow.env.UIParent)
		local icon = bag:CreateTexture(nil, "BORDER")
		icon:SetPoint("CENTER", bag, "CENTER", 0, 0)
		bag.icon = icon
		local ring = bag:CreateTexture(nil, "OVERLAY")
		local slot = Backend:Create("box")
		Backend:Set(slot, { position = "absolute", left = 0, top = 0, width = 38, height = 38 })
		local cell = Backend:Embed(bag)
		Backend:Set(cell, { width = 38, height = 38, look = "icon" })
		Backend:SetChildren(slot, { cell }, 1)
		Backend:SetChildren(layer, { slot }, 1)
		Backend:Flush()
		assert.are.equal(0, ring:GetAlpha())
		assert.are.equal(1, icon:GetAlpha())
		assert.are.equal(cell.pW, icon:GetWidth()) -- the icon fills the box
		local l = unpack(icon._coords)
		assert.is_true(l > 0) -- the rim cropped
		-- Blizzard sets the icon again (a bag changed): still cropped
		icon:SetTexture(133634)
		icon:SetTexCoord(0, 1, 0, 1)
		assert.is_true(unpack(icon._coords) > 0)
		Backend:SetChildren(slot, {}, 0)
		Backend:Release(cell)
		assert.are.equal(1, ring:GetAlpha())
		assert.are.equal("CENTER", (icon:GetPoint(1)))
		icon:SetTexCoord(0, 1, 0, 1) -- given back: Blizzard's coordinates stay its own
		assert.are.equal(0, (unpack(icon._coords)))
	end)

	describe("bindings: SetField and SetArgument", function()
		local wow, Backend, layer
		before_each(function()
			local ns
			wow, ns = client()
			Backend = ns.Backend
			layer = Backend:Layer("screen")
		end)

		it("writes one bound key, and a later Set of the static table keeps it", function()
			local STATIC = wow.env.table.freeze({ position = "absolute", left = 0, top = 0, height = 20,
				background = ref("color.surface") })
			local b = Backend:Create("box")
			Backend:Set(b, STATIC)
			Backend:SetChildren(layer, { b }, 1)
			Backend:Flush()
			Backend:SetField(b, "width", 50)
			Backend:Flush()
			assert.are.equal(50, b.w)
			-- the render runs again with the same static table, and with a new one that lacks the bound key too
			Backend:Set(b, STATIC)
			Backend:Set(b, wow.env.table.freeze({ position = "absolute", left = 0, top = 0, height = 30 }))
			Backend:Flush()
			assert.are.equal(50, b.a.width)
			assert.are.same({ 50, 30 }, { b.a.width, b.a.height })
			assert.is_nil(b.a.background) -- a static key the new table lacks still goes
			Backend:SetField(b, "width", nil)
			Backend:Flush()
			assert.is_nil(b.a.width)
		end)

		it("does nothing for the same value or a key the node doesn't take", function()
			local b = Backend:Create("box")
			Backend:Set(b, { width = 10 })
			Backend:SetField(b, "width", 10)
			Backend:SetField(b, "wrap", false) -- a text's key on a box
			assert.is_nil(b.a.wrap)
			assert.is_nil(b.queued)
		end)

		it("draws a text's changed arguments at the next Flush, once", function()
			local t = Backend:Create("text")
			Backend:Set(t, { text = "%d / %d", arguments = { 1, 2 } })
			Backend:SetChildren(layer, { t }, 1)
			Backend:Flush()
			Backend:SetArgument(t, 1, 10)
			Backend:SetArgument(t, 2, 20)
			assert.are.equal("1 / 2", t.fs:GetText())
			Backend:Flush()
			assert.are.equal("10 / 20", t.fs:GetText())
		end)
	end)

	it("hides a taken Blizzard frame with shown = false, again after Blizzard shows it, and gives it back", function()
		local wow, ns = client()
		local Backend = ns.Backend
		local bar = wow.env.CreateFrame("Frame", nil, wow.env.UIParent)
		bar:Show()
		local node = Backend:Take(bar)
		Backend:Set(node, { shown = false })
		assert.is_false(bar:IsShown())
		bar:Show() -- Blizzard's layout shows it again
		assert.is_false(bar:IsShown())
		bar:SetShown(true)
		assert.is_false(bar:IsShown())
		Backend:Release(node)
		assert.is_true(bar:IsShown())
		bar:Hide()
		bar:Show() -- ours no longer: Blizzard's own showing stands
		assert.is_true(bar:IsShown())
	end)
end)
