-- Made by lunatype from OrdaenMinimap/settings.luna: change the source, not this file.
local R = LunaType
local __getKey, __cell, __computed, __lens, __class, __inherit, __template, __draw = R.getKey, R.cell, R.computed, R.lens, R.class, R.inherit, R.template, R.draw
local __OrdaenMinimap_locales_MINIMAP_HIDE_NEVER = R.addon("OrdaenMinimap")["locales"].MINIMAP_HIDE_NEVER
local __OrdaenMinimap_locales_MINIMAP_HIDE_COMBAT = R.addon("OrdaenMinimap")["locales"].MINIMAP_HIDE_COMBAT
local __OrdaenMinimap_locales_MINIMAP_HIDE_TRANSPORT = R.addon("OrdaenMinimap")["locales"].MINIMAP_HIDE_TRANSPORT
local __OrdaenLibrary_slider_Slider = R.addon("OrdaenLibrary")["slider"].Slider
local __OrdaenMinimap_locales_MINIMAP_SCALE = R.addon("OrdaenMinimap")["locales"].MINIMAP_SCALE
local __OrdaenMinimap_locales_MINIMAP_SCALE_TIP = R.addon("OrdaenMinimap")["locales"].MINIMAP_SCALE_TIP
local __OrdaenLibrary_checkbox_Checkbox = R.addon("OrdaenLibrary")["checkbox"].Checkbox
local __OrdaenMinimap_locales_MINIMAP_SHOWZONE = R.addon("OrdaenMinimap")["locales"].MINIMAP_SHOWZONE
local __OrdaenMinimap_locales_MINIMAP_SHOWZONE_TIP = R.addon("OrdaenMinimap")["locales"].MINIMAP_SHOWZONE_TIP
local __OrdaenMinimap_locales_MINIMAP_SHOWCLOCK = R.addon("OrdaenMinimap")["locales"].MINIMAP_SHOWCLOCK
local __OrdaenMinimap_locales_MINIMAP_SHOWCLOCK_TIP = R.addon("OrdaenMinimap")["locales"].MINIMAP_SHOWCLOCK_TIP
local __OrdaenMinimap_locales_MINIMAP_SHOWCOORDS = R.addon("OrdaenMinimap")["locales"].MINIMAP_SHOWCOORDS
local __OrdaenMinimap_locales_MINIMAP_SHOWCOORDS_TIP = R.addon("OrdaenMinimap")["locales"].MINIMAP_SHOWCOORDS_TIP
local __OrdaenMinimap_locales_MINIMAP_BUTTONSHOVER = R.addon("OrdaenMinimap")["locales"].MINIMAP_BUTTONSHOVER
local __OrdaenMinimap_locales_MINIMAP_BUTTONSHOVER_TIP = R.addon("OrdaenMinimap")["locales"].MINIMAP_BUTTONSHOVER_TIP
local __OrdaenLibrary_dropdown_Dropdown = R.addon("OrdaenLibrary")["dropdown"].Dropdown
local __OrdaenMinimap_locales_MINIMAP_HIDE = R.addon("OrdaenMinimap")["locales"].MINIMAP_HIDE
local __OrdaenMinimap_locales_MINIMAP_HIDE_TIP = R.addon("OrdaenMinimap")["locales"].MINIMAP_HIDE_TIP
local __OrdaenLibrary_switch_Switch = R.addon("OrdaenLibrary")["switch"].Switch
local __OrdaenMinimap_locales_MINIMAP_DRAWERON = R.addon("OrdaenMinimap")["locales"].MINIMAP_DRAWERON
local __OrdaenMinimap_locales_MINIMAP_DRAWERON_TIP = R.addon("OrdaenMinimap")["locales"].MINIMAP_DRAWERON_TIP
local __OrdaenMinimap_locales_MINIMAP_DRAWERCOLUMNS = R.addon("OrdaenMinimap")["locales"].MINIMAP_DRAWERCOLUMNS
local __OrdaenMinimap_locales_MINIMAP_DRAWERCOLUMNS_TIP = R.addon("OrdaenMinimap")["locales"].MINIMAP_DRAWERCOLUMNS_TIP
local __Ordaen_module_Component = R.addon("Ordaen")["module"].Component
local M = {}
R.addon("OrdaenMinimap")["settings"] = M
local HIDES, MapPage, DrawerPage

local function __d1(self, parent)
	local __c2 = __OrdaenLibrary_slider_Slider.new(parent, __cell(__OrdaenMinimap_locales_MINIMAP_SCALE), __lens(parent, self.settings.draft, "scale"), 0.8, 1.6, 0.05, "percent", __cell(__OrdaenMinimap_locales_MINIMAP_SCALE_TIP), nil)
	__draw(parent, __c2, nil)
	local __c3 = __OrdaenLibrary_checkbox_Checkbox.new(parent, __cell(__OrdaenMinimap_locales_MINIMAP_SHOWZONE), __lens(parent, self.settings.draft, "showZone"), __cell(__OrdaenMinimap_locales_MINIMAP_SHOWZONE_TIP), nil)
	__draw(parent, __c3, nil)
	local __c4 = __OrdaenLibrary_checkbox_Checkbox.new(parent, __cell(__OrdaenMinimap_locales_MINIMAP_SHOWCLOCK), __lens(parent, self.settings.draft, "showClock"), __cell(__OrdaenMinimap_locales_MINIMAP_SHOWCLOCK_TIP), nil)
	__draw(parent, __c4, nil)
	local __c5 = __OrdaenLibrary_checkbox_Checkbox.new(parent, __cell(__OrdaenMinimap_locales_MINIMAP_SHOWCOORDS), __lens(parent, self.settings.draft, "showCoords"), __cell(__OrdaenMinimap_locales_MINIMAP_SHOWCOORDS_TIP), nil)
	__draw(parent, __c5, nil)
	local __c6 = __OrdaenLibrary_checkbox_Checkbox.new(parent, __cell(__OrdaenMinimap_locales_MINIMAP_BUTTONSHOVER), __lens(parent, self.settings.draft, "buttonsHover"), __cell(__OrdaenMinimap_locales_MINIMAP_BUTTONSHOVER_TIP), nil)
	__draw(parent, __c6, nil)
	local __c7 = __OrdaenLibrary_dropdown_Dropdown.new(parent, __cell(__OrdaenMinimap_locales_MINIMAP_HIDE), __lens(parent, self.settings.draft, "hide"), HIDES, __cell(__OrdaenMinimap_locales_MINIMAP_HIDE_TIP), nil)
	__draw(parent, __c7, nil)
end

local function __c8(self)
	return not __getKey(self.settings.draft, "drawerOn")
end

local function __d9(self, parent)
	local __c10 = __OrdaenLibrary_switch_Switch.new(parent, __cell(__OrdaenMinimap_locales_MINIMAP_DRAWERON), __lens(parent, self.settings.draft, "drawerOn"), __cell(__OrdaenMinimap_locales_MINIMAP_DRAWERON_TIP), nil)
	__draw(parent, __c10, nil)
	local __c11 = __OrdaenLibrary_slider_Slider.new(parent, __cell(__OrdaenMinimap_locales_MINIMAP_DRAWERCOLUMNS), __lens(parent, self.settings.draft, "drawerColumns"), 2, 12, nil, nil, __cell(__OrdaenMinimap_locales_MINIMAP_DRAWERCOLUMNS_TIP), self.drawerOff)
	__draw(parent, __c11, nil)
end

HIDES = { { value = "never", label = __OrdaenMinimap_locales_MINIMAP_HIDE_NEVER }, { value = "combat", label = __OrdaenMinimap_locales_MINIMAP_HIDE_COMBAT }, { value = "transport", label = __OrdaenMinimap_locales_MINIMAP_HIDE_TRANSPORT } }

MapPage = __class({})

function MapPage.new(__owner, settings)
	local self = setmetatable({}, MapPage)
	R.adopt(__owner, self)
	self.settings = settings
	return self
end

function MapPage:render()
	return __template(__d1, self)
end

DrawerPage = __class({})

function DrawerPage.new(__owner, settings)
	local self = setmetatable({}, DrawerPage)
	R.adopt(__owner, self)
	self.settings = settings
	self.drawerOff = __computed(self, __c8, self)
	return self
end

function DrawerPage:render()
	return __template(__d9, self)
end
__inherit(MapPage, { __Ordaen_module_Component })
__inherit(DrawerPage, { __Ordaen_module_Component })

M.HIDES = HIDES
M.MapPage = MapPage
M.DrawerPage = DrawerPage
