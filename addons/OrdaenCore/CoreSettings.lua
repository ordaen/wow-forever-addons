-- Ordaen Core's own settings (settings.jsonc): how every Ordaen addon looks. The theme decides the default of every
-- look setting of every Ordaen addon (SettingsStore.lua); OrdaenCore.UI reads OrdaenCoreDB.ui (theme, textSize)
-- when it loads and again on OrdaenCore.UI._SettingsChanged(), which runs after every change here.
local addonName, ns = ...
local _ = ns.NewAddon -- the build loads this file after Addon.lua, which defines NewAddon

---@class OrdaenCoreAPI
local Core = ns.Core

local function uiSettingsChanged()
	local UI = OrdaenCore.UI
	if UI and UI._SettingsChanged then
		UI._SettingsChanged()
	end
end

-- A theme switch first moves every addon's untouched look settings (each addon hears its changes, features
-- first), then OrdaenCore.UI redraws.
local function coreSettingChanged(key, value)
	if key == "ui.theme" then
		Core._SettingsStore.SetTheme(value)
	end
	uiSettingsChanged()
end

-- No slash command: /ordaen belongs to the dev addon. The page is under Options > AddOns > Ordaen Core.
local A = ns.NewAddon(addonName, ns, { onChange = coreSettingChanged }) --[[@as OrdaenCoreAddon]]
if not A then
	return
end

-- Ordaen Core loads before every addon that depends on it, so the theme is set before their settings bind.
A:OnLoad(function(db)
	Core._SettingsStore.SetTheme(db.ui.theme)
end)
