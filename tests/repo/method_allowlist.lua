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

	-- HybridMinimap.MapCanvas (Map.lua, guarded by `if HybridMinimap`). Blizzard_HybridMinimap is load-on-demand
	-- on Forever (dump 1.60.1-70790 has HybridMinimap_LoadUI and C_Minimap.ShouldUseHybridMinimap) and wasn't
	-- loaded during the dump, so its canvas methods aren't listed. Same call as SexyMap's Shapes.lua.
	SetUseMaskTexture = "HybridMinimap.MapCanvas (load-on-demand, not in the dump)",

	-- Vector2D objects (C_Map.GetWorldPosFromMapPos returns one, per docs.txt; Info.lua). Dump 1.60.1-70790
	-- lists Vector2DMixin.GetXY in namespaces.txt.
	GetXY = "Vector2DMixin (namespaces.txt: Vector2DMixin.GetXY)",

	-- LibDBIcon-1.0 (embedded by other addons), confirmed by its use in MinimapButtonButton Logic/Main.lua.
	GetButtonList = "LibDBIcon-1.0",
	GetMinimapButton = "LibDBIcon-1.0",
}
