-- The settings window (addons/OrdaenSettings; design settings/) on the fake client, as built, with Ordaen Panel: a bare
-- /ordaen loads it and opens the window; its list (General, the modules with their switches); General's tabs and rows
-- bound to the global settings; a module's page in its tabs; a module that's off shows only that it's off.
local Fake = require("tests.fake.wow")

local DIST = ".ordaen/check/dist"

-- Blizzard's frames Ordaen Panel takes, as FrameXML makes them before any addon loads
local BLIZZARD = {
	"CharacterMicroButton", "ProfessionMicroButton", "SpellbookMicroButton", "TalentMicroButton", "LegacyMicroButton",
	"QuestLogMicroButton", "GuildMicroButton", "LFDMicroButton", "CollectionsMicroButton", "MainMenuMicroButton",
	"QuickJoinToastButton", "MainMenuBarBackpackButton", "CharacterBag0Slot", "CharacterBag1Slot", "CharacterBag2Slot",
	"CharacterBag3Slot",
}

local function Start(db)
	local wow = Fake.New({ dist = DIST, addons = { "OrdaenCore", "OrdaenPanel", "OrdaenLibrary", "OrdaenSettings" } })
	local home = wow.env.CreateFrame("Frame", "BagsBar", wow.env.UIParent)
	for _, name in ipairs(BLIZZARD) do
		local f = wow.env.CreateFrame("Button", name, home)
		f:SetSize(45, 45)
		f:SetPoint("CENTER", home, "CENTER", 0, 0)
	end
	wow.env.OrdaenCoreDB = db
	wow:Login()
	wow:Tick()
	return wow, wow.addons.OrdaenCore.ns
end

-- every text drawn on the dialog layer (the window's), and every box there
local function walk(ns, fn)
	local function go(node)
		fn(node)
		for i = 1, node.count or 0 do
			go(node.children[i])
		end
	end
	go(ns.Game.Layer.Dialog.node)
end
local function texts(ns)
	local out = {}
	walk(ns, function(node)
		if node.kind == "text" then
			out[node.fs:GetText()] = node
		end
	end)
	return out
end
-- a click on what the node is drawn in: the nearest box up from it that takes clicks
local function press(node)
	while not (node.frame and node.a and node.a.OnClick) do
		node = node.parent
	end
	node.frame:GetScript("OnClick")(node.frame, "LeftButton")
end
local function click(node)
	local frame = node.frame
	frame:GetScript("OnClick")(frame, "LeftButton")
end

describe("the settings window", function()
	it("isn't loaded at login, and a bare /ordaen loads it and opens the window on General", function()
		local wow, ns = Start(nil)
		assert.is_false(wow.addons.OrdaenSettings.loaded)
		wow:Slash("/ordaen")
		ns.Scheduler.Flush()
		assert.is_true(wow.addons.OrdaenSettings.loaded)
		assert.are.same({}, wow.errors)
		local t = texts(ns)
		assert.is_truthy(t["General"]) -- the list's own entry
		assert.is_truthy(t["Panel"]) -- the module, its title without "Ordaen "
		assert.is_truthy(t["Scale"] and t["Numbers"] and t["Behaviour"]) -- General's tabs
		assert.is_truthy(t["Ordaen window scale"]) -- the scale's row, bound to the global
		assert.is_truthy(t["100%"])
		assert.are.same({}, wow.errors)
		-- every layer over the ones before it (the tab's rim over its wood)
		assert.are.equal(0, ns.Core._BackendStats({}).order_errors)
	end)

	it("toggles: /ordaen again closes it, /ordaen <module> goes to that page, again closes it", function()
		local wow, ns = Start(nil)
		wow:Slash("/ordaen")
		ns.Scheduler.Flush()
		assert.is_truthy(texts(ns)["Ordaen window scale"])
		wow:Slash("/ordaen")
		ns.Scheduler.Flush()
		assert.is_nil(texts(ns)["Ordaen window scale"])
		wow:Slash("/ordaen")
		ns.Scheduler.Flush()
		wow:Slash("/ordaen panel")
		ns.Scheduler.Flush()
		assert.is_nil(texts(ns)["Ordaen window scale"]) -- on Panel's page, still open
		assert.is_truthy(texts(ns)["General"])
		wow:Slash("/ordaen panel")
		ns.Scheduler.Flush()
		assert.is_nil(texts(ns)["General"])
		assert.are.same({}, wow.errors)
	end)

	it("shows a module's page when its entry is picked, and that it's off when it is", function()
		local wow, ns = Start(nil)
		wow:Slash("/ordaen")
		ns.Scheduler.Flush()
		click(texts(ns)["Panel"].parent)
		ns.Scheduler.Flush()
		local t = texts(ns)
		assert.is_falsy(t["Ordaen window scale"]) -- General's rows are gone
		assert.is_truthy(t["Micro menu"] and t["Bottom panel"]) -- the Panel's tabs, from its page description
		assert.is_falsy(t["Menu icons"]) -- a later tab's rows aren't drawn: the first tab is
		assert.are.same({}, wow.errors)
		-- turned off from its switch: off now, its page says so
		local panel
		for _, entry in ipairs(ns.Game.Modules) do
			if entry.folder == "OrdaenPanel" then
				panel = entry
			end
		end
		panel:Enable(false)
		ns.Scheduler.Flush()
		t = texts(ns)
		local off = false
		for text in pairs(t) do
			if text:find("module is off", 1, true) then
				off = true
			end
		end
		assert.is_true(off)
		assert.are.same({}, wow.errors)
	end)

	it("stages changes until Save, and rolls the last Save back", function()
		local wow, ns = Start(nil)
		wow:Slash("/ordaen")
		ns.Scheduler.Flush()
		local t = texts(ns)
		assert.is_falsy(t["On top of the game's UI scale."]) -- the hint: in a tooltip, not inline
		local label = t["Ordaen window scale"].parent
		label.frame:GetScript("OnEnter")(label.frame)
		ns.Scheduler.Flush()
		assert.is_truthy(texts(ns)["On top of the game's UI scale."])
		label.frame:GetScript("OnLeave")(label.frame)
		ns.Scheduler.Flush()
		assert.is_falsy(texts(ns)["On top of the game's UI scale."])
		t = texts(ns)
		local pixel = ns.Globals.Get("pixel")
		local was = pixel:Peek()
		-- the checkbox: the box beside the "One-pixel lines" label
		local row = t["One-pixel lines"].parent.parent
		local check = row.children[2]
		click(check)
		ns.Scheduler.Flush()
		assert.are.equal(was, pixel:Peek()) -- staged, not applied
		t = texts(ns)
		click(t["Save"].parent.parent)
		ns.Scheduler.Flush()
		assert.are.equal(not was, pixel:Peek())
		t = texts(ns)
		assert.is_truthy(t["Roll back"])
		click(t["Roll back"].parent.parent)
		ns.Scheduler.Flush()
		assert.are.equal(was, pixel:Peek())
		assert.are.same({}, wow.errors)
	end)

	it("closes on Escape, and keeps where its tab row was dragged", function()
		local wow, ns = Start(nil)
		wow:Slash("/ordaen")
		ns.Scheduler.Flush()
		-- the tab row: the box over the window's top, before the tab
		local tab = texts(ns)["Ordaen"].parent.parent
		local row = tab.parent.parent.children[1]
		local f = row.frame
		f:GetScript("OnDragStart")(f)
		f:GetScript("OnDragStop")(f)
		ns.Scheduler.Flush()
		assert.is_true(wow.env.CloseSpecialWindows()) -- Escape: the window took it, no game menu
		ns.Scheduler.Flush()
		assert.are.same({}, wow.errors)
		assert.is_falsy(texts(ns)["General"])
		assert.is_false(wow.env.CloseSpecialWindows()) -- closed: Escape is the game's again
		assert.are.same({}, wow.errors)
	end)

	it("resizes from its grip, its content laid out again, and keeps the size", function()
		local wow, ns = Start(nil)
		wow:Slash("/ordaen")
		ns.Scheduler.Flush()
		local grip
		walk(ns, function(node)
			if node.a and node.a.OnDragStart and type(node.a.width) == "number" and node.a.width < 20 then
				grip = node
			end
		end)
		local page = texts(ns)["Save"].parent.parent.parent -- the buttons' row, at the foot's right end
		local x0 = page.x
		local f = grip.frame
		wow:MoveCursor(500, 500)
		wow:DragStart(f)
		wow:MoveCursor(600, 450)
		wow:Tick()
		wow:DragStop(f)
		ns.Scheduler.Flush()
		ns.Backend:Flush()
		assert.is_true(page.x > x0) -- the foot's buttons moved right with the window's right edge
		local db = wow.env.OrdaenSettingsDB
		assert.is_truthy(db)
		assert.are.same({}, wow.errors)
	end)

	it("holds its tab and its list still on the screen while resized, step by fraction of a pixel", function()
		local wow, ns = Start(nil)
		wow:Slash("/ordaen")
		ns.Scheduler.Flush()
		local grip
		walk(ns, function(node)
			if node.a and node.a.OnDragStart and type(node.a.width) == "number" and node.a.width < 20 then
				grip = node
			end
		end)
		local tab = texts(ns)["Ordaen"].parent.parent
		local list = texts(ns)["General"].parent
		local f = grip.frame
		wow:MoveCursor(500, 500)
		wow:DragStart(f)
		local seen = {}
		for i = 1, 40 do
			wow:MoveCursor(500 + i * 0.37, 500 - i * 0.29)
			wow:Tick()
			ns.Scheduler.Flush()
			ns.Backend:Flush()
			for _, node in ipairs({ tab, list }) do
				local fr = node.frame
				local key = tostring(node)
				local at = string.format("%.4f %.4f", fr:GetLeft(), fr:GetTop())
				seen[key] = seen[key] or at
				if seen[key] ~= at then
					local win = tab.parent.parent
					error(string.format("%s step %d: %s -> %s; win frame %.4f %.4f off %.4f %.4f w %.4f h %.4f",
						node == tab and "tab" or "list", i, seen[key], at, win.frame:GetLeft(), win.frame:GetTop(),
						win.offL or -1, win.offT or -1, win.w or -1, win.h or -1))
				end
			end
		end
		wow:DragStop(f)
		assert.are.same({}, wow.errors)
	end)

	it("opens again where its tab row left it", function()
		local wow, ns = Start(nil)
		wow:Slash("/ordaen")
		ns.Scheduler.Flush()
		local tab = texts(ns)["Ordaen"].parent.parent
		local f = tab.frame
		wow:MoveCursor(500, 500)
		wow:DragStart(f)
		wow:MoveCursor(600, 450)
		wow:Tick()
		ns.Scheduler.Flush()
		wow:DragStop(f)
		ns.Scheduler.Flush()
		local moved = tab.parent.offL
		wow:Slash("/ordaen")
		ns.Scheduler.Flush()
		assert.is_nil(texts(ns)["Ordaen"])
		wow:Slash("/ordaen")
		ns.Scheduler.Flush()
		local again = texts(ns)["Ordaen"].parent.parent.parent
		assert.is_number(moved)
		assert.are.equal(moved, again.offL)
		assert.is_number(wow.env.OrdaenSettingsDB["window#main"].x) -- kept in the module's db: a /reload keeps it too
		assert.are.same({}, wow.errors)
	end)

	it("stops at the screen's edge when dragged past it", function()
		local wow, ns = Start(nil)
		wow:Slash("/ordaen")
		ns.Scheduler.Flush()
		local tab = texts(ns)["Ordaen"].parent.parent
		local win = tab.parent
		local f = tab.frame
		ns.Backend:Flush()
		local top0 = win.frame:GetTop()
		wow:MoveCursor(500, 500)
		wow:DragStart(f)
		for x = 400, -3000, -100 do -- along the screen, then past its left edge: the window stops, its height stays
			wow:MoveCursor(x, 500)
			wow:Tick()
			ns.Scheduler.Flush()
			ns.Backend:Flush()
			assert.is_true(math.abs(win.frame:GetTop() - top0) < 0.5, "top " .. tostring(win.frame:GetTop()) ..
				" was " .. tostring(top0) .. " at x " .. x)
		end
		wow:DragStop(f)
		ns.Scheduler.Flush()
		ns.Backend:Flush()
		assert.is_true(win.frame:GetLeft() >= -0.5, "left " .. tostring(win.frame:GetLeft()))
		assert.is_true(math.abs(win.frame:GetTop() - top0) < 0.5, "top after " .. tostring(win.frame:GetTop()))
		assert.are.same({}, wow.errors)
	end)

	it("moves with its tab row while dragged", function()
		local wow, ns = Start(nil)
		wow:Slash("/ordaen")
		ns.Scheduler.Flush()
		local tab = texts(ns)["Ordaen"].parent.parent
		local win = tab.parent.parent
		local before = win.offL or 0
		local f = tab.frame
		wow:MoveCursor(500, 500)
		wow:DragStart(f)
		wow:MoveCursor(600, 500)
		wow:Tick()
		ns.Scheduler.Flush()
		wow:DragStop(f)
		ns.Scheduler.Flush()
		assert.is_true((win.offL or 0) > before, "moved " .. tostring(win.offL))
		assert.are.same({}, wow.errors)
	end)

	it("leaves the mouse to the boxes with a handler: the tab's art doesn't cover its drag", function()
		local wow, ns = Start(nil)
		wow:Slash("/ordaen")
		ns.Scheduler.Flush()
		local taking = 0
		walk(ns, function(node)
			if node.kind == "box" and not node.embedded and node.frame:IsMouseEnabled() then
				local a = node.a
				assert.is_truthy(a.OnClick or a.OnEnter or a.OnLeave or a.OnDragStart or a.hoverWithin or node.states,
					"a box without a handler takes the mouse")
				taking = taking + 1
			end
		end)
		assert.is_true(taking > 0)
	end)

	it("draws its corner buttons at the body's top right after a drag", function()
		local wow, ns = Start(nil)
		wow:Slash("/ordaen")
		ns.Scheduler.Flush()
		local tab = texts(ns)["Ordaen"].parent.parent
		local f = tab.frame
		wow:MoveCursor(500, 500)
		wow:DragStart(f)
		wow:MoveCursor(560, 470)
		wow:Tick()
		ns.Scheduler.Flush()
		-- the cursor onto the body while still dragging, then the drag ends
		local body = tab.parent.parent.children[3]
		body.frame:GetScript("OnEnter")(body.frame)
		ns.Scheduler.Flush()
		wow:DragStop(f)
		ns.Scheduler.Flush()
		ns.Backend:Flush()
		local group
		for i = 1, body.count do
			local c = body.children[i]
			if c.a.overflow == "clip" then
				group = c
			end
		end
		assert.is_truthy(group, "no corner group")
		local out = {}
		local function dump(n, d)
			out[#out + 1] = string.rep(" ", d) .. string.format("%s x=%s y=%s w=%s h=%s pW=%s pH=%s", n.kind,
				tostring(n.x), tostring(n.y), tostring(n.w), tostring(n.h), tostring(n.pW), tostring(n.pH))
			for i = 1, n.count or 0 do
				dump(n.children[i], d + 1)
			end
		end
		dump(group, 0)
		assert.is_true(group.w < 60, table.concat(out, " | "))
		assert.is_true(group.x > body.w / 2, table.concat(out, " | "))
	end)

	it("keeps the tab's layers in order while the corner buttons show", function()
		local wow, ns = Start(nil)
		wow:Slash("/ordaen")
		ns.Scheduler.Flush()
		local tab = texts(ns)["Ordaen"].parent.parent
		local body = tab.parent.parent.children[3]
		body.frame:GetScript("OnEnter")(body.frame)
		ns.Scheduler.Flush()
		assert.are.equal(0, ns.Core._BackendStats({}).order_errors) -- the tab's wood, flare and rim, as before
	end)

	it("draws its corner buttons in place after open, move, close and open again", function()
		local wow, ns = Start(nil)
		wow:Slash("/ordaen")
		ns.Scheduler.Flush()
		local f = texts(ns)["Ordaen"].parent.parent.frame
		wow:MoveCursor(500, 500)
		wow:DragStart(f)
		wow:MoveCursor(560, 470)
		wow:Tick()
		ns.Scheduler.Flush()
		wow:DragStop(f)
		ns.Scheduler.Flush()
		wow.env.CloseSpecialWindows()
		ns.Scheduler.Flush()
		wow:Slash("/ordaen")
		ns.Scheduler.Flush()
		local tab = texts(ns)["Ordaen"].parent.parent
		-- every part of the tab within the tab and its art's 10 px past it
		for i = 1, tab.count do
			local c = tab.children[i]
			if c.kind == "box" then
				local w = c.frame:GetWidth()
				assert.is_true(w <= tab.frame:GetWidth() + 12, string.format("part %d is %.1f wide, the tab %.1f", i, w,
					tab.frame:GetWidth()))
			end
		end
		local body = tab.parent.parent.children[3]
		body.frame:GetScript("OnEnter")(body.frame)
		ns.Scheduler.Flush()
		ns.Backend:Flush()
		local group
		for i = 1, body.count do
			local c = body.children[i]
			if c.a.overflow == "clip" then
				group = c
			end
		end
		assert.is_truthy(group, "no corner group")
		local fr = group.frame
		local info = string.format("w=%s x=%s frame=%sx%s pt=%s", tostring(group.w), tostring(group.x),
			tostring(fr:GetWidth()), tostring(fr:GetHeight()), tostring(fr:GetNumPoints()))
		assert.is_true(math.abs(fr:GetWidth() - group.w) < 1, info)
		assert.is_true(group.x > body.w / 2, info)
		assert.are.equal(1, fr:GetNumPoints(), info)
	end)

	it("«Themes»: a tab per theme, the active one marked; Use goes through the draft, Copy makes an own theme", function()
		local wow, ns = Start(nil)
		wow:Slash("/ordaen")
		ns.Scheduler.Flush()
		press(texts(ns)["Themes"])
		ns.Scheduler.Flush()
		local t = texts(ns)
		assert.is_truthy(t["● Ordaen"] and t["Blizzard"] and t["Minimal"])
		assert.is_truthy(t["In use"] and t["Fonts"] and t["Class colours"] and t["Text font"])
		assert.are.same({}, wow.errors)
		press(t["Blizzard"])
		ns.Scheduler.Flush()
		press(texts(ns)["Use"])
		ns.Scheduler.Flush()
		assert.are.equal("ordaen", ns.Globals.Get("theme"):Get()) -- waits for «Save»
		assert.is_truthy(texts(ns)["● Blizzard"])
		press(texts(ns)["Save"])
		ns.Scheduler.Flush()
		assert.are.equal("blizzard", ns.Globals.Get("theme"):Get())
		press(texts(ns)["Copy"])
		ns.Scheduler.Flush()
		assert.are.equal(4, #ns.Themes:List())
		assert.is_truthy(texts(ns)["Delete"])
		assert.are.same({}, wow.errors)
	end)
end)
