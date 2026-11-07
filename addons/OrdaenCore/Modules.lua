-- Ordaen Core, modules (CLAUDE.md "Ordaen: one addon, modules"): every other Ordaen addon is a module, load on
-- demand, loaded by Ordaen while it's on. A module is an installed addon named Ordaen<Name> (no underscore: Ordaen's
-- own parts, OrdaenCore_UI and the dev addon OrdaenCore_Debug, aren't modules) that loads on demand.
--
-- On or off: Ordaen Core's setting `modules` (name -> false when off; a missing entry is on), account-wide for now
-- (per character comes with profiles). Startup: Ordaen's own ADDON_LOADED (CoreSettings.lua) loads the modules that
-- are on, before PLAYER_LOGIN, so the ones that take over Blizzard's frames are in place before Edit Mode lays them
-- out. Turning one on loads it at once (A:OnLogin then runs right away); turning one off needs a /reload, since code
-- can't be unloaded.
--
-- Cost: one pass over the addon list, once; nothing per frame or event.
local _, ns = ...

---@class OrdaenCoreAPI
local Core = ns.Core

local Modules = {}
Core.Modules = Modules

local list ---@type string[]|nil module names in the addon list's order (found once)
local failed = {} ---@type table<string, string> module -> why it didn't load (Blizzard's reason, e.g. "DISABLED")

--- The installed modules, in the addon list's order.
---@return string[]
function Modules.List()
	if not list then
		list = {}
		for i = 1, C_AddOns.GetNumAddOns() do
			local name = C_AddOns.GetAddOnInfo(i)
			if type(name) == "string" and name:find("^Ordaen%a+$") and name ~= "OrdaenCore"
				and C_AddOns.IsAddOnLoadOnDemand(i) then
				list[#list + 1] = name
			end
		end
	end
	return list
end

local function saved()
	local A = ns.CoreAddon
	return A and A:Get("modules") or nil
end

--- Whether a module is on (the player's choice; it may still not be loaded: see Modules.Why).
---@param name string
---@return boolean
function Modules.IsOn(name)
	local map = saved()
	return not (map and map[name] == false)
end

--- Why a module that is on isn't loaded: Blizzard's reason ("DISABLED" in the AddOns list, "MISSING", ...); nil if
--- it loaded or wasn't tried.
---@param name string
---@return string|nil
function Modules.Why(name)
	return failed[name]
end

local function load(name)
	local ok, loaded, reason = pcall(C_AddOns.LoadAddOn, name)
	if not ok then
		failed[name] = tostring(loaded)
		geterrorhandler()(loaded)
	elseif not loaded then
		failed[name] = reason or "?"
	else
		failed[name] = nil
	end
	local Debug = ns.CoreAddon and ns.CoreAddon.Debug
	if Debug then
		Debug:Logf("modules: %s %s", name, failed[name] and ("not loaded: " .. failed[name]) or "loaded")
	end
	return failed[name] == nil
end

--- Load every module that is on (Ordaen's ADDON_LOADED; each in its own protected call).
function Modules.LoadEnabled()
	for _, name in ipairs(Modules.List()) do
		if Modules.IsOn(name) and not C_AddOns.IsAddOnLoaded(name) then
			load(name)
		end
	end
end

--- Turn a module on (it loads now, after combat if in combat) or off (it stays loaded until a /reload).
---@param name string
---@param on boolean
---@return boolean reload true when a /reload is needed for the change to take effect
function Modules.Set(name, on)
	local A = ns.CoreAddon
	if not A then
		return false
	end
	local map = {} -- a player's action: one small table per switch
	for k, v in pairs(A:Get("modules") or {}) do
		map[k] = v
	end
	map[name] = not on and false or nil -- only "off" is saved
	A:Set("modules", map)
	if not on then
		return C_AddOns.IsAddOnLoaded(name)
	end
	if not C_AddOns.IsAddOnLoaded(name) then
		if InCombatLockdown() then
			A:AfterCombat(function()
				load(name)
			end)
		else
			load(name)
		end
	end
	return false
end
