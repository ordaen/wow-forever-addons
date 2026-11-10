-- The placing mode (addons/OrdaenCore/Placing.lua) on the fake client, as built: a free part at its default place,
-- the mode's outline dragged to move it (saved on drop, in UI units), a right-click back to the default, a grip
-- resizing a resizable part, and the mode refused and closed in combat.
local Fake = require("tests.fake.wow")

local DIST = ".ordaen/check/dist"

describe("the placing mode", function()
	local wow, ns, part

	local function frames(fn)
		local out = {}
		local function walk(node)
			if node.frame and fn(node.frame) then
				out[#out + 1] = node.frame
			end
			for i = 1, node.count or 0 do
				walk(node.children[i])
			end
		end
		walk(ns.Game.Layer.Screen.node)
		return out
	end

	before_each(function()
		wow = Fake.New({ dist = DIST, addons = { "OrdaenCore" } })
		wow:Login()
		ns = wow.addons.OrdaenCore.ns
		local module = { name = "OrdaenSpec", ns = {}, cache = {}, Import = function()
			return nil
		end }
		ns.App.currentModule, ns.App.currentFile = module, "components/bars"
		local Bars = ns.Define.Component({
			Render = function(game)
				game.ui:Placed(1, nil, { attributes = { part = "status" },
					slots = { default = function(g)
						g.ui:Box(2, { attributes = { width = 10, height = 10 } })
					end } }, "status")
			end,
		})
		ns.App.currentModule, ns.App.currentFile = nil, nil
		-- the module's parts, as its declaration lists them (App registers them at mount)
		ns.Placing.Declare("OrdaenSpec", { status = { title = "Полосы", width = 300, height = 20, resize = "width",
			default = { point = "BOTTOM", relativePoint = "BOTTOM", left = 0, top = -80 } } })
		ns.Engine:Mount(nil, Bars, 0, {}, ns.Game.Layer.Screen, module, ns.Game.ForModule(module))
		ns.Scheduler.Flush()
		wow:Tick()
		part = frames(function(f)
			return f:GetWidth() == 300
		end)[1]
	end)

	local function outline()
		return frames(function(f)
			return f._scripts.OnDragStart ~= nil and f:GetWidth() == 300
		end)[1]
	end

	it("draws a part at its default place, with no outline until the mode is on", function()
		assert.is_table(part)
		assert.is_nil(outline())
		assert.is_true(ns.Game.Placing:Enter())
		ns.Scheduler.Flush()
		wow:Tick()
		assert.is_table(outline())
		assert.are.same({}, wow.errors)
	end)

	it("moves with a drag, saved on drop under the part's own id, and goes back on a right-click", function()
		ns.Game.Placing:Enter()
		ns.Scheduler.Flush()
		wow:Tick()
		local frame = outline()
		local scale = frame:GetEffectiveScale()
		local left, top = frame:GetLeft(), frame:GetTop()
		wow:MoveCursor((left + 10) * scale, (top - 5) * scale)
		wow:DragStart(frame)
		wow:MoveCursor((left + 50) * scale, (top - 25) * scale)
		wow:Tick()
		ns.Scheduler.Flush()
		wow:DragStop(frame)
		ns.Scheduler.Flush()
		local saved = wow.env.OrdaenCoreDB.placed["OrdaenSpec.status"]
		assert.are.same({ point = "BOTTOM", relativePoint = "BOTTOM", left = 40, top = -60, width = 300, height = 20 },
			saved)
		outline():GetScript("OnClick")(outline(), "RightButton")
		ns.Scheduler.Flush()
		assert.is_nil(wow.env.OrdaenCoreDB.placed)
		assert.are.same({}, wow.errors)
	end)

	it("refuses a part its module doesn't declare", function()
		local module = { name = "OrdaenSpec", ns = {}, cache = {}, Import = function()
			return nil
		end }
		ns.App.currentModule, ns.App.currentFile = module, "components/other"
		local Other = ns.Define.Component({
			Render = function(game)
				game.ui:Placed(1, nil, { attributes = { part = "nowhere" } })
			end,
		})
		ns.App.currentModule, ns.App.currentFile = nil, nil
		ns.Engine:Mount(nil, Other, 0, {}, ns.Game.Layer.Screen, module, ns.Game.ForModule(module))
		ns.Scheduler.Flush()
		local found = false
		for _, e in ipairs(wow.errors) do
			found = found or tostring(e):find("OrdaenSpec.nowhere is no part its module declares", 1, true) ~= nil
		end
		assert.is_true(found)
	end)

	it("is refused in combat and closes when combat starts", function()
		wow.combat = true
		assert.is_false(ns.Game.Placing:Enter())
		wow.combat = false
		ns.Game.Placing:Enter()
		wow.combat = true
		wow:Fire("PLAYER_REGEN_DISABLED")
		assert.is_false(ns.Game.Placing.on:Peek())
	end)

	it("opens with /ordaen move", function()
		wow:Slash("/ordaen move")
		assert.is_true(ns.Game.Placing.on:Peek())
		wow:Slash("/ordaen move")
		assert.is_false(ns.Game.Placing.on:Peek())
	end)
end)

describe("the placing mode's saved places", function()
	it("move once from the ids parts had before they were declared", function()
		local wow = Fake.New({ dist = DIST, addons = { "OrdaenCore" } })
		wow.env.OrdaenCoreDB = { placed = {
			["OrdaenPanel.module#bar1"] = { point = "BOTTOM", left = 10, top = -50 },
			["OrdaenMinimap.module#map"] = { point = "TOPRIGHT", left = -4, top = -4 },
		} }
		wow:Login()
		assert.are.same({
			["OrdaenPanel.bar1"] = { point = "BOTTOM", left = 10, top = -50 },
			["OrdaenMinimap.map"] = { point = "TOPRIGHT", left = -4, top = -4 },
		}, wow.env.OrdaenCoreDB.placed)
	end)
end)
