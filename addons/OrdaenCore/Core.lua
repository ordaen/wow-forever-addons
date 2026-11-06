-- Ordaen Core: code shared by all Ordaen addons. Every Ordaen addon uses the global OrdaenCore (the build
-- derives `## Dependencies: OrdaenCore` from that) and starts with OrdaenCore.NewAddon (Addon.lua).
--
-- Compatibility rule: users update the Core and the addons independently, so the public API
-- only grows. Never change or remove something that has been released; add a new name instead.
-- An addon that needs a newer Core sets "minCore" in its addon.jsonc (`## X-Ordaen-MinCore`);
-- NewAddon checks it with OrdaenCore.IsCompatible.
local addonName, ns = ...

local Core = {}
ns.Core = Core
OrdaenCore = Core

local function metadata(addon, field)
	if C_AddOns and C_AddOns.GetAddOnMetadata then
		return C_AddOns.GetAddOnMetadata(addon, field)
	end
	return nil
end

Core.version = metadata(addonName, "Version") or "0.0.0"

-- The packager replaces this token with the release tag. If it is still there, this is a
-- git checkout (development), where versions in the TOC don't mean anything yet.
local PACKAGED_VERSION = "@project-version@"
Core.isDevBuild = PACKAGED_VERSION:sub(1, 1) == "@"

--- Compare two dotted versions ("1.2.3"); missing parts count as 0.
---@return integer -1 if a < b, 0 if equal, 1 if a > b
function Core.CompareVersions(a, b)
	local function parts(v)
		local out = {}
		for n in tostring(v):gmatch("%d+") do
			out[#out + 1] = tonumber(n)
		end
		return out
	end
	local pa, pb = parts(a), parts(b)
	for i = 1, math.max(#pa, #pb) do
		local x, y = pa[i] or 0, pb[i] or 0
		if x ~= y then
			return x < y and -1 or 1
		end
	end
	return 0
end

local warned = {}

--- Whether this Core is new enough for `addon` (its `## X-Ordaen-MinCore` TOC field).
--- Prints one chat warning per addon when it isn't. Development checkouts always pass.
---@param addon string
---@return boolean
function Core.IsCompatible(addon)
	local required = metadata(addon, "X-Ordaen-MinCore")
	if not required or Core.isDevBuild or Core.CompareVersions(Core.version, required) >= 0 then
		return true
	end
	if not warned[addon] then
		warned[addon] = true
		local title = metadata(addon, "Title") or addon
		DEFAULT_CHAT_FRAME:AddMessage("|cffff5555" .. ns.L.NEEDS_NEWER_CORE:format(title, required, Core.version) .. "|r")
	end
	return false
end

-- Debug kit for players: one shared, do-nothing object for every addon (methods on a shared metatable,
-- called with `:`). No per-addon tables or closures, nothing recorded, Wrap returns the function itself (so
-- errors take WoW's normal path), and no help text or slash handling: players don't need to know dev tools
-- exist. Development mode is the dev-only addon "Ordaen Core - Debug" (OrdaenCore_Debug, private repo, never
-- shipped). When installed it loads before the Ordaen addons (the build gives them ## OptionalDeps on it) and
-- replaces Core.NewDebug with the real kit; keep these methods in step with that kit.
-- Release builds strip the logging and tracing statements and the `if Debug:IsEnabled() then` /
-- `if Debug:TraceEnabled() then` blocks altogether (ordaen build --release); in git checkouts without the dev
-- addon these no-ops run.
Core.debugMode = false

local function noop() end

local function no()
	return false
end

local NO_LINES = {} -- shared and never filled; callers only iterate it

---@class OrdaenDebug
local StandIn = {
	Init = noop, -- Init(db, { slash, print, dump })
	Log = noop, -- info level
	Logf = noop,
	Warn = noop, -- warn level
	Warnf = noop,
	Verbose = noop, -- debug level
	Verbosef = noop,
	Dump = noop,
	Trace = noop, -- Trace(what, detail): "event", "enter", "click", "slash", "setting"...
	TraceFrame = noop, -- a frame whose OnEnter/OnLeave/OnClick/OnShow/OnHide the dev addon may trace
	IsEnabled = no,
	TraceEnabled = no,
}

-- Methods (called with `:`); the stand-in has no state, so they ignore self.
function StandIn.Wrap(_, fn)
	return fn
end

function StandIn.Snapshot(_, value)
	return value
end

function StandIn.Call(_, fn, ...)
	return fn(...)
end

function StandIn.HelpLines()
	return NO_LINES
end

StandIn.HandleSlash = no

local standIn = setmetatable({}, { __index = StandIn })

--- The debug kit for one addon: the shared no-op stand-in unless the dev addon replaced this.
---@return OrdaenDebug
function Core.NewDebug()
	return standIn
end
