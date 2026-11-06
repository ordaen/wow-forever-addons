-- Our addon code against the real Forever API (api/forever/CURRENT). luacheck already checks globals
-- and namespace functions (api/forever/luacheck.lua); this checks ":Method(" calls, which luacheck
-- can't see. Pending until the first in-game dump is imported (scripts/api-import.sh).
local forever = require("tests.repo.forever_api")
local allowlist = dofile("tests/repo/method_allowlist.lua")

local function addonFiles()
	local files = {}
	for _, path in ipairs(require("scripts.fs").Files("addons", "%.lua$")) do
		files[#files + 1] = path
	end
	return files
end

local function read(path)
	local f = assert(io.open(path, "rb"))
	local content = f:read("*a")
	f:close()
	return content
end

-- Strip comments and string literals so method names inside them don't count.
local function code(source)
	source = source:gsub("%-%-%[(=*)%[.-%]%1%]", "")
	source = source:gsub("%-%-[^\n]*", "")
	source = source:gsub("%[(=*)%[.-%]%1%]", '""')
	source = source:gsub('"[^"\n]*"', '""')
	source = source:gsub("'[^'\n]*'", "''")
	return source
end

describe("addon code against the Forever API dump", function()
	local methods = forever.Methods()
	if not methods then
		pending("no API dump imported yet (Ordaen Dev window: Dump game API, then scripts/api-import.sh)")
		return
	end

	it("only calls methods that exist on Forever", function()
		local own = {} -- methods our own code defines (function X:Name / X.Name = function(self)
		local sources = {}
		for _, path in ipairs(addonFiles()) do
			sources[path] = code(read(path))
			for name in sources[path]:gmatch("function%s+[%w_%.]+:([%w_]+)%s*%(") do
				own[name] = true
			end
			for name in sources[path]:gmatch("%.([%w_]+)%s*=%s*function%s*%(%s*self") do
				own[name] = true
			end
		end
		local unknown = {}
		for path, source in pairs(sources) do
			for name in source:gmatch(":([%a_][%w_]*)%s*%(") do
				if not methods[name] and not allowlist[name] and not own[name] then
					unknown[#unknown + 1] = path .. ": " .. name
				end
			end
		end
		table.sort(unknown)
		assert.same({}, unknown, "methods not in the Forever " .. forever.Current() .. " dump (or the allowlist)")
	end)
end)
