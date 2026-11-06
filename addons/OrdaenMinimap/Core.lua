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

-- What /om dump saves (through Debug.Snapshot, so frames are described rather than stored).
local function dumpState()
	return {
		db = OrdaenMinimapDB,
		map = ns.Map.Describe(),
	}
end

local function applyAll()
	if ns.Guard.blocked then
		return
	end
	ns.Map.Apply(OrdaenMinimapDB)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", Debug.Wrap(function(_, event, arg1)
	if event == "ADDON_LOADED" and arg1 == addonName then
		OrdaenMinimapDB = ns.ApplyDefaults(OrdaenMinimapDB or {})
		Debug.Init(OrdaenMinimapDB, { slash = SLASH, print = Print, dump = dumpState })
		ns.Options.Register(OrdaenMinimapDB, applyAll)
	elseif event == "PLAYER_LOGIN" then
		local version = C_AddOns.GetAddOnMetadata(addonName, "Version") or "?"
		Debug.Log("PLAYER_LOGIN")
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
		applyAll()
		Print(L.RESET_DONE)
	else
		printHelp()
	end
end)
