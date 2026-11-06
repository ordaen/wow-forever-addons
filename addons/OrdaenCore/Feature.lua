-- Ordaen Core: features. A feature is one part of an addon that can be on or off (the drawer, the clock). The
-- framework starts each one on its own after login, so an error in one is reported and the others still start
-- (CLAUDE.md, "Isolated features"), and switches it when its setting changes. What a feature registers through it
-- (events, unit events, tickers, hooks) runs only while it is on, and is released when it goes off: an addon
-- can't forget to unregister, and an off feature costs nothing but its hooks' first line.
--
--   local F = A:Feature("drawer", { setting = "drawerEnabled" })   -- on while db.drawerEnabled is true
--   local G = A:Feature("map", { when = function(db) return not ns.Guard.blocked end })
--   F:OnEnable(function(db) ... end)        -- build or show things
--   F:OnDisable(function() ... end)         -- hide what it showed; events, tickers and hooks stop by themselves
--   F:OnChange(function(key, value) ... end) -- a setting changed while it is on (re-apply)
--   F:On("BAG_UPDATE", onBags)              -- registered only while on
--   F:OnUnit("UNIT_AURA", "player", onAura)
--   local fast = F:Every(0.1, update)       -- ticks only while on (and until fast:Stop())
--   F:Hook(Minimap, "SetMaskTexture", fn)   -- hooksecurefunc once; fn runs only while on
--   F:Refresh()                             -- re-check `when` (the addon's own state changed)
--
-- No `setting` and no `when`: always on (after login). Both: on when both say so. Features start in the order made,
-- after the addon's OnLogin functions (which may decide what `when` says).
local _, ns = ...

---@class OrdaenCoreAPI
local Core = ns.Core
---@class OrdaenAddon
local Addon = ns.AddonClass

local call = Core._call

--- One part of an addon that can be on or off (A:Feature). Methods are called with `:`.
---@class OrdaenFeature
---@field addon OrdaenAddon
---@field name string
---@field setting string|nil a boolean setting (dotted key into the addon's db) that turns it on
---@field when (fun(db: table|nil): boolean)|nil
---@field conflicts string[]|nil addons that keep it off while loaded (Conflict.lua)
---@field enabled boolean
---@field private _onEnable function[]
---@field private _onDisable function[]
---@field _onChange function[] (read by Addon:_SettingChanged)
---@field private _events table[] { event, fn, unit } registered while on
---@field private _tickers OrdaenTicker[]
local Feature = {}
Feature.__index = Feature

local function settingValue(db, key)
	local value = db
	for part in key:gmatch("[^.]+") do
		if type(value) ~= "table" then
			return nil
		end
		value = value[part]
	end
	return value
end

local function wanted(feature)
	local addon = feature.addon
	if feature.setting and not settingValue(addon.db, feature.setting) then
		return false
	end
	if feature.when and not feature.when(addon.db) then
		return false
	end
	-- it would be on: a declared conflict that is loaded keeps it off (recorded once, as handled)
	local conflicts = feature.conflicts
	if conflicts then
		for i = 1, #conflicts do
			if Core._IsAddOnLoaded(conflicts[i]) then
				addon:Conflict(conflicts[i], "feature " .. feature.name .. " off", true)
				return false
			end
		end
	end
	return true
end

local function register(feature, entry)
	local addon = feature.addon
	if entry.unit then
		addon:OnUnit(entry.event, entry.unit, entry.fn)
	else
		addon:On(entry.event, entry.fn)
	end
end

local function unregister(feature, entry)
	local addon = feature.addon
	if entry.unit then
		addon:OffUnit(entry.event, entry.unit, entry.fn)
	else
		addon:Off(entry.event, entry.fn)
	end
end

-- A feature's functions, run as its addon's code (Core._running, see Conflict.lua).
local function runAll(feature, list, ...)
	local previous = Core._running
	Core._running = feature.addon
	for i = 1, #list do
		call(list[i], ...)
	end
	Core._running = previous
end

local function setEnabled(feature, on)
	if feature.enabled == on then
		return
	end
	feature.enabled = on
	local Debug = feature.addon.Debug
	Debug:Logf("feature %s %s", feature.name, on and "on" or "off")
	for _, entry in ipairs(feature._events) do
		if on then
			register(feature, entry)
		else
			unregister(feature, entry)
		end
	end
	for _, ticker in ipairs(feature._tickers) do
		Core._SyncTicker(ticker)
	end
	if on then
		runAll(feature, feature._onEnable, feature.addon.db)
	else
		runAll(feature, feature._onDisable)
	end
end

-- Switch on or off as the setting and `when` say. Through `call`: an error in `when` or OnEnable is reported and
-- the addon's other features still start.
local function sync(feature)
	call(function()
		setEnabled(feature, wanted(feature))
	end)
end

--- Make a feature of this addon. Call it once per feature, at load.
---@param name string short, for the dev log ("drawer")
---@param opts { setting: string?, when: (fun(db: table|nil): boolean)?, conflicts: string[]? }|nil
---@return OrdaenFeature
function Addon:Feature(name, opts)
	local feature = setmetatable({
		addon = self,
		name = name,
		setting = opts and opts.setting,
		when = opts and opts.when,
		conflicts = opts and opts.conflicts,
		enabled = false,
		_onEnable = {},
		_onDisable = {},
		_onChange = {},
		_events = {},
		_tickers = {},
	}, Feature)
	self._features[#self._features + 1] = feature
	if self.loaded and Core._IsLoggedIn() then
		sync(feature)
	end
	return feature
end

--- Bring every feature in line with its setting and `when` (after login, a setting change or a reset).
function Addon:_SyncFeatures()
	for _, feature in ipairs(self._features) do
		sync(feature)
	end
end

--- A setting of this addon changed (Settings.lua): switch the features it turns on or off, then tell the ones
--- that are on.
---@param key string
---@param value any
function Addon:_SettingChanged(key, value)
	for _, feature in ipairs(self._features) do
		sync(feature)
		if feature.enabled and feature.setting ~= key then
			runAll(feature, feature._onChange, key, value)
		end
	end
end

---@return boolean
function Feature:IsEnabled()
	return self.enabled
end

--- Re-check `when` (call it when the state it reads changed).
function Feature:Refresh()
	if self.addon.loaded and Core._IsLoggedIn() then
		sync(self)
	end
end

--- Run `fn(db)` each time the feature goes on (at login when it starts on).
---@param fn fun(db: table|nil)
function Feature:OnEnable(fn)
	self._onEnable[#self._onEnable + 1] = self.addon.Debug:Wrap(fn)
end

--- Run `fn()` each time the feature goes off. Its events and tickers stop by themselves.
---@param fn fun()
function Feature:OnDisable(fn)
	self._onDisable[#self._onDisable + 1] = self.addon.Debug:Wrap(fn)
end

--- Run `fn(key, value)` when another setting of the addon changes while the feature is on.
---@param fn fun(key: string, value: any)
function Feature:OnChange(fn)
	self._onChange[#self._onChange + 1] = self.addon.Debug:Wrap(fn)
end

local function find(feature, event, unit, fn)
	for i, entry in ipairs(feature._events) do
		if entry.event == event and entry.unit == unit and entry.fn == fn then
			return i
		end
	end
end

local function on(feature, event, unit, fn)
	if find(feature, event, unit, fn) then
		return -- already registered: OnEnable may call this every time
	end
	local entry = { event = event, unit = unit, fn = fn }
	feature._events[#feature._events + 1] = entry
	if feature.enabled then
		register(feature, entry)
	end
end

local function off(feature, event, unit, fn)
	local i = find(feature, event, unit, fn)
	if i then
		local entry = table.remove(feature._events, i)
		if feature.enabled then
			unregister(feature, entry)
		end
	end
end

--- Run `fn(event, ...)` on `event` while the feature is on (until Off).
---@param event WowEvent
---@param fn fun(event: string, ...)
function Feature:On(event, fn)
	on(self, event, nil, fn)
end

---@param event WowEvent
---@param fn fun(event: string, ...) the function given to On
function Feature:Off(event, fn)
	off(self, event, nil, fn)
end

--- Run `fn(event, unit, ...)` on `event` for `unit` while the feature is on (until OffUnit).
---@param event WowEvent
---@param unit string
---@param fn fun(event: string, unit: string, ...)
function Feature:OnUnit(event, unit, fn)
	on(self, event, unit, fn)
end

---@param event WowEvent
---@param unit string
---@param fn fun(event: string, unit: string, ...) the function given to OnUnit
function Feature:OffUnit(event, unit, fn)
	off(self, event, unit, fn)
end

--- Run `fn()` every `interval` seconds while the feature is on, until `:Stop()` (Timer.lua). Make it once.
---@param interval number seconds
---@param fn fun()
---@return OrdaenTicker
function Feature:Every(interval, fn)
	local ticker = Core._NewTicker(self.addon, interval, fn, self)
	self._tickers[#self._tickers + 1] = ticker
	return ticker
end

-- Hooks ------------------------------------------------------------------------------------------------------------

-- target -> method -> fn -> true: hooks already made (hooksecurefunc can't be undone, so never twice)
local hooked = setmetatable({}, { __mode = "k" })
local GLOBALS = {} -- the key in `hooked` for global functions

-- hooksecurefunc(target, method, hook), or hooksecurefunc(method, hook) for a global function (target nil).
local function hook(addon, target, method, fn, feature)
	local where = target or _G
	if type(where[method]) ~= "function" then
		addon.Debug:Warnf("hook: no function %s to hook", method)
		return false
	end
	local key = target or GLOBALS
	local byMethod = hooked[key] or {}
	hooked[key] = byMethod
	local fns = byMethod[method] or {}
	byMethod[method] = fns
	if fns[fn] then
		return true
	end
	fns[fn] = true
	local wrapped = addon.Debug:Wrap(fn)
	local body
	-- Protected (an error in our hook must not break Blizzard's caller), and run as the addon's code.
	if feature then
		body = function(...)
			if feature.enabled then
				Core._RunAs(addon, wrapped, ...)
			end
		end
	else
		body = function(...)
			Core._RunAs(addon, wrapped, ...)
		end
	end
	if target then
		hooksecurefunc(target, method, body)
	else
		hooksecurefunc(method, body)
	end
	return true
end

--- Run `fn(target, ...)` after `target:method(...)` (or after the global function `method(...)`: pass only the
--- method name and fn). Secure: the original is untouched, so Blizzard's code doesn't get tainted. Hooks can't be
--- removed; hooking the same function twice does nothing. Hook only rarely called functions and keep `fn` cheap
--- (CLAUDE.md, Performance).
---@param target table|string the object, or the global function's name
---@param method string|function the method name, or fn when hooking a global function
---@param fn function|nil
---@return boolean hooked false when there is no such function (logged in dev mode)
function Addon:Hook(target, method, fn)
	if type(target) == "string" then
		return hook(self, nil, target, method --[[@as function]], nil)
	end
	return hook(self, target, method --[[@as string]], fn --[[@as function]], nil)
end

--- Like Addon:Hook, but `fn` runs only while the feature is on.
---@param target table|string the object, or the global function's name
---@param method string|function the method name, or fn when hooking a global function
---@param fn function|nil
---@return boolean hooked
function Feature:Hook(target, method, fn)
	if type(target) == "string" then
		return hook(self.addon, nil, target, method --[[@as function]], self)
	end
	return hook(self.addon, target, method --[[@as string]], fn --[[@as function]], self)
end
