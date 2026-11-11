-- Zones (design settings, Ordaen Panel «Нижняя панель» → «Элементы»): where each of a part's items sits, edited by
-- dragging. The zones side by side in one bronze-edged box, each with its name on top; under them «Не на панели»,
-- the pool of what isn't placed. Each item is a chip (its setting's label) in the zone its setting names; dragging a
-- chip into another zone, or into the pool, sets it (through the settings window's draft). The cursor on a chip shows
-- its setting's hint.
--
-- Attributes: `items`, the choice Settings it edits (Define.Signal each), all with the same members: every member but
-- `off` is a zone, in the members' order; `off` is the pool. A custom editor's `title` is its section's.
local Define = import("@ordaen/define")

local PX = 1 / 1.2 -- UI units a design px is at the user's scale (a 1440p screen)
local OFF = "off"
local DIM = { 0.639, 0.592, 0.498, 1 } -- --o-dim #a3977f
local CHIP_TEXT = { 0.953, 0.882, 0.722, 1 } -- #f3e1b8
-- the zones' box: #2a1e10 at the top to #1a1208, a 1 px bronze edge (design .sw-zones)
local BOX_FILL = { from = { 42 / 255, 30 / 255, 16 / 255, 1 }, to = { 26 / 255, 18 / 255, 8 / 255, 1 },
	direction = "vertical" }
local BRONZE = { width = 1 * PX, color = { 108 / 255, 85 / 255, 53 / 255, 1 } }
-- a zone after the first: its 1 px #3e2f1d left edge
local DIVIDER = { width = 1 * PX, sides = { "left" }, color = { 62 / 255, 47 / 255, 29 / 255, 1 } }
-- a chip: #5a4428 to #3a2a16, a 1 px #1a1306 edge (design .chipz); in the pool, greyed
local CHIP_FILL = { from = { 90 / 255, 68 / 255, 40 / 255, 1 }, to = { 58 / 255, 42 / 255, 22 / 255, 1 },
	direction = "vertical" }
local CHIP_EDGE = { width = 1 * PX, color = { 26 / 255, 19 / 255, 6 / 255, 1 } }
-- the pool: a #4a3a24 edge on a dark fill (design .sw-offpool draws it dashed)
local POOL_FILL = { 0, 0, 0, 0.25 }
local POOL_EDGE = { width = 1 * PX, color = { 74 / 255, 58 / 255, 36 / 255, 1 } }
local ALIGN = { "start", "center", "end" } -- the zones' chips: from the left, centred, to the right

local function Chips(game, self, member)
	local items = self.attributes.items
	local calls = self.chips
	for i = 1, #items do
		if items[i]:Get() == member then
			game.ui:Box(calls[i][member == OFF])
		end
	end
end

local function Zones(game, self)
	local calls = self.zoneCalls
	for k = 1, #calls do
		game.ui:Box(calls[k])
	end
end

local function Parts(game, self)
	game.ui:Box(self.zonesCall)
	game.ui:Text(self.poolLabel)
	game.ui:Box(self.poolCall)
	-- the hovered chip's hint, under the zones
	local tip = self.state.tip
	if tip > 0 and self.tips[tip] then
		game.ui:Tip(self.tips[tip])
	end
end

return Define.Component({
	Setup = function(_, self)
		Define.Ephemeral({
			dragging = { type = "number", default = 0 }, -- the item being dragged, by index; 0: none
			tip = { type = "number", default = 0 }, -- the item under the cursor, by index; 0: none
		})
		local items = self.attributes.items
		local out = {}
		local function stop()
			self.state.dragging = 0
		end
		local function leave()
			self.state.tip = 0
		end
		-- each chip, made once: its text, and its box in a zone and in the pool; its hint's tooltip
		out.chips, out.tips = {}, {}
		for i = 1, #items do
			local item = items[i]
			local text = { attributes = { text = item:Label(), textColor = CHIP_TEXT, textSize = 14 * PX, wrap = false } }
			local function slot(game)
				game.ui:Text(text)
			end
			local function start()
				self.state.dragging = i
				self.state.tip = 0
			end
			local function enter()
				if self.state.dragging == 0 then
					self.state.tip = i
				end
			end
			local function chip(pooled)
				return { key = i, attributes = {
					padding = { 4 * PX, 10 * PX, 4 * PX, 10 * PX }, background = CHIP_FILL, border = CHIP_EDGE,
					desaturate = pooled, opacity = pooled and 0.8 or 1,
					OnDragStart = start, OnDragStop = stop, OnEnter = enter, OnLeave = leave,
				}, slots = { default = slot } }
			end
			out.chips[i] = { [false] = chip(false), [true] = chip(true) }
			local hint = item:Tip()
			if hint and hint ~= "" then
				out.tips[i] = { attributes = { title = item:Label(), text = hint, left = 0, top = 0 } }
			end
		end
		-- each zone (every member but off) and the pool, made once
		local function drop(member)
			return function()
				local item = items[self.state.dragging]
				if item and item:Peek() ~= member then
					item:Set(member)
				end
			end
		end
		local members = items[1]:Choices()
		out.zoneCalls = {}
		for k = 1, #members do
			local member = members[k]
			if member ~= OFF then
				local n = #out.zoneCalls + 1
				local label = { attributes = { text = items[1]:ChoiceLabel(member), textColor = DIM, textSize = 12 * PX } }
				local function slot(game, me)
					game.ui:Text(label)
					Chips(game, me, member)
				end
				out.zoneCalls[n] = { key = member, attributes = {
					columns = 1, gap = 6 * PX, padding = 8 * PX, xAlign = ALIGN[n] or "start", yAlign = "start",
					border = n > 1 and DIVIDER or nil, OnDrop = drop(member),
				}, slots = { default = slot } }
			end
		end
		out.zonesCall = { attributes = { columns = #out.zoneCalls, background = BOX_FILL, border = BRONZE },
			slots = { default = Zones } }
		out.poolLabel = { attributes = { text = items[1]:ChoiceLabel(OFF), textColor = DIM, textSize = 13 * PX } }
		local function pool(game, me)
			Chips(game, me, OFF)
		end
		out.poolCall = { attributes = { columns = 1, gap = 6 * PX, padding = 8 * PX, background = POOL_FILL,
			border = POOL_EDGE, OnDrop = drop(OFF) }, slots = { default = pool } }
		out.root = { attributes = { columns = 1, gap = 8 * PX }, slots = { default = Parts } }
		return out
	end,

	Render = function(game, self)
		game.ui:Box(self.root)
	end,
})
