-- Ordaen Minimap's start: declares the addon to the Ordaen Core framework (SavedVariables, settings page, slash
-- commands) and starts the features once the settings and the world are there.
local addonName, ns = ...

local L = ns.L

local function applyAll()
	if ns.Guard.blocked then
		return
	end
	local db = OrdaenMinimapDB
	ns.Map.Apply(db)
	if not ns.Map.active then
		return
	end
	ns.Buttons.Apply(db)
	ns.Info.Apply(db)
	ns.Drawer.Apply(db)
end

-- The dev-mode dump ("Save for Claude & reload" in the Ordaen Dev window).
local function dumpState()
	return {
		db = OrdaenMinimapDB,
		map = ns.Map.Describe(),
		drawer = ns.Drawer.Describe(),
		buttons = ns.Buttons.Describe(),
		info = ns.Info.Describe(),
		tooltip = OrdaenCore.UI._Describe(), -- the last tooltip as measured and drawn
	}
end

local A = OrdaenCore.NewAddon(addonName, ns, {
	db = "OrdaenMinimapDB",
	defaults = ns.DEFAULTS,
	slash = { "/om", "/ordaenminimap" },
	dump = dumpState,
	settings = {
		title = "SETTINGS_TITLE",
		onChange = applyAll,
		{ header = "HEADER_BORDER" },
		{ key = "borderStyle", label = "BORDER_STYLE", tooltip = "BORDER_STYLE_TOOLTIP", choices = ns.BORDER_STYLES },
		{ key = "borderColor", label = "BORDER_COLOR", tooltip = "BORDER_COLOR_TOOLTIP", choices = ns.BORDER_COLORS },
		{ header = "HEADER_MAP" },
		{
			key = "scale",
			label = "MAP_SCALE",
			tooltip = "MAP_SCALE_TOOLTIP",
			min = ns.SCALE_MIN,
			max = ns.SCALE_MAX,
			step = ns.SCALE_STEP,
			format = "percent",
		},
		{ header = "HEADER_DRAWER" },
		{ key = "drawerEnabled", label = "DRAWER_ENABLED", tooltip = "DRAWER_ENABLED_TOOLTIP" },
		{
			key = "hideBlizzardCompartment",
			label = "HIDE_BLIZZARD_COMPARTMENT",
			tooltip = "HIDE_BLIZZARD_COMPARTMENT_TOOLTIP",
		},
		{
			key = "drawerColumns",
			label = "DRAWER_COLUMNS",
			tooltip = "DRAWER_COLUMNS_TOOLTIP",
			min = ns.DRAWER_COLUMNS_MIN,
			max = ns.DRAWER_COLUMNS_MAX,
			step = 1,
		},
	},
})
if not A then
	return -- Ordaen Core is too old; the player was told
end
ns.Addon = A
ns.Debug = A.Debug
function ns.Print(...)
	A:Print(...)
end

-- WoW APIs this addon uses that aren't confirmed on Forever yet (many retail/classic FrameXML helpers
-- are missing there). Dev mode logs which exist, so one in-game session settles it.
local UNCONFIRMED_APIS = {
	"C_AddOns.DisableAddOn",
	"DisableAddOn",
	"C_AddOns.GetNumAddOns",
	"C_AddOns.GetAddOnInfo",
	"Minimap.GetZoomLevels",
	"Minimap.SetTaskBlobRingScalar",
	"StaticPopupDialogs",
	"AddonCompartmentFrame.registeredAddons",
	-- Frames deeper than the API dump goes (Buttons.lua / Info.lua / Map.lua look them up).
	"MinimapCluster.Tracking.Button",
	"MinimapCluster.IndicatorFrame.MailFrame",
	"MinimapCluster.IndicatorFrame.CraftingOrderFrame",
	"MinimapCluster.MinimapContainer.PlayerCoords",
}

local function logApiAvailability()
	if not A.Debug.IsEnabled() then
		return
	end
	local parts = {}
	for _, path in ipairs(UNCONFIRMED_APIS) do
		local value = _G
		for key in path:gmatch("[^.]+") do
			value = type(value) == "table" and value[key] or nil
		end
		parts[#parts + 1] = path .. "=" .. (value ~= nil and type(value) or "missing")
	end
	A.Debug.Log("api: " .. table.concat(parts, ", "))
end

A:OnLoad(function(db)
	ns.ApplyDefaults(db)
	db.buttonAngles = ns.SanitizeAngles(db.buttonAngles)
	db.drawerButton = nil -- old free position of the drawer button (before the ring)
end)

-- Some pieces we hide come with load-on-demand Blizzard addons (the clock with Blizzard_TimeManager).
A:On("ADDON_LOADED", function(_, name)
	if name:find("^Blizzard_") then
		ns.Map.RetryHidden()
	end
end)

A:OnLogin(function()
	A.Debug.Log("PLAYER_LOGIN")
	logApiAvailability()
	if ns.Guard.Start(OrdaenMinimapDB, applyAll) then
		applyAll()
	end
	A:Print(L.LOADED:format(C_AddOns.GetAddOnMetadata(addonName, "Version") or "?", A.slash))
end)

A:OnReset(function()
	OrdaenMinimapDB.buttonAngles = ns.SanitizeAngles(nil)
	applyAll()
end)
