-- OrdaenCore.UI default theme: what each style role looks like. Data only: the renderer reads it, nothing here
-- draws. It uses Blizzard's own art and fonts, so Ordaen UI looks native out of the box; a theme addon will
-- replace these tables (same shape) to give everything a different look.
--
-- blocks[style]: surface art (backdrop), colors, and layout defaults (padding, gap, minWidth, maxWidth).
-- text[style]:   a font object name (a Blizzard global) and a color. Elements without a style are "body".
local _, ns = ...

local WHITE = { 1, 1, 1 }
local GOLD = { 1, 0.82, 0 }
local GREY = { 0.5, 0.5, 0.5 }

ns.Theme = {
	blocks = {
		tooltip = {
			backdrop = {
				bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
				edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
				edgeSize = 16,
				insets = { left = 4, right = 4, top = 4, bottom = 4 },
			},
			background = { 0.09, 0.09, 0.19, 0.95 }, -- Blizzard's tooltip colors
			border = { 1, 1, 1, 1 },
			padding = 10,
			gap = 2,
			maxWidth = 300,
		},
	},
	text = {
		title = { font = "GameTooltipHeaderText", color = WHITE },
		subtitle = { font = "GameTooltipText", color = GOLD },
		body = { font = "GameTooltipText", color = WHITE },
		label = { font = "GameTooltipText", color = GOLD },
		value = { font = "GameTooltipText", color = WHITE },
		hint = { font = "GameTooltipTextSmall", color = GREY },
	},
}
