-- Window (design controls/window: the tabbed window, TabbedWindow): a window whose open tab is its title. The small
-- metal frame round its body, the character sheet's wood as one picture across the body and the tab, the tab standing
-- on the body's top line at its left, its rim running down into the frame's left line and out along the top line on
-- its right, the title in gold. Centred on the screen at first; dragging its tab row moves it (design windows/:
-- dragged by its tab row), and Escape closes it as it closes Blizzard's windows. Sizes as the design draws them at the
-- user's scale (a px is 1/1.2 UI units).
--
-- In the body's top-right corner, while the cursor is over the window: full screen (and back) and close, a joined group
-- of plates under the frame's line.
--
-- Attributes: `title` (text), `width`, `height` (the body's, UI units), `x`, `y` (where it sits: its centre's offset
-- from the screen's, UI units, y down; 0, 0 when unset), `OnMoved(x, y)` (called when a drag ends: its owner keeps
-- the place), `OnClose` (called by the close button and by Escape). Slot `default`: the body's content, inside its
-- padding.
local Define = import("@ordaen/define")

local PX = 1 / 1.2 -- UI units a design px is at the user's scale (a 1440p screen)
local TAB = 36 * PX -- the tab row above the body
local LINE = 42 * PX -- the body's top line, from the window's top
local CORNER = 14 * PX -- the tab's top corners
local FLARE = 8 * PX -- the open tab's right side curving out into the body's line
local EDGE = 2.5 * PX -- the tab's rim inside its bounds
local ROW_X = 1 * PX -- the tab row's start: the tab's rim on the card's left line
local INSET = 3 * PX -- the body's wood inside the metal
-- the body's content: the design's padding (14 12 12) inside the wood's inset
local PADDING = { 14 * PX + INSET, 12 * PX + INSET, 12 * PX + INSET, 12 * PX + INSET }
-- the tab: its text and 16 px each side; its art from 12 px above it to 10 px below the line, 10 px past its right
local TAB_PAD = 16 * PX
local ART_TOP, ART_H, ART_PAST = -12 * PX, 64 * PX, 10 * PX
local TITLE = { 1, 0.82, 0, 1 } -- #ffd100
local TITLE_SIZE = 15 * PX
local CENTER = { point = "CENTER", relativePoint = "CENTER" }

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

local function Body(game, self)
	game.ui:Slot("default")
	if self.state.hovered then
		game.ui:Box({ attributes = CORNER_GROUP, slots = { default = CornerButtons } })
	end
end

local function Parts(game, self)
	game.ui:Box({ attributes = { position = "absolute", left = 0, right = 0, top = TAB, bottom = 0,
		border = Define.Theme.frame.small, background = WOOD, padding = PADDING, columns = 1, hoverWithin = true,
		OnEnter = self.enter, OnLeave = self.leave }, slots = { default = Body } })
	-- the tab row: the whole row above the body moves the window, the tab over it too
	game.ui:Box({ attributes = { position = "absolute", left = 0, right = 0, top = 0, height = TAB,
		OnDragStart = self.dragStart, OnDrag = self.drag, OnDragStop = self.dragStop } })
	game.ui:Box({ attributes = { position = "absolute", left = ROW_X, top = 0, height = LINE + 4 * PX,
		padding = { 0, TAB_PAD, 0, TAB_PAD }, yAlign = "center", columns = 1, OnDragStart = self.dragStart,
		OnDrag = self.drag, OnDragStop = self.dragStop }, slots = { default = TabParts } })
end

-- where the window sits: centred and moved by dragging its tab, or the whole screen
local function Anchor(_, self)
	return not self.state.full and CENTER or nil
end
local function Left(_, self)
	return self.state.full and 0 or self.state.x
end
local function Top(_, self)
	return self.state.full and 0 or self.state.y
end
local function Edge(_, self)
	return self.state.full and 0 or nil
end
local function Width(_, self)
	return not self.state.full and self.attributes.width or nil
end
local function Height(_, self)
	return not self.state.full and TAB + self.attributes.height or nil
end

return Define.Component({
	Setup = function(_, self)
		Define.Ephemeral({
			x = { type = "number", default = Define.Peek(self.attributes.x) or 0 },
			y = { type = "number", default = Define.Peek(self.attributes.y) or 0 },
			full = { type = "boolean", default = false },
			hovered = { type = "boolean", default = false },
		})
		-- where the window was and where the cursor took the tab when the drag began: the window follows the cursor
		local x0, y0, grabX, grabY = 0, 0, 0, 0
		return {
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
