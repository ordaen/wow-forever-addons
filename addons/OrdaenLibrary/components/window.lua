-- Window (design controls/window: the tabbed window, TabbedWindow): a window whose open tab is its title. The small
-- metal frame round its body, the character sheet's wood as one picture across the body and the tab, the tab standing
-- on the body's top line at its left, its rim running down into the frame's left line and out along the top line on
-- its right, the title in gold. Centred on the screen; dragging its tab moves it. Sizes as the design draws them at
-- the user's scale (a px is 1/1.2 UI units).
--
-- Attributes: `title` (text), `width`, `height` (the body's, UI units). Slot `default`: the body's content, inside its
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
local BODY = { position = "absolute", left = 0, right = 0, top = TAB, bottom = 0, border = Define.Theme.frame.small,
	background = WOOD, padding = PADDING, columns = 1 }
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

local function Content(game)
	game.ui:Slot("default")
end

local function Parts(game, self)
	game.ui:Box({ attributes = BODY, slots = { default = Content } })
	game.ui:Box({ attributes = { position = "absolute", left = ROW_X, top = 0, height = LINE + 4 * PX,
		padding = { 0, TAB_PAD, 0, TAB_PAD }, yAlign = "center", columns = 1, OnDragStart = self.dragStart,
		OnDrag = self.drag }, slots = { default = TabParts } })
end

-- where the window sits: its offset from the screen's centre, moved by dragging its tab
local function Left(_, self)
	return self.state.x
end
local function Top(_, self)
	return self.state.y
end

return Define.Component({
	Setup = function(_, self)
		Define.Ephemeral({ x = { type = "number", default = 0 }, y = { type = "number", default = 0 } })
		-- where the window was and where the cursor took the tab when the drag began: the window follows the cursor
		local x0, y0, grabX, grabY = 0, 0, 0, 0
		return {
			dragStart = function(x, y)
				x0, y0, grabX, grabY = Define.Peek(self.state.x), Define.Peek(self.state.y), x, y
			end,
			drag = function(x, y)
				self.state.x = x0 + x - grabX
				self.state.y = y0 + y - grabY
			end,
		}
	end,

	Render = function(game, self)
		game.ui:Box({ attributes = { position = "absolute", anchor = CENTER, left = Left(game, self), top = Top(game, self),
			width = self.attributes.width, height = TAB + self.attributes.height, artOrigin = true },
			slots = { default = Parts } })
	end,
})
