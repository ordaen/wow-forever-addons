-- One Ordaen tooltip in place of a Blizzard one (design tooltips/): its frame (tipFrame) where Blizzard placed its
-- own (the same anchor point, to Blizzard's invisible tooltip), or beside the button or item slot it belongs to, and
-- the tooltips open from the start beside it in one column (use effects, the set, the item a recipe makes), on its
-- right. While something in it counts down (a cooldown, an aura's time) it is read again once a second; nothing runs
-- otherwise.
--
-- Attributes: `tip` (game.Tooltip.<name>), `model` (Read's model for it), `refill` (reads the tip into the model
-- again: the module's), `anchor` (nil: Blizzard's place; else { to, point, relativePoint } beside its owner),
-- `epoch` (the module's: changes when a comparison rewrote this view's rows); the lock (the module's, design
-- «Tooltips in tooltips»): `charge` (its steps, the main tooltip's bar), `kept` (locked while this view showed: it
-- stays after Blizzard's goes), `locked`, `OnEnter`/`OnLeave` (the mouse on the locked group) and `OnClose`; the
-- tooltips opened from its links (the main view only): `links` (per depth, OnLink of its rows: 0 this view's),
-- `nested` (their models by depth, `.n` open), `nest` (changes when one opens or closes), `nestHover` (per depth,
-- { OnEnter, OnLeave }: the mouse on that one); `compares` (the main view only: the comparison tooltips, each
-- { tip, model, name, call }, drawn on its right while shown or kept by the lock; `keptBy` the lock's kept views,
-- `compareEpoch` the module's epoch).
local Define = import("@ordaen/define")

local PX = 1 / 1.2
-- the group's columns: the tooltip, then the ones beside it, then each opened from a link (one table per count)
local COLUMNS = {}
for n = 1, 8 do
	local list = {}
	for i = 1, n do
		list[i] = "auto"
	end
	COLUMNS[n] = list
end

local function Link(_, self)
	return self.attributes.locked and self.attributes.links and self.attributes.links[0] or nil
end

-- a tooltip opened from a link, in a box that knows the mouse on it
local function Opened(game, self)
	local d = self.nestedDepth
	game.ui:TipFrame(nil, self.nestedCalls[d], d)
end
local function Nested(game, self)
	local nested = self.attributes.nested
	local calls, boxes = self.nestedCalls, self.nestedBoxes
	for d = 1, nested.n do
		local call = calls[d]
		if not call then
			call = { attributes = { side = true, locked = false } }
			calls[d] = call
			local hover = self.attributes.nestHover[d]
			boxes[d] = { attributes = { columns = 1, hoverWithin = true, OnEnter = hover.OnEnter,
				OnLeave = hover.OnLeave }, slots = { default = self.opened[d] } }
		end
		local a = call.attributes
		a.model, a.version, a.OnLink = nested[d], self.attributes.nest, self.attributes.links[d]
		game.ui:Box(nil, boxes[d], d)
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
		call.attributes.model, call.attributes.version = m.side[i], self.attributes.tip.shown:Get() * 1000000 +
			self.attributes.epoch * 1000 + self.state.tick
		call.attributes.OnLink = Link(game, self)
		game.ui:TipFrame(nil, call, i)
	end
end

local function Parts(game, self)
	local call = self.mainCall
	-- a new show, a comparison or a refill: the frames draw again
	local a = call.attributes
	a.model, a.version = self.attributes.model, self.attributes.tip.shown:Get() * 1000000 +
		self.attributes.epoch * 1000 + self.state.tick
	a.charge, a.locked, a.OnClose = self.attributes.charge, self.attributes.locked, self.attributes.OnClose
	a.OnLink = Link(game, self)
	game.ui:TipFrame(call)
	local n = 1
	if self.attributes.model.side.n > 0 then
		game.ui:Box(self.sidesBox)
		n = n + 1
	end
	local compares = self.attributes.compares
	if compares then
		local kept = self.attributes.locked and self.attributes.keptBy
		for i = 1, #compares do
			local c = compares[i]
			local shown = c.tip.shown:Get()
			if shown > 0 or (kept and kept[c.name]) then
				local ca = c.call.attributes
				ca.model, ca.version = c.model, shown * 1000000 + (self.attributes.compareEpoch or 0) * 1000
				ca.OnLink = Link(game, self)
				game.ui:TipFrame(nil, c.call, c.name)
				n = n + 1
			end
		end
	end
	local nested = self.attributes.nested
	local _ = self.attributes.nest -- read: one opened or closed draws again
	if nested and nested.n > 0 and self.attributes.locked then
		self.nestedBox.attributes.columns = COLUMNS[nested.n]
		game.ui:Box(self.nestedBox)
		n = n + 1
	end
	self.box.attributes.columns = COLUMNS[n]
end

return Define.Component({
	Setup = function(_, self)
		Define.Ephemeral({ tick = { type = "number", default = 0 } }) -- the once-a-second refills of this show
		self.mainCall = { attributes = {} }
		self.sideCalls = {}
		self.sidesBox = { attributes = { columns = 1, gap = 4 * PX, yAlign = "start" }, slots = { default = Sides } }
		self.nestedBox = { attributes = { columns = 1, gap = 4 * PX, yAlign = "start" }, slots = { default = Nested } }
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
		local beside = self.attributes.anchor
		if beside then
			a.anchor = beside
		elseif a.anchor.to ~= tip.frame or a.anchor.point ~= tip.point then
			a.anchor = { to = tip.frame, point = tip.point, relativePoint = tip.point } -- a new place: a new table
		end
		game.ui:Box(self.box)
	end,
})
