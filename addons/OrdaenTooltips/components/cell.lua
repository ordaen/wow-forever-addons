-- A cell of a tooltip's band (view.lua): its glyph (design TooltipGlyph: 16 px, from assets/glyphs.tga, which
-- art/tooltip-glyphs.mjs renders from the design's SVGs) before its text, centred, never wrapped. While OnLink is set
-- (the tooltip is locked), the mouse on a cell with a term opens that term's tooltip (OnLink(link, entered)).
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
	game.ui:Text({ attributes = { text = self.attributes.text, textColor = self.attributes.color, textSize = 16 * PX,
		wrap = false } })
end

local function Enter(_, self)
	return self.attributes.OnLink and self.attributes.term and self.enter or nil
end
local function Leave(_, self)
	return self.attributes.OnLink and self.attributes.term and self.leave or nil
end

return Define.Component({
	Setup = function(_, self)
		local link -- the link the mouse entered, left with it
		return {
			enter = function()
				local fn, term = self.attributes.OnLink, self.attributes.term
				if fn and term then
					link = "ordaen:term:" .. term .. ":" .. (self.attributes.amount or "")
					fn(link, true)
				end
			end,
			leave = function()
				local fn = self.attributes.OnLink
				if fn and link then
					fn(link, false)
				end
				link = nil
			end,
		}
	end,

	Render = function(game, self)
		game.ui:Box({ attributes = { columns = { "auto", "auto" }, gap = 5 * PX, xAlign = "center", yAlign = "center",
			OnEnter = Enter(game, self), OnLeave = Leave(game, self) }, slots = { default = Parts } })
	end,
})
