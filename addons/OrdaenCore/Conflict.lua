-- Ordaen Core: conflicts between our addons and third-party ones. Declared in code, so the build can list them in
-- the TOC (`## X-Ordaen-Conflicts`, read by the companion from disk) and the framework can check them at login:
--
--   local A = OrdaenCore.NewAddon(addonName, ns, { conflicts = { "SexyMap" }, ... })
--   A:OnConflict(function(other) ... A:Conflict(other, "map left to SexyMap", true) end) -- at login, if loaded
--   A:Feature("drawer", { conflicts = { "MinimapButtonButton" } }) -- stays off while it is loaded (recorded)
--   A:Conflict("SomeAddon", "moved our button", false)                -- found at runtime (hooks, checks)
--
-- `handled`: true when we adapted (a feature off, a frame left alone), false when something is broken. Records are
-- kept in memory only (never SavedVariables), at most MAX per addon; dev mode sends each to the companion.
local _, ns = ...

---@class OrdaenCoreAPI
local Core = ns.Core
---@class OrdaenAddon
---@field _conflicts OrdaenConflict[]
---@field _conflictSeen table<string, boolean> other .. "\n" .. what
---@field _onConflict function[]
local Addon = ns.AddonClass

local call = Core._call
local MAX = 20

--- Whether the addon (folder name) is loaded or being loaded.
---@param name string
---@return boolean
function Core._IsAddOnLoaded(name)
	local loaded = C_AddOns.IsAddOnLoaded(name)
	return loaded and true or false
end

---@class OrdaenConflict
---@field other string the third-party addon
---@field what string what happened, for developers (English)
---@field handled boolean

--- Record a conflict with another addon (once per other addon and `what`).
---@param other string the other addon's folder name
---@param what string what happened, short, for developers (English, not shown to players)
---@param handled boolean true when we adapted, false when something is broken
function Addon:Conflict(other, what, handled)
	local key = other .. "\n" .. what
	local seen = self._conflictSeen
	if seen[key] or #self._conflicts >= MAX then
		return
	end
	seen[key] = true
	self._conflicts[#self._conflicts + 1] = { other = other, what = what, handled = handled }
	self.Debug:Conflict(other, what, handled)
end

--- The conflicts recorded so far (don't change the list).
---@return OrdaenConflict[]
function Addon:Conflicts()
	return self._conflicts
end

--- Run `fn(other)` at login for each addon in the spec's `conflicts` that is loaded, before the addon's OnLogin
--- functions. `fn` adapts and reports with A:Conflict; without any OnConflict function the conflict is recorded
--- as not handled.
---@param fn fun(other: string)
function Addon:OnConflict(fn)
	self._onConflict[#self._onConflict + 1] = self.Debug:Wrap(fn)
end

--- The spec's conflicts that are loaded (Addon.lua, at login).
function Addon:_CheckConflicts()
	local declared = self.spec.conflicts
	if not declared then
		return
	end
	for _, other in ipairs(declared) do
		if Core._IsAddOnLoaded(other) then
			if #self._onConflict == 0 then
				self:Conflict(other, "loaded together", false)
			end
			for _, fn in ipairs(self._onConflict) do
				call(fn, other)
			end
		end
	end
end
