# Themes

How Ordaen UI looks is data: a theme says which sizes, fonts, colours and surface effects each style role gets, and
the one renderer draws it. Your addon names roles (`style = "title"`, `gap = "sm"`) and never numbers or colours,
so every Ordaen addon looks the same and follows the player's settings by itself.

## The player chooses, once, for every Ordaen addon

Ordaen Core's settings page (Options > AddOns > Ordaen Core, "Appearance") holds two global settings:

| Setting | Saved as | Values |
|---|---|---|
| Theme | `OrdaenCoreDB.ui.theme` | `ordaen` (default), `blizzard`, `minimal` |
| Text size | `OrdaenCoreDB.ui.textSize` | body text height, 10 to 16 px (default 12) |

A change redraws everything on screen at once: Ordaen Core calls `OrdaenCore.UI._SettingsChanged()`, which
rebuilds the theme and redraws every component and the shown tooltip. Nothing reloads.

## Three themes, always

This is the rule for every theme set we ship (CLAUDE.md, "UI framework"):

| Theme | Look |
|---|---|
| `ordaen` | Ours, the default. Flat surfaces drawn without art: a dark vertical gradient, pixel-exact edges brighter on top, a soft darkened rim, a header band, warm text without shadows, titles in capitals. Tinted by an **accent** colour. |
| `blizzard` | Blizzard's tooltip art (backdrop), Blizzard's colours and shadowed text: looks like the game. |
| `minimal` | Flat and quiet: one solid fill, a one-pixel grey border, plain text, no effects. |

Every theme defines every role, so your addon never needs to know which one is on.

## One design scale

All sizes come from the text size the player picked. At 12 px:

| Spacing token | `xs` | `sm` | `md` | `lg` | `xl` |
|---|---|---|---|---|---|
| UI units | 2 | 4 | 8 | 12 | 16 |

| Text tier | `tiny` | `small` | `body` | `large` | `title` |
|---|---|---|---|---|---|
| × text size | 0.75 | 0.9 | 1 | 1.17 | 1.42 |

At another text size, every step is multiplied by `textSize / 12` and rounded, so proportions stay the same.
Tooltip widths are in ems: `maxWidth = 25` in a theme means 25 × the text size.

Use the tokens in your blocks: `gap = "sm"`, `padding = { "md", "lg", "md", "lg" }`. A plain number still works,
for sizes that belong to art (a 20 px icon), not to text.

## Accent

```lua
UI.Tooltip({ accent = { 0.64, 0.21, 0.93 }, UI.Header({ title = "Thunderfury" }), ... })
```

`accent = { r, g, b }` on a block tints its surface, its lines and accented text (the subtitle) in the `ordaen`
theme; children inherit it. Use it for meaning: an item's quality, a zone's PvP colour. Without one, the theme's
own accent is used (bronze in `ordaen`, as the minimap's rim).

Theme colours are written as formulas, `{ r, g, b, a, accent = k }`: the colour plus k × the accent. One theme
entry then tints correctly for any accent, and no table is made per accent.

## What a style role controls

| Field | Used for |
|---|---|
| `padding`, `gap` | defaults when the block doesn't set them (tokens) |
| `minWidth`, `maxWidth` | defaults, in ems |
| `fill` | `{ top = colour, bottom = colour }`: a vertical gradient, drawn on one white texture |
| `edges` | `{ top, right, bottom, left }`, each `{ physical px, colour }`: whole pixels at any UI scale |
| `vignette` | `{ size = token, alpha }`: the rim darkened inwards |
| `bleed` | a nested block's surface reaches over its parent's padding to the edges (the header band) |
| `backdrop`, `background`, `border` | Blizzard art instead of a fill (`blizzard` theme) |
| `highlight` | `{ texture = path }` or `{ color = { r, g, b, a } }`, shown while the mouse is over it |

Nested blocks with a style draw their own surface, so a `header` inside a `tooltip` gets its band.

## Credits

The `ordaen` theme's approach (accent-driven surfaces drawn without textures, gradient band, edges brighter on top,
vignette, capitals for titles, hairline separators) follows the design of
[PrettyTooltip](https://github.com/FallenShard/PrettyTooltip) (MIT, © 2026 FallenShard). The values are our own
scale; no code was taken.
