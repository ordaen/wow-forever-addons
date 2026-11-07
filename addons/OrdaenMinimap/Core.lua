-- Ordaen Minimap's start: declares the addon to the Ordaen Core framework (SavedVariables, settings page, slash
-- commands) and starts the features once the settings and the world are there.
local addonName, ns = ...

local L = ns.L

-- The dev-mode dump ("Send state" in the Ordaen Dev window; Claude reads it with wow_dump).
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

-- The zone name and the clock are shown by the minimap or by Ordaen Panel, one at a time (the user's decision,
-- 2026-11-07; Core's A:Shared): turning one on in either addon turns the other's off. The holds are made below.
local zoneHold, clockHold
local sharing = false -- the other addon took or gave back an item: our own setting changes, no Claim/Release
local HOLDS = { showZone = function()
	return zoneHold
end, showClock = function()
	return clockHold
end }

local function onSettingChanged(key, value)
	local hold = HOLDS[key] and HOLDS[key]()
	if hold and not sharing then
		if value then
			hold:Claim()
		else
			hold:Release()
		end
	end
end

local A = OrdaenCore.NewAddon(addonName, ns, {
	db = "OrdaenMinimapDB",
	defaults = ns.DEFAULTS,
	slash = { "/om", "/ordaenminimap" },
	dump = dumpState,
	migrations = {
		function(db)
			db.drawerButton = nil -- the drawer button's old free position (before the button ring)
		end,
	},
	settings = {
		title = "SETTINGS_TITLE",
		onChange = onSettingChanged,
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
		{ key = "showZone", label = "SHOW_ZONE", tooltip = "SHOW_ZONE_TOOLTIP" },
		{ key = "showClock", label = "SHOW_CLOCK", tooltip = "SHOW_CLOCK_TOOLTIP" },
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

-- Our own setting, as if the player changed it on the page (the page reads the saved value when shown).
local function setShared(key, value)
	sharing = true
	OrdaenMinimapDB[key] = value
	A:_SettingChanged(key, value)
	sharing = false
end

-- Ordaen Panel shows it now: ours off. Its owner isn't loaded any more (fallback): ours back on.
zoneHold = A:Shared("zone", {
	lost = function()
		setShared("showZone", false)
	end,
	regained = function()
		setShared("showZone", true)
	end,
	fallback = true,
})
clockHold = A:Shared("clock", {
	lost = function()
		setShared("showClock", false)
	end,
	regained = function()
		setShared("showClock", true)
	end,
	fallback = true,
})
function ns.Print(...)
	A:Print(...)
end

-- WoW APIs this addon uses that aren't confirmed on Forever yet (many retail/classic FrameXML helpers
-- are missing there). Dev mode logs which exist, so one in-game session settles it.
local UNCONFIRMED_APIS = {
	"C_AddOns.GetNumAddOns",
	"C_AddOns.GetAddOnInfo",
	"Minimap.GetZoomLevels",
	"Minimap.SetTaskBlobRingScalar",
	"AddonCompartmentFrame.registeredAddons",
	-- Frames deeper than the API dump goes (Buttons.lua / Info.lua / Map.lua look them up).
	"MinimapCluster.Tracking.Button",
	"MinimapCluster.IndicatorFrame.MailFrame",
	"MinimapCluster.IndicatorFrame.CraftingOrderFrame",
	"MinimapCluster.MinimapContainer.PlayerCoords",
}

local function logApiAvailability()
	if not A.Debug:IsEnabled() then
		return
	end
	local parts = {}
	for _, path in ipairs(UNCONFIRMED_APIS) do
		---@type any
		local value = _G
		for key in path:gmatch("[^.]+") do
			value = type(value) == "table" and value[key] or nil
		end
		parts[#parts + 1] = path .. "=" .. (value ~= nil and type(value) or "missing")
	end
	A.Debug:Log("api: " .. table.concat(parts, ", "))
end

A:OnLoad(function(db)
	ns.ApplyDefaults(db)
	db.buttonAngles = ns.SanitizeAngles(db.buttonAngles)
	ns.Guard.Init(db)
end)

-- Features (Core Feature.lua): each starts in its own protected call after OnLogin, in this order, so one failing
-- is reported and the others still start. The map comes first: the others only run while we own it.
local function mapOwned()
	return ns.Map.active
end

local mapFeature = A:Feature("map", {
	when = function()
		return not ns.Guard.blocked
	end,
})
mapFeature:OnEnable(function(db)
	ns.Map.Apply(db)
end)
mapFeature:OnDisable(function()
	ns.Map.StepAside()
end)
mapFeature:OnChange(function()
	ns.Map.Apply(OrdaenMinimapDB)
end)

local buttonsFeature = A:Feature("buttons", { when = mapOwned })
buttonsFeature:OnEnable(function(db)
	ns.Buttons.Apply(db)
end)
buttonsFeature:OnChange(function()
	ns.Buttons.Apply(OrdaenMinimapDB)
end)

local infoFeature = A:Feature("info", { when = mapOwned })
infoFeature:OnEnable(function(db)
	ns.Info.Enable(infoFeature, db)
end)
infoFeature:OnDisable(function()
	ns.Info.Hide()
end)
infoFeature:OnChange(function()
	ns.Info.Apply(OrdaenMinimapDB)
end)

-- Off while MinimapButtonButton is loaded: both would grab the same buttons.
local drawerFeature = A:Feature("drawer", {
	setting = "drawerEnabled",
	when = mapOwned,
	conflicts = { "MinimapButtonButton" },
})
drawerFeature:OnEnable(function(db)
	ns.Drawer.Enable(db)
end)
drawerFeature:OnDisable(function()
	ns.Drawer.Disable()
end)
drawerFeature:OnChange(function()
	ns.Drawer.Apply(OrdaenMinimapDB)
end)

-- Guard decided (a conflict, or the player kept ours): the map goes on or off, the others follow it.
local function refreshFeatures()
	mapFeature:Refresh()
	buttonsFeature:Refresh()
	infoFeature:Refresh()
	drawerFeature:Refresh()
end

-- What the Core finds (an addon calling what we claim, e.g. Minimap:SetMaskTexture or GetMinimapShape) goes to
-- Guard, which steps aside and asks with its own dialog; recorded as handled, so the Core doesn't ask as well.
A:OnConflict(function(other, what)
	ns.Guard.Conflict(other, what)
	A:Conflict(other, what, true)
end)

-- Some pieces we hide come with load-on-demand Blizzard addons (the clock with Blizzard_TimeManager).
A:On("ADDON_LOADED", function(_, name)
	if name:find("^Blizzard_") then
		ns.Map.RetryHidden()
	end
end)

A:OnLogin(function()
	A.Debug:Log("PLAYER_LOGIN")
	logApiAvailability()
	ns.Guard.Start(refreshFeatures) -- decides Guard.blocked; the features start right after OnLogin
	zoneHold:Sync(OrdaenMinimapDB.showZone)
	clockHold:Sync(OrdaenMinimapDB.showClock)
	if OrdaenMinimapDB.drawerEnabled and C_AddOns.IsAddOnLoaded("MinimapButtonButton") then
		A:Print(L.DRAWER_MBB_WARNING)
	end
	A:Print(L.LOADED:format(C_AddOns.GetAddOnMetadata(addonName, "Version") or "?", A.slash))
end)

-- The features already went on or off for the defaults; the ones that are on re-apply them.
A:OnReset(function()
	local db = OrdaenMinimapDB
	db.buttonAngles = ns.SanitizeAngles(nil)
	ns.Guard.Init(db)
	if mapFeature:IsEnabled() then
		ns.Map.Apply(db)
	end
	if buttonsFeature:IsEnabled() then
		ns.Buttons.Apply(db)
	end
	if infoFeature:IsEnabled() then
		ns.Info.Apply(db)
	end
	if drawerFeature:IsEnabled() then
		ns.Drawer.Apply(db)
	end
end)
