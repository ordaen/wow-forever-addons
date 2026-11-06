-- Ordaen Tooltips: the native GameTooltip stays shown and keeps its content; we read it, draw ours in its place and
-- make it invisible. Anything secret stays native.
local helpers = require("tests.OrdaenCore.helpers")

-- A WoW object stand-in that records calls; methods return these defaults (what the UI renderer measures with).
local DEFAULTS = { GetUnboundedStringWidth = 40, GetStringHeight = 12, GetEffectiveScale = 1, SetFont = true,
	GetFrameLevel = 3 }
local function stub(name, extra)
	local obj = { name = name, calls = {}, scripts = {}, shown = false }
	setmetatable(obj, { __index = function(self, method)
		if not helpers.isStubMethod(method) then
			return nil
		end
		local fn = function(_, ...)
			self.calls[method] = self.calls[method] or {}
			table.insert(self.calls[method], { ... })
			return DEFAULTS[method]
		end
		rawset(self, method, fn)
		return fn
	end })
	function obj:Show()
		local was = self.shown
		self.shown = true
		if not was and self.scripts.OnShow then
			self.scripts.OnShow(self)
		end
	end
	function obj:Hide()
		local was = self.shown
		self.shown = false
		if was and self.scripts.OnHide then
			self.scripts.OnHide(self)
		end
	end
	function obj:IsShown()
		return self.shown
	end
	function obj:SetScript(script, fn)
		self.scripts[script] = fn
	end
	function obj:HookScript(script, fn)
		local before = self.scripts[script]
		self.scripts[script] = before and function(...)
			before(...)
			fn(...)
		end or fn
	end
	function obj:GetName()
		return self.name
	end
	function obj:SetAlpha(a)
		self.alpha = a
	end
	function obj:CreateFontString()
		return stub(name .. ".font")
	end
	function obj:CreateTexture()
		return stub(name .. ".texture")
	end
	for k, v in pairs(extra or {}) do
		rawset(obj, k, v)
	end
	return obj
end

-- A font string of the native tooltip: text, colour, shown.
local function line(text, r, g, b)
	return stub("line", {
		GetText = function()
			return text
		end,
		GetTextColor = function()
			return r or 1, g or 1, b or 1
		end,
		IsShown = function()
			return text ~= nil
		end,
	})
end

describe("Ordaen Tooltips", function()
	local ns, frames, secrets, tooltip, left, right

	local function frameNamed(name)
		for _, f in ipairs(frames) do
			if f.name == name then
				return f
			end
		end
	end

	local function fire(event, arg)
		frames[1].scripts.OnEvent(frames[1], event, arg)
	end

	before_each(function()
		frames, secrets = {}, {}
		left, right = {}, {}
		tooltip = stub("GameTooltip", {
			NumLines = function()
				return #left
			end,
			GetLeftLine = function(_, i)
				return left[i]
			end,
			GetRightLine = function(_, i)
				return right[i]
			end,
			GetPoint = function()
				return "BOTTOMRIGHT", nil, "BOTTOMRIGHT", -20, 20
			end,
			IsForbidden = function()
				return false
			end,
		})
		helpers.stubGlobals({
			CreateFrame = function(_, name)
				local f = stub(name or "anon")
				f.shown = true
				table.insert(frames, f)
				return f
			end,
			hooksecurefunc = function(obj, method, fn)
				local original = obj[method]
				obj[method] = function(...)
					local r = original and original(...)
					fn(...)
					return r
				end
			end,
			C_Timer = { After = function() end },
			GameTooltip = tooltip,
			GameTooltipStatusBar = stub("GameTooltipStatusBar"),
			issecretvalue = function(v)
				return secrets[v] == true
			end,
		})
		rawget(_G, "C_AddOns").LoadAddOn = function(name)
			assert.equals("OrdaenCore_UI", name)
			helpers.loadAddon("OrdaenCore/OrdaenCore_UI")
			return true
		end
		helpers.loadCore()
		ns = {}
		helpers.loadAddon("OrdaenTooltips", ns)
		fire("ADDON_LOADED", "OrdaenTooltips")
		fire("PLAYER_LOGIN")
	end)

	local function show(lines)
		left, right = {}, {}
		for i, l in ipairs(lines) do
			left[i] = line(l[1], l[3], l[4], l[5])
			right[i] = line(l[2])
		end
		tooltip:Show()
	end

	it("draws the native tooltip's lines in our view and makes the native one invisible", function()
		show({ { "Thunderfury", nil, 1, 0.5, 0 }, { "Binds when picked up" }, { "One-Hand", "Sword" } })
		local view = frameNamed("OrdaenTooltipsGameTooltip")
		assert.is_true(view.shown)
		assert.equals(0, tooltip.alpha)
		local described = ns.Takeover.Describe().GameTooltip
		assert.equals(3, described.rows)
		-- The view sits on the native tooltip's own corner, so it grows the same way.
		assert.same({ "BOTTOMRIGHT", tooltip, "BOTTOMRIGHT" }, view.calls.SetPoint[#view.calls.SetPoint])
	end)

	it("hides ours with the native one", function()
		show({ { "Hogger" } })
		tooltip:Hide()
		assert.is_false(frameNamed("OrdaenTooltipsGameTooltip").shown)
	end)

	it("passes Blizzard's fades to our view and keeps the native one at 0", function()
		show({ { "Hogger" } })
		tooltip:SetAlpha(0.4)
		assert.equals(0, tooltip.alpha)
		assert.equals(0.4, frameNamed("OrdaenTooltipsGameTooltip").alpha)
	end)

	it("leaves a tooltip with secret values native", function()
		local text = "Hogger"
		secrets[text] = true
		show({ { text } })
		assert.is_false(frameNamed("OrdaenTooltipsGameTooltip").shown)
		assert.equals(1, tooltip.alpha)
	end)
end)
