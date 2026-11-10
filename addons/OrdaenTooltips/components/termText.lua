-- A piece of a tooltip's text that may name a glossary term (design Tooltip.vue: a part with `data-term`): its text,
-- never wrapped. While the tooltip is locked (OnLink set) a part with a term is underlined with gold dashes, and the
-- mouse on it shows the help cursor (design `cursor: help`) and opens the term's tooltip
-- (OnLink("ordaen:term:<key>:<amount>", entered)).
--
-- Attributes: `text`, `color`, `size` (text size, UI units), `term` and `amount` (its glossary entry and the number it
-- speaks of, or nil), `OnLink`.
local Define = import("@ordaen/define")
local DASH_FILE = import("assets/dash.tga")
local HELP_CURSOR = import("assets/help-cursor.tga") -- art/tooltip-help-cursor.py

local PX = 1 / 1.2
-- the underline: the dash tiled along the text's bottom, 1 px high (art/tooltip-dash.py: 2 px on, 2 off)
local UNDERLINE = { attributes = { position = "absolute", left = 0, right = 0, bottom = 0, height = 1 * PX,
	background = { file = DASH_FILE, size = { 8, 2 }, tile = true } } }

local function Lit(_, self)
	return self.attributes.OnLink ~= nil and self.attributes.term ~= nil
end

local function Parts(game, self)
	game.ui:Text({ attributes = { text = self.attributes.text, textColor = self.attributes.color,
		textSize = self.attributes.size, wrap = false } })
	if Lit(game, self) then
		game.ui:Box(UNDERLINE)
	end
end

local function Enter(game, self)
	return Lit(game, self) and self.enter or nil
end
local function Leave(game, self)
	return Lit(game, self) and self.leave or nil
end

return Define.Component({
	Setup = function(_, self)
		local link -- the link the mouse entered, left with it
		return {
			enter = function()
				local fn, term = self.attributes.OnLink, self.attributes.term
				if fn and term then
					link = "ordaen:term:" .. term .. ":" .. (self.attributes.amount or "")
					SetCursor(HELP_CURSOR)
					fn(link, true)
				end
			end,
			leave = function()
				local fn = self.attributes.OnLink
				if link then
					ResetCursor()
				end
				if fn and link then
					fn(link, false)
				end
				link = nil
			end,
		}
	end,

	Render = function(game, self)
		game.ui:Box({ attributes = { columns = 1, OnEnter = Enter(game, self), OnLeave = Leave(game, self) },
			slots = { default = Parts } })
	end,
})
