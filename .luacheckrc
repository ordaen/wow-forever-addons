-- luacheck config. WoW runs Lua 5.1.
std = "lua51"
max_line_length = 120
exclude_files = { "node_modules/", ".release/", ".lua/", ".luarocks/", ".install/", "api/" }

-- Globals the addons are allowed to define (or add entries to).
local ours = {
	"GetMinimapShape", -- Blizzard convention: the minimap addon defines it
	"OrdaenCore",
	"StaticPopupDialogs", -- we add our popup to it
	"OrdaenCoreDebugDB",
	"SLASH_ORDAENDEV1",
	"OrdaenMinimapDB",
	"SLASH_ORDAENMINIMAP1",
	"SLASH_ORDAENMINIMAP2",
	"SlashCmdList",
}
globals = ours

-- Globals other addons define that we use when they are present (never Blizzard API).
local fromOtherAddons = {
	"LibStub",
	"BugGrabber",
}

-- The real Forever API, generated from an in-game dump (scripts/api-import.sh, api/forever/CURRENT).
-- With it, using anything Forever doesn't have (like MouseIsOver) fails luacheck.
local ok, forever = pcall(dofile, "api/forever/luacheck.lua")
if ok and type(forever) == "table" then
	for _, name in ipairs(ours) do
		forever[name] = nil
	end
	for _, name in ipairs(fromOtherAddons) do
		forever[name] = { other_fields = true } -- their fields are theirs to define
	end
	read_globals = forever
else
	-- Fallback until the first dump is imported: hand-checked names (see CLAUDE.md, "Forever lacks
	-- many retail/classic FrameXML helpers").
	read_globals = {
		"C_AddOns", "CreateFrame", "DEFAULT_CHAT_FRAME", "Minimap", "UIParent", "InCombatLockdown",
		"C_Timer", "GameTooltip", "IsShiftKeyDown", "CreateSettingsListSectionHeaderInitializer", "ReloadUI",
		"StaticPopup_Show", "issecurevariable", "MinimalSliderWithSteppersMixin", "MinimapCluster",
		"RAID_CLASS_COLORS", "Settings", "UnitClass", "hooksecurefunc", "BackdropTemplateMixin",
		"ChatFontNormal", "GetBuildInfo", "GetLocale", "GetTime", "UISpecialFrames", "date", "time",
		"debuglocals", "debugstack", "geterrorhandler", "seterrorhandler", "C_UI", "GetCursorPosition",
		"LoggingChat", "Screenshot",
	}
	for _, name in ipairs(fromOtherAddons) do
		read_globals[#read_globals + 1] = name
	end
end

-- Specs read and set fields on their own WoW fakes (Minimap.calls, _G.OrdaenMinimapDB...): the strict API
-- fields from the dump apply to addon code, not to tests inspecting fakes.
files["tests/"] = { std = "+busted", ignore = { "122", "142", "143" } }
files["scripts/"] = { std = "lua51" }
