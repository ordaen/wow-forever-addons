-- The real Forever API as dumped in game (api/forever/CURRENT), for specs. Returns nil-ish answers
-- while no dump has been imported yet, so specs can mark themselves pending instead of failing.
local M = {}

-- Folder that contains api/forever/. The private wow-dev-tools repo points it at this checkout.
M.root = "."

local function read(path)
	local f = io.open(path, "rb")
	if not f then
		return nil
	end
	local content = f:read("*a")
	f:close()
	return content
end

--- The folder of the current dump, e.g. "1.60.1-70790", or nil when none is imported.
function M.Current()
	local current = read(M.root .. "/api/forever/CURRENT")
	return current and current:match("^%s*(.-)%s*$") or nil
end

local function file(name)
	local current = M.Current()
	return current and read(M.root .. "/api/forever/" .. current .. "/" .. name) or nil
end

--- Set of Blizzard global names, or nil.
function M.Globals()
	local text = file("globals.txt")
	if not text then
		return nil
	end
	local set = {}
	for name in text:gmatch("([^\t\n]+)\t[^\n]*") do
		set[name] = true
	end
	return set
end

-- Templates our frames inherit (CreateFrame's 4th argument) mix in Blizzard methods from these tables.
M.TEMPLATE_MIXINS = {
	BackdropTemplate = "BackdropTemplateMixin",
}

--- Set of method names any widget type, dumped Blizzard object or template mixin we use has, or nil.
function M.Methods()
	local widgets, objects, namespaces = file("widgets.txt"), file("objects.txt"), file("namespaces.txt")
	if not widgets then
		return nil
	end
	local set = {}
	for method in widgets:gmatch(":([%w_]+)\n") do
		set[method] = true
	end
	for key in (objects or ""):gmatch("%.([%w_]+)\tfunction\n") do
		set[key] = true
	end
	for _, mixin in pairs(M.TEMPLATE_MIXINS) do
		for key in (namespaces or ""):gmatch("\n" .. mixin .. "%.([%w_]+)\tfunction") do
			set[key] = true
		end
	end
	return set
end

-- Globals that aren't Blizzard's but may be stubbed: ours, and other addons' we use when present.
local NOT_BLIZZARD = { LibStub = true, BugGrabber = true, GetMinimapShape = true }

local function ours(name)
	return NOT_BLIZZARD[name] or name:find("^Ordaen") or name:find("^SLASH_ORDAEN")
end

--- Error when a spec stubs a global Forever doesn't have (no-op until a dump is imported).
---@param names table list of global names a spec is about to stub
function M.CheckStubs(names)
	local globals = M.Globals()
	if not globals then
		return
	end
	local missing = {}
	for _, name in ipairs(names) do
		if not globals[name] and not ours(name) then
			missing[#missing + 1] = name
		end
	end
	if #missing > 0 then
		table.sort(missing)
		error("stubbed globals that Forever " .. M.Current() .. " doesn't have: " .. table.concat(missing, ", "), 2)
	end
end

return M
