-- A cell of a tooltip's band (view.lua): its glyph (design TooltipGlyph: 16 px, from assets/glyphs.tga, which
-- art/tooltip-glyphs.mjs renders from the design's SVGs) before its text (a TermText: its term underlined and opened
-- once the tooltip is locked), centred, never wrapped.
--
-- Attributes: `text`, `color`, `glyph` (the glyph's background, or nil for none), `tint` (the glyph's colour: a
-- spell's cost in its resource's colour), `term` and `amount` (its glossary entry and the number it speaks of),
-- `OnLink`.
local Define = import("@ordaen/define")

local PX = 1 / 1.2

local function Parts(game, self)
	if self.attributes.glyph then
		game.ui:Box({ attributes = { width = 16 * PX, height = 16 * PX, background = self.attributes.glyph,
			tint = self.attributes.tint } })
	end
	game.ui:TermText({ attributes = { text = self.attributes.text, color = self.attributes.color, size = 16 * PX,
		term = self.attributes.term, amount = self.attributes.amount, OnLink = self.attributes.OnLink } })
end

return Define.Component({
	Render = function(game, self)
		game.ui:Box({ attributes = { columns = { "auto", "auto" }, gap = 5 * PX, xAlign = "center", yAlign = "center" },
			slots = { default = Parts } })
	end,
})
