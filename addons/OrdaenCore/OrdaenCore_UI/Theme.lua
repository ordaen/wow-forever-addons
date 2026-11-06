-- OrdaenCore.UI default theme: what each style role looks like. Data only: the renderer reads it, nothing here
-- draws. It uses Blizzard's own art and fonts, so Ordaen UI looks native out of the box; a theme addon will
-- replace these tables (same shape) to give everything a different look.
--
-- blocks[style]: surface art (backdrop), colors, a hover highlight, and layout defaults (padding, gap, minWidth,
--                maxWidth). A style without a backdrop draws no surface (plain text, a bare icon).
-- text[style]:   a font object name (a Blizzard global) and a color. Elements without a style are "body".
local _, ns = ...

local WHITE = { 1, 1, 1 }
local GOLD = { 1, 0.82, 0 }
local GREY = { 0.5, 0.5, 0.5 }

local TOOLTIP_ART = {
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	edgeSize = 16,
	insets = { left = 4, right = 4, top = 4, bottom = 4 },
}
local HIGHLIGHT = "Interface\\Buttons\\ButtonHilight-Square" -- drawn additively over the content on hover

---@class OrdaenUIBlockLook
---@field backdrop table|nil BackdropTemplate backdrop info; nil = no surface art
---@field background number[]|nil { r, g, b, a } of the backdrop
---@field border number[]|nil { r, g, b, a } of the backdrop's edge
---@field highlight string|nil texture shown over the content while the mouse is over it
---@field padding number|number[]|nil
---@field gap number|number[]|nil
---@field minWidth number|nil
---@field maxWidth number|nil

---@class OrdaenUITextLook
---@field font string name of a Blizzard font object
---@field color number[] { r, g, b }

---@class OrdaenUITheme
---@field blocks table<string, OrdaenUIBlockLook>
---@field text table<string, OrdaenUITextLook>
ns.Theme = {
	blocks = {
		-- A floating panel next to its owner.
		tooltip = {
			backdrop = TOOLTIP_ART,
			background = { 0.09, 0.09, 0.19, 0.95 }, -- Blizzard's tooltip colors
			border = { 1, 1, 1, 1 },
			padding = 10,
			gap = 2,
			maxWidth = 300,
		},
		-- Clickable text without a surface (a zone name, a clock).
		button = {
			padding = 0,
			gap = 0,
		},
		-- A small square icon button with a dark surface (the Ordaen Dev gear button's look).
		iconButton = {
			backdrop = TOOLTIP_ART,
			background = { 0, 0, 0, 0.8 },
			border = { 1, 1, 1, 1 },
			highlight = HIGHLIGHT,
			padding = 4,
		},
		-- A cell in a grid of icons (the drawer's entries): no surface, a highlight on hover.
		slot = {
			highlight = HIGHLIGHT,
			padding = 3,
		},
	},
	text = {
		title = { font = "GameTooltipHeaderText", color = WHITE },
		subtitle = { font = "GameTooltipText", color = GOLD },
		body = { font = "GameTooltipText", color = WHITE },
		label = { font = "GameTooltipText", color = GOLD },
		value = { font = "GameTooltipText", color = WHITE },
		hint = { font = "GameTooltipTextSmall", color = GREY },
		normal = { font = "GameFontNormal", color = GOLD }, -- names on the screen (the zone above the map)
		small = { font = "GameFontHighlightSmall", color = WHITE }, -- small readouts (coordinates, clock)
	},
}
