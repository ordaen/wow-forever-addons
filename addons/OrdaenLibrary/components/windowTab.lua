-- WindowTab (design controls/window, TabbedWindow's tabs): one of a window's tabs on its top line. The open one stands
-- on the line, its wood running into the body, its title in gold; a closed one stands 5 px lower, behind the line,
-- darker, its title dim. An icon fills the tab's left end (the open one's corner rounded like the tab's); the title
-- is centred in what's left, with an optional second line under it (a profession's skill).
--
-- Attributes: `window` (the Window it belongs to: its `tabs`, each { title, desc, icon }, and `selected`), `index`
-- (this tab's in them), `height` (the open tab's, UI units: the window's line; a closed one is 5 px less), `OnPick` (a
-- click on a closed tab).
local Define = import("@ordaen/define")

local PX = 1 / 1.2 -- UI units a design px is at the user's scale (a 1440p screen)
local CORNER = 14 * PX -- the tab's top corners
local FLARE = 8 * PX -- the open tab's right side curving out into the body's line
local EDGE = 2.5 * PX -- the tab's rim inside its bounds
local DROP = 5 * PX -- a closed tab stands this much lower
local ART_TOP, ART_PAST = -12 * PX, 10 * PX -- the tab art from above the tab to past its right
local ART_BELOW = 10 * PX -- and below the line
local TITLE_OPEN = { 1, 0.82, 0, 1 } -- #ffd100
local TITLE_CLOSED = { 0.702, 0.651, 0.565, 1 } -- #b3a690
local DESC = { 0.561, 0.518, 0.439, 1 } -- #8f8470
local SHADE = { 0.6, 0.6, 0.6, 1 } -- a closed tab's art and wood, darker
local TITLE_SIZE, DESC_SIZE = 15 * PX, 11 * PX
local SHADOW = { color = { 0, 0, 0, 0.8 }, x = 1 * PX, y = -1 * PX }
local LABEL_PAD = 10 * PX

local WOOD = Define.Theme.window.wood

-- the window's attributes are signals: read them as such (the build turns only this component's own into reads)
local function Tab(self)
	local tabs = self.attributes.window.attributes.tabs:Get()
	return tabs and tabs[self.attributes.index] or {}
end
local function Open(self)
	return self.attributes.window.attributes.selected:Get() == self.attributes.index
end
-- a closed tab is DROP shorter: the tab row lines its tabs up at the bottom, so it stands lower
local function Height(self)
	return Open(self) and self.attributes.height or self.attributes.height - DROP
end
local function Tint(self)
	return not Open(self) and SHADE or nil
end
-- the open tab's art reaches below the line, its rim running into the body's; a closed tab's stops at its bottom
local function ArtBelow(self)
	return Open(self) and -ART_BELOW or 0
end
local function IconMask(self)
	return Open(self) and Define.Theme.ctl.tabIconOpen or Define.Theme.ctl.tabIcon
end
local function IconSide(self)
	return Tab(self).icon and Height(self) - 3 * PX or 0
end

local function Label(game, self)
	game.ui:Text({ attributes = { text = Tab(self).title, textSize = TITLE_SIZE, wrap = false,
		textColor = Open(self) and TITLE_OPEN or TITLE_CLOSED, textShadow = SHADOW } })
	if Tab(self).desc then
		game.ui:Text({ attributes = { text = Tab(self).desc, textSize = DESC_SIZE, wrap = false, textColor = DESC,
			textShadow = SHADOW } })
	end
end

local function Parts(game, self)
	game.ui:Box({ attributes = { position = "absolute", left = 0, top = 0, width = CORNER, bottom = 0,
		background = WOOD, tint = Tint(self), mask = Define.Theme.ctl.tabCornerL } })
	game.ui:Box({ attributes = { position = "absolute", left = CORNER, right = CORNER, top = 0, bottom = 0,
		background = WOOD, tint = Tint(self) } })
	game.ui:Box({ attributes = { position = "absolute", right = 0, top = 0, width = CORNER, bottom = 0,
		background = WOOD, tint = Tint(self), mask = Define.Theme.ctl.tabCornerR } })
	if Open(self) then
		game.ui:Box({ attributes = { position = "absolute", right = EDGE - FLARE, bottom = -3 * PX, width = FLARE,
			height = FLARE + 3 * PX, background = WOOD, mask = Define.Theme.ctl.tabFlareR } })
	end
	-- the icon under the art, so the tab's rim lies over its edge
	if Tab(self).icon then
		game.ui:Box({ attributes = { position = "absolute", left = 3 * PX, top = 3 * PX, width = IconSide(self),
			height = IconSide(self), background = Tab(self).icon, tint = Tint(self), mask = IconMask(self) } })
	end
	game.ui:Box({ attributes = { position = "absolute", left = 0, right = -ART_PAST, top = ART_TOP,
		bottom = ArtBelow(self), background = Define.Theme.ctl.tab, tint = Tint(self) } })
	Label(game, self)
end
-- the left padding: the icon and the label's own
local function Padding(self)
	return { 0, LABEL_PAD, 0, IconSide(self) + 3 * PX + LABEL_PAD }
end

return Define.Component({
	Render = function(game, self)
		game.ui:Box({ attributes = { height = Height(self), padding = Padding(self), rows = "auto", xAlign = "center",
			yAlign = "center", gap = 1 * PX, OnClick = not Open(self) and self.attributes.OnPick or nil },
			slots = { default = Parts } })
	end,
})
