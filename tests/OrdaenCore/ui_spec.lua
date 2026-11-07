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
	function fs:SetShown(shown)
		self.shown = shown and true or false
	end
	function fs:SetAlpha(a)
		self.alpha = a
	end
	function fs:GetAlpha()
		return self.alpha or 1
	end
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
	function fs:GetFont()
		return self.fontFile, self.fontSize, self.fontFlags
	end
	function fs:IsObjectType(kind)
		return kind == "FontString" or kind == "Region"
	end
	function fs:SetAlpha(a)
		self.alpha = a
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
	function t:IsObjectType(kind)
		return kind == "Texture" or kind == "Region"
	end
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
	function t:SetScale(scale)
		self.scale = scale
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
	function t:SetShown(shown)
		self.shown = shown and true or false
	end
	function t:SetDesaturated(on)
		self.desaturated = on
	end
	function t:AddMaskTexture(mask)
		self.masks = self.masks or {}
		self.masks[#self.masks + 1] = mask
	end
	function t:SetAlpha(a)
		self.alpha = a
	end
	function t:GetAlpha()
		return self.alpha or 1
	end
	-- An animation group that remembers whether it played (the bar's gain flash).
	function t:CreateAnimationGroup()
		local group = { played = 0 }
		function group:CreateAnimation()
			return setmetatable({}, STRICT)
		end
		function group:Play()
			self.played = self.played + 1
		end
		function group:Stop() end
		self.group = group
		return group
	end
	return setmetatable(t, STRICT)
end

local function fakeEditBox(f)
	f.text, f.focus = "", false
	function f:SetAutoFocus(on)
		self.autoFocus = on
	end
	function f:SetTextInsets(...)
		self.insets = { ... }
	end
	function f:SetText(text)
		self.text = text
		if self.scripts.OnTextChanged then
			self.scripts.OnTextChanged(self, false)
		end
	end
	function f:GetText()
		return self.text
	end
	function f:HasFocus()
		return self.focus
	end
	function f:ClearFocus()
		self.focus = false
		if self.scripts.OnEditFocusLost then
			self.scripts.OnEditFocusLost(self)
		end
	end
	function f:SetFont(file, size, flags)
		self.fontFile, self.fontSize, self.fontFlags = file, size, flags
	end
	function f:GetFont()
		return self.fontFile, self.fontSize, self.fontFlags
	end
	function f:SetShadowOffset(x, y)
		self.shadow = { x, y }
	end
	function f:SetShadowColor() end
	function f:SetTextColor(...)
		self.color = { ... }
	end
	-- The player types (userInput true), as the game calls the script.
	function f:Type(text)
		self.text = text
		self.scripts.OnTextChanged(self, true)
	end
	return f
end

local function fakeFrame(name, log, parent)
	local f = {
		name = name, shown = true, fonts = {}, textures = {}, scripts = {}, parent = parent or false,
		events = {}, mouse = nil, clicks = nil, drag = nil, children = {}, strata = "MEDIUM",
	}
	if parent and parent.children then
		parent.children[#parent.children + 1] = f
	end
	-- Parent, children and art (regions: textures, then font strings), as dressing walks them.
	function f:GetPoint() -- point, relative frame, relative point, x, y
		local p = self.point
		return p[1], p[2], p[3], p[4], p[5]
	end
	function f:GetName()
		return self.name
	end
	function f:SetMovable(on)
		self.movable = on
	end
	function f:SetClampedToScreen(on)
		self.clamped = on
	end
	function f:StartMoving()
		self.moving = true
	end
	function f:StopMovingOrSizing()
		self.moving = false
	end
	function f:SetParent(p)
		if self.parent and self.parent.children then
			for i, child in ipairs(self.parent.children) do
				if child == self then
					table.remove(self.parent.children, i)
					break
				end
			end
		end
		self.parent = p or false
		if p and p.children then
			p.children[#p.children + 1] = self
		end
		self.level = nil -- as in the game: the level becomes the new parent's + 1 again
	end
	function f:GetParent()
		return self.parent or nil
	end
	function f:GetChildren()
		return unpack(self.children)
	end
	function f:IsObjectType(kind)
		return kind == "Frame" or kind == self.objectType
	end
	function f:GetRegions()
		local out = {}
		for _, t in ipairs(self.textures) do
			out[#out + 1] = t
		end
		for _, fs in ipairs(self.fonts) do
			out[#out + 1] = fs
		end
		return unpack(out)
	end
	function f:ClearAllPoints()
		self.point = nil
	end
	function f:SetAllPoints(target)
		self.point = { "ALL", target }
	end
	function f:SetFrameStrata(strata)
		self.strata = strata
	end
	function f:GetFrameStrata()
		return self.strata
	end
	function f:LockHighlight()
		self.highlightLocked = true
	end
	function f:UnlockHighlight()
		self.highlightLocked = false
	end
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
	function f:CreateMaskTexture()
		return fakeTexture("ARTWORK")
	end
	function f:CreateTexture(_, layer, _, sublevel)
		local t = fakeTexture(layer)
		t.sublevel = sublevel
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
	-- Like the game: OnShow/OnHide run when the frame's own shown state changes.
	function f:Show()
		local was = self.shown
		self.shown = true
		if not was and self.scripts and self.scripts.OnShow then
			self.scripts.OnShow(self)
		end
	end
	function f:Hide()
		local was = self.shown
		self.shown = false
		if was and self.scripts and self.scripts.OnHide then
			self.scripts.OnHide(self)
		end
	end
	function f:SetShown(shown)
		if shown then
			self:Show()
		else
			self:Hide()
		end
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
	function f:SetUsingParentLevel(on)
		self.usingParentLevel = on
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
	function f:GetScript(script)
		return self.scripts[script]
	end
	function f:RegisterEvent(event)
		self.events[event] = true
	end
	function f:UnregisterEvent(event)
		self.events[event] = nil
	end
	-- Status bars (the bar element): range, value (and whether it was animated), colour, texture.
	function f:SetMinMaxValues(lo, hi)
		self.range = { lo, hi }
	end
	function f:SetValue(v, interpolation)
		self.value, self.interpolation = v, interpolation
	end
	function f:SetStatusBarColor(...)
		self.barColor = { ... }
	end
	function f:SetStatusBarTexture(file)
		self.barTexture = file
	end
	-- Fading (panels): alpha, clicks, and an animation group that remembers its last fade.
	function f:SetAlpha(a)
		self.alpha = a
	end
	function f:GetAlpha()
		return self.alpha or 1
	end
	function f:SetMouseClickEnabled(on)
		self.clicksEnabled = on
	end
	function f:CreateAnimationGroup()
		local group = { played = 0 }
		function group:CreateAnimation()
			local anim = {}
			function anim:SetFromAlpha(a)
				group.from = a
			end
			function anim:SetToAlpha(a)
				group.to = a
			end
			function anim:SetDuration(d)
				group.duration = d
			end
			return setmetatable(anim, STRICT)
		end
		function group:Play()
			self.played = self.played + 1
		end
		function group:Stop() end
		function group:SetToFinalAlpha() end
		self.group = group
		return group
	end
	return setmetatable(f, STRICT)
end

-- Stands for a secret value in the fake world (issecretvalue says so).
local SECRET = setmetatable({}, { __tostring = function()
	return "<secret>"
end })

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

	-- The status bars drawn on `parent` (three per bar element: overlay, quest, value), in creation order.
	local function barsOf(parent)
		local out = {}
		for _, f in ipairs(frames) do
			if f.parent == parent and f.range then
				out[#out + 1] = f
			end
		end
		return out
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
			CreateFrame = function(kind, name, parent)
				local f = fakeFrame(name, log, parent)
				if kind == "EditBox" then
					rawset(f, "kind", kind)
					fakeEditBox(f)
				end
				table.insert(frames, f)
				return f
			end,
			-- Secret values (Forever): SECRET stands for one, a number our code may pass on but not compare.
			issecretvalue = function(value)
				return value == SECRET
			end,
			-- Blizzard's CallbackRegistry: a callback gets its owner first, then the event's arguments.
			EventRegistry = {
				callbacks = {},
				RegisterCallback = function(self, event, fn, owner)
					self.callbacks[event] = self.callbacks[event] or {}
					table.insert(self.callbacks[event], { fn, owner })
				end,
				TriggerEvent = function(self, event, ...)
					for _, c in ipairs(self.callbacks[event] or {}) do
						c[1](c[2], ...)
					end
				end,
			},
			-- Blizzard's: runs `fn` after the original, with the same arguments.
			hooksecurefunc = function(target, method, fn)
				if type(target) == "string" then
					target, method, fn = _G, target, method
				end
				local original = target[method]
				rawset(target, method, function(...)
					local a, b, c = original(...)
					fn(...)
					return a, b, c
				end)
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
			assert.same({ "Elwynn Forest", "Click: world map" }, shownTexts(s))
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

		it("fall back to the ordaen look for a theme that isn't built (blizzard and minimal are planned)", function()
			rawset(_G, "OrdaenCoreDB", { ui = { theme = "blizzard", textSize = 12 } })
			local tip = UI.Tooltip({ { text = "Elwynn Forest", style = "title" } })
			tip:Show(owner)
			local s = surface()
			assert.is_nil(s.backdrop) -- drawn without art, as ordaen
			assert.same({ "Elwynn Forest" }, shownTexts(s)) -- titles keep their case
		end)

		it("show a block's hints and hotkey at the bottom, dimmed, the key last, the same in every tooltip", function()
			local tip = { { text = "Character Info", style = "title" }, hints = { "Left-click: open" } }
			UI.Tooltip(tip)
			tip.hotkey = "C"
			tip:Show(owner)
			local s = surface()
			assert.same({ "Character Info", "Left-click: open", "Key: C" }, shownTexts(s), "Ordaen Core's words")
			tip.hotkey = nil -- unbound
			tip:Refresh()
			assert.same({ "Character Info", "Left-click: open" }, shownTexts(s))
			tip.hints[2] = "Right-click: settings"
			tip.hotkey = "Shift-M"
			tip:Refresh()
			assert.same({ "Character Info", "Left-click: open", "Right-click: settings", "Key: Shift-M" }, shownTexts(s))
			tip.hints[2] = nil
			tip:Refresh()
			assert.same({ "Character Info", "Left-click: open", "Key: Shift-M" }, shownTexts(s))
			assert.equals(2, #tip, "the bottom rows added once")
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

		it("game events go to the component's own frame (billed to its addon), only while listened to", function()
			local one = UI.Block({ name = "One", { text = "1" } })
			local two = UI.Block({ name = "Two", { text = "2" } })
			local got = {}
			local function onZone(self, arg)
				got[#got + 1] = { self, arg }
			end
			one:On("ZONE_CHANGED", onZone)
			two:On("ZONE_CHANGED", onZone)
			for _, f in ipairs(frames) do
				if f.events.ZONE_CHANGED then
					assert.is_true(f == one.frame or f == two.frame, "no shared frame")
				end
			end
			one.frame.scripts.OnEvent(one.frame, "ZONE_CHANGED", "payload")
			two.frame.scripts.OnEvent(two.frame, "ZONE_CHANGED", "payload")
			assert.same({ { one, "payload" }, { two, "payload" } }, got)
			assert.is_false(one.frame.mouse) -- game events don't make a block take the mouse
			one:Off("ZONE_CHANGED", onZone)
			assert.is_nil(one.frame.events.ZONE_CHANGED)
			assert.is_true(two.frame.events.ZONE_CHANGED)
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
			assert.is_nil(f.backdrop) -- drawn without art
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
			assert.equals("Interface\\Buttons\\WHITE8X8", highlight.file) -- the theme's highlight colour
			assert.is_true(highlight.vertexColor[4] > 0)
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

	describe("windows", function()
		it("are the parent of what's embedded in them, so closing one hides its panes and buttons too", function()
			local close = UI.Button({ name = "PaneClose", { text = "x" } })
			local pane = UI.Block({ name = "Pane", { embed = close } })
			local raised = UI.Button({ name = "Raised", strata = "DIALOG", level = 30, { text = "!" } })
			local win = UI.Window({ name = "PaneWindow", { embed = pane }, { embed = raised } })
			win:Refresh()
			assert.equals(win.frame, pane.frame:GetParent())
			assert.equals(pane.frame, close.frame:GetParent(), "nested: the pane's own button is the pane's child")
			assert.equals(win.frame, raised.frame:GetParent())
			assert.equals("DIALOG", raised.frame:GetFrameStrata(), "a spec's own strata survives the new parent")
			assert.equals(30, raised.frame:GetFrameLevel(), "and its own level")
		end)

		it("open where the owner says the first time, hidden, movable, closed by Escape", function()
			local win = UI.Window({ name = "MyWindow", { text = "Bags" } }, { point = "RIGHT", x = -40 })
			local f = win.frame
			assert.equals("window", win.block.style)
			assert.is_false(f.shown)
			assert.is_true(f.movable)
			assert.is_true(f.clamped)
			assert.same({ "RIGHT", _G.UIParent, "RIGHT", -40, 0 }, f.point)
			assert.same({ "MyWindow" }, _G.UISpecialFrames)
			assert.same({ "LeftButton" }, f.drag)
		end)

		it("remember where the player drops them, and forget it on ResetPosition", function()
			rawset(_G, "OrdaenCoreDB", {})
			local win = UI.Window({ name = "Dragged", { text = "Bags" } })
			local f = win.frame
			f.scripts.OnDragStart(f)
			assert.is_true(f.moving)
			f:SetPoint("TOPLEFT", _G.UIParent, "TOPLEFT", 100.4, -200.6) -- where the game left it
			f.scripts.OnDragStop(f)
			assert.is_false(f.moving)
			assert.same({ "TOPLEFT", 100, -201 }, _G.OrdaenCoreDB.ui.windows.Dragged)
			local again = UI.Window({ name = "Dragged", { text = "Bags" } }) -- next session
			assert.same({ "TOPLEFT", _G.UIParent, "TOPLEFT", 100, -201 }, again.frame.point)
			again:ResetPosition()
			assert.is_nil(_G.OrdaenCoreDB.ui.windows.Dragged)
			assert.same({ "CENTER", _G.UIParent, "CENTER", 0, 0 }, again.frame.point)
		end)

		it("wear Blizzard's window frame and fill, tinted only by an accent of their own", function()
			local win = UI.Window({ name = "Framed", { text = "Bags" } })
			win:Show()
			local f = win.frame
			assert.equals("ButtonFrameTemplateNoPortrait", f.layout)
			assert.equals(1, f.TopLeftCorner.scale)
			assert.same({ 1, 1, 1 }, f.TopLeftCorner.vertexColor)
			local fill
			for _, t in ipairs(f.textures) do
				if t.atlas == "UI-Character-Info-General-BG" then
					fill = t
				end
			end
			assert.is_truthy(fill, "the fill inside the border")
			assert.is_true(f.unsharpened)
			win.block.accent = { 0.6, 0.2, 0.9 }
			win:Refresh()
			assert.same({ 0.6, 0.2, 0.9 }, f.TopLeftCorner.vertexColor)
		end)

		it("leave open sides without border: that edge and its corners hide, the edges beside it run on", function()
			local strip = UI.Block({ name = "Strip", style = "panel", open = { bottom = true }, { text = "Gold" } })
			local f = strip.frame
			assert.is_false(f.BottomEdge.shown)
			assert.is_false(f.BottomLeftCorner.shown)
			assert.is_false(f.BottomRightCorner.shown)
			assert.is_true(f.TopEdge.shown)
			assert.is_true(f.TopLeftCorner.shown)
			-- (the fake keeps the last point: each edge's bottom-right one, to the outer side of the hidden corner)
			assert.same({ "BOTTOMRIGHT", f.BottomLeftCorner, "BOTTOMRIGHT" }, f.LeftEdge.point)
			assert.same({ "BOTTOMRIGHT", f.BottomRightCorner, "BOTTOMRIGHT" }, f.RightEdge.point)
			assert.same({ "BOTTOMRIGHT", f.TopRightCorner, "BOTTOMLEFT" }, f.TopEdge.point, "closed sides: inner")
			strip:SetOpen(nil)
			assert.is_true(f.BottomEdge.shown, "closed again: Blizzard's layout as it was")
			assert.is_true(f.BottomLeftCorner.shown)
		end)

		it("fit a background that doesn't tile to the surface's shape: cropped centred, never stretched", function()
			-- The shared fake atlas (helpers.atlasInfo): 200 x 100, a region inside its file. The crop counts within the
			-- atlas (0..1), never in the file's coordinates.
			local win = UI.Window({ name = "Fitted", width = 300, height = 400, { text = "Bags" } })
			win:Show()
			local fill
			for _, t in ipairs(win.frame.textures) do
				fill = fill or (t.atlas == "UI-Character-Info-General-BG" and t)
			end
			-- Inside the border (2 + 2 wide, 21 + 2 tall): 296 x 377, taller than 2:1, so a band of the art's width.
			local l, r, t, b = unpack(fill.texCoord)
			assert.same({ 0, 1 }, { t, b }, "its full height")
			assert.is_true(math.abs((r - l) - (296 / 377) / 2) < 1e-6, "the share of its width the aspect allows")
			assert.is_true(math.abs(l - (1 - r)) < 1e-6, "centred")
		end)

		-- The control art drawn on a frame: its shown textures by layer, as { atlas or file, alpha, tint }.
		local function controlPieces(frame, layer)
			local out = {}
			for _, t in ipairs(frame.textures) do
				if t.shown and t.layer == layer and (t.atlas or t.file) then
					out[#out + 1] = t
				end
			end
			return out
		end

		it("draw Blizzard's control art: a selected tab's three slices, the hover piece on the highlight layer", function()
			local tab = UI.Block({ name = "Tab", style = "tab", controlState = "selected", width = 200, height = 30 })
			local pieces = controlPieces(tab.frame, "BACKGROUND")
			assert.same({ "uiframe-activetab-left", "_uiframe-activetab-center", "uiframe-activetab-right" },
				{ pieces[1].atlas, pieces[2].atlas, pieces[3].atlas })
			assert.equals(60, pieces[1].size[1], "an end keeps its aspect (2:1 here) at the tab's height")
			assert.equals(80, pieces[2].size[1], "the centre stretches")
			local hover = controlPieces(tab.frame, "HIGHLIGHT")
			assert.equals(3, #hover)
			assert.equals(0.4, hover[1].alpha)
		end)

		it("draw a checked box over the box, and a state without art as normal, darker or grey", function()
			local box = UI.Block({ name = "Box", style = "checkbox", controlState = "checked", width = 24, height = 24 })
			local files = {}
			for _, t in ipairs(controlPieces(box.frame, "BACKGROUND")) do
				files[#files + 1] = t.file
			end
			assert.same({ "Interface\\Buttons\\UI-CheckBox-Up", "Interface\\Buttons\\UI-CheckBox-Check" }, files)
			-- (the close button's art has no pushed or disabled piece)
			local button = UI.Block({ name = "Close", style = "closeButton", controlState = "pushed", width = 28,
				height = 28 })
			local left = controlPieces(button.frame, "BACKGROUND")[1]
			assert.equals("RedButton-Exit", left.atlas, "no pushed art: normal")
			assert.same({ 0.75, 0.75, 0.75 }, left.vertexColor)
			button.block.controlState = "disabled"
			button:Refresh()
			assert.is_true(controlPieces(button.frame, "BACKGROUND")[1].desaturated)
		end)

		it("take a tracked control's state into its art, without a states map", function()
			local b = fakeFrame("PushButton", log, _G.UIParent)
			local enabled = true
			function b:IsEnabled()
				return enabled
			end
			function b:GetButtonState()
				return "NORMAL"
			end
			function b:Disable()
				enabled = false
			end
			function b:Enable()
				enabled = true
			end
			function b:SetEnabled(on)
				enabled = on
			end
			function b:SetButtonState() end
			local dress = UI.Dress(b, { style = "pushButton", size = "frame", art = {}, track = "button" })
			b:Disable()
			assert.equals("pushButton", dress.look.block.style)
			assert.equals("disabled", dress.look.block.controlState)
		end)

		it("tint an item slot by its accent (quality), its ring reaching past the icon", function()
			local slot = UI.Block({ name = "Slot", style = "slot", width = 37, height = 37, accent = { 0.6, 0.2, 0.9 } })
			local ring = controlPieces(slot.frame, "BACKGROUND")[1]
			assert.equals("UI-Character-Info-GearSlot", ring.atlas)
			assert.same({ 55, 55 }, ring.size, "9 px around the 37 px icon")
			assert.same({ 0.6, 0.2, 0.9 }, ring.vertexColor)
		end)

		it("put a dropdown's label in the middle of its field, clear of the arrow", function()
			local label = { text = "Sort" }
			local dropdown = UI.Block({ name = "DropLabel", style = "dropdown", width = 150, height = 26, label })
			local x, y, w, h = dropdown:RectOf(label)
			assert.equals(math.floor((26 - h) / 2 + 0.5), y, "centred on the field")
			assert.is_true(x + w <= 150 - 26, "clear of the arrow")
		end)

		it("draw a dropdown as the button plate, its gold arrow at its own size inside the right end", function()
			local dropdown = UI.Block({ name = "Drop", style = "dropdown", width = 150 })
			assert.equals(34, dropdown.frame.size[2], "the buttons' height, from the role")
			local plate = controlPieces(dropdown.frame, "BACKGROUND")[1]
			assert.equals("Interface\\AddOns\\OrdaenCore\\media\\button", plate.file)
			local arrow = controlPieces(dropdown.frame, "BORDER")[1]
			assert.equals("Interface\\AddOns\\OrdaenCore\\media\\dropdown-arrow", arrow.file)
			assert.same({ 16, 16 }, arrow.size)
			assert.same({ "TOPLEFT", dropdown.frame, "TOPLEFT", 150 - 16 - 6, -(34 - 16) / 2 }, arrow.point)
		end)

				it("mirror a small surface's top from Blizzard's bottom corners, flipped within their atlas", function()
			rawset(_G, "NineSliceLayouts", { ButtonFrameTemplateNoPortrait = {
				BottomLeftCorner = { atlas = "UI-Frame-Metal-CornerBottomLeft", x = -8, y = -8 },
				BottomRightCorner = { atlas = "UI-Frame-Metal-CornerBottomRight", x = 2, y = -8 },
				BottomEdge = { atlas = "_UI-Frame-Metal-EdgeBottom" },
				LeftEdge = { atlas = "!UI-Frame-Metal-EdgeLeft" },
				RightEdge = { atlas = "!UI-Frame-Metal-EdgeRight" },
			} })
			local strip = UI.Block({ name = "Small", style = "panel", { text = "Gold" } })
			local corner = strip.frame.TopRightCorner
			assert.equals("UI-Frame-Metal-CornerBottomRight", corner.atlas)
			local top = strip.frame.TopEdge
			assert.equals("!UI-Frame-Metal-EdgeLeft", top.atlas, "the left edge, turned to light from the top-left")
			assert.same({ 0, 1, 1, 1, 0, 0, 1, 0 }, top.texCoord, "a quarter turn clockwise, within the atlas")
			-- Mitred: the corner is an invisible square as wide as the rim, the two rims masked over it.
			assert.same({ 200, 200 }, corner.size, "the left edge's thickness (the fake atlas: 200)")
			assert.equals(0, corner.alpha)
			local masked = {}
			for _, t in ipairs(strip.frame.textures) do
				if t.masks and t.shown then
					masked[#masked + 1] = t.masks[1].file
				end
			end
			assert.is_true(#masked >= 4, "two masked rims per top corner")
			assert.same({ 0, 1, 1, 0 }, corner.texCoord, "flipped within the atlas, not in its file")
			assert.same({ "TOPRIGHT", strip.frame, "TOPRIGHT", 2, 8 }, corner.point, "the bottom offset turned up")
			rawset(_G, "NineSliceLayouts", nil)
		end)

		it("insets wear Blizzard's inset frame and its background", function()
			local pane = UI.Block({ name = "Pane", style = "inset", { text = "Bags" } })
			assert.equals("InsetFrameTemplate", pane.frame.layout)
			local tiled
			for _, t in ipairs(pane.frame.textures) do
				tiled = tiled or t.file == 374154
			end
			assert.is_true(tiled, "the inset background (a file that tiles)")
		end)

				it("need a name", function()
			assert.has_error(function()
				UI.Window({ { text = "Bags" } })
			end)
		end)
	end)

	describe("inputs", function()
		local function editBox()
			for i = #frames, 1, -1 do
				if frames[i].kind == "EditBox" then
					return frames[i]
				end
			end
		end

		it("stand as tall as the buttons, the search border cut as a nine-slice that stays thin", function()
			local input = UI.Input({ width = 200 })
			assert.equals(34, input.frame.size[2], "the input role's height")
			local look
			for _, f in ipairs(frames) do
				if f.parent == input.frame then
					look = f
				end
			end
			local pieces = {}
			for _, t in ipairs(look.textures) do
				if t.shown and t.atlas == "common-search-border-left" then
					pieces[#pieces + 1] = t
				end
			end
			assert.equals(3, #pieces, "the left end in three rows")
			assert.same({ 0, 1, 0, 6 / 100 }, pieces[1].texCoord, "its top: 6 px of the (fake) 100 px high art")
			assert.equals(6, pieces[1].size[2], "6 px high, whatever the field's height")
			assert.equals(200, pieces[1].size[1], "its own width (the fake atlas is 200 wide: clamped to the field)")
		end)

		it("wear the theme's input art (Blizzard's search border) around the box", function()
			local input = UI.Input({ width = 200, placeholder = "Search" })
			local look
			for _, f in ipairs(frames) do
				if f.parent == input.frame then
					look = f
				end
			end
			assert.is_truthy(look, "the dress's look, on the box")
			local atlases, seen = {}, {}
			for _, t in ipairs(look.textures) do
				if t.shown and t.atlas and not seen[t.atlas] then
					seen[t.atlas] = true
					atlases[#atlases + 1] = t.atlas
				end
			end
			assert.same({ "common-search-border-left", "common-search-border-middle", "common-search-border-right" },
				atlases)
			assert.is_true(look.shown, "shown")
		end)

		it("tell listeners what the player typed, not what code set", function()
			local seen = {}
			local input = UI.Input({ width = 180, on = { change = function(self, text)
				seen[#seen + 1] = { self, text }
			end } })
			local box = editBox()
			assert.equals(box, input.frame)
			assert.is_false(box.autoFocus)
			assert.equals(180, box.size[1])
			box:Type("lin")
			input:SetText("")
			assert.same({ { input, "lin" } }, seen)
			assert.equals("", input:GetText())
		end)

		it("show the placeholder only while empty and not being typed in", function()
			local input = UI.Input({ placeholder = "Search" })
			local box = input.frame
			assert.equals("Search", input.placeholder.text)
			assert.is_true(input.placeholder.shown)
			box.focus = true
			box.scripts.OnEditFocusGained(box)
			assert.is_false(input.placeholder.shown)
			box:Type("x")
			box:ClearFocus()
			assert.is_false(input.placeholder.shown, "it has text")
			input:SetText("")
			assert.is_true(input.placeholder.shown)
		end)

		it("give up the keyboard on Escape, then tell listeners; Enter too", function()
			local heard = {}
			local input = UI.Input({})
			input:On("escape", function()
				heard[#heard + 1] = "escape"
			end)
			input:On("enter", function()
				heard[#heard + 1] = "enter"
			end)
			local box = input.frame
			box.focus = true
			box.scripts.OnEscapePressed(box)
			assert.is_false(box.focus)
			box.scripts.OnEnterPressed(box)
			assert.same({ "escape", "enter" }, heard)
			assert.has_error(function()
				input:On("click", function() end)
			end)
		end)
	end)

	describe("panels", function()
		local function screen(w, h)
			_G.UIParent:SetSize(w, h)
		end

		it("keep the panel's look when the owner puts in a new block", function()
			screen(1920, 1080)
			local panel = UI.Panel({ { text = "Gold" } })
			panel.block = { { text = "Gold" } } -- a layout change built a new table without a style
			panel:Place()
			assert.equals("panel", panel.block.style)
		end)

		it("tell others how much of their edge they cover, and announce a change", function()
			screen(1920, 1080)
			local heard = 0
			_G.EventRegistry:RegisterCallback("OrdaenUI.InsetsChanged", function()
				heard = heard + 1
			end, {})
			assert.equals(0, UI.ScreenInset("bottom"))
			local panel = UI.Panel({ { text = "Gold" } }, { offset = 2 })
			local height = panel.frame.size[2]
			assert.is_true(height > 0)
			assert.equals(height + 2, UI.ScreenInset("bottom"))
			assert.equals(0, UI.ScreenInset("top"))
			assert.equals(1, heard)
			panel.panel.edge = "top"
			panel:Place()
			assert.equals(0, UI.ScreenInset("bottom"), "moved to the top: the bottom is free again")
			assert.equals(height + 2, UI.ScreenInset("top"))
			assert.equals(2, heard)
		end)

		it("follow a panel that grows after it was placed (its content filled in, then :Refresh())", function()
			screen(1920, 1080)
			local panel = UI.Panel({ { text = "Gold" } })
			local before = UI.ScreenInset("bottom")
			panel.block[2] = { text = "Silver" } -- a second row
			panel:Refresh()
			assert.is_true(UI.ScreenInset("bottom") > before)
		end)

		it("tell listeners when they're drawn, with their size (\"render\")", function()
			local block = UI.Block({ { text = "Gold" } })
			local seen
			block:On("render", function(self, width, height)
				seen = { self, width, height }
			end)
			block:Refresh()
			assert.equals(block, seen[1])
			assert.same({ block.frame:GetWidth(), block.frame:GetHeight() }, { seen[2], seen[3] })
			assert.is_false(block.frame.mouse or false, "a framework event doesn't make the frame take the mouse")
		end)

		it("stretch along the bottom edge by default, re-placed when the screen changes", function()
			screen(1920, 1080)
			local panel = UI.Panel({ { text = "Gold" } })
			local f = panel.frame
			assert.same({ "BOTTOM", _G.UIParent, "BOTTOM", 0, 0 }, f.point)
			assert.equals(1920, f.size[1])
			screen(2560, 1440)
			for _, fr in ipairs(frames) do
				if fr.events and fr.events.DISPLAY_SIZE_CHANGED and fr.scripts.OnEvent then
					fr.scripts.OnEvent(fr, "DISPLAY_SIZE_CHANGED")
				end
			end
			assert.equals(2560, f.size[1])
		end)

		it("stand along the left or right edge full height, or fit their content in the middle", function()
			screen(1920, 1080)
			local left = UI.Panel({ { text = "Gold" } }, { edge = "left", offset = 4 })
			assert.same({ "LEFT", _G.UIParent, "LEFT", 4, 0 }, left.frame.point)
			assert.equals(1080, left.frame.size[2])
			local fit = UI.Panel({ { text = "Gold" } }, { edge = "top", fit = "center" })
			assert.same({ "TOP", _G.UIParent, "TOP", 0, 0 }, fit.frame.point)
			assert.is_true(fit.frame.size[1] < 1920, "as wide as its content")
		end)

		it("fade with the theme's time and take no clicks while faded", function()
			screen(1920, 1080)
			local panel = UI.Panel({ { text = "Gold" } })
			panel:FadeTo(0)
			local group = panel.frame.group
			assert.same({ 1, 0, 0.15, 1 }, { group.from, group.to, group.duration, group.played })
			assert.is_false(panel.frame.clicksEnabled)
			assert.is_true(panel:IsFaded())
			panel:FadeTo(1, 0)
			assert.equals(1, panel.frame.alpha)
			assert.is_true(panel.frame.clicksEnabled)
			assert.is_false(panel:IsFaded())
		end)
	end)

	describe("dressing Blizzard's buttons", function()
		-- A Blizzard button the way modern clients build it: art on the frame, the clicks on a `.Button` child.
		local function blizzardButton()
			local holder = fakeFrame("HolderFrame", log, _G.UIParent)
			local frame = fakeFrame("BlizzardButton", log, holder)
			frame:SetSize(32, 40)
			frame:SetFrameLevel(5)
			local art = frame:CreateTexture(nil, "ARTWORK")
			art:SetAlpha(0.8)
			frame.Button = fakeFrame(nil, log, frame)
			local glow = frame.Button:CreateTexture(nil, "OVERLAY")
			return frame, art, glow, holder
		end

		it("hides Blizzard's art and puts our look under its frame, which keeps the clicks", function()
			local frame, art, glow, holder = blizzardButton()
			local dress = UI.Dress(frame, { atlas = "UI-HUD-MicroMenu-Guild-Up" })
			local look = dress.look.frame
			assert.same({ 0, 0 }, { art.alpha, glow.alpha })
			assert.equals(holder, look.parent, "a sibling of Blizzard's frame, so it never covers it")
			assert.same({ "CENTER", frame, "CENTER" }, look.point)
			assert.is_true(look:GetFrameLevel() < frame:GetFrameLevel())
			assert.same({ look:GetWidth(), look:GetHeight() }, frame.size)
			assert.same({ "ALL", frame }, frame.Button.point, "the clickable child covers the dressed frame")
			assert.is_false(look.mouse, "ours takes no mouse")
		end)

		it("highlights our look while Blizzard's button is hovered", function()
			local frame = blizzardButton()
			local dress = UI.Dress(frame, { icon = 136243 })
			frame.Button.scripts.OnEnter(frame.Button)
			assert.is_true(dress.look.frame.highlightLocked)
			frame.Button.scripts.OnLeave(frame.Button)
			assert.is_false(dress.look.frame.highlightLocked)
		end)

		it("gives the art and size back on :Undress, and dresses the same frame only once", function()
			local frame, art, glow = blizzardButton()
			local dress = UI.Dress(frame, { icon = 136243 })
			dress:Undress()
			assert.same({ 0.8, 1 }, { art.alpha, glow.alpha })
			assert.same({ 32, 40 }, frame.size)
			assert.is_false(dress.look.frame.shown)
			frame.Button.scripts.OnEnter(frame.Button)
			assert.is_falsy(dress.look.frame.highlightLocked, "an undressed button doesn't light ours")
			assert.equals(dress, UI.Dress(frame), "dressed again: the same object")
			assert.same({ 0, 0 }, { art.alpha, glow.alpha })
		end)

		it("hides only art, never text, and keeps it hidden when Blizzard fades it back in", function()
			local frame, art = blizzardButton()
			local label = frame:CreateFontString()
			UI.Dress(frame, { icon = 136243 })
			assert.is_nil(label.alpha, "a button's text (its count, a tab's name) stays")
			art:SetAlpha(0.6) -- Blizzard fading its art in (a chat background on hover)
			assert.equals(0, art.alpha)
		end)

		-- A chat window: its background reaches past the frame, its message lines are children (content).
		local function chatWindow()
			local holder = fakeFrame("UIParentLike", log, _G.UIParent)
			local window = fakeFrame("ChatFrameLike", log, holder)
			window:SetSize(400, 180)
			local background = window:CreateTexture(nil, "BACKGROUND")
			local border = window:CreateTexture(nil, "BORDER")
			local lines = fakeFrame(nil, log, window)
			local line = lines:CreateTexture(nil, "ARTWORK") -- an icon inside a message line
			return window, background, border, line
		end

		it("report a dress that fails and return nothing, so the caller's other dresses go on", function()
			local window = chatWindow()
			function window:GetRegions()
				error("a frame Blizzard broke")
			end
			assert.is_nil(UI.Dress(window, { style = "panel", size = "frame" }))
			assert.equals(1, #helpers.forwarded, "reported to the error handler (BugSack)")
			assert.is_truthy(tostring(helpers.forwarded[1]):find("a frame Blizzard broke", 1, true))
			assert.is_truthy(UI.Dress(chatWindow(), { style = "panel", size = "frame", art = {} }), "the next one works")
		end)

		it("hide art Blizzard re-created with :Restrip, without drawing again", function()
			local window, background = chatWindow()
			local dress = UI.Dress(window, { style = "panel", size = "frame" })
			assert.equals(0, background.alpha)
			local glow = window:CreateTexture(nil, "ARTWORK") -- Blizzard added art after we dressed it
			local drawn = dress.look.frame.size
			dress:Restrip()
			assert.equals(0, glow.alpha)
			assert.equals(drawn, dress.look.frame.size, "not drawn again")
		end)

		it("cover a frame at its own size with size = \"frame\", hiding only the art listed", function()
			local window, background, border, line = chatWindow()
			local dress = UI.Dress(window, { style = "panel", size = "frame", cover = background,
				art = { background, border } })
			assert.same({ 400, 180 }, window.size, "Blizzard's (Edit Mode's) size stays")
			assert.same({ "ALL", background }, dress.look.frame.point)
			assert.same({ 0, 0 }, { background.alpha, border.alpha })
			assert.is_nil(line.alpha, "a message line's icon isn't art")
			assert.is_nil(dress.icon, "no icon in a window")
			dress:Undress()
			assert.same({ 1, 1 }, { background.alpha, border.alpha })
			assert.same({ 400, 180 }, window.size)
		end)

		it("put a window's border above Blizzard's frame and its children with borderAbove, the fill under", function()
			local window = chatWindow()
			window.strata = "HIGH"
			window:SetFrameLevel(10)
			local dress = UI.Dress(window, { style = "window", size = "frame", art = {}, borderAbove = true })
			local look = dress.look.frame
			local overlay = look.children[#look.children]
			assert.equals("ButtonFrameTemplateNoPortrait", overlay.layout)
			assert.is_nil(rawget(look, "layout"), "no border under the window")
			assert.same({ "ALL", look }, overlay.point)
			assert.equals("HIGH", overlay.strata)
			assert.equals(510, overlay.level, "500 above the window, as Blizzard's templates put their NineSlice")
			assert.is_false(overlay.mouse)
			local fill
			for _, t in ipairs(look.textures) do
				fill = fill or (t.atlas == "UI-Character-Info-General-BG" and t)
			end
			assert.is_truthy(fill, "the fill stays on the look, under the window")
		end)

		it("put the border at the level of the window's own NineSlice, above every content child", function()
			local window = chatWindow()
			window:SetFrameLevel(2)
			rawset(window, "NineSlice", { GetFrameLevel = function()
				return 501
			end })
			local dress = UI.Dress(window, { style = "portraitWindow", size = "frame", art = {}, borderAbove = true })
			local look = dress.look.frame
			assert.equals(501, look.children[#look.children].level)
		end)

		it("stay shown when dressed on a closed frame with size = \"frame\" (its parent decides)", function()
			local window, background = chatWindow()
			window:Hide() -- Ordaen Reskin dresses windows at login, while they're closed
			local dress = UI.Dress(window, { style = "window", size = "frame", cover = background, art = {} })
			assert.is_true(dress.look.frame.shown, "shown as a child: it appears when the window opens")
		end)

		it("draw on the frame with size = \"frame\": a child at its level, so it shows, hides, fades with it", function()
			local window, background = chatWindow()
			window:Show()
			window.strata = "HIGH"
			local dress = UI.Dress(window, { style = "panel", size = "frame", cover = background, art = { background } })
			local look = dress.look.frame
			assert.equals(window, look.parent, "on the frame, not beside it")
			assert.is_true(look.usingParentLevel, "its regions interleave with the frame's by layer")
			assert.is_nil(rawget(look, "level"), "no level of its own")
			assert.equals("MEDIUM", look.strata, "no strata copied: the parent's applies")
			window:Hide()
			window:SetAlpha(0.2)
			assert.is_true(look.shown, "hidden and faded through its parent, nothing set on it")
			assert.is_nil(rawget(look, "alpha"))
		end)

				it("show only while being typed in with `focus`, at full alpha (an input over the chat)", function()
			local input = chatWindow()
			input:Show()
			local focused = false
			input.HasFocus = function()
				return focused
			end
			input.IsObjectType = function(_, kind)
				return kind == "EditBox" or kind == "Frame"
			end
			input:SetAlpha(0.35) -- Blizzard's IM style leaves an inactive input faintly shown
			local dress = UI.Dress(input, { style = "input", size = "frame", art = {}, focus = true })
			assert.is_false(dress.look.frame.shown, "not typing: nothing of ours shows")
			focused = true
			input.scripts.OnEditFocusGained(input)
			assert.is_true(dress.look.frame.shown)
			assert.equals(1, dress.look.frame:GetAlpha(), "solid while typing")
			focused = false
			input.scripts.OnEditFocusLost(input)
			assert.is_false(dress.look.frame.shown)
		end)

		it("dress a frame whose size is secret (a damage meter bar) without measuring it", function()
			local bar = chatWindow()
			bar:Show()
			local dress = UI.Dress(bar, { style = "panel", size = "frame", art = {} })
			local look = dress.look.frame
			local drawn = look.size
			look.GetWidth = function()
				return SECRET -- sized from combat numbers
			end
			look.GetHeight = function()
				return SECRET
			end
			dress:Apply() -- before: "attempt to compare a secret value"
			look.scripts.OnSizeChanged(look)
			assert.same(drawn, look.size, "not drawn again for a size it can't read")
			assert.is_true(look.shown, "still covering the frame")
		end)

				it("reach past the covered region with `extend` (an input with buttons on its left)", function()
			local window = chatWindow()
			local dress = UI.Dress(window, { style = "panel", size = "frame", extend = { 60, 0, 2, 2 }, art = {} })
			local look = dress.look.frame
			assert.same({ "BOTTOMRIGHT", window, "BOTTOMRIGHT", 0, -2 }, look.point)
		end)

		it("reach past it by spacing tokens, following the text size (a chat window's padding)", function()
			local window = chatWindow()
			local dress = UI.Dress(window, { style = "panel", size = "frame", extend = { "md", 0, "xs", "sm" }, art = {} })
			local look = dress.look.frame
			assert.same({ "BOTTOMRIGHT", window, "BOTTOMRIGHT", 0, -4 }, look.point, "sm: 4 at the default text size")
			rawset(_G, "OrdaenCoreDB", { ui = { textSize = 16 } })
			UI._SettingsChanged()
			assert.is_true(-look.point[5] > 4, "a bigger text size: more room")
		end)

		it("mark a control as new with the theme's gem at its left end, and take it off again", function()
			local button = chatWindow()
			button:SetSize(120, 26)
			local dress = UI.Dress(button, { style = "pushButton", size = "frame", art = {} })
			local function gem()
				for _, t in ipairs(dress.look.frame.textures) do
					if t.file and tostring(t.file):find("new%-gem") then
						return t
					end
				end
			end
			assert.is_nil(gem())
			dress:SetNew(true)
			local g = gem()
			assert.is_truthy(g, "the theme's marker (control.newMarker)")
			assert.equals("LEFT", g.point[1])
			assert.equals(4, g.point[4], "the asset's inset from the left")
			assert.is_true(g.shown)
			dress:SetNew(false)
			assert.is_false(g.shown)
		end)

		it("place a window's title inside its top, with the engraved rule under it", function()
			local window = chatWindow()
			window:SetSize(300, 200)
			local title = window:CreateFontString()
			title:SetPoint("CENTER", window, "TOP", 0, 10) -- on Blizzard's title plate
			UI.Dress(window, { style = "dialog", size = "frame", art = {}, title = title })
			assert.same({ "TOP", window, "TOP", 0, -14 }, title.point, "inside the top")
			assert.same({ 1, 0.82, 0 }, { title.color[1], title.color[2], title.color[3] }, "in gold")
			title:SetPoint("CENTER", window, "TOP", 0, 10) -- Blizzard's layout again
			assert.same({ "TOP", window, "TOP", 0, -14 }, title.point, "back inside")
		end)

		it("switch a dressed control's style with :SetStyle, keeping its state", function()
			local button = chatWindow()
			local dress = UI.Dress(button, { style = "pushButton", size = "frame", art = {} })
			dress:SetState("pushed")
			dress:SetStyle("pushButtonAccent")
			assert.equals("pushButtonAccent", dress.look.block.style)
			assert.equals("pushed", dress.look.block.controlState)
		end)

		it("switch the style with :SetState (a selected or flashing tab)", function()
			local window = chatWindow()
			local dress = UI.Dress(window, { style = "tab", size = "frame", art = {},
				states = { selected = "tabSelected", flash = "tabFlash" } })
			dress:SetState("selected")
			assert.equals("tabSelected", dress.look.block.style)
			dress:SetState("flash")
			assert.equals("tabFlash", dress.look.block.style)
			dress:SetState(nil)
			assert.equals("tab", dress.look.block.style)
		end)

		-- A Blizzard push button or checkbox: enabled state, button state, checked state, as the game keeps them.
		local function blizzardControl()
			local b = chatWindow()
			local enabled, state, checked = true, "NORMAL", false
			function b:IsEnabled()
				return enabled
			end
			function b:Enable()
				enabled = true
			end
			function b:Disable()
				enabled = false
			end
			function b:SetEnabled(on)
				enabled = on and true or false
			end
			function b:GetButtonState()
				return state
			end
			function b:SetButtonState(s)
				state = s
			end
			function b:SetChecked(on)
				checked = on and true or false
			end
			function b:GetChecked()
				return checked
			end
			return b
		end

		it("track a button's own state: disabled, pushed while held, back to normal", function()
			local b = blizzardControl()
			local dress = UI.Dress(b, { style = "pushButton", size = "frame", art = {}, track = "button",
				states = { pushed = "pushButtonPushed", disabled = "pushButtonDisabled" } })
			assert.equals("pushButton", dress.look.block.style)
			b.scripts.OnMouseDown(b)
			assert.equals("pushButtonPushed", dress.look.block.style)
			b.scripts.OnMouseUp(b)
			assert.equals("pushButton", dress.look.block.style)
			b.scripts.OnMouseDown(b)
			b.scripts.OnHide(b) -- its window closed mid-press
			assert.is_nil(dress.state, "not left pushed")
			b:Disable()
			assert.equals("pushButtonDisabled", dress.look.block.style)
			b:Enable()
			b:SetButtonState("PUSHED")
			assert.equals("pushButtonPushed", dress.look.block.style)
		end)

		it("track a checkbox's checked state", function()
			local b = blizzardControl()
			local dress = UI.Dress(b, { style = "checkbox", size = "frame", art = {}, track = "checkbox",
				states = { checked = "checkboxChecked" } })
			b:SetChecked(true)
			assert.equals("checkboxChecked", dress.look.block.style)
			b:SetChecked(false)
			assert.equals("checkbox", dress.look.block.style)
		end)

		it("track a panel tab selected by Blizzard (PanelTemplates), also one selected before dressing", function()
			rawset(_G, "PanelTemplates_SelectTab", function(tab)
				tab:Disable()
			end)
			rawset(_G, "PanelTemplates_DeselectTab", function(tab)
				tab:Enable()
			end)
			local first, second = blizzardControl(), blizzardControl()
			first:Disable() -- Blizzard's selected tab is disabled
			local a = UI.Dress(first, { style = "tab", size = "frame", art = {}, track = "tab",
				states = { selected = "tabSelected" } })
			local b = UI.Dress(second, { style = "tab", size = "frame", art = {}, track = "tab",
				states = { selected = "tabSelected" } })
			assert.equals("tabSelected", a.look.block.style)
			assert.equals("tab", b.look.block.style)
			_G.PanelTemplates_DeselectTab(first)
			_G.PanelTemplates_SelectTab(second)
			assert.same({ "tab", "tabSelected" }, { a.look.block.style, b.look.block.style })
			rawset(_G, "PanelTemplates_SelectTab", nil)
			rawset(_G, "PanelTemplates_DeselectTab", nil)
		end)

		-- A Blizzard StatusBar (a damage meter's bar) with its own texture: only methods the dump lists.
		local function blizzardBar()
			local bar = fakeFrame("MeterBar", log, _G.UIParent)
			local texture = fakeTexture("ARTWORK")
			texture:SetTexture("Interface\\Blizzard\\MeterBar")
			function texture:GetTexture()
				return self.file
			end
			function bar:GetStatusBarTexture()
				return texture
			end
			bar.barTexture = texture.file
			return bar
		end

		it("puts the theme's bar texture on Blizzard's bars with UI.DressBar and keeps it there", function()
			local bar = blizzardBar()
			local dress = UI.DressBar(bar)
			assert.equals("Interface\\Buttons\\WHITE8X8", bar.barTexture) -- bar.texture "flat"
			bar:SetStatusBarTexture("Interface\\Blizzard\\Thin") -- Blizzard's style change
			assert.equals("Interface\\Buttons\\WHITE8X8", bar.barTexture)
			dress:SetAsset("blizzard") -- the addon's setting
			assert.equals("Interface\\TargetingFrame\\UI-StatusBar", bar.barTexture)
			assert.equals(dress, UI.DressBar(bar, "flat"), "once per bar")
			dress:Undress()
			assert.equals("Interface\\Blizzard\\MeterBar", bar.barTexture)
			bar:SetStatusBarTexture("Interface\\Blizzard\\Thin")
			assert.equals("Interface\\Blizzard\\Thin", bar.barTexture, "undressed: Blizzard's again")
		end)

		it("put the theme's font on Blizzard's text and keep it there with UI.DressFont", function()
			local frame = fakeFrame("Tab", log, _G.UIParent)
			local label = frame:CreateFontString()
			label:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
			UI.DressFont(label, "label")
			local file, size, flags = label:GetFont()
			assert.is_not.equals("Fonts\\FRIZQT__.TTF", file)
			assert.equals("OUTLINE", flags, "Blizzard's flags stay")
			label:SetFont("Fonts\\FRIZQT__.TTF", 20, "OUTLINE") -- the chat font size menu
			assert.equals(file, (label:GetFont()))
			assert.equals(size, select(2, label:GetFont()))
			-- A bigger global text size: re-applied with the theme.
			rawset(_G, "OrdaenCoreDB", { ui = { textSize = 16 } })
			UI._SettingsChanged()
			assert.is_true(select(2, label:GetFont()) > size)
		end)

		it("outlines text on a coloured bar (the onBar styles), without a drop shadow", function()
			local frame = fakeFrame("Bar", log, _G.UIParent)
			local name = frame:CreateFontString()
			name:SetFont("Fonts\\ARIALN.TTF", 12, "")
			UI.DressFont(name, "onBar")
			assert.equals("OUTLINE", select(3, name:GetFont()))
			assert.same({ 0, 0 }, name.shadow, "the outline does the shadow's work")
			name:SetFont("Fonts\\ARIALN.TTF", 14, "") -- Blizzard sets it again (text scale)
			assert.equals("OUTLINE", select(3, name:GetFont()), "kept")
		end)

		it("hides art Blizzard adds later on :Refresh, and changes the icon", function()
			local frame = blizzardButton()
			local dress = UI.Dress(frame, { icon = 136243 })
			local badge = frame:CreateTexture(nil, "OVERLAY")
			dress:Refresh()
			assert.equals(0, badge.alpha)
			dress:SetIcon(nil, "UI-HUD-MicroMenu-Guild-Up")
			local atlas
			for _, t in ipairs(dress.look.frame.textures) do
				atlas = atlas or t.atlas
			end
			assert.equals("UI-HUD-MicroMenu-Guild-Up", atlas)
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

		-- Vertical edge lines (1 px wide, taller than wide) drawn on `frame`, by their x.
		local function verticalEdges(frame)
			local xs = {}
			for _, t in ipairs(solids(frame, "BORDER")) do
				local w, h = t.size[1], t.size[2]
				if w <= 1 and h > 1 then
					xs[#xs + 1] = t.point[4]
				end
			end
			table.sort(xs)
			return xs
		end

		it("collapse the borders of touching blocks: one line between neighbours, none over the parent's", function()
			local cell = function()
				return { style = "iconButton", width = 20, height = 20 }
			end
			local row = UI.Block({ style = "panel", columns = { "auto", "auto", "auto" }, gap = 0, padding = 0,
				cell(), cell(), cell() })
			-- The panel's left and right edges, then one shared line between each pair of cells: x 0, 20, 40, 59.
			local xs = verticalEdges(row.frame)
			assert.equals(4, #xs, "not 2 + 2 per cell")
			assert.equals(0, xs[1])
			assert.equals(20 - 1, xs[2], "the first cell's right edge, shared with the second")
			assert.equals(40 - 1, xs[3])
		end)

		it("keep both borders when blocks don't touch (a gap)", function()
			local cell = function()
				return { style = "iconButton", width = 20, height = 20 }
			end
			local row = UI.Block({ style = "panel", columns = { "auto", "auto" }, gap = 4, padding = 4, cell(), cell() })
			assert.equals(2 + 2, #verticalEdges(row.frame), "each cell's own two (the panel wears Blizzard's art)")
		end)

		it("light a cell on request (highlight), under its content", function()
			local lit = { style = "iconButton", width = 20, height = 20, highlight = true }
			local row = UI.Block({ style = "panel", columns = { "auto" }, gap = 0, padding = 0, lit })
			local found = false
			for _, t in ipairs(solids(row.frame, "ARTWORK")) do
				found = found or (t.size[1] == 20 and t.size[2] == 20)
			end
			assert.is_true(found)
			local x, y, w, h = row:RectOf(lit)
			assert.same({ 0, 0, 20, 20 }, { x, y, w, h })
		end)

		it("scale every text size and spacing step with the global text size", function()
			rawset(_G, "OrdaenCoreDB", { ui = { theme = "ordaen", textSize = 16 } })
			UI.Tooltip({ { text = "Goldshire" }, { text = "Stormwind", style = "title" } }):Show(owner)
			local s = surface()
			assert.equals(16, fontOf(s, "Goldshire").fontSize)
			assert.equals(23, fontOf(s, "Stormwind").fontSize) -- title tier: 16 x 1.42
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
			assert.same({ "Stormwind" }, shownTexts(s))
			rawset(_G, "OrdaenCoreDB", { ui = { theme = "ordaen", textSize = 14 } })
			UI._SettingsChanged()
			assert.same({ "Stormwind" }, shownTexts(s))
			assert.equals(13, fontOf(label.frame, "Goldshire").fontSize) -- small tier of 14
			rawset(_G, "OrdaenCoreDB", { ui = { theme = "ordaen", textSize = 12 } })
			UI._SettingsChanged()
			assert.equals(11, fontOf(label.frame, "Goldshire").fontSize) -- small tier of 12 again
		end)

		it("tint the window art with the block's own accent only (quality), as Blizzard does", function()
			local tip = UI.Tooltip({ { text = "Hogger" } })
			tip:Show(owner)
			local s = surface()
			assert.equals("ButtonFrameTemplateNoPortrait", s.layout, "small surfaces: the approved window metal")
			assert.equals(0.5, s.TopEdge.scale, "small surfaces: the border at half size")
			assert.same({ 1, 1, 1 }, s.TopEdge.vertexColor)
			tip.accent = { 1, 0, 0 }
			tip:Refresh()
			assert.same({ 1, 0, 0 }, s.TopEdge.vertexColor)
		end)

		it("draw edges and lines in whole physical pixels at any UI scale", function()
			uiScale = 0.5 -- one physical pixel is 2 UI units here (the fake pixel factor is 1)
			UI.Tooltip({ { text = "Goldshire" }, { separator = "rule" } }):Show(owner)
			local s = surface()
			local rule = solids(s, "ARTWORK")[1]
			assert.equals(2, rule.size[2]) -- 1 px
		end)

		it("write capitals in Russian too", function()
			UI.Tooltip({ { text = "Элвиннский лес, ёлка", style = "caption" } }):Show(owner) -- captions keep capitals
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
			-- two caption lines, the bar's bronze bezel (four sides, then a dark line inside: four more), its recessed
			-- track and the shadow under the track's top; the fill is a status bar
			assert.equals(12, #lines)
			local track = lines[11].size[1]
			assert.is_true(track < inner and track > inner - 10, "the track sits inside the bezel")
			local value = barsOf(s)[3]
			assert.same({ 0, 1 }, value.range)
			assert.equals(0.25, value.value)
			assert.equals(track, value.size[1], "the parts fill the track")
		end)

		it("draw a unit's portrait as an image", function()
			local drawn
			rawset(_G, "SetPortraitTexture", function(texture, unit)
				drawn = { texture, unit }
			end)
			UI.Tooltip({ { portrait = "player", size = 30 } }):Show(owner)
			rawset(_G, "SetPortraitTexture", nil)
			assert.is_table(drawn, "a portrait-only element is an image (it was laid out as an empty block)")
			assert.equals("player", drawn[2])
			assert.same({ 30, 30 }, { drawn[1].size and drawn[1].size[1], drawn[1].size and drawn[1].size[2] })
		end)

		it("let a block drop or keep each of its style's edges", function()
			local both = { style = "iconButton", width = 20, height = 20 }
			local second = { style = "iconButton", width = 20, height = 20 }
			local tip = UI.Tooltip({ columns = { "auto", "auto" }, gap = 8, both, second })
			tip:Show(owner)
			local full = #solids(surface(), "BORDER")
			second.edges = { top = false, bottom = false } -- only its left and right
			tip:Refresh()
			assert.equals(full - 2, #solids(surface(), "BORDER"))
			second.edges = { top = false, right = false, bottom = false, left = false }
			tip:Refresh()
			assert.equals(full - 4, #solids(surface(), "BORDER"), "none at all")
		end)

		it("draw a bar's quest and dimmed overlay parts behind its value, colours from theme tokens", function()
			UI.Tooltip({
				{ bar = 3000, min = 0, max = 10000, quest = 4500, overlay = 6500, color = "color.xp",
					overlayColor = "color.rested", text = "42%" },
			}):Show(owner)
			local bars = barsOf(surface())
			local overlay, quest, value = bars[1], bars[2], bars[3]
			assert.same({ 3000, 4500, 6500 }, { value.value, quest.value, overlay.value })
			assert.same({ 0.58, 0.12, 0.66, 1 }, value.barColor) -- color.xp of the ordaen theme
			assert.same({ 0.58, 0.12, 0.66, 0.7 }, quest.barColor) -- the value's colour, lighter
			assert.same({ 0.1, 0.42, 0.9, 0.5 }, overlay.barColor) -- color.rested, fainter (the theme's bar.ahead)
			assert.equals("Interface\\Buttons\\WHITE8X8", value.barTexture) -- bar.texture "flat"
			assert.same({ "42%" }, shownTexts(value))
		end)

		it("build a bar into the panel as a groove when the player picks it, with engraved sections and a scrim", function()
			rawset(_G, "OrdaenCoreDB", { ui = { barFrame = "groove" } })
			UI._SettingsChanged()
			UI.Tooltip({ { bar = 0.5, sections = 4, text = "50%" } }):Show(owner)
			local s = surface()
			-- the groove (shadow above in two lines, left, lip below, right side), the recessed track, its shadow
			assert.equals(7, #solids(s, "ARTWORK"))
			local value = barsOf(s)[3]
			local made = value.textures
			local ticks, glints, scrims = 0, 0, 0
			for _, t in ipairs(made) do
				if t.shown ~= false and t.sublevel == 7 then
					local c = t.vertexColor
					if c and c[1] == 0 then
						ticks = ticks + 1
					elseif c then
						glints = glints + 1
					end
				elseif t.sublevel == 6 and t.shown ~= false then
					scrims = scrims + 1
				end
			end
			assert.same({ 3, 3 }, { ticks, glints }, "each section line engraved: a dark line, a light one beside")
			assert.equals(2, scrims, "the scrim's two halves under the label")
			rawset(_G, "OrdaenCoreDB", nil)
			UI._SettingsChanged()
		end)

		it("animate a bar's changes: glide, flash the gain, wrap around on a drop", function()
			rawset(_G, "Enum", { StatusBarInterpolation = { Immediate = 0, ExponentialEaseOut = 1 } })
			helpers.loadAddon("OrdaenCore/OrdaenCore_UI") -- read the enum again
			local timers = {}
			rawset(_G, "C_Timer", { After = function(_, fn)
				timers[#timers + 1] = fn
			end })
			local xp = { bar = 3000, min = 0, max = 10000, animate = true }
			local tip = UI.Tooltip({ xp })
			tip:Show(owner)
			local value = barsOf(surface())[3]
			assert.is_nil(value.interpolation, "the first draw sets it at once")
			xp.bar = 3500
			tip:Refresh()
			assert.equals(3500, value.value)
			assert.equals(1, value.interpolation)
			local flash = value.textures[1]
			assert.equals(1, flash.group.played)
			xp.bar = 200 -- a new level
			tip:Refresh()
			assert.equals(10000, value.value, "first runs to the end")
			timers[1]()
			assert.equals(200, value.value, "then from the bottom to the new value")
			rawset(_G, "Enum", nil)
			rawset(_G, "C_Timer", nil)
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

		it("make headers: icon left, title and subtitle beside it, on the tooltip's own background", function()
			-- (A header without an icon puts its title where the icon would be: the same x.)
			local header = UI.Header({ title = "Stormwind", subtitle = "Trade District", icon = 134400 })
			local tip = UI.Tooltip({ header, { text = "Goldshire" } })
			tip:Show(owner)
			local s = surface()
			assert.same({ "Stormwind", "Trade District", "Goldshire" }, shownTexts(s))
			assert.same({}, solids(s, "BACKGROUND"), "no band: the tooltip's one background behind the title too")
			-- Its content lines up with the text below (the band's bleed adds no margin of its own).
			local iconX, bodyX
			for _, t in ipairs(s.textures) do
				if t.file == 134400 and t.shown then
					iconX = t.point[4]
				end
			end
			for _, fs in ipairs(s.fonts) do
				if fs.shown and fs.text == "Goldshire" then
					bodyX = fs.point[4]
				end
			end
			assert.equals(bodyX, iconX)
			header.titleText.text = "Elwynn"
			tip:Refresh()
			assert.same({ "Elwynn", "Trade District", "Goldshire" }, shownTexts(s))
		end)
	end)

	it("says which style roles the theme has, for addons that dress Blizzard's controls", function()
		assert.is_true(UI.HasStyle("window"))
		assert.is_true(UI.HasStyle("inset"))
		assert.is_false(UI.HasStyle("noSuchRole"))
	end)

	describe("sections", function()
		it("stats fill columns in order, value over caption, the first without a line on its left", function()
			local stats = UI.Stats(4)
			stats:Add("8-25", "Range")
			stats:Add(15, nil, "%d sec")
			assert.equals(2, stats.shown)
			assert.same({ "1fr", "1fr" }, stats.columns)
			assert.same({ left = false }, stats[1].edges)
			assert.is_nil(stats[2].edges)
			assert.is_true(stats[3].hidden)
			assert.is_true(stats.captions[2].hidden, "no caption given")
			UI.Tooltip({ { text = "Charge", style = "title" }, stats }):Show(owner)
			local s = surface()
			assert.same({ "Charge", "8-25", "Range", "15 sec" }, shownTexts(s))
			stats:Clear()
			assert.is_true(stats.hidden)
			stats:Add(1)
			stats:Add(2)
			stats:Add(3)
			stats:Add(4)
			stats:Add(5)
			assert.equals(4, stats.shown, "past the last column: ignored")
		end)

		it("rows put a name on the left and its value on the right, a section gap above", function()
			local rows = UI.Rows(3)
			rows:Add("Strength", 120)
			rows:Add("Arms", "21/51")
			assert.equals("section", rows.style)
			UI.Tooltip({ { text = "Character", style = "title" }, rows }):Show(owner)
			assert.same({ "Character", "Strength", "120", "Arms", "21/51" }, shownTexts(surface()))
			rows:Clear()
			assert.is_true(rows[1].hidden and rows[2].hidden and rows.hidden)
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
