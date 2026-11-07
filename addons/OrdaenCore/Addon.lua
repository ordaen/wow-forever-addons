-- Ordaen Core: the addon framework. An addon declares what it needs once and the framework does the wiring:
-- SavedVariables with defaults, its lifecycle, events on its own event frame, slash commands (help and reset built
-- in), a settings page, an addon compartment entry, and work held back until combat ends.
--
--   local addonName, ns = ...
--   local A = OrdaenCore.NewAddon(addonName, ns, {
--   	db = "MyAddonDB",                       -- SavedVariables (the build writes ## SavedVariables from this)
--   	defaults = { scale = 1, enabled = true }, -- filled in where missing, never overwritten
--   	slash = { "/ma", "/myaddon" },
--   	settings = { title = "SETTINGS_TITLE", { key = "enabled", label = "ENABLED" } }, -- see Settings.lua
--   })
--   if not A then return end                   -- Ordaen Core is too old (the player was told)
--   A:OnLoad(function(db) ... end)             -- settings are there
--   A:OnLogin(function() ... end)              -- the world is there
--   A:On("ZONE_CHANGED", function(event, ...) ... end)
--   A:OnUnit("UNIT_AURA", "player", function(event, unit, ...) ... end)
--   local F = A:Feature("drawer", { setting = "drawerEnabled" }) -- Feature.lua: on/off with its events,
--                                                                -- tickers and hooks; Timer.lua: A:Every
--
-- An addon with a settings.jsonc (ns.SETTINGS_SCHEMA, docs/reference/settings.md) gives no db, defaults or
-- settings here: the manifest names them, Ordaen Core keeps the values (SettingsStore.lua: only the player's
-- choices are saved, everything else is the theme's default) and builds the page. It reads `db.key` as usual,
-- writes with `A:Set(key, value)`, and hears changes in `onChange = fn(key, value)` (features hear first).
--
-- Spec fields besides those above: `charDb`/`charDefaults` (per character), `dump` (dev-mode state), and
-- `migrations`/`charMigrations`: arrays of `function(db)`, each run once, in order, on SavedVariables saved before
-- it existed (`db._schema` counts the ones done; new SavedVariables start counted). Append only, never reorder.
--
-- The spec must be a table written in the file (the build reads `db`/`charDb` from it). Strings shown to players
-- (labels, help) are locale keys of the addon (`ns.L`). Cost: one event frame per addon (plus one per unit it has
-- unit events for), handlers in plain arrays (no tables or closures per event), nothing runs per frame.
local _, ns = ...

---@class OrdaenCoreAPI
---@field _running OrdaenAddon|nil the Ordaen addon whose code runs now (set by the framework's dispatch)
local Core = ns.Core
local L = ns.L

--- The framework object of one addon (OrdaenCore.NewAddon). Methods are called with `:` (lua-language-server
--- reports a `.` call as a type error: the first argument would land in self).
---@class OrdaenAddon
---@field name string
---@field ns table the addon's namespace
---@field spec table the NewAddon spec
---@field L table<string, string> the addon's locale (ns.L)
---@field Debug OrdaenDebug the addon's debug kit
---@field db table|nil its SavedVariables, after OnLoad
---@field charDb table|nil its per-character SavedVariables, after OnLoad
---@field slash string|nil its main slash command
---@field loaded boolean
---@field private _onLoad function[]|nil
---@field private _onLogin function[]|nil
---@field private _onReset function[]
---@field private _commands table<string, fun(rest: string)>
---@field private _help string[]
---@field private _wrapped table<function, function>
---@field private _printParts string[]
---@field _features OrdaenFeature[] Feature.lua
---@field _conflictCalls table<string, integer> other addon -> A:Conflict calls about it (Conflict.lua)
---@field _events OrdaenEventFrame its own event frame (CPU billed to it)
---@field _unitEvents table<string, OrdaenEventFrame> unit -> its own frame for that unit's events
---@field _clock OrdaenClock its tickers and C_Timer chain (Timer.lua)
---@field _settingsCategory table|nil set by Settings.lua
---@field _store OrdaenSettingsStore|nil the values, for an addon with a settings manifest (SettingsStore.lua)
local Addon = {}
Addon.__index = Addon

local loggedIn = false
local afterCombat -- array of functions waiting for PLAYER_REGEN_ENABLED

-- Each handler runs through securecallfunction when the client has it: an error in one addon's handler is
-- reported (BugSack, Blizzard, dev mode) and the other handlers of the event still run.
local call = securecallfunction or function(fn, ...)
	return fn(...)
end
Core._call = call

-- An event frame and its handlers: event -> array of { fn = ..., addon = ..., Debug = ... }. Lists are replaced
-- (never changed) by add/remove, so On/Off from inside a handler can't disturb the dispatch loop that is running.
-- `unit` set: a frame for one unit's events (RegisterUnitEvent), so the game filters them and we never see the rest.
---@class OrdaenEventFrame
---@field frame Frame|nil
---@field handlers table<string, table[]>
---@field unit string|nil

-- Dev mode records (the dev addon's state sync: what the framework did for each addon; Claude reads it with
-- wow_dump). The framework calls Core._DevEventTime, _DevHook and _DevTicker only inside `if <x>.Debug:IsEnabled()
-- then ... end` blocks, which release builds strip; the dev addon OrdaenCore_Debug defines them (its Sync.lua), and
-- IsEnabled is true only with it loaded. So players' builds carry none of this code.

local function dispatch(self, event, ...)
	local list = self.events.handlers[event]
	if list then
		for i = 1, #list do
			local entry = list[i]
			-- Dev builds: the companion shows which addon handled what. Release builds strip this block.
			if entry.Debug:TraceEnabled() then
				entry.Debug:Trace("event", event)
			end
			-- Dev builds: each handler's time per addon and event (Core._dev). Release builds strip both blocks; the
			-- start time lives on the entry, so nothing is left behind in release code.
			if entry.Debug:IsEnabled() then
				entry.started = debugprofilestop()
			end
			-- Core._running: which Ordaen addon's code runs (Conflict.lua tells our own calls from others' by it)
			local previous = Core._running
			Core._running = entry.addon
			call(entry.fn, event, ...)
			Core._running = previous
			if entry.Debug:IsEnabled() then
				Core._DevEventTime(entry, event)
			end
		end
	end
end

-- Who pays for an event (CPU attribution, the AddOns profiler and wow_perf): WoW bills a script handler's whole call
-- tree to the addon whose code was running when the frame carrying it was created (EllesmereUI's finding, tested in
-- game). So each addon has its own event frames, made by NewAddon while the addon's own file runs, and the Core's
-- shared frame only carries the framework's own handlers.
---@type OrdaenEventFrame
local shared = { handlers = {} }

local function frameOf(events)
	local frame = events.frame
	if not frame then
		frame = CreateFrame("Frame") --[[@as Frame]]
		---@diagnostic disable-next-line: inject-field
		frame.events = events
		frame:SetScript("OnEvent", dispatch)
		events.frame = frame
	end
	return frame
end

local function addHandler(event, fn, addon, events)
	events = events or shared
	local old = events.handlers[event]
	local list = {}
	if old then
		for i = 1, #old do
			list[i] = old[i]
		end
	elseif events.unit then
		frameOf(events):RegisterUnitEvent(event, events.unit)
	else
		frameOf(events):RegisterEvent(event)
	end
	-- Debug: the owning addon's kit (the Core's for the framework's own handlers), for tracing in dev builds.
	list[#list + 1] = { fn = fn, addon = addon, Debug = addon and addon.Debug or Core.NewDebug("OrdaenCore") }
	events.handlers[event] = list
end

local function removeHandler(event, fn, events)
	events = events or shared
	local old = events.handlers[event]
	if not old then
		return
	end
	local list = {}
	for i = 1, #old do
		if old[i].fn ~= fn then
			list[#list + 1] = old[i]
		end
	end
	if #list == 0 then
		events.handlers[event] = nil
		events.frame:UnregisterEvent(event)
	else
		events.handlers[event] = list
	end
end

--- The framework's own handler on the shared event frame (not tied to an addon).
---@param event WowEvent
---@param fn fun(event: string, ...)
function Core._On(event, fn)
	addHandler(event, fn, nil)
end

-- An addon's event frame for one unit's events, made on first use (units aren't known at load, so this one is
-- created when its first handler is added: billed to whichever addon's code runs then, usually its own).
local function unitEvents(addon, unit)
	local frames = addon._unitEvents
	local events = frames[unit]
	if not events then
		events = { handlers = {}, unit = unit }
		frames[unit] = events
	end
	return events
end

local function copyDefaults(target, defaults)
	for key, value in pairs(defaults) do
		if target[key] == nil then
			if type(value) == "table" then
				target[key] = copyDefaults({}, value)
			else
				target[key] = value
			end
		elseif type(value) == "table" and type(target[key]) == "table" then
			copyDefaults(target[key], value)
		end
	end
	return target
end
Core.CopyDefaults = copyDefaults

local function runAll(list, ...)
	if list then
		for i = 1, #list do
			call(list[i], ...)
		end
	end
end

-- runAll with `addon` marked as running (Core._running).
local function runAs(addon, list, ...)
	local previous = Core._running
	Core._running = addon
	runAll(list, ...)
	Core._running = previous
end

--- Run `fn(...)` (protected) as `addon`'s code: the framework's own callers of addon code use this, so a hook on a
--- claimed Blizzard method can tell our calls from other addons' (Conflict.lua) with one field read.
---@param addon OrdaenAddon
---@param fn function
function Core._RunAs(addon, fn, ...)
	local previous = Core._running
	Core._running = addon
	call(fn, ...)
	Core._running = previous
end

--- Print a line in chat, prefixed with the addon's name.
function Addon:Print(...)
	local n = select("#", ...)
	local parts = self._printParts
	for i = 1, n do
		parts[i] = tostring((select(i, ...)))
	end
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99" .. self.name .. "|r: " .. table.concat(parts, " ", 1, n))
end

--- Run `fn(db, charDb)` when the addon's SavedVariables are loaded (its ADDON_LOADED).
---@param fn fun(db: table, charDb: table|nil) db is nil only for an addon that declares no `db`
function Addon:OnLoad(fn)
	if self.loaded then
		call(fn, self.db, self.charDb)
	else
		self._onLoad[#self._onLoad + 1] = fn
	end
end

--- Run `fn()` at PLAYER_LOGIN, or right away if the player is already in the world (load-on-demand addons).
---@param fn fun()
function Addon:OnLogin(fn)
	if self.loaded and loggedIn then
		call(fn)
	else
		self._onLogin[#self._onLogin + 1] = fn
	end
end

--- Run `fn(event, ...)` on `event` until Off. Register only while a feature needs it.
---@param event WowEvent
---@param fn fun(event: string, ...)
function Addon:On(event, fn)
	local Debug = self.Debug
	if Debug:IsEnabled() then
		-- forever-lint FL9 catches a literal name; this one, a name from a variable (an event list)
		if event:find("^UNIT_") then
			Debug:Warnf("%s registered for every unit: use OnUnit with the units you need", event)
		end
	end
	local wrapped = self._wrapped[fn] or Debug:Wrap(fn)
	self._wrapped[fn] = wrapped
	addHandler(event, wrapped, self, self._events)
end

--- Stop running `fn` on `event`.
---@param event WowEvent
---@param fn fun(event: string, ...) the function given to On
function Addon:Off(event, fn)
	local wrapped = self._wrapped[fn]
	if wrapped then
		removeHandler(event, wrapped, self._events)
	end
end

--- Run `fn(event, unit, ...)` on `event` for `unit` only ("player", "target", "party1", ...) until OffUnit. The
--- game filters by unit, so other units' events (UNIT_AURA for every nameplate) never reach Lua.
---@param event WowEvent
---@param unit string
---@param fn fun(event: string, unit: string, ...)
function Addon:OnUnit(event, unit, fn)
	local wrapped = self._wrapped[fn] or self.Debug:Wrap(fn)
	self._wrapped[fn] = wrapped
	addHandler(event, wrapped, self, unitEvents(self, unit))
end

--- Stop running `fn` on `event` for `unit`.
---@param event WowEvent
---@param unit string
---@param fn fun(event: string, unit: string, ...) the function given to OnUnit
function Addon:OffUnit(event, unit, fn)
	local wrapped = self._wrapped[fn]
	local events = self._unitEvents[unit]
	if wrapped and events then
		removeHandler(event, wrapped, events)
	end
end

local function onCombatEnd()
	local queue = afterCombat
	afterCombat = nil
	removeHandler("PLAYER_REGEN_ENABLED", onCombatEnd)
	runAll(queue)
end

--- Run `fn()` now, or when combat ends if protected frames are locked.
---@param fn fun()
function Addon:AfterCombat(fn)
	if not InCombatLockdown() then
		call(fn)
		return
	end
	if not afterCombat then
		afterCombat = {}
		addHandler("PLAYER_REGEN_ENABLED", onCombatEnd)
	end
	afterCombat[#afterCombat + 1] = fn
end

--- Add a slash subcommand: `/<slash> <name> <rest>` runs `fn(rest)`. `help` is a locale key with one %s (the
--- slash command), shown by `/<slash> help`.
---@param name string
---@param fn fun(rest: string)
---@param help string|nil locale key
function Addon:Command(name, fn, help)
	self._commands[name:lower()] = fn
	if help then
		self._help[#self._help + 1] = help
	end
end

--- Run `fn()` after `/<slash> reset` restored the default settings.
---@param fn fun()
function Addon:OnReset(fn)
	self._onReset[#self._onReset + 1] = fn
end

--- An entry in Blizzard's addon compartment (the minimap's addon menu; Ordaen Minimap's drawer shows it too).
---@param entry table { icon = texture, onClick = fn(mouseButton), onEnter = fn(menuButton), onLeave = fn(menuButton) }
function Addon:Compartment(entry)
	if not (AddonCompartmentFrame and AddonCompartmentFrame.RegisterAddon) then
		return
	end
	local Debug = self.Debug
	AddonCompartmentFrame:RegisterAddon({
		text = C_AddOns.GetAddOnMetadata(self.name, "Title") or self.name,
		icon = entry.icon or C_AddOns.GetAddOnMetadata(self.name, "IconTexture"),
		notCheckable = true,
		registerForAnyClick = true,
		func = entry.onClick and Debug:Wrap(function(_, inputData)
			entry.onClick(inputData and inputData.buttonName)
		end),
		funcOnEnter = entry.onEnter and Debug:Wrap(function(button)
			entry.onEnter(button)
		end),
		funcOnLeave = entry.onLeave and Debug:Wrap(function(button)
			entry.onLeave(button)
		end),
	})
end

--- A setting's value (a dotted key reads a nested table): the player's, else the theme's default.
---@param key string
---@return any
function Addon:Get(key)
	if self._store then
		return self._store:Get(key)
	end
	local tbl, leaf = Core.Settings.Resolve(self.db or {}, key)
	return tbl and tbl[leaf]
end

--- Save the player's value for a setting of the manifest, if valid; features and `onChange` hear of it.
---@param key string
---@param value any
---@return boolean saved false when the value isn't valid for the setting (or the addon has no manifest)
function Addon:Set(key, value)
	return self._store ~= nil and self._store:Set(key, value)
end

--- Forget the player's value for a setting of the manifest: the theme's default applies again.
---@param key string
function Addon:Reset(key)
	if self._store then
		self._store:Reset(key)
	end
end

--- Open the addon's settings page (if it declared one).
function Addon:OpenSettings()
	if self._settingsCategory then
		Settings.OpenToCategory(self._settingsCategory:GetID())
	end
end

local function printHelp(addon)
	local slash = addon.slash
	addon:Print(L.HELP_HEADER)
	if addon._settingsCategory then
		addon:Print("  " .. L.HELP_OPEN:format(slash))
	end
	if addon.db then
		addon:Print("  " .. L.HELP_RESET:format(slash))
	end
	for _, key in ipairs(addon._help) do
		addon:Print("  " .. addon.L[key]:format(slash))
	end
	for _, line in ipairs(addon.Debug:HelpLines()) do
		addon:Print("  " .. line)
	end
end

-- Empty `t` for a reset, but keep the nested tables the defaults have: a settings control is bound to its table
-- (db.ui for "ui.theme"), so replacing it would leave the control writing to a table nobody reads.
local function clear(t, defaults)
	for key, value in pairs(t) do
		if type(value) == "table" and type(defaults[key]) == "table" then
			clear(value, defaults[key])
		else
			t[key] = nil
		end
	end
end

local function reset(addon)
	local db = addon.db
	if addon._store then
		addon._store:ResetAll() -- the player's values go (each change is announced), `_schema` stays
	else
		local schema = db._schema -- the migrations stay done: the defaults are the newest shape
		clear(db, addon.spec.defaults or {})
		copyDefaults(db, addon.spec.defaults or {})
		db._schema = schema
		if Core.Settings then
			Core.Settings.Sanitize(addon)
		end
	end
	addon:_SyncFeatures()
	runAs(addon, addon._onReset)
	addon:Print(L.RESET_DONE)
end

local function registerSlash(addon)
	local commands = addon.spec.slash
	if not commands then
		return
	end
	local key = addon.name:upper() -- SLASH_ORDAENMINIMAP1, SlashCmdList.ORDAENMINIMAP
	for i, command in ipairs(commands) do
		rawset(_G, "SLASH_" .. key .. i, command)
	end
	addon.slash = commands[1]
	local Debug = addon.Debug
	SlashCmdList[key] = Debug:Wrap(function(msg)
		if Debug:TraceEnabled() then
			Debug:Trace("slash", msg)
		end
		if Debug:HandleSlash(msg) then
			return
		end
		local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
		cmd = cmd:lower()
		local fn = addon._commands[cmd]
		if fn then
			fn(rest)
		elseif cmd == "" and addon._settingsCategory then
			addon:OpenSettings()
		elseif cmd == "reset" and addon.db then
			reset(addon)
		else
			printHelp(addon)
		end
	end)
end

-- Run the migrations `db` hasn't had, in order. One that fails is reported and stops the rest; they run again at
-- the next load (so a migration must cope with being run on data it already half changed).
local function migrate(db, migrations)
	local done = db._schema or 0
	local handler = geterrorhandler()
	for i = done + 1, #migrations do
		local migration = migrations[i]
		if not xpcall(function()
			migration(db)
		end, handler) then
			return
		end
		db._schema = i
	end
end

local function savedVariables(name, defaults, migrations)
	local db = _G[name]
	if type(db) ~= "table" then
		db = {}
		rawset(_G, name, db)
		if migrations then
			db._schema = #migrations -- nothing old to change
		end
	elseif migrations then
		migrate(db, migrations)
	end
	return copyDefaults(db, defaults or {})
end

-- A SavedVariables table as saved (created when new), with its migrations run; no defaults filled.
local function rawSaved(name, migrations)
	local db = _G[name]
	if type(db) ~= "table" then
		db = {}
		rawset(_G, name, db)
		if migrations then
			db._schema = #migrations
		end
	elseif migrations then
		migrate(db, migrations)
	end
	return db
end

-- An addon with a settings manifest: migrations on the raw tables, then the store binds them to the schema (reads
-- fall back to the theme's defaults, invalid values go). Each change reaches the features, then `spec.onChange`.
local function bindSettings(addon, schema)
	local spec = addon.spec
	local db = rawSaved(schema.db, spec.migrations)
	local charDb = schema.charDb and rawSaved(schema.charDb, spec.charMigrations) or nil
	local store = Core._SettingsStore.Bind(schema, db, charDb)
	local onChange = spec.onChange
	local Debug = addon.Debug
	store.onChange = function(key, value)
		if Debug:TraceEnabled() then
			Debug:Trace("setting", key .. "=" .. tostring(value))
		end
		addon:_SettingChanged(key, value)
		if onChange then
			Core._RunAs(addon, onChange, key, value)
		end
	end
	addon._store, addon.db, addon.charDb = store, db, charDb
end

local function login(addon)
	addon:_CheckConflicts() -- Conflict.lua: the declared ones, before OnLogin
	runAs(addon, addon._onLogin)
	addon._onLogin = nil
	addon:_SyncFeatures() -- features start after the addon's own OnLogin (it may decide what may run)
end

local function onAddonLoaded(addon)
	local spec = addon.spec
	local schema = addon.ns.SETTINGS_SCHEMA
	if schema then
		bindSettings(addon, schema)
	else
		if spec.db then
			addon.db = savedVariables(spec.db, spec.defaults, spec.migrations)
		end
		if spec.charDb then
			addon.charDb = savedVariables(spec.charDb, spec.charDefaults, spec.charMigrations)
		end
	end
	addon.Debug:Init(addon.db or {}, {
		slash = addon.spec.slash and addon.spec.slash[1],
		print = function(...)
			addon:Print(...)
		end,
		dump = spec.dump,
	})
	if schema and Core.Settings then
		Core.Settings.RegisterSchema(addon, schema)
	elseif spec.settings and Core.Settings then
		Core.Settings.Register(addon)
	end
	registerSlash(addon)
	addon.loaded = true
	runAs(addon, addon._onLoad, addon.db, addon.charDb)
	addon._onLoad = nil
	if loggedIn then
		login(addon)
	end
end

-- An addon's ADDON_LOADED and PLAYER_LOGIN, on its own event frame (so its OnLoad, OnLogin and features' start are
-- billed to it). One closure per addon, made in NewAddon.
local function lifecycle(addon)
	local handler
	handler = function(event, arg1)
		if event == "ADDON_LOADED" then
			if arg1 == addon.name then
				removeHandler("ADDON_LOADED", handler, addon._events)
				onAddonLoaded(addon)
			end
		elseif event == "PLAYER_LOGIN" then
			removeHandler("PLAYER_LOGIN", handler, addon._events)
			loggedIn = true
			if addon.loaded then
				login(addon)
			end
		end
	end
	return handler
end

Core._addons = {}

--- An Ordaen addon loaded by Ordaen from inside its own ADDON_LOADED (Modules.lua): the game doesn't deliver the
--- loaded addon's ADDON_LOADED to the frame it registered while loading (seen 2026-11-07: every module loaded, none
--- started), so Ordaen starts it here. Nothing when it already started (the event came after all).
---@param name string
function Core._Loaded(name)
	for _, addon in ipairs(Core._addons) do
		if addon.name == name and not addon.loaded and addon._lifecycle then
			removeHandler("ADDON_LOADED", addon._lifecycle, addon._events)
			Core._RunAs(addon, onAddonLoaded, addon)
		end
	end
end

---@return boolean
function Core._IsLoggedIn()
	return loggedIn
end

-- The loading screen: addons load under it, so it starts as up. Something shown under it may be gone when it ends
-- (the conflict dialog after the first login with a newly enabled addon, 2026-11-06).
local loadingScreen = true
local afterLoading = {} -- functions waiting for the loading screen to end

-- Whichever comes first ends it: PLAYER_ENTERING_WORLD (the world is ready; after a /reload Forever sent
-- LOADING_SCREEN_DISABLED only much later, so a dialog waited, 2026-11-06) or LOADING_SCREEN_DISABLED. Dev mode logs
-- each with its time, to see how the client orders them.
local function onLoadingScreen(event)
	local Debug = Core.NewDebug("OrdaenCore")
	Debug:Logf("%s at %.1f", event, GetTime())
	if event == "LOADING_SCREEN_ENABLED" then
		loadingScreen = true
		return
	end
	if not loadingScreen then
		return
	end
	loadingScreen = false
	local queue = afterLoading
	afterLoading = {}
	runAll(queue)
end
local watchingLoadingScreen = false -- registered with the first addon (NewAddon), under the loading screen

--- Run `fn()` now, or when the loading screen ends if one is up (for anything the player must see).
---@param fn fun()
function Core._AfterLoadingScreen(fn)
	if loadingScreen then
		afterLoading[#afterLoading + 1] = fn
	else
		call(fn)
	end
end

--- Create the framework object for an addon. Call it once, at the top level of one of its files.
---@param addonName string the first value of `...`
---@param addonNs table the addon's namespace (second value of `...`)
---@param spec table see the top of this file
---@return OrdaenAddon|nil addon nil when this Ordaen Core is too old for the addon (the player was told)
function Core.NewAddon(addonName, addonNs, spec)
	if not Core.IsCompatible(addonName) then
		return nil
	end
	local addon = setmetatable({
		name = addonName,
		ns = addonNs,
		spec = spec,
		L = addonNs.L or setmetatable({}, {
			__index = function(_, key)
				return key
			end,
		}),
		Debug = Core.NewDebug(addonName),
		_onLoad = {},
		_onLogin = {},
		_onReset = {},
		_commands = {},
		_help = {},
		_wrapped = {},
		_printParts = {},
		_features = {},
		_conflicts = {},
		_conflictSeen = {},
		_conflictCalls = {}, -- other addon -> A:Conflict calls about it (Conflict.lua)
		_onConflict = {},
		_watching = {},
		_asked = {},
		_events = { handlers = {} },
		_unitEvents = {},
	}, Addon)
	Core._addons[#Core._addons + 1] = addon
	-- Its own event frame and clock, made now: this runs in the addon's own file, so WoW bills them to the addon.
	frameOf(addon._events)
	-- its clock (Timer.lua): the C_Timer callback is made here; whether that bills the ticks to the addon is
	-- unverified (no frame carries it; see Timer.lua)
	local clock = { list = {}, pendingAt = math.huge }
	clock.tick = function()
		Core._Tick(clock)
	end
	addon._clock = clock
	local onLifecycle = lifecycle(addon)
	addon._lifecycle = onLifecycle
	addHandler("ADDON_LOADED", onLifecycle, addon, addon._events)
	if not watchingLoadingScreen then
		watchingLoadingScreen = true
		addHandler("LOADING_SCREEN_ENABLED", onLoadingScreen)
		addHandler("LOADING_SCREEN_DISABLED", onLoadingScreen)
		addHandler("PLAYER_ENTERING_WORLD", onLoadingScreen)
	end
	if not loggedIn then
		loggedIn = IsLoggedIn() or false
	end
	if not loggedIn then
		addHandler("PLAYER_LOGIN", onLifecycle, addon, addon._events)
	end
	return addon
end

-- For files that must load after this one (the build orders by what a file reads at load): CoreSettings.lua, and
-- Feature.lua / Timer.lua, which add methods to the addon object.
ns.NewAddon = Core.NewAddon
ns.AddonClass = Addon
