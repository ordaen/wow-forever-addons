-- Made by lunatype from Showcase/index.luna: change the source, not this file.
local R = LunaType
local __get, __getKey, __set, __cell, __computed, __lens, __listen, __class, __inherit, __el, __attr, __bind, __on, __template, __draw, __when = R.get, R.getKey, R.set, R.cell, R.computed, R.lens, R.listen, R.class, R.inherit, R.el, R.attr, R.bind, R.on, R.template, R.draw, R.when
local __OrdaenLibrary_tabs_Tabs = R.addon("OrdaenLibrary")["tabs"].Tabs
local __OrdaenLibrary_settingsTab_SettingsTab = R.addon("OrdaenLibrary")["settingsTab"].SettingsTab
local __OrdaenLibrary_section_Section = R.addon("OrdaenLibrary")["section"].Section
local __OrdaenLibrary_checkbox_Checkbox = R.addon("OrdaenLibrary")["checkbox"].Checkbox
local __OrdaenLibrary_slider_Slider = R.addon("OrdaenLibrary")["slider"].Slider
local __OrdaenLibrary_switch_Switch = R.addon("OrdaenLibrary")["switch"].Switch
local __OrdaenLibrary_dropdown_Dropdown = R.addon("OrdaenLibrary")["dropdown"].Dropdown
local __OrdaenLibrary_input_Input = R.addon("OrdaenLibrary")["input"].Input
local __OrdaenLibrary_switch_Toggle = R.addon("OrdaenLibrary")["switch"].Toggle
local __OrdaenLibrary_pushButton_PushButton = R.addon("OrdaenLibrary")["pushButton"].PushButton
local __OrdaenLibrary_dialog_Dialog = R.addon("OrdaenLibrary")["dialog"].Dialog
local __OrdaenLibrary_tip_Tip = R.addon("OrdaenLibrary")["tip"].Tip
local __Ordaen_module_Module = R.addon("Ordaen")["module"].Module
local __Showcase_windowed_Windowed = R.addon("Showcase")["windowed"].Windowed
local __Showcase_tinted_Tinted = R.addon("Showcase")["tinted"].Tinted
local __Showcase_arranged_Arranged = R.addon("Showcase")["arranged"].Arranged
local M = {}
R.addon("Showcase")["index"] = M
local TABS, HIDES, Showcase

local function __c1(self)
	return __get(self.tab) == 1
end

local function __c2(self)
	return __get(self.tab) == 2
end

local function __c3(self)
	return self:describe()
end

local function __b15(self)
	return not __getKey(self.choices, "showZone")
end

local function __d11(self, parent)
	local __c12 = __OrdaenLibrary_checkbox_Checkbox.new(parent, __cell("Show the zone"), __lens(parent, self.choices, "showZone"), nil, nil)
	__draw(parent, __c12, nil)
	local __c13 = __OrdaenLibrary_slider_Slider.new(parent, __cell("Size"), __lens(parent, self.choices, "scale"), 0.8, 1.6, 0.05, "percent", nil, nil)
	__draw(parent, __c13, nil)
	local __c14 = __OrdaenLibrary_slider_Slider.new(parent, __cell("Columns"), __lens(parent, self.choices, "columns"), 2, 12, nil, nil, nil, __computed(parent, __b15, self))
	__draw(parent, __c14, nil)
end

local function __d9(self, parent)
	local __c10 = __OrdaenLibrary_section_Section.new(parent, __cell("Map"))
	__draw(parent, __c10, { self = self, [""] = __d11 })
end

local function __b22(self)
	return not __getKey(self.choices, "drawer")
end

local function __b24(self)
	return not __getKey(self.choices, "drawer")
end

local function __b26(self)
	return __getKey(self.choices, "name")
end

local function __d19(self, parent)
	local __c20 = __OrdaenLibrary_switch_Switch.new(parent, __cell("Button drawer"), __lens(parent, self.choices, "drawer"), __cell("Other addons' buttons in one place."), nil)
	__draw(parent, __c20, nil)
	local __c21 = __OrdaenLibrary_dropdown_Dropdown.new(parent, __cell("Hide the map"), __lens(parent, self.choices, "hide"), HIDES, nil, __computed(parent, __b22, self))
	__draw(parent, __c21, nil)
	local __c23 = __OrdaenLibrary_input_Input.new(parent, __cell("Its name"), __lens(parent, self.choices, "name"), 12, __cell("Shown over the drawer."), __computed(parent, __b24, self))
	__draw(parent, __c23, nil)
	local __e25 = __el(parent, "text")
	__bind(__e25, "value", __b26, self)
	local __c27 = __OrdaenLibrary_switch_Toggle.new(parent, __lens(parent, self.choices, "drawer"), nil)
	__draw(parent, __c27, nil)
end

local function __d17(self, parent)
	local __c18 = __OrdaenLibrary_section_Section.new(parent, __cell("Drawer"))
	__draw(parent, __c18, { self = self, [""] = __d19 })
end

local function __b29(self)
	return __get(self.summary)
end

local function __b32(self)
	return __get(self.saved) == 0
end

local function __b34(self)
	return __get(self.asking)
end

local function __d37(self, parent)
	local __e38 = __el(parent, "text")
	__attr(__e38, "value", "Forget what was saved?")
end

local function __d39(self, parent)
	local __c40 = __OrdaenLibrary_pushButton_PushButton.new(parent, __cell("Forget"), __cell(100), __cell(true), nil)
	__listen(__c40.click, self, self.onDiscard)
	__draw(parent, __c40, nil)
	local __c41 = __OrdaenLibrary_pushButton_PushButton.new(parent, __cell("Keep"), __cell(100), nil, nil)
	__listen(__c41.click, self, self.onKeep)
	__draw(parent, __c41, nil)
end

local function __d35(self, parent)
	local __c36 = __OrdaenLibrary_dialog_Dialog.new(parent, __cell(360), __cell("Reset"))
	__draw(parent, __c36, { self = self, [""] = __d37, ["buttons"] = __d39 })
end

local __w33 = { __b34, __d35 }

local function __b43(self)
	return __get(self.hint)
end

local function __d44(self, parent)
	local __c45 = __OrdaenLibrary_tip_Tip.new(parent, __cell("Showcase"), self.summary, __cell(0), __cell(0))
	__draw(parent, __c45, nil)
end

local __w42 = { __b43, __d44 }

local function __d5(self, parent)
	local __e6 = __el(parent, "box")
	__attr(__e6, "columns", 1)
	__attr(__e6, "gap", 8)
	__on(__e6, "enter", self, self.onEnter)
	__on(__e6, "leave", self, self.onLeave)
	local __c7 = __OrdaenLibrary_tabs_Tabs.new(__e6, __cell(TABS), self.tab)
	__draw(__e6, __c7, nil)
	local __c8 = __OrdaenLibrary_settingsTab_SettingsTab.new(__e6, "Map", self.onMap)
	__draw(__e6, __c8, { self = self, [""] = __d9 })
	local __c16 = __OrdaenLibrary_settingsTab_SettingsTab.new(__e6, "Drawer", self.onDrawer)
	__draw(__e6, __c16, { self = self, [""] = __d17 })
	local __e28 = __el(__e6, "text")
	__bind(__e28, "value", __b29, self)
	local __c30 = __OrdaenLibrary_pushButton_PushButton.new(__e6, __cell("Save"), __cell(120), nil, nil)
	__listen(__c30.click, self, self.onSave)
	__draw(__e6, __c30, nil)
	local __c31 = __OrdaenLibrary_pushButton_PushButton.new(__e6, __cell("Reset"), __cell(120), __cell(true), __computed(__e6, __b32, self))
	__listen(__c31.click, self, self.onReset)
	__draw(__e6, __c31, nil)
	__when(__e6, __w33, self)
	__when(__e6, __w42, self)
end

TABS = { "Map", "Drawer" }
HIDES = { { value = "never", label = "Never" }, { value = "combat", label = "In combat" }, { value = "transport", label = "On a mount", soon = true } }

Showcase = __class({})

function Showcase.new(__owner)
	local self = setmetatable({ title = "Showcase" }, Showcase)
	R.adopt(__owner, self)
	self.pages = {}
	self.choices = __cell({ showZone = true, scale = 1, columns = 4, drawer = false, hide = "never", name = "" })
	self.saved = __cell(0)
	self.hint = __cell(false)
	self.tab = __cell(1)
	self.onMap = __computed(self, __c1, self)
	self.onDrawer = __computed(self, __c2, self)
	self.summary = __computed(self, __c3, self)
	self.asking = __cell(false)
	return self
end

function Showcase:describe()
	local __t4
	if __getKey(self.choices, "showZone") then
		__t4 = "zone shown"
	else
		__t4 = "zone hidden"
	end
	return __t4
end

function Showcase:onSave()
	__set(self.saved, __get(self.saved) + 1)
end

function Showcase:onReset()
	__set(self.asking, true)
end

function Showcase:onKeep()
	__set(self.asking, false)
end

function Showcase:onDiscard()
	__set(self.saved, 0)
	__set(self.asking, false)
end

function Showcase:onEnter()
	__set(self.hint, true)
end

function Showcase:onLeave()
	__set(self.hint, false)
end

function Showcase:render()
	return __template(__d5, self)
end
__inherit(Showcase, { __Ordaen_module_Module })

M.TABS = TABS
M.HIDES = HIDES
M.Showcase = Showcase
M.Windowed = __Showcase_windowed_Windowed
M.Tinted = __Showcase_tinted_Tinted
M.Arranged = __Showcase_arranged_Arranged
