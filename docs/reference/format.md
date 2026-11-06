# Block format

## Block

A table without `text`, `image`, `separator` or `bar`. Its array part holds the children.

| Field | Type | Default | |
|---|---|---|---|
| `style` | string | none | style role in the theme: `tooltip`, `header`, `button`, `iconButton`, `slot` |
| `accent` | `{ r, g, b }` | parent's, else the theme's | tints the surface, lines and accented text; for meaning |
| `columns` | list of tracks | `{ "1fr" }` | number (fixed), `"auto"`, `"Nfr"` |
| `gap` | token or number, or `{ column, row }` | theme, else 0 | space between cells |
| `padding` | token or number, or `{ top, right, bottom, left }` | theme, else 0 | space inside the edge |
| `width` | number | shrink to fit | exact width |
| `minWidth` | number | theme | |
| `maxWidth` | number | theme | `tooltip`: 25 ems (300 at text size 12) |
| `height` | number | from content | forces the height |
| `[1..n]` | nodes | | the children, in order |

## Text

| Field | Type | Default | |
|---|---|---|---|
| `text` | string | `text` or `format` | |
| `format` | string | | a format string, drawn with `args` through WoW's `SetFormattedText` |
| `args` | list | | values for `format`; change them in place, then refresh |
| `style` | string | `"body"` | `title`, `subtitle`, `body`, `label`, `value`, `hint`, `caption`, `normal`, `small` |
| `color` | `{ r, g, b [, a] }` | the style's | 0 to 1; for meaning only |
| `caps` | boolean | the style's | capitals (ASCII and Cyrillic); plain `text` only, a `format` keeps its case |

`format` + `args` is for values that change often (coordinates, a clock): no Lua string is built per change, and
the text is measured again only when an argument's value changes.

## Image

| Field | Type | Default | |
|---|---|---|---|
| `image` | texture path or file ID | `image` or `atlas` | |
| `atlas` | atlas name | | |
| `width` | number | `size`, else 16 | |
| `height` | number | `size`, else `width` | |
| `size` | number | | sets both |
| `texCoord` | `{ left, right, top, bottom }` | whole texture | e.g. `{ 0.08, 0.92, 0.08, 0.92 }` trims an icon's border |
| `color` | `{ r, g, b, a? }` or a colour token | untinted | a tint; `"color.icon"` for white glyph icons (`OrdaenCore/media/icon-*`) |

## Separator

| Field | Type | |
|---|---|---|
| `separator` | `"rule"`, `"divider"`, `"caption"` | a hairline, a stronger break, or `text` between two lines |
| `text` | string | the caption (drawn in the `caption` style) |

Separators take their cell's whole width; give them `colSpan` in a block with several columns.

## Bar

| Field | Type | Default | |
|---|---|---|---|
| `bar` | number | | the value, from `min` to `max` |
| `min`, `max` | number | 0, 1 | the range |
| `quest` | number | the value | a second part behind the value, up to here, lighter (XP from completed quests) |
| `overlay` | number | `quest` | a third part, dimmed, up to here (rested XP) |
| `color` | `{ r, g, b [, a] }` or a colour token (`"color.xp"`) | the theme's (accent) | for meaning: health, progress, XP |
| `questColor`, `overlayColor` | the same | `color` | |
| `animate` | boolean | false | changes glide (the game animates the status bar, no Lua per frame), a gain flashes for a moment (the theme's `motion.fade`), a value that drops (a new level) runs to the end first, then starts again |
| `sections` | integer | none | split into this many sections by one-pixel lines in the theme's bar edge colour, like Blizzard's experience bar (20) |
| `text`, or `format` + `args` | | | text on the bar, centred; `style`, `textColor` as for text |
| `height` | number | the theme's (`sm`) | |

The texture is the theme's `bar.texture` token. Colours given as token names follow the theme, so an addon never
picks a colour of its own for a look (`color.xp`, `color.quest`, `color.rested`, `color.reputation.<standing>`
with the standings `hated` to `exalted`).

## Any child

| Field | Type | Default | |
|---|---|---|---|
| `hidden` | boolean | false | skipped: no cell, no gap |
| `colSpan` | number | 1 | capped at the column count |
| `align` | `"left"`, `"center"`, `"right"` | left | placement inside the cell |
| `shift` | boolean | none | `true`: only while Shift is held; `false`: only while it isn't (a "Hold Shift" hint) |

A tooltip with `shift` rows listens to `MODIFIER_STATE_CHANGED` only while it is shown and redraws when Shift
goes down or up.

## Spacing tokens

`"xs"`, `"sm"`, `"md"`, `"lg"`, `"xl"`: 2, 4, 8, 12, 16 at text size 12, scaled with the player's text size. See
[Themes](/guide/themes#one-design-scale).

## Tracks

| Track | Meaning |
|---|---|
| `24` | fixed width |
| `"auto"` | widest one-line content of the column |
| `"1fr"`, `"2.5fr"` | share of the remaining width, by weight |

A column never shrinks below 8 units. See [Layout](/guide/layout) for the full algorithm.
