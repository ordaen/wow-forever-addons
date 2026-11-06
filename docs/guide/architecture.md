# Architecture

## Files

```
addons/OrdaenCore/
  UI.lua                    entry point, always loaded: UI.Tooltip objects, UI.Block/UI.Button, the types
  OrdaenCore_UI/            "Ordaen Core - UI", load-on-demand, shipped in the Core zip
    Layout.lua              grid engine, pure Lua
    Theme.lua               default theme, data only
    Render.lua              the only drawing code: measures and draws
    Component.lua           Block and Button: instances, :On events, the shared game-event frame
    Tooltip.lua             the tooltip surface and placement; hands everything to UI.lua
tests/OrdaenCore/
  layout_spec.lua           the engine with a fake text measurer
  ui_spec.lua               entry point + framework with fake frames
```

The build derives the load order inside `OrdaenCore_UI` from what each file reads when it loads: Layout, Theme,
Render (reads `ns.Layout`, `ns.Theme`), Component (reads `ns.Render`), Tooltip (reads `ns.Render`,
`ns.Component`). `ordaen build --explain` prints the reasons.

## Loading

```
tip = UI.Tooltip(block)           sets a metatable on your table; loads nothing
        │
tip:Show(owner) / UI.Button(spec)
        │
        ▼
UI.lua: framework loaded? ── yes ──► impl.ShowTooltip / impl.Button
        │ no
        ▼
C_AddOns.LoadAddOn("OrdaenCore_UI")
        │
        ├─ fails: one chat line with the reason; Block/Button return nil, tooltips stay off
        ▼
Tooltip.lua runs: OrdaenCore.UI._Provide({ ShowTooltip, ..., Block, Button })
```

`tip:Hide()` and `tip:Refresh()` never load the framework: if it isn't loaded, there is nothing to hide or redraw.
A component needs its frame at once, so `UI.Block`/`UI.Button` load the framework when called; Ordaen Minimap
makes its components at login.

## Components and events

```
UI.Button(spec)
  CreateFrame("Button", spec.name, spec.parent)   mouse off until a user listener exists
  instance = setmetatable({ frame, block = spec, listeners }, one shared metatable)
  spec.on → :On(...), spec.tooltip → :Tooltip(...)
  Render.Draw(frame, spec)
```

- **User events:** `:On("click", fn)` turns the mouse on, registers clicks, and sets the frame's `OnClick` to a
  dispatcher made once at load (one per event name). The dispatcher finds the instance by frame and runs its
  listeners. No closure per instance or per `:On`.
- **Game events:** one shared frame for all components. An event is registered while at least one instance listens
  and unregistered after the last `:Off`.
- **Listeners** run through `securecallfunction` when the client has it, so one failing listener doesn't stop the
  others.

## Drawing a block

```
Tooltip.Show(block, owner, opts)    (and Component:Refresh, on the component's own frame)
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
