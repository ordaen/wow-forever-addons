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
---@field _watching table<string, boolean> claimed methods hooked ("Minimap:SetMaskTexture")
---@field _asked table<string, boolean> other addons the player was asked about this session
local Addon = ns.AddonClass

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

--- Run `fn(other, what)` for each conflict found: an addon in the spec's `conflicts` that is loaded (at login,
--- before the addon's OnLogin; what = "loaded together"), or another addon touching what this addon claims (a
--- global it defines, a Blizzard frame method it calls: what = "GetMinimapShape", "Minimap:SetMaskTexture").
--- `fn` adapts and records that with A:Conflict(other, "...", true).
---@param fn fun(other: string, what: string)
function Addon:OnConflict(fn)
	self._onConflict[#self._onConflict + 1] = self.Debug:Wrap(fn)
end

-- How many records the addon has about `other`.
local function records(addon, other)
	local n = 0
	for _, c in ipairs(addon._conflicts) do
		if c.other == other then
			n = n + 1
		end
	end
	return n
end

-- The dialog ---------------------------------------------------------------------------------------------------------

-- What a claim touches, in the player's words: the first pattern that matches `what` names it (locale key).
local AREAS = {
	{ "Tooltip", "CONFLICT_AREA_TOOLTIPS" },
	{ "Minimap", "CONFLICT_AREA_MINIMAP" },
}

-- An addon's title from its TOC, without colour codes (the dialog styles its own text).
local function title(name)
	local text = C_AddOns.GetAddOnMetadata(name, "Title") or name
	return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

-- Turn `name` off and reload (after combat). Without the API, tell the player how.
local function turnOff(addon, name)
	local disable = C_AddOns.DisableAddOn
	if type(disable) ~= "function" then
		addon:Print(ns.L.CONFLICT_TURN_OFF_MANUALLY:format(title(name)))
		return
	end
	addon.Debug:Logf("conflict: turning off %s and reloading", name)
	disable(name)
	addon:AfterCombat(ReloadUI)
end

local ASK_DELAY = 1 -- seconds

-- Ask the player which of the two to keep: Ordaen Core's one dialog for every addon (OrdaenCore.UI.Confirm), once
-- per other addon and session. "Decide later" (or Escape) keeps both until the next login, where it asks again.
local function ask(addon, other, what)
	local UI = Core.UI
	if addon._asked[other] or not (UI and UI.Confirm) then
		return
	end
	addon._asked[other] = true
	local L = ns.L
	local area = L.CONFLICT_AREA_OTHER
	for _, rule in ipairs(AREAS) do
		if what:find(rule[1]) then
			area = L[rule[2]]
			break
		end
	end
	local ours, theirs = title(addon.name), title(other)
	local function later()
		addon.Debug:Logf("conflict: decide later (%s)", other)
	end
	local dialog = UI.Confirm({
		text = L.CONFLICT_TEXT:format(ours, theirs, area),
		buttons = {
			{
				text = L.CONFLICT_KEEP:format(ours),
				onClick = function()
					turnOff(addon, other)
				end,
			},
			{
				text = L.CONFLICT_KEEP:format(theirs),
				onClick = function()
					turnOff(addon, addon.name)
				end,
			},
			{ text = L.CONFLICT_LATER, onClick = later },
		},
		onCancel = later,
	})
	-- A second later: not from inside the other addon's hook, and after login has settled.
	C_Timer.After(ASK_DELAY, function()
		dialog:Show()
	end)
end

-- A conflict found at login or at runtime, once per (other, what): the addon's OnConflict functions decide what to
-- do and record it (A:Conflict(other, "...", true)). If none recorded anything new about `other`, it is recorded as
-- not handled and the player is asked which addon to keep.
local function found(addon, other, what)
	local key = "found\n" .. other .. "\n" .. what
	if addon._conflictSeen[key] then
		return
	end
	addon._conflictSeen[key] = true
	local before = records(addon, other)
	for _, fn in ipairs(addon._onConflict) do
		Core._RunAs(addon, fn, other, what)
	end
	if records(addon, other) == before then
		addon:Conflict(other, what, false)
		ask(addon, other, what)
	end
end

--- The spec's conflicts that are loaded, and claimed globals someone else defined (Addon.lua, at login, before
--- the addon's OnLogin functions: before our own code redefines them).
function Addon:_CheckConflicts()
	for _, other in ipairs(self.spec.conflicts or {}) do
		if Core._IsAddOnLoaded(other) then
			found(self, other, "loaded together")
		end
	end
	self:_WatchClaims()
end

-- Claims (ns.CLAIMS, generated by the build from the addon's code: claims.rs in the ordaen CLI) ----------------------

-- Who made the call: the first addon on the stack below this watcher. An Ordaen addon (ours, e.g. from a raw
-- hooksecurefunc body, which Core._running doesn't mark) or Blizzard's code means no conflict: nil. Deeper frames
-- don't count, so an addon whose code merely triggered ours (Show -> our hook -> SetAlpha) isn't blamed.
local function caller()
	local stack = debugstack(2) or ""
	for line in stack:gmatch("[^\n]+") do
		local name = line:match("[Ii]nterface[/\\][Aa]dd[Oo]ns[/\\]([^/\\]+)[/\\]")
		if name and not line:find("OrdaenCore[/\\]Conflict%.lua") then
			if name:find("^Ordaen") or name:find("^Blizzard_") then
				return nil
			end
			return name
		end
	end
end

-- Who defined a claimed global: an addon other than ours and Blizzard's, or nil.
local function definer(addon, name)
	if _G[name] == nil then
		return nil
	end
	local secure, taintedBy = issecurevariable(name)
	if secure or not taintedBy or taintedBy == addon.name or taintedBy:find("^Ordaen") then
		return nil
	end
	return taintedBy
end

local RATE = 1 -- seconds between two stack checks of one claimed method (Blizzard may call it often)

-- Watch `object:method()` for calls by other addons: hooksecurefunc (the original stays untouched), our own calls
-- are skipped with one field read (Core._running), others cost one debugstack, at most once per RATE seconds.
local function watch(addon, object, method, what)
	local key = what
	if addon._watching[key] or type(object) ~= "table" or type(object[method]) ~= "function" then
		return
	end
	addon._watching[key] = true
	local last = -RATE
	hooksecurefunc(object, method, function()
		if Core._running then
			return -- an Ordaen addon's code: ours, not a conflict
		end
		local now = GetTime()
		if now - last < RATE then
			return
		end
		last = now
		local other = caller()
		if other then
			found(addon, other, what)
		end
	end)
end

local function resolve(path)
	local value = _G
	for part in path:gmatch("[^.]+") do
		if type(value) ~= "table" then
			return nil
		end
		value = value[part]
	end
	return value
end

--- Watch the build's claims of this addon (again after other addons load: their frames and globals appear then).
function Addon:_WatchClaims()
	local claims = self.ns.CLAIMS
	if not claims then
		return
	end
	for _, name in ipairs(claims.globals) do
		local other = definer(self, name)
		if other then
			found(self, other, name)
		end
	end
	for _, claim in ipairs(claims.methods) do
		local path, method = claim[1], claim[2]
		watch(self, resolve(path), method, path .. ":" .. method)
	end
	Core._WatchLoads()
end

--- Claim methods of a frame the build can't see (found at runtime, e.g. by one of several names): another addon
--- calling them is a conflict, like the build's claims.
---@param object table the frame
---@param methods string[] its method names
---@param name string|nil how to name it in reports (default: its frame name)
function Addon:Claim(object, methods, name)
	local label = name or (object.GetName and object:GetName()) or "?"
	for _, method in ipairs(methods) do
		watch(self, object, method, label .. ":" .. method)
	end
end

-- After login, an addon loading later may define a claimed global or create a claimed frame: check again then.
local watchingLoads = false
local function onLoaded(_, name)
	if name:find("^Ordaen") then
		return
	end
	for _, addon in ipairs(Core._addons) do
		if addon.loaded and addon.ns.CLAIMS then
			addon:_WatchClaims()
		end
	end
end

function Core._WatchLoads()
	if not watchingLoads then
		watchingLoads = true
		Core._On("ADDON_LOADED", onLoaded)
	end
end
