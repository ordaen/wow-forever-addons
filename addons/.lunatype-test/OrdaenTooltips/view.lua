-- Made by lunatype from OrdaenTooltips/view.luna: change the source, not this file.
local R = LunaType
local __get, __getKey, __len, __cell, __computed, __event, __listen, __emit, __class, __inherit, __el, __attr, __bind, __on, __template, __draw, __when, __each = R.get, R.getKey, R.len, R.cell, R.computed, R.event, R.listen, R.emit, R.class, R.inherit, R.el, R.attr, R.bind, R.on, R.template, R.draw, R.when, R.each
local __insert = table.insert
local __OrdaenTooltips_term_term = R.addon("OrdaenTooltips")["term"].term
local __OrdaenTooltips_frame_TipFrame = R.addon("OrdaenTooltips")["frame"].TipFrame
local __Ordaen_module_Component = R.addon("Ordaen")["module"].Component
local M = {}
R.addon("OrdaenTooltips")["view"] = M
local PX, GAP, LOWERED, LEVEL, NOTHING, Opened, TipGroup

local function __c1(self)
	return self:read()
end

local function __d3(self, parent)
	local __c4 = __OrdaenTooltips_frame_TipFrame.new(parent, self.model, __cell(true), nil, nil, nil)
	__draw(parent, __c4, nil)
end

local function __c5(self)
	return __len(self.compared) > 0
end

local function __c6(self)
	return self:inOrder()
end

local function __c7(self)
	return self:autos(__len(self.pieces))
end

local function __c8(self)
	return self:at()
end

local function __c9(self)
	local __t10
	if __getKey(self.standing, "below") or __get(self.comparing) then
		__t10 = "start"
	else
		__t10 = "end"
	end
	return __t10
end

local function __c11(self)
	local __t12
	if __get(self.comparing) then
		__t12 = LOWERED
	else
		__t12 = LEVEL
	end
	return __t12
end

local function __b19(self)
	return __get(self.shown)
end

local function __b22(self)
	return __get(self.place)
end

local function __b23(self)
	return __get(self.columns)
end

local function __b24(self)
	return __get(self.across)
end

local function __b26(self)
	return __get(self.locked)
end

local function __d27(self, parent)
	local __e28 = __el(parent, "box")
	__attr(__e28, "position", "absolute")
	__attr(__e28, "left", 0)
	__attr(__e28, "top", 0)
	__attr(__e28, "right", 0)
	__attr(__e28, "bottom", 0)
	__attr(__e28, "hoverWithin", true)
	__on(__e28, "enter", self, self.onEnter)
	__on(__e28, "leave", self, self.onLeave)
end

local __w25 = { __b26, __d27 }

local function __b29(self)
	return __get(self.pieces)
end

local function __b32(self, piece)
	return __getKey(piece, "slot") == "main"
end

local function __b35(self, piece)
	return __get(self.lowered)
end

local function __b37(self, piece)
	return __getKey(piece, "model")
end

local function __d38(self, parent, piece, __2, __3, __v39)
	local __c40 = Opened.new(parent, __v39[1])
	__draw(parent, __c40, nil)
end

local function __d33(self, parent, piece)
	local __e34 = __el(parent, "box")
	__bind(__e34, "padding", __b35, self, piece)
	local __c36 = __OrdaenTooltips_frame_TipFrame.new(__e34, __computed(__e34, __b37, self, piece), nil, __cell(true), self.charge, self.locked)
	__listen(__c36.close, self, self.onClose)
	__draw(__e34, __c36, { self = self, a = piece, ["opened"] = __d38 })
end

local function __b41(self, piece)
	return __getKey(piece, "slot") == "sides"
end

local function __b44(self, piece)
	return __get(self.across)
end

local function __b45(self, piece)
	return __get(self.sides)
end

local function __d46(self, parent, piece, side)
	local __c47 = __OrdaenTooltips_frame_TipFrame.new(parent, side, __cell(true), nil, nil, nil)
	__draw(parent, __c47, nil)
end

local function __d42(self, parent, piece)
	local __e43 = __el(parent, "box")
	__attr(__e43, "gap", 3.3333333333333335)
	__bind(__e43, "yAlign", __b44, self, piece)
	__each(__e43, __b45, nil, __d46, 2, 0, true, self, piece)
end

local function __b48(self, piece)
	return __getKey(piece, "slot") == "compared"
end

local function __b51(self, piece)
	return __getKey(piece, "model")
end

local function __d49(self, parent, piece)
	local __c50 = __OrdaenTooltips_frame_TipFrame.new(parent, __computed(parent, __b51, self, piece), __cell(true), nil, nil, nil)
	__draw(parent, __c50, nil)
end

local __w31 = { __b32, __d33, __b41, __d42, __b48, __d49 }

local function __d30(self, parent, piece)
	__when(parent, __w31, self, piece)
end

local function __d20(self, parent)
	local __e21 = __el(parent, "surface")
	__attr(__e21, "layer", "tooltip")
	__bind(__e21, "place", __b22, self)
	__bind(__e21, "columns", __b23, self)
	__attr(__e21, "gap", 3.3333333333333335)
	__bind(__e21, "yAlign", __b24, self)
	__when(__e21, __w25, self)
	__each(__e21, __b29, nil, __d30, 1, 0, true, self)
end

local __w18 = { __b19, __d20 }

local function __d17(self, parent)
	__when(parent, __w18, self)
end

PX = 0.8333333333333334
GAP = 3.3333333333333335
LOWERED = { top = 29.166666666666668 }
LEVEL = {}
NOTHING = { kind = "text", name = "", nameColor = { r = 1, g = 1, b = 1, a = 1 }, desc = {}, info = {}, facts = {}, body = {}, more = {}, foot = {}, keys = {}, picture = "None" }

Opened = __class({})

function Opened.new(__owner, opens)
	local self = setmetatable({}, Opened)
	R.adopt(__owner, self)
	self.opens = opens
	self.model = __computed(self, __c1, self)
	return self
end

function Opened:read()
	local opens = __get(self.opens)
	local __s2 = opens[1] or opens
	if __s2 == "Term" then
		return __OrdaenTooltips_term_term(opens.term, opens.amount)
	elseif __s2 == "None" then
		return NOTHING
	end
end

function Opened:render()
	return __template(__d3, self)
end

TipGroup = __class({})

function TipGroup.new(__owner, model, sides, compared, standing, shown, charge, locked)
	local self = setmetatable({}, TipGroup)
	R.adopt(__owner, self)
	if charge == nil then charge = __cell(0) end
	if locked == nil then locked = __cell(false) end
	self.model = model
	self.sides = sides
	self.compared = compared
	self.standing = standing
	self.shown = shown
	self.charge = charge
	self.locked = locked
	self.comparing = __computed(self, __c5, self)
	self.pieces = __computed(self, __c6, self)
	self.columns = __computed(self, __c7, self)
	self.place = __computed(self, __c8, self)
	self.across = __computed(self, __c9, self)
	self.lowered = __computed(self, __c11, self)
	self.close = __event()
	self.enter = __event()
	self.leave = __event()
	return self
end

function TipGroup:onClose()
	__emit(self.close)
end

function TipGroup:onEnter()
	__emit(self.enter)
end

function TipGroup:onLeave()
	__emit(self.leave)
end

function TipGroup:inOrder()
	local outwards = { { slot = "main", model = __get(self.model) } }
	if __len(self.sides) > 0 then
		__insert(outwards, { slot = "sides", model = __get(self.model) })
	end
	local __l14 = __get(self.compared)
	for __i13 = 1, #__l14 do
		local model = __l14[__i13]
		__insert(outwards, { slot = "compared", model = model })
	end
	if not __getKey(self.standing, "right") then
		return outwards
	end
	local leftwards = {}
	for i = #outwards, 1, -1 do
		local piece = outwards[i]
		if piece ~= nil then
			__insert(leftwards, piece)
		end
	end
	return leftwards
end

function TipGroup:autos(count)
	local list = {}
	for i = 1, count do
		__insert(list, "auto")
	end
	return list
end

function TipGroup:at()
	local standing = __get(self.standing)
	if standing.below then
		local __t15
		if standing.right then
			__t15 = { point = "TOPRIGHT", to = "BOTTOMRIGHT", by = standing.by }
		else
			__t15 = { point = "TOPLEFT", to = "BOTTOMLEFT", by = standing.by }
		end
		return __t15
	end
	local __t16
	if standing.right then
		__t16 = { point = "BOTTOMRIGHT", to = "TOPRIGHT", by = standing.by }
	else
		__t16 = { point = "BOTTOMLEFT", to = "TOPLEFT", by = standing.by }
	end
	return __t16
end

function TipGroup:render()
	return __template(__d17, self)
end
__inherit(Opened, { __Ordaen_module_Component })
__inherit(TipGroup, { __Ordaen_module_Component })

M.PX = PX
M.GAP = GAP
M.LOWERED = LOWERED
M.LEVEL = LEVEL
M.NOTHING = NOTHING
M.Opened = Opened
M.TipGroup = TipGroup
