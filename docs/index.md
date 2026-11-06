# Introduction

**Ordaen UI** (`OrdaenCore.UI`) is the UI framework every Ordaen addon uses. Addons describe what they want as plain
Lua tables and work with objects; the framework lays it out and draws it. Addon code never creates font strings,
sets backdrops or measures text.

```lua
local UI = OrdaenCore.UI

local tip = UI.Tooltip({
  { text = "Elwynn Forest", style = "title" },
  { text = "Click: world map", style = "hint" },
}, { side = "below" })

local zone = UI.Button({ name = "MyZone", parent = Minimap, tooltip = tip, { text = "Elwynn Forest" } })
zone:On("click", function() ToggleWorldMap() end)
zone:SetPoint("BOTTOM", Minimap, "TOP", 0, 9)
```

## Principles

These are fixed design rules, recorded in `CLAUDE.md`.

| Rule | What it means for your code |
|---|---|
| **Addons declare, they never render** | You hand over a table. The same calls work in every addon, and behaviour changes in one place. |
| **Everything is a block** | A block is a box with a style role whose children sit in a grid. Text and images are the only other elements. |
| **Objects with methods** | Tooltips and components are objects: `tip:Show(owner)`, `button:On("click", fn)`. |
| **One renderer, themes are data** | The only drawing code is the framework's. Looks come from a theme table, by default Blizzard's own art and fonts. |
| **Nothing is truncated** | Text always wraps. The layout makes room for it. |
| **It costs nothing until used** | The framework is a load-on-demand addon, loaded on first use. Your tables are built once. |

## What exists today

| Part | State |
|---|---|
| Blocks, text (also `format` + `args`) and image (also atlas) elements | Built |
| Grid layout (fixed, `auto`, `fr` columns, gap, padding, spans, widths) | Built, 17 specs |
| Default theme (Blizzard art and fonts; tooltip, button, iconButton, slot) | Built |
| Tooltip objects (`UI.Tooltip`: `:Show`, `:Hide`, `:Refresh`) | Built, used by Ordaen Minimap |
| Components `UI.Block`, `UI.Button` with `:On(event, fn)` for user and game events | Built, used by Ordaen Minimap |
| Windows, inputs (text entry, checkbox, slider), bars, dropdowns | Decided, not built. See [Roadmap](/roadmap) |

## Where to go next

- [Quick start](/guide/quick-start): a tooltip, a button that has it, game events, fast-changing values.
- [Layout](/guide/layout): how the grid decides sizes, with examples.
- [API](/reference/api) and [Block format](/reference/format): every function and field.
