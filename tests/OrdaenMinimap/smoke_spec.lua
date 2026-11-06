-- Loads the whole addon (Core + OrdaenMinimap, in TOC order) against stubbed WoW objects and runs
-- the login path, the settings page and the slash command. Catches typos and wrong call order
-- in the WoW-facing files; how things look is still checked in game.
local helpers = require("tests.OrdaenCore.helpers")

-- A stand-in for any WoW frame/texture/object: records calls, returns sensible defaults.
local function stubObject(name, extra)
	local obj = { name = name, calls = {}, scripts = {}, shown = true }
	local defaults = {
		GetZoom = 2,
		GetZoomLevels = 6,
		GetFrameLevel = 3,
		GetID = 42,
		GetData = {},
	}
	setmetatable(obj, {
		__index = function(self, method)
			local fn = function(_, ...)
				self.calls[method] = self.calls[method] or {}
				table.insert(self.calls[method], { ... })
				return defaults[method]
			end
			rawset(self, method, fn)
			return fn
		end,
	})
	obj.Hide = function(self)
		self.shown = false
	end
	obj.Show = function(self)
		self.shown = true
	end
	obj.SetScript = function(self, script, fn)
		self.scripts[script] = fn
	end
	obj.SetParent = function(self, parent)
		self.calls.SetParent = self.calls.SetParent or {}
		table.insert(self.calls.SetParent, { parent })
		self.parent = parent
	end
	obj.GetParent = function(self)
		return self.parent
	end
	obj.GetScript = function(self, script)
		return self.scripts[script]
	end
	obj.HookScript = function(self, script, fn)
		local before = self.scripts[script]
		self.scripts[script] = before and function(...)
			before(...)
			fn(...)
		end or fn
	end
	obj.SetText = function(self, text)
		self.text = text
	end
	obj.IsShown = function(self)
		return self.shown
	end
	obj.CreateTexture = function(self)
		self.texture = stubObject(name .. ".texture") -- the last one created, for assertions
		return self.texture
	end
	obj.CreateFontString = function(self, fontName)
		self.font = stubObject(fontName or (name .. ".font"))
		return self.font
	end
	for k, v in pairs(extra or {}) do
		rawset(obj, k, v)
	end
	return obj
end

local function loadToc(addon, ns)
	helpers.loadAddon(addon, ns)
end

describe("OrdaenMinimap smoke", function()
	local ns, frames, hooks, chat, settings, opened, world

	local BLIZZARD_STACK = "Interface/AddOns/Blizzard_Minimap/Minimap.lua:120: in function <...>"

	before_each(function()
		frames, hooks, chat, settings, opened = {}, {}, {}, {}, nil
		-- What the fake client reports; tests change these to simulate other addons.
		world = {
			loaded = {},
			stack = BLIZZARD_STACK,
			taint = { true, nil }, -- issecurevariable("GetMinimapShape")
			secure = {}, -- issecurevariable(_G, name) for frame names
			popups = {},
			timers = {},
			disabled = {},
			addonList = {}, -- C_AddOns.GetAddOnInfo(i)
			children = {}, -- Minimap:GetChildren()
			icons = {}, -- LibDBIcon buttons by name
			iconOrder = {},
			runtimeEntries = {}, -- AddonCompartmentFrame.registeredAddons
			-- UnitPosition: world X (north), Y (west). The stub map spans X 1000..600, Y 2000..1200,
			-- so (800, 1800) is map (0.25, 0.5).
			position = { 800, 1800 },
			cursor = { 0, 0 },
		}
		helpers.stubGlobals({
			GetLocale = function()
				return "ruRU"
			end,
			debugstack = function()
				return world.stack
			end,
			DEFAULT_CHAT_FRAME = {
				AddMessage = function(_, msg)
					table.insert(chat, msg)
				end,
			},
		})
		local addons = rawget(_G, "C_AddOns") -- created by helpers.stubGlobals
		addons.IsAddOnLoaded = function(name)
			return world.loaded[name]
		end
		addons.DisableAddOn = function(name)
			table.insert(world.disabled, name)
		end
		addons.GetNumAddOns = function()
			return #world.addonList
		end
		addons.GetAddOnInfo = function(i)
			return world.addonList[i]
		end
		local minimap = stubObject("Minimap")
		minimap.ZoomIn = stubObject("ZoomIn")
		minimap.ZoomOut = stubObject("ZoomOut")
		minimap.GetChildren = function()
			return unpack(world.children)
		end
		local stubs = {
			Minimap = minimap,
			AddonCompartmentFrame = stubObject("AddonCompartmentFrame", { registeredAddons = world.runtimeEntries }),
			UISpecialFrames = {},
			GameTooltip = stubObject("GameTooltip"),
			IsShiftKeyDown = function()
				return false
			end,
			LibStub = function(major)
				if major ~= "LibDBIcon-1.0" then
					return nil
				end
				return {
					GetButtonList = function()
						return world.iconOrder
					end,
					GetMinimapButton = function(_, name)
						return world.icons[name]
					end,
					RegisterCallback = function(_, event, fn)
						world.iconCallbacks = world.iconCallbacks or {}
						world.iconCallbacks[event] = fn
					end,
				}
			end,
			MinimapCompassTexture = stubObject("MinimapCompassTexture"),
			MinimapCluster = stubObject("MinimapCluster", {
				UpdateMinimapConfig = function() end,
				DielFrame = stubObject("DielFrame"),
				Tracking = stubObject("Tracking", { Button = stubObject("Tracking.Button") }),
				IndicatorFrame = stubObject("IndicatorFrame", { MailFrame = stubObject("MailFrame") }),
			}),
			GameTimeFrame = stubObject("GameTimeFrame"),
			TimeManagerClockButton = stubObject("TimeManagerClockButton"),
			ToggleCalendar = function()
				world.calendar = (world.calendar or 0) + 1
			end,
			GetMinimapZoneText = function()
				return "Elwynn Forest"
			end,
			GetRealZoneText = function()
				return "Elwynn Forest"
			end,
			GetSubZoneText = function()
				return "Goldshire"
			end,
			TimeManager_Toggle = function()
				world.clockSettings = true
			end,
			ToggleWorldMap = function() end,
			C_CVar = {
				GetCVarBool = function()
					return nil
				end,
			},
			C_Calendar = {
				GetNumPendingInvites = function()
					return world.invites or 0
				end,
			},
			C_PvP = {
				GetZonePVPInfo = function()
					return "friendly"
				end,
			},
			GetGameTime = function()
				return 14, 5
			end,
			time = os.time,
			GetCursorPosition = function()
				return world.cursor[1], world.cursor[2]
			end,
			UnitPosition = function()
				return world.position[1], world.position[2]
			end,
			CreateVector2D = function(x, y)
				return { x = x, y = y, GetXY = function(self)
					return self.x, self.y
				end }
			end,
			C_Map = {
				GetBestMapForUnit = function()
					return 1429
				end,
				GetWorldPosFromMapPos = function(_, pos)
					-- World X grows north, Y grows west: map (0,0) = NW corner = (top, left).
					local top, left, height, width = 1000, 2000, 400, 800
					return 0, { GetXY = function()
						return top - pos.y * height, left - pos.x * width
					end }
				end,
			},
			CreateFrame = function(_, name)
				local f = stubObject(name or "anon")
				table.insert(frames, f)
				return f
			end,
			hooksecurefunc = function(obj, method, fn)
				table.insert(hooks, { obj = obj, method = method, fn = fn })
				local original = obj[method]
				obj[method] = function(...)
					local r = original and original(...)
					fn(...)
					return r
				end
			end,
			UnitClass = function()
				return "Warrior", "WARRIOR"
			end,
			RAID_CLASS_COLORS = { WARRIOR = { r = 0.78, g = 0.61, b = 0.43 } },
			MinimalSliderWithSteppersMixin = { Label = { Right = "right" } },
			CreateSettingsListSectionHeaderInitializer = function(text)
				return { header = text }
			end,
			SlashCmdList = {},
			IsLoggedIn = function()
				return false -- the specs fire PLAYER_LOGIN themselves
			end,
			issecurevariable = function(tbl, name)
				if type(tbl) == "table" then
					return world.secure[name] == true, nil
				end
				return world.taint[1], world.taint[2]
			end,
			C_Timer = {
				After = function(_, fn)
					table.insert(world.timers, fn)
				end,
			},
			ReloadUI = function()
				world.reloaded = true
			end,
			StaticPopupDialogs = {},
			StaticPopup_Show = function(which, text, _, data)
				table.insert(world.popups, { which = which, text = text, data = data })
			end,
			Settings = {
				RegisterVerticalLayoutCategory = function(name)
					return stubObject("category:" .. name), stubObject("layout")
				end,
				RegisterAddOnSetting = function(_, _, key, tbl, varType, name, default)
					local setting = { key = key, tbl = tbl, type = varType, name = name, default = default }
					function setting:SetValueChangedCallback(fn)
						self.callback = fn
					end
					function setting:Set(value)
						self.tbl[self.key] = value
						self.callback(self, value)
					end
					settings[key] = setting
					return setting
				end,
				CreateControlTextContainer = function()
					local data = {}
					return {
						Add = function(_, value, label)
							table.insert(data, { value = value, label = label })
						end,
						GetData = function()
							return data
						end,
					}
				end,
				CreateDropdown = function(_, setting, getOptions)
					setting.options = getOptions()
				end,
				CreateSliderOptions = function()
					return stubObject("sliderOptions")
				end,
				CreateSlider = function() end,
				CreateCheckbox = function() end,
				RegisterAddOnCategory = function() end,
				OpenToCategory = function(id)
					opened = id
				end,
			},
		}
		local names = {}
		for k in pairs(stubs) do
			names[#names + 1] = k
		end
		require("tests.repo.forever_api").CheckStubs(names) -- no fakes of APIs Forever lacks
		for k, v in pairs(stubs) do
			rawset(_G, k, v)
		end
		rawset(_G, "OrdaenMinimapDB", nil)
		rawset(_G, "GetMinimapShape", nil)

		helpers.loadCore()
		ns = {}
		loadToc("OrdaenMinimap", ns)
	end)

	local function frameNamed(name)
		for _, f in ipairs(frames) do
			if f.name == name then
				return f
			end
		end
		return nil
	end

	local function fire(event, arg)
		local eventFrame = frames[1]
		eventFrame.scripts.OnEvent(eventFrame, event, arg)
	end

	it("creates defaults and the settings page on ADDON_LOADED", function()
		fire("ADDON_LOADED", "OrdaenMinimap")
		assert.equals("gold", _G.OrdaenMinimapDB.borderStyle)
		assert.equals("borderStyle", settings.borderStyle.key)
		assert.equals("Стиль рамки", settings.borderStyle.name)
		assert.equals(#ns.BORDER_STYLES, #settings.borderStyle.options)
		assert.equals(#ns.BORDER_COLORS, #settings.borderColor.options)
		assert.equals("number", settings.scale.type)
	end)

	it("makes the map square with a border on PLAYER_LOGIN", function()
		fire("ADDON_LOADED", "OrdaenMinimap")
		fire("PLAYER_LOGIN")
		assert.same({ "Interface\\Buttons\\WHITE8X8" }, Minimap.calls.SetMaskTexture[1])
		assert.equals("SQUARE", _G.GetMinimapShape())
		assert.is_false(_G.MinimapCompassTexture.shown)
		assert.is_false(Minimap.ZoomIn.shown)
		assert.is_function(Minimap.scripts.OnMouseWheel)

		local border = frameNamed("OrdaenMinimapBorder")
		assert.equals("OrdaenMinimapBorder", border.name)
		assert.equals("Interface\\DialogFrame\\UI-DialogBox-Border", border.calls.SetBackdrop[1][1].edgeFile)
		assert.same({ 1 }, Minimap.calls.SetScale[1])
		assert.truthy(chat[#chat]:find("/om", 1, true))
	end)

	it("keeps hidden pieces hidden and the mask applied when Blizzard re-shows them", function()
		fire("ADDON_LOADED", "OrdaenMinimap")
		fire("PLAYER_LOGIN")
		_G.MinimapCompassTexture:Show()
		assert.is_false(_G.MinimapCompassTexture.shown)
		local masks = #Minimap.calls.SetMaskTexture
		MinimapCluster:UpdateMinimapConfig()
		assert.equals(masks + 1, #Minimap.calls.SetMaskTexture)
	end)

	it("zooms with the mouse wheel within the zoom levels", function()
		fire("ADDON_LOADED", "OrdaenMinimap")
		fire("PLAYER_LOGIN")
		Minimap.scripts.OnMouseWheel(Minimap, 1)
		assert.same({ 3 }, Minimap.calls.SetZoom[1])
	end)

	describe("around the map", function()
		local function login()
			fire("ADDON_LOADED", "OrdaenMinimap")
			fire("PLAYER_LOGIN")
		end

		local function lastPoint(f)
			return f.calls.SetPoint[#f.calls.SetPoint]
		end

		it("hides Blizzard's day/night, calendar, clock and keeps them hidden", function()
			login()
			assert.is_false(MinimapCluster.DielFrame.shown)
			assert.is_false(_G.GameTimeFrame.shown)
			assert.is_false(_G.TimeManagerClockButton.shown)
			_G.GameTimeFrame:Show()
			assert.is_false(_G.GameTimeFrame.shown)
		end)

		it("shows the zone above, coordinates and the clock below, outside the border", function()
			login()
			local zone = frameNamed("OrdaenMinimapZone")
			assert.equals("Elwynn Forest", zone.font.text)
			assert.same({ 0.1, 1, 0.1 }, zone.font.calls.SetTextColor[1])
			-- gold border: outset 7, + 2 px gap
			assert.same({ "BOTTOMRIGHT", Minimap, "TOPRIGHT", 0, 9 }, lastPoint(zone))
			local coords = Minimap.font
			assert.equals("OrdaenMinimapCoords", coords.name)
			assert.same({ "%.1f, %.1f", 25, 50 }, coords.calls.SetFormattedText[#coords.calls.SetFormattedText])
			local clock = frameNamed("OrdaenMinimapClock")
			assert.same({ "%02d:%02d", 14, 5 }, clock.font.calls.SetFormattedText[1])
		end)

		it("shows the clock tooltip through OrdaenCore.UI, with the invites line only when invites are pending", function()
			-- Drawing is OrdaenCore.UI's job (tests/OrdaenCore/ui_spec.lua); here: the block Minimap declares.
			local shown, refreshed = {}, 0
			local UI = rawget(_G, "OrdaenCore").UI
			UI.ShowTooltip = function(owner, block, opts)
				shown.owner, shown.block, shown.opts = owner, block, opts
			end
			UI.RefreshTooltip = function()
				refreshed = refreshed + 1
			end
			local function visibleTexts()
				local texts = {}
				for _, el in ipairs(shown.block) do
					if not el.hidden then
						texts[#texts + 1] = el.text
					end
				end
				return table.concat(texts, "|")
			end
			login()
			local clock = frameNamed("OrdaenMinimapClock")
			clock.scripts.OnEnter(clock)
			assert.equals(clock, shown.owner)
			assert.equals("tooltip", shown.block.style)
			assert.equals("below", shown.opts.side)
			local plain = visibleTexts()
			assert.truthy(plain:find(ns.L.TIME_TOOLTIP_CALENDAR, 1, true))
			assert.falsy(plain:find(ns.L.CALENDAR_PENDING, 1, true))

			world.invites = 2
			local infoEvents
			for i, f in ipairs(frames) do
				if f.name == "OrdaenMinimapClock" then
					infoEvents = frames[i + 1]
				end
			end
			local before = refreshed
			infoEvents.scripts.OnEvent(infoEvents, "CALENDAR_UPDATE_PENDING_INVITES")
			assert.equals(before + 1, refreshed) -- a shown tooltip is redrawn with the new line
			assert.truthy(visibleTexts():find(ns.L.CALENDAR_PENDING, 1, true))
		end)

		it("opens the calendar from the clock", function()
			login()
			local clock = frameNamed("OrdaenMinimapClock")
			clock.scripts.OnClick(clock, "LeftButton")
			assert.equals(1, world.calendar)
		end)

		it("clears the coordinates where there are none (instances)", function()
			login()
			world.position = {}
			-- Info.lua's event frame is created right after the clock.
			local infoEvents
			for i, f in ipairs(frames) do
				if f.name == "OrdaenMinimapClock" then
					infoEvents = frames[i + 1]
				end
			end
			infoEvents.scripts.OnEvent(infoEvents, "ZONE_CHANGED_NEW_AREA")
			local coords = Minimap.font
			assert.equals("", coords.text)
		end)

		it("puts the tracking button in our style outside the border and drags it around", function()
			login()
			local tracking = MinimapCluster.Tracking
			assert.same({ Minimap }, tracking.calls.SetParent[1])
			local look = frameNamed("OrdaenMinimapTrackingButton")
			assert.truthy(look)
			assert.same({ "CENTER", tracking, "CENTER" }, look.calls.SetPoint[#look.calls.SetPoint])
			-- Default angle 160, map 140 (stub default), gold outset 7, button 28: outside the left side.
			local point = lastPoint(tracking)
			assert.equals("CENTER", point[1])
			assert.is_true(point[4] < -(70 + 7))

			-- Blizzard's layout moves it back: we put it back.
			tracking:SetPoint("TOPLEFT", MinimapCluster, "TOPLEFT", 0, 0)
			assert.same(point, lastPoint(tracking))

			-- Drag to the right side.
			world.cursor = { 500, 0 }
			rawset(Minimap, "GetCenter", function()
				return 0, 0
			end)
			tracking.Button.scripts.OnDragStart(tracking.Button)
			local driver
			for _, f in ipairs(frames) do
				if f.scripts.OnUpdate and f.name == "anon" and not f.scripts.OnShow then
					driver = f
				end
			end
			driver.scripts.OnUpdate(driver, 0.01)
			tracking.Button.scripts.OnDragStop(tracking.Button)
			assert.equals(0, _G.OrdaenMinimapDB.buttonAngles.tracking)
			assert.is_true(lastPoint(tracking)[4] > 70 + 7)
			assert.is_nil(driver.scripts.OnUpdate) -- nothing runs once the drag ends
		end)

		it("takes over placing the Ordaen Dev gear button (dev mode) and tells it so", function()
			local gear = stubObject("OrdaenDevButton")
			rawset(_G, "OrdaenDevButton", gear)
			login()
			assert.equals("OrdaenMinimap", gear.ordaenPlacedBy)
			assert.same({ Minimap }, gear.calls.SetParent[1])
			assert.is_true(lastPoint(gear)[4] < -(70 + 7)) -- default 200 degrees: left side, outside the border
			assert.is_function(gear.scripts.OnDragStart)
			rawset(_G, "OrdaenDevButton", nil)
		end)

		it("moves Blizzard's mail indicator off the map but keeps its parent", function()
			login()
			local mail = MinimapCluster.IndicatorFrame.MailFrame
			-- Blizzard's mail code calls self:GetParent():Layout() (Minimap.lua:520): re-parenting it onto the
			-- minimap, which has no Layout, errored on every mail update.
			assert.is_nil(mail.calls.SetParent)
			local point = lastPoint(mail)
			assert.equals(Minimap, point[2])
			assert.is_true(point[4] > 70) -- right side by default
		end)

		it("places the drawer button on the ring and forgets angles on /om reset", function()
			login()
			local button = frameNamed("OrdaenMinimapDrawerButton")
			local before = lastPoint(button)
			assert.is_true(before[4] < -70 and before[5] < -70) -- bottom-left corner
			_G.OrdaenMinimapDB.buttonAngles.drawer = 0
			SlashCmdList.ORDAENMINIMAP("reset")
			assert.same({}, _G.OrdaenMinimapDB.buttonAngles)
			assert.same(before, lastPoint(button))
		end)

		it("removes the texts when another minimap addon takes over", function()
			login()
			world.stack = [[[string "@Interface/AddOns/SexyMap/Shapes.lua"]:348: in function 'ApplyShape']]
			Minimap:SetMaskTexture("round")
			assert.is_false(frameNamed("OrdaenMinimapZone").shown)
			assert.is_false(frameNamed("OrdaenMinimapClock").shown)
		end)
	end)

	it("re-applies the look when a setting changes", function()
		fire("ADDON_LOADED", "OrdaenMinimap")
		fire("PLAYER_LOGIN")
		settings.borderStyle:Set("thin")
		settings.borderColor:Set("class")
		local border = frameNamed("OrdaenMinimapBorder")
		local lastBackdrop = border.calls.SetBackdrop[#border.calls.SetBackdrop][1]
		assert.equals("Interface\\Buttons\\WHITE8X8", lastBackdrop.edgeFile)
		assert.same({ 0.78, 0.61, 0.43, 1 },
			border.calls.SetBackdropBorderColor[#border.calls.SetBackdropBorderColor])

		settings.borderStyle:Set("none")
		assert.is_false(border.shown)
		settings.scale:Set(1.3)
		assert.same({ 1.3 }, Minimap.calls.SetScale[#Minimap.calls.SetScale])
	end)

	it("draws a frame style as one tinted texture and switches back to a backdrop", function()
		table.insert(ns.BORDER_STYLES, {
			id = "test-frame",
			label = "STYLE_GOLD",
			frame = { file = "Interface\\AddOns\\OrdaenMinimap\\media\\test-frame" },
			outset = 11,
		})
		fire("ADDON_LOADED", "OrdaenMinimap")
		fire("PLAYER_LOGIN")
		settings.borderColor:Set("gold")
		settings.borderStyle:Set("test-frame")
		local border = frameNamed("OrdaenMinimapBorder")
		assert.same({ nil }, border.calls.SetBackdrop[#border.calls.SetBackdrop])
		local texture = border.texture
		assert.same({ "Interface\\AddOns\\OrdaenMinimap\\media\\test-frame" },
			texture.calls.SetTexture[#texture.calls.SetTexture])
		assert.same({ 1, 0.82, 0, 1 }, texture.calls.SetVertexColor[#texture.calls.SetVertexColor])
		assert.same({ "TOPLEFT", Minimap, "TOPLEFT", -11, 11 }, border.calls.SetPoint[#border.calls.SetPoint - 1])

		settings.borderStyle:Set("gold")
		assert.is_false(texture.shown)
		assert.equals("Interface\\DialogFrame\\UI-DialogBox-Border",
			border.calls.SetBackdrop[#border.calls.SetBackdrop][1].edgeFile)
	end)

	it("opens the settings with /om and resets with /om reset", function()
		fire("ADDON_LOADED", "OrdaenMinimap")
		fire("PLAYER_LOGIN")
		SlashCmdList.ORDAENMINIMAP("")
		assert.equals(42, opened)
		_G.OrdaenMinimapDB.borderStyle = "thin"
		SlashCmdList.ORDAENMINIMAP("reset")
		assert.equals("gold", _G.OrdaenMinimapDB.borderStyle)
	end)

	describe("conflicts", function()
		local function login()
			fire("ADDON_LOADED", "OrdaenMinimap")
			fire("PLAYER_LOGIN")
		end

		local function popup()
			return StaticPopupDialogs.ORDAEN_MINIMAP_CONFLICT
		end

		it("steps aside and asks when a known minimap addon is loaded", function()
			world.loaded.SexyMap = true
			login()
			assert.is_nil(Minimap.calls.SetMaskTexture)
			assert.equals(1, #world.popups)
			assert.equals("SexyMap", world.popups[1].data)
			assert.truthy(world.popups[1].text:find("SexyMap", 1, true))
		end)

		it("keeping ours disables a dedicated minimap addon and reloads", function()
			world.loaded.SexyMap = true
			login()
			popup().OnAccept(nil, "SexyMap")
			assert.same({ "SexyMap" }, world.disabled)
			assert.is_true(world.reloaded)
		end)

		it("keeping the other addon disables ours and reloads", function()
			world.loaded.SexyMap = true
			login()
			popup().OnCancel(nil, "SexyMap", "clicked")
			assert.same({ "OrdaenMinimap" }, world.disabled)
			assert.is_true(world.reloaded)
		end)

		it("asks the user to disable by hand when the client has no DisableAddOn", function()
			rawget(_G, "C_AddOns").DisableAddOn = nil
			world.loaded.SexyMap = true
			login()
			popup().OnAccept(nil, "SexyMap")
			assert.is_nil(world.reloaded)
			assert.truthy(chat[#chat]:find("SexyMap", 1, true))
		end)

		it("decide later keeps the map untouched for the session", function()
			world.loaded.SexyMap = true
			login()
			popup().OnAlt(nil, "SexyMap")
			settings.borderStyle:Set("thin")
			assert.is_nil(Minimap.calls.SetMaskTexture)
			assert.is_nil(world.reloaded)
		end)

		it("detects an addon that defined GetMinimapShape first, and can override it", function()
			rawset(_G, "GetMinimapShape", function()
				return "SQUARE"
			end)
			world.taint = { false, "EnhanceQoL" }
			login()
			assert.equals("EnhanceQoL", world.popups[1].data)
			assert.is_nil(Minimap.calls.SetMaskTexture)

			-- A multi-purpose addon is overridden, not disabled.
			popup().OnAccept(nil, "EnhanceQoL")
			assert.same({}, world.disabled)
			assert.equals("ours", _G.OrdaenMinimapDB.conflictChoice.EnhanceQoL)
			assert.equals(1, #Minimap.calls.SetMaskTexture)
		end)

		it("remembers an override at the next login", function()
			rawset(_G, "OrdaenMinimapDB", { conflictChoice = { SexyMap = "ours" } })
			world.loaded.SexyMap = true
			login()
			assert.equals(0, #world.popups)
			assert.equals(1, #Minimap.calls.SetMaskTexture)
		end)

		it("re-applies when Blizzard changes the mask, without asking", function()
			login()
			Minimap:SetMaskTexture("round")
			assert.equals(0, #world.popups)
			local calls = Minimap.calls.SetMaskTexture
			assert.same({ "Interface\\Buttons\\WHITE8X8" }, calls[#calls])
		end)

		it("detects another addon changing the mask later and names it", function()
			login()
			world.stack = [[[string "@Interface/AddOns/SexyMap/Shapes.lua"]:348: in function 'ApplyShape']]
			Minimap:SetMaskTexture("round")
			assert.equals("SexyMap", world.popups[1].data)
			assert.is_false(frameNamed("OrdaenMinimapBorder").shown) -- our border is gone
			assert.is_nil(_G.GetMinimapShape)
		end)

		it("the delayed check catches changes that bypassed our hooks", function()
			login()
			assert.is_function(world.timers[1]) -- the delayed check is scheduled first
			rawset(_G, "GetMinimapShape", function()
				return "ROUND"
			end)
			world.taint = { false, "SomeUI" }
			world.timers[1]()
			assert.equals("SomeUI", world.popups[1].data)
		end)

		it("the delayed check stays quiet when nothing changed", function()
			login()
			world.timers[1]()
			assert.equals(0, #world.popups)
		end)
	end)

	describe("drawer", function()
		local function login()
			fire("ADDON_LOADED", "OrdaenMinimap")
			fire("PLAYER_LOGIN")
		end

		local function addButton(name, opts)
			local button = stubObject(name, { GetName = function()
				return name
			end })
			if opts and opts.libdbicon then
				world.icons[opts.libdbicon] = button
				table.insert(world.iconOrder, opts.libdbicon)
			else
				table.insert(world.children, button)
			end
			return button
		end

		local function addTocEntry(addon, fields)
			table.insert(world.addonList, addon)
			world.loaded[addon] = true
			helpers.metadata[addon] = fields
		end

		it("collects buttons that ignore the square, LibDBIcon buttons, and leaves the rest", function()
			local alto = addButton("AltoholicMinimapButton")
			local bio = addButton("AutoBiographer_MinimapButton")
			local details = addButton("LibDBIcon10_Details", { libdbicon = "Details" })
			local pin = addButton("HandyNotes_Minimap")
			local blizzard = addButton("MiniMapTrackingButton")
			world.secure.MiniMapTrackingButton = true
			local drawerCalls = function(b)
				return b.calls.SetParent and #b.calls.SetParent or 0
			end
			login()
			local container = frameNamed("OrdaenMinimapDrawer")
			assert.truthy(container)
			assert.truthy(frameNamed("OrdaenMinimapDrawerButton"))
			for _, b in ipairs({ alto, bio, details }) do
				assert.equals(1, drawerCalls(b), b.name)
				assert.equals(container, b.calls.SetParent[1][1])
			end
			assert.equals(0, drawerCalls(pin))
			assert.equals(0, drawerCalls(blizzard))
		end)

		it("never collects our own frames, like the Ordaen Dev button on the minimap edge", function()
			local dev = addButton("OrdaenDevButton")
			local devLike = addButton("OrdaenDevMinimapButton") -- would match a pattern if renamed
			login()
			assert.is_nil(dev.calls.SetParent)
			assert.is_nil(devLike.calls.SetParent)
		end)

		it("keeps collected buttons from moving themselves back onto the map", function()
			local bio = addButton("AutoBiographer_MinimapButton")
			login()
			local before = bio.calls.SetPoint and #bio.calls.SetPoint or 0
			bio:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 52, -52) -- what its own code does
			local after = bio.calls.SetPoint and #bio.calls.SetPoint or 0
			assert.equals(before, after)
		end)

		it("collects LibDBIcon buttons created after login", function()
			login()
			local late = stubObject("LibDBIcon10_Late")
			world.iconCallbacks.LibDBIcon_IconCreated("LibDBIcon_IconCreated", late, "Late")
			assert.equals(frameNamed("OrdaenMinimapDrawer"), late.calls.SetParent[1][1])
		end)

		it("shows compartment entries, calls their functions, and hides twins of shown icons", function()
			local clicked = {}
			rawset(_G, "Pawn_OnCompartmentClick", function(addon, mouseButton)
				table.insert(clicked, { addon, mouseButton })
			end)
			addTocEntry("Pawn", { Title = "Pawn", AddonCompartmentFunc = "Pawn_OnCompartmentClick" })
			addTocEntry("Details", { Title = "Details!", AddonCompartmentFunc = "Details_Click" })
			addButton("LibDBIcon10_Details", { libdbicon = "Details" })
			table.insert(world.runtimeEntries, {
				text = "Baganator",
				func = function(_, input)
					table.insert(clicked, { "Baganator", input.buttonName })
				end,
			})
			login()
			frameNamed("OrdaenMinimapDrawerButton").scripts.OnClick(nil, "LeftButton")

			local description = ns.Drawer.Describe()
			assert.same({ "toc: Pawn", "runtime: Baganator" }, description.entries)

			local entryButtons = {}
			for _, f in ipairs(frames) do
				if f.name == "anon" and f.scripts.OnClick and f.index then
					entryButtons[f.index] = f
				end
			end
			entryButtons[1].scripts.OnClick(entryButtons[1], "RightButton")
			entryButtons[2].scripts.OnClick(entryButtons[2], "LeftButton")
			assert.same({ { "Pawn", "RightButton" }, { "Baganator", "LeftButton" } }, clicked)
			rawset(_G, "Pawn_OnCompartmentClick", nil)
		end)

		it("hides Blizzard's compartment button by default and shows it when the option is off", function()
			local compartment = _G.AddonCompartmentFrame
			compartment.parent = MinimapCluster
			login()
			-- Parented to a frame that is never shown, so no Show/SetShown can bring it back.
			local hidden = compartment:GetParent()
			assert.is_truthy(hidden)
			assert.are_not.equal(MinimapCluster, hidden)
			assert.is_false(hidden.shown)
			-- Blizzard's layout code re-parents it: it goes straight back.
			compartment:SetParent(MinimapCluster)
			assert.equals(hidden, compartment:GetParent())
			settings.hideBlizzardCompartment:Set(false)
			assert.equals(MinimapCluster, compartment:GetParent())
		end)

		it("stays off with a warning while MinimapButtonButton is loaded", function()
			world.loaded.MinimapButtonButton = true
			local bio = addButton("AutoBiographer_MinimapButton")
			login()
			assert.is_nil(frameNamed("OrdaenMinimapDrawerButton"))
			assert.is_nil(bio.calls.SetParent)
			local warned = false
			for _, line in ipairs(chat) do
				warned = warned or line:find("MinimapButtonButton", 1, true) ~= nil
			end
			assert.is_true(warned)
		end)

		it("does nothing when turned off in the settings", function()
			rawset(_G, "OrdaenMinimapDB", { drawerEnabled = false })
			login()
			assert.is_nil(frameNamed("OrdaenMinimapDrawerButton"))
			settings.drawerEnabled:Set(true)
			assert.truthy(frameNamed("OrdaenMinimapDrawerButton"))
		end)
	end)
end)
