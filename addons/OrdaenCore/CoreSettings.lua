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

-- The whole palette (at load and on a theme switch).
local function refreshColors()
	Colors:_Refresh(get)
end

-- A theme switch first moves every addon's untouched look settings (each addon hears its changes, features
-- first), then OrdaenCore.UI redraws. A tone or a class's colour updates just that in the palette (a colour picker
-- writes several times a second while dragged); only `ui.*` settings make OrdaenCore.UI restyle.
local function coreSettingChanged(key, value)
	if key == "ui.theme" then
		Core._SettingsStore.SetTheme(value)
		refreshColors()
	elseif key:find("^palette%.") or key:find("^class%.") then
		Colors:_Changed(key, get)
	end
	if key:find("^ui%.") then
		uiSettingsChanged()
	end
end

-- No slash command: /ordaen belongs to the dev addon. The page is under Options > AddOns > Ordaen Core.
A = ns.NewAddon(addonName, ns, { onChange = coreSettingChanged }) --[[@as OrdaenCoreAddon]]
if not A then
	return
end
ns.CoreAddon = A -- for Core's other files that read its settings (Modules.lua)

-- Ordaen Core loads before every addon that depends on it, so the theme and the palette are set before their
-- settings bind.
A:OnLoad(function(db)
	Core._SettingsStore.SetTheme(db.ui.theme)
	refreshColors()
	-- the modules that are on, now: before PLAYER_LOGIN, with the theme and palette already set
	Core.Modules.LoadEnabled()
end)
