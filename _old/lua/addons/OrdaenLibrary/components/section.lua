-- Section (design controls/row, heading): a group of rows on a settings tab under its heading: the title in gold
-- bold, a bronze rule fading out to its right; the rows 14 px apart below it.
--
-- Attributes: `title` (text). Slot `default`: the rows.
local Define = import("@ordaen/define")

local PX = 1 / 1.2 -- UI units a design px is at the user's scale (a 1440p screen)
local GOLD = { 0.91, 0.765, 0.353, 1 } -- --o-gold #e8c35a
local TEXT = 15 * PX
local BOLD = { color = GOLD, x = 1 * PX, y = 0 } -- the design's 700: the same colour one pixel right
local ROWS = { columns = 1, gap = 14 * PX }
-- the heading: its title, then the rule filling the rest, 10 px apart, centred on the title
local HEADING = { columns = { "auto", "1fr" }, gap = 10 * PX, yAlign = "center" }
local RULE = { attributes = { height = 1 * PX, background = Define.Theme.ctl.rule } }

local function Heading(game, self)
	game.ui:Text({ attributes = { text = self.attributes.title, textColor = GOLD, textSize = TEXT, textShadow = BOLD,
		wrap = false } })
	game.ui:Box(RULE)
end

local function Parts(game)
	game.ui:Box({ attributes = HEADING, slots = { default = Heading } })
	game.ui:Slot("default")
end

return Define.Component({
	Render = function(game)
		game.ui:Box({ attributes = ROWS, slots = { default = Parts } })
	end,
})
