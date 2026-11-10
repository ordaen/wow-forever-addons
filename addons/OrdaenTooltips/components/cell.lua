-- A cell of a tooltip's band (view.lua): its glyph (design TooltipGlyph: 16 px, from assets/glyphs.tga, which
-- art/tooltip-glyphs.mjs renders from the design's SVGs) before its text, centred, never wrapped.
--
-- Attributes: `text`, `color`, `glyph` (a background for the glyph box: Glyph(name) below, or nil for none).
local Define = import("@ordaen/define")

local PX = 1 / 1.2

local function Parts(game, self)
	if self.attributes.glyph then
		game.ui:Box({ attributes = { width = 16 * PX, height = 16 * PX, background = self.attributes.glyph } })
	end
	game.ui:Text({ attributes = { text = self.attributes.text, textColor = self.attributes.color, textSize = 16 * PX,
		wrap = false } })
end

return Define.Component({
	Render = function(game, self)
		game.ui:Box({ attributes = { columns = { "auto", "auto" }, gap = 5 * PX, xAlign = "center", yAlign = "center" },
			slots = { default = Parts } })
	end,
})
