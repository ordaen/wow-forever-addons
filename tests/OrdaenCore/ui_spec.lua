-- OrdaenCore.UI: the always-loaded entry point (addons/OrdaenCore/UI.lua) and the load-on-demand framework
-- (addons/OrdaenCore/OrdaenCore_UI/), driven with fake frames whose font strings measure like the layout spec's.
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

local function fakeFrame(name, log, parent)
	local f = { name = name, shown = true, fonts = {}, scripts = {}, parent = parent or false }
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
	return setmetatable(f, { __index = function()
		return function() end
	end })
end

describe("OrdaenCore.UI", function()
	local UI, chat, frames, log, loads, loadResult

	local function shownTexts(surface)
		local out = {}
		for _, fs in ipairs(surface.fonts) do
			if fs.shown then
				out[#out + 1] = fs.text
			end
		end
		return out
	end

	local function surface()
		for _, f in ipairs(frames) do
			if f.name == "OrdaenUITooltip" then
				return f
			end
		end
	end

	before_each(function()
		chat, frames, log, loads, loadResult, uiScale = {}, {}, { setText = 0 }, 0, true, 1
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
		for _, font in ipairs({ "GameTooltipHeaderText", "GameTooltipText", "GameTooltipTextSmall", "GameFontNormal" }) do
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

	it("loads the framework only on the first tooltip, never for Hide or Refresh", function()
		UI.HideTooltip(owner)
		UI.RefreshTooltip(owner)
		assert.equals(0, loads)
		UI.ShowTooltip(owner, { style = "tooltip", { text = "Hello" } })
		UI.ShowTooltip(owner, { style = "tooltip", { text = "Again" } })
		assert.equals(1, loads)
	end)

	it("draws a tooltip block: theme fonts and colors, shrink-to-fit size with the theme's padding", function()
		local block = {
			style = "tooltip",
			{ text = "Elwynn Forest", style = "title" },
			{ text = "Click: world map", style = "hint" },
		}
		UI.ShowTooltip(owner, block, { side = "below" })
		local s = surface()
		assert.is_true(s.shown)
		assert.same({ "Elwynn Forest", "Click: world map" }, shownTexts(s))
		local visible = {}
		for _, fs in ipairs(s.fonts) do
			if fs.shown then
				visible[#visible + 1] = fs -- the surface also holds its hidden measuring font string
			end
		end
		local title, hint = visible[1], visible[2]
		assert.equals("GameTooltipHeaderText", title.font.fontName)
		assert.same({ 0.5, 0.5, 0.5 }, hint.color)
		-- widest line (16 chars, +1 px rounding margin) + 2 x padding 10; two lines + gap 2 + padding.
		assert.same({ 16 * CHAR + 1 + 20, LINE + 2 + LINE + 20 }, s.size)
		assert.same({ "TOP", owner, "BOTTOM", 0, -4 }, s.point)
		assert.equals("Interface\\Tooltips\\UI-Tooltip-Border", s.backdrop.edgeFile)
	end)

	it("redraws a shown tooltip after its block changed, hiding what is no longer drawn", function()
		local invites = { text = "You have invitations", hidden = true }
		local block = { style = "tooltip", invites, { text = "Click: calendar", style = "hint" } }
		UI.ShowTooltip(owner, block)
		local s = surface()
		assert.same({ "Click: calendar" }, shownTexts(s))
		invites.hidden = false
		UI.RefreshTooltip(owner)
		assert.same({ "You have invitations", "Click: calendar" }, shownTexts(s))
		invites.hidden = true
		UI.RefreshTooltip(owner)
		assert.same({ "Click: calendar" }, shownTexts(s))
	end)

	it("puts a tooltip anchored to nothing at Edit Mode's HUD Tooltip position", function()
		local container = { name = "GameTooltipDefaultContainer" }
		rawset(_G, "GameTooltipDefaultContainer", container)
		UI.ShowTooltip(owner, { style = "tooltip", { text = "Somewhere" } }, { side = "default" })
		assert.same({ "BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 0 }, surface().point)
		rawset(_G, "GameTooltipDefaultContainer", nil)
	end)

	it("hides only the owner's own tooltip", function()
		UI.ShowTooltip(owner, { style = "tooltip", { text = "Mine" } })
		UI.HideTooltip({ name = "someone else" })
		assert.is_true(surface().shown)
		UI.HideTooltip(owner)
		assert.is_false(surface().shown)
	end)

	it("wraps long text at the theme's maximum width instead of growing", function()
		local long = string.rep("word ", 20) -- 100 chars = 600 px
		UI.ShowTooltip(owner, { style = "tooltip", { text = long } })
		local s = surface()
		assert.equals(300, s.size[1])
		assert.is_true(s.size[2] > LINE + 20)
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
			UI.ShowTooltip(owner, {
				style = "tooltip",
				{ text = "Elwynn Forest", style = "title" },
				{ text = "Goldshire" },
				{ text = "Click: world map", style = "hint" },
			})
			assertNothingOverflows(surface())
		end)

		it("measures again when the UI scale changes", function()
			UI.ShowTooltip(owner, { style = "tooltip", { text = "Click: calendar" } })
			uiScale = 0.64
			UI.RefreshTooltip(owner)
			assertNothingOverflows(surface())
		end)
	end)

	it("measures text once and reuses it while the text doesn't change", function()
		local block = { style = "tooltip", { text = "Steady" } }
		UI.ShowTooltip(owner, block)
		local after = log.setText
		UI.RefreshTooltip(owner)
		-- Only the drawn font string gets its text again; the measurer is not asked.
		assert.equals(after + 1, log.setText)
	end)

	it("says once in chat when the framework can't load, and stays quiet afterwards", function()
		loadResult = false
		UI.ShowTooltip(owner, { style = "tooltip", { text = "x" } })
		UI.ShowTooltip(owner, { style = "tooltip", { text = "y" } })
		assert.equals(1, loads)
		assert.equals(1, #chat)
		assert.truthy(chat[1]:find("OrdaenCore_UI", 1, true))
		assert.truthy(chat[1]:find("DISABLED", 1, true))
	end)
end)
