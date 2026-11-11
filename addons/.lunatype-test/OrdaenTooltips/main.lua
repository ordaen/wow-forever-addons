-- Made by lunatype from OrdaenTooltips/main.luna: change the source, not this file.
local R = LunaType
local __get, __getKey, __peek, __set, __cell, __computed, __watch, __listen, __class, __inherit, __template, __draw = R.get, R.getKey, R.peek, R.set, R.cell, R.computed, R.watch, R.listen, R.class, R.inherit, R.template, R.draw
local __insert = table.insert
local __Ordaen_settings_Settings = R.addon("Ordaen")["settings"].Settings
local __OrdaenTooltips_locales_TAB_GENERAL = R.addon("OrdaenTooltips")["locales"].TAB_GENERAL
local __OrdaenTooltips_settings_GeneralPage = R.addon("OrdaenTooltips")["settings"].GeneralPage
local __OrdaenTooltips_locales_TAB_ITEMS = R.addon("OrdaenTooltips")["locales"].TAB_ITEMS
local __OrdaenTooltips_settings_ItemsPage = R.addon("OrdaenTooltips")["settings"].ItemsPage
local __OrdaenTooltips_locales_TAB_SPELLS = R.addon("OrdaenTooltips")["locales"].TAB_SPELLS
local __OrdaenTooltips_settings_SpellsPage = R.addon("OrdaenTooltips")["settings"].SpellsPage
local __OrdaenTooltips_locales_TAB_AURAS = R.addon("OrdaenTooltips")["locales"].TAB_AURAS
local __OrdaenTooltips_settings_AurasPage = R.addon("OrdaenTooltips")["settings"].AurasPage
local __OrdaenTooltips_locales_TAB_PLAYERS = R.addon("OrdaenTooltips")["locales"].TAB_PLAYERS
local __OrdaenTooltips_settings_PlayersPage = R.addon("OrdaenTooltips")["settings"].PlayersPage
local __OrdaenTooltips_locales_TAB_NPCS = R.addon("OrdaenTooltips")["locales"].TAB_NPCS
local __OrdaenTooltips_settings_NpcsPage = R.addon("OrdaenTooltips")["settings"].NpcsPage
local __OrdaenTooltips_locales_TAB_OBJECTS = R.addon("OrdaenTooltips")["locales"].TAB_OBJECTS
local __OrdaenTooltips_settings_ObjectsPage = R.addon("OrdaenTooltips")["settings"].ObjectsPage
local __OrdaenTooltips_locales_TAB_TEXTS = R.addon("OrdaenTooltips")["locales"].TAB_TEXTS
local __OrdaenTooltips_settings_TextsPage = R.addon("OrdaenTooltips")["settings"].TextsPage
local __math_floor = R.math.floor
local __game__Clock_time = R.game.Clock.time
local __game__Tooltip_main = R.game.Tooltip.main
local __OrdaenTooltips_read_kindOf = R.addon("OrdaenTooltips")["read"].kindOf
local __game__Tooltip_hide = R.game.Tooltip.hide
local __game__Units_of = R.game.Units.of
local __OrdaenTooltips_read_group = R.addon("OrdaenTooltips")["read"].group
local __game__Clock_seconds = R.game.Clock.seconds
local __OrdaenTooltips_buttons_extras = R.addon("OrdaenTooltips")["buttons"].extras
local __game__Tooltip_compared = R.game.Tooltip.compared
local __OrdaenTooltips_item_item = R.addon("OrdaenTooltips")["item"].item
local __OrdaenTooltips_item_compare = R.addon("OrdaenTooltips")["item"].compare
local __OrdaenTooltips_locales_EQUIPPED = R.addon("OrdaenTooltips")["locales"].EQUIPPED
local __OrdaenTooltips_view_TipGroup = R.addon("OrdaenTooltips")["view"].TipGroup
local __Ordaen_module_Module = R.addon("Ordaen")["module"].Module
local M = {}
R.addon("OrdaenTooltips")["main"] = M
local UNIT_NAME, DELAY, CHARGE, STEPS, GRACE, REFRESH, NOTHING, Tooltips

local function __d1(self, parent)
	local __c2 = __OrdaenTooltips_settings_GeneralPage.new(parent, self.settings)
	__draw(parent, __c2, nil)
end

local function __d3(self, parent)
	local __c4 = __OrdaenTooltips_settings_ItemsPage.new(parent, self.settings)
	__draw(parent, __c4, nil)
end

local function __d5(self, parent)
	local __c6 = __OrdaenTooltips_settings_SpellsPage.new(parent, self.settings)
	__draw(parent, __c6, nil)
end

local function __d7(self, parent)
	local __c8 = __OrdaenTooltips_settings_AurasPage.new(parent, self.settings)
	__draw(parent, __c8, nil)
end

local function __d9(self, parent)
	local __c10 = __OrdaenTooltips_settings_PlayersPage.new(parent, self.settings)
	__draw(parent, __c10, nil)
end

local function __d11(self, parent)
	local __c12 = __OrdaenTooltips_settings_NpcsPage.new(parent, self.settings)
	__draw(parent, __c12, nil)
end

local function __d13(self, parent)
	local __c14 = __OrdaenTooltips_settings_ObjectsPage.new(parent, self.settings)
	__draw(parent, __c14, nil)
end

local function __d15(self, parent)
	local __c16 = __OrdaenTooltips_settings_TextsPage.new(parent, self.settings)
	__draw(parent, __c16, nil)
end

local function __c17(self)
	return self:readNow()
end

local function __c18(self)
	return __get(self.held) ~= nil
end

local function __c19(self)
	return self:chargeNow()
end

local function __c20(self)
	return self:goneNow()
end

local function __c21(self)
	return self:awayNow()
end

local function __c22(self)
	local __t25 = __get(self.read)
	if __t25 == nil then
		local __t23 = __get(self.held)
		local __t24
		if __t23 ~= nil then __t24 = __t23.shown end
		__t25 = __t24
	end
	return __t25
end

local function __c26(self)
	return __get(self.current) ~= nil
end

local function __c27(self)
	local __t28 = __get(self.current)
	local __t29
	if __t28 ~= nil then __t29 = __t28.model end
	return __t29 or NOTHING
end

local function __c30(self)
	local __t31 = __get(self.current)
	local __t32
	if __t31 ~= nil then __t32 = __t31.sides end
	return __t32 or {}
end

local function __c33(self)
	local __t34 = __get(self.current)
	local __t35
	if __t34 ~= nil then __t35 = __t34.compared end
	return __t35 or {}
end

local function __c36(self)
	local __t37 = __get(self.held)
	local __t38
	if __t37 ~= nil then __t38 = __t37.standing end
	return __t38 or self:where()
end

local function __d49(self, parent)
	local __c50 = __OrdaenTooltips_view_TipGroup.new(parent, self.model, self.sides, self.compared, self.standing, self.shown, self.charge, self.locked)
	__listen(__c50.close, self, self.close)
	__listen(__c50.enter, self, self.onEnter)
	__listen(__c50.leave, self, self.onLeave)
	__draw(parent, __c50, nil)
end

UNIT_NAME = 2
DELAY = 0.18
CHARGE = 1
STEPS = 100
GRACE = 0.22
REFRESH = 0.1
NOTHING = { kind = "text", name = "", nameColor = { r = 1, g = 1, b = 1, a = 1 }, desc = {}, info = {}, facts = {}, body = {}, more = {}, foot = {}, keys = {}, picture = "None" }

Tooltips = __class({})

function Tooltips.new(__owner)
	local self = setmetatable({ title = "Ordaen Tooltips" }, Tooltips)
	R.adopt(__owner, self)
	self.settings = __Ordaen_settings_Settings.new(self, { anchorToButtons = true, itemsOn = true, itemsAnchorBags = "anchor", itemsAnchorChar = "anchor", itemsIlvl = true, itemsId = false, itemsCount = true, itemsStack = true, itemsCooldown = true, spellsOn = true, spellsId = false, spellsNext = true, spellsCooldown = true, aurasOn = true, aurasId = false, aurasCaster = true, aurasTotal = true, playersOn = true, playersTarget = true, playersRelation = true, npcsOn = true, npcsParty = true, npcsLoot = true, npcsRep = true, objectsOn = true, textsOn = true, textsExtra = true, itemsLock = true, spellsLock = true, aurasLock = true, playersLock = true, npcsLock = true, objectsLock = true }, "account")
	self.pages = { { title = __OrdaenTooltips_locales_TAB_GENERAL, content = __template(__d1, self) }, { title = __OrdaenTooltips_locales_TAB_ITEMS, content = __template(__d3, self) }, { title = __OrdaenTooltips_locales_TAB_SPELLS, content = __template(__d5, self) }, { title = __OrdaenTooltips_locales_TAB_AURAS, content = __template(__d7, self) }, { title = __OrdaenTooltips_locales_TAB_PLAYERS, content = __template(__d9, self) }, { title = __OrdaenTooltips_locales_TAB_NPCS, content = __template(__d11, self) }, { title = __OrdaenTooltips_locales_TAB_OBJECTS, content = __template(__d13, self) }, { title = __OrdaenTooltips_locales_TAB_TEXTS, content = __template(__d15, self) } }
	self.read = __computed(self, __c17, self)
	self.target = __cell(nil)
	self.closed = __cell(false)
	self.held = __cell(nil)
	self.hiddenAt = __cell(nil)
	self.leftAt = __cell(nil)
	self.locked = __computed(self, __c18, self)
	self.charge = __computed(self, __c19, self)
	self.gone = __computed(self, __c20, self)
	self.away = __computed(self, __c21, self)
	self.current = __computed(self, __c22, self)
	self.shown = __computed(self, __c26, self)
	self.model = __computed(self, __c27, self)
	self.sides = __computed(self, __c30, self)
	self.compared = __computed(self, __c33, self)
	self.standing = __computed(self, __c36, self)
	__watch(self, self.keepUnseen, self)
	__watch(self, self.follow, self)
	__watch(self, self.lockCharged, self)
	__watch(self, self.forget, self)
	__watch(self, self.graceOut, self)
	return self
end

function Tooltips:chargeNow()
	if __get(self.held) ~= nil then
		return 100
	end
	local target = __get(self.target)
	if target == nil or not target.locks or __get(self.closed) then
		return 0
	end
	local steps = __math_floor((__get(__game__Clock_time) - target.since - 0.18) / 1 * 100)
	if steps < 0 then
		return 0
	end
	local __t39
	if steps < 100 then
		__t39 = steps
	else
		__t39 = 100
	end
	return __t39
end

function Tooltips:goneNow()
	local at = __get(self.hiddenAt)
	return at ~= nil and __get(self.held) == nil and __get(__game__Clock_time) >= at + 0.1
end

function Tooltips:awayNow()
	local at = __get(self.leftAt)
	return at ~= nil and __get(__game__Clock_time) >= at + 0.22
end

function Tooltips:follow()
	local tip = __get(__game__Tooltip_main)
	if not tip.shown then
		if __peek(self.hiddenAt) == nil then
			__set(self.hiddenAt, __peek(__game__Clock_time))
		end
		return
	end
	__set(self.hiddenAt, nil)
	local data = tip.data
	local target = __peek(self.target)
	if target ~= nil and target.kind == data.kind and target.about == data.about then
		return
	end
	local kind = __OrdaenTooltips_read_kindOf(data)
	__set(self.held, nil)
	__set(self.leftAt, nil)
	__set(self.closed, false)
	__set(self.target, { kind = data.kind, about = data.about, since = __peek(__game__Clock_time), locks = kind ~= nil and self:wanted(kind, data) and self:locks(kind, data) })
end

function Tooltips:lockCharged()
	if __get(self.charge) < 100 or __peek(self.held) ~= nil then
		return
	end
	local read = __peek(self.read)
	if read == nil then
		__set(self.closed, true)
		return
	end
	__set(self.held, { shown = { model = read.model, sides = read.sides, compared = read.compared }, standing = __peek(self.standing) })
end

function Tooltips:forget()
	if __get(self.gone) then
		__set(self.target, nil)
		__set(self.closed, false)
		__set(self.hiddenAt, nil)
	end
end

function Tooltips:graceOut()
	if __get(self.away) then
		self:close()
	end
end

function Tooltips:close()
	__set(self.closed, true)
	__set(self.held, nil)
	__set(self.leftAt, nil)
end

function Tooltips:onEnter()
	__set(self.leftAt, nil)
end

function Tooltips:onLeave()
	__set(self.leftAt, __peek(__game__Clock_time))
end

function Tooltips:keepUnseen()
	__game__Tooltip_hide(__get(self.shown))
end

function Tooltips:options()
	local chosen = self.settings
	return { spellsCooldown = __getKey(chosen.values, "spellsCooldown"), spellsId = __getKey(chosen.values, "spellsId"), spellsNext = __getKey(chosen.values, "spellsNext"), aurasCaster = __getKey(chosen.values, "aurasCaster"), aurasTotal = __getKey(chosen.values, "aurasTotal"), aurasId = __getKey(chosen.values, "aurasId"), classNames = true, playersTarget = __getKey(chosen.values, "playersTarget"), playersRelation = __getKey(chosen.values, "playersRelation"), npcsLoot = __getKey(chosen.values, "npcsLoot"), npcsParty = __getKey(chosen.values, "npcsParty"), npcsRep = __getKey(chosen.values, "npcsRep"), itemsIlvl = __getKey(chosen.values, "itemsIlvl"), itemsCooldown = __getKey(chosen.values, "itemsCooldown"), itemsId = __getKey(chosen.values, "itemsId"), itemsCount = __getKey(chosen.values, "itemsCount"), itemsStack = __getKey(chosen.values, "itemsStack") }
end

function Tooltips:aPlayer(data)
	local first = data.lines[1]
	local __t40
	if first ~= nil and first.kind == 2 then
		__t40 = first.unit
	else
		__t40 = nil
	end
	local token = __t40
	local __t41
	if token ~= nil then
		__t41 = __game__Units_of(token)
	else
		__t41 = nil
	end
	local who = __t41
	return who ~= nil and who.player
end

function Tooltips:wanted(kind, data)
	local chosen = self.settings
	if kind == "item" then
		return __getKey(chosen.values, "itemsOn")
	elseif kind == "spell" then
		return __getKey(chosen.values, "spellsOn")
	elseif kind == "aura" then
		return __getKey(chosen.values, "aurasOn")
	elseif kind == "object" then
		return __getKey(chosen.values, "objectsOn")
	elseif kind == "text" then
		return __getKey(chosen.values, "textsOn")
	elseif kind == "set" then
		return false
	elseif kind == "term" then
		return false
	elseif kind == "unit" then
		local __t42
		if self:aPlayer(data) then
			__t42 = __getKey(chosen.values, "playersOn")
		else
			__t42 = __getKey(chosen.values, "npcsOn")
		end
		return __t42
	end
end

function Tooltips:locks(kind, data)
	local chosen = self.settings
	if kind == "item" then
		return __getKey(chosen.values, "itemsLock")
	elseif kind == "spell" then
		return __getKey(chosen.values, "spellsLock")
	elseif kind == "aura" then
		return __getKey(chosen.values, "aurasLock")
	elseif kind == "object" then
		return __getKey(chosen.values, "objectsLock")
	elseif kind == "text" then
		return false
	elseif kind == "set" then
		return false
	elseif kind == "term" then
		return false
	elseif kind == "unit" then
		local __t43
		if self:aPlayer(data) then
			__t43 = __getKey(chosen.values, "playersLock")
		else
			__t43 = __getKey(chosen.values, "npcsLock")
		end
		return __t43
	end
end

function Tooltips:readNow()
	local tip = __get(__game__Tooltip_main)
	if not tip.shown then
		return nil
	end
	local kind = __OrdaenTooltips_read_kindOf(tip.data)
	if kind == nil or not self:wanted(kind, tip.data) then
		return nil
	end
	local options = self:options()
	local read = __OrdaenTooltips_read_group(tip.data, options)
	if read == nil then
		return nil
	end
	if read.model.timer == true then
		local _ = __get(__game__Clock_seconds)
	end
	local __t44
	if __getKey(self.settings.values, "textsExtra") then
		__t44 = __OrdaenTooltips_buttons_extras(tip.ownerName, read.model)
	else
		__t44 = read.model
	end
	local told = __t44
	if told.kind ~= "item" then
		return { model = told, sides = read.sides, compared = {} }
	end
	local worn = __get(__game__Tooltip_compared)
	local compared = {}
	local model = told
	for __i45 = 1, #worn do
		local data = worn[__i45]
		repeat
			local other = __OrdaenTooltips_item_item(data, options)
			if other == nil then
				break
			end
			if #worn == 1 then
				model = __OrdaenTooltips_item_compare(model, read.stats, other.stats, true)
				local __t46 = other.model
				__insert(compared, { header = __OrdaenTooltips_locales_EQUIPPED, kind = __t46.kind, picture = __t46.picture, name = __t46.name, nameColor = __t46.nameColor, desc = __t46.desc, info = __t46.info, facts = __t46.facts, body = __t46.body, more = __t46.more, foot = __t46.foot, keys = __t46.keys, timer = __t46.timer })
			else
				local __t47 = __OrdaenTooltips_item_compare(other.model, read.stats, other.stats, false)
				__insert(compared, { header = __OrdaenTooltips_locales_EQUIPPED, kind = __t47.kind, picture = __t47.picture, name = __t47.name, nameColor = __t47.nameColor, desc = __t47.desc, info = __t47.info, facts = __t47.facts, body = __t47.body, more = __t47.more, foot = __t47.foot, keys = __t47.keys, timer = __t47.timer })
			end
		until true
	end
	return { model = model, sides = read.sides, compared = compared }
end

function Tooltips:beside(tip)
	local chosen = self.settings
	local name = tip.ownerName or ""
	local __t48
	if __getKey(chosen.values, "anchorToButtons") then
		__t48 = "anchor"
	else
		__t48 = "corner"
	end
	local place = __t48
	if (name):match("^Character.+Slot$") ~= nil then
		place = __getKey(chosen.values, "itemsAnchorChar")
	elseif (name):match("^ContainerFrame%d+Item") ~= nil or (name):match("^Bank") ~= nil then
		place = __getKey(chosen.values, "itemsAnchorBags")
	end
	return place == "anchor" and tip.placeable
end

function Tooltips:where()
	local tip = __get(__game__Tooltip_main)
	local owner = tip.owner
	if owner ~= nil and self:beside(tip) then
		return { by = owner, below = tip.ownerHigh, right = tip.ownerRight }
	end
	return { by = tip.corner, below = tip.below, right = tip.right }
end

function Tooltips:render()
	return __template(__d49, self)
end
__inherit(Tooltips, { __Ordaen_module_Module })

M.UNIT_NAME = UNIT_NAME
M.DELAY = DELAY
M.CHARGE = CHARGE
M.STEPS = STEPS
M.GRACE = GRACE
M.REFRESH = REFRESH
M.NOTHING = NOTHING
M.Tooltips = Tooltips
