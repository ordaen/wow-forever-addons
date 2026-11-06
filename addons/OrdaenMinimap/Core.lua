local addonName, ns = ...
if not OrdaenCore.IsCompatible(addonName) then
	return
end
local Debug = OrdaenCore.NewDebug(addonName)
ns.Debug = Debug

local L = ns.L
local SLASH = "/om"

local function Print(...)
	local parts = {}
	for i = 1, select("#", ...) do
		parts[i] = tostring((select(i, ...)))
	end
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99" .. addonName .. "|r: " .. table.concat(parts, " "))
end
ns.Print = Print

-- The dev-mode dump ("Save for Claude & reload" in the Ordaen Dev window), through Debug.Snapshot.
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

local function applyAll()
	if ns.Guard.blocked then
		return
	end
	ns.Map.Apply(OrdaenMinimapDB)
	if not ns.Map.active then
		return
	end
	ns.Buttons.Apply(OrdaenMinimapDB)
	ns.Info.Apply(OrdaenMinimapDB)
	ns.Drawer.Apply(OrdaenMinimapDB)
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
	if not Debug.IsEnabled() then
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
	Debug.Log("api: " .. table.concat(parts, ", "))
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", Debug.Wrap(function(_, event, arg1)
	if event == "ADDON_LOADED" and arg1 == addonName then
		OrdaenMinimapDB = ns.ApplyDefaults(OrdaenMinimapDB or {})
		OrdaenMinimapDB.buttonAngles = ns.SanitizeAngles(OrdaenMinimapDB.buttonAngles)
		OrdaenMinimapDB.drawerButton = nil -- old free position of the drawer button (before the ring)
		Debug.Init(OrdaenMinimapDB, { slash = SLASH, print = Print, dump = dumpState })
		ns.Options.Register(OrdaenMinimapDB, applyAll)
	elseif event == "ADDON_LOADED" and arg1:find("^Blizzard_") then
		-- Some pieces we hide come with load-on-demand Blizzard addons (the clock with Blizzard_TimeManager).
		ns.Map.RetryHidden()
	elseif event == "PLAYER_LOGIN" then
		local version = C_AddOns.GetAddOnMetadata(addonName, "Version") or "?"
		Debug.Log("PLAYER_LOGIN")
		logApiAvailability()
		if ns.Guard.Start(OrdaenMinimapDB, applyAll) then
			applyAll()
		end
		Print(L.LOADED:format(version, SLASH))
	end
end))

local function printHelp()
	Print(L.HELP_HEADER)
	Print("  " .. L.HELP_OPEN:format(SLASH))
	Print("  " .. L.HELP_RESET:format(SLASH))
	for _, line in ipairs(Debug.HelpLines()) do
		Print("  " .. line)
	end
end

SLASH_ORDAENMINIMAP1 = SLASH
SLASH_ORDAENMINIMAP2 = "/ordaenminimap"
SlashCmdList.ORDAENMINIMAP = Debug.Wrap(function(msg)
	if Debug.HandleSlash(msg) then
		return
	end
	local cmd = ((msg or ""):match("^%s*(%S*)") or ""):lower()
	if cmd == "" then
		ns.Options.Open()
	elseif cmd == "reset" then
		for key, value in pairs(ns.DEFAULTS) do
			OrdaenMinimapDB[key] = value
		end
		OrdaenMinimapDB.conflictChoice = nil
		OrdaenMinimapDB.buttonAngles = {}
		applyAll()
		Print(L.RESET_DONE)
	else
		printHelp()
	end
end)
