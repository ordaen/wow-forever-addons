-- The app (design: development/framework/app): Ordaen at the root. Modules register from their generated
-- __module.lua; at Ordaen's own ADDON_LOADED the app loads every module that is on and mounts its root into the
-- screen layer, before login. It fires the stages.
local addonName, ns = ...

local Core, Engine, Game, Define = ns.Core, ns.Engine, ns.Game, ns.Define
local type, error, pcall = type, error, pcall

---@class OrdaenApp
---@field currentFile string|nil the module file running now (Define.Component names its component by it)
local App = {}
ns.App = App

local modules = {} -- folder -> module
local handles = {} -- name without "Ordaen" -> handle (game:UseModule)

---@class OrdaenModuleContext
local Module = {}
local ModuleMeta = { __index = Module }

local IMPORTING = {} -- marks a file whose import is running (a cycle)

-- What the build freezes in a module file goes through here (design: development/framework/structure, «Frozen
-- tables»). Forever's table.freeze freezes only a table owned by its caller's addon, and a module file's tables are
-- made while OrdaenCore imports it: they are OrdaenCore's, so OrdaenCore's function freezes them. A table it can't
-- freeze stays as it is (the module still loads) and the import reports it in dev.
local freeze = table.freeze
local freezeError -- the first failure while a file is imported
local function Freeze(t)
	local ok, err = pcall(freeze, t)
	if not ok and not freezeError then
		freezeError = err
	end
	return t
end

--- A file's export by its path in the module; runs the file the first time.
---@param path string
function Module:Import(path)
	if path == "@ordaen/define" then
		return Define
	elseif path == "@ordaen/freeze" then
		return Freeze
	end
	local cached = self.cache[path]
	if cached == IMPORTING then
		error("Ordaen: " .. self.name .. " imports " .. path .. " in a cycle", 2)
	elseif cached ~= nil then
		return cached
	end
	local export = self.ns[path]
	if export == nil then
		error("Ordaen: " .. self.name .. " has no file " .. path, 2)
	end
	if type(export) == "function" then
		self.cache[path] = IMPORTING
		local previous = App.currentFile
		App.currentFile = path
		local ok, result = pcall(export, self.import)
		App.currentFile = previous
		if freezeError then
			self.debug:Warnf("%s: a table the build froze stayed writable: %s", path, tostring(freezeError))
			freezeError = nil
		end
		if not ok then
			self.cache[path] = nil
			error(result, 0)
		end
		export = result
		if export == nil then
			export = false
		end
	end
	self.cache[path] = export
	return export
end

function Module:Conflict() end -- luacheck: ignore 212
function Module:Conflicts() return {} end -- luacheck: ignore 212
function Module:OpenSettings() end -- luacheck: ignore 212

--- Called by every module's generated __module.lua with WoW's (folder, ns).
---@param folder string
---@param moduleNs table
function Core.RegisterModule(folder, moduleNs)
	local module = setmetatable({
		name = folder, ns = moduleNs, cache = {},
		debug = Core.NewDebug(folder),
		Signal = { Conflict = ns.NewEvent() },
	}, ModuleMeta)
	module.import = function(path)
		return module:Import(path)
	end
	modules[folder] = module
end

--- A registered module by its folder ("OrdaenBench"), or nil.
---@param folder string
function App.Module(folder)
	return modules[folder]
end

--- A module's public part by its name ("Notices" for OrdaenNotices): stable, empty while it's off.
---@param name string
function App.Handle(name)
	local handle = handles[name]
	if not handle then
		handle = Engine.NewHandle()
		handles[name] = handle
	end
	return handle
end

local function SavedTable(global)
	local t = _G[global]
	if type(t) ~= "table" then
		t = {}
		_G[global] = t
	end
	return t
end

local function MountModule(module)
	module.db = SavedTable(module.name .. "DB")
	module.charDb = SavedTable(module.name .. "CharDB")
	module.game = Game.ForModule(module)
	local ok, declaration = pcall(module.Import, module, "module")
	if not ok then
		geterrorhandler()(declaration)
		return
	end
	local short = module.name:gsub("^Ordaen", "")
	module.root = Engine:Mount(nil, declaration, 0, { ref = App.Handle(short) }, Game.Layer.Screen, module, module.game)
	if module.root then
		ns.Commands.AddModule(module, declaration.commands) -- /ordaen <module> ...
	end
	module.debug:Logf("mounted: %s", module.root and "yes" or "failed")
end

local function LoadModules()
	for i = 1, C_AddOns.GetNumAddOns() do
		local name = C_AddOns.GetAddOnInfo(i)
		if type(name) == "string" and C_AddOns.GetAddOnMetadata(name, "X-Ordaen-Module") == "1" then
			ns.Commands.Know(name) -- /ordaen <module> answers "off" until it mounts
			-- Ordaen decides which of its modules run, not the AddOns list: one disabled there (by the character, or new
			-- since the client started) is enabled for this character before it loads
			if C_AddOns.GetAddOnEnableState(name, UnitName("player")) == 0 then
				C_AddOns.EnableAddOn(name, UnitName("player"))
			end
			local ok, loaded = pcall(C_AddOns.LoadAddOn, name)
			if not ok then
				geterrorhandler()(loaded)
			elseif loaded and modules[name] and not modules[name].game then
				MountModule(modules[name])
			end
		end
	end
end

-- The app's own events, on its own frame: loading the modules and the stages.
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("LOADING_SCREEN_DISABLED")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:SetScript("OnEvent", function(_, event, arg)
	local Stage = ns.Stage
	if event == "ADDON_LOADED" then
		if arg == addonName then
			frame:UnregisterEvent("ADDON_LOADED")
			LoadModules()
		end
	elseif event == "PLAYER_LOGIN" then
		frame:UnregisterEvent("PLAYER_LOGIN")
		Stage.Login:Fire()
	elseif event == "LOADING_SCREEN_DISABLED" then
		frame:UnregisterEvent("LOADING_SCREEN_DISABLED")
		Stage.Ready:Fire()
	else
		Stage.Shutdown:Fire()
	end
end)
