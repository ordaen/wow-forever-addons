-- OrdaenCore.UI themes: how everything looks, as data. The renderer (Render.lua) is the only code that draws;
-- a theme only says which sizes, fonts, colours and surface effects each style role gets.
--
-- One design scale for every Ordaen addon. Its root is the player's global setting in Ordaen Core
-- (OrdaenCoreDB.ui.textSize: body text height in px). Every text size tier and every spacing step is derived
-- from it, so one slider resizes all Ordaen UI and the proportions stay the same. Addons name roles
-- (style = "title", gap = "sm"), never numbers, and pick a change up by themselves.
--
-- Themes (CLAUDE.md, "UI framework"): only `ordaen` is built; `blizzard`
-- (mostly Blizzard's default look) and `minimal` (little to no textures) are planned and unimplemented. The theme is
-- chosen globally in Ordaen Core (OrdaenCoreDB.ui.theme); an unknown name falls back to ordaen. Every theme defines
-- every role, so an addon never needs to know which one is on.
--
-- Colours are { r, g, b, a?, accent = k? }: the colour plus k times the block's accent (its `accent` field,
-- else the theme's), so one formula tints a surface for any accent without a table per accent.
local _, ns = ...

---@class OrdaenUIResolvedText
---@field file string font file
---@field size number px
---@field color number[]
---@field shadow boolean
---@field outline boolean a 1 px outline (and no drop shadow): text on a coloured bar
---@field caps boolean

---@class OrdaenUISeparatorLook
---@field space number room above and below
---@field gap number empty room in the middle (divider) or around the caption text
---@field width number line width in physical px
---@field color number[]

local Theme = {
	version = 0, -- bumped by every Apply; measurement caches compare it
	name = nil, ---@type string|nil the theme in use
	space = {}, ---@type table<string, number> spacing tokens (xs, sm, md, lg, xl) -> UI units
	size = {}, ---@type table<string, number> text size tiers (tiny, small, body, large, title) -> px
	blocks = {}, ---@type table<string, table> style role -> resolved look (numbers, no tokens)
	text = {}, ---@type table<string, OrdaenUIResolvedText> text style -> resolved look
	separators = {}, ---@type table<string, OrdaenUISeparatorLook> rule, divider, caption
	bar = {}, -- { height, track, trackBottom, edge, fill, frames, frame, recessed, shade, tick, scrim, scrimWidth, ahead }
	-- The glass tube a bar element asks for with `frame = "tube"` (the bottom panel's experience bar; art/panel.py):
	-- its art (three-slices), its height in UI units (centred in the element's), the trough's inset as a share of
	-- the height, the fill's tint (its texture is the xpFill asset's own blue) and the rested/quest part past it.
	tube = {
		ring = "Interface\\AddOns\\OrdaenCore\\media\\xp-tube",
		trough = "Interface\\AddOns\\OrdaenCore\\media\\xp-tube-trough",
		shine = "Interface\\AddOns\\OrdaenCore\\media\\xp-tube-shine",
		height = 30, inset = 10 / 64,
		white = { 1, 1, 1 }, rested = { 0.43, 0.59, 0.82, 0.16 },
	},
	-- A unit's round portrait (UI.Portrait: the bottom panel's character button; art/panel.py): the ring and its
	-- shadow, the round mask for the live face, the level's badge; sizes as shares of the portrait's size.
	portrait = {
		ring = "Interface\\AddOns\\OrdaenCore\\media\\portrait-ring",
		shadow = "Interface\\AddOns\\OrdaenCore\\media\\portrait-shadow",
		mask = "Interface\\AddOns\\OrdaenCore\\media\\circle-mask",
		badge = "Interface\\AddOns\\OrdaenCore\\media\\level-badge",
		face = 104 / 128, -- the face's diameter (the ring's inner circle)
		shadowOffset = 5 / 152, -- down and right
		badgeSize = 36 / 152, badgeAt = 0.94, -- the badge's size, and how far out along the 45 degree line its centre sits
		level = { 1, 0.82, 0 }, -- the level's colour (Blizzard's gold)
	},
	accent = nil, ---@type number[]|nil the theme's accent, for blocks without their own
}
ns.Theme = Theme

Theme.DEFAULT_THEME = "ordaen"
Theme.DEFAULT_TEXT_SIZE = 12
Theme.MIN_TEXT_SIZE, Theme.MAX_TEXT_SIZE = 10, 16

local floor, max, min = math.floor, math.max, math.min

-- The scale at text size 12; every step is multiplied by textSize / 12 and rounded.
local SPACE = { xs = 2, sm = 4, md = 8, lg = 12, xl = 16 }
local SIZE = { tiny = 0.75, small = 0.9, body = 1, large = 1.17, title = 1.42 }

-- Fonts: the client's own files, so every language's glyphs are there (the user's client is ruRU). `body` is
-- the tooltip font, `header` the tooltip header font, `ui` the general interface font.
local FONT_SOURCES = { body = "GameTooltipText", header = "GameTooltipHeaderText", ui = "GameFontNormal" }

local function fontFile(kind)
	local object = rawget(_G, FONT_SOURCES[kind] or "GameTooltipText")
	local file = object and object.GetFont and object:GetFont()
	return file or STANDARD_TEXT_FONT
end

-- Themes ---------------------------------------------------------------------------------------------
-- Block looks: padding and gap (tokens or numbers), minWidth/maxWidth in ems (times the text size), and the
-- surface: backdrop (Blizzard art: background, border colours) or fill = { top, bottom } (a vertical gradient),
-- edges = { top, right, bottom, left }, each { width in physical px, colour }, vignette = { size, alpha } (the
-- rim darkened inwards), highlight (hover: { texture } or { color }), bleed (a nested block's surface reaches
-- over its parent's padding to the parent's edges), frameArt (Blizzard's window art from theme tokens: frame and
-- background assets, the border's scale, the background's inset in the art's pixels; instead of fill and edges),
-- controlArt (Blizzard's control art from theme tokens: { kind, base = the normal piece, parts = { name = point },
-- accent = tint by the block's accent }, drawn in the block's controlState; top-level blocks; instead of fill/edges).
-- Text looks: font (body, header, ui), size tier, color, shadow, outline, caps.

local THEMES = {}

-- An engraved window title (title variant B): the title's text inside the window's top
-- (its top `textY` below the window's), and under it a groove `ruleY` below the top, `inset` in from each side: a
-- 1 px dark line over a 1 px lit one (lit from the top-left), both fading out at their ends.
local TITLE_RULE = { textY = 14, ruleY = 32, inset = 40, text = { 1, 0.82, 0 }, -- the title in gold (#ffd100)
	lines = { { 0, 0, 0, 0.85 }, { 0.839, 0.647, 0.420, 0.55 } } }

-- Blizzard's window art, by theme token (themes.jsonc): the frame asset (its NineSlice layout), the background asset,
-- the border's scale, and where the background sits inside that layout's border (the art's pixels: top, right,
-- bottom, left). Windows at full size; small surfaces (tooltips, panels, the chat window) with the border at the
-- small scale (half); dialogs in Blizzard's dialog frame.
local WINDOW_ART = { border = "frame.border", background = "frame.background", scale = "frame.scale.window",
	inset = { 21, 2, 2, 2 } }
-- Small surfaces: the window metal at the small scale, its top drawn as its bottom mirrored (mirrorTop): a window's
-- top edge carries the title bar, which on a strip reads as two borders stacked.
local SMALL_ART = { border = "frame.borderSmall", background = "frame.background", scale = "frame.scale.small",
	inset = { 6, 6, 6, 6 }, mirrorTop = true }
-- Windows with a portrait ring in the top-left corner (Blizzard's own windows that Ordaen Reskin dresses).
local PORTRAIT_ART = { border = "frame.portrait", background = "frame.background", scale = "frame.scale.window",
	inset = { 21, 2, 2, 2 } }
-- Dialogs: the window's art (everything uses the same art), its top mirrored from its bottom: a dialog has
-- no title bar.
local DIALOG_ART = { border = "frame.dialog", background = "frame.dialogBackground", scale = "frame.scale.window",
	inset = { 2, 2, 2, 2 }, mirrorTop = true }
local INSET_ART = { border = "frame.inset", background = "frame.insetBackground", scale = "frame.scale.window",
	inset = { 2, 2, 2, 2 } }

THEMES.ordaen = {
	accent = { 0.72, 0.56, 0.34 }, -- bronze, as the minimap's rim
	blocks = {
		tooltip = {
			padding = "lg", gap = "xs", minWidth = 12, maxWidth = 25,
			frameArt = SMALL_ART,
		},
		header = {
			-- No fill of its own: the tooltip's one background shows behind the title too. No side
			-- padding: its icon and title line up with the text below.
			-- Nothing below it: the section after it brings the gap.
			padding = 0, gap = { "md", "xs" },
		},
		-- Tabs in a list beside their page (Ordaen Bags' categories): hovering darkens one; the selected one has a bronze
		-- bar on its left over a faint warm fill (as on the bags design page).
		listTab = {
			padding = { "sm", "lg", "sm", "lg" },
			highlight = { color = { 0, 0, 0, 0.35 }, blend = "BLEND", under = true },
		},
		listTabSelected = {
			padding = { "sm", "lg", "sm", "lg" },
			-- the page's own fill (tabPage), so the selected tab and its page read as one surface
			fill = { top = { 0, 0, 0, 0.25 }, bottom = { 0, 0, 0, 0.25 } },
			edges = { left = { 3, { 0, 0, 0, 1, accent = 1 } } },
		},
		tabPage = { padding = "lg", gap = "md", fill = { top = { 0, 0, 0, 0.25 }, bottom = { 0, 0, 0, 0.25 } } },
		-- A tooltip's part after its title (UI.Stats, UI.Rows, a text block): the section gap above it, no surface.
		section = { padding = { "lg", 0, 0, 0 } },
		button = { padding = 0, gap = 0 },
		iconButton = {
			padding = 4,
			fill = { top = { 0.07, 0.06, 0.07, 0.88 }, bottom = { 0.02, 0.02, 0.02, 0.88 } },
			edges = {
				top = { 1, { 0, 0, 0, 1, accent = 0.7 } },
				right = { 1, { 0, 0, 0, 1, accent = 0.45 } },
				bottom = { 1, { 0, 0, 0, 1, accent = 0.45 } },
				left = { 1, { 0, 0, 0, 1, accent = 0.45 } },
			},
			highlight = { color = { 1, 0.92, 0.75, 0.14 } },
		},
		iconSlot = { padding = 3, highlight = { color = { 1, 0.92, 0.75, 0.16 } } },
		-- A column of a section of key numbers (a spell's cost, range, cast, cooldown): a hairline on its left.
		stat = {
			padding = { "xs", "sm", "xs", "sm" },
			edges = { left = { 1, { 1, 1, 1, 0.08, accent = 0.25 } } },
		},
		-- Chat tabs (UI.Dress with states): unselected, selected, flashing (a new message in a tab not shown).
		chatTab = {
			padding = 0,
			fill = { top = { 0.05, 0.04, 0.05, 0.6 }, bottom = { 0.02, 0.02, 0.02, 0.6 } },
			edges = { top = { 1, { 0, 0, 0, 0.8, accent = 0.35 } } },
			highlight = { color = { 1, 0.92, 0.75, 0.12 } },
		},
		chatTabSelected = {
			padding = 0,
			fill = { top = { 0.05, 0.04, 0.05, 0.93, accent = 0.2 }, bottom = { 0.015, 0.012, 0.015, 0.93 } },
			edges = { top = { 2, { 0, 0, 0, 1, accent = 1 } } },
			highlight = { color = { 1, 0.92, 0.75, 0.12 } },
		},
		chatTabFlash = {
			padding = 0,
			fill = { top = { 0, 0, 0, 0.9, accent = 0.55 }, bottom = { 0, 0, 0, 0.9, accent = 0.2 } },
			edges = { top = { 1, { 0, 0, 0, 1, accent = 1 } } },
			highlight = { color = { 1, 0.92, 0.75, 0.12 } },
		},
		-- Ordaen Chat's tabs and input keep a flat look of their own (the chat input over the chat's lines: opaque, so the
		-- text under it never shows through).
		chatInput = {
			padding = 0,
			fill = {
				top = { 0.05, 0.04, 0.05, 1, accent = 0.07 },
				bottom = { 0.015, 0.012, 0.015, 1, accent = 0.025 },
			},
			edges = {
				top = { 1, { 0, 0, 0, 1, accent = 0.8 } },
				right = { 1, { 0, 0, 0, 1, accent = 0.35 } },
				bottom = { 1, { 0, 0, 0, 1, accent = 0.35 } },
				left = { 1, { 0, 0, 0, 1, accent = 0.35 } },
			},
		},
		-- A window the player moves (UI.Window): the panel's surface with room inside. Blizzard's window art comes later.
		-- (Blizzard's metal frame; the top padding clears its title bar.)
		window = {
			padding = { 28, "md", "md", "md" },
			gap = "sm",
			frameArt = WINDOW_ART,
			titleRule = TITLE_RULE,
		},
		-- A window with Blizzard's portrait ring (the portrait itself stays the window's own).
		portraitWindow = {
			padding = { 28, "md", "md", "md" },
			gap = "sm",
			frameArt = PORTRAIT_ART,
		},
		panel = { -- a box holding other things (the minimap drawer): the tooltip surface, no size of its own
			padding = 0,
			frameArt = SMALL_ART,
		},
		dialog = {
			padding = "xl", gap = "lg",
			frameArt = DIALOG_ART,
			titleRule = TITLE_RULE,
		},
		-- An inner pane of a window (Blizzard's inset: a sunken frame inside the metal one), e.g. a list behind its own
		-- border. Ordaen Reskin dresses Blizzard's own insets (frame.Inset) with it.
		inset = {
			padding = "sm", gap = "xs",
			frameArt = INSET_ART,
		},
		-- Blizzard's controls (Ordaen Reskin dresses them, UI.Confirm's buttons are push buttons): drawn from the theme's
		-- control art (themes.jsonc, token control.<kind>) in the state the dress gives (:SetState, `track`): the asset's
		-- piece for that state (a selected tab, a pushed button), or `normal` darker (pushed) or grey (disabled) when it
		-- has none; checked and disabledChecked go over `normal` (the box, then its check). `base`: the piece used as
		-- normal (a scroll stepper's back or forward arrow). `parts` put a part at a side (a dropdown's arrow). `accent`:
		-- the block's accent tints it (an item's quality on its slot). The asset's highlight shows on hover.
		pushButton = { padding = { "sm", "lg", "sm", "lg" }, controlArt = { kind = "pushButton" } },
		-- The panel's cells (Ordaen Panel): our button's side rims only, the panel's wood showing through, edge to edge
		-- (two neighbours' rims make the divider). The panel pads its metal edge's side, so the cells start just
		-- under it (from the panel's top their rims would show as notches above the edge).
		-- Hover: the block's `highlight` (its glow), pressed: `controlState = "pushed"`.
		panelCell = { padding = 0, controlArt = { kind = "panelCell" } },
		-- An important button (the game menu's exits): the accent plate, the same kind of art under its own token.
		pushButtonAccent = { padding = { "sm", "lg", "sm", "lg" },
			controlArt = { kind = "pushButton", token = "control.pushButtonAccent" } },
		closeButton = { padding = 0, controlArt = { kind = "closeButton" } },
		tab = { padding = 0, controlArt = { kind = "tab" } },
		sideTab = { padding = 0, controlArt = { kind = "sideTab" } },
		checkbox = { padding = 0, controlArt = { kind = "checkbox" } },
		-- Its label in the middle of the field, clear of the arrow on the right (the arrow part is as wide as about the
		-- field's height: 26).
		dropdown = { padding = { 0, 30, 0, "md" }, rowAlign = "center", height = 34,
			controlArt = { kind = "dropdown", parts = { arrow = "RIGHT" } } },
		-- (as tall as the buttons, as in the bags layout)
		input = { padding = 0, height = 34, controlArt = { kind = "input" } },
		scrollTrack = { padding = 0, controlArt = { kind = "scrollTrack" } },
		scrollThumb = { padding = 0, controlArt = { kind = "scrollThumb" } },
		scrollStepper = { padding = 0, controlArt = { kind = "scrollStepper", base = "back" } },
		scrollStepperForward = { padding = 0, controlArt = { kind = "scrollStepper", base = "forward" } },
		slot = { padding = 0, controlArt = { kind = "slot", base = "background", accent = true } },
	},
	text = {
		-- No capitals: the size step sets the title apart.
		title = { font = "header", size = "title", color = { 0.96, 0.91, 0.82 } },
		subtitle = { font = "body", size = "small", color = { 0.5, 0.5, 0.5, accent = 0.6 } },
		body = { font = "body", size = "body", color = { 0.89, 0.85, 0.77 } },
		label = { font = "body", size = "small", color = { 0.70, 0.65, 0.56 } },
		value = { font = "body", size = "body", color = { 0.96, 0.93, 0.86 } },
		-- White text on a coloured bar (a meter's names and numbers, the XP bar's label): a 1 px outline instead of a
		-- shadow, over a faint scrim.
		onBar = { font = "body", size = "body", color = { 1, 1, 1 }, outline = true },
		onBarValue = { font = "body", size = "body", color = { 1, 1, 1 }, outline = true },
		hint = { font = "body", size = "small", color = { 0.56, 0.54, 0.50 } },
		-- A control's label (a dropdown's, a push button's): gold with a dark shadow, the game's button text.
		control = { font = "ui", size = "body", color = { 0.941, 0.784, 0.376 }, shadow = true },
		caption = { font = "body", size = "tiny", color = { 0.62, 0.58, 0.51 }, caps = true },
		-- On the world (labels on the minimap): no surface behind them, so they keep a shadow.
		normal = { font = "ui", size = "body", color = { 0.96, 0.86, 0.64 }, shadow = true },
		small = { font = "ui", size = "small", color = { 0.93, 0.91, 0.87 }, shadow = true },
	},
	separators = {
		rule = { space = "sm", width = 1, color = { 0, 0, 0, 0.45, accent = 0.7 } },
		divider = { space = "md", gap = "lg", width = 1, color = { 0, 0, 0, 0.8, accent = 0.55 } },
		caption = { space = "xs", gap = "sm", width = 1, color = { 0, 0, 0, 0.5, accent = 0.5 } },
	},
	bar = {
		height = "md", track = { 0.08, 0.08, 0.09, 0.9 }, trackBottom = { 0.02, 0.02, 0.02, 0.9 },
		edge = { 0.36, 0.31, 0.24, 1 }, fill = { 0, 0, 0, 1, accent = 1 },
		-- A bar built into the panel (a skeuomorphic part of the panel), two constructions to try in game
		-- (Ordaen Core's setting ui.barFrame) until one is picked. All in whole physical pixels.
		frames = {
			-- A bronze bezel like the panel's rim: lit top and left, shaded bottom and right, a dark line inside it.
			bezel = { width = 3, light = { 0.80, 0.64, 0.40, 1 }, mid = { 0.56, 0.43, 0.26, 1 },
				dark = { 0.24, 0.17, 0.10, 1 }, inner = { 0.03, 0.02, 0.015, 1 } },
			-- Cut into the panel: shadow above and left, a light bronze lip below.
			groove = { shadow = { 0, 0, 0, 0.95 }, softShadow = { 0, 0, 0, 0.6 }, lip = { 0.80, 0.64, 0.40, 0.7 },
				side = { 0.56, 0.43, 0.26, 0.55 } },
		},
		recessed = { top = { 0.03, 0.025, 0.02, 1 }, bottom = { 0.09, 0.075, 0.06, 1 } }, -- the track inside a frame
		shade = { 0, 0, 0, 0.45 }, -- the inner shadow under the track's top edge, fading over 3 px
		tick = { { 0, 0, 0, 0.47 }, { 1, 0.94, 0.82, 0.11 } }, -- engraved sections: a dark line, a faint light one
		scrim = 0.38, -- the faint dark gradient under a bar's text (its middle), so white outlined text reads
		scrimWidth = 0.6, -- the share of the bar's width it spreads over, from the middle out
		ahead = 0.5, -- how strong the part ahead of the value (rested) is drawn: the value's colour, fainter
	},
}

Theme.THEMES = THEMES
Theme.ORDER = { "ordaen" }

-- Resolving ------------------------------------------------------------------------------------------

--- A spacing token ("xs".."xl") or number -> UI units. Pure; used by the layout engine for blocks' own values.
local function space(value)
	if type(value) == "string" then
		return Theme.space[value] or 0
	end
	return value
end
Theme.Space = space

local function spaceList(value)
	if type(value) ~= "table" then
		return space(value)
	end
	local out = {}
	for i = 1, #value do
		out[i] = space(value[i])
	end
	return out
end

-- A look's frameArt from the theme's tokens: { layout, scale, background = asset or nil, inset }, or nil when the
-- theme's frame isn't a NineSlice layout.
local function resolveArt(spec, themeName)
	local store = OrdaenCore._SettingsStore
	if not (spec and store) then
		return nil
	end
	local frame = store.Asset("frame", store.TokenIn(themeName, spec.border))
	if not (frame and frame.layout) then
		return nil
	end
	local background = store.Asset("background", store.TokenIn(themeName, spec.background))
	return {
		layout = frame.layout,
		scale = tonumber(store.TokenIn(themeName, spec.scale)) or 1,
		background = background and (background.atlas or background.file) and background or nil,
		inset = spec.inset,
		mirrorTop = spec.mirrorTop,
	}
end

-- A look's controlArt from the theme's tokens: { asset = the control asset (pieces per state), base, parts, accent },
-- or nil when the theme has none for that kind.
local function resolveControl(spec, themeName)
	local store = OrdaenCore._SettingsStore
	if not (spec and store) then
		return nil
	end
	local asset = store.Asset(spec.kind, store.TokenIn(themeName, spec.token or ("control." .. spec.kind)))
	if not asset then
		return nil
	end
	return { asset = asset, base = spec.base or "normal", parts = spec.parts, accent = spec.accent, extend = spec.extend }
end

local function resolveBlock(look, textSize, themeName)
	local out = {}
	for key, value in pairs(look) do
		out[key] = value
	end
	out.frameArt = resolveArt(look.frameArt, themeName)
	out.controlArt = resolveControl(look.controlArt, themeName)
	out.padding = spaceList(look.padding)
	out.gap = spaceList(look.gap)
	out.minWidth = look.minWidth and look.minWidth * textSize
	out.maxWidth = look.maxWidth and look.maxWidth * textSize
	if look.vignette then
		out.vignette = { size = space(look.vignette.size), alpha = look.vignette.alpha }
	end
	return out
end

-- Upper case for `caps` text: ASCII, and Cyrillic (Russian), which string.upper leaves alone.
local CYRILLIC_UPPER = {}
for byte = 176, 191 do -- а..п
	CYRILLIC_UPPER["\208" .. string.char(byte)] = "\208" .. string.char(byte - 32)
end
for byte = 128, 143 do -- р..я
	CYRILLIC_UPPER["\209" .. string.char(byte)] = "\208" .. string.char(byte + 32)
end
CYRILLIC_UPPER["\209\145"] = "\208\129" -- ё

--- `text` in capitals (UTF-8: ASCII and Cyrillic). Pure; the renderer caches its result per element.
---@param text string
---@return string
function Theme.Upper(text)
	return (text:upper():gsub("[\208\209][\128-\191]", CYRILLIC_UPPER))
end

--- The global UI settings: OrdaenCoreDB.ui from Ordaen Core, or the defaults while there are none.
---@return string theme, number textSize
function Theme.Settings()
	local db = rawget(_G, "OrdaenCoreDB")
	local ui = type(db) == "table" and db.ui or nil
	local name = ui and THEMES[ui.theme] and ui.theme or Theme.DEFAULT_THEME
	local size = ui and tonumber(ui.textSize) or Theme.DEFAULT_TEXT_SIZE
	return name, max(Theme.MIN_TEXT_SIZE, min(Theme.MAX_TEXT_SIZE, floor(size + 0.5)))
end

--- Build the resolved theme (numbers and font files, no tokens) from the global settings, or from the
--- arguments (specs). Draws after this use it; caches measured with an older version measure again.
--- Runs once on first use and on each settings change: it creates tables, never call it per draw.
---@param name string|nil theme id
---@param textSize number|nil body text px
function Theme.Apply(name, textSize)
	if name == nil then
		name, textSize = Theme.Settings()
	end
	textSize = textSize or Theme.DEFAULT_TEXT_SIZE
	local source = THEMES[name] or THEMES[Theme.DEFAULT_THEME]
	local scale = textSize / Theme.DEFAULT_TEXT_SIZE
	for key, base in pairs(SPACE) do
		Theme.space[key] = max(1, floor(base * scale + 0.5))
	end
	for key, factor in pairs(SIZE) do
		Theme.size[key] = floor(textSize * factor + 0.5)
	end
	local blocks = {}
	for role, look in pairs(source.blocks) do
		blocks[role] = resolveBlock(look, textSize, name)
	end
	local text = {}
	for role, look in pairs(source.text) do
		text[role] = {
			file = fontFile(look.font),
			size = Theme.size[look.size] or textSize,
			color = look.color,
			shadow = look.shadow or false,
			outline = look.outline or false,
			caps = look.caps or false,
		}
	end
	local separators = {}
	for kind, look in pairs(source.separators) do
		separators[kind] = {
			space = space(look.space), gap = space(look.gap or 0), width = look.width, color = look.color,
		}
	end
	Theme.name = THEMES[name] and name or Theme.DEFAULT_THEME
	Theme.blocks, Theme.text, Theme.separators = blocks, text, separators
	local bar = source.bar
	local db = rawget(_G, "OrdaenCoreDB")
	local chosen = type(db) == "table" and type(db.ui) == "table" and db.ui.barFrame or nil
	Theme.bar = {
		height = space(bar.height), track = bar.track, trackBottom = bar.trackBottom, edge = bar.edge, fill = bar.fill,
		frames = bar.frames, recessed = bar.recessed, shade = bar.shade, tick = bar.tick, scrim = bar.scrim,
		scrimWidth = bar.scrimWidth,
		ahead = bar.ahead,
		-- The construction (ui.barFrame, while the player compares them): a key of `frames`, else the plain edge.
		frame = bar.frames and bar.frames[chosen or "bezel"] and (chosen or "bezel") or nil,
	}
	Theme.accent = source.accent
	Theme.version = Theme.version + 1
end

local function ensure()
	if Theme.version == 0 then
		Theme.Apply()
	end
end
Theme.Ensure = ensure

--- The text look for a style name (body when unknown).
---@return OrdaenUIResolvedText
function Theme.TextStyle(style)
	ensure()
	return Theme.text[style or "body"] or Theme.text.body
end

--- The block look for a style role, or nil.
function Theme.BlockStyle(role)
	ensure()
	return role and Theme.blocks[role] or nil
end

-- Theme tokens (OrdaenCore/themes.jsonc, kept by Ordaen Core's settings store): what addons' looks follow.

--- A token's value in the theme the renderer draws with (e.g. "color.xp" -> { r, g, b }), or nil.
---@param name string
function Theme.Token(name)
	ensure()
	local store = OrdaenCore._SettingsStore
	return store and store.TokenIn(Theme.name, name)
end

--- The asset a theme token names (kind, token): e.g. ("marker", "control.newMarker") -> its data, or nil.
---@param kind string
---@param token string
function Theme.AssetOf(kind, token)
	ensure()
	local store = OrdaenCore._SettingsStore
	return store and store.Asset(kind, store.TokenIn(Theme.name, token)) or nil
end

--- A colour given as { r, g, b, a? } or as a colour token's name ("color.xp"): the colour, or `fallback`.
---@param spec number[]|string|nil
---@param fallback number[]|nil
---@return number[]|nil
function Theme.Color(spec, fallback)
	if type(spec) == "string" then
		local value = Theme.Token(spec)
		return type(value) == "table" and value or fallback
	end
	return spec or fallback
end

local FLAT = "Interface\\Buttons\\WHITE8X8"

--- The bar texture file the theme uses (token bar.texture, an asset of kind "bar").
---@return string
function Theme.BarTexture()
	local store = OrdaenCore._SettingsStore
	local id = Theme.Token("bar.texture")
	local asset = store and id and store.Asset("bar", id)
	return asset and asset.file or FLAT
end

--- The theme's fade time in seconds (token motion.fade).
---@return number
function Theme.Fade()
	return tonumber(Theme.Token("motion.fade")) or 0
end
