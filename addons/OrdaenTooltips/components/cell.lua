-- A cell of a tooltip's band (view.lua): its glyph (design TooltipGlyph: 16 px, from assets/glyphs.tga, which
-- art/tooltip-glyphs.mjs renders from the design's SVGs) before its text (a TermText: its term underlined and opened
-- once the tooltip is locked), centred, never wrapped.
--
-- Attributes: `text`, `color`, `glyph` (the glyph's background, or nil for none), `tint` (the glyph's colour: a
-- spell's cost in its resource's colour), `term` and `amount` (its glossary entry and the number it speaks of), `link`
-- (what it opens instead: a race's racials),
-- `divider` (a rule on its left: not the first cell), `last` (the band ends the tooltip: no padding under it),
-- `OnLink`.
local Define = import("@ordaen/define")

local PX = 1 / 1.2
local DIVIDER = { width = 1 * PX, sides = { "left" }, color = { 0.839, 0.647, 0.420, 0.18 } } -- --rule
local PADDING = { 8 * PX, 10 * PX, 8 * PX, 10 * PX }
local PADDING_LAST = { 8 * PX, 10 * PX, 0, 10 * PX }

local function Divider(_, self)
	return self.attributes.divider and DIVIDER or nil
end
local function Padding(_, self)
	return self.attributes.last and PADDING_LAST or PADDING
end

local function Parts(game, self)
	if self.attributes.glyph then
		game.ui:Box({ attributes = { width = 16 * PX, height = 16 * PX, background = self.attributes.glyph,
			tint = self.attributes.tint } })
	end
	game.ui:TermText({ attributes = { text = self.attributes.text, color = self.attributes.color, size = 16 * PX,
		term = self.attributes.term, amount = self.attributes.amount, link = self.attributes.link,
		OnLink = self.attributes.OnLink } })
end

-- the glyph and the text, centred in the cell
local function Content(game)
	game.ui:Box({ attributes = { columns = { "auto", "auto" }, gap = 5 * PX, xAlign = "center", yAlign = "center" },
		slots = { default = Parts } })
end

return Define.Component({
	Render = function(game, self)
		game.ui:Box({ attributes = { columns = 1, padding = Padding(game, self), border = Divider(game, self) },
			slots = { default = Content } })
	end,
})
