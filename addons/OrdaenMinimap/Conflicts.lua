-- Conflict detection, pure part (no WoW API at load time, so specs can load it).
--
-- Two ways to find another addon that changes the minimap:
--   1. Known list: dedicated minimap addons, checked by name at login.
--   2. Generic: whoever else defines GetMinimapShape (issecurevariable names the addon), and
--      whoever calls a method on something we own (the call stack names the addon file).
-- Multi-purpose addons (ElvUI, EnhanceQoL, Leatrix Plus...) only conflict when their own minimap
-- option is on, so they are not in the known list; generic detection finds them when they do.
local addonName, ns = ...

-- Dedicated minimap addons: keeping Ordaen Minimap means disabling them.
ns.KNOWN_CONFLICTS = {
	"SexyMap",
	"BasicMinimap",
	"Chinchilla",
	"pMinimap",
}

-- Our own addons never count as conflicts.
local OWN = {
	[addonName] = true,
	OrdaenCore = true,
	OrdaenCore_Debug = true,
}

local function isForeign(name)
	return name and name ~= "" and not OWN[name] and not name:find("^Blizzard_")
end

--- The first loaded known conflict, skipping addons the user already chose to override.
---@param isLoaded fun(name: string): boolean
---@param choices table|nil OrdaenMinimapDB.conflictChoice
---@return string|nil
function ns.FindKnownConflict(isLoaded, choices)
	for _, name in ipairs(ns.KNOWN_CONFLICTS) do
		if isLoaded(name) and not (choices and choices[name] == "ours") then
			return name
		end
	end
	return nil
end

--- Whether `name` is a dedicated minimap addon (safe to disable when the user keeps ours).
function ns.IsDedicatedMinimapAddon(name)
	for _, known in ipairs(ns.KNOWN_CONFLICTS) do
		if known == name then
			return true
		end
	end
	return false
end

--- The addon behind a call, from a debugstack() text: the first frame in another addon's folder.
--- nil when the call came from Blizzard code or from our own addons.
---@param stack string|nil
---@return string|nil
function ns.AddonFromStack(stack)
	if type(stack) ~= "string" then
		return nil
	end
	for line in stack:gmatch("[^\n]+") do
		local name = line:match("[Ii]nterface[/\\][Aa]dd[Oo]ns[/\\]([^/\\]+)[/\\]")
		if name and isForeign(name) then
			return name
		end
	end
	return nil
end

--- Who defined a global, from issecurevariable's results (secure, taintedBy).
--- nil when Blizzard defined it (secure) or one of our own addons did.
---@return string|nil
function ns.OwnerFromTaint(secure, taintedBy)
	if secure or not isForeign(taintedBy) then
		return nil
	end
	return taintedBy
end

--- What "keep Ordaen Minimap" does for a conflicting addon.
---@param other string|nil addon name, nil when unknown
---@return string "disable" (turn the other addon off, reload) or "override" (stay on top, remember)
function ns.KeepOursAction(other)
	if other and ns.IsDedicatedMinimapAddon(other) then
		return "disable"
	end
	return "override"
end
