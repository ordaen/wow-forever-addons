-- A tooltip's line (view.lua): a name and its value (a stat, a footer's label and value: the value on the right,
-- never wrapped) or free text (wraps at the tooltip's width).
--
-- Its links (a spell's name in a description, an item or spell link) call OnLink(link, entered) while it's set (the
-- tooltip is locked).
--
-- A footer label with a term (`term`, `amount`) is a TermText: underlined and opened once the tooltip is locked.
--
-- Attributes: `left`, `right` (nil: free text), `leftColor`, `rightColor`, `size` (text size, UI units), `term`,
-- `amount`, `OnLink`.
local Define = import("@ordaen/define")

local PX = 1 / 1.2

local function Free(game, self)
	if self.attributes.term then -- a footer note with a term («Требуется 9-й уровень»)
		game.ui:TermText({ attributes = { text = self.attributes.left, color = self.attributes.leftColor,
			size = self.attributes.size, term = self.attributes.term, amount = self.attributes.amount,
			OnLink = self.attributes.OnLink } })
	else
		game.ui:Text({ attributes = { text = self.attributes.left, textColor = self.attributes.leftColor,
			textSize = self.attributes.size } })
	end
end

local function Pair(game, self)
	if self.attributes.term then
		game.ui:TermText({ attributes = { text = self.attributes.left, color = self.attributes.leftColor,
			size = self.attributes.size, term = self.attributes.term, amount = self.attributes.amount,
			OnLink = self.attributes.OnLink } })
	else
		game.ui:Text({ attributes = { text = self.attributes.left, textColor = self.attributes.leftColor,
			textSize = self.attributes.size } })
	end
	game.ui:Text({ attributes = { text = self.attributes.right, textColor = self.attributes.rightColor,
		textSize = self.attributes.size, wrap = false } })
end

return Define.Component({
	Render = function(game, self)
		if self.attributes.right then
			game.ui:Box({ attributes = { columns = { "1fr", "auto" }, gap = 10 * PX, OnLink = self.attributes.OnLink },
				slots = { default = Pair } })
		else
			game.ui:Box({ attributes = { columns = 1, OnLink = self.attributes.OnLink }, slots = { default = Free } })
		end
	end,
})
