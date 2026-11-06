# Tooltips

A tooltip is a top-level block with the `tooltip` style, shown while its owner is hovered. `UI.Tooltip` turns your
block into a tooltip object: the same table, with methods.

```lua
local tip = UI.Tooltip({ { text = "Elwynn Forest", style = "title" } }, { side = "below" })

tip:Show(owner)    -- usually from the owner's enter
tip:Hide()         -- usually from its leave
tip:Refresh()      -- after changing the block's fields
tip:IsShown()
```

On a component you don't call these yourself: `tooltip = tip` in the spec, or `button:Tooltip(tip)`, shows it on
`enter` and hides it on `leave`.

```lua
local zone = UI.Button({ name = "MyZone", parent = Minimap, tooltip = tip, { text = "Elwynn Forest" } })
```

## Placement

`opts.side` says where the tooltip goes, 4 units away from its owner. `opts.x` and `opts.y` add an offset. The opts
belong to the tooltip, given once to `UI.Tooltip`.

| `side` | Tooltip corner → owner corner |
|---|---|
| `"right"` (default) | top-left → top-right |
| `"left"` | top-right → top-left |
| `"below"` | top → bottom |
| `"above"` | bottom → top |
| `"default"` | bottom-right → `GameTooltipDefaultContainer` bottom-right |

`"default"` is for tooltips that belong to nothing on screen. They appear where Blizzard puts its own unanchored
tooltips: the **HUD Tooltip** spot the player moves in Edit Mode.

The tooltip is clamped to the screen, so near an edge it shifts inwards instead of going off screen.

## Scale

Tooltips use the global UI scale only. An anchored tooltip takes its **position** from its owner, never its scale:
a tooltip on a button of an enlarged minimap is the same size as any other tooltip.

## One at a time

All tooltips share one surface frame (`OrdaenUITooltip`), like Blizzard's `GameTooltip`:

- Showing a tooltip replaces whatever tooltip is shown.
- `tip:Hide()` hides only that tooltip. `tip:Hide(owner)` also checks the owner: useful when one tooltip object
  serves several buttons, so a late `leave` from one can't hide it while it's shown for another.
- `tip:Refresh()` redraws only if that tooltip is shown, so it's safe to call from any event.

The surface is on the `TOOLTIP` strata and lets the mouse pass through, so it never blocks clicks on what's under it.

## Live tooltips

Keep the table, change fields, refresh. The framework has no timers: your addon decides when content changes.

```lua
-- Ordaen Minimap's clock: the invites line appears and disappears while the tooltip is open.
local function updateInvites()
  invitesLine.hidden = C_Calendar.GetNumPendingInvites() == 0
  clock:Refresh() -- a component's Refresh also redraws its tooltip
end
```

## One tooltip for many buttons

The drawer's entry buttons share one tooltip object and change its title on hover:

```lua
local entryTitle = { text = "", style = "title" }
local entryTooltip = UI.Tooltip({ entryTitle }, { side = "left" })

local function onEnter(button)
  entryTitle.text = titleOf(button)
  entryTooltip:Show(button.frame)
end
local function onLeave(button)
  entryTooltip:Hide(button.frame)
end
```

## Blizzard's tooltips

Item, unit and spell tooltips are Blizzard's `GameTooltip` and stay that way. A future tooltip addon will restyle
them in place with the theme; they will never be hidden and redrawn as a lookalike.
