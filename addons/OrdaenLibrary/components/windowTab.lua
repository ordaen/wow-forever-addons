-- WindowTab (design controls/window, TabbedWindow's tabs): one of a window's tabs on its top line, framed with the
-- body's own metal (frame.tab: the small frame's top and sides, its top corners mitred like the body's). The open one
-- stands over the body, its wood running down over the body's top line, so its sides meet that line; its title in
-- gold. A closed one stands 5 px lower, behind the body (the body's line runs in front of it), darker, its title dim.
-- An icon fills the tab's left end inside the frame, with the frame's line on its right (and its bottom, on the body's
-- line, for the open one); the title is centred in what's left, with an optional second line under it (a profession's
-- skill). The frame is drawn inside the tab's box (border-box), so nothing is drawn outside it.
--
-- Attributes: `window` (the Window it belongs to: its `title`, or its `tabs`, each { title, desc, icon }, and
-- `selected`), `index` (this tab's in them), `height` (the open tab's, UI units: from the window's top to the inner
-- side of the body's top line; a closed one is 5 px less), `under` (the layer under the body: it shows the tab only
-- while closed; else only while open), `OnPick` (a click on a closed tab), `OnDragStart`, `OnDrag`, `OnDragStop`
-- (dragging the tab: Window's move).
local Define = import("@ordaen/define")

local PX = 1 / 1.2 -- UI units a design px is at the user's scale (a 1440p screen)
local DROP = 5 * PX -- a closed tab stands this much lower
local TITLE_OPEN = { 1, 0.82, 0, 1 } -- #ffd100
local TITLE_CLOSED = { 0.702, 0.651, 0.565, 1 } -- #b3a690
local DESC = { 0.561, 0.518, 0.439, 1 } -- #8f8470
local SHADE = { 0.6, 0.6, 0.6, 1 } -- a closed tab's wood and icon, darker
local TITLE_SIZE, DESC_SIZE = 15 * PX, 11 * PX
local SHADOW = { color = { 0, 0, 0, 0.8 }, x = 1 * PX, y = -1 * PX }
local LABEL_PAD = 10 * PX
local MIN_TAB = 120 * PX -- the tab's smallest width; wider as its label needs

local WOOD = Define.Theme.window.wood
local FRAME = Define.Theme.frame.tab
local ICON_FRAME, ICON_FRAME_OPEN = Define.Theme.frame.tabIcon, Define.Theme.frame.tabIconOpen

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
local function Tint(self)
	return not Open(self) and SHADE or nil
end
-- the tab's height, its frame's art included
local function Height(self)
	return Open(self) and self.attributes.height or self.attributes.height - DROP
end
-- the height it's given: a framed box grows by its art's reach (border-box), so less that
local function GivenHeight(self)
	return Height(self) - self.reachTop
end
-- the icon: as tall as the tab inside its frame's top, square; given less its own frame's reach (right, and bottom on
-- the open tab)
local function IconSide(self)
	return Height(self) - self.frameTop
end
local function IconWidth(self)
	return IconSide(self) - self.iconReachRight
end
local function IconHeight(self)
	return IconSide(self) - (Open(self) and self.iconReachBottom or 0)
end
local function IconFrame(self)
	return Open(self) and ICON_FRAME_OPEN or ICON_FRAME
end

-- Window draws its tabs twice, the closed ones under the body (`under`: the body's line runs over them) and the open
-- one over it; each layer shows only its own, the other's kept in place unseen (a box's opacity doesn't reach the
-- texts it draws, so the texts take an unseen colour too). A closed tab is picked on the layer it shows on (a box at
-- opacity 0 takes no mouse).
local UNSEEN = { 0, 0, 0, 0 }
local UNSEEN_SHADOW = { color = UNSEEN, x = 0, y = 0 }
local function Shown(self)
	return Open(self) ~= (self.attributes.under == true)
end
local function Opacity(self)
	return Shown(self) and 1 or 0
end
local function Click(self)
	return self.attributes.under and not Open(self) and self.attributes.OnPick or nil
end
local function TitleColor(self)
	return not Shown(self) and UNSEEN or Open(self) and TITLE_OPEN or TITLE_CLOSED
end
local function DescColor(self)
	return Shown(self) and DESC or UNSEEN
end
local function TextShadow(self)
	return Shown(self) and SHADOW or UNSEEN_SHADOW
end

local function Label(game, self)
	game.ui:Text({ attributes = { text = Title(self), textSize = TITLE_SIZE, wrap = false,
		textColor = TitleColor(self), textShadow = TextShadow(self) } })
	if Tab(self).desc then
		game.ui:Text({ attributes = { text = Tab(self).desc, textSize = DESC_SIZE, wrap = false,
			textColor = DescColor(self), textShadow = TextShadow(self) } })
	end
end

local LABEL = { rows = "auto", xAlign = "center", yAlign = "center", gap = 1 * PX }

local function Parts(game, self)
	if Tab(self).icon then
		game.ui:Box({ attributes = { width = IconWidth(self), height = IconHeight(self), background = Tab(self).icon,
			tint = Tint(self), border = IconFrame(self) } })
	end
	game.ui:Box({ attributes = LABEL, slots = { default = Label } })
end

-- the label's room: LABEL_PAD each side of it (the icon flush with the frame)
local PADDING_ICON = { 0, LABEL_PAD, 0, 0 }
local PADDING_TITLE = { 0, LABEL_PAD, 0, LABEL_PAD }
local COLUMNS_ICON, COLUMNS_TITLE = { "auto", "1fr" }, { "1fr" }
local function Padding(self)
	return Tab(self).icon and PADDING_ICON or PADDING_TITLE
end
local function Columns(self)
	return Tab(self).icon and COLUMNS_ICON or COLUMNS_TITLE
end

return Define.Component({
	Setup = function()
		-- the frame's top: its width and how far its art stands past its line, inside the box (border-box)
		local frame, icon = Define.ThemeValue(FRAME), Define.ThemeValue(ICON_FRAME_OPEN)
		local reachTop = frame.reach[1] * frame.scale
		return { width = { fit = "min", min = MIN_TAB }, reachTop = reachTop, frameTop = frame.width + reachTop,
			iconReachRight = icon.reach[2] * icon.scale, iconReachBottom = icon.reach[3] * icon.scale }
	end,

	Render = function(game, self)
		game.ui:Box({ attributes = { width = self.width, height = GivenHeight(self), border = FRAME, background = WOOD,
			tint = Tint(self), padding = Padding(self), columns = Columns(self), gap = LABEL_PAD,
			opacity = Opacity(self), OnClick = Click(self), OnDragStart = self.attributes.OnDragStart,
			OnDrag = self.attributes.OnDrag, OnDragStop = self.attributes.OnDragStop }, slots = { default = Parts } })
	end,
})
