-- WindowTab (design controls/window, TabbedWindow's tabs): one of a window's tabs on its top line. The open one stands
-- on the line, its wood running into the body, its title in gold; a closed one stands 5 px lower, behind the line,
-- darker, its title dim. An icon fills the tab's left end (the open one's corner rounded like the tab's); the title
-- is centred in what's left, with an optional second line under it (a profession's skill).
--
-- Its box holds all of its art: the art stands `above` the tab and `past` its right (Window's tab row sets both), and the
-- open tab's runs ART_BELOW under it into the body's line; nothing is drawn outside the box.
--
-- Attributes: `window` (the Window it belongs to: its `title`, or its `tabs`, each { title, desc, icon }, and
-- `selected`), `index` (this tab's in them), `height` (the open tab's, UI units, from its top to 4 px under the line; a
-- closed one is 5 px less), `above`, `past` (the art's reach above the tab and past its right), `OnPick` (a click on a
-- closed tab), `OnDragStart`, `OnDrag`, `OnDragStop` (dragging the tab: Window's move).
local Define = import("@ordaen/define")

local PX = 1 / 1.2 -- UI units a design px is at the user's scale (a 1440p screen)
local CORNER = 14 * PX -- the tab's top corners
local FLARE = 8 * PX -- the open tab's right side curving out into the body's line
local EDGE = 2.5 * PX -- the tab's rim inside its bounds
local DROP = 5 * PX -- a closed tab stands this much lower
-- the open tab's art runs to 11 px below the line; the tab stands 4 px below it, so 7 px under the tab
local ART_BELOW = 7 * PX
local TITLE_OPEN = { 1, 0.82, 0, 1 } -- #ffd100
local TITLE_CLOSED = { 0.702, 0.651, 0.565, 1 } -- #b3a690
local DESC = { 0.561, 0.518, 0.439, 1 } -- #8f8470
local SHADE = { 0.6, 0.6, 0.6, 1 } -- a closed tab's art and wood, darker
local TITLE_SIZE, DESC_SIZE = 15 * PX, 11 * PX
local SHADOW = { color = { 0, 0, 0, 0.8 }, x = 1 * PX, y = -1 * PX }
local LABEL_PAD = 10 * PX

local WOOD = Define.Theme.window.wood

local NONE = {} -- a single-title window's tab: no icon, no second line

-- the window's attributes are signals: read them as such (the build turns only this component's own into reads). A
-- window with a `title` and no `tabs` is a tabbed window with that one tab, open.
local function Tab(self)
	local tabs = self.attributes.window.attributes.tabs:Get()
	return tabs and tabs[self.attributes.index] or NONE
end
local function Title(self)
	local tabs = self.attributes.window.attributes.tabs:Get()
	return tabs and tabs[self.attributes.index].title or self.attributes.window.attributes.title:Get()
end
local function Open(self)
	local window = self.attributes.window.attributes
	return window.tabs:Get() == nil or window.selected:Get() == self.attributes.index
end
-- where the tab's own parts start in its box: under the art's reach above it, a closed tab DROP lower (its bottom on the
-- open one's); and end: the open tab's art runs ART_BELOW under it
local function PartsTop(self)
	return self.attributes.above + (Open(self) and 0 or DROP)
end
local function PartsBottom(self)
	return Open(self) and ART_BELOW or 0
end
local function Tint(self)
	return not Open(self) and SHADE or nil
end
local function IconMask(self)
	return Open(self) and Define.Theme.ctl.tabIconOpen or Define.Theme.ctl.tabIcon
end
-- the tab's own height (a closed one DROP less)
local function TabHeight(self)
	return Open(self) and self.attributes.height or self.attributes.height - DROP
end
local function IconSide(self)
	return Tab(self).icon and TabHeight(self) - 3 * PX or 0
end
-- the art: from the box's top (a closed tab's DROP lower) to its bottom, its whole width
local function ArtTop(self)
	return Open(self) and 0 or DROP
end

local function Label(game, self)
	game.ui:Text({ attributes = { text = Title(self), textSize = TITLE_SIZE, wrap = false,
		textColor = Open(self) and TITLE_OPEN or TITLE_CLOSED, textShadow = SHADOW } })
	if Tab(self).desc then
		game.ui:Text({ attributes = { text = Tab(self).desc, textSize = DESC_SIZE, wrap = false, textColor = DESC,
			textShadow = SHADOW } })
	end
end

local function Parts(game, self)
	local top, bottom, right = PartsTop(self), PartsBottom(self), self.attributes.past
	game.ui:Box({ attributes = { position = "absolute", left = 0, top = top, width = CORNER, bottom = bottom,
		background = WOOD, tint = Tint(self), mask = Define.Theme.ctl.tabCornerL } })
	game.ui:Box({ attributes = { position = "absolute", left = CORNER, right = right + CORNER, top = top,
		bottom = bottom, background = WOOD, tint = Tint(self) } })
	game.ui:Box({ attributes = { position = "absolute", right = right, top = top, width = CORNER, bottom = bottom,
		background = WOOD, tint = Tint(self), mask = Define.Theme.ctl.tabCornerR } })
	if Open(self) then
		game.ui:Box({ attributes = { position = "absolute", right = right + EDGE - FLARE, bottom = ART_BELOW - 3 * PX,
			width = FLARE, height = FLARE + 3 * PX, background = WOOD, mask = Define.Theme.ctl.tabFlareR } })
	end
	-- the icon under the art, so the tab's rim lies over its edge
	if Tab(self).icon then
		game.ui:Box({ attributes = { position = "absolute", left = 3 * PX, top = top + 3 * PX, width = IconSide(self),
			height = IconSide(self), background = Tab(self).icon, tint = Tint(self), mask = IconMask(self) } })
	end
	game.ui:Box({ attributes = { position = "absolute", left = 0, right = 0, top = ArtTop(self), bottom = 0,
		background = Define.Theme.ctl.tab, tint = Tint(self) } })
	-- an open tab after the first opens into the body on its left too: the art's left rim, which runs down into the
	-- frame's left line on the first tab, is covered below the line with the tab's wood (its left flare isn't drawn)
	if Open(self) and self.attributes.index > 1 then
		game.ui:Box({ attributes = { position = "absolute", left = 0, width = 2 * EDGE, bottom = 0,
			height = ART_BELOW + 4 * PX, background = WOOD } })
	end
	Label(game, self)
end
-- the label sits in the tab: under the parts' top, over their bottom, the icon and the art's reach out of its sides
local function Padding(self)
	return { PartsTop(self), LABEL_PAD + self.attributes.past, PartsBottom(self), IconSide(self) + 3 * PX + LABEL_PAD }
end
-- the box: the art above the tab, the tab (a closed one's parts DROP lower in it, its bottom on the open one's) and
-- under it for the open one
local function Height(self)
	return self.attributes.above + self.attributes.height + PartsBottom(self)
end

return Define.Component({
	Render = function(game, self)
		game.ui:Box({ attributes = { height = Height(self), padding = Padding(self), rows = "auto", xAlign = "center",
			yAlign = "center", gap = 1 * PX, OnClick = not Open(self) and self.attributes.OnPick or nil,
			OnDragStart = self.attributes.OnDragStart, OnDrag = self.attributes.OnDrag,
			OnDragStop = self.attributes.OnDragStop },
			slots = { default = Parts } })
	end,
})
