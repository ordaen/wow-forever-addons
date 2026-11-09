-- listTab: an entry in the settings window's list (design controls/list-tab): its icon (22 px), its name, and what
-- its slot holds at its right (a module's switch); the shade under the cursor; selected, a darker shade, the name
-- white and a 3 px light along its left; a module that's off, its name and icon dimmed.
--
-- Attributes: `label` (text), `icon` (a file, or nil), `selected`, `off` (booleans), `OnClick`. Slot `default`.
local Define = import("@ordaen/define")

local PX = 1 / 1.2 -- UI units a design px is at the user's scale (a 1440p screen)
local TEXT = 15 * PX
local INK = { 0.91, 0.863, 0.769, 1 } -- --o-ink #e8dcc4
local WHITE = { 1, 1, 1, 1 }
local OFF = { 0.478, 0.439, 0.373, 1 } -- #7a705f
local SHADE = { default = nil, hover = { 0, 0, 0, 0.35 } }
local SELECTED = { 0, 0, 0, 0.25 }
local DIM = { 0.6, 0.6, 0.6, 1 } -- an off module's icon: grey and darker
local BAR = { attributes = { position = "absolute", left = 0, top = 0, bottom = 0, width = 3 * PX,
	background = { 0.839, 0.647, 0.42, 1 } } } -- --o-hi #d6a56b
local ROW = { columns = { 22 * PX, "1fr", "auto" }, gap = 10 * PX, padding = { 7 * PX, 12 * PX, 7 * PX, 16 * PX },
	yAlign = "center" }

local function Background(_, self)
	return self.attributes.selected and SELECTED or SHADE
end
local function Color(_, self)
	return self.attributes.selected and WHITE or self.attributes.off and OFF or INK
end
local function Tint(_, self)
	return self.attributes.off and DIM or nil
end

local function Parts(game, self)
	if self.attributes.selected then
		game.ui:Box(BAR)
	end
	game.ui:Box({ attributes = { width = 22 * PX, height = 22 * PX, background = self.attributes.icon,
		desaturate = self.attributes.off, tint = Tint(game, self) } })
	game.ui:Text({ attributes = { text = self.attributes.label, textColor = Color(game, self), textSize = TEXT,
		wrap = false } })
	game.ui:Slot("default")
end

return Define.Component({
	Render = function(game, self)
		game.ui:Box({ attributes = { columns = ROW.columns, gap = ROW.gap, padding = ROW.padding, yAlign = ROW.yAlign,
			background = Background(game, self), OnClick = self.attributes.OnClick }, slots = { default = Parts } })
	end,
})
