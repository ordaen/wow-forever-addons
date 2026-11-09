-- The theme's values by path (development/framework/mvp, "Contract: engine and backend"): what a theme reference
-- (`Define.Theme.color.surface`, `{ path = "color.surface" }`) resolves to when the backend draws. The MVP has one
-- theme, owned by the backend; this table is its only copy.
--   color.*    { r, g, b, a } from 0 to 1
--   spacing.*  UI units
--   text.*     font sizes
--   panel.*    Ordaen Panel's look (design: panel): wood, a background { atlas } that covers its box; edge, a border
--              { width, sides, nineSlice } drawn with a Blizzard nine-slice's art along the top only
local _, ns = ...

ns.Theme = {
	["color.surface"] = { 0.06, 0.06, 0.08, 0.92 },
	["color.surfaceHover"] = { 0.14, 0.14, 0.18, 0.95 },
	["color.border"] = { 0.28, 0.27, 0.25, 1 },
	["color.text"] = { 0.93, 0.91, 0.86, 1 },
	["color.textDim"] = { 0.62, 0.6, 0.56, 1 },
	["color.accent"] = { 1, 0.82, 0, 1 },
	["spacing.xs"] = 2,
	["spacing.sm"] = 4,
	["spacing.md"] = 8,
	["spacing.lg"] = 12,
	["spacing.xl"] = 16,
	["text.small"] = 10,
	["text.body"] = 12,
	["text.large"] = 14,
	["text.title"] = 16,
	-- the character sheet's wood, as the panel's surface
	["panel.wood"] = { atlas = "UI-Character-Info-General-BG" },
	-- the small metal (GenericMetal at half its size) along the top: 8 px at the user's scale (1.2 px per unit)
	["panel.edge"] = { width = 7, sides = { "top" }, nineSlice = "GenericMetal" },
}
