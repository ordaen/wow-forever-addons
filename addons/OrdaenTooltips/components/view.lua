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
-- stays after Blizzard's goes), `locked`, `OnEnter`/`OnLeave` (the mouse on the locked group) and `OnClose`.
local Define = import("@ordaen/define")

local PX = 1 / 1.2

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
	game.ui:TipFrame(call)
	if self.attributes.model.side.n > 0 then
		game.ui:Box(self.sidesBox)
	end
end

return Define.Component({
	Setup = function(_, self)
		Define.Ephemeral({ tick = { type = "number", default = 0 } }) -- the once-a-second refills of this show
		self.mainCall = { attributes = {} }
		self.sideCalls = {}
		self.sidesBox = { attributes = { columns = 1, gap = 4 * PX, yAlign = "start" }, slots = { default = Sides } }
		self.box = { attributes = { position = "fixed", columns = { "auto", "auto" }, gap = 4 * PX, yAlign = "start",
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
