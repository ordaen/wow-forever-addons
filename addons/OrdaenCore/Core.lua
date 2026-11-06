-- Ordaen Core: code shared by all Ordaen addons. Every Ordaen addon declares
-- `## Dependencies: OrdaenCore` and gets the API from the global OrdaenCore.
--
-- Compatibility rule: users update the Core and the addons independently, so the public API
-- only grows. Never change or remove something that has been released; add a new name instead.
-- An addon that needs a newer Core declares `## X-Ordaen-MinCore: <version>` in its TOC and
-- calls OrdaenCore.IsCompatible(addonName) before using anything else.
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
		DEFAULT_CHAT_FRAME:AddMessage(string.format(
			"|cffff5555%s needs Ordaen Core %s or newer (you have %s). Please update Ordaen Core.|r",
			title, required, Core.version))
	end
	return false
end

-- Debug API. Players get this no-op stand-in: nothing is recorded, Wrap returns the function
-- unchanged, and errors take WoW's normal path (BugSack, Blizzard's handler). Development mode is
-- the optional addon "Ordaen Core - Debug" (OrdaenCore_Debug, disabled by default); when enabled it
-- loads before the Ordaen addons (they list it in ## OptionalDeps) and replaces Core.NewDebug.
Core.debugMode = false

local DEBUG_COMMANDS = { debug = true, dump = true, errors = true }
local DEBUG_HINT = 'debug mode is off. Enable "Ordaen Core - Debug" in the AddOns list and restart the game.'

local function noop() end

--- The debug kit for one addon (no-op unless Ordaen Core - Debug is enabled).
---@param addon string
---@return table Debug
function Core.NewDebug(addon)
	local options = {}
	local Debug = {
		Log = noop,
		Logf = noop,
		Dump = noop,
		RecordError = noop,
		ShowReport = noop,
	}

	function Debug.Init(_, opts)
		options = opts or {}
	end

	function Debug.IsEnabled()
		return false
	end

	function Debug.Wrap(fn)
		return fn
	end

	function Debug.Call(fn, ...)
		return fn(...)
	end

	function Debug.HelpLines()
		return { (options.slash or "") .. ' debug - development tools (needs "Ordaen Core - Debug")' }
	end

	--- Answers the debug commands with a hint; everything else is left to the addon.
	function Debug.HandleSlash(msg)
		local cmd = ((msg or ""):match("^%s*(%S*)") or ""):lower()
		if not DEBUG_COMMANDS[cmd] then
			return false
		end
		if options.print then
			options.print(DEBUG_HINT)
		else
			DEFAULT_CHAT_FRAME:AddMessage(addon .. ": " .. DEBUG_HINT)
		end
		return true
	end

	return Debug
end
