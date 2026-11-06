-- Ordaen Core's own settings: how every Ordaen addon looks. OrdaenCore.UI reads OrdaenCoreDB.ui (theme, textSize)
-- when it loads and again on OrdaenCore.UI._SettingsChanged(), which this page calls after every change.
local addonName, ns = ...
local _ = ns.NewAddon -- the build loads this file after Addon.lua, which defines NewAddon

local THEMES = {
	{ id = "ordaen", label = "THEME_ORDAEN" },
	{ id = "blizzard", label = "THEME_BLIZZARD" },
	{ id = "minimal", label = "THEME_MINIMAL" },
}

local function uiSettingsChanged()
	local UI = OrdaenCore.UI
	if UI and UI._SettingsChanged then
		UI._SettingsChanged()
	end
end

-- No slash command: /ordaen belongs to the dev addon. The page is under Options > AddOns > Ordaen Core.
OrdaenCore.NewAddon(addonName, ns, {
	db = "OrdaenCoreDB",
	defaults = { ui = { theme = "ordaen", textSize = 12 } },
	settings = {
		title = "SETTINGS_TITLE",
		onChange = uiSettingsChanged,
		{ header = "HEADER_APPEARANCE" },
		{ key = "ui.theme", label = "THEME", tooltip = "THEME_TOOLTIP", choices = THEMES },
		{
			key = "ui.textSize",
			label = "TEXT_SIZE",
			tooltip = "TEXT_SIZE_TOOLTIP",
			min = 10,
			max = 16,
			step = 1,
			format = "px",
		},
	},
})
