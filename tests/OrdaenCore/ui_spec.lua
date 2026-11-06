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

-- Like the shared fakes (helpers.stubObject): a method a real Forever widget has is a no-op, anything else nil.
local function noop() end
local STRICT = { __index = function(_, key)
	return helpers.isStubMethod(key) and noop or nil
end }

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
	function fs:SetFont(file, size, flags)
		self.fontFile, self.fontSize, self.fontFlags = file, size, flags
		return true
	end
	function fs:SetShadowOffset(x, y)
		self.shadow = { x, y }
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
	return setmetatable(fs, STRICT)
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
	function t:SetGradient(orientation, from, to)
		self.gradient = { orientation, { from:GetRGBA() }, { to:GetRGBA() } }
	end
	function t:SetDrawLayer(drawLayer, sublevel)
		self.layer, self.sublevel = drawLayer, sublevel
	end
	function t:SetVertexColor(...)
		self.vertexColor = { ... }
	end
	function t:SetPoint(...)
		self.point = { ... }
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
	return setmetatable(t, STRICT)
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
	function f:GetWidth()
		return self.size and self.size[1] or 0
	end
	function f:GetHeight()
		return self.size and self.size[2] or 0
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
	function f:ClearBackdrop()
		self.backdrop = nil
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
	function f:SetFrameLevel(level)
		self.level = level
	end
	function f:GetFrameLevel() -- a real frame always has one: its parent's + 1 unless set
		if self.level then
			return self.level
		end
		local parentLevel = self.parent and self.parent.GetFrameLevel and self.parent:GetFrameLevel()
		return parentLevel and parentLevel + 1 or 1
	end
	function f:SetAttribute(key, value)
		self.attributes = self.attributes or {}
		self.attributes[key] = value
	end
	function f:HookScript(script, fn)
		local before = self.scripts[script]
		self.scripts[script] = before and function(...)
			before(...)
			fn(...)
		end or fn
	end
	function f:RegisterEvent(event)
		self.events[event] = true
	end
	function f:UnregisterEvent(event)
		self.events[event] = nil
	end
	return setmetatable(f, STRICT)
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
			-- The player's settings at Blizzard's defaults (secure buttons act on key down).
			C_CVar = { GetCVarBool = function(name)
				return name == "ActionButtonUseKeyDown"
			end },
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
			rawset(_G, font, { fontName = font, GetFont = function()
				return "Fonts\\" .. font .. ".ttf", 12, ""
			end })
		end
		rawset(_G, "OrdaenCoreDB", nil) -- Ordaen Core's global settings: defaults (theme ordaen, text size 12)
		helpers.shiftDown = false
		local core = helpers.loadCore()
		-- The game ends the loading screen after login; dialogs wait for it (Confirm.lua).
		for _, f in ipairs(frames) do
			if f.events and f.events.LOADING_SCREEN_DISABLED and f.scripts.OnEvent then
				f.scripts.OnEvent(f, "LOADING_SCREEN_DISABLED")
			end
		end
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
			-- The ordaen theme: titles in capitals, in the header font at the title size (12 x 1.42), no shadow.
			assert.same({ "ELWYNN FOREST", "Click: world map" }, shownTexts(s))
			local visible = {}
			for _, fs in ipairs(s.fonts) do
				if fs.shown then
					visible[#visible + 1] = fs -- the surface also holds its hidden measuring font string
				end
			end
			assert.equals("Fonts\\GameTooltipHeaderText.ttf", visible[1].fontFile)
			assert.equals(17, visible[1].fontSize)
			assert.same({ 0, 0 }, visible[1].shadow)
			assert.same({ 0.56, 0.54, 0.50 }, visible[2].color)
			-- min width 12 ems (144) beats the widest line; two lines + gap xs (2) + padding lg (12) twice.
			assert.same({ 144, LINE + 2 + LINE + 24 }, s.size)
			assert.same({ "TOP", owner, "BOTTOM", 0, -4 }, s.point)
			assert.is_nil(s.backdrop) -- drawn without art
		end)

		it("draw Blizzard's art and shadowed text in the blizzard theme", function()
			rawset(_G, "OrdaenCoreDB", { ui = { theme = "blizzard", textSize = 12 } })
			local tip = UI.Tooltip({ { text = "Elwynn Forest", style = "title" } })
			tip:Show(owner)
			local s = surface()
			assert.equals("Interface\\Tooltips\\UI-Tooltip-Border", s.backdrop.edgeFile)
			assert.same({ "Elwynn Forest" }, shownTexts(s)) -- no capitals
			assert.same({ 13 * CHAR + 1 + 16, LINE + 16 }, s.size) -- padding md (8)
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
			local layout = {} -- the laid-out text elements, in drawing order (nested blocks' too)
			for _, item in ipairs(UI._Describe().layout) do
				if item.text then
					layout[#layout + 1] = item
				end
			end
			local drawn = 0
			for _, fs in ipairs(s.fonts) do
				if fs.shown then
					drawn = drawn + 1
					local item = layout[drawn]
					assert.equals(item.text:upper(), fs.text:upper()) -- titles may be drawn in capitals
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
			assert.equals("Fonts\\GameFontNormal.ttf", f.fonts[#f.fonts].fontFile) -- labels on the world: ui font
			assert.equals(11, f.fonts[#f.fonts].fontSize) -- small tier: 12 x 0.9
			assert.same({ 1, -1 }, f.fonts[#f.fonts].shadow) -- no surface behind it: keeps a shadow
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
			rawset(_G, "OrdaenCoreDB", { ui = { theme = "blizzard" } })
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

	describe("themes", function()
		local WHITE = "Interface\\Buttons\\WHITE8X8"

		-- Shown solid (white, tinted) textures on `frame`, optionally on one draw layer.
		local function solids(frame, layer)
			local out = {}
			for _, t in ipairs(frame.textures) do
				if t.shown and t.file == WHITE and t.layer ~= "HIGHLIGHT" and (layer == nil or t.layer == layer) then
					out[#out + 1] = t
				end
			end
			return out
		end

		local function fontOf(frame, text)
			for _, fs in ipairs(frame.fonts) do
				if fs.shown and fs.text == text then
					return fs
				end
			end
		end

		it("scale every text size and spacing step with the global text size", function()
			rawset(_G, "OrdaenCoreDB", { ui = { theme = "ordaen", textSize = 16 } })
			UI.Tooltip({ { text = "Goldshire" }, { text = "Stormwind", style = "title" } }):Show(owner)
			local s = surface()
			assert.equals(16, fontOf(s, "Goldshire").fontSize)
			assert.equals(23, fontOf(s, "STORMWIND").fontSize) -- title tier: 16 x 1.42
			-- padding lg (12 at size 12) is 16 here, gap xs 3; min width 12 ems = 192.
			assert.same({ 192, LINE + 3 + LINE + 32 }, s.size)
		end)

		it("fall back to the defaults for settings they don't know", function()
			rawset(_G, "OrdaenCoreDB", { ui = { theme = "neon", textSize = 99 } })
			UI.Tooltip({ { text = "Goldshire" } }):Show(owner)
			local s = surface()
			assert.is_nil(s.backdrop) -- ordaen
			assert.equals(16, fontOf(s, "Goldshire").fontSize) -- clamped to the largest size
		end)

		it("restyle everything on screen when the global settings change", function()
			local tip = UI.Tooltip({ { text = "Stormwind", style = "title" } })
			tip:Show(owner)
			local label = UI.Block({ name = "Label", { text = "Goldshire", style = "small" } })
			local s = surface()
			assert.same({ "STORMWIND" }, shownTexts(s))
			rawset(_G, "OrdaenCoreDB", { ui = { theme = "blizzard", textSize = 14 } })
			UI._SettingsChanged()
			assert.same({ "Stormwind" }, shownTexts(s))
			assert.equals("Interface\\Tooltips\\UI-Tooltip-Border", s.backdrop.edgeFile)
			assert.equals(13, fontOf(label.frame, "Goldshire").fontSize) -- small tier of 14
			rawset(_G, "OrdaenCoreDB", { ui = { theme = "minimal", textSize = 12 } })
			UI._SettingsChanged()
			assert.is_nil(s.backdrop) -- art taken off again
			assert.same({ "Stormwind" }, shownTexts(s))
		end)

		it("tint a surface with the block's accent, else the theme's", function()
			UI.Tooltip({ accent = { 1, 0, 0 }, { text = "Hogger" } }):Show(owner)
			local top = solids(surface(), "BORDER")[1] -- the top edge: 0 + accent x 0.8
			assert.same({ 0.8, 0, 0, 0.95 }, top.gradient[2])
		end)

		it("draw edges and lines in whole physical pixels at any UI scale", function()
			uiScale = 0.5 -- one physical pixel is 2 UI units here (the fake pixel factor is 1)
			UI.Tooltip({ { text = "Goldshire" }, { separator = "rule" } }):Show(owner)
			local s = surface()
			local top = solids(s, "BORDER")[1]
			assert.equals(4, top.size[2]) -- 2 px
			local rule = solids(s, "ARTWORK")[1]
			assert.equals(2, rule.size[2]) -- 1 px
		end)

		it("write capitals in Russian too", function()
			UI.Tooltip({ { text = "Элвиннский лес, ёлка", style = "title" } }):Show(owner)
			assert.same({ "ЭЛВИННСКИЙ ЛЕС, ЁЛКА" }, shownTexts(surface()))
		end)

		it("stretch separators and bars over their cell, a caption between two lines", function()
			UI.Tooltip({
				{ text = "A line of some length" },
				{ separator = "caption", text = "Stats" },
				{ bar = 0.25 },
			}):Show(owner)
			local s = surface()
			assert.same({ "A line of some length", "STATS" }, shownTexts(s))
			local layout = UI._Describe().layout
			local inner = s.size[1] - 24
			assert.equals(inner, layout[2].w)
			assert.equals(inner, layout[3].w)
			local lines = solids(s, "ARTWORK")
			assert.equals(4, #lines) -- two caption lines, the bar's track and fill
			assert.equals(inner, lines[3].size[1])
			assert.equals(inner * 0.25, lines[4].size[1])
		end)

		it("show Shift rows only while Shift is held, and listen for it only while shown", function()
			local tip = UI.Tooltip({
				{ text = "Hogger" },
				{ text = "Level 11 elite", shift = true },
				{ text = "Hold Shift for more", style = "hint", shift = false },
			})
			tip:Show(owner)
			local s = surface()
			assert.same({ "Hogger", "Hold Shift for more" }, shownTexts(s))
			assert.is_true(s.events.MODIFIER_STATE_CHANGED)
			helpers.shiftDown = true
			s.scripts.OnEvent(s, "MODIFIER_STATE_CHANGED", "LSHIFT", 1)
			assert.same({ "Hogger", "Level 11 elite" }, shownTexts(s))
			tip:Hide()
			assert.is_nil(s.events.MODIFIER_STATE_CHANGED)
			UI.Tooltip({ { text = "No Shift rows" } }):Show(owner)
			assert.is_nil(s.events.MODIFIER_STATE_CHANGED)
		end)

		it("make headers: icon left, title and subtitle beside it, on a band to the tooltip's edges", function()
			local header = UI.Header({ title = "Stormwind", subtitle = "Trade District", icon = 134400 })
			local tip = UI.Tooltip({ header, { text = "Goldshire" } })
			tip:Show(owner)
			local s = surface()
			assert.same({ "STORMWIND", "Trade District", "Goldshire" }, shownTexts(s))
			local band
			for _, t in ipairs(solids(s, "BACKGROUND")) do
				if t.sublevel == 2 then
					band = t
				end
			end
			assert.same({ "TOPLEFT", s, "TOPLEFT", 0, 0 }, band.point) -- bleeds over the tooltip's padding
			assert.equals(s.size[1], band.size[1])
			header.titleText.text = "Elwynn"
			tip:Refresh()
			assert.same({ "ELWYNN", "Trade District", "Goldshire" }, shownTexts(s))
		end)
	end)

	describe("confirm dialogs", function()
		-- The shown frame whose drawn text is `text` (a button's label, the message).
		local function frameWithText(text)
			for _, f in ipairs(frames) do
				if f.shown then
					for _, fs in ipairs(f.fonts) do
						if fs.shown and fs.text == text then
							return f
						end
					end
				end
			end
		end

		it("cost nothing until shown, then show the message and the buttons", function()
			local ask = UI.Confirm({ text = "Reload now?", buttons = { { text = "OK" }, { text = "Later" } } })
			assert.equals(0, loads)
			ask:Show()
			local dialog = frameNamed("OrdaenUIConfirm")
			assert.is_true(dialog.shown)
			assert.is_true(ask:IsShown())
			assert.truthy(frameWithText("Reload now?"))
			assert.truthy(frameWithText("OK"))
			assert.truthy(frameWithText("Later"))
			assert.equals("OrdaenUIConfirm", rawget(_G, "UISpecialFrames")[#rawget(_G, "UISpecialFrames")])
		end)

		it("close on a button, then run its function", function()
			local pressed
			local ask = UI.Confirm({ text = "Keep ours?", buttons = {
				{ text = "Keep ours", onClick = function()
					pressed = "ours"
				end },
				{ text = "Keep theirs" },
			} })
			ask:Show()
			local button = frameWithText("Keep ours")
			button.scripts.OnClick(button, "LeftButton")
			assert.equals("ours", pressed)
			assert.is_false(frameNamed("OrdaenUIConfirm").shown)
			assert.is_false(ask:IsShown())
		end)

		it("count Escape as cancel", function()
			local cancelled = false
			local ask = UI.Confirm({ text = "?", buttons = { { text = "OK" } }, onCancel = function()
				cancelled = true
			end })
			ask:Show()
			local dialog = frameNamed("OrdaenUIConfirm")
			dialog:Hide() -- what Escape does to a frame in UISpecialFrames
			dialog.scripts.OnHide(dialog)
			assert.is_true(cancelled)
			assert.is_false(ask:IsShown())
		end)

		it("grow to fit their buttons: none sticks out of the dialog", function()
			UI.Confirm({ text = "Two addons change the tooltips.", buttons = {
				{ text = "Keep Ordaen Tooltips" }, { text = "Keep PrettyTooltip" }, { text = "Keep both" },
			} }):Show()
			local dialog = frameNamed("OrdaenUIConfirm")
			for _, label in ipairs({ "Keep Ordaen Tooltips", "Keep PrettyTooltip", "Keep both" }) do
				local button = frameWithText(label)
				local point = button.point -- { "TOPLEFT", dialog, "TOPLEFT", x, -y }
				assert.equals(dialog, point[2])
				assert.is_true(point[4] >= 0, label .. " starts left of the dialog")
				assert.is_true(point[4] + button.size[1] <= dialog.size[1], label .. " sticks out on the right")
				assert.is_true(-point[5] + button.size[2] <= dialog.size[2], label .. " sticks out at the bottom")
			end
		end)

		it("run a button's macro through a secure overlay, after its onClick", function()
			local turnedOff = false
			UI.Confirm({ text = "Reload?", buttons = {
				{ text = "Reload", macro = "/reload", onClick = function()
					turnedOff = true
				end },
				{ text = "Not now" },
			} }):Show()
			local button = frameWithText("Reload")
			local overlay
			for _, f in ipairs(frames) do
				if f.parent == button and f.attributes then
					overlay = f
				end
			end
			assert.truthy(overlay)
			assert.equals("macro", overlay.attributes.type1)
			assert.equals("/reload", overlay.attributes.macrotext)
			-- On the press the game acts on (ActionButtonUseKeyDown, on by default): the other half did nothing.
			assert.same({ "LeftButtonDown" }, overlay.clicks)
			overlay.scripts.PreClick(overlay, "LeftButton")
			assert.is_true(turnedOff)
		end)

		it("wait for the loading screen: one shown under it appears when it ends", function()
			local eventFrame
			for _, f in ipairs(frames) do
				if f.events and f.events.LOADING_SCREEN_ENABLED then
					eventFrame = f
				end
			end
			eventFrame.scripts.OnEvent(eventFrame, "LOADING_SCREEN_ENABLED")
			local ask = UI.Confirm({ text = "At login", buttons = { { text = "OK" } } })
			ask:Show()
			assert.is_false(ask:IsShown())
			eventFrame.scripts.OnEvent(eventFrame, "LOADING_SCREEN_DISABLED")
			assert.is_true(ask:IsShown())
			assert.truthy(frameWithText("At login"))
		end)

		it("show one at a time: a second waits for the first to close", function()
			local first = UI.Confirm({ text = "First", buttons = { { text = "OK" } } })
			local second = UI.Confirm({ text = "Second", buttons = { { text = "Fine" } } })
			first:Show()
			second:Show()
			assert.is_true(first:IsShown())
			assert.is_false(second:IsShown())
			local ok = frameWithText("OK")
			ok.scripts.OnClick(ok, "LeftButton")
			assert.is_true(second:IsShown())
			assert.truthy(frameWithText("Second"))
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
