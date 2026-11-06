# Architecture

## Files

```
addons/OrdaenCore/
  UI.lua                    entry point, always loaded (about 70 lines)
  OrdaenCore_UI/            "Ordaen Core - UI", load-on-demand, shipped in the Core zip
    Layout.lua              grid engine, pure Lua
    Theme.lua               default theme, data only
    Render.lua              the only drawing code: measures and draws
    Tooltip.lua             the tooltip role: one shared surface, placement
tests/OrdaenCore/
  layout_spec.lua           the engine with a fake text measurer
  ui_spec.lua               entry point + framework with fake frames
```

The load order inside `OrdaenCore_UI` is Layout, Theme, Render, Tooltip: Render reads `ns.Layout` and `ns.Theme`
when it loads, Tooltip reads `ns.Render`.

## Loading

```
addon calls UI.ShowTooltip
        │
        ▼
UI.lua: framework loaded? ── yes ──► impl.ShowTooltip
        │ no
        ▼
C_AddOns.LoadAddOn("OrdaenCore_UI")
        │
        ├─ fails: one chat line with the reason; every later call does nothing
        ▼
Tooltip.lua runs: OrdaenCore.UI._Provide({ ShowTooltip, HideTooltip, RefreshTooltip, Describe })
        │
        ▼
impl.ShowTooltip
```

`HideTooltip` and `RefreshTooltip` never load the framework: if it isn't loaded, there is nothing to hide or redraw.

## Drawing a block

```
Tooltip.Show(owner, block, opts)
  Render.Draw(surface, block)
    Layout.Run(block, nil, ctx)        pass 1 widths, pass 2 heights; ctx.measure = the renderer's measurer
    draw each laid-out item            font strings and textures from the surface's pools
    hide pooled objects not used now
    backdrop and colours from the theme
    surface:SetSize(width, height)
  anchor the surface to the owner
  show it
```

- **Measuring** happens on a hidden font string that belongs to the surface, so it uses the surface's scale. See
  [Text](/guide/text#measured-where-it-is-drawn).
- **Pools**: each surface keeps the font strings and textures it created and reuses them on every draw. What a
  smaller tooltip doesn't need is hidden, not destroyed.
- **Results**: the layout writes into one result table per block, reused on every run.

## The renderer contract

The layout engine knows nothing about WoW. It gets two functions in `ctx`:

| Function | Returns |
|---|---|
| `measure(element, width)` | natural size when `width` is nil; else `width` and the wrapped height |
| `defaults(style)` | the theme's layout defaults for a style role |

This is why the engine can be tested with a fake measurer, and why one renderer serves every theme.
