# Introduction

**Ordaen UI** (`OrdaenCore.UI`) is the UI framework every Ordaen addon uses. Addons describe what they want as plain
Lua tables; the framework lays it out and draws it. Addon code never creates font strings, sets backdrops or measures
text.

```lua
local UI = OrdaenCore.UI

local tooltip = {
  style = "tooltip",
  { text = "Elwynn Forest", style = "title" },
  { text = "Click: world map", style = "hint" },
}

button:SetScript("OnEnter", function(self) UI.ShowTooltip(self, tooltip) end)
button:SetScript("OnLeave", function(self) UI.HideTooltip(self) end)
```

## Principles

These are fixed design rules, recorded in `CLAUDE.md`.

| Rule | What it means for your code |
|---|---|
| **Addons declare, they never render** | You hand over a table. The same calls work in every addon, and behaviour changes in one place. |
| **Everything is a block** | A block is a box with a style role whose children sit in a grid. Text and images are the only other elements. |
| **One renderer, themes are data** | The only drawing code is the framework's. Looks come from a theme table, by default Blizzard's own art and fonts. |
| **Nothing is truncated** | Text always wraps. The layout makes room for it. |
| **It costs nothing until used** | The framework is a load-on-demand addon, loaded on the first tooltip. Your tables are built once. |

## What exists today

| Part | State |
|---|---|
| Blocks, text and image elements | Built |
| Grid layout (fixed, `auto`, `fr` columns, gap, padding, spans, widths) | Built, 17 specs |
| Default theme (Blizzard tooltip art and fonts) | Built |
| Tooltips (`ShowTooltip`, `HideTooltip`, `RefreshTooltip`) | Built, used by Ordaen Minimap |
| Events (`on = { click = fn, ... }`), buttons, windows, inputs | Decided, not built. See [Roadmap](/roadmap) |

## Where to go next

- [Quick start](/guide/quick-start): your first tooltip, and how to keep it live.
- [Layout](/guide/layout): how the grid decides sizes, with examples.
- [API](/reference/api) and [Block format](/reference/format): every function and field.
