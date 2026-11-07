-- Ordaen Reskin: Blizzard's windows and dialogs dressed in the theme's look on their first show. Only their frame art
-- (NineSlice, a dialog's Border, Bg, TopTileStreaks) is handed to UI.Dress; their content stays. Load-on-demand
-- windows are picked up when Blizzard loads them; a setting turned off gives the windows Blizzard's look back.
local helpers = require("tests.OrdaenCore.helpers")

-- A WoW object stand-in that records calls; unknown widget methods are no-ops (see helpers.isStubMethod).
local function stub(name, extra)
	local obj = { name = name, calls = {}, scripts = {}, shown = false, regions = {} }
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
	function obj:IsShown()
		return self.shown
	end
	function obj:IsObjectType(kind)
		return self.kind == kind
	end
	for k, v in pairs(extra or {}) do
		rawset(obj, k, v)
	end
	return obj
end

local function texture(name)
	return stub(name, { kind = "Texture" })
end

-- A window as Blizzard builds it (PortraitFrameTemplate): a NineSlice of border pieces, the Bg fill and the top
-- streaks, plus content of its own (a parchment page) that must stay.
local function window(name)
	local nine = stub(name .. ".NineSlice", { kind = "Frame" })
	nine.regions = { texture(name .. ".TopLeftCorner"), texture(name .. ".TopEdge"), stub(name .. ".Text",
		{ kind = "FontString" }) }
	local frame = stub(name, { kind = "Frame", NineSlice = nine, Bg = texture(name .. ".Bg"),
		TopTileStreaks = texture(name .. ".TopTileStreaks"), Page = texture(name .. ".Page") })
	frame.regions = { frame.Bg, frame.Page }
	return frame
end

-- A dialog (DialogBorderTemplate): its pieces sit in a Border frame.
local function dialog(name)
	local border = stub(name .. ".Border", { kind = "Frame" })
	border.regions = { texture(name .. ".Border.TopLeft"), texture(name .. ".Border.Top") }
	return stub(name, { kind = "Frame", Border = border, Bg = texture(name .. ".Bg") })
end

local function show(frame)
	frame.shown = true
	if frame.scripts.OnShow then
		frame.scripts.OnShow(frame)
	end
end

describe("Ordaen Reskin", function()
	local ns, frames, dressed, windows

	local function fire(event, arg)
		frames[1].scripts.OnEvent(frames[1], event, arg)
	end

	-- The theme's dressing, recorded: which frame got which style and art; Apply/Undress switch it on and off.
	local function fakeDressing()
		OrdaenCore.UI.Dress = function(frame, spec)
			assert.is_nil(dressed[frame], "a window is dressed once")
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
	end

	local function load()
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
		fakeDressing()
		ns = {}
		helpers.loadAddon("OrdaenReskin", ns)
		fire("ADDON_LOADED", "OrdaenReskin")
		fire("PLAYER_LOGIN")
	end

	local function art(frame)
		local names = {}
		for _, t in ipairs(dressed[frame].spec.art) do
			names[#names + 1] = t.name
		end
		table.sort(names)
		return names
	end

	before_each(function()
		frames, dressed = {}, {}
		windows = { CharacterFrame = window("CharacterFrame"), GameMenuFrame = dialog("GameMenuFrame") }
	end)

	after_each(function()
		rawset(_G, "PlayerSpellsFrame", nil)
	end)

	it("dresses nothing until a window is shown", function()
		load()
		assert.same({}, dressed)
	end)

	it("dresses a window on its first show, with its frame art only", function()
		load()
		show(windows.CharacterFrame)
		local dress = dressed[windows.CharacterFrame]
		assert.equals("window", dress.spec.style)
		assert.equals("frame", dress.spec.size)
		assert.same({ "CharacterFrame.Bg", "CharacterFrame.TopEdge", "CharacterFrame.TopLeftCorner",
			"CharacterFrame.TopTileStreaks" }, art(windows.CharacterFrame), "the parchment and text stay")
		show(windows.CharacterFrame) -- a second show: no second dress (fakeDressing asserts it)
	end)

	it("dresses a dialog in the dialog style, with its Border pieces", function()
		load()
		show(windows.GameMenuFrame)
		assert.equals("dialog", dressed[windows.GameMenuFrame].spec.style)
		assert.same({ "GameMenuFrame.Bg", "GameMenuFrame.Border.Top", "GameMenuFrame.Border.TopLeft" },
			art(windows.GameMenuFrame))
	end)

	it("finds the border of a window that keeps it in a BorderFrame, and a fill named only as a global", function()
		load()
		local map = stub("WorldMapFrame", { kind = "Frame", BorderFrame = window("WorldMapFrame.BorderFrame") })
		rawset(_G, "WorldMapFrame", map)
		rawset(_G, "WorldMapFrameBg", texture("WorldMapFrameBg"))
		fire("ADDON_LOADED", "Blizzard_WorldMap")
		show(map)
		assert.same({ "WorldMapFrame.BorderFrame.Bg", "WorldMapFrame.BorderFrame.TopEdge",
			"WorldMapFrame.BorderFrame.TopLeftCorner", "WorldMapFrame.BorderFrame.TopTileStreaks", "WorldMapFrameBg" },
			art(map))
		rawset(_G, "WorldMapFrame", nil)
		rawset(_G, "WorldMapFrameBg", nil)
	end)

	it("dresses a window that is already open when it starts", function()
		windows.CharacterFrame.shown = true
		load()
		assert.truthy(dressed[windows.CharacterFrame])
	end)

	it("picks up a load-on-demand window when Blizzard loads it", function()
		load()
		local spellbook = window("PlayerSpellsFrame")
		rawset(_G, "PlayerSpellsFrame", spellbook)
		fire("ADDON_LOADED", "Blizzard_PlayerSpells")
		show(spellbook)
		assert.equals("window", dressed[spellbook].spec.style)
	end)

	it("gives Blizzard's look back when its setting is turned off, and dresses again when it's on", function()
		load()
		show(windows.CharacterFrame)
		show(windows.GameMenuFrame)
		ns.Addon:Set("windows", false)
		assert.is_false(dressed[windows.CharacterFrame].on)
		assert.is_true(dressed[windows.GameMenuFrame].on, "dialogs have their own setting")
		ns.Addon:Set("windows", true)
		assert.is_true(dressed[windows.CharacterFrame].on)
	end)

	it("leaves windows alone while its setting is off", function()
		rawset(_G, "OrdaenReskinDB", nil)
		load()
		ns.Addon:Set("dialogs", false)
		show(windows.GameMenuFrame)
		assert.is_nil(dressed[windows.GameMenuFrame])
	end)
end)
