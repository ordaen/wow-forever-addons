# Themes

A theme is a data table. The renderer reads it; nothing in it draws. The default theme
(`OrdaenCore_UI/Theme.lua`) uses Blizzard's own art and fonts, so Ordaen UI looks native without anything else
installed.

```lua
ns.Theme = {
  blocks = {   -- per style role: surface art, colours, layout defaults
    tooltip = {
      backdrop = {
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
      },
      background = { 0.09, 0.09, 0.19, 0.95 },
      border = { 1, 1, 1, 1 },
      padding = 10, gap = 2, maxWidth = 300,
    },
  },
  text = {     -- per text style: a font object (a Blizzard global) and a colour
    title = { font = "GameTooltipHeaderText", color = { 1, 1, 1 } },
    hint  = { font = "GameTooltipTextSmall",  color = { 0.5, 0.5, 0.5 } },
    -- subtitle, body, label, value
  },
}
```

## What a style role controls

| Field | Used for |
|---|---|
| `backdrop` | the surface's backdrop (top-level blocks) |
| `background`, `border` | backdrop colours, `{ r, g, b, a }` |
| `padding`, `gap` | defaults when the block doesn't set them |
| `minWidth`, `maxWidth` | defaults when the block doesn't set them |

Layout defaults live in the theme on purpose: a theme with bigger fonts or a thicker border can also give itself
more padding, and every block still fits.

## Changing the look

The plan is a theme addon that replaces these tables (same shape) and ships its art files, with no drawing code. The
API for that isn't designed yet: see [Roadmap](/roadmap).

Inside your addon, don't style: pick a style role and text styles. `color` on an element is the one exception, for
meaning.
