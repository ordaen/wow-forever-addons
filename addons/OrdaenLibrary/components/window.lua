-- Window (design controls/window: the tabbed window, TabbedWindow): a window whose open tab is its title. The small
-- metal frame round its body, the character sheet's wood as one picture across the body and the tab, the tab standing
-- on the body's top line at its left, its rim running down into the frame's left line and out along the top line on
-- its right, the title in gold. Centred on the screen at first; dragging its tab row moves it (design windows/:
-- dragged by its tab row), and Escape closes it as it closes Blizzard's windows. Sizes as the design draws them at the
-- user's scale (a px is 1/1.2 UI units). Its grip in the bottom-right corner resizes it (Blizzard's own grip art,
-- the chat window's), its top-left corner staying where it is; the content lays itself out at the new size.
--
-- In the body's top-right corner, while the cursor is over the window: full screen (and back) and close, a joined group
-- of plates under the frame's line.
--
-- Attributes: `title` (text: one tab, the window's name), or `tabs` (several: each { title, desc, icon }, a WindowTab),
-- `selected` (the open one's index) and `OnSelect(index)`; `width`, `height` (the body's, UI units), `x`, `y` (where it
-- sits: its centre's offset from the screen's, UI units, y down; 0, 0 when unset), `OnMoved(x, y)` (called when a drag
-- ends: its owner keeps the place), `minWidth`, `minHeight` (the smallest body; 320 x 200 px unless given),
-- `maxWidth`, `maxHeight` (the largest), `OnResized(width, height)` (called when a resize ends, the body's size),
-- `OnClose` (called by the close button and by Escape). Slot `default`: the body's content, inside its padding.
local Define = import("@ordaen/define")

local PX = 1 / 1.2 -- UI units a design px is at the user's scale (a 1440p screen)
local TAB = 36 * PX -- the tab row above the body
local LINE = 42 * PX -- the body's top line, from the window's top
local CORNER = 14 * PX -- the tab's top corners
local FLARE = 8 * PX -- the open tab's right side curving out into the body's line
local EDGE = 2.5 * PX -- the tab's rim inside its bounds
local ROW_X = 2 * PX -- the tab row's start: the tab's rim on the card's left line (measured in game: the metal's
-- brightest column is 2 px in from the card's edge)
local INSET = 3 * PX -- the body's wood inside the metal
-- the body's content: the design's padding (14 12 12) inside the wood's inset
local PADDING = { 14 * PX + INSET, 12 * PX + INSET, 12 * PX + INSET, 12 * PX + INSET }
-- the tab: its text and 16 px each side; its art from 12 px above it to 10 px below the line, 10 px past its right
local TAB_PAD = 16 * PX
local ART_TOP, ART_H, ART_PAST = -12 * PX, 64 * PX, 10 * PX
local TITLE = { 1, 0.82, 0, 1 } -- #ffd100
local TITLE_SIZE = 15 * PX
-- placed by its top-left corner from the screen's centre: x and y say where its centre is, and the corner is half
-- its size from there. A resize moves the centre by half the size change, so the corner's offset stays exactly the
-- same and snaps to the same pixel (by its centre, a size rounded to pixels would move it a pixel back and forth)
local FROM_CENTER = { point = "TOPLEFT", relativePoint = "CENTER" }

local WOOD = Define.Theme.window.wood
-- the open tab, over the body (drawn after it): its wood in three parts (the corners masked round), the right flare's
-- wood, the art, the title in its flow (the tab is as wide as the title and its padding)
local WOOD_L = { position = "absolute", left = 0, top = 0, width = CORNER, bottom = 0, background = WOOD,
	mask = Define.Theme.ctl.tabCornerL }
local WOOD_M = { position = "absolute", left = CORNER, right = CORNER, top = 0, bottom = 0, background = WOOD }
local WOOD_R = { position = "absolute", right = 0, top = 0, width = CORNER, bottom = 0, background = WOOD,
	mask = Define.Theme.ctl.tabCornerR }
local FLARE_R = { position = "absolute", right = EDGE - FLARE, top = LINE - FLARE, width = FLARE,
	height = FLARE + 3 * PX, background = WOOD, mask = Define.Theme.ctl.tabFlareR }
local ART = { position = "absolute", left = 0, right = -ART_PAST, top = ART_TOP, height = ART_H,
	background = Define.Theme.ctl.tab }

-- the tab row's height: taller when a tab has a second line (TabbedWindow: 50 px with a description, else 36)
local TAB_DESC = 50 * PX
local function TabH(self)
	local tabs = self.attributes.tabs
	if tabs then
		for i = 1, #tabs do
			if tabs[i].desc then
				return TAB_DESC
			end
		end
	end
	return TAB
end
local function LineH(self)
	return TabH(self) + (LINE - TAB)
end
-- the tab row: one auto column per tab, made once per count
local tabColumns = setmetatable({}, { __index = function(t, n)
	local list = {}
	for i = 1, n do
		list[i] = "auto"
	end
	t[n] = list
	return list
end })
local function TabRow(game, self)
	local tabs, height = self.attributes.tabs, LineH(self) + 4 * PX
	for i = 1, #tabs do
		local call = self.tabCalls[i]
		call.attributes.height = height
		game.ui:WindowTab(call)
	end
end

local function TabParts(game, self)
	game.ui:Box({ attributes = WOOD_L })
	game.ui:Box({ attributes = WOOD_M })
	game.ui:Box({ attributes = WOOD_R })
	game.ui:Box({ attributes = FLARE_R })
	game.ui:Box({ attributes = ART })
	game.ui:Text({ attributes = { text = self.attributes.title, textColor = TITLE, textSize = TITLE_SIZE,
		textShadow = { color = { 0, 0, 0, 0.7 }, x = 1 * PX, y = -1 * PX }, wrap = false } })
end

-- the corner group: 5.5 px down, its right end at the frame's right line's inner edge (5 px in; the design's group
-- reaches 1 px in, under the line, which draws over it), the full-screen plate 5 px into its art (the group's edge),
-- close after it; the art reaches 5 px below the plates
local CORNER_GROUP = { position = "absolute", top = 5.5 * PX, right = 5 * PX, width = (5 + 30 + 28) * PX,
	height = 32 * PX, overflow = "clip" }

local function FullArt(_, self)
	return self.state.full and Define.Theme.ctl.cornerContract or Define.Theme.ctl.cornerExpand
end

local function CornerButtons(game, self)
	game.ui:Box({ attributes = { position = "absolute", left = 0, top = 0, width = 64 * PX, height = 32 * PX,
		background = FullArt(game, self), OnClick = self.toggleFull } })
	game.ui:Box({ attributes = { position = "absolute", left = 35 * PX, top = 0, width = 64 * PX, height = 32 * PX,
		background = Define.Theme.ctl.cornerClose, OnClick = self.close } })
end

-- the resize grip: 16 px, 2 px in from the body's bottom-right corner, over the content
local GRIP = { attributes = { position = "absolute", right = 2 * PX, bottom = 2 * PX, width = 16 * PX,
	height = 16 * PX, background = { default = Define.Theme.ctl.grip, hover = Define.Theme.ctl.gripHover,
		pressed = Define.Theme.ctl.gripDown } } }

local function Body(game, self)
	game.ui:Slot("default")
	if self.state.hovered then
		game.ui:Box({ attributes = CORNER_GROUP, slots = { default = CornerButtons } })
	end
	if not self.state.full then
		game.ui:Box(self.grip)
	end
end

local function Parts(game, self)
	game.ui:Box({ attributes = { position = "absolute", left = 0, right = 0, top = TabH(self), bottom = 0,
		border = Define.Theme.frame.small, background = WOOD, padding = PADDING, columns = 1, hoverWithin = true,
		OnEnter = self.enter, OnLeave = self.leave }, slots = { default = Body } })
	-- the tab row: the whole row above the body moves the window, the tab over it too
	game.ui:Box({ attributes = { position = "absolute", left = 0, right = 0, top = 0, height = TabH(self),
		OnDragStart = self.dragStart, OnDrag = self.drag, OnDragStop = self.dragStop } })
	if self.attributes.tabs then
		game.ui:Box({ attributes = { position = "absolute", left = ROW_X, top = 0, height = LineH(self) + 4 * PX,
			columns = tabColumns[#self.attributes.tabs], gap = 12 * PX, yAlign = "end" }, slots = { default = TabRow } })
		return
	end
	game.ui:Box({ attributes = { position = "absolute", left = ROW_X, top = 0, height = LINE + 4 * PX,
		padding = { 0, TAB_PAD, 0, TAB_PAD }, yAlign = "center", columns = 1, OnDragStart = self.dragStart,
		OnDrag = self.drag, OnDragStop = self.dragStop }, slots = { default = TabParts } })
end

-- where the window sits: centred and moved by dragging its tab, or the whole screen
local function Anchor(_, self)
	return not self.state.full and FROM_CENTER or nil
end
local function Left(_, self)
	return self.state.full and 0 or self.state.x - self.state.w / 2
end
-- the smallest body when the window names none: room for the tab row and a few lines
local MIN_W, MIN_H = 320 * PX, 200 * PX

local function Top(_, self)
	return self.state.full and 0 or self.state.y - (TabH(self) + self.state.h) / 2
end
local function Edge(_, self)
	return self.state.full and 0 or nil
end
local function Width(_, self)
	return not self.state.full and self.state.w or nil
end
local function Height(_, self)
	return not self.state.full and TabH(self) + self.state.h or nil
end

return Define.Component({
	Setup = function(_, self)
		Define.Ephemeral({
			x = { type = "number", default = Define.Peek(self.attributes.x) or 0 },
			y = { type = "number", default = Define.Peek(self.attributes.y) or 0 },
			w = { type = "number", default = Define.Peek(self.attributes.width) or 0 },
			h = { type = "number", default = Define.Peek(self.attributes.height) or 0 },
			full = { type = "boolean", default = false },
			hovered = { type = "boolean", default = false },
		})
		-- where the window was and where the cursor took the tab when the drag began: the window follows the cursor
		local x0, y0, grabX, grabY = 0, 0, 0, 0
		local w0, h0 = 0, 0 -- the body's size when a resize began
		local function sizeStart(x, y)
			x0, y0, grabX, grabY = Define.Peek(self.state.x), Define.Peek(self.state.y), x, y
			w0, h0 = Define.Peek(self.state.w), Define.Peek(self.state.h)
		end
		-- the grip follows the cursor; the window is placed by its centre, so the centre moves half as far and the
		-- top-left corner stays
		local function size(x, y)
			local w = math.min(self.attributes.maxWidth or math.huge,
				math.max(self.attributes.minWidth or MIN_W, w0 + x - grabX))
			local h = math.min(self.attributes.maxHeight or math.huge,
				math.max(self.attributes.minHeight or MIN_H, h0 + y - grabY))
			self.state.w = w
			self.state.h = h
			self.state.x = x0 + (w - w0) / 2
			self.state.y = y0 + (h - h0) / 2
		end
		local function sizeStop()
			local resized, moved = self.attributes.OnResized, self.attributes.OnMoved
			if resized then
				resized(Define.Peek(self.state.w), Define.Peek(self.state.h))
			end
			if moved then
				moved(Define.Peek(self.state.x), Define.Peek(self.state.y))
			end
		end
		local grip = GRIP.attributes
		-- each tab's call, made once per index; a click on a closed one selects it
		local tabCalls = setmetatable({}, { __index = function(t, i)
			local call = { key = i, attributes = { window = self, index = i, height = TAB, OnPick = function()
				local fn = self.attributes.OnSelect
				if fn then
					fn(i)
				end
			end } }
			t[i] = call
			return call
		end })
		return {
			tabCalls = tabCalls,
			grip = { attributes = { position = grip.position, right = grip.right, bottom = grip.bottom,
				width = grip.width, height = grip.height, background = grip.background, OnDragStart = sizeStart,
				OnDrag = size, OnDragStop = sizeStop } },
			dragStart = function(x, y)
				x0, y0, grabX, grabY = Define.Peek(self.state.x), Define.Peek(self.state.y), x, y
			end,
			drag = function(x, y)
				if Define.Peek(self.state.full) then
					return
				end
				self.state.x = x0 + x - grabX
				self.state.y = y0 + y - grabY
			end,
			dragStop = function()
				local fn = self.attributes.OnMoved
				if fn and not Define.Peek(self.state.full) then
					fn(Define.Peek(self.state.x), Define.Peek(self.state.y))
				end
			end,
			enter = function()
				self.state.hovered = true
			end,
			leave = function()
				self.state.hovered = false
			end,
			toggleFull = function()
				self.state.full = not Define.Peek(self.state.full)
			end,
			close = function()
				local fn = self.attributes.OnClose
				if fn then
					fn()
				end
			end,
		}
	end,

	Render = function(game, self)
		game.ui:Box({ attributes = { position = "absolute", anchor = Anchor(game, self), left = Left(game, self),
			top = Top(game, self), right = Edge(game, self), bottom = Edge(game, self), width = Width(game, self),
			height = Height(game, self), artOrigin = true, OnEscape = self.close }, slots = { default = Parts } })
	end,
})
