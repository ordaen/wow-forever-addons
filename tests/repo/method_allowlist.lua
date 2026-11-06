-- Methods our addons call with ":" that are not WoW widget methods, so the API dump can't list them.
-- Each entry says where it's confirmed. Add an entry only with that proof.
return {
	-- Lua string methods ("text":find(...)), standard Lua 5.1.
	find = "Lua string library",
	format = "Lua string library",
	gmatch = "Lua string library",
	gsub = "Lua string library",
	lower = "Lua string library",
	match = "Lua string library",
	sub = "Lua string library",
	upper = "Lua string library",
	rep = "Lua string library",
	byte = "Lua string library",

	-- Blizzard Settings API objects (setting, category, layout, slider options, text container).
	-- Confirmed on Forever by MinimapButtonButton\Settings\SettingsMenu.lua and ForeverLootSparkles.
	SetValueChangedCallback = "Settings setting object (MinimapButtonButton SettingsMenu.lua)",
	AddInitializer = "Settings layout (ForeverLootSparkles SoftTarget.lua uses Settings.RegisterInitializer)",
	SetLabelFormatter = "Settings slider options (MinimapButtonButton SettingsMenu.lua)",
	GetData = "Settings control text container (MinimapButtonButton SettingsMenu.lua)",
	Add = "Settings control text container (MinimapButtonButton SettingsMenu.lua)",
	GetID = "Settings category (ForeverQuestTint Options.lua: category:GetID())",

	-- LibDBIcon-1.0 (embedded by other addons), confirmed by its use in MinimapButtonButton Logic/Main.lua.
	GetButtonList = "LibDBIcon-1.0",
	GetMinimapButton = "LibDBIcon-1.0",
}
