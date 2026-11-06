-- OrdaenCore.UI: the always-loaded entry point (addons/OrdaenCore/UI.lua) and the load-on-demand framework
-- (OrdaenCore_UI: layout, theme, renderer, components, tooltips), driven with fake frames whose font strings
-- measure like the layout spec's.
local helpers = require("tests.OrdaenCore.helpers")

local CHAR, LINE = 6, 12

-- WoW renders fonts at whole-pixel sizes for the frame's effective scale, so the same text is a little wider
-- in UI units on a scaled frame than on an unscaled one. The fakes model that: 6 px per char at effective
-- scale 1, 6.6 px at any other scale. Text measured on one frame and drawn on another then disagrees.
local function charWidth(scale)
	return scale == 1 and CHAR or CHAR * 1.1
end

local uiScale = 1 -- UIParent's effective scale in the current test

-- A fake font string: knows its text, font, width, color, points; measures per char and 12 px per line,
-- wrapping at its width like WoW does.
local function fakeFontString(log, frame)
	local fs = { shown = true, width = 0, text = "", frame = frame }
	local function natural(self)
		return #self.text * charWidth(self.frame:GetEffectiveScale())
	end
	--- Lines this text takes at its current width (what the player sees).
	function fs:Lines()
		if self.width and self.width > 0 then
			return math.max(1, math.ceil(natural(self) / self.width))
		end
		return 1
	end
	function fs:SetFontObject(font)
		self.font = font
	end
	function fs:SetWidth(w)
		self.width = w
	end
	function fs:SetText(text)
		self.text = text
		log.setText = log.setText + 1
	end
	function fs:SetFormattedText(format, ...)
		self.text = format:format(...)
		log.setFormatted = log.setFormatted + 1
	end
	function fs:GetText()
		return self.text
	end
	function fs:GetUnboundedStringWidth()
		return natural(self)
	end
	function fs:GetStringHeight()
		return self:Lines() * LINE
	end
	function fs:GetParent()
		return self.frame
	end
	function fs:SetTextColor(r, g, b)
		self.color = { r, g, b }
	end
	function fs:SetJustifyH(j)
		self.justify = j
	end
	function fs:SetPoint(...)
		self.point = { ... }
	end
	function fs:Show()
		self.shown = true
	end
	function fs:Hide()
		self.shown = false
	end
	return setmetatable(fs, { __index = function()
		return function() end
	end })
end

local function fakeTexture(layer)
	local t = { layer = layer, shown = true }
	function t:SetTexture(file)
		self.file, self.atlas = file, nil
	end
	function t:SetAtlas(name)
		self.atlas, self.file = name, nil
	end
	function t:SetTexCoord(...)
		self.texCoord = { ... }
	end
	function t:SetSize(w, h)
		self.size = { w, h }
	end
	function t:Show()
		self.shown = true
	end
	function t:Hide()
		self.shown = false
	end
	return setmetatable(t, { __index = function()
		return function() end
	end })
end

local function fakeFrame(name, log, parent)
	local f = {
		name = name, shown = true, fonts = {}, textures = {}, scripts = {}, parent = parent or false,
		events = {}, mouse = nil, clicks = nil, drag = nil,
	}
	--- Frames without a parent have scale 1; UIParent's scale is the UI scale; others inherit their parent's.
	function f:GetEffectiveScale()
		if not self.parent then
			return 1
		elseif self.parent == _G.UIParent then
			return uiScale
		end
		return self.parent:GetEffectiveScale()
	end
	function f:CreateFontString()
		local fs = fakeFontString(log, self)
		self.fonts[#self.fonts + 1] = fs
		return fs
	end
	function f:CreateTexture(_, layer)
		local t = fakeTexture(layer)
		self.textures[#self.textures + 1] = t
		return t
	end
	function f:SetSize(w, h)
		self.size = { w, h }
	end
	function f:SetPoint(...)
		self.point = { ... }
	end
	function f:Show()
		self.shown = true
	end
	function f:Hide()
		self.shown = false
	end
	function f:IsShown()
		return self.shown
	end
	function f:SetBackdrop(b)
		self.backdrop = b
	end
	function f:EnableMouse(on)
		self.mouse = on
	end
	function f:RegisterForClicks(...)
		self.clicks = { ... }
	end
	function f:RegisterForDrag(...)
		self.drag = { ... }
	end
	function f:SetScript(script, fn)
		self.scripts[script] = fn
	end
	function f:RegisterEvent(event)
		self.events[event] = true
	end
	function f:UnregisterEvent(event)
		self.events[event] = nil
	end
	return setmetatable(f, { __index = function()
		return function() end
	end })
end

describe("OrdaenCore.UI", function()
	local UI, chat, frames, log, loads, loadResult

	local function shownTexts(frame)
		local out = {}
		for _, fs in ipairs(frame.fonts) do
			if fs.shown then
				out[#out + 1] = fs.text
			end
		end
		return out
	end

	local function frameNamed(name)
		for _, f in ipairs(frames) do
			if f.name == name then
				return f
			end
		end
	end

	local function surface()
		return frameNamed("OrdaenUITooltip")
	end

	before_each(function()
		chat, frames, loads, loadResult, uiScale = {}, {}, 0, true, 1
		log = { setText = 0, setFormatted = 0 }
		helpers.stubGlobals({
			DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg)
				table.insert(chat, msg)
			end },
			CreateFrame = function(_, name, parent)
				local f = fakeFrame(name, log, parent)
				table.insert(frames, f)
				return f
			end,
		})
		for _, font in ipairs({ "GameTooltipHeaderText", "GameTooltipText", "GameTooltipTextSmall", "GameFontNormal",
			"GameFontHighlightSmall" }) do
			rawset(_G, font, { fontName = font })
		end
		local core = helpers.loadCore()
		rawget(_G, "C_AddOns").LoadAddOn = function(name)
			loads = loads + 1
			if not loadResult then
				return false, "DISABLED"
			end
			assert.equals("OrdaenCore_UI", name)
			helpers.loadAddon("OrdaenCore/OrdaenCore_UI")
			return true
		end
		UI = core.UI
	end)

	local owner = { name = "owner" }

	describe("tooltips", function()
		it("are the caller's own table, with methods; making one loads nothing", function()
			local block = { { text = "Hello" } }
			local tip = UI.Tooltip(block)
			assert.equals(block, tip)
			assert.equals("tooltip", tip.style)
			tip:Hide()
			tip:Refresh()
			assert.is_false(tip:IsShown())
			assert.equals(0, loads)
			tip:Show(owner)
			UI.Tooltip({ { text = "Again" } }):Show(owner)
			assert.equals(1, loads)
		end)

		it("draw with the theme's fonts and colors, shrink to fit, and sit where opts say", function()
			local tip = UI.Tooltip({
				{ text = "Elwynn Forest", style = "title" },
				{ text = "Click: world map", style = "hint" },
			}, { side = "below" })
			tip:Show(owner)
			local s = surface()
			assert.is_true(s.shown)
			assert.is_true(tip:IsShown())
			assert.same({ "Elwynn Forest", "Click: world map" }, shownTexts(s))
			local visible = {}
			for _, fs in ipairs(s.fonts) do
				if fs.shown then
					visible[#visible + 1] = fs -- the surface also holds its hidden measuring font string
				end
			end
			assert.equals("GameTooltipHeaderText", visible[1].font.fontName)
			assert.same({ 0.5, 0.5, 0.5 }, visible[2].color)
			-- widest line (16 chars, +1 px rounding margin) + 2 x padding 10; two lines + gap 2 + padding.
			assert.same({ 16 * CHAR + 1 + 20, LINE + 2 + LINE + 20 }, s.size)
			assert.same({ "TOP", owner, "BOTTOM", 0, -4 }, s.point)
			assert.equals("Interface\\Tooltips\\UI-Tooltip-Border", s.backdrop.edgeFile)
		end)

		it("redraw after their fields changed, hiding what is no longer drawn", function()
			local invites = { text = "You have invitations", hidden = true }
			local tip = UI.Tooltip({ invites, { text = "Click: calendar", style = "hint" } })
			tip:Show(owner)
			local s = surface()
			assert.same({ "Click: calendar" }, shownTexts(s))
			invites.hidden = false
			tip:Refresh()
			assert.same({ "You have invitations", "Click: calendar" }, shownTexts(s))
		end)

		it("go to Edit Mode's HUD Tooltip position when anchored to nothing", function()
			local container = { name = "GameTooltipDefaultContainer" }
			rawset(_G, "GameTooltipDefaultContainer", container)
			UI.Tooltip({ { text = "Somewhere" } }, { side = "default" }):Show(owner)
			assert.same({ "BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 0 }, surface().point)
			rawset(_G, "GameTooltipDefaultContainer", nil)
		end)

		it("hide only themselves, and with an owner only for that owner", function()
			local mine = UI.Tooltip({ { text = "Mine" } })
			local other = UI.Tooltip({ { text = "Other" } })
			mine:Show(owner)
			other:Hide()
			assert.is_true(surface().shown)
			mine:Hide({ name = "someone else" })
			assert.is_true(surface().shown)
			mine:Hide(owner)
			assert.is_false(surface().shown)
		end)

		it("wrap long text at the theme's maximum width instead of growing", function()
			UI.Tooltip({ { text = string.rep("word ", 20) } }):Show(owner) -- 100 chars = 600 px
			local s = surface()
			assert.equals(300, s.size[1])
			assert.is_true(s.size[2] > LINE + 20)
		end)

		it("measure text once and reuse it while the text doesn't change", function()
			local tip = UI.Tooltip({ { text = "Steady" } })
			tip:Show(owner)
			local after = log.setText
			tip:Refresh()
			-- Only the drawn font string gets its text again; the measurer is not asked.
			assert.equals(after + 1, log.setText)
		end)
	end)

	describe("at a UI scale other than 1", function()
		-- Every line the player sees must fit the height the layout gave it, inside the tooltip.
		local function assertNothingOverflows(s)
			local layout = UI._Describe().layout
			local drawn = 0
			for _, fs in ipairs(s.fonts) do
				if fs.shown then
					drawn = drawn + 1
					local item = layout[drawn]
					assert.equals(item.text, fs.text)
					assert.is_true(fs:Lines() * LINE <= item.h,
						("%q needs %d lines, the layout made room for %d"):format(fs.text, fs:Lines(), item.h / LINE))
					assert.is_true(item.y + item.h <= s.size[2], fs.text .. " sticks out at the bottom")
				end
			end
			assert.is_true(drawn > 0)
		end

		it("measures text at the scale it is drawn at, so no line wraps unexpectedly", function()
			uiScale = 0.64
			UI.Tooltip({
				{ text = "Elwynn Forest", style = "title" },
				{ text = "Goldshire" },
				{ text = "Click: world map", style = "hint" },
			}):Show(owner)
			assertNothingOverflows(surface())
		end)

		it("measures again when the UI scale changes", function()
			local tip = UI.Tooltip({ { text = "Click: calendar" } })
			tip:Show(owner)
			uiScale = 0.64
			tip:Refresh()
			assertNothingOverflows(surface())
		end)
	end)

	describe("components", function()
		it("a block draws its tree on its own frame and takes no mouse without listeners", function()
			local label = UI.Block({ name = "MyLabel", { text = "Goldshire", style = "small" } })
			assert.equals(1, loads)
			local f = frameNamed("MyLabel")
			assert.equals(f, label.frame)
			assert.same({ "Goldshire" }, shownTexts(f))
			assert.equals("GameFontHighlightSmall", f.fonts[#f.fonts].font.fontName)
			assert.is_false(f.mouse)
			assert.is_nil(f.scripts.OnClick)
			assert.same({ 9 * CHAR + 1, LINE }, f.size) -- shrink to fit, no padding without a style
		end)

		it("a button takes clicks once it has a listener, and calls it with itself", function()
			local clicks = {}
			local button = UI.Button({ name = "MyButton", { text = "Calendar" } })
			assert.equals("button", button.block.style)
			button:On("click", function(self, mouseButton)
				clicks[#clicks + 1] = { self, mouseButton }
			end)
			local f = button.frame
			assert.is_true(f.mouse)
			assert.same({ "AnyUp" }, f.clicks)
			f.scripts.OnClick(f, "RightButton", false)
			assert.same({ { button, "RightButton" } }, clicks)
		end)

		it("listeners can come in the spec, several per event, and go away with Off", function()
			local seen = {}
			local function a()
				seen[#seen + 1] = "a"
			end
			local function b()
				seen[#seen + 1] = "b"
			end
			local button = UI.Button({ name = "Two", on = { click = a }, { text = "x" } })
			button:On("click", b)
			button.frame.scripts.OnClick(button.frame, "LeftButton")
			button:Off("click", a)
			button.frame.scripts.OnClick(button.frame, "LeftButton")
			assert.same({ "a", "b", "b" }, seen)
		end)

		it("drag listeners register the frame for dragging", function()
			local button = UI.Button({ name = "Draggable", { text = "x" } })
			button:On("dragstart", function() end)
			assert.same({ "LeftButton" }, button.frame.drag)
			assert.is_function(button.frame.scripts.OnDragStart)
		end)

		it("game events use one shared frame, registered only while someone listens", function()
			local one = UI.Block({ name = "One", { text = "1" } })
			local two = UI.Block({ name = "Two", { text = "2" } })
			local got = {}
			local function onZone(self, arg)
				got[#got + 1] = { self, arg }
			end
			one:On("ZONE_CHANGED", onZone)
			two:On("ZONE_CHANGED", onZone)
			local shared
			for _, f in ipairs(frames) do
				if f.events.ZONE_CHANGED then
					assert.is_nil(shared, "only one frame registers the event")
					shared = f
				end
			end
			shared.scripts.OnEvent(shared, "ZONE_CHANGED", "payload")
			assert.same({ { one, "payload" }, { two, "payload" } }, got)
			assert.is_false(one.frame.mouse) -- game events don't make a block take the mouse
			one:Off("ZONE_CHANGED", onZone)
			assert.is_true(shared.events.ZONE_CHANGED)
			two:Off("ZONE_CHANGED", onZone)
			assert.is_nil(shared.events.ZONE_CHANGED)
		end)

		it("refuses events it doesn't know", function()
			local block = UI.Block({ name = "X", { text = "x" } })
			assert.has_error(function()
				block:On("hover", function() end)
			end)
		end)

		it("a tooltip in the spec shows on enter next to the frame and hides on leave", function()
			local tip = UI.Tooltip({ { text = "World map" } }, { side = "below" })
			local zone = UI.Button({ name = "Zone", tooltip = tip, { text = "Elwynn Forest" } })
			assert.is_nil(zone.block.tooltip) -- the tooltip belongs to the instance, not the block tree
			local f = zone.frame
			f.scripts.OnEnter(f)
			assert.is_true(tip:IsShown())
			assert.equals(f, surface().point[2])
			f.scripts.OnLeave(f)
			assert.is_false(tip:IsShown())
		end)

		it("redraws after its fields change, and SetText changes the first text", function()
			local label = { text = "12:00", style = "small" }
			local clock = UI.Button({ name = "Clock", label })
			clock:SetText("12:01")
			assert.equals("12:01", label.text)
			assert.same({ "12:01" }, shownTexts(clock.frame))
			label.hidden = true
			clock:Refresh()
			assert.same({}, shownTexts(clock.frame))
		end)

		it("passes placement calls to its frame", function()
			local block = UI.Block({ name = "Placed", { text = "x" } })
			block:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 2, -9)
			assert.same({ "TOPLEFT", owner, "BOTTOMLEFT", 2, -9 }, block.frame.point)
			block:Hide()
			assert.is_false(block:IsShown())
		end)

		it("draws an icon button's surface, image and hover highlight from the theme", function()
			local icon = { image = "Interface\\Icons\\INV_Misc_Bag_10", size = 20 }
			local button = UI.Button({ name = "Bag", style = "iconButton", icon })
			local f = button.frame
			assert.same({ 28, 28 }, f.size) -- padding 4 around a 20 px icon
			assert.is_table(f.backdrop)
			local image, highlight
			for _, t in ipairs(f.textures) do
				if t.layer == "HIGHLIGHT" then
					highlight = t
				else
					image = t
				end
			end
			assert.equals("Interface\\Icons\\INV_Misc_Bag_10", image.file)
			assert.same({ 0, 1, 0, 1 }, image.texCoord)
			assert.equals("Interface\\Buttons\\ButtonHilight-Square", highlight.file)
			icon.image, icon.atlas, icon.texCoord = nil, "ui-hud-minimap-mail-up", { 0.1, 0.9, 0.1, 0.9 }
			button:Refresh()
			assert.equals("ui-hud-minimap-mail-up", image.atlas)
			assert.same({ 0.1, 0.9, 0.1, 0.9 }, image.texCoord)
		end)

		it("draws format + args with SetFormattedText and measures again only when an argument changes", function()
			local value = { format = "%.1f, %.1f", args = { 42.5, 61.0 }, style = "small" }
			local coords = UI.Block({ name = "Coords", value })
			assert.same({ "42.5, 61.0" }, shownTexts(coords.frame))
			assert.equals(0, log.setText)
			local before = log.setFormatted
			coords:Refresh() -- same arguments: only the drawn font string is set again
			assert.equals(before + 1, log.setFormatted)
			value.args[1] = 42.6
			coords:Refresh()
			assert.same({ "42.6, 61.0" }, shownTexts(coords.frame))
			assert.is_true(log.setFormatted > before + 2) -- measured again, then drawn
		end)
	end)

	it("says once in chat when the framework can't load, and stays quiet afterwards", function()
		loadResult = false
		UI.Tooltip({ { text = "x" } }):Show(owner)
		assert.is_nil(UI.Button({ name = "B", { text = "y" } }))
		assert.equals(1, loads)
		assert.equals(1, #chat)
		assert.truthy(chat[1]:find("OrdaenCore_UI", 1, true))
		assert.truthy(chat[1]:find("DISABLED", 1, true))
	end)
end)
