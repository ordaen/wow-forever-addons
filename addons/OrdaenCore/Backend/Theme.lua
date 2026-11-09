-- The theme's values by path (development/framework/mvp, "Contract: engine and backend"): what a theme reference
-- (`Define.Theme.color.surface`, `{ path = "color.surface" }`) resolves to when the backend draws. The MVP has one
-- theme, owned by the backend; this table is its only copy.
--   color.*    { r, g, b, a } from 0 to 1
--   spacing.*  UI units
--   text.*     font sizes
--   font.*     font files (textFamily)
--   panel.*    Ordaen Panel's look (design: panel): wood, a background { atlas } that covers its box; edge, a border
--              { width, sides, nineSlice } drawn with a Blizzard nine-slice's art along the top only; corner, the
--              portrait's mask { mask, rim } (media/portrait-*.tga, drawn for a 128 x 124 box); badge, the level
--              badge's art as a background
local _, ns = ...

ns.Theme = {
	["color.surface"] = { 0.06, 0.06, 0.08, 0.92 },
	["color.surfaceHover"] = { 0.14, 0.14, 0.18, 0.95 },
	["color.border"] = { 0.28, 0.27, 0.25, 1 },
	["color.text"] = { 0.93, 0.91, 0.86, 1 },
	["color.textDim"] = { 0.62, 0.6, 0.56, 1 },
	["color.accent"] = { 1, 0.82, 0, 1 },
	-- experience: the old panel's XP blue; rested XP the design's pale blue over the trough (XpTube)
	["color.xp"] = { 0.1, 0.42, 0.9, 1 },
	["color.xpRested"] = { 0.43, 0.59, 0.82, 0.16 },
	-- a bar's trough on the wood: darker than the wood, so the bar reads as set into it
	["color.inset"] = { 0.02, 0.012, 0.006, 0.85 },
	["spacing.xs"] = 2,
	["spacing.sm"] = 4,
	["spacing.md"] = 8,
	["spacing.lg"] = 12,
	["spacing.xl"] = 16,
	["text.small"] = 10,
	["text.body"] = 12,
	["text.large"] = 14,
	["text.title"] = 16,
	-- the client's text font (Friz Quadrata; its Cyrillic file on ruRU), and Blizzard's number font (NumberFontNormal's)
	["font.body"] = STANDARD_TEXT_FONT,
	["font.numbers"] = "Fonts\\ARIALN.TTF",
	-- the character sheet's wood, as the panel's surface
	["panel.wood"] = { atlas = "UI-Character-Info-General-BG" },
	-- the small metal along the top, as the design site's MetalFrame kind "small" draws it: Blizzard's
	-- ButtonFrameTemplateNoPortrait at half size, its outer side 1.5 units above the panel, the wood from 3 below
	-- its top; the content starts 7 units down (8 px at the user's scale, 1.2 px per unit)
	["panel.edge"] = { width = 7, sides = { "top" }, nineSlice = "ButtonFrameTemplateNoPortrait", scale = 0.5,
		outset = 1.5, inset = 3 },
	-- the portrait fitted into the screen's corner: flat top, the top-right corner rounded, the rim along the top and
	-- the right (design: panel, «Portrait»; CornerPortrait)
	["panel.corner"] = {
		mask = "Interface\\AddOns\\OrdaenCore\\media\\portrait-mask",
		rim = "Interface\\AddOns\\OrdaenCore\\media\\portrait-rim",
	},
	["panel.badge"] = "Interface\\AddOns\\OrdaenCore\\media\\level-badge",
	-- a thin dark edge round a bar on the wood (the portrait rim's darkest stroke)
	["panel.barEdge"] = { width = 1, color = { 0.07, 0.043, 0.02, 1 } },
	-- a bag button's edge on the wood (ItemSlot): one bronze line inside the slot's size
	["panel.slotEdge"] = { width = 1, color = { 0.424, 0.333, 0.208, 1 } },
	-- a micro menu or bag cell (PanelCell): our button's side rims on the wood, caps a fifth of its height; rows
	-- 0 normal, 1 the hover glow (over normal), 2 pushed
	["panel.cell"] = { file = "Interface\\AddOns\\OrdaenCore\\media\\panel-cell", size = { 256, 256 }, cap = 32,
		capHeight = 0.2, rows = 4, normal = 0, glow = 1, pressed = 2 },
	-- the experience tube (XpTube), back to front: the trough, the fill tiling along it (inset 10/64 of the tube's
	-- height), the glass shine, the bronze ring; the three tube pieces three-sliced with caps as wide as it is high
	["panel.xpTrough"] = { file = "Interface\\AddOns\\OrdaenCore\\media\\xp-tube-trough", size = { 256, 64 }, cap = 64,
		capHeight = 1 },
	["panel.xpFill"] = { file = "Interface\\AddOns\\OrdaenCore\\media\\xp-fill-brushed", size = { 1024, 32 },
		tile = true },
	["panel.xpShine"] = { file = "Interface\\AddOns\\OrdaenCore\\media\\xp-tube-shine", size = { 256, 64 }, cap = 64,
		capHeight = 1 },
	["panel.xpTube"] = { file = "Interface\\AddOns\\OrdaenCore\\media\\xp-tube", size = { 256, 64 }, cap = 64,
		capHeight = 1 },
	-- the settings switch (design controls/switch), rendered from it at 3.2 texels a px: the track, a pill three-sliced
	-- with round caps (rows 0 off, 1 on, 2 the hover ring over either), and the knob drawn whole in a 26 px square
	-- (the 14 px knob and the on knob's glow; rows 0 off, 1 on)
	["ctl.switchOff"] = { file = "Interface\\AddOns\\OrdaenCore\\media\\ctl-switch-track", size = { 128, 256 },
		cap = 32, capHeight = 0.5, rows = 4, normal = 0, glow = 2 },
	["ctl.switchOn"] = { file = "Interface\\AddOns\\OrdaenCore\\media\\ctl-switch-track", size = { 128, 256 },
		cap = 32, capHeight = 0.5, rows = 4, normal = 1, glow = 2 },
	["ctl.knobOff"] = { file = "Interface\\AddOns\\OrdaenCore\\media\\ctl-switch-knob", size = { 64, 128 }, cap = 0,
		capHeight = 0, rows = 2, normal = 0 },
	["ctl.knobOn"] = { file = "Interface\\AddOns\\OrdaenCore\\media\\ctl-switch-knob", size = { 64, 128 }, cap = 0,
		capHeight = 0, rows = 2, normal = 1 },
	-- a count on a cell (the friends online on the social button; design .mbadge): a green pill with a black ring and a
	-- faint top highlight, round caps half its height wide; the box gives it 16 px height, the text and side padding
	["panel.countBadge"] = { file = "Interface\\AddOns\\OrdaenCore\\media\\panel-count-badge", size = { 128, 64 },
		cap = 32, capHeight = 0.5 },
}
