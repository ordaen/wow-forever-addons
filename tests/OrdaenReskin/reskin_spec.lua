-- Ordaen Reskin: Blizzard's windows and dialogs skinned in the theme's look as soon as they exist (at login, or when
-- Blizzard loads them), with their tabs, close button and every standard control inside (Kit.lua). Only frame and
-- control art is handed to UI.Dress; content, text and icons stay. A role the theme doesn't draw leaves its control
-- alone; each window skins in its own protected call; a setting turned off gives everything Blizzard's look back.
local helpers = require("tests.OrdaenCore.helpers")

-- A WoW object stand-in that records calls; unknown widget methods are no-ops (see helpers.isStubMethod).
local function stub(name, extra)
	local obj = { name = name, calls = {}, scripts = {}, shown = false, regions = {}, children = {}, kind = "Frame" }
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
	function obj:IsShown()
		return self.shown
	end
	function obj:IsForbidden()
		return false
	end
	function obj:GetObjectType()
		return self.kind
	end
	function obj:IsObjectType(kind)
		return self.kind == kind
	end
	for _, slot in ipairs({ "Normal", "Pushed", "Disabled", "Highlight", "Checked", "DisabledChecked" }) do
		obj["Get" .. slot .. "Texture"] = function(self)
			return rawget(self, slot .. "Tex")
		end
	end
	for k, v in pairs(extra or {}) do
		rawset(obj, k, v)
	end
	return obj
end

local function texture(name)
	return stub(name, { kind = "Texture" })
end

-- A button-like control of `kind` with the given texture parts and its four state textures.
local function control(name, kind, parts, extra)
	local c = stub(name, extra)
	c.kind = kind
	for _, part in ipairs(parts or {}) do
		rawset(c, part, texture(name .. "." .. part))
	end
	for _, slot in ipairs({ "Normal", "Pushed", "Disabled", "Highlight" }) do
		rawset(c, slot .. "Tex", texture(name .. "." .. slot))
	end
	return c
end

-- A window as Blizzard builds it: a NineSlice of border pieces (a portrait ring on PortraitFrameTemplate), the Bg
-- fill and the top streaks, and content of its own (a parchment page) that must stay.
local function window(name, portrait)
	local corner = texture(name .. ".TopLeftCorner")
	local atlas = portrait and "UI-Frame-PortraitMetal-CornerTopLeft" or "UI-Frame-Metal-CornerTopLeft"
	function corner:GetAtlas()
		return atlas
	end
	local nine = stub(name .. ".NineSlice", { TopLeftCorner = corner })
	nine.regions = { corner, texture(name .. ".TopEdge"), stub(name .. ".Text", { kind = "FontString" }) }
	local frame = stub(name, { NineSlice = nine, Bg = texture(name .. ".Bg"),
		TopTileStreaks = texture(name .. ".TopTileStreaks"), Page = texture(name .. ".Page") })
	frame.regions = { frame.Bg, frame.Page }
	return frame
end

-- A dialog (DialogBorderTemplate): its pieces sit in a Border frame.
local function dialog(name)
	local border = stub(name .. ".Border")
	border.regions = { texture(name .. ".Border.TopLeft"), texture(name .. ".Border.Top") }
	return stub(name, { Border = border, Bg = texture(name .. ".Bg") })
end

local function show(frame)
	frame.shown = true
	if frame.scripts.OnShow then
		frame.scripts.OnShow(frame)
	end
end

local function names(list)
	local out = {}
	for _, t in ipairs(list) do
		out[#out + 1] = t.name
	end
	table.sort(out)
	return out
end

describe("Ordaen Reskin", function()
	local ns, frames, dressed, windows, styles, errors

	local function fire(event, arg)
		frames[1].scripts.OnEvent(frames[1], event, arg)
	end

	-- The theme's dressing, recorded: which frame got which style, art and options; Apply/Undress switch it.
	local function fakeDressing(hasStyle)
		local UI = OrdaenCore.UI
		UI.Dress = function(frame, spec)
			assert.is_nil(dressed[frame], "a frame is dressed once")
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
		rawset(UI, "HasStyle", hasStyle and function(role)
			return styles[role] == true
		end or nil)
	end

	local function load(opts)
		opts = opts or {}
		helpers.stubGlobals({
			CreateFrame = function(_, name)
				local f = stub(name or "anon")
				table.insert(frames, f)
				return f
			end,
			CharacterFrame = windows.CharacterFrame,
			GameMenuFrame = windows.GameMenuFrame,
		})
		rawget(_G, "C_AddOns").LoadAddOn = function()
			error("the real UI framework must not load: the spec fakes its dressing")
		end
		rawset(_G, "OrdaenReskinDB", nil)
		helpers.loadCore()
		fakeDressing(opts.hasStyle ~= false)
		helpers.errorHandler = function(err)
			errors[#errors + 1] = tostring(err)
		end
		ns = {}
		helpers.loadAddon("OrdaenReskin", ns)
		fire("ADDON_LOADED", "OrdaenReskin")
		fire("PLAYER_LOGIN")
	end

	before_each(function()
		frames, dressed, errors = {}, {}, {}
		helpers.inCombat = false
		styles = { window = true, portraitWindow = true, dialog = true, inset = true, tab = true, sideTab = true,
			pushButton = true, closeButton = true, checkbox = true, dropdown = true, input = true, scrollTrack = true,
			scrollThumb = true, scrollStepper = true, slot = true }
		windows = { CharacterFrame = window("CharacterFrame", true), GameMenuFrame = dialog("GameMenuFrame") }
	end)

	after_each(function()
		for _, name in ipairs({ "PlayerSpellsFrame", "MailFrame", "WorldMapFrame", "WorldMapFrameBg",
			"CharacterFrameTab1", "CharacterFrameTab2", "CharacterFrameCloseButton", "StaticPopup1" }) do
			rawset(_G, name, nil)
		end
		helpers.inCombat = false
	end)

	it("skins every window at login, before it is shown (eager)", function()
		load()
		local dress = dressed[windows.CharacterFrame]
		assert.equals("portraitWindow", dress.spec.style, "it has a portrait ring")
		assert.equals("frame", dress.spec.size)
		assert.is_true(dress.spec.borderAbove, "our border goes above its content, as Blizzard's")
		assert.same({ "CharacterFrame.Bg", "CharacterFrame.TopEdge", "CharacterFrame.TopLeftCorner",
			"CharacterFrame.TopTileStreaks" }, names(dress.spec.art), "the parchment and text stay")
		assert.equals("dialog", dressed[windows.GameMenuFrame].spec.style)
		assert.same({ "GameMenuFrame.Bg", "GameMenuFrame.Border.Top", "GameMenuFrame.Border.TopLeft" },
			names(dressed[windows.GameMenuFrame].spec.art))
	end)

	it("skins a load-on-demand window when Blizzard loads it, in the plain window style without a portrait", function()
		load()
		local spellbook = window("PlayerSpellsFrame")
		rawset(_G, "PlayerSpellsFrame", spellbook)
		fire("ADDON_LOADED", "Blizzard_PlayerSpells")
		assert.equals("window", dressed[spellbook].spec.style)
	end)

	it("finds a border kept in a BorderFrame and a fill named only as a global (World Map), and skips its canvas",
		function()
			load()
			local canvas = stub("WorldMapFrame.ScrollContainer")
			canvas.children = { control("Pin", "Button", { "Left", "Middle", "Right" }) }
			local map = stub("WorldMapFrame", { BorderFrame = window("WorldMapFrame.BorderFrame"),
				ScrollContainer = canvas })
			map.children = { canvas }
			rawset(_G, "WorldMapFrame", map)
			rawset(_G, "WorldMapFrameBg", texture("WorldMapFrameBg"))
			fire("ADDON_LOADED", "Blizzard_WorldMap")
			assert.same({ "WorldMapFrame.BorderFrame.Bg", "WorldMapFrame.BorderFrame.TopEdge",
				"WorldMapFrame.BorderFrame.TopLeftCorner", "WorldMapFrame.BorderFrame.TopTileStreaks",
				"WorldMapFrameBg" }, names(dressed[map].spec.art))
			assert.is_nil(dressed[canvas.children[1]], "the map's canvas isn't scanned")
		end)

	it("dresses side tabs by their global names and edge tabs from frame.Tabs, following the selected tab", function()
		local tab1 = control("CharacterFrameTab1", "Button", { "Left", "Middle", "Right", "LeftActive" })
		rawset(_G, "CharacterFrameTab1", tab1)
		rawset(_G, "CharacterFrameTab2", control("CharacterFrameTab2", "Button", { "Left" }))
		load()
		local dress = dressed[tab1]
		assert.equals("sideTab", dress.spec.style)
		assert.equals("tab", dress.spec.track)
		assert.same({ selected = "sideTabSelected" }, dress.spec.states)
		assert.same({ "CharacterFrameTab1.Disabled", "CharacterFrameTab1.Highlight", "CharacterFrameTab1.Left",
			"CharacterFrameTab1.LeftActive", "CharacterFrameTab1.Middle", "CharacterFrameTab1.Normal",
			"CharacterFrameTab1.Pushed", "CharacterFrameTab1.Right" }, names(dress.spec.art))
		local mailTab = control("MailFrameTab1", "Button", { "Left" })
		local mail = window("MailFrame", true)
		rawset(mail, "Tabs", { mailTab })
		rawset(_G, "MailFrame", mail)
		fire("ADDON_LOADED", "Blizzard_MailFrame")
		assert.equals("tab", dressed[mailTab].spec.style)
		assert.same({ selected = "tabSelected" }, dressed[mailTab].spec.states)
	end)

	it("dresses the close button, and every standard control inside the window, but not list rows or content",
		function()
			local close = control("CharacterFrameCloseButton", "Button")
			rawset(_G, "CharacterFrameCloseButton", close)
			local c = windows.CharacterFrame
			local button = control("Button", "Button", { "Left", "Middle", "Right" })
			local check = control("Check", "CheckButton")
			rawset(check, "CheckedTex", texture("Check.Checked"))
			local input = control("Input", "EditBox", { "Left", "Middle", "Right" })
			local dropdown = control("Dropdown", "Button", { "Background", "Arrow" }, { Text = stub("Dropdown.Text") })
			local slot = control("Slot", "ItemButton", { "IconBorder" }, { icon = texture("Slot.icon") })
			local track = stub("Bar.Track")
			track.regions = { texture("Bar.Track.Begin"), texture("Bar.Track.End") }
			local thumb = control("Bar.Thumb", "Button")
			local back = control("Bar.Back", "Button")
			local bar = stub("Bar", { Track = track, Thumb = thumb, Back = back })
			local row = control("Row", "Button") -- a list row: no template parts
			local inset = stub("Inset", { NineSlice = stub("Inset.NineSlice"), Bg = texture("Inset.Bg") })
			local nested = control("Nested", "Button", { "Left", "Middle", "Right" })
			inset.children = { nested }
			local pane = stub("Pane")
			pane.children = { button, check, input, dropdown, slot, bar, row }
			c.children = { pane, inset }
			load()
			assert.equals("closeButton", dressed[close].spec.style)
			assert.same({ pushed = "pushButtonPushed", disabled = "pushButtonDisabled" }, dressed[button].spec.states)
			assert.equals("button", dressed[button].spec.track)
			assert.equals("checkbox", dressed[check].spec.style)
			assert.equals("checkbox", dressed[check].spec.track)
			assert.truthy(names(dressed[check].spec.art)[1], "its tick goes too: the theme draws the checked state")
			assert.equals("input", dressed[input].spec.style)
			assert.equals("dropdown", dressed[dropdown].spec.style)
			assert.equals("slot", dressed[slot].spec.style)
			assert.same({ "Slot.IconBorder", "Slot.Normal", "Slot.Pushed" }, names(dressed[slot].spec.art),
				"the icon stays")
			assert.equals("scrollTrack", dressed[track].spec.style)
			assert.equals("scrollThumb", dressed[thumb].spec.style)
			assert.equals("scrollStepper", dressed[back].spec.style)
			assert.is_nil(dressed[row], "a list row isn't a control")
			assert.equals("inset", dressed[inset].spec.style)
			assert.equals("pushButton", dressed[nested].spec.style, "controls inside an inset too")
			assert.is_nil(dressed[pane], "a plain frame holding controls isn't dressed itself")
		end)

	it("leaves a control alone while the theme has no role for it", function()
		styles.checkbox = nil
		local check = control("Check", "CheckButton")
		windows.CharacterFrame.children = { check }
		load()
		assert.is_nil(dressed[check])
		assert.truthy(dressed[windows.CharacterFrame])
	end)

	it("without UI.HasStyle dresses only the window roles every theme has", function()
		local button = control("Button", "Button", { "Left", "Middle", "Right" })
		windows.CharacterFrame.children = { button }
		load({ hasStyle = false })
		assert.truthy(dressed[windows.CharacterFrame])
		assert.is_nil(dressed[button])
	end)

	it("dresses controls Blizzard made since when the window shows again, each once", function()
		load()
		local later = control("Later", "Button", { "Left", "Middle", "Right" })
		windows.CharacterFrame.children = { later }
		show(windows.CharacterFrame)
		assert.equals("pushButton", dressed[later].spec.style)
		show(windows.CharacterFrame) -- a second show: no second dress (fakeDressing asserts it)
	end)

	it("gives Blizzard's look back to a window and its controls when its setting is off, and dresses them again",
		function()
			local button = control("Button", "Button", { "Left", "Middle", "Right" })
			windows.CharacterFrame.children = { button }
			load()
			ns.Addon:Set("windows", false)
			assert.is_false(dressed[windows.CharacterFrame].on)
			assert.is_false(dressed[button].on)
			assert.is_true(dressed[windows.GameMenuFrame].on, "dialogs have their own setting")
			ns.Addon:Set("windows", true)
			assert.is_true(dressed[windows.CharacterFrame].on)
			assert.is_true(dressed[button].on)
		end)

	it("leaves windows alone while their setting is off", function()
		load()
		ns.Addon:Set("dialogs", false)
		local popup = dialog("StaticPopup1")
		rawset(_G, "StaticPopup1", popup)
		fire("ADDON_LOADED", "SomeAddon")
		assert.is_nil(dressed[popup])
	end)

	it("skins each window in its own call: one failing is reported and the others still skin", function()
		function windows.CharacterFrame:GetChildren()
			error("broken window")
		end
		load()
		assert.truthy(dressed[windows.GameMenuFrame])
		assert.equals(1, #errors)
		assert.truthy(errors[1]:find("broken window", 1, true))
	end)

	it("waits for the end of combat to skin a window Blizzard loads in combat", function()
		load()
		helpers.inCombat = true
		local spellbook = window("PlayerSpellsFrame")
		rawset(_G, "PlayerSpellsFrame", spellbook)
		fire("ADDON_LOADED", "Blizzard_PlayerSpells")
		assert.is_nil(dressed[spellbook])
		helpers.inCombat = false
		fire("PLAYER_REGEN_ENABLED")
		assert.truthy(dressed[spellbook])
	end)
end)
