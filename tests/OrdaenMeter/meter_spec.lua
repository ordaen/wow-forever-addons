-- Ordaen Meter: the game's damage meter (Blizzard_DamageMeter) dressed in place. Blizzard keeps drawing it; we only
-- post-hook its windows and bars, draw the theme's header row and panel under them, put Blizzard's controls over
-- their cells, and give the bars the theme's texture and fonts.
local helpers = require("tests.OrdaenCore.helpers")

-- What the stand-ins' getters answer (the meter's header strip is 32 tall, as in Blizzard's XML).
local DEFAULTS = { GetNumPoints = 0, GetWidth = 100, GetHeight = 32, GetAlpha = 1 }

-- The arguments of the last SetAlpha call on a stand-in.
local function lastAlpha(obj)
	local calls = obj.calls.SetAlpha
	return calls and calls[#calls]
end

-- A WoW object stand-in that records calls; unknown widget methods are no-ops (see helpers.isStubMethod).
local function stub(name, extra)
	local obj = { name = name, calls = {}, scripts = {}, shown = true, regions = {}, children = {} }
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
	function obj:GetRegions()
		return unpack(self.regions)
	end
	function obj:GetChildren()
		return unpack(self.children)
	end
	function obj:IsObjectType(kind) -- a StatusBar or Button is a Frame too, as in WoW
		return self.kind == kind or (kind == "Frame" and (self.kind == "StatusBar" or self.kind == "Button"))
	end
	for k, v in pairs(extra or {}) do
		rawset(obj, k, v)
	end
	return obj
end

local function fontString(name)
	return stub(name, { kind = "FontString" })
end

local function texture(name)
	return stub(name, { kind = "Texture" })
end

-- A colour as Blizzard's ColorMixin: r, g, b and GetRGB.
local function blizzardColor(r, g, b)
	return { r = r, g = g, b = b, GetRGB = function(c)
		return c.r, c.g, c.b
	end }
end

-- Blizzard's class colours (RAID_CLASS_COLORS) for two classes, and the meter's own default colour.
local RAID = { ROGUE = blizzardColor(1, 0.96, 0.41), MAGE = blizzardColor(0.25, 0.78, 0.92) }
local METER_DEFAULT = blizzardColor(0.5, 0.5, 0.5)

-- A bar of the meter: a button with a status bar holding its name and value; Blizzard colours its fill with
-- entry:SetStatusBarColor(colour) (DamageMeterEntry.lua), a class's RAID_CLASS_COLORS object or its own.
local function entry(name, colour)
	local fill = texture(name .. ".Fill")
	local statusBar = stub(name .. ".StatusBar", { kind = "StatusBar", Name = fontString(name .. ".Name"),
		Value = fontString(name .. ".Value"), made = {} })
	function statusBar:CreateTexture(_, layer, _, sublevel)
		local t = texture(name .. ".Ours")
		t.layer, t.sublevel = layer, sublevel
		self.made[#self.made + 1] = t
		return t
	end
	local bar = stub(name, { kind = "Button", statusBar = statusBar, track = texture(name .. ".Background"),
		edge = texture(name .. ".BackgroundEdge"), fill = fill })
	function bar:GetStatusBar()
		return self.statusBar
	end
	function bar:GetStatusBarTexture()
		return self.fill
	end
	function bar:SetStatusBarColor(c)
		self.statusBarColor = c
		self.fill:SetVertexColor(c:GetRGB())
	end
	function bar:GetBackground()
		return self.track
	end
	function bar:GetBackgroundEdge()
		return self.edge
	end
	bar:SetStatusBarColor(colour or RAID.ROGUE)
	return bar
end

-- The last colour the fill was given, as { r, g, b }.
local function fillColour(bar)
	local calls = bar.fill.calls.SetVertexColor
	return calls[#calls]
end

-- A session window as on Forever (Blizzard's DamageMeterSessionWindow.xml): the header strip is a texture; the meter
-- type dropdown (its label TypeName), the session dropdown (its label), the settings dropdown and the minimize
-- button sit on it, with the session timer; the bars and the background are in a container that hides when the
-- window is minimized.
local function sessionWindow(name)
	local typeDropdown = stub(name .. ".DamageMeterTypeDropdown", { kind = "Button",
		TypeName = fontString(name .. ".TypeName") })
	local session = stub(name .. ".SessionDropdown", { kind = "Button", SessionName = fontString(name .. ".Session") })
	local window = stub(name, { kind = "Frame", entries = {}, minimized = false,
		header = texture(name .. ".Header"), typeDropdown = typeDropdown, session = session,
		settings = stub(name .. ".SettingsDropdown", { kind = "Button" }),
		minimize = stub(name .. ".MinimizeButton", { kind = "Button" }),
		container = stub(name .. ".MinimizeContainer", { kind = "Frame" }),
		background = texture(name .. ".Background"), timer = fontString(name .. ".SessionTimer"),
		notActive = fontString(name .. ".NotActive") })
	function window:GetHeader()
		return self.header
	end
	function window:GetDamageMeterTypeDropdown()
		return self.typeDropdown
	end
	function window:GetSessionDropdown()
		return self.session
	end
	function window:GetSessionName()
		return self.session.SessionName
	end
	function window:GetSettingsDropdown()
		return self.settings
	end
	function window:GetMinimizeButton()
		return self.minimize
	end
	function window:GetMinimizeContainer()
		return self.container
	end
	function window:GetBackground()
		return self.background
	end
	function window:GetSessionTimerFontString()
		return self.timer
	end
	function window:GetNotActiveFontString()
		return self.notActive
	end
	function window:IsMinimized()
		return self.minimized
	end
	function window:SetMinimized(minimized)
		self.minimized = minimized
	end
	function window:ForEachEntryFrame(fn)
		for _, bar in ipairs(self.entries) do
			fn(bar)
		end
	end
	-- Blizzard's scroll box shows a bar: InitEntry for a new one, SetupEntry for it and for a reused one.
	function window:InitEntry(bar)
		self.entries[#self.entries + 1] = bar
	end
	function window:SetupEntry() end
	function window:Show(bar)
		self:InitEntry(bar)
		self:SetupEntry(bar)
	end
	return window
end

local function meterFrame()
	local meter = stub("DamageMeter", { kind = "Frame", windows = {} })
	function meter:ForEachSessionWindow(fn)
		for _, window in ipairs(self.windows) do
			fn(window)
		end
	end
	function meter:SetupSessionWindow(window)
		self.windows[#self.windows + 1] = window
	end
	return meter
end

describe("Ordaen Meter", function()
	local ns, frames, dressed, fonts, outlines, bars, meter, Core

	local function fire(event, arg)
		frames[1].scripts.OnEvent(frames[1], event, arg)
	end

	-- The theme's dressing, recorded: which frames got a look (and with what), which texts a font, which bars a
	-- texture. A look draws its block's children side by side, 32 wide each, and tells its "render" listeners.
	local function fakeLook(spec)
		local look = { frame = stub("look"), listeners = {}, draws = 0 }
		function look:On(event, fn)
			assert.equals("render", event)
			self.listeners[#self.listeners + 1] = fn
		end
		function look:RectOf(element)
			for i, child in ipairs(spec.block or {}) do
				if child == element then
					return (i - 1) * 32, 0, 32, 32
				end
			end
		end
		function look:Draw()
			self.draws = self.draws + 1
			for _, fn in ipairs(self.listeners) do
				fn(self, 160, 32)
			end
		end
		return look
	end

	local function fakeDressing()
		local UI = OrdaenCore.UI
		UI.Dress = function(frame, spec)
			assert.is_nil(dressed[frame], "a frame is dressed once")
			local dress = { frame = frame, spec = spec, on = true, look = fakeLook(spec) }
			function dress:Apply()
				self.on = true
			end
			function dress:Undress()
				self.on = false
			end
			function dress:Refresh()
				self.look:Draw()
			end
			dressed[frame] = dress
			return dress
		end
		UI.DressFont = function(text, style, flags)
			fonts[text] = style
			outlines[text] = flags
		end
		UI.DressBar = function(bar, asset)
			local dress = { bar = bar, asset = asset, on = true }
			function dress:Apply()
				self.on = true
			end
			function dress:SetAsset(a)
				self.asset = a
			end
			function dress:Undress()
				self.on = false
			end
			assert.is_nil(bars[bar], "a bar is dressed once")
			bars[bar] = dress
			return dress
		end
	end

	local function load(withMeter)
		helpers.stubGlobals({
			CreateFrame = function(_, name)
				local f = stub(name or "anon")
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
			DamageMeter = withMeter and meter or false,
			C_DamageMeter = { IsDamageMeterAvailable = function()
				return true
			end },
			RAID_CLASS_COLORS = RAID,
		})
		if not withMeter then
			rawset(_G, "DamageMeter", nil) -- not loaded yet
		end
		rawget(_G, "C_AddOns").LoadAddOn = function()
			error("the real UI framework must not load: the spec fakes its dressing")
		end
		rawset(_G, "OrdaenCoreDB", nil)
		Core = helpers.loadCore()
		fire("ADDON_LOADED", "OrdaenCore") -- its settings: the palette (OrdaenCore.Colors)
		fakeDressing()
		ns = {}
		helpers.loadAddon("OrdaenMeter", ns)
		fire("ADDON_LOADED", "OrdaenMeter")
		fire("PLAYER_LOGIN")
	end

	-- The window's header row and its cells, as given to UI.Dress.
	local function header(window)
		local dress = dressed[window]
		return dress, dress.spec.block
	end

	-- The last SetPoint call on `frame`, or its last one for `point` ("LEFT").
	local function lastPoint(frame, point)
		local points = frame.calls.SetPoint or {}
		for i = #points, 1, -1 do
			if not point or points[i][1] == point then
				return points[i]
			end
		end
	end

	before_each(function()
		frames, dressed, fonts, outlines, bars = {}, {}, {}, {}, {}
		rawset(_G, "OrdaenMeterDB", nil)
		meter = meterFrame()
	end)

	after_each(function()
		assert.same({}, helpers.forwarded) -- no error was caught and reported on the way
	end)

	it("draws one header row over Blizzard's strip: dropdown, title, session, settings, minimize", function()
		local window = sessionWindow("DamageMeterSessionWindow1")
		meter:SetupSessionWindow(window)
		load(true)
		local dress, row = header(window)
		assert.equals("panel", dress.spec.style)
		assert.equals(window.header, dress.spec.cover)
		assert.same({ window.header }, dress.spec.art)
		assert.equals(5, #row)
		assert.same({ 0, 0 }, { row.gap, row.padding }, "touching cells share one line")
		for _, i in ipairs({ 1, 3, 4, 5 }) do
			local cell = row[i]
			assert.equals("iconButton", cell.style)
			assert.equals(32, cell.height, "as tall as the strip")
			assert.same({ top = false, bottom = false }, cell.edges, "the row's lines frame them")
		end
		assert.matches("icon%-dropdown$", row[1][1].image)
		assert.matches("icon%-settings$", row[4][1].image)
		assert.matches("icon%-minimize$", row[5][1].image)
		-- The body: the theme's panel under the bars, on the container that hides when minimized.
		local body = dressed[window.container]
		assert.equals("panel", body.spec.style)
		assert.same({ window.background }, body.spec.art)
		assert.same({ 0, 0, -32, 0 }, body.spec.extend, "below the header")
	end)

	it("puts Blizzard's controls over their cells, art hidden, and the texts in the title area", function()
		local window = sessionWindow("DamageMeterSessionWindow1")
		meter:SetupSessionWindow(window)
		load(true)
		local dress = header(window)
		local look = dress.look
		local controls = { window.typeDropdown, window.session, window.settings, window.minimize }
		local columns = { 0, 64, 96, 128 } -- cells 1, 3, 4, 5 of the fake look
		for i, control in ipairs(controls) do
			assert.equals("none", dressed[control].spec.style, "its art hidden, nothing drawn")
			assert.same({ "TOPLEFT", look.frame, "TOPLEFT", columns[i], 0 }, lastPoint(control))
			assert.same({ 32, 32 }, control.calls.SetSize[#control.calls.SetSize])
		end
		local typeName = window.typeDropdown.TypeName
		assert.same({ "LEFT", look.frame, "TOPLEFT", 32 + 6, -16 }, lastPoint(typeName, "LEFT"))
		assert.same({ "RIGHT", window.timer, "LEFT", -6, 0 }, lastPoint(typeName, "RIGHT"), "up to the timer")
		assert.same({ "RIGHT", look.frame, "TOPLEFT", 64 - 6, -16 }, lastPoint(window.timer))
		assert.equals("label", fonts[window.typeDropdown.TypeName])
		assert.equals("label", fonts[window.timer])
		assert.equals("label", fonts[window.session.SessionName])
		assert.equals("body", fonts[window.notActive])
	end)

	it("lights a control's cell while Blizzard's button is hovered", function()
		local window = sessionWindow("DamageMeterSessionWindow1")
		meter:SetupSessionWindow(window)
		load(true)
		local _, row = header(window)
		window.settings.scripts.OnEnter(window.settings)
		assert.is_true(row[4].highlight)
		assert.is_falsy(row[5].highlight)
		window.settings.scripts.OnLeave(window.settings)
		assert.is_false(row[4].highlight)
	end)

	it("follows minimizing: the expand glyph, and the header closes its bottom line", function()
		local window = sessionWindow("DamageMeterSessionWindow1")
		meter:SetupSessionWindow(window)
		load(true)
		local _, row = header(window)
		assert.is_false(row.edges.bottom, "the body's top line is the separator")
		window:SetMinimized(true)
		assert.matches("icon%-expand$", row[5][1].image)
		assert.is_true(row.edges.bottom)
		window:SetMinimized(false)
		assert.matches("icon%-minimize$", row[5][1].image)
		assert.is_false(row.edges.bottom)
	end)

	it("gives the bars the theme's texture and fonts, the windows' bars at login and each one shown later", function()
		local window = sessionWindow("DamageMeterSessionWindow1")
		meter:SetupSessionWindow(window)
		local first = entry("Bar1")
		window:InitEntry(first)
		load(true)
		assert.equals(ns.Addon:Get("barTexture"), bars[first.statusBar].asset)
		assert.equals("body", fonts[first.statusBar.Name])
		assert.equals("value", fonts[first.statusBar.Value])
		assert.is_nil(dressed[first.statusBar], "never measured: a bar's size is secret in combat")
		for _, art in ipairs({ first.track, first.edge }) do
			assert.same({ 0 }, lastAlpha(art), "Blizzard's track and shadow edge hidden")
			art:SetAlpha(0.6) -- the meter's background transparency
			assert.same({ 0 }, lastAlpha(art), "and kept hidden")
		end
		local later = entry("Bar2")
		window:Show(later) -- InitEntry and SetupEntry both run; dressing happens once (fakeDressing asserts it)
		window:SetupEntry(later) -- reused from the pool
		assert.truthy(bars[later.statusBar])
		local described = ns.Look.Describe()
		assert.same({ true, true, true, 1, 2 },
			{ described.on, described.meter, described.available, described.windows, described.bars })
	end)

	it("paints a class's bar in its palette colour, now and when Blizzard colours it again", function()
		local window = sessionWindow("DamageMeterSessionWindow1")
		meter:SetupSessionWindow(window)
		local rogue = entry("Bar1", RAID.ROGUE)
		window:InitEntry(rogue)
		load(true)
		local Colors = Core.Colors
		assert.same({ Colors:Class("ROGUE"):GetRGB() }, fillColour(rogue), "the palette's yellow, not Blizzard's")
		rogue:SetStatusBarColor(RAID.MAGE) -- the bar is reused for a mage
		assert.same({ Colors:Get("cyan"):GetRGB() }, fillColour(rogue))
		rogue:SetStatusBarColor(METER_DEFAULT) -- a creature: the meter's own colour stays
		assert.same({ 0.5, 0.5, 0.5 }, fillColour(rogue))
	end)

	it("repaints when the player picks another colour in Ordaen Core's settings", function()
		local window = sessionWindow("DamageMeterSessionWindow1")
		meter:SetupSessionWindow(window)
		local mage = entry("Bar1", RAID.MAGE)
		window:InitEntry(mage)
		load(true)
		local A
		for _, addon in ipairs(Core._addons) do
			A = addon.name == "OrdaenCore" and addon or A
		end
		A:Set("palette.cyan", { 0.1, 0.5, 0.6 })
		assert.same({ 0.1, 0.5, 0.6 }, fillColour(mage))
		A:Set("class.MAGE", "violet")
		assert.same({ Core.Colors:Get("violet"):GetRGB() }, fillColour(mage))
	end)

	it("outlines the bar's texts and puts a scrim under them, made from the bar's own points", function()
		local window = sessionWindow("DamageMeterSessionWindow1")
		meter:SetupSessionWindow(window)
		local bar = entry("Bar1")
		window:InitEntry(bar)
		load(true)
		assert.equals("OUTLINE", outlines[bar.statusBar.Name])
		assert.equals("OUTLINE", outlines[bar.statusBar.Value])
		local left, right = bar.statusBar.made[1], bar.statusBar.made[2]
		assert.same({ "ARTWORK", 7 }, { left.layer, left.sublevel }, "over the fill, under the texts")
		assert.same({ "BOTTOMRIGHT", bar.statusBar, "BOTTOM" }, left.calls.SetPoint[2], "to the middle")
		assert.same({ "TOPLEFT", bar.statusBar, "TOP" }, right.calls.SetPoint[1])
		assert.equals("HORIZONTAL", left.calls.SetGradient[1][1])
		assert.is_nil(bar.statusBar.calls.GetWidth, "the bar's size (secret in combat) is never read")
	end)

	it("dresses a window the meter adds later", function()
		load(true)
		local window = sessionWindow("DamageMeterSessionWindow2")
		meter:SetupSessionWindow(window)
		assert.truthy(dressed[window])
		local bar = entry("Bar1")
		window:Show(bar)
		assert.truthy(bars[bar.statusBar])
	end)

	it("starts when Blizzard_DamageMeter loads after us", function()
		load(false)
		assert.is_false(ns.Look.Describe().meter)
		local window = sessionWindow("DamageMeterSessionWindow1")
		meter:SetupSessionWindow(window)
		rawset(_G, "DamageMeter", meter)
		fire("ADDON_LOADED", "Blizzard_DamageMeter")
		assert.truthy(dressed[window])
		local bar = entry("Bar1")
		window:Show(bar)
		assert.truthy(bars[bar.statusBar])
	end)

	it("gives Blizzard's look back when turned off, and the theme's when turned on again", function()
		local window = sessionWindow("DamageMeterSessionWindow1")
		meter:SetupSessionWindow(window)
		local bar = entry("Bar1")
		window:InitEntry(bar)
		load(true)
		local placed = #window.settings.calls.SetPoint
		ns.Addon:Set("meterLook", false)
		for _, frame in ipairs({ window, window.container, window.settings }) do
			assert.is_false(dressed[frame].on)
		end
		assert.is_false(bars[bar.statusBar].on)
		assert.same({ 1 }, lastAlpha(bar.track), "Blizzard's track back, at its own alpha")
		assert.same({ 1 }, lastAlpha(bar.edge))
		assert.same({ RAID.ROGUE:GetRGB() }, fillColour(bar), "Blizzard's class colour back")
		local scrim = bar.statusBar.made[1].calls.SetShown
		assert.same({ false }, scrim[#scrim], "no scrim")
		assert.equals(1, #window.settings.calls.ClearAllPoints - placed, "back where Blizzard put it")
		local later = entry("Bar2")
		window:Show(later)
		assert.is_nil(bars[later.statusBar], "nothing is dressed while off")
		ns.Addon:Set("meterLook", true)
		assert.is_true(dressed[window].on)
		assert.is_true(dressed[window.settings].on)
		assert.is_true(bars[bar.statusBar].on)
		assert.truthy(bars[later.statusBar], "bars shown while off are dressed when it's back on")
	end)
end)
