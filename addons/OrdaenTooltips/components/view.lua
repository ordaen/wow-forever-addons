-- One Ordaen tooltip in place of a Blizzard one (design tooltips/) and the group around it: the tooltip itself (the
-- main one), the ones open from the start beside it (use effects, the set, the item a recipe makes: one column), the
-- comparison tooltips (the main view's); the ones opened from links each at the text that opened it. While something in it
-- counts down (a cooldown, an aura's time) it is read again once a second; nothing runs otherwise.
--
-- Placement (design tooltips «Placement»), decided once per show:
--   beside its owner (`place`, the module's): above it, the bottom edges of the group's tooltips on the owner's top,
--   or below it, their top edges on its bottom; lined up on the owner's left edge, or on its right edge with the
--   group running leftwards (place.right);
--   else where Blizzard placed its own (the same point, to Blizzard's invisible tooltip), the group running away from
--   that point's side.
-- The main tooltip is always the one at the anchor; the others follow it in one row, in the order above, lined up on
-- the edge that faces the owner (so no tooltip floats off it). The row's columns are set before it draws.
--
-- Attributes: `tip` (game.Tooltip.<name>), `model` (Read's model for it), `refill` (reads the tip into the model
-- again: the module's), `places` (the module's: tip name -> nil for Blizzard's place, else { to, below, right },
-- written as each show starts), `epoch` (the module's: changes when a comparison rewrote this view's rows); the lock (the module's, design «Tooltips in tooltips»): `charge` (its
-- steps, the main tooltip's bar), `kept` (locked while this view showed: it stays after Blizzard's goes), `locked`,
-- `OnEnter`/`OnLeave` (the mouse on the locked group) and `OnClose`; the main view's: `links` (per depth, OnLink of
-- its tooltips' parts: 0 the group's own), `nested` (the models opened from links by depth, `.n` open, `.at[d]` the
-- frame of the text it opened from), `nest`
-- (changes when one opens or closes), `nestHover` (per depth, { OnEnter, OnLeave }), `compares` (the comparison
-- tooltips, each { tip, model, name, call }), `keptBy` (the lock's kept views by name).
local Define = import("@ordaen/define")

local PX = 1 / 1.2
-- the group's columns (one table per count)
local COLUMNS = {}
for n = 1, 8 do
	local list = {}
	for i = 1, n do
		list[i] = "auto"
	end
	COLUMNS[n] = list
end
local MAIN, SIDES = "main", "sides" -- the group's parts (a comparison: its index)

local function Link(_, self)
	return self.attributes.locked and self.attributes.links and self.attributes.links[0] or nil
end

local function Version(self, tip)
	return tip.shown:Get() * 1000000 + self.attributes.epoch * 1000 + self.state.tick
end

-- a tooltip opened from a link: its own box at the text that opened it (below it, or above it in the screen's lower
-- half; on its left edge, or its right edge in the screen's right third), knowing the mouse on it
local function Opened(game, self)
	local d = self.nestedDepth
	game.ui:TipFrame(nil, self.nestedCalls[d], d)
end

local function AnchorAt(box, frame)
	local x, y = frame:GetCenter()
	local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
	local side = (x and x * scale > UIParent:GetWidth() * 2 / 3) and "RIGHT" or "LEFT"
	local below = not y or y * scale > UIParent:GetHeight() / 2
	local point = (below and "TOP" or "BOTTOM") .. side
	local relativePoint = (below and "BOTTOM" or "TOP") .. side
	local anchor = box.attributes.anchor
	if not anchor or anchor.to ~= frame or anchor.point ~= point then
		box.attributes.anchor = { to = frame, point = point, relativePoint = relativePoint }
	end
end

local function Nested(game, self)
	local nested = self.attributes.nested
	local _ = self.attributes.nest -- read: one opened or closed draws again
	if not (nested and self.attributes.locked) then
		return
	end
	local calls, boxes = self.nestedCalls, self.nestedBoxes
	for d = 1, nested.n do
		local frame = nested.at[d]
		if frame then
			local call = calls[d]
			if not call then
				call = { attributes = { side = true, locked = false } }
				calls[d] = call
				local hover = self.attributes.nestHover[d]
				boxes[d] = { attributes = { position = "fixed", columns = 1, hoverWithin = true,
					OnEnter = hover.OnEnter, OnLeave = hover.OnLeave }, slots = { default = self.opened[d] } }
			end
			local a = call.attributes
			a.model, a.version, a.OnLink = nested[d], self.attributes.nest, self.attributes.links[d]
			AnchorAt(boxes[d], frame)
			game.ui:Box(nil, boxes[d], d)
		end
	end
end

local function Sides(game, self)
	local m = self.attributes.model
	local calls = self.sideCalls
	for i = 1, m.side.n do
		local call = calls[i]
		if not call then
			call = { attributes = { side = true } }
			calls[i] = call
		end
		call.attributes.model, call.attributes.version = m.side[i], Version(self, self.attributes.tip)
		call.attributes.OnLink = Link(game, self)
		game.ui:TipFrame(nil, call, i)
	end
end

local function Part(game, self, part)
	if part == MAIN then
		local a = self.mainCall.attributes
		a.model, a.version = self.attributes.model, Version(self, self.attributes.tip)
		a.charge, a.locked, a.OnClose = self.attributes.charge, self.attributes.locked, self.attributes.OnClose
		a.OnLink = Link(game, self)
		game.ui:TipFrame(self.mainCall)
	elseif part == SIDES then
		game.ui:Box(self.sidesBox)
	else
		local c = self.attributes.compares[part]
		local a = c.call.attributes
		a.model, a.version = c.model, c.tip.shown:Get() * 1000000 + self.attributes.epoch * 1000
		a.OnLink = Link(game, self)
		game.ui:TipFrame(nil, c.call, c.name)
	end
end

-- the group's parts in order: the main tooltip at the anchor, the rest away from it
local function Parts(game, self)
	local order, n = self.order, self.nParts
	if self.reversed then
		for i = n, 1, -1 do
			Part(game, self, order[i])
		end
	else
		for i = 1, n do
			Part(game, self, order[i])
		end
	end
end

-- what the group holds this time, in order from the main tooltip outwards
local function Order(self)
	local order, n = self.order, 1
	order[1] = MAIN
	if self.attributes.model.side.n > 0 then
		n = n + 1
		order[n] = SIDES
	end
	local compares = self.attributes.compares
	if compares then
		local kept = self.attributes.locked and self.attributes.keptBy
		for i = 1, #compares do
			local c = compares[i]
			if c.tip.shown:Get() > 0 or (kept and kept[c.name]) then
				n = n + 1
				order[n] = i
			end
		end
	end
	self.nParts = n
	return n
end

-- the anchor: beside the owner by its corner, or Blizzard's own point (a new table only for a new place)
local function Place(self, tip)
	-- read at each show from the module's table: an attribute set by the module would be the last show's
	local a, place = self.box.attributes, self.attributes.places[tip.name]
	local to, point, relativePoint, below, right
	if place then
		below, right = place.below, place.right
		local side = right and "RIGHT" or "LEFT"
		to = place.to
		point = (below and "TOP" or "BOTTOM") .. side
		relativePoint = (below and "BOTTOM" or "TOP") .. side
	else
		to, point, relativePoint = tip.frame, tip.point, tip.point
		below, right = not point:find("BOTTOM"), point:find("RIGHT") ~= nil
	end
	local anchor = a.anchor
	if anchor.to ~= to or anchor.point ~= point or anchor.relativePoint ~= relativePoint then
		a.anchor = { to = to, point = point, relativePoint = relativePoint }
	end
	a.yAlign = below and "start" or "end" -- every tooltip's edge on the owner's side lined up
	self.reversed = right
end

return Define.Component({
	Setup = function(_, self)
		Define.Ephemeral({ tick = { type = "number", default = 0 } }) -- the once-a-second refills of this show
		self.mainCall = { attributes = {} }
		self.sideCalls = {}
		self.order, self.nParts, self.reversed = {}, 0, false
		self.sidesBox = { attributes = { columns = 1, gap = 4 * PX }, slots = { default = Sides } }
		self.nestedCalls, self.nestedBoxes, self.opened = {}, {}, {}
		for d = 1, 8 do
			self.opened[d] = function(game)
				self.nestedDepth = d
				Opened(game, self)
			end
		end
		self.box = { attributes = { position = "fixed", columns = COLUMNS[1], gap = 4 * PX, yAlign = "start",
			anchor = {} }, slots = { default = Parts } }
		local function Tick()
			local tip = self.attributes.tip
			if self.attributes.refill(tip) then
				self.state.tick = Define.Peek(self.state.tick) + 1
			end
		end
		-- once a second, only while a shown tooltip has something counting down
		self:Watch(function()
			local tip = self.attributes.tip
			if tip.shown:Get() > 0 and self.attributes.model.timer then
				self:Every(1, Tick)
			end
		end)
	end,

	Render = function(game, self)
		local tip = self.attributes.tip
		if tip.shown:Get() == 0 and not self.attributes.kept then
			return
		end
		local a = self.box.attributes
		-- locked: the mouse on it keeps the group (else the box lets the mouse through to what's under it)
		local locked = self.attributes.locked
		a.hoverWithin = locked or nil
		a.OnEnter = locked and self.attributes.OnEnter or nil
		a.OnLeave = locked and self.attributes.OnLeave or nil
		Place(self, tip)
		a.columns = COLUMNS[Order(self)]
		-- the sides' column lined up like the row
		self.sidesBox.attributes.yAlign = a.yAlign
		game.ui:Box(self.box)
		Nested(game, self)
	end,
})
