-- Made by lunatype from OrdaenTooltips/settings.luna: change the source, not this file.
local R = LunaType
local __getKey, __cell, __computed, __lens, __class, __inherit, __template, __draw = R.getKey, R.cell, R.computed, R.lens, R.class, R.inherit, R.template, R.draw
local __x = {
	OrdaenTooltips_locales_TOOLTIPS_ITEMSANCHORBAGS_CORNER = R.addon("OrdaenTooltips")["locales"].TOOLTIPS_ITEMSANCHORBAGS_CORNER,
	OrdaenTooltips_locales_TOOLTIPS_ITEMSANCHORBAGS_ANCHOR = R.addon("OrdaenTooltips")["locales"].TOOLTIPS_ITEMSANCHORBAGS_ANCHOR,
	OrdaenTooltips_locales_TOOLTIPS_ITEMSANCHORCHAR_CORNER = R.addon("OrdaenTooltips")["locales"].TOOLTIPS_ITEMSANCHORCHAR_CORNER,
	OrdaenTooltips_locales_TOOLTIPS_ITEMSANCHORCHAR_ANCHOR = R.addon("OrdaenTooltips")["locales"].TOOLTIPS_ITEMSANCHORCHAR_ANCHOR,
	OrdaenLibrary_checkbox_Checkbox = R.addon("OrdaenLibrary")["checkbox"].Checkbox,
	OrdaenTooltips_locales_TOOLTIPS_ANCHORTOBUTTONS = R.addon("OrdaenTooltips")["locales"].TOOLTIPS_ANCHORTOBUTTONS,
	OrdaenTooltips_locales_TOOLTIPS_ANCHORTOBUTTONS_TIP = R.addon("OrdaenTooltips")["locales"].TOOLTIPS_ANCHORTOBUTTONS_TIP,
	OrdaenLibrary_switch_Switch = R.addon("OrdaenLibrary")["switch"].Switch,
	OrdaenTooltips_locales_TOOLTIPS_ITEMSON = R.addon("OrdaenTooltips")["locales"].TOOLTIPS_ITEMSON,
	OrdaenTooltips_locales_TOOLTIPS_ITEMSON_TIP = R.addon("OrdaenTooltips")["locales"].TOOLTIPS_ITEMSON_TIP,
	OrdaenTooltips_locales_TOOLTIPS_LOCK = R.addon("OrdaenTooltips")["locales"].TOOLTIPS_LOCK,
	OrdaenTooltips_locales_TOOLTIPS_LOCK_TIP = R.addon("OrdaenTooltips")["locales"].TOOLTIPS_LOCK_TIP,
	OrdaenLibrary_dropdown_Dropdown = R.addon("OrdaenLibrary")["dropdown"].Dropdown,
	OrdaenTooltips_locales_TOOLTIPS_ITEMSANCHORBAGS = R.addon("OrdaenTooltips")["locales"].TOOLTIPS_ITEMSANCHORBAGS,
	OrdaenTooltips_locales_TOOLTIPS_ITEMSANCHORBAGS_TIP = R.addon("OrdaenTooltips")["locales"].TOOLTIPS_ITEMSANCHORBAGS_TIP,
	OrdaenTooltips_locales_TOOLTIPS_ITEMSANCHORCHAR = R.addon("OrdaenTooltips")["locales"].TOOLTIPS_ITEMSANCHORCHAR,
	OrdaenTooltips_locales_TOOLTIPS_ITEMSANCHORCHAR_TIP = R.addon("OrdaenTooltips")["locales"].TOOLTIPS_ITEMSANCHORCHAR_TIP,
	OrdaenLibrary_section_Section = R.addon("OrdaenLibrary")["section"].Section,
	OrdaenTooltips_locales_SECTION_MORE = R.addon("OrdaenTooltips")["locales"].SECTION_MORE,
	OrdaenTooltips_locales_TOOLTIPS_ITEMSILVL = R.addon("OrdaenTooltips")["locales"].TOOLTIPS_ITEMSILVL,
	OrdaenTooltips_locales_TOOLTIPS_ITEMSILVL_TIP = R.addon("OrdaenTooltips")["locales"].TOOLTIPS_ITEMSILVL_TIP,
	OrdaenTooltips_locales_TOOLTIPS_ITEMSID = R.addon("OrdaenTooltips")["locales"].TOOLTIPS_ITEMSID,
	OrdaenTooltips_locales_TOOLTIPS_ITEMSID_TIP = R.addon("OrdaenTooltips")["locales"].TOOLTIPS_ITEMSID_TIP,
	OrdaenTooltips_locales_TOOLTIPS_ITEMSCOUNT = R.addon("OrdaenTooltips")["locales"].TOOLTIPS_ITEMSCOUNT,
	OrdaenTooltips_locales_TOOLTIPS_ITEMSCOUNT_TIP = R.addon("OrdaenTooltips")["locales"].TOOLTIPS_ITEMSCOUNT_TIP,
	OrdaenTooltips_locales_TOOLTIPS_ITEMSSTACK = R.addon("OrdaenTooltips")["locales"].TOOLTIPS_ITEMSSTACK,
	OrdaenTooltips_locales_TOOLTIPS_ITEMSSTACK_TIP = R.addon("OrdaenTooltips")["locales"].TOOLTIPS_ITEMSSTACK_TIP,
	OrdaenTooltips_locales_TOOLTIPS_ITEMSCOOLDOWN = R.addon("OrdaenTooltips")["locales"].TOOLTIPS_ITEMSCOOLDOWN,
	OrdaenTooltips_locales_TOOLTIPS_ITEMSCOOLDOWN_TIP = R.addon("OrdaenTooltips")["locales"].TOOLTIPS_ITEMSCOOLDOWN_TIP,
	OrdaenTooltips_locales_TOOLTIPS_SPELLSON = R.addon("OrdaenTooltips")["locales"].TOOLTIPS_SPELLSON,
	OrdaenTooltips_locales_TOOLTIPS_SPELLSON_TIP = R.addon("OrdaenTooltips")["locales"].TOOLTIPS_SPELLSON_TIP,
	OrdaenTooltips_locales_TOOLTIPS_SPELLSID = R.addon("OrdaenTooltips")["locales"].TOOLTIPS_SPELLSID,
	OrdaenTooltips_locales_TOOLTIPS_SPELLSID_TIP = R.addon("OrdaenTooltips")["locales"].TOOLTIPS_SPELLSID_TIP,
	OrdaenTooltips_locales_TOOLTIPS_SPELLSNEXT = R.addon("OrdaenTooltips")["locales"].TOOLTIPS_SPELLSNEXT,
	OrdaenTooltips_locales_TOOLTIPS_SPELLSNEXT_TIP = R.addon("OrdaenTooltips")["locales"].TOOLTIPS_SPELLSNEXT_TIP,
	OrdaenTooltips_locales_TOOLTIPS_SPELLSCOOLDOWN = R.addon("OrdaenTooltips")["locales"].TOOLTIPS_SPELLSCOOLDOWN,
	OrdaenTooltips_locales_TOOLTIPS_SPELLSCOOLDOWN_TIP = R.addon("OrdaenTooltips")["locales"].TOOLTIPS_SPELLSCOOLDOWN_TIP,
	OrdaenTooltips_locales_TOOLTIPS_AURASON = R.addon("OrdaenTooltips")["locales"].TOOLTIPS_AURASON,
	OrdaenTooltips_locales_TOOLTIPS_AURASON_TIP = R.addon("OrdaenTooltips")["locales"].TOOLTIPS_AURASON_TIP,
	OrdaenTooltips_locales_TOOLTIPS_AURASID = R.addon("OrdaenTooltips")["locales"].TOOLTIPS_AURASID,
	OrdaenTooltips_locales_TOOLTIPS_AURASID_TIP = R.addon("OrdaenTooltips")["locales"].TOOLTIPS_AURASID_TIP,
	OrdaenTooltips_locales_TOOLTIPS_AURASCASTER = R.addon("OrdaenTooltips")["locales"].TOOLTIPS_AURASCASTER,
	OrdaenTooltips_locales_TOOLTIPS_AURASCASTER_TIP = R.addon("OrdaenTooltips")["locales"].TOOLTIPS_AURASCASTER_TIP,
	OrdaenTooltips_locales_TOOLTIPS_AURASTOTAL = R.addon("OrdaenTooltips")["locales"].TOOLTIPS_AURASTOTAL,
	OrdaenTooltips_locales_TOOLTIPS_AURASTOTAL_TIP = R.addon("OrdaenTooltips")["locales"].TOOLTIPS_AURASTOTAL_TIP,
	OrdaenTooltips_locales_TOOLTIPS_PLAYERSON = R.addon("OrdaenTooltips")["locales"].TOOLTIPS_PLAYERSON,
	OrdaenTooltips_locales_TOOLTIPS_PLAYERSON_TIP = R.addon("OrdaenTooltips")["locales"].TOOLTIPS_PLAYERSON_TIP,
	OrdaenTooltips_locales_TOOLTIPS_PLAYERSTARGET = R.addon("OrdaenTooltips")["locales"].TOOLTIPS_PLAYERSTARGET,
	OrdaenTooltips_locales_TOOLTIPS_PLAYERSTARGET_TIP = R.addon("OrdaenTooltips")["locales"].TOOLTIPS_PLAYERSTARGET_TIP,
	OrdaenTooltips_locales_TOOLTIPS_PLAYERSRELATION = R.addon("OrdaenTooltips")["locales"].TOOLTIPS_PLAYERSRELATION,
	OrdaenTooltips_locales_TOOLTIPS_PLAYERSRELATION_TIP = R.addon("OrdaenTooltips")["locales"].TOOLTIPS_PLAYERSRELATION_TIP,
	OrdaenTooltips_locales_TOOLTIPS_NPCSON = R.addon("OrdaenTooltips")["locales"].TOOLTIPS_NPCSON,
	OrdaenTooltips_locales_TOOLTIPS_NPCSON_TIP = R.addon("OrdaenTooltips")["locales"].TOOLTIPS_NPCSON_TIP,
	OrdaenTooltips_locales_TOOLTIPS_NPCSPARTY = R.addon("OrdaenTooltips")["locales"].TOOLTIPS_NPCSPARTY,
	OrdaenTooltips_locales_TOOLTIPS_NPCSPARTY_TIP = R.addon("OrdaenTooltips")["locales"].TOOLTIPS_NPCSPARTY_TIP,
	OrdaenTooltips_locales_TOOLTIPS_NPCSLOOT = R.addon("OrdaenTooltips")["locales"].TOOLTIPS_NPCSLOOT,
	OrdaenTooltips_locales_TOOLTIPS_NPCSLOOT_TIP = R.addon("OrdaenTooltips")["locales"].TOOLTIPS_NPCSLOOT_TIP,
	OrdaenTooltips_locales_TOOLTIPS_NPCSREP = R.addon("OrdaenTooltips")["locales"].TOOLTIPS_NPCSREP,
	OrdaenTooltips_locales_TOOLTIPS_NPCSREP_TIP = R.addon("OrdaenTooltips")["locales"].TOOLTIPS_NPCSREP_TIP,
	OrdaenTooltips_locales_TOOLTIPS_OBJECTSON = R.addon("OrdaenTooltips")["locales"].TOOLTIPS_OBJECTSON,
	OrdaenTooltips_locales_TOOLTIPS_OBJECTSON_TIP = R.addon("OrdaenTooltips")["locales"].TOOLTIPS_OBJECTSON_TIP,
	OrdaenTooltips_locales_TOOLTIPS_TEXTSON = R.addon("OrdaenTooltips")["locales"].TOOLTIPS_TEXTSON,
	OrdaenTooltips_locales_TOOLTIPS_TEXTSON_TIP = R.addon("OrdaenTooltips")["locales"].TOOLTIPS_TEXTSON_TIP,
	OrdaenTooltips_locales_TOOLTIPS_TEXTSEXTRA = R.addon("OrdaenTooltips")["locales"].TOOLTIPS_TEXTSEXTRA,
	OrdaenTooltips_locales_TOOLTIPS_TEXTSEXTRA_TIP = R.addon("OrdaenTooltips")["locales"].TOOLTIPS_TEXTSEXTRA_TIP,
	Ordaen_module_Component = R.addon("Ordaen")["module"].Component,
}
local M = {}
R.addon("OrdaenTooltips")["settings"] = M
local ITEMSANCHORBAGS, ITEMSANCHORCHAR, GeneralPage, ItemsPage, SpellsPage, AurasPage, PlayersPage, NpcsPage, ObjectsPage, TextsPage

local function __d1(self, parent)
	local __c2 = __x.OrdaenLibrary_checkbox_Checkbox.new(parent, __cell(__x.OrdaenTooltips_locales_TOOLTIPS_ANCHORTOBUTTONS), __lens(parent, self.settings.draft, "anchorToButtons"), __cell(__x.OrdaenTooltips_locales_TOOLTIPS_ANCHORTOBUTTONS_TIP), nil)
	__draw(parent, __c2, nil)
end

local function __c3(self)
	return not __getKey(self.settings.draft, "itemsOn")
end

local function __d10(self, parent)
	local __c11 = __x.OrdaenLibrary_checkbox_Checkbox.new(parent, __cell(__x.OrdaenTooltips_locales_TOOLTIPS_ITEMSILVL), __lens(parent, self.settings.draft, "itemsIlvl"), __cell(__x.OrdaenTooltips_locales_TOOLTIPS_ITEMSILVL_TIP), self.off)
	__draw(parent, __c11, nil)
	local __c12 = __x.OrdaenLibrary_checkbox_Checkbox.new(parent, __cell(__x.OrdaenTooltips_locales_TOOLTIPS_ITEMSID), __lens(parent, self.settings.draft, "itemsId"), __cell(__x.OrdaenTooltips_locales_TOOLTIPS_ITEMSID_TIP), self.off)
	__draw(parent, __c12, nil)
	local __c13 = __x.OrdaenLibrary_checkbox_Checkbox.new(parent, __cell(__x.OrdaenTooltips_locales_TOOLTIPS_ITEMSCOUNT), __lens(parent, self.settings.draft, "itemsCount"), __cell(__x.OrdaenTooltips_locales_TOOLTIPS_ITEMSCOUNT_TIP), self.off)
	__draw(parent, __c13, nil)
	local __c14 = __x.OrdaenLibrary_checkbox_Checkbox.new(parent, __cell(__x.OrdaenTooltips_locales_TOOLTIPS_ITEMSSTACK), __lens(parent, self.settings.draft, "itemsStack"), __cell(__x.OrdaenTooltips_locales_TOOLTIPS_ITEMSSTACK_TIP), self.off)
	__draw(parent, __c14, nil)
	local __c15 = __x.OrdaenLibrary_checkbox_Checkbox.new(parent, __cell(__x.OrdaenTooltips_locales_TOOLTIPS_ITEMSCOOLDOWN), __lens(parent, self.settings.draft, "itemsCooldown"), __cell(__x.OrdaenTooltips_locales_TOOLTIPS_ITEMSCOOLDOWN_TIP), self.off)
	__draw(parent, __c15, nil)
end

local function __d4(self, parent)
	local __c5 = __x.OrdaenLibrary_switch_Switch.new(parent, __cell(__x.OrdaenTooltips_locales_TOOLTIPS_ITEMSON), __lens(parent, self.settings.draft, "itemsOn"), __cell(__x.OrdaenTooltips_locales_TOOLTIPS_ITEMSON_TIP), nil)
	__draw(parent, __c5, nil)
	local __c6 = __x.OrdaenLibrary_checkbox_Checkbox.new(parent, __cell(__x.OrdaenTooltips_locales_TOOLTIPS_LOCK), __lens(parent, self.settings.draft, "itemsLock"), __cell(__x.OrdaenTooltips_locales_TOOLTIPS_LOCK_TIP), self.off)
	__draw(parent, __c6, nil)
	local __c7 = __x.OrdaenLibrary_dropdown_Dropdown.new(parent, __cell(__x.OrdaenTooltips_locales_TOOLTIPS_ITEMSANCHORBAGS), __lens(parent, self.settings.draft, "itemsAnchorBags"), ITEMSANCHORBAGS, __cell(__x.OrdaenTooltips_locales_TOOLTIPS_ITEMSANCHORBAGS_TIP), self.off)
	__draw(parent, __c7, nil)
	local __c8 = __x.OrdaenLibrary_dropdown_Dropdown.new(parent, __cell(__x.OrdaenTooltips_locales_TOOLTIPS_ITEMSANCHORCHAR), __lens(parent, self.settings.draft, "itemsAnchorChar"), ITEMSANCHORCHAR, __cell(__x.OrdaenTooltips_locales_TOOLTIPS_ITEMSANCHORCHAR_TIP), self.off)
	__draw(parent, __c8, nil)
	local __c9 = __x.OrdaenLibrary_section_Section.new(parent, __cell(__x.OrdaenTooltips_locales_SECTION_MORE))
	__draw(parent, __c9, { self = self, [""] = __d10 })
end

local function __c16(self)
	return not __getKey(self.settings.draft, "spellsOn")
end

local function __d21(self, parent)
	local __c22 = __x.OrdaenLibrary_checkbox_Checkbox.new(parent, __cell(__x.OrdaenTooltips_locales_TOOLTIPS_SPELLSID), __lens(parent, self.settings.draft, "spellsId"), __cell(__x.OrdaenTooltips_locales_TOOLTIPS_SPELLSID_TIP), self.off)
	__draw(parent, __c22, nil)
	local __c23 = __x.OrdaenLibrary_checkbox_Checkbox.new(parent, __cell(__x.OrdaenTooltips_locales_TOOLTIPS_SPELLSNEXT), __lens(parent, self.settings.draft, "spellsNext"), __cell(__x.OrdaenTooltips_locales_TOOLTIPS_SPELLSNEXT_TIP), self.off)
	__draw(parent, __c23, nil)
	local __c24 = __x.OrdaenLibrary_checkbox_Checkbox.new(parent, __cell(__x.OrdaenTooltips_locales_TOOLTIPS_SPELLSCOOLDOWN), __lens(parent, self.settings.draft, "spellsCooldown"), __cell(__x.OrdaenTooltips_locales_TOOLTIPS_SPELLSCOOLDOWN_TIP), self.off)
	__draw(parent, __c24, nil)
end

local function __d17(self, parent)
	local __c18 = __x.OrdaenLibrary_switch_Switch.new(parent, __cell(__x.OrdaenTooltips_locales_TOOLTIPS_SPELLSON), __lens(parent, self.settings.draft, "spellsOn"), __cell(__x.OrdaenTooltips_locales_TOOLTIPS_SPELLSON_TIP), nil)
	__draw(parent, __c18, nil)
	local __c19 = __x.OrdaenLibrary_checkbox_Checkbox.new(parent, __cell(__x.OrdaenTooltips_locales_TOOLTIPS_LOCK), __lens(parent, self.settings.draft, "spellsLock"), __cell(__x.OrdaenTooltips_locales_TOOLTIPS_LOCK_TIP), self.off)
	__draw(parent, __c19, nil)
	local __c20 = __x.OrdaenLibrary_section_Section.new(parent, __cell(__x.OrdaenTooltips_locales_SECTION_MORE))
	__draw(parent, __c20, { self = self, [""] = __d21 })
end

local function __c25(self)
	return not __getKey(self.settings.draft, "aurasOn")
end

local function __d30(self, parent)
	local __c31 = __x.OrdaenLibrary_checkbox_Checkbox.new(parent, __cell(__x.OrdaenTooltips_locales_TOOLTIPS_AURASID), __lens(parent, self.settings.draft, "aurasId"), __cell(__x.OrdaenTooltips_locales_TOOLTIPS_AURASID_TIP), self.off)
	__draw(parent, __c31, nil)
	local __c32 = __x.OrdaenLibrary_checkbox_Checkbox.new(parent, __cell(__x.OrdaenTooltips_locales_TOOLTIPS_AURASCASTER), __lens(parent, self.settings.draft, "aurasCaster"), __cell(__x.OrdaenTooltips_locales_TOOLTIPS_AURASCASTER_TIP), self.off)
	__draw(parent, __c32, nil)
	local __c33 = __x.OrdaenLibrary_checkbox_Checkbox.new(parent, __cell(__x.OrdaenTooltips_locales_TOOLTIPS_AURASTOTAL), __lens(parent, self.settings.draft, "aurasTotal"), __cell(__x.OrdaenTooltips_locales_TOOLTIPS_AURASTOTAL_TIP), self.off)
	__draw(parent, __c33, nil)
end

local function __d26(self, parent)
	local __c27 = __x.OrdaenLibrary_switch_Switch.new(parent, __cell(__x.OrdaenTooltips_locales_TOOLTIPS_AURASON), __lens(parent, self.settings.draft, "aurasOn"), __cell(__x.OrdaenTooltips_locales_TOOLTIPS_AURASON_TIP), nil)
	__draw(parent, __c27, nil)
	local __c28 = __x.OrdaenLibrary_checkbox_Checkbox.new(parent, __cell(__x.OrdaenTooltips_locales_TOOLTIPS_LOCK), __lens(parent, self.settings.draft, "aurasLock"), __cell(__x.OrdaenTooltips_locales_TOOLTIPS_LOCK_TIP), self.off)
	__draw(parent, __c28, nil)
	local __c29 = __x.OrdaenLibrary_section_Section.new(parent, __cell(__x.OrdaenTooltips_locales_SECTION_MORE))
	__draw(parent, __c29, { self = self, [""] = __d30 })
end

local function __c34(self)
	return not __getKey(self.settings.draft, "playersOn")
end

local function __d39(self, parent)
	local __c40 = __x.OrdaenLibrary_checkbox_Checkbox.new(parent, __cell(__x.OrdaenTooltips_locales_TOOLTIPS_PLAYERSTARGET), __lens(parent, self.settings.draft, "playersTarget"), __cell(__x.OrdaenTooltips_locales_TOOLTIPS_PLAYERSTARGET_TIP), self.off)
	__draw(parent, __c40, nil)
	local __c41 = __x.OrdaenLibrary_checkbox_Checkbox.new(parent, __cell(__x.OrdaenTooltips_locales_TOOLTIPS_PLAYERSRELATION), __lens(parent, self.settings.draft, "playersRelation"), __cell(__x.OrdaenTooltips_locales_TOOLTIPS_PLAYERSRELATION_TIP), self.off)
	__draw(parent, __c41, nil)
end

local function __d35(self, parent)
	local __c36 = __x.OrdaenLibrary_switch_Switch.new(parent, __cell(__x.OrdaenTooltips_locales_TOOLTIPS_PLAYERSON), __lens(parent, self.settings.draft, "playersOn"), __cell(__x.OrdaenTooltips_locales_TOOLTIPS_PLAYERSON_TIP), nil)
	__draw(parent, __c36, nil)
	local __c37 = __x.OrdaenLibrary_checkbox_Checkbox.new(parent, __cell(__x.OrdaenTooltips_locales_TOOLTIPS_LOCK), __lens(parent, self.settings.draft, "playersLock"), __cell(__x.OrdaenTooltips_locales_TOOLTIPS_LOCK_TIP), self.off)
	__draw(parent, __c37, nil)
	local __c38 = __x.OrdaenLibrary_section_Section.new(parent, __cell(__x.OrdaenTooltips_locales_SECTION_MORE))
	__draw(parent, __c38, { self = self, [""] = __d39 })
end

local function __c42(self)
	return not __getKey(self.settings.draft, "npcsOn")
end

local function __d47(self, parent)
	local __c48 = __x.OrdaenLibrary_checkbox_Checkbox.new(parent, __cell(__x.OrdaenTooltips_locales_TOOLTIPS_NPCSPARTY), __lens(parent, self.settings.draft, "npcsParty"), __cell(__x.OrdaenTooltips_locales_TOOLTIPS_NPCSPARTY_TIP), self.off)
	__draw(parent, __c48, nil)
	local __c49 = __x.OrdaenLibrary_checkbox_Checkbox.new(parent, __cell(__x.OrdaenTooltips_locales_TOOLTIPS_NPCSLOOT), __lens(parent, self.settings.draft, "npcsLoot"), __cell(__x.OrdaenTooltips_locales_TOOLTIPS_NPCSLOOT_TIP), self.off)
	__draw(parent, __c49, nil)
	local __c50 = __x.OrdaenLibrary_checkbox_Checkbox.new(parent, __cell(__x.OrdaenTooltips_locales_TOOLTIPS_NPCSREP), __lens(parent, self.settings.draft, "npcsRep"), __cell(__x.OrdaenTooltips_locales_TOOLTIPS_NPCSREP_TIP), self.off)
	__draw(parent, __c50, nil)
end

local function __d43(self, parent)
	local __c44 = __x.OrdaenLibrary_switch_Switch.new(parent, __cell(__x.OrdaenTooltips_locales_TOOLTIPS_NPCSON), __lens(parent, self.settings.draft, "npcsOn"), __cell(__x.OrdaenTooltips_locales_TOOLTIPS_NPCSON_TIP), nil)
	__draw(parent, __c44, nil)
	local __c45 = __x.OrdaenLibrary_checkbox_Checkbox.new(parent, __cell(__x.OrdaenTooltips_locales_TOOLTIPS_LOCK), __lens(parent, self.settings.draft, "npcsLock"), __cell(__x.OrdaenTooltips_locales_TOOLTIPS_LOCK_TIP), self.off)
	__draw(parent, __c45, nil)
	local __c46 = __x.OrdaenLibrary_section_Section.new(parent, __cell(__x.OrdaenTooltips_locales_SECTION_MORE))
	__draw(parent, __c46, { self = self, [""] = __d47 })
end

local function __c51(self)
	return not __getKey(self.settings.draft, "objectsOn")
end

local function __d52(self, parent)
	local __c53 = __x.OrdaenLibrary_switch_Switch.new(parent, __cell(__x.OrdaenTooltips_locales_TOOLTIPS_OBJECTSON), __lens(parent, self.settings.draft, "objectsOn"), __cell(__x.OrdaenTooltips_locales_TOOLTIPS_OBJECTSON_TIP), nil)
	__draw(parent, __c53, nil)
	local __c54 = __x.OrdaenLibrary_checkbox_Checkbox.new(parent, __cell(__x.OrdaenTooltips_locales_TOOLTIPS_LOCK), __lens(parent, self.settings.draft, "objectsLock"), __cell(__x.OrdaenTooltips_locales_TOOLTIPS_LOCK_TIP), self.off)
	__draw(parent, __c54, nil)
end

local function __c55(self)
	return not __getKey(self.settings.draft, "textsOn")
end

local function __d56(self, parent)
	local __c57 = __x.OrdaenLibrary_switch_Switch.new(parent, __cell(__x.OrdaenTooltips_locales_TOOLTIPS_TEXTSON), __lens(parent, self.settings.draft, "textsOn"), __cell(__x.OrdaenTooltips_locales_TOOLTIPS_TEXTSON_TIP), nil)
	__draw(parent, __c57, nil)
	local __c58 = __x.OrdaenLibrary_checkbox_Checkbox.new(parent, __cell(__x.OrdaenTooltips_locales_TOOLTIPS_TEXTSEXTRA), __lens(parent, self.settings.draft, "textsExtra"), __cell(__x.OrdaenTooltips_locales_TOOLTIPS_TEXTSEXTRA_TIP), self.off)
	__draw(parent, __c58, nil)
end

ITEMSANCHORBAGS = { { value = "corner", label = __x.OrdaenTooltips_locales_TOOLTIPS_ITEMSANCHORBAGS_CORNER }, { value = "anchor", label = __x.OrdaenTooltips_locales_TOOLTIPS_ITEMSANCHORBAGS_ANCHOR } }
ITEMSANCHORCHAR = { { value = "corner", label = __x.OrdaenTooltips_locales_TOOLTIPS_ITEMSANCHORCHAR_CORNER }, { value = "anchor", label = __x.OrdaenTooltips_locales_TOOLTIPS_ITEMSANCHORCHAR_ANCHOR } }

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

ItemsPage = __class({})

function ItemsPage.new(__owner, settings)
	local self = setmetatable({}, ItemsPage)
	R.adopt(__owner, self)
	self.settings = settings
	self.off = __computed(self, __c3, self)
	return self
end

function ItemsPage:render()
	return __template(__d4, self)
end

SpellsPage = __class({})

function SpellsPage.new(__owner, settings)
	local self = setmetatable({}, SpellsPage)
	R.adopt(__owner, self)
	self.settings = settings
	self.off = __computed(self, __c16, self)
	return self
end

function SpellsPage:render()
	return __template(__d17, self)
end

AurasPage = __class({})

function AurasPage.new(__owner, settings)
	local self = setmetatable({}, AurasPage)
	R.adopt(__owner, self)
	self.settings = settings
	self.off = __computed(self, __c25, self)
	return self
end

function AurasPage:render()
	return __template(__d26, self)
end

PlayersPage = __class({})

function PlayersPage.new(__owner, settings)
	local self = setmetatable({}, PlayersPage)
	R.adopt(__owner, self)
	self.settings = settings
	self.off = __computed(self, __c34, self)
	return self
end

function PlayersPage:render()
	return __template(__d35, self)
end

NpcsPage = __class({})

function NpcsPage.new(__owner, settings)
	local self = setmetatable({}, NpcsPage)
	R.adopt(__owner, self)
	self.settings = settings
	self.off = __computed(self, __c42, self)
	return self
end

function NpcsPage:render()
	return __template(__d43, self)
end

ObjectsPage = __class({})

function ObjectsPage.new(__owner, settings)
	local self = setmetatable({}, ObjectsPage)
	R.adopt(__owner, self)
	self.settings = settings
	self.off = __computed(self, __c51, self)
	return self
end

function ObjectsPage:render()
	return __template(__d52, self)
end

TextsPage = __class({})

function TextsPage.new(__owner, settings)
	local self = setmetatable({}, TextsPage)
	R.adopt(__owner, self)
	self.settings = settings
	self.off = __computed(self, __c55, self)
	return self
end

function TextsPage:render()
	return __template(__d56, self)
end
__inherit(GeneralPage, { __x.Ordaen_module_Component })
__inherit(ItemsPage, { __x.Ordaen_module_Component })
__inherit(SpellsPage, { __x.Ordaen_module_Component })
__inherit(AurasPage, { __x.Ordaen_module_Component })
__inherit(PlayersPage, { __x.Ordaen_module_Component })
__inherit(NpcsPage, { __x.Ordaen_module_Component })
__inherit(ObjectsPage, { __x.Ordaen_module_Component })
__inherit(TextsPage, { __x.Ordaen_module_Component })

M.ITEMSANCHORBAGS = ITEMSANCHORBAGS
M.ITEMSANCHORCHAR = ITEMSANCHORCHAR
M.GeneralPage = GeneralPage
M.ItemsPage = ItemsPage
M.SpellsPage = SpellsPage
M.AurasPage = AurasPage
M.PlayersPage = PlayersPage
M.NpcsPage = NpcsPage
M.ObjectsPage = ObjectsPage
M.TextsPage = TextsPage
