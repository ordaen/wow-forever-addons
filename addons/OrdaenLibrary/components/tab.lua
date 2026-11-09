-- Tab: one of a Tabs strip's tabs (design controls/page-tabs .pt): its name in the dim colour, lighter with a shade
-- under the cursor; picked, white on a darker shade, outlined in #3e2f1d with a 2 px light along its top inside.
--
-- Attributes: `label` (text), `selected` (boolean), `OnPick` (called by a click on a tab not picked).
local Define = import("@ordaen/define")

local PX = 1 / 1.2 -- UI units a design px is at the user's scale (a 1440p screen)
local TEXT = 15 * PX
local LINE = { 0.243, 0.184, 0.114, 1 } -- #3e2f1d
local NAME = { default = { 0.639, 0.592, 0.498, 1 }, hover = { 0.91, 0.863, 0.769, 1 } } -- --o-dim, --o-ink on hover
local WHITE = { 1, 1, 1, 1 }
local SHADE = { default = nil, hover = { 0, 0, 0, 0.2 } }
local PICKED = { 0, 0, 0, 0.35 }
local OUTLINE = { width = 1 * PX, color = LINE, sides = { "top", "left", "right" } }
local PADDING = { 7 * PX, 14 * PX, 6 * PX, 14 * PX }
local TOP_LIGHT = { attributes = { position = "absolute", left = 1 * PX, right = 1 * PX, top = 1 * PX, height = 2 * PX,
	background = { 0.839, 0.647, 0.42, 1 } } } -- --o-hi #d6a56b

local function Background(_, self)
	return self.attributes.selected and PICKED or SHADE
end
local function Border(_, self)
	return self.attributes.selected and OUTLINE or nil
end
local function Color(_, self)
	return self.attributes.selected and WHITE or NAME
end
local function Click(_, self)
	return not self.attributes.selected and self.attributes.OnPick or nil
end

local function Parts(game, self)
	if self.attributes.selected then
		game.ui:Box(TOP_LIGHT)
	end
	game.ui:Text({ attributes = { text = self.attributes.label, textColor = Color(game, self), textSize = TEXT,
		stateFrom = "parent", wrap = false } })
end

return Define.Component({
	Render = function(game, self)
		game.ui:Box({ attributes = { padding = PADDING, background = Background(game, self), border = Border(game, self),
			OnClick = Click(game, self) }, slots = { default = Parts } })
	end,
})
