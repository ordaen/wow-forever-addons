-- The library's settings controls (addons/OrdaenLibrary/components; design: controls/switch, controls/slider) on the
-- fake client, as built: each bound to a component's stored setting through `value`, drawn from it, and writing it
-- back from the player's clicks and drags; `disabled` greys them and takes no input.
local Fake = require("tests.fake.wow")

local DIST = ".ordaen/check/dist"

describe("the settings controls", function()
	local wow, ns, instance, disabled

	local function mount(render)
		local module = { name = "OrdaenSpec", ns = {}, cache = {}, db = {}, charDb = {}, Import = function(_, path)
			error("OrdaenSpec has no file " .. path, 2)
		end }
		instance = ns.Engine:Mount(nil, ns.Define.Component({
			Setup = function()
				ns.Define.Persistent({
					on = { type = "boolean", default = false, setting = true },
					height = { type = "number", default = 60, min = 24, max = 96, step = 1, unit = "px", setting = true },
					scale = { type = "number", default = 1, min = 0.7, max = 1.5, step = 0.05, unit = "percent",
						setting = true },
					-- the build writes `order` from the enum literal; a spec's component isn't built, so it's given
					density = { type = "choice", choices = { Compact = "compact", Normal = "normal", Roomy = "roomy" },
						order = { "compact", "normal", "roomy" }, default = "normal", setting = true },
				})
				disabled = ns.NewValue(false)
			end,
			Render = render,
		}), 0, {}, ns.Game.Layer.Screen, module, ns.Game.ForModule(module))
		ns.Scheduler.Flush()
	end

	before_each(function()
		wow = Fake.New({ dist = DIST, addons = { "OrdaenCore", "OrdaenLibrary" } })
		wow:Login()
		ns = wow.addons.OrdaenCore.ns
	end)

	-- every drawn box and text under the screen layer, in drawing order
	local function nodes()
		local out = {}
		local function walk(node)
			out[#out + 1] = node
			for i = 1, node.count or 0 do
				walk(node.children[i])
			end
		end
		walk(ns.Game.Layer.Screen.node)
		return out
	end
	local function withBackground(path)
		for _, node in ipairs(nodes()) do
			local bg = node.a and node.a.background
			if type(bg) == "table" and rawget(bg, "path") == path then
				return node
			end
		end
	end
	local function texts()
		local out = {}
		for _, node in ipairs(nodes()) do
			if node.kind == "text" then
				out[#out + 1] = node.fs:GetText()
			end
		end
		return out
	end
	local function has(text)
		for _, t in ipairs(texts()) do
			if t == text then
				return true
			end
		end
		return false
	end
	-- the row a control sits in (SettingRow) faded to 45% while disabled
	local function faded()
		for _, node in ipairs(nodes()) do
			if node.frame and node.frame:GetAlpha() == 0.45 then
				return true
			end
		end
		return false
	end
	local function click(node, x)
		local frame = node.frame
		local scale = frame:GetEffectiveScale()
		wow:MoveCursor((frame:GetLeft() + (x or 1)) * scale, (frame:GetTop() - 1) * scale)
		frame:GetScript("OnClick")(frame, "LeftButton")
		ns.Scheduler.Flush()
	end

	describe("Switch", function()
		local function draw()
			mount(function(game, self)
				game.ui:Switch(1, { attributes = { value = self.state.persistent.on, disabled = disabled:Get() } })
			end)
		end

		it("draws off, flips on a click and draws on: the knob moves right and glows", function()
			draw()
			local track = withBackground("ctl.switchOff")
			assert.is_truthy(track)
			assert.is_truthy(withBackground("ctl.knobOff"))
			click(track)
			assert.is_true(instance.state.persistent.on:Peek())
			assert.is_truthy(withBackground("ctl.switchOn"))
			local knob = withBackground("ctl.knobOn")
			assert.is_truthy(knob)
			assert.is_true(knob.x > 0)
			click(withBackground("ctl.switchOn"))
			assert.is_false(instance.state.persistent.on:Peek())
			assert.are.same({}, wow.errors)
		end)

		it("follows the setting written elsewhere, and while disabled draws faded and takes no click", function()
			draw()
			instance.state.persistent.on:Set(true)
			ns.Scheduler.Flush()
			assert.is_truthy(withBackground("ctl.switchOn"))
			disabled:Set(true)
			ns.Scheduler.Flush()
			local track = withBackground("ctl.switchOn")
			assert.is_true(faded())
			assert.is_nil(track.frame:GetScript("OnClick") and track.a.OnClick)
			assert.are.same({}, wow.errors)
		end)
	end)

	describe("Checkbox", function()
		it("draws the well, the tick while on, toggles on a click, and takes no click while disabled", function()
			mount(function(game, self)
				game.ui:Checkbox(1, { attributes = { value = self.state.persistent.on, disabled = disabled:Get() } })
			end)
			local well = withBackground("ctl.check")
			assert.is_truthy(well)
			assert.is_nil(withBackground("ctl.tick"))
			click(well)
			assert.is_true(instance.state.persistent.on:Peek())
			assert.is_truthy(withBackground("ctl.tick"))
			disabled:Set(true)
			ns.Scheduler.Flush()
			well = withBackground("ctl.check")
			assert.is_true(faded())
			assert.is_nil(well.a.OnClick)
			assert.are.same({}, wow.errors)
		end)
	end)

	describe("Dropdown", function()
		it("shows the picked choice, opens its menu in order, picks one, and closes on a click outside", function()
			mount(function(game, self)
				game.ui:Dropdown(1, { attributes = { value = self.state.persistent.density, disabled = disabled:Get() } })
			end)
			local face = withBackground("ctl.button")
			assert.is_truthy(face)
			local setting = instance.state.persistent.density
			assert.is_true(has(setting:ChoiceLabel("normal")))
			assert.is_true(has(setting:Label())) -- its row's label
			click(face)
			local marks = {}
			for _, node in ipairs(nodes()) do
				local bg = node.a and node.a.background
				local path = type(bg) == "table" and rawget(bg, "path")
				if path == "ctl.radio" or path == "ctl.radioOn" then
					marks[#marks + 1] = path
				end
			end
			assert.are.same({ "ctl.radio", "ctl.radioOn", "ctl.radio" }, marks) -- in order, the picked one gold
			local menu = withBackground("ctl.radioOn").parent.parent
			assert.is_true(menu.frame:GetFrameLevel() > face.frame:GetFrameLevel()) -- over the rows below
			local items = menu.children
			items[3].frame:GetScript("OnClick")(items[3].frame, "LeftButton") -- Просторно
			ns.Scheduler.Flush()
			assert.are.equal("roomy", setting:Peek())
			assert.is_nil(withBackground("ctl.radio")) -- closed
			click(withBackground("ctl.button"))
			assert.is_truthy(withBackground("ctl.radioOn"))
			-- a click outside: the screen-wide box under the menu closes it
			for _, node in ipairs(nodes()) do
				if node.a and node.a.position == "fixed" and node.a.OnClick then
					node.frame:GetScript("OnClick")(node.frame, "LeftButton")
				end
			end
			ns.Scheduler.Flush()
			assert.is_nil(withBackground("ctl.radioOn"))
			assert.are.equal("roomy", setting:Peek())
			disabled:Set(true)
			ns.Scheduler.Flush()
			click(withBackground("ctl.button"))
			assert.is_nil(withBackground("ctl.radioOn")) -- disabled: doesn't open
			assert.is_true(faded())
			assert.are.same({}, wow.errors)
		end)
	end)

	describe("SettingsTab and Section", function()
		local function draw(shown)
			mount(function(game)
				game.ui:SettingsTab(1, { attributes = { title = "Tab", shown = shown }, slots = { default = function(g)
					g.ui:Section(2, { attributes = { title = "Heading" }, slots = { default = function(g2)
						g2.ui:Text(3, { attributes = { text = "a row" } })
					end } })
				end } })
			end)
		end

		it("draws a tab's sections: the heading with its rule, the rows below", function()
			draw(nil)
			assert.is_true(has("Heading"))
			assert.is_true(has("a row"))
			assert.is_truthy(withBackground("ctl.rule"))
			assert.are.same({}, wow.errors)
		end)

		it("draws nothing of a tab that isn't shown", function()
			draw(false)
			assert.is_false(has("a row"))
		end)
	end)

	describe("Tabs", function()
		it("draws the names, the picked one with its light, and picks another on a click", function()
			local picked = {}
			local selected = ns.NewValue(1)
			mount(function(game)
				game.ui:Tabs(1, { attributes = { tabs = { "One", "Two", "Three" }, selected = selected:Get(),
					OnSelect = function(i)
						picked[#picked + 1] = i
						selected:Set(i)
					end } })
			end)
			assert.is_true(has("One") and has("Two") and has("Three"))
			local tabs = {}
			for _, node in ipairs(nodes()) do
				if node.kind == "text" and (node.fs:GetText() == "Three") then
					tabs.three = node.parent
				end
			end
			tabs.three.frame:GetScript("OnClick")(tabs.three.frame, "LeftButton")
			ns.Scheduler.Flush()
			assert.are.same({ 3 }, picked)
			assert.is_nil(tabs.three.a.OnClick) -- picked: no click of its own
			assert.are.same({}, wow.errors)
		end)
	end)

	describe("Window", function()
		local function draw()
			mount(function(game)
				game.ui:Window(1, { attributes = { title = "Ordaen", width = 400, height = 300 }, slots = {
					default = function(g)
						g.ui:Text(2, { attributes = { text = "inside" } })
					end,
				} })
			end)
		end

		it("draws its body in the metal with the wood, its tab with the title, and the content in the body", function()
			draw()
			local body = withBackground("window.wood")
			assert.is_truthy(body)
			local window = body.parent
			assert.is_true(window.a.artOrigin)
			assert.are.equal("CENTER", (window.frame:GetPoint(1)))
			local metal = nil
			for _, node in ipairs(nodes()) do
				if node.frameArt and node.frameArt.top and node.frameArt.top:IsShown() then
					metal = node
				end
			end
			assert.is_truthy(metal) -- the body's frame art
			assert.is_truthy(withBackground("ctl.tab"))
			local t = texts()
			assert.is_truthy(table.concat(t, "|"):find("Ordaen", 1, true))
			assert.is_truthy(table.concat(t, "|"):find("inside", 1, true))
			assert.are.same({}, wow.errors)
		end)

		it("shows its corner buttons while the cursor is over it: full screen and back, close", function()
			local closed = 0
			mount(function(game)
				game.ui:Window(1, { attributes = { title = "Ordaen", width = 400, height = 300, OnClose = function()
					closed = closed + 1
				end } })
			end)
			assert.is_nil(withBackground("ctl.cornerClose")) -- hidden until hovered
			local body = withBackground("window.wood")
			body.frame:GetScript("OnEnter")(body.frame)
			ns.Scheduler.Flush()
			local full = withBackground("ctl.cornerExpand")
			assert.is_truthy(full)
			full.frame:GetScript("OnClick")(full.frame, "LeftButton")
			ns.Scheduler.Flush()
			local window = body.parent
			assert.are.equal("TOPLEFT", (window.frame:GetPoint(1))) -- no anchor: it fills the layer
			assert.are.equal(window.parent.w, window.w)
			assert.is_truthy(withBackground("ctl.cornerContract"))
			withBackground("ctl.cornerContract").frame:GetScript("OnClick")(full.frame, "LeftButton")
			ns.Scheduler.Flush()
			assert.are.equal("CENTER", (window.frame:GetPoint(1)))
			local close = withBackground("ctl.cornerClose")
			close.frame:GetScript("OnClick")(close.frame, "LeftButton")
			assert.are.equal(1, closed)
			assert.are.same({}, wow.errors)
		end)

		it("moves with its tab when dragged", function()
			draw()
			local art = withBackground("ctl.tab")
			local tab = art.parent
			local frame = tab.frame
			local window = tab.parent
			local scale = frame:GetEffectiveScale()
			local left, top = frame:GetLeft(), frame:GetTop()
			wow:MoveCursor((left + 10) * scale, (top - 10) * scale)
			wow:DragStart(frame)
			wow:MoveCursor((left + 60) * scale, (top - 30) * scale)
			wow:Tick()
			ns.Scheduler.Flush()
			wow:DragStop(frame)
			ns.Scheduler.Flush()
			local _, _, _, x, y = window.frame:GetPoint(1)
			assert.is_true(math.abs(x - 50) < 1 and math.abs(y + 20) < 1) -- 50 right, 20 down
			assert.are.same({}, wow.errors)
		end)
	end)

	describe("Slider", function()
		local function draw(key)
			mount(function(game, self)
				game.ui:Slider(1, { attributes = { value = self.state.persistent[key], disabled = disabled:Get() } })
			end)
		end
		local function band()
			return withBackground("ctl.groove").parent
		end

		it("shows the value in its unit, the fill and knob at its place, and sets it from a click in its steps", function()
			draw("height")
			assert.is_true(has("60 px"))
			local groove = withBackground("ctl.groove")
			local fill, knob = withBackground("ctl.sliderFill"), withBackground("ctl.sliderKnob")
			local length = groove.w
			local t = (60 - 24) / (96 - 24)
			assert.is_true(math.abs(fill.w - t * (length - 2 / 1.2)) < 1)
			assert.is_true(math.abs(knob.x + knob.w / 2 - t * length) < 1)
			click(band(), length) -- the far end
			assert.are.equal(96, instance.state.persistent.height:Peek())
			assert.is_true(has("96 px"))
			click(band(), length * 0.251) -- a quarter: 24 + 18 = 42
			assert.are.equal(42, instance.state.persistent.height:Peek())
			assert.are.same({}, wow.errors)
		end)

		it("drags: the value follows the cursor, held to the range; percent shows as a whole number", function()
			draw("scale")
			assert.is_true(has("100%"))
			local b = band()
			local frame = b.frame
			local scale = frame:GetEffectiveScale()
			local left, top = frame:GetLeft(), frame:GetTop()
			wow:MoveCursor((left + 10) * scale, (top - 5) * scale)
			wow:DragStart(frame)
			wow:MoveCursor((left + 10000) * scale, (top - 5) * scale) -- far past the end
			wow:Tick()
			ns.Scheduler.Flush()
			assert.are.equal(1.5, instance.state.persistent.scale:Peek())
			wow:DragStop(frame)
			ns.Scheduler.Flush()
			assert.is_true(has("150%"))
			assert.are.same({}, wow.errors)
		end)

		it("takes no input while disabled", function()
			draw("height")
			disabled:Set(true)
			ns.Scheduler.Flush()
			click(band(), 0)
			assert.are.equal(60, instance.state.persistent.height:Peek())
			assert.is_true(faded())
		end)
	end)
end)
