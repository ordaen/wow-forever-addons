-- Files and folders without a shell (find, ls, mkdir -p, rm -rf), for the scripts and specs: they run inside the
-- ordaen CLI's own Lua on Windows, where there is no POSIX shell, and in plain Lua 5.1 with luarocks on Linux.
-- Both provide LuaFileSystem (`lfs`). Paths use "/" and come out sorted, like `find ... | sort`.
local lfs = require("lfs")

local M = {}

local function isDir(path)
	return lfs.attributes(path, "mode") == "directory"
end

--- Every file under `root` (recursively) whose path matches `pattern` (a Lua pattern, e.g. "%.lua$"), sorted.
---@param root string
---@param pattern string|nil
---@return string[]
function M.Files(root, pattern)
	local out = {}
	local function walk(dir)
		if not isDir(dir) then
			return
		end
		for name in lfs.dir(dir) do
			if name ~= "." and name ~= ".." then
				local path = dir .. "/" .. name
				local mode = lfs.attributes(path, "mode")
				if mode == "directory" then
					walk(path)
				elseif mode == "file" and (not pattern or path:find(pattern)) then
					out[#out + 1] = path
				end
			end
		end
	end
	walk((root:gsub("/+$", "")))
	table.sort(out)
	return out
end

--- The names in one folder (not recursive), sorted; empty when it doesn't exist.
---@param dir string
---@return string[]
function M.List(dir)
	local out = {}
	if isDir(dir) then
		for name in lfs.dir(dir) do
			if name ~= "." and name ~= ".." then
				out[#out + 1] = name
			end
		end
	end
	table.sort(out)
	return out
end

--- `mkdir -p`.
---@param path string
function M.MakeDirs(path)
	local sofar = path:match("^/") and "" or nil
	for part in path:gmatch("[^/\\]+") do
		sofar = sofar and (sofar .. "/" .. part) or part
		if not isDir(sofar) then
			lfs.mkdir(sofar)
		end
	end
	assert(isDir(path), "couldn't create " .. path)
end

--- `rm -rf`.
---@param path string
function M.Remove(path)
	local mode = lfs.attributes(path, "mode")
	if mode == "directory" then
		for _, name in ipairs(M.List(path)) do
			M.Remove(path .. "/" .. name)
		end
		assert(lfs.rmdir(path))
	elseif mode then
		assert(os.remove(path))
	end
end

--- A new empty folder for a spec's files, under the repo's gitignored .ordaen/ (os.tmpname has no folder form, and
--- on Windows it names a file in the drive's root).
---@param name string
---@return string
function M.TempDir(name)
	local dir = ".ordaen/tmp/" .. name .. "-" .. tostring(os.time()) .. "-" .. tostring(math.random(1e6))
	M.Remove(dir)
	M.MakeDirs(dir)
	return dir
end

return M
