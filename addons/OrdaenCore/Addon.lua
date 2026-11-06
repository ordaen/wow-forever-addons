-- Ordaen Core: the addon framework. An addon declares what it needs once and the framework does the wiring:
-- SavedVariables with defaults, its lifecycle, events on one shared frame, slash commands (help and reset built
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
--
-- The spec must be a table written in the file (the build reads `db`/`charDb` from it). Strings shown to players
-- (labels, help) are locale keys of the addon (`ns.L`). Cost: one event frame for all Ordaen addons, handlers in
-- plain arrays (no tables or closures per event), nothing runs per frame.
local _, ns = ...

---@class OrdaenCoreAPI
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
---@field _settingsCategory table|nil set by Settings.lua
local Addon = {}
Addon.__index = Addon

local byName = {} -- addon name -> addon object, for ADDON_LOADED
local loggedIn = false
local frame -- the shared event frame, created with the first addon
local handlers = {} -- event -> array of { fn = ..., addon = ... }; replaced (not changed) by On/Off
local afterCombat -- array of functions waiting for PLAYER_REGEN_ENABLED

-- Each handler runs through securecallfunction when the client has it: an error in one addon's handler is
-- reported (BugSack, Blizzard, dev mode) and the other handlers of the event still run.
local call = securecallfunction or function(fn, ...)
	return fn(...)
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

local function eventFrame()
	if not frame then
		frame = CreateFrame("Frame")
		frame:SetScript("OnEvent", function(_, event, ...)
			local list = handlers[event]
			if list then
				for i = 1, #list do
					local entry = list[i]
					-- Dev builds: the companion shows which addon handled what. Release builds strip this block.
					if entry.Debug:TraceEnabled() then
						entry.Debug:Trace("event", event)
					end
					call(entry.fn, event, ...)
				end
			end
		end)
	end
	return frame
end

-- Handlers run in the order they were added. The list is replaced, never changed, so On/Off from inside a
-- handler can't disturb the dispatch loop that is running.
local function addHandler(event, fn, addon)
	local old = handlers[event]
	local list = {}
	if old then
		for i = 1, #old do
			list[i] = old[i]
		end
	else
		eventFrame():RegisterEvent(event)
	end
	-- Debug: the owning addon's kit (the Core's for the framework's own handlers), for tracing in dev builds.
	list[#list + 1] = { fn = fn, addon = addon, Debug = addon and addon.Debug or Core.NewDebug("OrdaenCore") }
	handlers[event] = list
end

local function removeHandler(event, fn)
	local old = handlers[event]
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
		handlers[event] = nil
		frame:UnregisterEvent(event)
	else
		handlers[event] = list
	end
end

local function runAll(list, ...)
	if list then
		for i = 1, #list do
			call(list[i], ...)
		end
	end
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
	local wrapped = self._wrapped[fn] or self.Debug:Wrap(fn)
	self._wrapped[fn] = wrapped
	addHandler(event, wrapped, self)
end

--- Stop running `fn` on `event`.
---@param event WowEvent
---@param fn fun(event: string, ...) the function given to On
function Addon:Off(event, fn)
	local wrapped = self._wrapped[fn]
	if wrapped then
		removeHandler(event, wrapped)
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
	clear(db, addon.spec.defaults or {})
	copyDefaults(db, addon.spec.defaults or {})
	if Core.Settings then
		Core.Settings.Sanitize(addon)
	end
	runAll(addon._onReset)
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

local function savedVariables(name, defaults)
	local db = _G[name]
	if type(db) ~= "table" then
		db = {}
		rawset(_G, name, db)
	end
	return copyDefaults(db, defaults or {})
end

local function onAddonLoaded(addon)
	local spec = addon.spec
	if spec.db then
		addon.db = savedVariables(spec.db, spec.defaults)
	end
	if spec.charDb then
		addon.charDb = savedVariables(spec.charDb, spec.charDefaults)
	end
	addon.Debug:Init(addon.db or {}, {
		slash = addon.spec.slash and addon.spec.slash[1],
		print = function(...)
			addon:Print(...)
		end,
		dump = spec.dump,
	})
	if spec.settings and Core.Settings then
		Core.Settings.Register(addon)
	end
	registerSlash(addon)
	addon.loaded = true
	runAll(addon._onLoad, addon.db, addon.charDb)
	addon._onLoad = nil
	if loggedIn then
		runAll(addon._onLogin)
		addon._onLogin = nil
	end
end

local waitingForLoad, waitingForLogin = false, false

local function onLifecycle(event, arg1)
	if event == "ADDON_LOADED" then
		local addon = byName[arg1]
		if addon then
			byName[arg1] = nil
			onAddonLoaded(addon)
			if not next(byName) then
				waitingForLoad = false
				removeHandler("ADDON_LOADED", onLifecycle)
			end
		end
	elseif event == "PLAYER_LOGIN" then
		loggedIn = true
		waitingForLogin = false
		removeHandler("PLAYER_LOGIN", onLifecycle)
		for _, addon in ipairs(Core._addons) do
			if addon.loaded then
				runAll(addon._onLogin)
				addon._onLogin = nil
			end
		end
	end
end

Core._addons = {}

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
	}, Addon)
	byName[addonName] = addon
	Core._addons[#Core._addons + 1] = addon
	if not waitingForLoad then
		waitingForLoad = true
		addHandler("ADDON_LOADED", onLifecycle)
	end
	if not loggedIn and not waitingForLogin then
		loggedIn = IsLoggedIn() or false
		if not loggedIn then
			waitingForLogin = true
			addHandler("PLAYER_LOGIN", onLifecycle)
		end
	end
	return addon
end

-- For files that must load after this one (the build orders by what a file reads at load).
ns.NewAddon = Core.NewAddon
