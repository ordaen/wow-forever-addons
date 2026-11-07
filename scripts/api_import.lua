-- Import an in-game API dump (OrdaenCoreDebugDB.apiDump, made by "Dump game API" in the Ordaen Dev
-- window) into api/forever/<version>-<build>/ as sorted plain text, one entry per line, so git keeps
-- a readable history per client version. Also writes:
--   api/forever/CURRENT       the folder luacheck checks against (the newest build)
--   api/forever/CHANGES.md    what each version added/removed compared with the previous one
--   api/forever/luacheck.lua  read_globals for .luacheckrc, generated from CURRENT
--   api/forever/<v>/api.json  the same API, structured (for scripts/forever_lint.lua and other tools)
--   api/forever/luals/        LuaLS definitions of CURRENT (scripts/luals_defs.lua), for lua-language-server
--
--   lua scripts/api_import.lua <path to SavedVariables/OrdaenCore_Debug.lua> <repo root>
--   lua scripts/api_import.lua --rebuild <repo root>   regenerate the derived files from the text files
-- Usually run through scripts/api-import.sh. Lua 5.1; the functions are also used by specs.
local M = {}

local FILES = { "globals", "namespaces", "widgets", "objects", "docs" }

local function sortedKeys(t)
	local keys = {}
	for k in pairs(t or {}) do
		keys[#keys + 1] = k
	end
	table.sort(keys, function(a, b)
		return tostring(a) < tostring(b)
	end)
	return keys
end

local function lines(list)
	table.sort(list)
	return table.concat(list, "\n") .. (#list > 0 and "\n" or "")
end

--- Merge a new dump's text file into the one already imported for the same client build: every entry either
--- saw, the new one winning for an entry both have (an entry is a line; its key is the text before the first tab,
--- or the whole line). The dump only keeps what Blizzard set, so a field one of our addons writes
--- (ChatFrame2.isStaticDocked, written by Ordaen Chat) drops out of later dumps; the build still has it.
--- Pure.
---@param old string|nil the imported file
---@param new string the new dump's file
---@return string
function M.Merge(old, new)
	local byKey, keys = {}, {}
	local function add(text)
		for line in (text or ""):gmatch("[^\n]+") do
			local key = line:match("^([^\t]*)\t") or line
			if byKey[key] == nil then
				keys[#keys + 1] = key
			end
			byKey[key] = line
		end
	end
	add(old)
	add(new)
	local list = {}
	for i, key in ipairs(keys) do
		list[i] = byKey[key]
	end
	return lines(list)
end

-- The files merged with an earlier import of the same build (the rest are replaced: meta, docs).
local MERGED = { ["globals.txt"] = true, ["namespaces.txt"] = true, ["widgets.txt"] = true, ["objects.txt"] = true }

--- Folder name for a dump: "<version>-<build>", e.g. "1.60.1-70790".
function M.FolderName(meta)
	return tostring(meta.version) .. "-" .. tostring(meta.build)
end

-- Only names code can use as an identifier are API. Others are per-user or per-session noise: template
-- placeholders ("$HealerMarkerCheckButton"), localized lookup keys (hash_EmoteTokenList,
-- hash_SlashCmdList, which also lists other addons' slash commands), the user's own UI state
-- (g_addonCategoriesCollapsed). Markers like "<skipped>" (too big to list) and "<forbidden>" (a table WoW protects:
-- it exists, reading it would taint) are kept.
local function identifier(name)
	return type(name) == "string" and name:match("^[%a_][%w_]*$") ~= nil
end
M.IsIdentifier = identifier

--- The text files for one dump, as filename -> content.
function M.Render(dump)
	local out = {}

	local meta = {}
	for _, key in ipairs(sortedKeys(dump.meta)) do
		meta[#meta + 1] = key .. "=" .. tostring(dump.meta[key])
	end
	out["meta.txt"] = lines(meta)

	local globals = {}
	for name, kind in pairs(dump.globals or {}) do
		if identifier(name) then
			globals[#globals + 1] = name .. "\t" .. kind
		end
	end
	out["globals.txt"] = lines(globals)

	local namespaces = {}
	for name, members in pairs(dump.namespaces or {}) do
		if identifier(name) then
			for key, kind in pairs(members) do
				if identifier(key) or key == "<skipped>" or key == "<forbidden>" then
					namespaces[#namespaces + 1] = name .. "." .. key .. "\t" .. kind
				end
			end
		end
	end
	out["namespaces.txt"] = lines(namespaces)

	local widgets = {}
	for widgetType, methods in pairs(dump.widgets or {}) do
		if methods == false then
			widgets[#widgets + 1] = widgetType .. "\tunavailable"
		else
			for _, method in ipairs(methods) do
				widgets[#widgets + 1] = widgetType .. ":" .. method
			end
		end
	end
	out["widgets.txt"] = lines(widgets)

	-- A widget node's methods that its widget type already has (widgets.txt) aren't repeated: with every
	-- named UIParent child as a root that would be ~250 lines per frame. Each node keeps its own keys,
	-- methods its type doesn't have (mixins) and "<objectType>", which points at the rest.
	local typeMethods = {}
	for widgetType, methods in pairs(dump.widgets or {}) do
		if methods then
			typeMethods[widgetType] = {}
			for _, method in ipairs(methods) do
				typeMethods[widgetType][method] = true
			end
		end
	end
	local objects = {}
	for path, members in pairs(dump.objects or {}) do
		local inherited = typeMethods[members["<objectType>"] or ""]
		for key, kind in pairs(members) do
			if not (inherited and kind == "function" and inherited[key]) then
				objects[#objects + 1] = path .. "." .. key .. "\t" .. kind
			end
		end
	end
	out["objects.txt"] = lines(objects)

	if dump.docs then
		local docs = {}
		for name, signature in pairs(dump.docs.functions or {}) do
			docs[#docs + 1] = "function " .. name .. signature
		end
		for name, payload in pairs(dump.docs.events or {}) do
			docs[#docs + 1] = "event " .. name .. "(" .. payload .. ")"
		end
		out["docs.txt"] = lines(docs)
	end
	return out
end

--- Lines added and removed between two versions of a file's content.
function M.Diff(old, new)
	local before, after = {}, {}
	for line in (old or ""):gmatch("[^\n]+") do
		before[line] = true
	end
	for line in (new or ""):gmatch("[^\n]+") do
		after[line] = true
	end
	local added, removed = {}, {}
	for line in pairs(after) do
		if not before[line] then
			added[#added + 1] = line
		end
	end
	for line in pairs(before) do
		if not after[line] then
			removed[#removed + 1] = line
		end
	end
	table.sort(added)
	table.sort(removed)
	return added, removed
end

--- Order version folders by build number (then by name).
function M.SortVersions(folders)
	table.sort(folders, function(a, b)
		local ba, bb = tonumber(a:match("%-(%d+)$")) or 0, tonumber(b:match("%-(%d+)$")) or 0
		if ba ~= bb then
			return ba < bb
		end
		return a < b
	end)
	return folders
end

--- CHANGES.md from each version's rendered files: {folder = {filename = content}}, folders sorted.
function M.Changes(folders, contents)
	local out = { "# Forever API changes", "", "Generated by scripts/api-import.sh. Newest first.", "" }
	for i = #folders, 1, -1 do
		local folder = folders[i]
		out[#out + 1] = "## " .. folder
		out[#out + 1] = ""
		if i == 1 then
			out[#out + 1] = "First dump."
			out[#out + 1] = ""
		else
			local previous = folders[i - 1]
			local any = false
			for _, name in ipairs(FILES) do
				local file = name .. ".txt"
				local added, removed = M.Diff(contents[previous][file], contents[folder][file])
				if #added + #removed > 0 then
					any = true
					out[#out + 1] = string.format("### %s (+%d / -%d vs %s)", file, #added, #removed, previous)
					out[#out + 1] = ""
					for _, line in ipairs(added) do
						out[#out + 1] = "- `+ " .. line .. "`"
					end
					for _, line in ipairs(removed) do
						out[#out + 1] = "- `- " .. line .. "`"
					end
					out[#out + 1] = ""
				end
			end
			if not any then
				out[#out + 1] = "No changes from " .. previous .. "."
				out[#out + 1] = ""
			end
		end
	end
	return table.concat(out, "\n")
end

local function quote(s)
	return string.format("%q", s)
end

--- api/forever/luacheck.lua: read_globals for .luacheckrc from one rendered version.
--- Namespaces get their exact fields (so C_AddOns.NoSuchFunction is flagged); members that are
--- tables, widgets and huge tables allow any further field (we only know one level).
function M.Luacheck(files, folder)
	local namespaces = {}
	for line in (files["namespaces.txt"] or ""):gmatch("[^\n]+") do
		local name, key, kind = line:match("^([^.]+)%.([^\t]+)\t(.+)$")
		if name then
			namespaces[name] = namespaces[name] or {}
			namespaces[name][key] = kind
		end
	end
	local widgetMethods = {}
	for widgetType, method in (files["widgets.txt"] or ""):gmatch("([^:\t\n]+):([^\n]+)") do
		widgetMethods[widgetType] = widgetMethods[widgetType] or {}
		widgetMethods[widgetType][method] = true
	end
	local objects = {}
	local opaque = {} -- objects whose members aren't all known: "<truncated>", "<forbidden>"
	for line in (files["objects.txt"] or ""):gmatch("[^\n]+") do
		local path, key, kind = line:match("^(.+)%.([^.\t]+)\t(.+)$")
		if path and (key == "<truncated>" or key == "<forbidden>") then
			opaque[path] = true
		end
		-- Only top-level objects with identifier-safe keys become luacheck fields. Deep paths, unnamed
		-- children ("#3") and markers ("<ref>", "<objectType>", "<truncated>") stay in the text/JSON only.
		if path and path:match("^[%a_][%w_]*$") then
			if key:match("^[%a_][%w_]*$") then
				objects[path] = objects[path] or {}
				objects[path][key] = true
			elseif key == "<objectType>" and widgetMethods[kind] then
				-- objects.txt leaves out methods that come from the widget type (see Render); add them back.
				objects[path] = objects[path] or {}
				for method in pairs(widgetMethods[kind]) do
					objects[path][method] = true
				end
			end
		end
	end

	local out = {
		"-- Generated by scripts/api-import.sh from api/forever/" .. folder .. ". Do not edit.",
		"-- Blizzard globals that exist on Forever, for luacheck's read_globals.",
		"return {",
	}
	for line in (files["globals.txt"] or ""):gmatch("[^\n]+") do
		local name, kind = line:match("^([^\t]+)\t(.+)$")
		if name and name:match("^[%a_][%w_]*$") then
			local members = namespaces[name]
			if members and not members["<skipped>"] and not members["<forbidden>"] then
				out[#out + 1] = "\t[" .. quote(name) .. "] = { fields = {"
				for _, key in ipairs(sortedKeys(members)) do
					local open = (members[key] == "table" or members[key] == "widget") and "{ other_fields = true }" or "{}"
					out[#out + 1] = "\t\t[" .. quote(key) .. "] = " .. open .. ","
				end
				out[#out + 1] = "\t} },"
			elseif objects[name] and not opaque[name] then
				out[#out + 1] = "\t[" .. quote(name) .. "] = { fields = {"
				for _, key in ipairs(sortedKeys(objects[name])) do
					out[#out + 1] = "\t\t[" .. quote(key) .. "] = { other_fields = true },"
				end
				out[#out + 1] = "\t} },"
			elseif kind == "table" or kind == "widget" then
				out[#out + 1] = "\t[" .. quote(name) .. "] = { other_fields = true },"
			else
				out[#out + 1] = "\t[" .. quote(name) .. "] = {},"
			end
		end
	end
	out[#out + 1] = "}"
	return table.concat(out, "\n") .. "\n"
end

-- Structured API (api.json) --------------------------------------------------------------------

local scriptDir = (debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "./")
local json = dofile(scriptDir .. "json.lua")
local lualsDefs = dofile(scriptDir .. "luals_defs.lua")
local fs = dofile(scriptDir .. "fs.lua")

--- "name:type?, other:type=" -> list of {name, type, nilable[, default]}. A trailing "?" means Nilable, a
--- trailing "=" means the argument has a documented Default (both: "type?="). `default` is only set when
--- the dump records defaults at all, so older dumps don't claim "no default".
local function parseFields(text, withDefaults)
	local list = json.array({})
	for field in (text or ""):gmatch("[^,]+") do
		local name, kind = field:match("^%s*([^:]+):(.-)%s*$")
		if name then
			local default = kind:sub(-1) == "="
			if default then
				kind = kind:sub(1, -2)
			end
			local nilable = kind:sub(-1) == "?"
			local entry = { name = name, type = nilable and kind:sub(1, -2) or kind, nilable = nilable }
			if withDefaults then
				entry.default = default
			end
			list[#list + 1] = entry
		end
	end
	return list
end

--- The structured API (what api.json holds), built from one version's rendered text files so it can be
--- rebuilt for any committed version without the in-game dump:
---   meta {key = value}, globals {name = type}, namespaces {name = {key = type}},
---   widgets {Type = [methods] | false}, objects {path = {key = type}},
---   functions {"C_X.Name" = {args = [...], returns = [...]}}, events {NAME = {payload = [...]}}
--- args/returns/payload are lists of {name, type, nilable}.
function M.Structured(files)
	local api = { meta = {}, globals = {}, namespaces = {}, widgets = {}, objects = {}, functions = {}, events = {} }
	for key, value in (files["meta.txt"] or ""):gmatch("([^=\n]+)=([^\n]*)") do
		api.meta[key] = tonumber(value) or value
	end
	for name, kind in (files["globals.txt"] or ""):gmatch("([^\t\n]+)\t([^\n]+)") do
		api.globals[name] = kind
	end
	for name, key, kind in (files["namespaces.txt"] or ""):gmatch("([^.\t\n]+)%.([^\t\n]+)\t([^\n]+)") do
		api.namespaces[name] = api.namespaces[name] or {}
		api.namespaces[name][key] = kind
	end
	for line in (files["widgets.txt"] or ""):gmatch("[^\n]+") do
		local widgetType, method = line:match("^([^:\t]+):(.+)$")
		if widgetType then
			api.widgets[widgetType] = api.widgets[widgetType] or json.array({})
			table.insert(api.widgets[widgetType], method)
		else
			local unavailable = line:match("^([^\t]+)\tunavailable$")
			if unavailable then
				api.widgets[unavailable] = false
			end
		end
	end
	for line in (files["objects.txt"] or ""):gmatch("[^\n]+") do
		local path, key, kind = line:match("^(.+)%.([^.\t]+)\t(.+)$")
		if path then
			api.objects[path] = api.objects[path] or {}
			api.objects[path][key] = kind
		end
	end
	-- Dumps that record defaults mark them with "=" (e.g. "character:cstring="); older ones don't.
	local withDefaults = (files["docs.txt"] or ""):find("=[,)]") ~= nil
	api.meta.docsDefaults = withDefaults
	for line in (files["docs.txt"] or ""):gmatch("[^\n]+") do
		local name, args, returns = line:match("^function ([^(]+)%((.-)%) %-> %((.-)%)$")
		if name then
			api.functions[name] = { args = parseFields(args, withDefaults), returns = parseFields(returns) }
		else
			local event, payload = line:match("^event ([^(]+)%((.-)%)$")
			if event then
				api.events[event] = { payload = parseFields(payload) }
			end
		end
	end
	return api
end

-- Command line ----------------------------------------------------------------------------------

local function readFile(path)
	local f = io.open(path, "rb")
	if not f then
		return nil
	end
	local content = f:read("*a")
	f:close()
	return content
end

local function writeFile(path, content)
	local f = assert(io.open(path, "wb"))
	f:write(content)
	f:close()
end

local function listDirs(path)
	local dirs = {}
	for _, name in ipairs(fs.List(path)) do
		if name:match("%-%d+$") then
			dirs[#dirs + 1] = name
		end
	end
	return dirs
end

--- Regenerate everything derived from the committed text files: each version's api.json, CURRENT,
--- CHANGES.md and luacheck.lua. Used after an import, and on its own (--rebuild) when the generators
--- change.
function M.Rebuild(root)
	local base = root .. "/api/forever"
	local folders = M.SortVersions(listDirs(base))
	if #folders == 0 then
		io.stderr:write("No versions in " .. base .. "\n")
		os.exit(1)
	end
	local contents, structured = {}, {}
	for _, f in ipairs(folders) do
		contents[f] = { ["meta.txt"] = readFile(base .. "/" .. f .. "/meta.txt") }
		for _, name in ipairs(FILES) do
			contents[f][name .. ".txt"] = readFile(base .. "/" .. f .. "/" .. name .. ".txt")
		end
		structured[f] = M.Structured(contents[f])
		writeFile(base .. "/" .. f .. "/api.json", json.encode(structured[f]))
	end
	local current = folders[#folders]
	writeFile(base .. "/CURRENT", current .. "\n")
	writeFile(base .. "/CHANGES.md", M.Changes(folders, contents))
	writeFile(base .. "/luacheck.lua", M.Luacheck(contents[current], current))
	-- LuaLS definitions of the current version (.luarc.json points lua-language-server at them).
	fs.MakeDirs(base .. "/luals")
	for _, name in ipairs(fs.List(base .. "/luals")) do -- files are split into parts; drop parts that are gone
		if name:match("%.lua$") then
			os.remove(base .. "/luals/" .. name)
		end
	end
	for name, content in pairs(lualsDefs.Generate(structured[current], current)) do
		writeFile(base .. "/luals/" .. name, content)
	end
	return current, #folders
end

function M.Main(savedVariablesPath, root)
	local env = {}
	local chunk = assert(loadfile(savedVariablesPath))
	setfenv(chunk, env)
	chunk()
	local dump = env.OrdaenCoreDebugDB and env.OrdaenCoreDebugDB.apiDump
	if not dump then
		io.stderr:write("No apiDump in " .. savedVariablesPath .. '. Click "Dump game API" in the Ordaen Dev window.\n')
		os.exit(1)
	end

	local base = root .. "/api/forever"
	local folder = M.FolderName(dump.meta)
	fs.MakeDirs(base .. "/" .. folder)
	for name, content in pairs(M.Render(dump)) do
		local path = base .. "/" .. folder .. "/" .. name
		if MERGED[name] then
			content = M.Merge(readFile(path), content) -- same build dumped again: keep what earlier dumps saw
		end
		writeFile(path, content)
	end
	local current, count = M.Rebuild(root)
	print("Imported " .. folder .. " (current: " .. current .. ", versions: " .. count .. ")")
end

if arg and arg[0] and arg[0]:match("api_import%.lua$") and arg[1] then
	if arg[1] == "--rebuild" then
		local current, count = M.Rebuild(arg[2] or ".")
		print("Rebuilt " .. count .. " version(s) (current: " .. current .. ")")
	else
		M.Main(arg[1], arg[2] or ".")
	end
end

return M
