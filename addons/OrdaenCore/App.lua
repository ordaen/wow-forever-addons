-- The app (design: development/framework/app): Ordaen at the root. Modules register from their generated
-- __module.lua; at Ordaen's own ADDON_LOADED the app loads every module that is on and mounts its root into the
-- screen layer, before login. It fires the stages.
local addonName, ns = ...

local Core, Engine, Game, Define = ns.Core, ns.Engine, ns.Game, ns.Define
local type, error, pcall = type, error, pcall

---@class OrdaenApp
---@field currentFile string|nil the module file running now (Define.Component names its component by it)
---@field currentModule table|nil the module whose file runs now (Define.Component keeps it: its state's store)
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
		local previous, previousModule = App.currentFile, App.currentModule
		App.currentFile, App.currentModule = path, self
		local ok, result = pcall(export, self.import)
		App.currentFile, App.currentModule = previous, previousModule
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

local LIBRARY = "OrdaenLibrary" -- the component library's folder (Define.Library)

--- The component library: loaded at its first use (the first `game.ui:<Name>` no module file answers), or nil when
--- it can't be (not installed, or failing to load). Enabled for this character first, like the modules.
function App.Library()
	local library = modules[LIBRARY]
	if library or App.libraryFailed then
		return library
	end
	if C_AddOns.GetAddOnEnableState(LIBRARY, UnitName("player")) == 0 then
		C_AddOns.EnableAddOn(LIBRARY, UnitName("player"))
	end
	local ok, loaded = pcall(C_AddOns.LoadAddOn, LIBRARY)
	if not ok or not loaded then
		App.libraryFailed = true -- asked once: a missing library doesn't cost a LoadAddOn per draw
		if not ok then
			geterrorhandler()(loaded)
		end
	end
	return modules[LIBRARY]
end

local MountModule -- below: a module's root mounted, after its SavedVariables

--- An on-demand module (`onDemand = true`: the settings window): loaded and mounted on the dialog layer at its
--- first use, never at login, and not in the module list. Returns the module, or nil when it can't load.
---@param folder string
function App.OpenOnDemand(folder)
	local module = modules[folder]
	if module and module.root then
		return module
	end
	if C_AddOns.GetAddOnMetadata(folder, "X-Ordaen-OnDemand") ~= "1" then
		return nil
	end
	if C_AddOns.GetAddOnEnableState(folder, UnitName("player")) == 0 then
		C_AddOns.EnableAddOn(folder, UnitName("player"))
	end
	local ok, loaded = pcall(C_AddOns.LoadAddOn, folder)
	if not ok then
		geterrorhandler()(loaded)
		return nil
	end
	module = loaded and modules[folder]
	if module and not module.game then
		MountModule(module, Game.Layer.Dialog)
	end
	return module and module.root and module or nil
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

function MountModule(module, layer)
	module.db = SavedTable(module.name .. "DB")
	module.charDb = SavedTable(module.name .. "CharDB")
	module.game = Game.ForModule(module)
	local ok, declaration = pcall(module.Import, module, "module")
	if not ok then
		geterrorhandler()(declaration)
		return
	end
	if declaration.parts then -- its free parts: the placing mode knows them from now on
		ns.Placing.Declare(module.name, declaration.parts)
	end
	local short = module.name:gsub("^Ordaen", "")
	module.root = Engine:Mount(nil, declaration, 0, { ref = App.Handle(short) }, layer or Game.Layer.Screen, module,
		module.game)
	if module.root then
		ns.Commands.AddModule(module, declaration.commands) -- /ordaen <module> ...
	end
	module.debug:Logf("mounted: %s", module.root and "yes" or "failed")
end

-- The module list (`game.Modules`, the settings window's left column) ---------------------------------------------

-- Which modules are off: Ordaen's own setting, account-wide in OrdaenCoreDB (`off[folder] = true`, only the ones that
-- are off; the table only while one is), not the AddOns list.
local db

local function IsOff(folder)
	return db.off ~= nil and db.off[folder] == true
end

---@class OrdaenModuleEntry
---@field folder string "OrdaenPanel"
---@field title string the toc's Title ("Ordaen Panel")
---@field icon string|nil the toc's IconTexture (the build writes it from addon.jsonc's icon)
---@field on OrdaenValueSignal boolean: the player's choice
---@field loaded OrdaenValueSignal boolean: mounted and running now
---@field reason OrdaenValueSignal string|nil: why it can't run, nil when it can: the AddOns list's reason ("MISSING",
---  "DEP_DISABLED", ...; the game's text is _G["ADDON_" .. reason]) or "FAILED" (its own error stopped it)
---@field pending OrdaenValueSignal boolean: off but still running until /reload (Forever can't unload an addon)
local Entry = {}
local EntryMeta = { __index = Entry }

local list = {} -- the entries in AddOns order
App.modules = list

-- Load and mount the module, out of the AddOns list's say: Ordaen decides which of its modules run, so one disabled
-- there (by the character, or new since the client started) is enabled for this character first.
function Entry:Load()
	local folder = self.folder
	local module = modules[folder]
	if module and module.root then
		return
	end
	if C_AddOns.GetAddOnEnableState(folder, UnitName("player")) == 0 then
		C_AddOns.EnableAddOn(folder, UnitName("player"))
	end
	local ok, loaded, reason = pcall(C_AddOns.LoadAddOn, folder)
	if not ok then
		geterrorhandler()(loaded)
	end
	module = modules[folder]
	if ok and loaded and module and not module.game then
		MountModule(module)
	end
	local running = module and module.root ~= nil or false
	self.loaded:Set(running)
	self.reason:Set(not running and (ok and not loaded and reason or "FAILED") or nil)
end

--- Turn the module on or off. On loads and mounts it now; off is stored, and it keeps running (pending) until
--- /reload: Forever can't unload an addon, and its /reload needs the player's click (a secure button).
---@param on boolean
function Entry:Enable(on)
	on = on and true or false
	if not on then
		db.off = db.off or {}
		db.off[self.folder] = true
	elseif db.off then
		db.off[self.folder] = nil
		if next(db.off) == nil then
			db.off = nil
		end
	end
	self.on:Set(on)
	if on then
		self:Load()
	end
	self.pending:Set(not on and self.loaded:Peek())
end

local function LoadModules()
	db = OrdaenCore.SavedVariables({ db = "OrdaenCoreDB" })
	for i = 1, C_AddOns.GetNumAddOns() do
		local name, title = C_AddOns.GetAddOnInfo(i)
		if type(name) == "string" and C_AddOns.GetAddOnMetadata(name, "X-Ordaen-Module") == "1" then
			ns.Commands.Know(name) -- /ordaen <module> answers "off" until it mounts
			local entry = setmetatable({
				folder = name, title = title or name, icon = C_AddOns.GetAddOnMetadata(name, "IconTexture"),
				on = ns.NewValue(not IsOff(name)), loaded = ns.NewValue(false), reason = ns.NewValue(nil),
				pending = ns.NewValue(false),
			}, EntryMeta)
			list[#list + 1] = entry
			if entry.on:Peek() then
				entry:Load()
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
			-- Ordaen's own SavedVariables (its global settings and, later, the players' themes): there now
			ns.Globals.Load(OrdaenCore.SavedVariables({ db = "OrdaenCoreDB" }))
			ns.Themes.Load()
			ns.Themes.Start()
			ns.Placing.Load()
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
