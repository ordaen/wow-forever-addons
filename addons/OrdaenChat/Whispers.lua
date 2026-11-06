-- Whispers in their own tabs: Blizzard's own "New whispers: new tab" option (Options > Social), one tab per
-- conversation, for character and Battle.net whispers. Set once with the default tabs (Tabs.Apply); the player
-- changes it in Blizzard's options afterwards and we don't set it again. Nothing runs.
local _, ns = ...

local Whispers = {}
ns.Whispers = Whispers

-- CVars aren't in the API dump (unconfirmed: dev mode logs what the client says; Core.lua).
local MODES = { "whisperMode", "bnWhisperMode" }

--- Open each whisper conversation in its own tab.
function Whispers.UseTabs()
	for _, cvar in ipairs(MODES) do
		local ok = C_CVar.SetCVar(cvar, "popout")
		ns.Debug:Logf("whispers: %s = popout (%s), now %s", cvar, tostring(ok), tostring(C_CVar.GetCVar(cvar)))
	end
end

--- What the dev-mode dump records.
function Whispers.Describe()
	local modes = {}
	for _, cvar in ipairs(MODES) do
		modes[cvar] = C_CVar.GetCVar(cvar) or false
	end
	return modes
end
