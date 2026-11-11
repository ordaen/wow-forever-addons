-- Made by lunatype from OrdaenSettings/general.luna: change the source, not this file.
local R = LunaType
local __getKey, __cell, __computed, __lens, __class, __inherit, __template, __draw = R.getKey, R.cell, R.computed, R.lens, R.class, R.inherit, R.template, R.draw
local __OrdaenSettings_locales_GLOBAL_DENSITY_COMPACT = R.addon("OrdaenSettings")["locales"].GLOBAL_DENSITY_COMPACT
local __OrdaenSettings_locales_GLOBAL_DENSITY_NORMAL = R.addon("OrdaenSettings")["locales"].GLOBAL_DENSITY_NORMAL
local __OrdaenSettings_locales_GLOBAL_DENSITY_ROOMY = R.addon("OrdaenSettings")["locales"].GLOBAL_DENSITY_ROOMY
local __OrdaenSettings_locales_GLOBAL_NUMBERFORMAT_SPACE = R.addon("OrdaenSettings")["locales"].GLOBAL_NUMBERFORMAT_SPACE
local __OrdaenSettings_locales_GLOBAL_NUMBERFORMAT_COMMA = R.addon("OrdaenSettings")["locales"].GLOBAL_NUMBERFORMAT_COMMA
local __OrdaenSettings_locales_GLOBAL_NUMBERFORMAT_DOT = R.addon("OrdaenSettings")["locales"].GLOBAL_NUMBERFORMAT_DOT
local __OrdaenSettings_locales_GLOBAL_NUMBERS_FULL = R.addon("OrdaenSettings")["locales"].GLOBAL_NUMBERS_FULL
local __OrdaenSettings_locales_GLOBAL_NUMBERS_SHORT = R.addon("OrdaenSettings")["locales"].GLOBAL_NUMBERS_SHORT
local __OrdaenSettings_locales_GLOBAL_CLOCK_24 = R.addon("OrdaenSettings")["locales"].GLOBAL_CLOCK_24
local __OrdaenSettings_locales_GLOBAL_CLOCK_12 = R.addon("OrdaenSettings")["locales"].GLOBAL_CLOCK_12
local __OrdaenLibrary_slider_Slider = R.addon("OrdaenLibrary")["slider"].Slider
local __OrdaenSettings_locales_GLOBAL_SCALE = R.addon("OrdaenSettings")["locales"].GLOBAL_SCALE
local __OrdaenSettings_locales_GLOBAL_SCALE_TIP = R.addon("OrdaenSettings")["locales"].GLOBAL_SCALE_TIP
local __OrdaenLibrary_dropdown_Dropdown = R.addon("OrdaenLibrary")["dropdown"].Dropdown
local __OrdaenSettings_locales_GLOBAL_DENSITY = R.addon("OrdaenSettings")["locales"].GLOBAL_DENSITY
local __OrdaenSettings_locales_GLOBAL_DENSITY_TIP = R.addon("OrdaenSettings")["locales"].GLOBAL_DENSITY_TIP
local __OrdaenLibrary_checkbox_Checkbox = R.addon("OrdaenLibrary")["checkbox"].Checkbox
local __OrdaenSettings_locales_GLOBAL_PIXEL = R.addon("OrdaenSettings")["locales"].GLOBAL_PIXEL
local __OrdaenSettings_locales_GLOBAL_PIXEL_TIP = R.addon("OrdaenSettings")["locales"].GLOBAL_PIXEL_TIP
local __OrdaenSettings_locales_GLOBAL_NUMBERFORMAT = R.addon("OrdaenSettings")["locales"].GLOBAL_NUMBERFORMAT
local __OrdaenSettings_locales_GLOBAL_NUMBERFORMAT_TIP = R.addon("OrdaenSettings")["locales"].GLOBAL_NUMBERFORMAT_TIP
local __OrdaenSettings_locales_GLOBAL_NUMBERROUND = R.addon("OrdaenSettings")["locales"].GLOBAL_NUMBERROUND
local __OrdaenSettings_locales_GLOBAL_NUMBERROUND_TIP = R.addon("OrdaenSettings")["locales"].GLOBAL_NUMBERROUND_TIP
local __OrdaenSettings_locales_GLOBAL_NUMBERPRECISION = R.addon("OrdaenSettings")["locales"].GLOBAL_NUMBERPRECISION
local __OrdaenSettings_locales_GLOBAL_NUMBERPRECISION_TIP = R.addon("OrdaenSettings")["locales"].GLOBAL_NUMBERPRECISION_TIP
local __OrdaenSettings_locales_GLOBAL_NUMBERS = R.addon("OrdaenSettings")["locales"].GLOBAL_NUMBERS
local __OrdaenSettings_locales_GLOBAL_NUMBERS_TIP = R.addon("OrdaenSettings")["locales"].GLOBAL_NUMBERS_TIP
local __OrdaenSettings_locales_GLOBAL_SOUNDS = R.addon("OrdaenSettings")["locales"].GLOBAL_SOUNDS
local __OrdaenSettings_locales_GLOBAL_SOUNDS_TIP = R.addon("OrdaenSettings")["locales"].GLOBAL_SOUNDS_TIP
local __OrdaenSettings_locales_GLOBAL_CLOCK = R.addon("OrdaenSettings")["locales"].GLOBAL_CLOCK
local __OrdaenSettings_locales_GLOBAL_CLOCK_TIP = R.addon("OrdaenSettings")["locales"].GLOBAL_CLOCK_TIP
local __Ordaen_module_Component = R.addon("Ordaen")["module"].Component
local M = {}
R.addon("OrdaenSettings")["general"] = M
local DENSITIES, FORMATS, LARGE, CLOCKS, ScalePage, NumbersPage, BehaviourPage

local function __d1(self, parent)
	local __c2 = __OrdaenLibrary_slider_Slider.new(parent, __cell(__OrdaenSettings_locales_GLOBAL_SCALE), __lens(parent, self.globals.draft, "scale"), 0.7, 1.5, 0.05, "percent", __cell(__OrdaenSettings_locales_GLOBAL_SCALE_TIP), nil)
	__draw(parent, __c2, nil)
	local __c3 = __OrdaenLibrary_dropdown_Dropdown.new(parent, __cell(__OrdaenSettings_locales_GLOBAL_DENSITY), __lens(parent, self.globals.draft, "density"), DENSITIES, __cell(__OrdaenSettings_locales_GLOBAL_DENSITY_TIP), nil)
	__draw(parent, __c3, nil)
	local __c4 = __OrdaenLibrary_checkbox_Checkbox.new(parent, __cell(__OrdaenSettings_locales_GLOBAL_PIXEL), __lens(parent, self.globals.draft, "pixel"), __cell(__OrdaenSettings_locales_GLOBAL_PIXEL_TIP), nil)
	__draw(parent, __c4, nil)
end

local function __c5(self)
	return __getKey(self.globals.draft, "numberRound")
end

local function __d6(self, parent)
	local __c7 = __OrdaenLibrary_dropdown_Dropdown.new(parent, __cell(__OrdaenSettings_locales_GLOBAL_NUMBERFORMAT), __lens(parent, self.globals.draft, "numberFormat"), FORMATS, __cell(__OrdaenSettings_locales_GLOBAL_NUMBERFORMAT_TIP), nil)
	__draw(parent, __c7, nil)
	local __c8 = __OrdaenLibrary_checkbox_Checkbox.new(parent, __cell(__OrdaenSettings_locales_GLOBAL_NUMBERROUND), __lens(parent, self.globals.draft, "numberRound"), __cell(__OrdaenSettings_locales_GLOBAL_NUMBERROUND_TIP), nil)
	__draw(parent, __c8, nil)
	local __c9 = __OrdaenLibrary_slider_Slider.new(parent, __cell(__OrdaenSettings_locales_GLOBAL_NUMBERPRECISION), __lens(parent, self.globals.draft, "numberPrecision"), 0, 3, nil, nil, __cell(__OrdaenSettings_locales_GLOBAL_NUMBERPRECISION_TIP), self.rounded)
	__draw(parent, __c9, nil)
	local __c10 = __OrdaenLibrary_dropdown_Dropdown.new(parent, __cell(__OrdaenSettings_locales_GLOBAL_NUMBERS), __lens(parent, self.globals.draft, "numbers"), LARGE, __cell(__OrdaenSettings_locales_GLOBAL_NUMBERS_TIP), nil)
	__draw(parent, __c10, nil)
end

local function __d11(self, parent)
	local __c12 = __OrdaenLibrary_checkbox_Checkbox.new(parent, __cell(__OrdaenSettings_locales_GLOBAL_SOUNDS), __lens(parent, self.globals.draft, "sounds"), __cell(__OrdaenSettings_locales_GLOBAL_SOUNDS_TIP), nil)
	__draw(parent, __c12, nil)
	local __c13 = __OrdaenLibrary_dropdown_Dropdown.new(parent, __cell(__OrdaenSettings_locales_GLOBAL_CLOCK), __lens(parent, self.globals.draft, "clock"), CLOCKS, __cell(__OrdaenSettings_locales_GLOBAL_CLOCK_TIP), nil)
	__draw(parent, __c13, nil)
end

DENSITIES = { { value = "compact", label = __OrdaenSettings_locales_GLOBAL_DENSITY_COMPACT }, { value = "normal", label = __OrdaenSettings_locales_GLOBAL_DENSITY_NORMAL }, { value = "roomy", label = __OrdaenSettings_locales_GLOBAL_DENSITY_ROOMY } }
FORMATS = { { value = "space", label = __OrdaenSettings_locales_GLOBAL_NUMBERFORMAT_SPACE }, { value = "comma", label = __OrdaenSettings_locales_GLOBAL_NUMBERFORMAT_COMMA }, { value = "dot", label = __OrdaenSettings_locales_GLOBAL_NUMBERFORMAT_DOT } }
LARGE = { { value = "full", label = __OrdaenSettings_locales_GLOBAL_NUMBERS_FULL }, { value = "short", label = __OrdaenSettings_locales_GLOBAL_NUMBERS_SHORT } }
CLOCKS = { { value = "24", label = __OrdaenSettings_locales_GLOBAL_CLOCK_24 }, { value = "12", label = __OrdaenSettings_locales_GLOBAL_CLOCK_12 } }

ScalePage = __class({})

function ScalePage.new(__owner, globals)
	local self = setmetatable({}, ScalePage)
	R.adopt(__owner, self)
	self.globals = globals
	return self
end

function ScalePage:render()
	return __template(__d1, self)
end

NumbersPage = __class({})

function NumbersPage.new(__owner, globals)
	local self = setmetatable({}, NumbersPage)
	R.adopt(__owner, self)
	self.globals = globals
	self.rounded = __computed(self, __c5, self)
	return self
end

function NumbersPage:render()
	return __template(__d6, self)
end

BehaviourPage = __class({})

function BehaviourPage.new(__owner, globals)
	local self = setmetatable({}, BehaviourPage)
	R.adopt(__owner, self)
	self.globals = globals
	return self
end

function BehaviourPage:render()
	return __template(__d11, self)
end
__inherit(ScalePage, { __Ordaen_module_Component })
__inherit(NumbersPage, { __Ordaen_module_Component })
__inherit(BehaviourPage, { __Ordaen_module_Component })

M.DENSITIES = DENSITIES
M.FORMATS = FORMATS
M.LARGE = LARGE
M.CLOCKS = CLOCKS
M.ScalePage = ScalePage
M.NumbersPage = NumbersPage
M.BehaviourPage = BehaviourPage
