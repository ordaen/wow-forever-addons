-- Made by lunatype from OrdaenPanel/settings.luna: change the source, not this file.
local R = LunaType
local __getKey, __cell, __computed, __lens, __class, __inherit, __template, __draw = R.getKey, R.cell, R.computed, R.lens, R.class, R.inherit, R.template, R.draw
local __x = {
	OrdaenPanel_locales_PANEL_MICROICONS_UPSCALED = R.addon("OrdaenPanel")["locales"].PANEL_MICROICONS_UPSCALED,
	OrdaenPanel_locales_PANEL_MICROICONS_GOLD = R.addon("OrdaenPanel")["locales"].PANEL_MICROICONS_GOLD,
	OrdaenPanel_locales_PANEL_CHARBUTTON_PORTRAIT = R.addon("OrdaenPanel")["locales"].PANEL_CHARBUTTON_PORTRAIT,
	OrdaenPanel_locales_PANEL_CHARBUTTON_BUTTON = R.addon("OrdaenPanel")["locales"].PANEL_CHARBUTTON_BUTTON,
	OrdaenPanel_locales_PANEL_OUTLINE_NONE = R.addon("OrdaenPanel")["locales"].PANEL_OUTLINE_NONE,
	OrdaenPanel_locales_PANEL_OUTLINE_THIN = R.addon("OrdaenPanel")["locales"].PANEL_OUTLINE_THIN,
	OrdaenPanel_locales_PANEL_OUTLINE_THICK = R.addon("OrdaenPanel")["locales"].PANEL_OUTLINE_THICK,
	OrdaenPanel_locales_PANEL_EDGE_BOTTOM = R.addon("OrdaenPanel")["locales"].PANEL_EDGE_BOTTOM,
	OrdaenPanel_locales_PANEL_EDGE_TOP = R.addon("OrdaenPanel")["locales"].PANEL_EDGE_TOP,
	OrdaenPanel_locales_PANEL_EDGE_LEFT = R.addon("OrdaenPanel")["locales"].PANEL_EDGE_LEFT,
	OrdaenPanel_locales_PANEL_EDGE_RIGHT = R.addon("OrdaenPanel")["locales"].PANEL_EDGE_RIGHT,
	OrdaenPanel_locales_PANEL_FIT_FULL = R.addon("OrdaenPanel")["locales"].PANEL_FIT_FULL,
	OrdaenPanel_locales_PANEL_FIT_CENTER = R.addon("OrdaenPanel")["locales"].PANEL_FIT_CENTER,
	OrdaenPanel_locales_SECTION_ITEMS_LEFT = R.addon("OrdaenPanel")["locales"].SECTION_ITEMS_LEFT,
	OrdaenPanel_locales_SECTION_ITEMS_CENTER = R.addon("OrdaenPanel")["locales"].SECTION_ITEMS_CENTER,
	OrdaenPanel_locales_SECTION_ITEMS_RIGHT = R.addon("OrdaenPanel")["locales"].SECTION_ITEMS_RIGHT,
	OrdaenPanel_locales_SECTION_ITEMS_OFF = R.addon("OrdaenPanel")["locales"].SECTION_ITEMS_OFF,
	OrdaenPanel_locales_PANEL_MICROMENU = R.addon("OrdaenPanel")["locales"].PANEL_MICROMENU,
	OrdaenPanel_locales_PANEL_MICROMENU_TIP = R.addon("OrdaenPanel")["locales"].PANEL_MICROMENU_TIP,
	OrdaenPanel_locales_PANEL_SOCIAL = R.addon("OrdaenPanel")["locales"].PANEL_SOCIAL,
	OrdaenPanel_locales_PANEL_SOCIAL_TIP = R.addon("OrdaenPanel")["locales"].PANEL_SOCIAL_TIP,
	OrdaenPanel_locales_PANEL_EXPERIENCE = R.addon("OrdaenPanel")["locales"].PANEL_EXPERIENCE,
	OrdaenPanel_locales_PANEL_EXPERIENCE_TIP = R.addon("OrdaenPanel")["locales"].PANEL_EXPERIENCE_TIP,
	OrdaenPanel_locales_PANEL_ZONE = R.addon("OrdaenPanel")["locales"].PANEL_ZONE,
	OrdaenPanel_locales_PANEL_ZONE_TIP = R.addon("OrdaenPanel")["locales"].PANEL_ZONE_TIP,
	OrdaenPanel_locales_PANEL_CLOCK = R.addon("OrdaenPanel")["locales"].PANEL_CLOCK,
	OrdaenPanel_locales_PANEL_CLOCK_TIP = R.addon("OrdaenPanel")["locales"].PANEL_CLOCK_TIP,
	OrdaenPanel_locales_PANEL_CURRENCIES = R.addon("OrdaenPanel")["locales"].PANEL_CURRENCIES,
	OrdaenPanel_locales_PANEL_CURRENCIES_TIP = R.addon("OrdaenPanel")["locales"].PANEL_CURRENCIES_TIP,
	OrdaenPanel_locales_PANEL_BAGS = R.addon("OrdaenPanel")["locales"].PANEL_BAGS,
	OrdaenPanel_locales_PANEL_BAGS_TIP = R.addon("OrdaenPanel")["locales"].PANEL_BAGS_TIP,
	OrdaenPanel_locales_PANEL_SHOW_ALWAYS = R.addon("OrdaenPanel")["locales"].PANEL_SHOW_ALWAYS,
	OrdaenPanel_locales_PANEL_SHOW_MOUSEOVER = R.addon("OrdaenPanel")["locales"].PANEL_SHOW_MOUSEOVER,
	OrdaenPanel_locales_PANEL_SHOW_NEVER = R.addon("OrdaenPanel")["locales"].PANEL_SHOW_NEVER,
	OrdaenPanel_locales_PANEL_COMBAT_ANY = R.addon("OrdaenPanel")["locales"].PANEL_COMBAT_ANY,
	OrdaenPanel_locales_PANEL_COMBAT_HIDE = R.addon("OrdaenPanel")["locales"].PANEL_COMBAT_HIDE,
	OrdaenPanel_locales_PANEL_COMBAT_ONLY = R.addon("OrdaenPanel")["locales"].PANEL_COMBAT_ONLY,
	OrdaenLibrary_section_Section = R.addon("OrdaenLibrary")["section"].Section,
	OrdaenPanel_locales_SECTION_MICROMENU = R.addon("OrdaenPanel")["locales"].SECTION_MICROMENU,
	OrdaenLibrary_switch_Switch = R.addon("OrdaenLibrary")["switch"].Switch,
	OrdaenPanel_locales_PANEL_MICROON = R.addon("OrdaenPanel")["locales"].PANEL_MICROON,
	OrdaenPanel_locales_PANEL_MICROON_TIP = R.addon("OrdaenPanel")["locales"].PANEL_MICROON_TIP,
	OrdaenPanel_locales_SECTION_STATUS = R.addon("OrdaenPanel")["locales"].SECTION_STATUS,
	OrdaenPanel_locales_PANEL_STATUSON = R.addon("OrdaenPanel")["locales"].PANEL_STATUSON,
	OrdaenPanel_locales_PANEL_STATUSON_TIP = R.addon("OrdaenPanel")["locales"].PANEL_STATUSON_TIP,
	OrdaenPanel_locales_SECTION_BOTTOM = R.addon("OrdaenPanel")["locales"].SECTION_BOTTOM,
	OrdaenPanel_locales_PANEL_BOTTOMON = R.addon("OrdaenPanel")["locales"].PANEL_BOTTOMON,
	OrdaenPanel_locales_PANEL_BOTTOMON_TIP = R.addon("OrdaenPanel")["locales"].PANEL_BOTTOMON_TIP,
	OrdaenLibrary_dropdown_Dropdown = R.addon("OrdaenLibrary")["dropdown"].Dropdown,
	OrdaenPanel_locales_PANEL_MICROICONS = R.addon("OrdaenPanel")["locales"].PANEL_MICROICONS,
	OrdaenPanel_locales_PANEL_MICROICONS_TIP = R.addon("OrdaenPanel")["locales"].PANEL_MICROICONS_TIP,
	OrdaenPanel_locales_PANEL_CHARBUTTON = R.addon("OrdaenPanel")["locales"].PANEL_CHARBUTTON,
	OrdaenPanel_locales_PANEL_CHARBUTTON_TIP = R.addon("OrdaenPanel")["locales"].PANEL_CHARBUTTON_TIP,
	OrdaenPanel_locales_PANEL_OUTLINE = R.addon("OrdaenPanel")["locales"].PANEL_OUTLINE,
	OrdaenPanel_locales_PANEL_OUTLINE_TIP = R.addon("OrdaenPanel")["locales"].PANEL_OUTLINE_TIP,
	OrdaenLibrary_checkbox_Checkbox = R.addon("OrdaenLibrary")["checkbox"].Checkbox,
	OrdaenPanel_locales_PANEL_SHADOW = R.addon("OrdaenPanel")["locales"].PANEL_SHADOW,
	OrdaenPanel_locales_PANEL_SHADOW_TIP = R.addon("OrdaenPanel")["locales"].PANEL_SHADOW_TIP,
	OrdaenPanel_locales_PANEL_EDGE = R.addon("OrdaenPanel")["locales"].PANEL_EDGE,
	OrdaenPanel_locales_PANEL_EDGE_TIP = R.addon("OrdaenPanel")["locales"].PANEL_EDGE_TIP,
	OrdaenPanel_locales_PANEL_FIT = R.addon("OrdaenPanel")["locales"].PANEL_FIT,
	OrdaenPanel_locales_PANEL_FIT_TIP = R.addon("OrdaenPanel")["locales"].PANEL_FIT_TIP,
	OrdaenLibrary_slider_Slider = R.addon("OrdaenLibrary")["slider"].Slider,
	OrdaenPanel_locales_PANEL_HEIGHT = R.addon("OrdaenPanel")["locales"].PANEL_HEIGHT,
	OrdaenPanel_locales_PANEL_HEIGHT_TIP = R.addon("OrdaenPanel")["locales"].PANEL_HEIGHT_TIP,
	OrdaenPanel_locales_SECTION_ITEMS = R.addon("OrdaenPanel")["locales"].SECTION_ITEMS,
	OrdaenLibrary_zones_Zones = R.addon("OrdaenLibrary")["zones"].Zones,
	OrdaenPanel_locales_SECTION_VISIBILITY = R.addon("OrdaenPanel")["locales"].SECTION_VISIBILITY,
	OrdaenPanel_locales_PANEL_SHOW = R.addon("OrdaenPanel")["locales"].PANEL_SHOW,
	OrdaenPanel_locales_PANEL_SHOW_TIP = R.addon("OrdaenPanel")["locales"].PANEL_SHOW_TIP,
	OrdaenPanel_locales_PANEL_COMBAT = R.addon("OrdaenPanel")["locales"].PANEL_COMBAT,
	OrdaenPanel_locales_PANEL_COMBAT_TIP = R.addon("OrdaenPanel")["locales"].PANEL_COMBAT_TIP,
	OrdaenPanel_locales_PANEL_VEHICLE = R.addon("OrdaenPanel")["locales"].PANEL_VEHICLE,
	OrdaenPanel_locales_PANEL_VEHICLE_TIP = R.addon("OrdaenPanel")["locales"].PANEL_VEHICLE_TIP,
	OrdaenPanel_locales_PANEL_PETBATTLE = R.addon("OrdaenPanel")["locales"].PANEL_PETBATTLE,
	OrdaenPanel_locales_PANEL_PETBATTLE_TIP = R.addon("OrdaenPanel")["locales"].PANEL_PETBATTLE_TIP,
	OrdaenPanel_locales_PANEL_RESTING = R.addon("OrdaenPanel")["locales"].PANEL_RESTING,
	OrdaenPanel_locales_PANEL_RESTING_TIP = R.addon("OrdaenPanel")["locales"].PANEL_RESTING_TIP,
	OrdaenPanel_locales_PANEL_FADEDALPHA = R.addon("OrdaenPanel")["locales"].PANEL_FADEDALPHA,
	OrdaenPanel_locales_PANEL_FADEDALPHA_TIP = R.addon("OrdaenPanel")["locales"].PANEL_FADEDALPHA_TIP,
	Ordaen_module_Component = R.addon("Ordaen")["module"].Component,
}
local M = {}
R.addon("OrdaenPanel")["settings"] = M
local ICONS, CHAR_BUTTONS, OUTLINES, EDGES, FITS, ZONES, OFF, ITEMS, SHOWS, COMBATS, GeneralPage, MicroPage, StatusPage, BottomPage

local function __d3(self, parent)
	local __c4 = __x.OrdaenLibrary_switch_Switch.new(parent, __cell(__x.OrdaenPanel_locales_PANEL_MICROON), __lens(parent, self.settings.draft, "microOn"), __cell(__x.OrdaenPanel_locales_PANEL_MICROON_TIP), nil)
	__draw(parent, __c4, nil)
end

local function __d6(self, parent)
	local __c7 = __x.OrdaenLibrary_switch_Switch.new(parent, __cell(__x.OrdaenPanel_locales_PANEL_STATUSON), __lens(parent, self.settings.draft, "statusOn"), __cell(__x.OrdaenPanel_locales_PANEL_STATUSON_TIP), nil)
	__draw(parent, __c7, nil)
end

local function __d9(self, parent)
	local __c10 = __x.OrdaenLibrary_switch_Switch.new(parent, __cell(__x.OrdaenPanel_locales_PANEL_BOTTOMON), __lens(parent, self.settings.draft, "bottomOn"), __cell(__x.OrdaenPanel_locales_PANEL_BOTTOMON_TIP), nil)
	__draw(parent, __c10, nil)
end

local function __d1(self, parent)
	local __c2 = __x.OrdaenLibrary_section_Section.new(parent, __cell(__x.OrdaenPanel_locales_SECTION_MICROMENU))
	__draw(parent, __c2, { self = self, [""] = __d3 })
	local __c5 = __x.OrdaenLibrary_section_Section.new(parent, __cell(__x.OrdaenPanel_locales_SECTION_STATUS))
	__draw(parent, __c5, { self = self, [""] = __d6 })
	local __c8 = __x.OrdaenLibrary_section_Section.new(parent, __cell(__x.OrdaenPanel_locales_SECTION_BOTTOM))
	__draw(parent, __c8, { self = self, [""] = __d9 })
end

local function __c11(self)
	return not __getKey(self.settings.draft, "microOn")
end

local function __d12(self, parent)
	local __c13 = __x.OrdaenLibrary_dropdown_Dropdown.new(parent, __cell(__x.OrdaenPanel_locales_PANEL_MICROICONS), __lens(parent, self.settings.draft, "microIcons"), ICONS, __cell(__x.OrdaenPanel_locales_PANEL_MICROICONS_TIP), self.off)
	__draw(parent, __c13, nil)
	local __c14 = __x.OrdaenLibrary_dropdown_Dropdown.new(parent, __cell(__x.OrdaenPanel_locales_PANEL_CHARBUTTON), __lens(parent, self.settings.draft, "charButton"), CHAR_BUTTONS, __cell(__x.OrdaenPanel_locales_PANEL_CHARBUTTON_TIP), self.off)
	__draw(parent, __c14, nil)
end

local function __d15(self, parent)
	local __c16 = __x.OrdaenLibrary_dropdown_Dropdown.new(parent, __cell(__x.OrdaenPanel_locales_PANEL_OUTLINE), __lens(parent, self.settings.draft, "outline"), OUTLINES, __cell(__x.OrdaenPanel_locales_PANEL_OUTLINE_TIP), nil)
	__draw(parent, __c16, nil)
	local __c17 = __x.OrdaenLibrary_checkbox_Checkbox.new(parent, __cell(__x.OrdaenPanel_locales_PANEL_SHADOW), __lens(parent, self.settings.draft, "shadow"), __cell(__x.OrdaenPanel_locales_PANEL_SHADOW_TIP), nil)
	__draw(parent, __c17, nil)
end

local function __c18(self)
	return not __getKey(self.settings.draft, "bottomOn")
end

local function __d24(self, parent)
	local __c25 = __x.OrdaenLibrary_zones_Zones.new(parent, ITEMS, ZONES, OFF, __lens(parent, self.settings.draft, "places"))
	__draw(parent, __c25, nil)
end

local function __d27(self, parent)
	local __c28 = __x.OrdaenLibrary_dropdown_Dropdown.new(parent, __cell(__x.OrdaenPanel_locales_PANEL_SHOW), __lens(parent, self.settings.draft, "show"), SHOWS, __cell(__x.OrdaenPanel_locales_PANEL_SHOW_TIP), self.off)
	__draw(parent, __c28, nil)
	local __c29 = __x.OrdaenLibrary_dropdown_Dropdown.new(parent, __cell(__x.OrdaenPanel_locales_PANEL_COMBAT), __lens(parent, self.settings.draft, "combat"), COMBATS, __cell(__x.OrdaenPanel_locales_PANEL_COMBAT_TIP), self.off)
	__draw(parent, __c29, nil)
	local __c30 = __x.OrdaenLibrary_checkbox_Checkbox.new(parent, __cell(__x.OrdaenPanel_locales_PANEL_VEHICLE), __lens(parent, self.settings.draft, "vehicle"), __cell(__x.OrdaenPanel_locales_PANEL_VEHICLE_TIP), self.off)
	__draw(parent, __c30, nil)
	local __c31 = __x.OrdaenLibrary_checkbox_Checkbox.new(parent, __cell(__x.OrdaenPanel_locales_PANEL_PETBATTLE), __lens(parent, self.settings.draft, "petBattle"), __cell(__x.OrdaenPanel_locales_PANEL_PETBATTLE_TIP), self.off)
	__draw(parent, __c31, nil)
	local __c32 = __x.OrdaenLibrary_checkbox_Checkbox.new(parent, __cell(__x.OrdaenPanel_locales_PANEL_RESTING), __lens(parent, self.settings.draft, "resting"), __cell(__x.OrdaenPanel_locales_PANEL_RESTING_TIP), self.off)
	__draw(parent, __c32, nil)
	local __c33 = __x.OrdaenLibrary_slider_Slider.new(parent, __cell(__x.OrdaenPanel_locales_PANEL_FADEDALPHA), __lens(parent, self.settings.draft, "fadedAlpha"), 0, 1, 0.05, "percent", __cell(__x.OrdaenPanel_locales_PANEL_FADEDALPHA_TIP), self.off)
	__draw(parent, __c33, nil)
end

local function __d19(self, parent)
	local __c20 = __x.OrdaenLibrary_dropdown_Dropdown.new(parent, __cell(__x.OrdaenPanel_locales_PANEL_EDGE), __lens(parent, self.settings.draft, "edge"), EDGES, __cell(__x.OrdaenPanel_locales_PANEL_EDGE_TIP), self.off)
	__draw(parent, __c20, nil)
	local __c21 = __x.OrdaenLibrary_dropdown_Dropdown.new(parent, __cell(__x.OrdaenPanel_locales_PANEL_FIT), __lens(parent, self.settings.draft, "fit"), FITS, __cell(__x.OrdaenPanel_locales_PANEL_FIT_TIP), self.off)
	__draw(parent, __c21, nil)
	local __c22 = __x.OrdaenLibrary_slider_Slider.new(parent, __cell(__x.OrdaenPanel_locales_PANEL_HEIGHT), __lens(parent, self.settings.draft, "height"), 24, 96, nil, "px", __cell(__x.OrdaenPanel_locales_PANEL_HEIGHT_TIP), self.off)
	__draw(parent, __c22, nil)
	local __c23 = __x.OrdaenLibrary_section_Section.new(parent, __cell(__x.OrdaenPanel_locales_SECTION_ITEMS))
	__draw(parent, __c23, { self = self, [""] = __d24 })
	local __c26 = __x.OrdaenLibrary_section_Section.new(parent, __cell(__x.OrdaenPanel_locales_SECTION_VISIBILITY))
	__draw(parent, __c26, { self = self, [""] = __d27 })
end

ICONS = { { value = "upscaled", label = __x.OrdaenPanel_locales_PANEL_MICROICONS_UPSCALED }, { value = "gold", label = __x.OrdaenPanel_locales_PANEL_MICROICONS_GOLD } }
CHAR_BUTTONS = { { value = "portrait", label = __x.OrdaenPanel_locales_PANEL_CHARBUTTON_PORTRAIT }, { value = "button", label = __x.OrdaenPanel_locales_PANEL_CHARBUTTON_BUTTON } }
OUTLINES = { { value = "none", label = __x.OrdaenPanel_locales_PANEL_OUTLINE_NONE }, { value = "thin", label = __x.OrdaenPanel_locales_PANEL_OUTLINE_THIN }, { value = "thick", label = __x.OrdaenPanel_locales_PANEL_OUTLINE_THICK } }
EDGES = { { value = "bottom", label = __x.OrdaenPanel_locales_PANEL_EDGE_BOTTOM }, { value = "top", label = __x.OrdaenPanel_locales_PANEL_EDGE_TOP }, { value = "left", label = __x.OrdaenPanel_locales_PANEL_EDGE_LEFT }, { value = "right", label = __x.OrdaenPanel_locales_PANEL_EDGE_RIGHT } }
FITS = { { value = "full", label = __x.OrdaenPanel_locales_PANEL_FIT_FULL }, { value = "center", label = __x.OrdaenPanel_locales_PANEL_FIT_CENTER } }
ZONES = { { value = "left", label = __x.OrdaenPanel_locales_SECTION_ITEMS_LEFT }, { value = "center", label = __x.OrdaenPanel_locales_SECTION_ITEMS_CENTER }, { value = "right", label = __x.OrdaenPanel_locales_SECTION_ITEMS_RIGHT } }
OFF = { value = "off", label = __x.OrdaenPanel_locales_SECTION_ITEMS_OFF }
ITEMS = { { key = "micromenu", label = __x.OrdaenPanel_locales_PANEL_MICROMENU, hint = __x.OrdaenPanel_locales_PANEL_MICROMENU_TIP }, { key = "social", label = __x.OrdaenPanel_locales_PANEL_SOCIAL, hint = __x.OrdaenPanel_locales_PANEL_SOCIAL_TIP }, { key = "experience", label = __x.OrdaenPanel_locales_PANEL_EXPERIENCE, hint = __x.OrdaenPanel_locales_PANEL_EXPERIENCE_TIP }, { key = "zone", label = __x.OrdaenPanel_locales_PANEL_ZONE, hint = __x.OrdaenPanel_locales_PANEL_ZONE_TIP }, { key = "clock", label = __x.OrdaenPanel_locales_PANEL_CLOCK, hint = __x.OrdaenPanel_locales_PANEL_CLOCK_TIP }, { key = "currencies", label = __x.OrdaenPanel_locales_PANEL_CURRENCIES, hint = __x.OrdaenPanel_locales_PANEL_CURRENCIES_TIP }, { key = "bags", label = __x.OrdaenPanel_locales_PANEL_BAGS, hint = __x.OrdaenPanel_locales_PANEL_BAGS_TIP } }
SHOWS = { { value = "always", label = __x.OrdaenPanel_locales_PANEL_SHOW_ALWAYS }, { value = "mouseover", label = __x.OrdaenPanel_locales_PANEL_SHOW_MOUSEOVER }, { value = "never", label = __x.OrdaenPanel_locales_PANEL_SHOW_NEVER } }
COMBATS = { { value = "any", label = __x.OrdaenPanel_locales_PANEL_COMBAT_ANY }, { value = "hide", label = __x.OrdaenPanel_locales_PANEL_COMBAT_HIDE }, { value = "only", label = __x.OrdaenPanel_locales_PANEL_COMBAT_ONLY } }

GeneralPage = __class({})

function GeneralPage.new(__owner, settings)
	local self = setmetatable({}, GeneralPage)
	R.adopt(__owner, self)
	self.settings = settings
	return self
end

function GeneralPage:render()
	return __template(__d1, self)
end

MicroPage = __class({})

function MicroPage.new(__owner, settings)
	local self = setmetatable({}, MicroPage)
	R.adopt(__owner, self)
	self.settings = settings
	self.off = __computed(self, __c11, self)
	return self
end

function MicroPage:render()
	return __template(__d12, self)
end

StatusPage = __class({})

function StatusPage.new(__owner, settings)
	local self = setmetatable({}, StatusPage)
	R.adopt(__owner, self)
	self.settings = settings
	return self
end

function StatusPage:render()
	return __template(__d15, self)
end

BottomPage = __class({})

function BottomPage.new(__owner, settings)
	local self = setmetatable({}, BottomPage)
	R.adopt(__owner, self)
	self.settings = settings
	self.off = __computed(self, __c18, self)
	return self
end

function BottomPage:render()
	return __template(__d19, self)
end
__inherit(GeneralPage, { __x.Ordaen_module_Component })
__inherit(MicroPage, { __x.Ordaen_module_Component })
__inherit(StatusPage, { __x.Ordaen_module_Component })
__inherit(BottomPage, { __x.Ordaen_module_Component })

M.ICONS = ICONS
M.CHAR_BUTTONS = CHAR_BUTTONS
M.OUTLINES = OUTLINES
M.EDGES = EDGES
M.FITS = FITS
M.ZONES = ZONES
M.OFF = OFF
M.ITEMS = ITEMS
M.SHOWS = SHOWS
M.COMBATS = COMBATS
M.GeneralPage = GeneralPage
M.MicroPage = MicroPage
M.StatusPage = StatusPage
M.BottomPage = BottomPage
