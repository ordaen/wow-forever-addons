local addonName, ns = ...
if not OrdaenCore.IsCompatible(addonName) then
	return
end
local Debug = OrdaenCore.NewDebug(addonName)
ns.Debug = Debug

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
	}
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", Debug.Wrap(function(_, event, arg1)
	if event == "ADDON_LOADED" and arg1 == addonName then
		OrdaenMinimapDB = OrdaenMinimapDB or {}
		Debug.Init(OrdaenMinimapDB, { slash = SLASH, print = Print, dump = dumpState })
	elseif event == "PLAYER_LOGIN" then
		local version = C_AddOns.GetAddOnMetadata(addonName, "Version") or "?"
		Debug.Log("PLAYER_LOGIN")
		Print("v" .. version .. " loaded. Type " .. SLASH .. " for commands.")
	end
end))

SLASH_ORDAENMINIMAP1 = SLASH
SLASH_ORDAENMINIMAP2 = "/ordaenminimap"
SlashCmdList.ORDAENMINIMAP = Debug.Wrap(function(msg)
	if Debug.HandleSlash(msg) then
		return
	end
	Print("commands:")
	for _, line in ipairs(Debug.HelpLines()) do
		Print("  " .. line)
	end
end)
