-- Made by lunatype from OrdaenSettings/main.luna: change the source, not this file.
local R = LunaType
local __get, __getKey, __len, __set, __cell, __computed, __listen, __class, __inherit, __el, __attr, __bind, __template, __placed, __draw, __when, __each = R.get, R.getKey, R.len, R.set, R.cell, R.computed, R.listen, R.class, R.inherit, R.el, R.attr, R.bind, R.template, R.placed, R.draw, R.when, R.each
local __insert = table.insert
local __OrdaenSettings_locales_GLOBAL_TAB_SCALE = R.addon("OrdaenSettings")["locales"].GLOBAL_TAB_SCALE
local __OrdaenSettings_general_ScalePage = R.addon("OrdaenSettings")["general"].ScalePage
local __Ordaen_core = R.addon("Ordaen")["core"]
local __OrdaenSettings_locales_GLOBAL_TAB_NUMBERS = R.addon("OrdaenSettings")["locales"].GLOBAL_TAB_NUMBERS
local __OrdaenSettings_general_NumbersPage = R.addon("OrdaenSettings")["general"].NumbersPage
local __OrdaenSettings_locales_GLOBAL_TAB_BEHAVIOR = R.addon("OrdaenSettings")["locales"].GLOBAL_TAB_BEHAVIOR
local __OrdaenSettings_general_BehaviourPage = R.addon("OrdaenSettings")["general"].BehaviourPage
local __string_upper = R.string.upper
local __OrdaenSettings_locales_LIST_MODULES = R.addon("OrdaenSettings")["locales"].LIST_MODULES
local __Ordaen_drafts = R.addon("Ordaen")["drafts"]
local __OrdaenLibrary_window_Window = R.addon("OrdaenLibrary")["window"].Window
local __OrdaenLibrary_listTab_ListTab = R.addon("OrdaenLibrary")["listTab"].ListTab
local __OrdaenSettings_locales_LIST_GLOBAL = R.addon("OrdaenSettings")["locales"].LIST_GLOBAL
local __OrdaenSettings_locales_LIST_THEMES = R.addon("OrdaenSettings")["locales"].LIST_THEMES
local __OrdaenSettings_moduleRow_ModuleRow = R.addon("OrdaenSettings")["moduleRow"].ModuleRow
local __OrdaenSettings_locales_MODULE_OFF = R.addon("OrdaenSettings")["locales"].MODULE_OFF
local __OrdaenLibrary_tabs_Tabs = R.addon("OrdaenLibrary")["tabs"].Tabs
local __OrdaenLibrary_pushButton_PushButton = R.addon("OrdaenLibrary")["pushButton"].PushButton
local __OrdaenSettings_locales_PLACING = R.addon("OrdaenSettings")["locales"].PLACING
local __OrdaenSettings_locales_OPENS_PAGE = R.addon("OrdaenSettings")["locales"].OPENS_PAGE
local __OrdaenSettings_locales_ROLLBACK = R.addon("OrdaenSettings")["locales"].ROLLBACK
local __OrdaenSettings_locales_SAVE = R.addon("OrdaenSettings")["locales"].SAVE
local __OrdaenLibrary_dialog_Dialog = R.addon("OrdaenLibrary")["dialog"].Dialog
local __OrdaenSettings_locales_UNSAVED_TITLE = R.addon("OrdaenSettings")["locales"].UNSAVED_TITLE
local __OrdaenSettings_locales_UNSAVED_ASK = R.addon("OrdaenSettings")["locales"].UNSAVED_ASK
local __OrdaenSettings_locales_CANCEL = R.addon("OrdaenSettings")["locales"].CANCEL
local __OrdaenSettings_locales_DONT_SAVE = R.addon("OrdaenSettings")["locales"].DONT_SAVE
local __Ordaen_module_Module = R.addon("Ordaen")["module"].Module
local M = {}
R.addon("OrdaenSettings")["main"] = M
local WIDTH, HEIGHT, MIN_WIDTH, MIN_HEIGHT, GENERAL, THEMES, CONFIRM_WIDTH, DIM, INK, PAGE_BACK, FILL, BODY, HEADING, FOOT_HEIGHT, ROWS_PAD, ROWS_BOTTOM, FOOT, SAVE_ROW, Settings

local __f = {}

function __f.d1(self, parent)
	local __c2 = __OrdaenSettings_general_ScalePage.new(parent, __Ordaen_core.globals)
	__draw(parent, __c2, nil)
end

function __f.d3(self, parent)
	local __c4 = __OrdaenSettings_general_NumbersPage.new(parent, __Ordaen_core.globals)
	__draw(parent, __c4, nil)
end

function __f.d5(self, parent)
	local __c6 = __OrdaenSettings_general_BehaviourPage.new(parent, __Ordaen_core.globals)
	__draw(parent, __c6, nil)
end

function __f.d7(self, parent)
end

function __f.c8(self)
	return __string_upper(__OrdaenSettings_locales_LIST_MODULES)
end

function __f.c9(self)
	return __get(self.page) == ""
end

function __f.c10(self)
	return __get(self.page) == "themes"
end

function __f.c11(self)
	return self:entryOf()
end

function __f.c12(self)
	return self:offNow()
end

function __f.c13(self)
	return self:pagesOf()
end

function __f.c14(self)
	return self:namesOf()
end

function __f.c15(self)
	return __len(self.names) > 1
end

function __f.c16(self)
	return self:contentOf()
end

function __f.c17(self)
	return __get(__Ordaen_drafts.unsaved) == 0
end

function __f.b24(self)
	return __get(self.open)
end

function __f.b34(self)
	return __get(self.heading)
end

function __f.b35(self)
	return __getKey(__Ordaen_core.theme, "font").numbers
end

function __f.b37(self)
	return __get(__Ordaen_core.modules)
end

function __f.d38(self, parent, entry)
	local __c39 = __OrdaenSettings_moduleRow_ModuleRow.new(parent, __get(entry), self.page)
	__listen(__c39.pick, self, self.onPick)
	__draw(parent, __c39, nil)
end

function __f.b43(self)
	return __get(self.onThemes)
end

function __f.d44(self, parent)
	local __e45 = __el(parent, "text")
	__attr(__e45, "value", __OrdaenSettings_locales_LIST_THEMES)
	__attr(__e45, "textColor", DIM)
	__attr(__e45, "textSize", 12.5)
end

function __f.b46(self)
	return __get(self.isOff)
end

function __f.d47(self, parent)
	local __e48 = __el(parent, "text")
	__attr(__e48, "value", __OrdaenSettings_locales_MODULE_OFF)
	__attr(__e48, "textColor", DIM)
	__attr(__e48, "textSize", 12.5)
end

function __f.b51(self)
	return __get(self.hasTabs)
end

function __f.d52(self, parent)
	local __c53 = __OrdaenLibrary_tabs_Tabs.new(parent, self.names, self.tab)
	__draw(parent, __c53, nil)
end

__f.w50 = { __f.b51, __f.d52 }

function __f.b55(self)
	return __get(self.content)
end

function __f.d49(self, parent)
	__when(parent, __f.w50, self)
	local __e54 = __el(parent, "box")
	__attr(__e54, "columns", 1)
	__attr(__e54, "gap", 11.666666666666668)
	__placed(__e54, __f.b55, self)
end

__f.w42 = { __f.b43, __f.d44, __f.b46, __f.d47, false, __f.d49 }

function __f.b60(self)
	return __get(self.onGeneral)
end

function __f.d61(self, parent)
	local __e62 = __el(parent, "text")
	__attr(__e62, "value", __OrdaenSettings_locales_OPENS_PAGE)
	__attr(__e62, "textColor", DIM)
	__attr(__e62, "textSize", 10.833333333333334)
end

__f.w59 = { __f.b60, __f.d61 }

function __f.b65(self)
	return __get(__Ordaen_drafts.rollbackable)
end

function __f.d66(self, parent)
	local __c67 = __OrdaenLibrary_pushButton_PushButton.new(parent, __cell(__OrdaenSettings_locales_ROLLBACK), __cell(108.33333333333334), nil, nil)
	__listen(__c67.click, self, self.rollback)
	__draw(parent, __c67, nil)
end

__f.w64 = { __f.b65, __f.d66 }

function __f.d27(self, parent)
	local __e28 = __el(parent, "box")
	__attr(__e28, "columns", BODY)
	__attr(__e28, "rows", FILL)
	local __e29 = __el(__e28, "box")
	__attr(__e29, "columns", 1)
	local __c30 = __OrdaenLibrary_listTab_ListTab.new(__e29, __cell(__OrdaenSettings_locales_LIST_GLOBAL), self.onGeneral, __cell(__Ordaen_core.icon), nil)
	__listen(__c30.pick, self, self.pickGeneral)
	__draw(__e29, __c30, nil)
	local __c31 = __OrdaenLibrary_listTab_ListTab.new(__e29, __cell(__OrdaenSettings_locales_LIST_THEMES), self.onThemes, __cell(__Ordaen_core.icon), nil)
	__listen(__c31.pick, self, self.pickThemes)
	__draw(__e29, __c31, nil)
	local __e32 = __el(__e29, "box")
	__attr(__e32, "padding", HEADING)
	local __e33 = __el(__e32, "text")
	__bind(__e33, "value", __f.b34, self)
	__attr(__e33, "textColor", DIM)
	__attr(__e33, "textSize", 10)
	__bind(__e33, "textFamily", __f.b35, self)
	local __e36 = __el(__e29, "box")
	__attr(__e36, "columns", 1)
	__each(__e36, __f.b37, nil, __f.d38, 1, 0, true, self)
	local __e40 = __el(__e28, "box")
	__attr(__e40, "background", PAGE_BACK)
	local __e41 = __el(__e40, "box")
	__attr(__e41, "position", "absolute")
	__attr(__e41, "left", 0)
	__attr(__e41, "right", 0)
	__attr(__e41, "top", 0)
	__attr(__e41, "bottom", 48.333333333333336)
	__attr(__e41, "padding", ROWS_PAD)
	__attr(__e41, "columns", 1)
	__attr(__e41, "gap", 11.666666666666668)
	__attr(__e41, "overflow", "scroll")
	__when(__e41, __f.w42, self)
	local __e56 = __el(__e40, "box")
	__attr(__e56, "position", "absolute")
	__attr(__e56, "left", 15)
	__attr(__e56, "right", 15)
	__attr(__e56, "bottom", 15)
	__attr(__e56, "height", 28.333333333333336)
	__attr(__e56, "columns", FOOT)
	__attr(__e56, "yAlign", "center")
	__attr(__e56, "gap", 10)
	local __c57 = __OrdaenLibrary_pushButton_PushButton.new(__e56, __cell(__OrdaenSettings_locales_PLACING), __cell(166.66666666666669), nil, nil)
	__listen(__c57.click, self, self.placingMode)
	__draw(__e56, __c57, nil)
	local __e58 = __el(__e56, "box")
	__when(__e58, __f.w59, self)
	local __e63 = __el(__e56, "box")
	__attr(__e63, "columns", SAVE_ROW)
	__attr(__e63, "gap", 6.666666666666667)
	__when(__e63, __f.w64, self)
	local __c68 = __OrdaenLibrary_pushButton_PushButton.new(__e63, __cell(__OrdaenSettings_locales_SAVE), __cell(116.66666666666667), nil, self.unchanged)
	__listen(__c68.click, self, self.save)
	__draw(__e63, __c68, nil)
end

function __f.d25(self, parent)
	local __c26 = __OrdaenLibrary_window_Window.new(parent, self.titles, self.titleTab, self.placing, 750, 400, nil, nil)
	__listen(__c26.close, self, self.onClose)
	__draw(parent, __c26, { self = self, [""] = __f.d27 })
end

__f.w23 = { __f.b24, __f.d25 }

function __f.b70(self)
	return __get(self.closing)
end

function __f.d73(self, parent)
	local __e74 = __el(parent, "text")
	__attr(__e74, "value", __OrdaenSettings_locales_UNSAVED_ASK)
	__attr(__e74, "textColor", INK)
	__attr(__e74, "textSize", 12.5)
end

function __f.d75(self, parent)
	local __c76 = __OrdaenLibrary_pushButton_PushButton.new(parent, __cell(__OrdaenSettings_locales_CANCEL), __cell(100), nil, nil)
	__listen(__c76.click, self, self.stay)
	__draw(parent, __c76, nil)
	local __c77 = __OrdaenLibrary_pushButton_PushButton.new(parent, __cell(__OrdaenSettings_locales_DONT_SAVE), __cell(125), nil, nil)
	__listen(__c77.click, self, self.closeDiscarding)
	__draw(parent, __c77, nil)
	local __c78 = __OrdaenLibrary_pushButton_PushButton.new(parent, __cell(__OrdaenSettings_locales_SAVE), __cell(116.66666666666667), nil, nil)
	__listen(__c78.click, self, self.closeSaving)
	__draw(parent, __c78, nil)
end

function __f.d71(self, parent)
	local __c72 = __OrdaenLibrary_dialog_Dialog.new(parent, __cell(403.33333333333337), __cell(__OrdaenSettings_locales_UNSAVED_TITLE))
	__draw(parent, __c72, { self = self, [""] = __f.d73, ["buttons"] = __f.d75 })
end

__f.w69 = { __f.b70, __f.d71 }

function __f.d22(self, parent)
	__when(parent, __f.w23, self)
	__when(parent, __f.w69, self)
end

WIDTH = 966.6666666666667
HEIGHT = 583.3333333333334
MIN_WIDTH = 750
MIN_HEIGHT = 400
GENERAL = ""
THEMES = "themes"
CONFIRM_WIDTH = 403.33333333333337
DIM = { r = 0.639, g = 0.592, b = 0.498, a = 1 }
INK = { r = 0.910, g = 0.863, b = 0.769, a = 1 }
PAGE_BACK = { r = 0, g = 0, b = 0, a = 0.251 }
FILL = { { fr = 1 } }
BODY = { "auto", { fr = 1 } }
HEADING = { top = 8.333333333333334, right = 13.333333333333334, bottom = 3.3333333333333335, left = 13.333333333333334 }
FOOT_HEIGHT = 28.333333333333336
ROWS_PAD = { top = 11.666666666666668, right = 15, left = 15 }
ROWS_BOTTOM = 48.333333333333336
FOOT = { "auto", { fr = 1 }, "auto" }
SAVE_ROW = { "auto", "auto" }

Settings = __class({})

function Settings.new(__owner)
	local self = setmetatable({ title = "Ordaen Settings" }, Settings)
	R.adopt(__owner, self)
	self.pages = { { title = __OrdaenSettings_locales_GLOBAL_TAB_SCALE, content = __template(__f.d1, self) }, { title = __OrdaenSettings_locales_GLOBAL_TAB_NUMBERS, content = __template(__f.d3, self) }, { title = __OrdaenSettings_locales_GLOBAL_TAB_BEHAVIOR, content = __template(__f.d5, self) } }
	self.open = __cell(false)
	self.page = __cell("")
	self.tab = __cell(1)
	self.closing = __cell(false)
	self.placing = __cell({ x = 0, y = 0, width = 966.6666666666667, height = 583.3333333333334 })
	self.titles = __cell({ { title = __Ordaen_core.title } })
	self.titleTab = __cell(1)
	self.nothing = __template(__f.d7, self)
	self.heading = __computed(self, __f.c8, self)
	self.onGeneral = __computed(self, __f.c9, self)
	self.onThemes = __computed(self, __f.c10, self)
	self.entry = __computed(self, __f.c11, self)
	self.isOff = __computed(self, __f.c12, self)
	self.shown = __computed(self, __f.c13, self)
	self.names = __computed(self, __f.c14, self)
	self.hasTabs = __computed(self, __f.c15, self)
	self.content = __computed(self, __f.c16, self)
	self.unchanged = __computed(self, __f.c17, self)
	__listen(__Ordaen_core.settingsAsked, self, self.asked)
	return self
end

function Settings:entryOf()
	local __l19 = __get(__Ordaen_core.modules)
	for __i18 = 1, #__l19 do
		local entry = __l19[__i18]
		if entry.folder == __get(self.page) then
			return entry
		end
	end
	return nil
end

function Settings:offNow()
	local entry = __get(self.entry)
	if entry == nil then
		return false
	end
	return not __get(entry.on)
end

function Settings:pagesOf()
	local entry = __get(self.entry)
	if entry == nil then
		return self.pages
	end
	return __get(entry.pages)
end

function Settings:namesOf()
	local list = {}
	local __l21 = __get(self.shown)
	for __i20 = 1, #__l21 do
		local page = __l21[__i20]
		__insert(list, page.title)
	end
	return list
end

function Settings:contentOf()
	local page = __getKey(self.shown, __get(self.tab))
	if page == nil then
		return self.nothing
	end
	return page.content
end

function Settings:asked(page)
	self:toggle(page or "")
end

function Settings:toggle(page)
	if __get(self.open) and __get(self.page) == page then
		self:onClose()
		return
	end
	self:show(page)
	__set(self.open, true)
end

function Settings:show(page)
	if __get(self.page) ~= page then
		__set(self.page, page)
		__set(self.tab, 1)
	end
end

function Settings:pickGeneral()
	self:show("")
end

function Settings:pickThemes()
	self:show("themes")
end

function Settings:onPick(folder)
	self:show(folder)
end

function Settings:onClose()
	if __get(__Ordaen_drafts.unsaved) > 0 then
		__set(self.closing, true)
		return
	end
	__set(self.open, false)
end

function Settings:save()
	__Ordaen_drafts.saveAll()
end

function Settings:rollback()
	__Ordaen_drafts.rollbackAll()
end

function Settings:placingMode()
	__Ordaen_core.togglePlacing()
end

function Settings:stay()
	__set(self.closing, false)
end

function Settings:closeSaving()
	__Ordaen_drafts.saveAll()
	__set(self.closing, false)
	__set(self.open, false)
end

function Settings:closeDiscarding()
	__Ordaen_drafts.discardAll()
	__set(self.closing, false)
	__set(self.open, false)
end

function Settings:render()
	return __template(__f.d22, self)
end
__inherit(Settings, { __Ordaen_module_Module })

M.WIDTH = WIDTH
M.HEIGHT = HEIGHT
M.MIN_WIDTH = MIN_WIDTH
M.MIN_HEIGHT = MIN_HEIGHT
M.GENERAL = GENERAL
M.THEMES = THEMES
M.CONFIRM_WIDTH = CONFIRM_WIDTH
M.DIM = DIM
M.INK = INK
M.PAGE_BACK = PAGE_BACK
M.FILL = FILL
M.BODY = BODY
M.HEADING = HEADING
M.FOOT_HEIGHT = FOOT_HEIGHT
M.ROWS_PAD = ROWS_PAD
M.ROWS_BOTTOM = ROWS_BOTTOM
M.FOOT = FOOT
M.SAVE_ROW = SAVE_ROW
M.Settings = Settings
