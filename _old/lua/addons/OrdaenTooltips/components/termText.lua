-- A piece of a tooltip's text that may name a glossary term (design Tooltip.vue: a part with `data-term`): its text,
-- never wrapped. While the tooltip is locked (OnLink set) a part with a term is underlined with gold dashes under the
-- text only, and the mouse on the text shows the question-mark cursor and opens the term's tooltip (hover.lua). The
-- text keeps its own width: the rest of its row stays empty (no underline, no hover there).
--
-- Attributes: `text`, `color`, `size` (text size, UI units), `term` and `amount` (its glossary entry and the number it
-- speaks of, or nil), `link` (what it opens instead of a term: an item's or spell's link), `OnLink`, `passive` (its
-- holder takes the mouse for it: a band's cell).
local Define = import("@ordaen/define")
local Hover = import("hover")
local DASH_FILE = import("assets/dash.tga")

local PX = 1 / 1.2
-- the underline: the dash tiled along the text's bottom, 1 px high (art/tooltip-dash.py: 2 px on, 2 off)
local UNDERLINE = { attributes = { position = "absolute", left = 0, right = 0, bottom = 0, height = 1 * PX,
	background = { file = DASH_FILE, size = { 8, 2 }, tile = true } } }
-- the text at its own width, the rest of the row empty
local ROW = { "auto", "1fr" }

local function Lit(_, self)
	return self.attributes.OnLink ~= nil and (self.attributes.term ~= nil or self.attributes.link ~= nil)
end

local function Parts(game, self)
	game.ui:Text({ attributes = { text = self.attributes.text, textColor = self.attributes.color,
		textSize = self.attributes.size, wrap = false } })
	if Lit(game, self) then
		game.ui:Box(UNDERLINE)
	end
end

local function Enter(game, self)
	return Lit(game, self) and not self.attributes.passive and self.enter or nil
end
local function Leave(game, self)
	return Lit(game, self) and not self.attributes.passive and self.leave or nil
end

local function Text(game, self)
	game.ui:Box({ attributes = { columns = 1, OnEnter = Enter(game, self), OnLeave = Leave(game, self) },
		slots = { default = Parts } })
end

return Define.Component({
	Setup = function(_, self)
		local enter, leave = Hover(self)
		return { enter = enter, leave = leave }
	end,

	Render = function(game, self)
		game.ui:Box({ attributes = { columns = ROW }, slots = { default = Text } })
	end,
})
