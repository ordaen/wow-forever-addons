-- luacheck config. WoW runs Lua 5.1.
std = "lua51"
max_line_length = 120
exclude_files = { "node_modules/", ".release/", ".lua/", ".luarocks/", ".install/" }

-- WoW API used by the addons. Add names here as you use them.
read_globals = {
	"C_AddOns",
	"CreateFrame",
	"DEFAULT_CHAT_FRAME",
	"Minimap",
	"UIParent",
	"InCombatLockdown",
	"LibStub",
	-- used by OrdaenMinimap
	"C_Timer",
	"CreateSettingsListSectionHeaderInitializer",
	"ReloadUI",
	"StaticPopup_Show",
	"issecurevariable",
	"MinimalSliderWithSteppersMixin",
	"MinimapCluster",
	"RAID_CLASS_COLORS",
	"Settings",
	"UnitClass",
	"hooksecurefunc",
	-- used by OrdaenCore/Debug.lua
	"BackdropTemplateMixin",
	"ChatFontNormal",
	"GetBuildInfo",
	"GetLocale",
	"GetTime",
	"UISpecialFrames",
	"date",
	"debuglocals",
	"debugstack",
	"geterrorhandler",
}

-- Globals the addons are allowed to define.
globals = {
	"GetMinimapShape", -- Blizzard convention: the minimap addon defines it
	"OrdaenCore",
	"StaticPopupDialogs", -- we add our popup to it
	"OrdaenMinimapDB",
	"SLASH_ORDAENMINIMAP1",
	"SLASH_ORDAENMINIMAP2",
	"SlashCmdList",
}

files["tests/"] = { std = "+busted" }
