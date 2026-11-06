-- Ordaen Meter: the game's damage meter (Blizzard_DamageMeter) dressed in place. Blizzard keeps drawing it; we only
-- post-hook its windows and bars and put the theme's panel, fonts and bar texture on them.
local helpers = require("tests.OrdaenCore.helpers")

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
		end
		rawset(self, method, fn)
		return fn
	end })
	function obj:SetScript(script, fn)
		self.scripts[script] = fn
	end
	function obj:GetRegions()
		return unpack(self.regions)
	end
	function obj:GetChildren()
		return unpack(self.children)
	end
	function obj:IsObjectType(kind)
		return self.kind == kind
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

-- A bar of the meter: a frame with a status bar, a name and a value.
local function entry(name)
	local statusBar = stub(name .. ".StatusBar", { kind = "StatusBar" })
	local bar = stub(name, { kind = "Frame", statusBar = statusBar })
	bar.children = { statusBar }
	statusBar.regions = { fontString(name .. ".Name"), fontString(name .. ".Value") }
	function bar:GetStatusBar()
		return self.statusBar
	end
	return bar
end

-- A session window: a background frame of textures, a header with a title, and its bars.
local function sessionWindow(name)
	local background = stub(name .. ".Background", { kind = "Frame" })
	background.regions = { texture(name .. ".Bg") }
	local header = stub(name .. ".Header", { kind = "Frame" })
	header.regions = { fontString(name .. ".Title"), texture(name .. ".HeaderArt") }
	local window = stub(name, { kind = "Frame", entries = {}, background = background, header = header })
	function window:GetBackground()
		return self.background
	end
	function window:GetHeader()
		return self.header
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
	local ns, frames, dressed, fonts, bars, meter

	local function fire(event, arg)
		frames[1].scripts.OnEvent(frames[1], event, arg)
	end

	-- The theme's dressing, recorded: which frames got the panel, which texts a font, which bars a texture.
	local function fakeDressing()
		local UI = OrdaenCore.UI
		UI.Dress = function(frame, spec)
			local dress = { frame = frame, spec = spec, on = true }
			function dress:Apply()
				self.on = true
			end
			function dress:Undress()
				self.on = false
			end
			dressed[frame] = dress
			return dress
		end
		UI.DressFont = function(text, style)
			fonts[text] = style
		end
		UI.DressBar = function(bar, asset)
			local dress = { bar = bar, asset = asset, on = true, applied = 1 }
			function dress:Apply()
				self.on = true
				self.applied = self.applied + 1
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
		})
		if not withMeter then
			rawset(_G, "DamageMeter", nil) -- not loaded yet
		end
		rawget(_G, "C_AddOns").LoadAddOn = function()
			error(debug.traceback("LoadAddOn"))
		end
		helpers.loadCore()
		fakeDressing()
		ns = {}
		helpers.loadAddon("OrdaenMeter", ns)
		fire("ADDON_LOADED", "OrdaenMeter")
		fire("PLAYER_LOGIN")
	end

	before_each(function()
		frames, dressed, fonts, bars = {}, {}, {}, {}
		rawset(_G, "OrdaenMeterDB", nil)
		meter = meterFrame()
	end)

	after_each(function()
		assert.same({}, helpers.forwarded) -- no error was caught and reported on the way
	end)

	it("dresses the windows and bars the meter already has at login", function()
		local window = sessionWindow("DamageMeterSessionWindow1")
		meter:SetupSessionWindow(window)
		local bar = entry("Bar1")
		window:InitEntry(bar)
		load(true)
		local dress = dressed[window]
		assert.truthy(dress)
		assert.equals("panel", dress.spec.style)
		assert.same({ window.background.regions[1] }, dress.spec.art, "Blizzard's background is the art we cover")
		assert.equals("label", fonts[window.header.regions[1]])
		assert.truthy(bars[bar.statusBar])
		assert.equals(ns.Addon:Get("barTexture"), bars[bar.statusBar].asset)
		assert.equals("body", fonts[bar.statusBar.regions[1]])
		assert.equals("body", fonts[bar.statusBar.regions[2]])
		local described = ns.Look.Describe()
		assert.same({ true, true, true, 1, 1 },
			{ described.on, described.meter, described.available, described.windows, described.bars })
	end)

	it("dresses each bar Blizzard shows later, once, through both hooks", function()
		local window = sessionWindow("DamageMeterSessionWindow1")
		meter:SetupSessionWindow(window)
		load(true)
		local bar = entry("Bar1")
		window:Show(bar) -- InitEntry and SetupEntry both run; dressing happens once (fakeDressing asserts it)
		window:SetupEntry(bar) -- reused from the pool
		assert.truthy(bars[bar.statusBar])
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
		ns.Addon:Set("meterLook", false)
		assert.is_false(dressed[window].on)
		assert.is_false(bars[bar.statusBar].on)
		local later = entry("Bar2")
		window:Show(later)
		assert.is_nil(bars[later.statusBar], "nothing is dressed while off")
		ns.Addon:Set("meterLook", true)
		assert.is_true(dressed[window].on)
		assert.is_true(bars[bar.statusBar].on)
		assert.truthy(bars[later.statusBar], "bars shown while off are dressed when it's back on")
	end)
end)
