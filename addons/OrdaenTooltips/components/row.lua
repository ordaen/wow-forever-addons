-- A tooltip's line (view.lua): a name and its value (a stat, a footer's label and value: the value on the right,
-- never wrapped) or free text (wraps at the tooltip's width).
--
-- Attributes: `left`, `right` (nil: free text), `leftColor`, `rightColor`, `size` (text size, UI units).
local Define = import("@ordaen/define")

local PX = 1 / 1.2

local function Pair(game, self)
	game.ui:Text({ attributes = { text = self.attributes.left, textColor = self.attributes.leftColor,
		textSize = self.attributes.size } })
	game.ui:Text({ attributes = { text = self.attributes.right, textColor = self.attributes.rightColor,
		textSize = self.attributes.size, wrap = false } })
end

return Define.Component({
	Render = function(game, self)
		if self.attributes.right then
			game.ui:Box({ attributes = { columns = { "1fr", "auto" }, gap = 10 * PX }, slots = { default = Pair } })
		else
			game.ui:Text({ attributes = { text = self.attributes.left, textColor = self.attributes.leftColor,
				textSize = self.attributes.size } })
		end
	end,
})
