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

## Text styles

| Style | Font object | Colour |
|---|---|---|
| `title` | `GameTooltipHeaderText` | `{ 1, 1, 1 }` |
| `subtitle` | `GameTooltipText` | `{ 1, 0.82, 0 }` |
| `body` | `GameTooltipText` | `{ 1, 1, 1 }` |
| `label` | `GameTooltipText` | `{ 1, 0.82, 0 }` |
| `value` | `GameTooltipText` | `{ 1, 1, 1 }` |
| `hint` | `GameTooltipTextSmall` | `{ 0.5, 0.5, 0.5 }` |

A font object name that doesn't exist falls back to `GameFontNormal`; an unknown text style falls back to `body`.
