-- Ordaen Core's own settings (settings.jsonc): how every Ordaen addon looks. The theme decides the default of every
-- look setting of every Ordaen addon (SettingsStore.lua); OrdaenCore.UI reads OrdaenCoreDB.ui (theme, textSize)
-- when it loads and again on OrdaenCore.UI._SettingsChanged(), which runs after every change here. The palette
-- (Colors.lua) reads its tones and the classes' colours from here too.
local addonName, ns = ...
local _ = ns.NewAddon -- the build loads this file after Addon.lua, which defines NewAddon
local Colors = ns.Colors -- and after Colors.lua

---@class OrdaenCoreAPI
local Core = ns.Core

local A ---@type OrdaenCoreAddon

local function uiSettingsChanged()
	local UI = OrdaenCore.UI
	if UI and UI._SettingsChanged then
		UI._SettingsChanged()
	end
end

local function get(key)
	return A:Get(key)
end

-- The palette follows its settings: a tone, a class's colour, or the theme (which moves the tones the player
-- didn't change; each of those is announced here too).
local function refreshColors()
	Colors:_Refresh(get)
end

-- A theme switch first moves every addon's untouched look settings (each addon hears its changes, features
-- first), then OrdaenCore.UI redraws.
local function coreSettingChanged(key, value)
	if key == "ui.theme" then
		Core._SettingsStore.SetTheme(value)
	end
	if key == "ui.theme" or key:find("^palette%.") or key:find("^class%.") then
		refreshColors()
	end
	uiSettingsChanged()
end

-- No slash command: /ordaen belongs to the dev addon. The page is under Options > AddOns > Ordaen Core.
A = ns.NewAddon(addonName, ns, { onChange = coreSettingChanged }) --[[@as OrdaenCoreAddon]]
if not A then
	return
end

-- Ordaen Core loads before every addon that depends on it, so the theme and the palette are set before their
-- settings bind.
A:OnLoad(function(db)
	Core._SettingsStore.SetTheme(db.ui.theme)
	refreshColors()
end)
