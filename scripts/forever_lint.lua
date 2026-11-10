-- forever-lint: checks Lua code against the real Forever API (api/forever/$(cat CURRENT)/api.json, made
-- from the in-game dump). luacheck already rejects unknown globals and namespace functions; this adds
-- what luacheck can't know:
--   FL1 event      :RegisterEvent/RegisterUnitEvent/UnregisterEvent/IsEventRegistered("NAME") or RawEvent("NAME")
--                  with a name Forever's API documentation doesn't list, or one its client refuses (the dump
--                  registers every documented event once: retail leftovers like MINIMAP_PING fail there)
--   FL2 method     a method that the widget type doesn't have, on a variable we know holds that type
--                  (from CreateFrame("Type", ..., "Template"), :CreateTexture(), :CreateFontString(), ...)
--   FL3 arguments  more arguments than a documented function takes, or fewer than it needs (only when
--                  the dump records argument defaults)
--   FL4 arg type   a literal of the wrong kind for a documented argument (a string where a number goes, ...)
--   FL5 frame type CreateFrame("X") with a type that isn't a widget type in the dump
--   FL6 debug kit  a debug kit method called with '.' (Debug.Log(...), debug().Logf(...)): it takes ':'
--   FL7 debug time Debug:Time(...) whose results are used: release builds strip the call, so it may only
--                  be a statement (time a value with t = Debug:TimeStart() ... Debug:TimeEnd(t, "label"))
--   FL8 reload     any ReloadUI / C_UI.Reload in addon code: Forever blocks a reload from addon code even inside
--                  a click; a secure /reload macro button reloads (UI.Confirm `macro`), or the player types /reload
--   FL9 unit event a unit event (its first argument is the unit, per Blizzard's documentation) registered for every
--                  unit: :RegisterEvent("UNIT_AURA") or :On("UNIT_AURA", ...) also runs for every nameplate and
--                  raider; register it for the units you need (RegisterUnitEvent, A:OnUnit / F:OnUnit)
-- It only reports what it's sure of: a variable assigned anything it can't type is no longer checked.
-- Silence one line with a trailing comment:  -- forever-lint: ignore FL2
--
--   lua scripts/forever_lint.lua [--root <repo>] <files or folders...>     (default: addons)
-- Exit code 1 when anything is reported. Uses luacheck's parser (luacheck is installed for the lint).
local M = {}

local scriptDir = (debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "./")

-- Templates whose methods are mixed into the frame: template name -> mixin table in the dump.
M.TEMPLATE_MIXINS = {
	BackdropTemplate = "BackdropTemplateMixin",
}

-- Region creators: method -> resulting widget type (CreateAnimation takes its type as first argument).
local CREATORS = {
	CreateTexture = "Texture",
	CreateMaskTexture = "MaskTexture",
	CreateFontString = "FontString",
	CreateLine = "Line",
	CreateAnimationGroup = "AnimationGroup",
}

local EVENT_METHODS = {
	RegisterEvent = true, RegisterUnitEvent = true, UnregisterEvent = true, IsEventRegistered = true,
}

-- Registering an event for every unit: the frame's own method, and the framework's (Addon/Feature/UI component :On).
local ALL_UNITS_METHODS = { RegisterEvent = true, On = true }

--- Whether Blizzard documents `event` with the unit as its first argument (UNIT_AURA: unitTarget), so it can be
--- registered per unit.
---@param api table
---@param event string
---@return boolean
function M.IsUnitEvent(api, event)
	local doc = api.events[event]
	local first = type(doc) == "table" and type(doc.payload) == "table" and doc.payload[1] or nil
	return type(first) == "table" and type(first.type) == "string" and first.type:find("^UnitToken") ~= nil
end

-- Documented argument types we can compare literals against; anything else is not checked.
-- (uiAddon is a name or an index, so it is neither.)
local STRING_TYPES = { string = true, cstring = true, stringView = true, UnitToken = true, WOWGUID = true }
local NUMBER_TYPES = { number = true, luaIndex = true, uiMapID = true, fileID = true }
local BOOL_TYPES = { bool = true, boolean = true }

-- API --------------------------------------------------------------------------------------------

--- Load the structured API of the current Forever version.
---@param root string repo root
function M.LoadApi(root)
	local current = assert(io.open(root .. "/api/forever/CURRENT")):read("*l"):match("^%s*(.-)%s*$")
	local f = assert(io.open(root .. "/api/forever/" .. current .. "/api.json", "rb"))
	local api = dofile(scriptDir .. "json.lua").decode(f:read("*a"))
	f:close()
	api.version = current
	return M.Prepare(api)
end

--- Index an api.json table for fast lookups (also used by specs with a small hand-made API).
function M.Prepare(api)
	api.methodSets = {}
	for widgetType, methods in pairs(api.widgets or {}) do
		if methods then
			local set = {}
			for _, m in ipairs(methods) do
				set[m] = true
			end
			api.methodSets[widgetType] = set
		end
	end
	api.events = api.events or {}
	api.functions = api.functions or {}
	api.namespaces = api.namespaces or {}
	return api
end

--- Members of a dumped Blizzard object (name -> type), following "<ref>" aliases; nil when the dump
--- doesn't have the path, its tree was truncated or WoW protects it ("<forbidden>": nothing can be said).
function M.ObjectMembers(api, objectPath)
	local objects = api.objects or {}
	local members = objects[objectPath]
	for _ = 1, 5 do
		if not members or not members["<ref>"] then
			break
		end
		members = objects[members["<ref>"]]
	end
	if not members or members["<truncated>"] or members["<forbidden>"] then
		return nil
	end
	return members
end

-- Types of values: { widget = "Button", templates = {...} } or nil (unknown).
local function widgetType(name, templates)
	return { widget = name, templates = templates or {} }
end

local function hasMethod(api, t, method)
	local set = api.methodSets[t.widget]
	if set and set[method] then
		return true
	end
	for _, template in ipairs(t.templates) do
		local mixin = M.TEMPLATE_MIXINS[template]
		if not mixin then
			return true -- a template we can't see into may add any method
		end
		local members = api.namespaces[mixin]
		if members and members[method] == "function" then
			return true
		end
	end
	return false
end

-- AST helpers ------------------------------------------------------------------------------------

local function literal(node)
	if not node then
		return nil
	end
	if node.tag == "String" then
		return "string", node[1]
	elseif node.tag == "Number" then
		return "number", node[1]
	elseif node.tag == "True" or node.tag == "False" then
		return "boolean"
	elseif node.tag == "Nil" then
		return "nil"
	end
	return nil
end

--- "a.b.c" for Id/Index chains with string keys, else nil.
local function path(node)
	if node.tag == "Id" then
		return node[1]
	elseif node.tag == "Index" and node[2].tag == "String" then
		local base = path(node[1])
		return base and (base .. "." .. node[2][1]) or nil
	end
	return nil
end

-- The Ordaen debug kit (Core.NewDebug: the stand-in in OrdaenCore/Core.lua, the real kit in OrdaenCore_Debug) is an
-- object: its methods are called with ':'. FL6 flags a '.' call on anything that is the kit: `Debug`, `x.Debug`,
-- or a call of a function named like it (`debug()`, `getDebug()`).
local KIT_METHODS = {}
for name in ([[Init IsEnabled Log Logf Warn Warnf Verbose Verbosef Wrap Call Dump Snapshot HandleSlash HelpLines
	Trace TraceFrame TraceEnabled TimeStart TimeEnd Time Conflict Record Recording]]):gmatch("%a+") do
	KIT_METHODS[name] = true
end

local function isDebugKit(node)
	if node.tag == "Id" then
		return node[1] == "Debug"
	elseif node.tag == "Index" and node[2].tag == "String" then
		return node[2][1] == "Debug"
	elseif node.tag == "Call" then
		local fn = node[1]
		local name = fn.tag == "Id" and fn[1] or (fn.tag == "Index" and fn[2].tag == "String" and fn[2][1])
		return type(name) == "string" and name:lower():find("debug$") ~= nil
	end
	return false
end

local function multiValue(node)
	return node and (node.tag == "Call" or node.tag == "Invoke" or node.tag == "Dots")
end

-- Linting ----------------------------------------------------------------------------------------

--- Lint one source text. Returns a list of {line, column, code, message}.
---@param api table from M.LoadApi / M.Prepare
---@param source string
function M.LintSource(api, source)
	local decoder = require("luacheck.decoder")
	local parser = require("luacheck.parser")
	local ast = parser.parse(decoder.decode(source))

	local lineStarts = { 1 }
	for pos in source:gmatch("()\n") do
		lineStarts[#lineStarts + 1] = pos + 1
	end
	local ignored = {}
	local n = 0
	for line in (source .. "\n"):gmatch("([^\n]*)\n") do
		n = n + 1
		local codes = line:match("%-%-%s*forever%-lint:%s*ignore%s*(.*)$")
		if codes then
			ignored[n] = codes == "" and true or codes
		end
	end

	local findings = {}
	local function report(node, code, message)
		local line = node.line or 1
		local skip = ignored[line]
		if skip == true or (type(skip) == "string" and skip:find(code, 1, true)) then
			return
		end
		local column = (node.offset or lineStarts[line]) - (lineStarts[line] or 1) + 1
		findings[#findings + 1] = { line = line, column = column, code = code, message = message }
	end

	-- Scopes map a path ("frame", "frame.icon") to a type, or false once its type is unknown.
	local scope = { vars = {}, parent = nil }
	local function lookup(name)
		local s = scope
		while s do
			local t = s.vars[name]
			if t ~= nil then
				return t or nil
			end
			s = s.parent
		end
		return nil
	end
	local function declare(name, t)
		scope.vars[name] = t or false
	end
	-- A name our code declares or assigns (so it is not, or no longer, a Blizzard object).
	local function declared(name)
		local s = scope
		while s do
			if s.vars[name] ~= nil then
				return true
			end
			s = s.parent
		end
		return false
	end
	local function assign(name, t)
		local root = name:match("^[^.]+")
		local s = scope
		while s do
			if s.vars[root] ~= nil or not s.parent then
				-- A conflicting assignment makes the path unknown for good.
				local old = s.vars[name]
				if old == nil or (old and t and old.widget == t.widget) then
					s.vars[name] = t or false
				else
					s.vars[name] = false
				end
				return
			end
			s = s.parent
		end
	end

	local typeOf -- forward

	local function checkEvent(at, event)
		local known = api.events[event]
		if not known then
			report(at, "FL1", "event '" .. event .. "' is not in Forever " .. tostring(api.version)
				.. "'s API documentation")
		elseif known.refused then
			report(at, "FL1", "event '" .. event .. "' is in Blizzard's documentation, but Forever " .. tostring(api.version)
				.. "'s client refuses to register it (unknown event)")
		end
	end

	local function checkCall(node)
		-- node: Call; node[1] = callee
		local callee = node[1]
		if callee.tag == "Index" and callee[2].tag == "String" and KIT_METHODS[callee[2][1]]
			and isDebugKit(callee[1]) then
			report(callee[2], "FL6", "debug kit method " .. callee[2][1] .. " called with '.'; it is a method: use ':' ("
				.. "a '.' call passes the first argument as self)")
		end
		local name = path(callee)
		if not name then
			return
		end
		if name == "RawEvent" then -- Ordaen Core's raw event signals (Game.lua)
			local kind, event = literal(node[2])
			if kind == "string" then
				checkEvent(node[2], event)
			end
		end
		if name == "CreateFrame" then
			local kind, frameType = literal(node[2])
			if kind == "string" and not api.methodSets[frameType] and api.widgets and api.widgets[frameType] == nil then
				report(node[2], "FL5", "CreateFrame type '" .. frameType .. "' is not a widget type in Forever "
					.. tostring(api.version))
			end
		end
		local fn = api.functions[name]
		if not fn then
			return
		end
		local args = {}
		for i = 2, #node do
			args[#args + 1] = node[i]
		end
		if #args > #fn.args and not multiValue(args[#args]) then
			report(node, "FL3", string.format("%s takes %d argument(s), got %d", name, #fn.args, #args))
		end
		-- Too few: only when the dump records defaults (meta.docsDefaults), since Blizzard's docs mark
		-- arguments with a default as non-nilable.
		if api.meta and api.meta.docsDefaults and not multiValue(args[#args]) then
			local required = 0
			for i, spec in ipairs(fn.args) do
				if not spec.nilable and not spec.default then
					required = i
				end
			end
			if #args < required then
				report(node, "FL3", string.format("%s needs %d argument(s) (%s), got %d", name, required,
					fn.args[required].name, #args))
			end
		end
		for i, arg in ipairs(args) do
			local spec = fn.args[i]
			local kind = literal(arg)
			if spec and kind and kind ~= "nil" then
				local bad = (kind == "string" and (NUMBER_TYPES[spec.type] or BOOL_TYPES[spec.type]))
					or (kind == "number" and (STRING_TYPES[spec.type] or BOOL_TYPES[spec.type]))
					or (kind == "boolean" and (STRING_TYPES[spec.type] or NUMBER_TYPES[spec.type]))
				if bad then
					report(arg, "FL4", string.format("%s argument %d (%s) is %s, got a %s", name, i, spec.name,
						spec.type, kind))
				end
			elseif spec and kind == "nil" and not spec.nilable and i < #args then
				-- nil in the middle for a non-nilable argument; trailing nils are the same as leaving it out
				report(arg, "FL4", string.format("%s argument %d (%s) can't be nil", name, i, spec.name))
			end
		end
	end

	local function checkInvoke(node)
		-- node: Invoke; node[1] = object, node[2] = String method
		local method = node[2][1]
		if EVENT_METHODS[method] then
			local kind, event = literal(node[3])
			if kind == "string" then
				checkEvent(node[3], event)
			end
		end
		if ALL_UNITS_METHODS[method] then
			local kind, event = literal(node[3])
			if kind == "string" and M.IsUnitEvent(api, event) then
				report(node[3], "FL9", "'" .. event .. "' is a unit event: registered this way it runs for every unit "
					.. "(nameplates, raiders); use RegisterUnitEvent or A:OnUnit / F:OnUnit with the units you need")
			end
		end
		local objectPath = path(node[1])
		local t = objectPath and lookup(objectPath)
		if t and not hasMethod(api, t, method) then
			report(node[2], "FL2", string.format("%s (%s) has no method %s on Forever", objectPath, t.widget, method))
		elseif objectPath and not t and not declared(objectPath:match("^[^.]+")) then
			-- A Blizzard object the dump walked (Minimap, MinimapCluster.Tracking.Button, ...).
			local members = M.ObjectMembers(api, objectPath)
			if members and members[method] ~= "function" then
				local objectType = members["<objectType>"]
				local set = objectType and api.methodSets[objectType]
				if not (set and set[method]) then
					report(node[2], "FL2", string.format("%s has no method %s on Forever", objectPath, method))
				end
			end
		end
	end

	function typeOf(expr)
		if not expr then
			return nil
		end
		if expr.tag == "Call" and path(expr[1]) == "CreateFrame" then
			local kind, frameType = literal(expr[2])
			if kind ~= "string" or not api.methodSets[frameType] then
				return nil
			end
			local templates = {}
			local tkind, list = literal(expr[5])
			if tkind == "string" then
				for template in list:gmatch("[^,%s]+") do
					templates[#templates + 1] = template
				end
			elseif expr[5] then
				templates[1] = "?" -- a template we can't read: any method allowed
			end
			return widgetType(frameType, templates)
		elseif expr.tag == "Invoke" then
			local method = expr[2][1]
			if CREATORS[method] then
				return widgetType(CREATORS[method])
			elseif method == "CreateAnimation" then
				local kind, animType = literal(expr[3])
				local name = kind == "string" and animType or "Animation"
				return api.methodSets[name] and widgetType(name) or nil
			end
		elseif expr.tag == "Id" or expr.tag == "Index" then
			local p = path(expr)
			return p and lookup(p) or nil
		end
		return nil
	end

	local walk

	local function walkFunction(fn)
		-- fn: Function; fn[1] = params, fn[2] = body
		local saved = scope
		scope = { vars = {}, parent = saved }
		for _, param in ipairs(fn[1]) do
			if param.tag == "Id" then
				declare(param[1], nil)
			end
		end
		walk(fn[2])
		scope = saved
	end

	-- inExpr: the node's value is used (it sits in an expression, not directly in a block)
	local function walkExprs(list)
		for _, expr in ipairs(list or {}) do
			walk(expr, true)
		end
	end

	function walk(node, inExpr)
		if type(node) ~= "table" then
			return
		end
		local tag = node.tag
		if tag == "Id" and node[1] == "ReloadUI" then
			report(node, "FL8", "ReloadUI from addon code: Forever blocks a reload from addon code even inside a click; "
				.. "give the button a secure macro (UI.Confirm button `macro = \"/reload\"`), or tell the player to "
				.. "type /reload")
		elseif tag == "Index" and node[1].tag == "Id" and node[1][1] == "C_UI" and node[2].tag == "String"
			and node[2][1] == "Reload" then
			report(node, "FL8", "C_UI.Reload from addon code: Forever blocks it; use a secure /reload macro button")
		end
		if inExpr and tag == "Invoke" and node[2].tag == "String" and node[2][1] == "Time" and isDebugKit(node[1]) then
			report(node[2], "FL7", "Debug:Time(...) used as a value: release builds strip it, so it may only be a "
				.. "statement; time a value with local t = Debug:TimeStart() ... Debug:TimeEnd(t, \"label\")")
		end
		if tag == "Function" then
			walkFunction(node)
			return
		elseif tag == "Local" then
			walkExprs(node[2])
			local names, exprs = node[1], node[2] or {}
			for i, id in ipairs(names) do
				local t = (i <= #exprs) and typeOf(exprs[i]) or nil
				declare(id[1], t)
			end
			return
		elseif tag == "Localrec" then
			declare(node[1][1][1], nil)
			walk(node[2])
			return
		elseif tag == "Set" then
			walkExprs(node[2])
			local targets, exprs = node[1], node[2]
			for i, target in ipairs(targets) do
				local p = path(target)
				if p then
					assign(p, typeOf(exprs[i]))
				else
					walk(target)
				end
			end
			return
		elseif tag == "Call" then
			checkCall(node)
		elseif tag == "Invoke" then
			checkInvoke(node)
		elseif tag == "Forin" then
			walkExprs(node[2])
			walk(node[3])
			return
		end
		local expr = tag ~= nil and tag ~= "Do"
		for i = 1, #node do
			walk(node[i], expr)
		end
	end

	walk(ast)
	table.sort(findings, function(a, b)
		return a.line < b.line or (a.line == b.line and a.column < b.column)
	end)
	return findings
end

-- Command line ----------------------------------------------------------------------------------

local function luaFiles(target)
	return dofile(scriptDir .. "fs.lua").Files(target, "%.lua$")
end

function M.Main(args)
	local root, targets = ".", {}
	local i = 1
	while i <= #args do
		if args[i] == "--root" then
			root = args[i + 1]
			i = i + 2
		else
			targets[#targets + 1] = args[i]
			i = i + 1
		end
	end
	if #targets == 0 then
		targets = { root .. "/addons" }
	end
	local api = M.LoadApi(root)
	local count, files = 0, 0
	for _, target in ipairs(targets) do
		for _, file in ipairs(luaFiles(target)) do
			files = files + 1
			local f = assert(io.open(file, "rb"))
			local source = f:read("*a")
			f:close()
			local ok, findings = pcall(M.LintSource, api, source)
			if not ok then
				print(file .. ": could not parse: " .. tostring(findings))
				count = count + 1
			else
				for _, finding in ipairs(findings) do
					print(string.format("%s:%d:%d: %s %s", file, finding.line, finding.column, finding.code,
						finding.message))
					count = count + 1
				end
			end
		end
	end
	print(string.format("forever-lint (Forever %s): %d finding(s) in %d file(s)", api.version, count, files))
	return count == 0
end

if arg and arg[0] and arg[0]:match("forever_lint%.lua$") then
	os.exit(M.Main(arg) and 0 or 1)
end

return M
