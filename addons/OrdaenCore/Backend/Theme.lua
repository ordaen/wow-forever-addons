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

-- the wood of the windows and the panel (design settings/wood, D): Blizzard's character sheet wood made a seamless tile
-- (design/scripts/wood-split.py), repeated from the box's top-left at the scale the picture had in a 1160 px window
-- (512 texels over 746 px), so a resized box keeps its grain; one file for every surface
local WOOD = { file = "Interface\\AddOns\\OrdaenCore\\media\\window-wood", size = { 512, 512 },
	repeatSize = 746 / 1.2 }
-- The metal art's thickness past its 3-unit line, per side { top, right, bottom, left }, in the art's units at scale 1:
-- the art (ButtonFrameTemplateNoPortrait's edges, design public/ui/metal) is drawn from the box's edge, and its line
-- ends 20.5 units in on the top and left (the left edge's art and the top turned from it: 20 transparent units, then
-- the shadow, the bronze and the dark core), 10.5 on the right and 16 at the bottom. A border is drawn inside its box
-- (border-box): the layout counts 3 + reach x scale as the border's width on each side it draws, so the content
-- starts where the art ends and never lies on it.
local METAL_REACH = { 14.5, 4.5, 10, 14.5 }
-- The one metal frame (design MetalFrame "small"): Blizzard's ButtonFrameTemplateNoPortrait at half size; its fill
-- (the wood) from 1.5 units into the art past its line, under the line, so no gap shows between them. Every framed
-- surface (windows, dialogs, tooltips, the minimap, the bottom panel's top edge, the window tabs) is this frame on the sides it names (all four when `sides` is nil). Spacing
-- inside a frame is the box's padding, never a wider border.
-- Its curves (border.radius, border.flare: tools/metal-curves.py makes their pieces from the same left edge): the
-- pieces' sides in the art's units at scale 1. A corner's radius reads at the line's bronze stripe, 14 units in from
-- the outer side: small 8 px, large 14 px at the user's scale (1.2 px a unit, the art at half size); a flare is the
-- line's visible 21 units, bent round its outer side.
local METAL_CURVES = { small = 8 / 1.2 / 0.5 + 14, large = 14 / 1.2 / 0.5 + 14, flare = 21 }
local function Metal(sides, inset, radius, flare)
	return { width = 3, nineSlice = "ButtonFrameTemplateNoPortrait", scale = 0.5, inset = inset or -1.5,
		reach = METAL_REACH, sides = sides, curves = METAL_CURVES, radius = radius, flare = flare }
end
local TAB_CORNERS = { tl = "large", tr = "large" }
local ICON_CORNER = { br = "small" }

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
	-- the micro menu's gold icon set: the icons desaturated and multiplied by this (the design's MicroIcon .gold filter,
	-- grayscale + sepia + saturate 2.6 + hue -8deg + brightness 1.05 + contrast 1.1, taken at mid grey)
	["color.microGold"] = { 1, 0.72, 0.28, 1 },
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
	-- the panel's surface: the windows' wood (WOOD), so its grain matches theirs and doesn't stretch on wide screens
	["panel.wood"] = WOOD,
	-- the metal along the bottom panel's top (its content below it starts after the panel's own padding)
	["panel.edge"] = Metal({ "top" }),
	-- a window's or small surface's metal on all four sides: windows, dialogs, tooltips, the minimap
	["frame.small"] = Metal(),
	-- a window tab's frame: the metal on its top and sides, its top corners rounded large, none along its bottom, where
	-- it stands on the window's body; the open tab's sides curve out into the body's top line (the first tab's left
	-- runs straight down the body's left line). Its icon's: the metal on its right; the open tab's on its bottom too,
	-- the corner between rounded small
	["frame.tab"] = Metal({ "top", "left", "right" }, nil, TAB_CORNERS),
	["frame.tabOpen"] = Metal({ "top", "left", "right" }, nil, TAB_CORNERS, { "left", "right" }),
	["frame.tabOpenFirst"] = Metal({ "top", "left", "right" }, nil, TAB_CORNERS, { "right" }),
	-- the icon's picture runs under its line to the box's right edge (the right reach times the scale, back)
	["frame.tabIcon"] = Metal({ "right" }, -2.25),
	["frame.tabIconOpen"] = Metal({ "right", "bottom" }, -2.25, ICON_CORNER),
	-- a button on the minimap's ring (design Minimap .ring): a 34 px dark disc in a bronze ring with a black edge,
	-- drawn whole (rows 0 the button, 1 the light ring over it under the cursor, 2 lit: the drawer open)
	["minimap.ring"] = { file = "Interface\\AddOns\\OrdaenCore\\media\\minimap-ring", size = { 128, 512 }, cap = 0,
		capHeight = 0, rows = 4, normal = 0, glow = 1 },
	["minimap.ringLit"] = { file = "Interface\\AddOns\\OrdaenCore\\media\\minimap-ring", size = { 128, 512 },
		cap = 0, capHeight = 0, rows = 4, normal = 2, glow = 1 },
	-- the portrait fitted into the screen's corner: flat top, the top-right corner rounded, the rim along the top and
	-- the right (design: panel, «Portrait»; CornerPortrait)
	["panel.corner"] = {
		mask = "Interface\\AddOns\\OrdaenCore\\media\\portrait-mask",
		rim = "Interface\\AddOns\\OrdaenCore\\media\\portrait-rim",
	},
	-- the portrait in a micro menu cell (Panel's charButton = "button"; design BottomPanel .face): a 40 px circle with
	-- a 1 px black ring
	["panel.faceRound"] = {
		mask = "Interface\\AddOns\\OrdaenCore\\media\\face-round-mask",
		rim = "Interface\\AddOns\\OrdaenCore\\media\\face-round-rim",
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
	["panel.xpFill.brushed"] = { file = "Interface\\AddOns\\OrdaenCore\\media\\xp-fill-brushed", size = { 1024, 32 },
		tile = true },
	["panel.xpFill.clouds"] = { file = "Interface\\AddOns\\OrdaenCore\\media\\xp-fill-clouds", size = { 1024, 32 },
		tile = true },
	["panel.xpFill.deep"] = { file = "Interface\\AddOns\\OrdaenCore\\media\\xp-fill-deep", size = { 1024, 32 },
		tile = true },
	["panel.xpFill.grain"] = { file = "Interface\\AddOns\\OrdaenCore\\media\\xp-fill-grain", size = { 1024, 32 },
		tile = true },
	["panel.xpFill.potion"] = { file = "Interface\\AddOns\\OrdaenCore\\media\\xp-fill-potion", size = { 1024, 32 },
		tile = true },
	["panel.xpFill.steel"] = { file = "Interface\\AddOns\\OrdaenCore\\media\\xp-fill-steel", size = { 1024, 32 },
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
	-- the checkbox (design controls/checkbox), 22 px, drawn whole: the well with its bronze edge (hover: the light ring
	-- over it), and the tick over the well
	["ctl.check"] = { file = "Interface\\AddOns\\OrdaenCore\\media\\ctl-check", size = { 64, 256 }, cap = 0,
		capHeight = 0, rows = 4, normal = 0, glow = 1 },
	["ctl.tick"] = { file = "Interface\\AddOns\\OrdaenCore\\media\\ctl-check", size = { 64, 256 }, cap = 0,
		capHeight = 0, rows = 4, normal = 2 },
	-- the slider (design controls/slider): the groove, 8 px with its 1 px edge (caps 1 px: an eighth of its height),
	-- the bronze fill inside it, and the knob, 14 x 20 px drawn in a 16 x 32 px square with its shadow (the knob 1 px
	-- in from the left, 2 px down)
	["ctl.groove"] = { file = "Interface\\AddOns\\OrdaenCore\\media\\ctl-slider", size = { 64, 128 }, cap = 4,
		capHeight = 0.125, rows = 4, normal = 0 },
	["ctl.sliderFill"] = { file = "Interface\\AddOns\\OrdaenCore\\media\\ctl-slider", size = { 64, 128 }, cap = 0,
		capHeight = 0, rows = 4, normal = 1 },
	["ctl.sliderKnob"] = { file = "Interface\\AddOns\\OrdaenCore\\media\\ctl-slider-knob", size = { 32, 64 },
		cap = 0, capHeight = 0 },
	-- the tabbed window (design TabbedWindow): its wood, one picture across the window from its top-left (the box with
	-- artOrigin), so the body and the open tab show one surface (the windows' wood: WOOD); its tabs are framed with
	-- frame.tab
	["window.wood"] = WOOD,
	-- the tabbed window's corner buttons (design TabbedWindow, the corner group of plates), each drawn whole from its
	-- art, 64 x 32 px: the full screen button 5 px in from the art's left (the group's edge and its lines), both 5 px
	-- above its bottom; the row by state
	["ctl.cornerExpand"] = { file = "Interface\\AddOns\\OrdaenCore\\media\\ctl-corner-full", size = { 128, 512 },
		cap = 0, capHeight = 0, rows = 8, normal = 0, hover = 1, pressed = 2 },
	["ctl.cornerContract"] = { file = "Interface\\AddOns\\OrdaenCore\\media\\ctl-corner-full", size = { 128, 512 },
		cap = 0, capHeight = 0, rows = 8, normal = 3, hover = 4, pressed = 5 },
	["ctl.cornerClose"] = { file = "Interface\\AddOns\\OrdaenCore\\media\\ctl-corner-close", size = { 128, 256 },
		cap = 0, capHeight = 0, rows = 4, normal = 0, hover = 1, pressed = 2 },
	-- the push button and the dropdown's face (design controls/push-button, dropdown; our own art, media/button: rows
	-- 0 normal, 1 pushed, 2 disabled, 3 the hover light over normal, 4 the accent, 5 the accent pushed), three-sliced
	-- with caps half as wide as it is high; the dropdown's arrow
	["ctl.button"] = { file = "Interface\\AddOns\\OrdaenCore\\media\\button", size = { 256, 512 },
		cap = 32, capHeight = 0.5, rows = 8,
		normal = 0, pressed = 1, glow = 3 },
	["ctl.buttonAccent"] = { file = "Interface\\AddOns\\OrdaenCore\\media\\button", size = { 256, 512 },
		cap = 32, capHeight = 0.5, rows = 8,
		normal = 4, pressed = 5, glow = 3 },
	["ctl.buttonDisabled"] = { file = "Interface\\AddOns\\OrdaenCore\\media\\button", size = { 256, 512 },
		cap = 32, capHeight = 0.5, rows = 8,
		normal = 2 },
	-- a dropdown menu item's mark (design Dropdown .mi::before): an 11 px circle, the dim outline, or gold with a dark
	-- inner ring for the picked one; drawn whole
	["ctl.radio"] = { file = "Interface\\AddOns\\OrdaenCore\\media\\ctl-radio", size = { 32, 64 },
		cap = 0, capHeight = 0, rows = 2, normal = 0 },
	["ctl.radioOn"] = { file = "Interface\\AddOns\\OrdaenCore\\media\\ctl-radio", size = { 32, 64 },
		cap = 0, capHeight = 0, rows = 2, normal = 1 },
	-- a section heading's rule (design controls/row, heading): #d6a56b at 45%, fading out to the right
	-- a window's resize grip in its bottom-right corner: Blizzard's own (the chat window's), up, under the cursor, held
	["ctl.grip"] = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up",
	["ctl.gripHover"] = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight",
	["ctl.gripDown"] = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down",
	["ctl.rule"] = "Interface\\AddOns\\OrdaenCore\\media\\ctl-rule",
	["ctl.dropdownArrow"] = "Interface\\AddOns\\OrdaenCore\\media\\dropdown-arrow",
	-- a count on a cell (the friends online on the social button; design .mbadge): a green pill with a black ring and a
	-- faint top highlight, round caps half its height wide; the box gives it 16 px height, the text and side padding
	["panel.countBadge"] = { file = "Interface\\AddOns\\OrdaenCore\\media\\panel-count-badge", size = { 128, 64 },
		cap = 32, capHeight = 0.5 },
}
