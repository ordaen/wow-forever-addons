# Tooltips

A tooltip is a top-level block with the `tooltip` style, shown while its owner is hovered. There is no separate
tooltip type: the same block format, a hover trigger, a position next to the owner.

```lua
UI.ShowTooltip(owner, block, opts)  -- usually in OnEnter
UI.HideTooltip(owner)               -- usually in OnLeave
UI.RefreshTooltip(owner)            -- after changing the block's fields
```

## Placement

`opts.side` says where the tooltip goes, 4 units away from its owner. `opts.x` and `opts.y` add an offset.

| `side` | Tooltip corner → owner corner |
|---|---|
| `"right"` (default) | top-left → top-right |
| `"left"` | top-right → top-left |
| `"below"` | top → bottom |
| `"above"` | bottom → top |
| `"default"` | bottom-right → `GameTooltipDefaultContainer` bottom-right |

```lua
local LEFT = { side = "left" }       -- build opts once, like the block
UI.ShowTooltip(self, mainTooltip, LEFT)
```

`"default"` is for tooltips that belong to nothing on screen. They appear where Blizzard puts its own unanchored
tooltips: the **HUD Tooltip** spot the player moves in Edit Mode.

The tooltip is clamped to the screen, so near an edge it shifts inwards instead of going off screen.

## Scale

Tooltips use the global UI scale only. An anchored tooltip takes its **position** from its owner, never its scale:
a tooltip on a button of an enlarged minimap is the same size as any other tooltip.

## One at a time

All tooltips share one surface frame (`OrdaenUITooltip`), like Blizzard's `GameTooltip`:

- Showing a tooltip replaces whatever tooltip is shown.
- `HideTooltip(owner)` hides it only if that owner's tooltip is the one shown. A late `OnLeave` from another button
  can't hide yours.
- `RefreshTooltip(owner)` redraws only if that owner's tooltip is shown, so it's safe to call from any event.

The surface is on the `TOOLTIP` strata and lets the mouse pass through, so it never blocks clicks on what's under it.

## Live tooltips

Keep the table, change fields, refresh. The framework has no timers: your addon decides when content changes.

```lua
-- Ordaen Minimap's clock: the invites line appears and disappears while the tooltip is open.
local function updateInvites()
  invitesLine.hidden = C_Calendar.GetNumPendingInvites() == 0
  UI.RefreshTooltip(timeButton)
end
```

## Blizzard's tooltips

Item, unit and spell tooltips are Blizzard's `GameTooltip` and stay that way. A future tooltip addon will restyle
them in place with the theme; they will never be hidden and redrawn as a lookalike.
