# API

All functions are on `OrdaenCore.UI`. Names become permanent at the first release of Ordaen Core; until then they
may still change.

## ShowTooltip

```lua
OrdaenCore.UI.ShowTooltip(owner, block, opts)
```

Shows `block` as a tooltip for `owner`, replacing any tooltip that is shown. Loads the framework on the first call.

| Parameter | Type | |
|---|---|---|
| `owner` | frame | what the tooltip belongs to and is placed next to |
| `block` | table | a block with `style = "tooltip"`; see [Block format](/reference/format) |
| `opts` | table, optional | placement only: `{ side, x, y }` |

`opts.side`: `"right"` (default), `"left"`, `"below"`, `"above"`, or `"default"` (Edit Mode's HUD Tooltip position).
`opts.x`, `opts.y`: an extra offset in UI units.

## HideTooltip

```lua
OrdaenCore.UI.HideTooltip(owner)
```

Hides the tooltip if it belongs to `owner`. Does nothing otherwise, and never loads the framework.

## RefreshTooltip

```lua
OrdaenCore.UI.RefreshTooltip(owner)
```

Lays out and redraws `owner`'s tooltip from its block's current fields, if that tooltip is shown. Does nothing
otherwise, and never loads the framework.

## Internal

Not for addon code.

| Function | |
|---|---|
| `UI._Provide(functions)` | called by `OrdaenCore_UI` when it loads, to hand over its implementation |
| `UI._Describe()` | the last tooltip as measured and drawn, for dev-mode dumps; builds tables |
