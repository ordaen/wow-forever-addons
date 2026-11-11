-- Made by lunatype from Ordaen/ordaen.luna: change the source, not this file.
local R = LunaType
local __provide, __getKey, __peek, __set, __setKey, __cell, __push, __event, __emit, __destroy, __class, __inherit = R.provide, R.getKey, R.peek, R.set, R.setKey, R.cell, R.push, R.event, R.emit, R.destroy, R.class, R.inherit
local __insert = table.insert
local __Ordaen_core = R.addon("Ordaen")["core"]
local __runtime_mount = R.runtime.mount
local __runtime_screen = R.runtime.screen
local __runtime_copy = R.runtime.copy
local __Ordaen_keeper_Keeper = R.addon("Ordaen")["keeper"].Keeper
local __Ordaen_theme_THEME = R.addon("Ordaen")["theme"].THEME
local __Ordaen_settings_Settings = R.addon("Ordaen")["settings"].Settings
local __Ordaen_globals_DEFAULTS = R.addon("Ordaen")["globals"].DEFAULTS
local __Ordaen_drafts = R.addon("Ordaen")["drafts"]
local __runtime_kept = R.runtime.kept
local __runtime_command = R.runtime.command
local __Ordaen_module_Entry = R.addon("Ordaen")["module"].Entry
local __lang_App = R.lang.App
local M = {}
R.addon("Ordaen")["ordaen"] = M
local ModuleEntry, OrdaenCore

ModuleEntry = __class({})

function ModuleEntry.new(__owner, folder, title, icon, make)
	local self = setmetatable({}, ModuleEntry)
	R.adopt(__owner, self)
	self.folder = folder
	self.title = title
	self.icon = icon
	self.make = make
	self.on = __cell(false)
	self.pages = __cell({})
	self.made = nil
	return self
end

function ModuleEntry:enable(on)
	__Ordaen_core.turn(self.folder, on)
end

function ModuleEntry:running()
	return self.made ~= nil
end

function ModuleEntry:begin()
	local made = self.make()
	if made == nil then
		return
	end
	self.made = made
	__runtime_mount(made, __runtime_screen())
	__set(self.pages, __runtime_copy(made.pages))
	__set(self.on, true)
end

function ModuleEntry:stop()
	local made = self.made
	__set(self.pages, {})
	self.made = nil
	__set(self.on, false)
	if made ~= nil then
		__destroy(made)
	end
end

OrdaenCore = __class({})

function OrdaenCore.new(__owner)
	local self = setmetatable({}, OrdaenCore)
	R.adopt(__owner, self)
	self.keeper = __Ordaen_keeper_Keeper.new(self)
	self.icon = "Interface/Icons/Trade_Engineering"
	self.title = "Ordaen"
	self.theme = __cell(__Ordaen_theme_THEME)
	self.dev = __cell(false)
	self.devButton = __cell(false)
	self.settingsAsked = __event()
	self.modules = __cell({})
	self.globals = __Ordaen_settings_Settings.new(self, __Ordaen_globals_DEFAULTS, "account")
	self.placing = __cell(false)
	self.entries = {}
	self.places = __cell({})
	self.chosen = {}
	self.started = false
	__provide(R.addon("Ordaen"), "core", {}, self, { "theme", "icon", "title", "dev", "devButton", "settingsAsked", "modules", "globals", "placing" }, { "toggleDev", "toggleSettings", "register", "start", "turn", "togglePlacing", "moved", "putAt" })
	__Ordaen_drafts.naming(nil)
	return self
end

function OrdaenCore:toggleDev()
	__set(self.dev, not __peek(self.dev))
end

function OrdaenCore:toggleSettings(page)
	__emit(self.settingsAsked, page)
end

function OrdaenCore:togglePlacing()
	__set(self.placing, not __peek(self.placing))
end

function OrdaenCore:moved(part)
	return __getKey(self.places, part)
end

function OrdaenCore:putAt(part, place)
	if place == nil then
		__setKey(self.places, part, nil)
	else
		__setKey(self.places, part, __runtime_copy(place))
	end
end

function OrdaenCore:register(folder, title, icon, make)
	local entry = ModuleEntry.new(self, folder, title, icon, make)
	__insert(self.entries, entry)
	__push(self.modules, entry)
	return entry
end

function OrdaenCore:turn(folder, on)
	local __l1 = self.entries
	for i = 1, #__l1 do
		local entry = __l1[i]
		if entry.folder == folder and entry:running() ~= on then
			if on then
				__Ordaen_drafts.naming(folder)
				local __t2 = self.entries[i]
				if __t2 ~= nil then
					__t2:begin()
				end
				__Ordaen_drafts.naming(nil)
			else
				local __t3 = self.entries[i]
				if __t3 ~= nil then
					__t3:stop()
				end
			end
			if self.started then
				self.chosen[folder] = entry:running()
			end
		end
	end
end

function OrdaenCore:command(text)
	local page = (text):match("^%s*(%S+)")
	__emit(self.settingsAsked, page)
end

function OrdaenCore:start()
	self.chosen = __runtime_kept(false, "modules", {})
	__set(self.places, __runtime_kept(false, "places", {}))
	self.started = true
	__runtime_command("/ordaen", function(text)
		return self:command(text)
	end)
	local __l5 = self.entries
	for __i4 = 1, #__l5 do
		local entry = __l5[__i4]
		if self.chosen[entry.folder] ~= false then
			self:turn(entry.folder, true)
		end
	end
end
__inherit(ModuleEntry, { __Ordaen_module_Entry })
__inherit(OrdaenCore, { __lang_App })

M.ModuleEntry = ModuleEntry
M.OrdaenCore = OrdaenCore
R.run(OrdaenCore, "Ordaen")
