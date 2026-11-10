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
-- `OnClose` (called by the close button and by Escape). `window`: the module's window (`self.windows.main`, design
-- development/framework/module «Windows») in place of x, y, width, height, OnMoved, OnResized and OnClose: it starts
-- where the player left it, keeps where a move or resize ends, and closes through the window. Slot `default`: the
-- body's content, inside its padding.
local Define = import("@ordaen/define")

local PX = 1 / 1.2 -- UI units a design px is at the user's scale (a 1440p screen)
-- the tab art (WindowTab) stands 11 px above the tab and 10 px past its right; the window's box holds it
local ART_ABOVE, ART_PAST = 11 * PX, 10 * PX
local TAB = 36 * PX -- the tab row above the body
local LINE = 42 * PX -- the body's top line, from the tab's top
local FRAME = Define.Theme.frame.small -- the body's metal
-- the tabs stand on the metal's line: the art reaches past it (border-box: inside the body's box) by reach x scale on
-- each side, so the row starts that far in on the left, plus RIM to the art's brightest column, where the tab's rim
-- meets it; and that far down on the top
local RIM = 2 * PX
local function Reach()
	local frame = Define.ThemeValue(FRAME)
	return frame.reach[1] * frame.scale, frame.reach[4] * frame.scale
end
local function RowX()
	local _, left = Reach()
	return left + RIM
end
local function RowY()
	local top = Reach()
	return top
end
local INSET = 3 * PX -- the body's wood inside the metal
-- the body's content: the design's padding (14 12 12) inside the wood's inset
local PADDING = { 14 * PX + INSET, 12 * PX + INSET, 12 * PX + INSET, 12 * PX + INSET }
-- placed by its top-left corner from the screen's centre: x and y say where its centre is, and the corner is half
-- its size from there. A resize moves the centre by half the size change, so the corner's offset stays exactly the
-- same and snaps to the same pixel (by its centre, a size rounded to pixels would move it a pixel back and forth)
local FROM_CENTER = { point = "TOPLEFT", relativePoint = "CENTER" }

local WOOD = Define.Theme.window.wood

-- the tab row's height: taller when a tab has a second line (TabbedWindow: 50 px with a description, else 36)
local TAB_DESC = 50 * PX
local function TabH(self)
	local tabs = self.attributes.tabs
	if tabs then
		for i = 1, #tabs do
			if tabs[i].desc then
				return ART_ABOVE + TAB_DESC
			end
		end
	end
	return ART_ABOVE + TAB
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
-- how many tabs: a window with a title and no tabs has that one
local function Count(self)
	local tabs = self.attributes.tabs
	return tabs and #tabs or 1
end
-- the tabs, twice: the closed ones under the body, the open one over it (WindowTab `under`)
local function Tabs(game, self, calls)
	local height = LineH(self) - ART_ABOVE + 4 * PX -- from the tab's top to 4 px under the line
	for i = 1, Count(self) do
		local call = calls[i]
		call.attributes.height = height
		game.ui:WindowTab(call)
	end
end
local function TabsUnder(game, self)
	Tabs(game, self, self.underCalls)
end
local function TabsOver(game, self)
	Tabs(game, self, self.tabCalls)
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

-- the body: its content (the default slot: one box) fills it, so a module's 1fr and percentage rows and columns follow
-- the window's size; and the card never gets smaller than that content needs (min-content), whatever the size
local BODY_ROWS = { "1fr" }

-- 12 px between the tabs, the art past each one's sides in them
local function TabRowAttributes(self)
	return { position = "absolute", left = RowX(), top = RowY(), columns = tabColumns[Count(self)],
		gap = 12 * PX - 2 * ART_PAST, yAlign = "start" }
end

local function Parts(game, self)
	game.ui:Box({ attributes = TabRowAttributes(self), slots = { default = TabsUnder } })
	game.ui:Box({ attributes = { position = "absolute", left = 0, right = 0, top = TabH(self), bottom = 0,
		border = FRAME, background = WOOD, padding = PADDING, columns = 1, rows = BODY_ROWS,
		minContent = true, hoverWithin = true, OnEnter = self.enter, OnLeave = self.leave }, slots = { default = Body } })
	-- the tab row: the whole row above the body moves the window, the tab over it too
	game.ui:Box({ attributes = { position = "absolute", left = 0, right = 0, top = 0, height = TabH(self),
		OnDragStart = self.dragStart, OnDrag = self.drag, OnDragStop = self.dragStop } })
	game.ui:Box({ attributes = TabRowAttributes(self), slots = { default = TabsOver } })
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
		local window = Define.Peek(self.attributes.window)
		local wx, wy, ww, wh
		if window then
			wx, wy, ww, wh = window:Place()
		end
		Define.Ephemeral({
			x = { type = "number", default = wx or Define.Peek(self.attributes.x) or 0 },
			y = { type = "number", default = wy or Define.Peek(self.attributes.y) or 0 },
			w = { type = "number", default = ww or Define.Peek(self.attributes.width) or 0 },
			h = { type = "number", default = wh or Define.Peek(self.attributes.height) or 0 },
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
		-- the module's window keeps where the player left it
		local function keep()
			if window then
				window:SetPlace(Define.Peek(self.state.x), Define.Peek(self.state.y), Define.Peek(self.state.w),
					Define.Peek(self.state.h))
			end
		end
		local function sizeStop()
			keep()
			local resized, moved = self.attributes.OnResized, self.attributes.OnMoved
			if resized then
				resized(Define.Peek(self.state.w), Define.Peek(self.state.h))
			end
			if moved then
				moved(Define.Peek(self.state.x), Define.Peek(self.state.y))
			end
		end
		local grip = GRIP.attributes
		-- the tab row moves the window, its tabs too
		local function dragStart(x, y)
			x0, y0, grabX, grabY = Define.Peek(self.state.x), Define.Peek(self.state.y), x, y
		end
		local function drag(x, y)
			if Define.Peek(self.state.full) then
				return
			end
			self.state.x = x0 + x - grabX
			self.state.y = y0 + y - grabY
		end
		local function dragStop()
			if not Define.Peek(self.state.full) then
				keep()
			end
			local fn = self.attributes.OnMoved
			if fn and not Define.Peek(self.state.full) then
				fn(Define.Peek(self.state.x), Define.Peek(self.state.y))
			end
		end
		-- each tab's call, made once per index; a click on a closed one selects it
		local tabCalls = setmetatable({}, { __index = function(t, i)
			local call = { key = i, attributes = { window = self, index = i, height = TAB, above = ART_ABOVE,
				past = ART_PAST, OnDragStart = dragStart, OnDrag = drag, OnDragStop = dragStop, OnPick = function()
					local fn = self.attributes.OnSelect
					if fn then
						fn(i)
					end
				end } }
			t[i] = call
			return call
		end })
		-- the same tabs in the layer under the body: shown while closed, no input (the open layer's take it)
		local underCalls = setmetatable({}, { __index = function(t, i)
			local call = { key = i, attributes = { window = self, index = i, height = TAB, above = ART_ABOVE,
				past = ART_PAST, under = true } }
			t[i] = call
			return call
		end })
		return {
			tabCalls = tabCalls,
			underCalls = underCalls,
			grip = { attributes = { position = grip.position, right = grip.right, bottom = grip.bottom,
				width = grip.width, height = grip.height, background = grip.background, OnDragStart = sizeStart,
				OnDrag = size, OnDragStop = sizeStop } },
			dragStart = dragStart,
			drag = drag,
			dragStop = dragStop,
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
				if window then
					window:Close()
					return
				end
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
			height = Height(game, self), artOrigin = true, minContent = true, OnEscape = self.close }, slots = { default = Parts } })
	end,
})
