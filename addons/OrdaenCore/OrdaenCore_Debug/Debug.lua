-- The per-addon debug kit in dev mode. Replaces the no-op stand-in OrdaenCore.NewDebug from
-- Ordaen Core (Ordaen addons list this addon in ## OptionalDeps, so it loads before them).
-- Same API as the stand-in; the data goes to OrdaenCoreDebugDB (Store.lua), not to the addon's
-- own SavedVariables.
local _, ns = ...
local Store, Capture = ns.Store, ns.Capture

local Core = OrdaenCore
Core.debugMode = true

ns.instances = {} -- addonName -> Debug, for the window ("Save for Claude" dumps every addon)

local function pack(...)
	return { n = select("#", ...), ... }
end

local function joinArgs(...)
	local parts = {}
	for i = 1, select("#", ...) do
		parts[i] = tostring((select(i, ...)))
	end
	return table.concat(parts, " ")
end

local function timestamp()
	local t = GetTime and GetTime() or 0
	return string.format("%s.%03d", date("%H:%M:%S"), math.floor((t % 1) * 1000))
end

local function round(x)
	return math.floor(x * 100 + 0.5) / 100
end

-- Frames, textures and font strings are tables with a GetObjectType method. SavedVariables
-- cannot store them, so describe the parts that matter for layout bugs instead.
local function isWidget(v)
	return type(v) == "table" and type(v.GetObjectType) == "function"
end

local function call(obj, method, ...)
	local fn = obj[method]
	if type(fn) ~= "function" then
		return nil
	end
	local ok, a, b = pcall(fn, obj, ...)
	if ok then
		return a, b
	end
	return nil
end

local function widgetName(w)
	if not isWidget(w) then
		return nil
	end
	return call(w, "GetName") or ("<" .. tostring(call(w, "GetObjectType")) .. ">")
end

local function describeWidget(w)
	local out = {
		widget = call(w, "GetObjectType"),
		name = call(w, "GetName"),
		parent = widgetName(call(w, "GetParent")),
		shown = call(w, "IsShown"),
		visible = call(w, "IsVisible"),
		strata = call(w, "GetFrameStrata"),
		level = call(w, "GetFrameLevel"),
		alpha = call(w, "GetAlpha"),
		scale = call(w, "GetScale"),
	}
	local width, height = call(w, "GetSize")
	if width then
		out.size = round(width) .. "x" .. round(height)
	end
	local numPoints = call(w, "GetNumPoints") or 0
	if numPoints > 0 then
		out.points = {}
		for i = 1, numPoints do
			local ok, point, relativeTo, relativePoint, x, y = pcall(w.GetPoint, w, i)
			if ok and point then
				out.points[i] = string.format("%s %s %s %s %s", point, widgetName(relativeTo) or "nil",
					tostring(relativePoint), tostring(x and round(x)), tostring(y and round(y)))
			end
		end
	end
	return out
end

local SNAPSHOT_DEPTH = 5
local SNAPSHOT_MAX_KEYS = 200

--- Convert any value into something SavedVariables can store: widgets become descriptions,
--- functions become "<function>", cycles and deep tables are cut off.
local function snapshot(value, depth)
	local seen = {}
	local function snap(v, d)
		local t = type(v)
		if t == "string" or t == "number" or t == "boolean" or t == "nil" then
			return v
		end
		if t ~= "table" then
			return "<" .. t .. ">"
		end
		if isWidget(v) then
			return describeWidget(v)
		end
		if seen[v] then
			return "<cycle>"
		end
		if d <= 0 then
			return "<table>"
		end
		seen[v] = true
		local out, count = {}, 0
		for k, val in pairs(v) do
			count = count + 1
			if count > SNAPSHOT_MAX_KEYS then
				out["<truncated>"] = true
				break
			end
			local kt = type(k)
			local key = (kt == "string" or kt == "number" or kt == "boolean") and k or tostring(k)
			out[key] = snap(val, d - 1)
		end
		seen[v] = nil -- only cut real cycles, not tables shared by two branches
		return out
	end
	return snap(value, depth or SNAPSHOT_DEPTH)
end

--- The debug kit for one addon. Calling it again for the same addon returns the same instance.
---@param addonName string
---@return table Debug
function Core.NewDebug(addonName)
	if ns.instances[addonName] then
		return ns.instances[addonName]
	end
	local Debug = { addonName = addonName }
	ns.instances[addonName] = Debug
	local options = {}

	local function chat(...)
		if options.print then
			options.print(...)
		elseif DEFAULT_CHAT_FRAME then
			DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99" .. addonName .. "|r: " .. joinArgs(...))
		end
	end

	--- Call from ADDON_LOADED. db (the addon's SavedVariables) is accepted for compatibility with
	--- the stand-in but unused: dev data lives in OrdaenCoreDebugDB.
	---@param opts table|nil { slash = "/om", print = fn, dump = fn():table }
	function Debug.Init(_, opts)
		options = opts or {}
		Debug.Log("---- session", Store.Session(), "start")
	end

	---@return boolean whether this addon's log is recording
	function Debug.IsEnabled()
		return Store.Addon(addonName).logging
	end

	--- Append a line to this addon's log. Arguments are joined like print().
	function Debug.Log(...)
		local addon = Store.Addon(addonName)
		if not addon.logging then
			return
		end
		local line = timestamp() .. " " .. joinArgs(...)
		Store.AppendLog(addonName, line)
		if addon.echo then
			chat("|cff999999" .. line .. "|r")
		end
	end

	--- Like Log, with string.format.
	function Debug.Logf(fmt, ...)
		if Store.Addon(addonName).logging then
			Debug.Log(string.format(fmt, ...))
		end
	end

	Debug.Snapshot = snapshot

	--- Save the addon's state (opts.dump, through Snapshot) to OrdaenCoreDebugDB.addons[name].dump.
	---@return table
	function Debug.Dump()
		local data = { time = Store.Now(), session = Store.Session() }
		if options.dump then
			local ok, result = pcall(options.dump)
			data.state = ok and snapshot(result) or ("dump failed: " .. tostring(result))
		end
		Store.Addon(addonName).dump = data
		return data
	end

	--- Call fn(...); an error is recorded and handed on (BugSack, Blizzard) instead of escaping.
	--- Returns fn's results, or nothing if it failed.
	function Debug.Call(fn, ...)
		local args = pack(...)
		local results = pack(xpcall(function()
			return fn(unpack(args, 1, args.n))
		end, Capture.Handler))
		if not results[1] then
			return
		end
		return unpack(results, 2, results.n)
	end

	--- Wrap a handler (event, script, slash command) with Debug.Call.
	function Debug.Wrap(fn)
		return function(...)
			return Debug.Call(fn, ...)
		end
	end

	function Debug.HelpLines()
		return { (options.slash or "") .. " debug - open the Ordaen Dev window" }
	end

	--- "/<cmd> debug" opens the Ordaen Dev window; everything else is left to the addon.
	---@return boolean handled
	function Debug.HandleSlash(msg)
		local cmd = ((msg or ""):match("^%s*(%S*)") or ""):lower()
		if cmd ~= "debug" then
			return false
		end
		if ns.UI then
			ns.UI.Toggle()
		end
		return true
	end

	return Debug
end
