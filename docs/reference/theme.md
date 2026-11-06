# Default theme

The values in `OrdaenCore_UI/Theme.lua`. All of it is Blizzard's own art and fonts.

## Block styles

### `tooltip`

| Field | Value |
|---|---|
| `backdrop.bgFile` | `Interface\Tooltips\UI-Tooltip-Background` |
| `backdrop.edgeFile` | `Interface\Tooltips\UI-Tooltip-Border` |
| `backdrop.edgeSize` | 16 |
| `backdrop.insets` | 4 on each side |
| `background` | `{ 0.09, 0.09, 0.19, 0.95 }` (Blizzard's tooltip colour) |
| `border` | `{ 1, 1, 1, 1 }` |
| `padding` | 10 |
| `gap` | 2 |
| `maxWidth` | 300 |

### `button`

Clickable text without a surface (Ordaen Minimap's zone name and clock): padding 0, gap 0. The default style of
`UI.Button`.

### `iconButton`

A small square icon button with a dark surface, the Ordaen Dev gear button's look: the tooltip backdrop with
background `{ 0, 0, 0, 0.8 }` and border `{ 1, 1, 1, 1 }`, padding 4 (a 20 px icon makes a 28 px button), and
`Interface\Buttons\ButtonHilight-Square` as hover highlight.

### `slot`

A cell in a grid of icons (the drawer's entries): no surface, padding 3, the same hover highlight.

## Text styles

| Style | Font object | Colour | Use |
|---|---|---|---|
| `title` | `GameTooltipHeaderText` | `{ 1, 1, 1 }` | |
| `subtitle` | `GameTooltipText` | `{ 1, 0.82, 0 }` | |
| `body` | `GameTooltipText` | `{ 1, 1, 1 }` | |
| `label` | `GameTooltipText` | `{ 1, 0.82, 0 }` | |
| `value` | `GameTooltipText` | `{ 1, 1, 1 }` | |
| `hint` | `GameTooltipTextSmall` | `{ 0.5, 0.5, 0.5 }` | |
| `normal` | `GameFontNormal` | `{ 1, 0.82, 0 }` | names on the screen |
| `small` | `GameFontHighlightSmall` | `{ 1, 1, 1 }` | small readouts |

A font object name that doesn't exist falls back to `GameFontNormal`; an unknown text style falls back to `body`.
