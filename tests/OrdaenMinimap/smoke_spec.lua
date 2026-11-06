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
	obj.GetScript = function(self, script)
		return self.scripts[script]
	end
	for k, v in pairs(extra or {}) do
		rawset(obj, k, v)
	end
	return obj
end

local function loadToc(addon, ns)
	local toc = assert(io.open("addons/" .. addon .. "/" .. addon .. ".toc")):read("*a")
	for file in toc:gmatch("[^\r\n]+") do
		if file:match("%.lua$") then
			assert(loadfile("addons/" .. addon .. "/" .. file))(addon, ns)
		end
	end
end

describe("OrdaenMinimap smoke", function()
	local ns, frames, hooks, chat, settings, opened

	before_each(function()
		frames, hooks, chat, settings, opened = {}, {}, {}, {}, nil
		helpers.stubGlobals({
			GetLocale = function()
				return "ruRU"
			end,
			DEFAULT_CHAT_FRAME = {
				AddMessage = function(_, msg)
					table.insert(chat, msg)
				end,
			},
		})
		local minimap = stubObject("Minimap")
		minimap.ZoomIn = stubObject("ZoomIn")
		minimap.ZoomOut = stubObject("ZoomOut")
		local stubs = {
			Minimap = minimap,
			MinimapCompassTexture = stubObject("MinimapCompassTexture"),
			MinimapCluster = stubObject("MinimapCluster", { UpdateMinimapConfig = function() end }),
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
				RegisterAddOnCategory = function() end,
				OpenToCategory = function(id)
					opened = id
				end,
			},
		}
		for k, v in pairs(stubs) do
			rawset(_G, k, v)
		end
		rawset(_G, "OrdaenMinimapDB", nil)
		rawset(_G, "GetMinimapShape", nil)

		helpers.loadCore()
		ns = {}
		loadToc("OrdaenMinimap", ns)
	end)

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

		local border = frames[#frames]
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

	it("re-applies the look when a setting changes", function()
		fire("ADDON_LOADED", "OrdaenMinimap")
		fire("PLAYER_LOGIN")
		settings.borderStyle:Set("thin")
		settings.borderColor:Set("class")
		local border = frames[#frames]
		local lastBackdrop = border.calls.SetBackdrop[#border.calls.SetBackdrop][1]
		assert.equals("Interface\\Buttons\\WHITE8X8", lastBackdrop.edgeFile)
		assert.same({ 0.78, 0.61, 0.43, 1 },
			border.calls.SetBackdropBorderColor[#border.calls.SetBackdropBorderColor])

		settings.borderStyle:Set("none")
		assert.is_false(border.shown)
		settings.scale:Set(1.3)
		assert.same({ 1.3 }, Minimap.calls.SetScale[#Minimap.calls.SetScale])
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
end)
