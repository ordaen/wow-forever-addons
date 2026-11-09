-- Ordaen: the framework every Ordaen module runs in (design: wow-dev-tools design/development/framework).
-- Publishes the global OrdaenCore: what generated module code (__module.lua) and the dev addon reach. Module code
-- itself never names it: it gets Define by import, game and self as parameters.
local addonName, ns = ...

---@class OrdaenCoreAPI
local Core = {}
ns.Core = Core
OrdaenCore = Core

Core.version = C_AddOns.GetAddOnMetadata(addonName, "Version") or "0.0.0"

-- Debug kit for players: one shared, do-nothing object for every addon (methods on a shared metatable,
-- called with `:`). No per-addon tables or closures, nothing recorded, Wrap returns the function itself (so
-- errors take WoW's normal path), and no help text or slash handling: players don't need to know dev tools
-- exist. Development mode is the dev-only addon "Ordaen Core - Debug" (OrdaenCore_Debug, private repo, never
-- shipped). When installed it loads before the Ordaen addons (the build gives them ## OptionalDeps on it) and
-- replaces Core.NewDebug with the real kit; keep these methods in step with that kit.
-- Release builds strip the logging and tracing statements and the `if Debug:IsEnabled() then` /
-- `if Debug:TraceEnabled() then` blocks altogether (ordaen build --release); in git checkouts without the dev
-- addon these no-ops run.

local NO_LINES = {} -- shared and never filled; callers only iterate it

-- Real `:` methods with typed parameters (not shared no-op functions), so lua-language-server reports a `.` call on
-- the kit as a type error, as forever-lint's FL6 does. Unused arguments are fine: the stand-in has no state.
-- luacheck: push ignore 212

--- The per-addon debug kit (this stand-in, or the real one from OrdaenCore_Debug).
---@class OrdaenDebug
local StandIn = {}

---@param db table the addon's SavedVariables (dev settings live in OrdaenCoreDebugDB, not here)
---@param opts { slash: string?, print: fun(...)?, dump: fun(): table }|nil
function StandIn:Init(db, opts) end

--- Info level.
---@param ... any
function StandIn:Log(...) end

---@param fmt string
---@param ... any
function StandIn:Logf(fmt, ...) end

--- Warn level.
---@param ... any
function StandIn:Warn(...) end

---@param fmt string
---@param ... any
function StandIn:Warnf(fmt, ...) end

--- Debug level.
---@param ... any
function StandIn:Verbose(...) end

---@param fmt string
---@param ... any
function StandIn:Verbosef(fmt, ...) end

--- The addon's dev-mode state (the dump callback's result); nothing here.
---@return table|nil
function StandIn:Dump() end

--- For the companion: what happened ("event", "enter", "click", "slash", "setting"...) and its detail.
---@param what string
---@param detail any
function StandIn:Trace(what, detail) end

--- A frame whose OnEnter/OnLeave/OnClick/OnShow/OnHide the dev addon may trace.
---@param frame table
function StandIn:TraceFrame(frame) end

---@return boolean
function StandIn:IsEnabled()
	return false
end

---@return boolean
function StandIn:TraceEnabled()
	return false
end

--- `fn` itself here (errors take WoW's normal path); the real kit records errors.
---@generic F
---@param fn F
---@return F
function StandIn:Wrap(fn)
	return fn
end

--- A saveable copy of `value` (frames as name, size, points...); the value itself here.
---@param value any
---@param depth integer|nil
---@return any
function StandIn:Snapshot(value, depth)
	return value
end

---@param fn function
---@param ... any
---@return any ...
function StandIn:Call(fn, ...)
	return fn(...)
end

---@return string[]
function StandIn:HelpLines()
	return NO_LINES
end

---@param msg string|nil
---@return boolean handled
function StandIn:HandleSlash(msg)
	return false
end

--- A conflict with another addon (the framework calls it from A:Conflict; dev mode sends it to the companion).
---@param other string the other addon's folder name
---@param what string what happened (English, for developers)
---@param handled boolean
function StandIn:Conflict(other, what, handled) end

-- Timing (Performance tab). Release builds strip `local t = Debug:TimeStart()`, `Debug:TimeEnd(...)` and
-- `Debug:Time(...)` statements; forever-lint FL7 refuses a Time call whose results are used.

--- A start mark for TimeEnd (debugprofilestop in the real kit); 0 here.
---@return number
function StandIn:TimeStart()
	return 0
end

--- Record the time since `start` under `label`.
---@param start number from TimeStart
---@param label string
function StandIn:TimeEnd(start, label) end

--- Run `fn(...)` and record its time under `label`; returns fn's results.
---@param label string
---@param fn function
---@param ... any
---@return any ...
function StandIn:Time(label, fn, ...)
	return fn(...)
end
-- luacheck: pop

local standIn = setmetatable({}, { __index = StandIn })

--- The debug kit for one addon: the shared no-op stand-in unless the dev addon replaced this.
---@return OrdaenDebug
---@param name string|nil the addon the kit is for (the real kit keeps per-addon logs)
function Core.NewDebug(name) -- luacheck: ignore 212
	return standIn
end
