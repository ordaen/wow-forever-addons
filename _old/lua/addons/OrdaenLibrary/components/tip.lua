-- Tip (design Tooltip, the title section): our tooltip beside what it explains, the small metal frame round the
-- windows' wood, 12 px inside; its name in white (18 px) and its text under it in the label colour (14 px), wrapped at
-- the tooltip's width (314 px). It draws over everything in its window and takes no mouse. Its owner shows it while
-- the cursor is on what it explains: a settings row's hint (SettingRow).
--
-- Attributes: `title`, `text` (texts), `left`, `top` (where it sits in the owner's box, UI units).
local Define = import("@ordaen/define")

local PX = 1 / 1.2 -- UI units a design px is at the user's scale (a 1440p screen)
local WIDTH = 314 * PX
local NAME = { 1, 1, 1, 1 }
local LABEL = { 0.796, 0.725, 0.58, 1 } -- --label #cbb994

local function Parts(game, self)
	game.ui:Text({ attributes = { text = self.attributes.title, textColor = NAME, textSize = 18 * PX } })
	game.ui:Text({ attributes = { text = self.attributes.text, textColor = LABEL, textSize = 14 * PX } })
end

return Define.Component({
	Render = function(game, self)
		game.ui:Box({ attributes = { position = "absolute", left = self.attributes.left, top = self.attributes.top,
			width = WIDTH, zLevel = 60, border = Define.Theme.frame.small, background = Define.Theme.window.wood,
			artOrigin = true, padding = 12 * PX, columns = 1, gap = 2 * PX }, slots = { default = Parts } })
	end,
})
