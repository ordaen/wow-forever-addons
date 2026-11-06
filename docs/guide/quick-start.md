# Quick start

## Requirements

Your addon depends on Ordaen Core, like every Ordaen addon. The UI framework comes with it: Ordaen Core always loads
the small entry point `OrdaenCore.UI`, and loads the rest (the addon **Ordaen Core - UI**) the first time a tooltip is
shown. There is nothing else to install or list.

## 1. Describe the tooltip once

Build the table at file load, not in `OnEnter`. It is data: a block with the `tooltip` style and its children.

```lua
local UI = OrdaenCore.UI
local BELOW = { side = "below" }

local zoneName = { text = "", style = "title" }       -- filled in on hover
local subzoneName = { text = "", style = "subtitle" }
local zoneTooltip = {
  style = "tooltip",
  zoneName,
  subzoneName,
  { text = L.ZONE_TOOLTIP_MAP, style = "hint" },
}
```

## 2. Show and hide it

Change the fields you need, then show it. `ShowTooltip` places the tooltip next to its owner; `HideTooltip` hides it
only if this owner's tooltip is the one shown.

```lua
zoneButton:SetScript("OnEnter", function(self)
  zoneName.text = GetRealZoneText() or ""
  subzoneName.text = GetSubZoneText() or ""
  subzoneName.hidden = subzoneName.text == "" or subzoneName.text == zoneName.text
  UI.ShowTooltip(self, zoneTooltip, BELOW)
end)
zoneButton:SetScript("OnLeave", function(self) UI.HideTooltip(self) end)
```

`hidden = true` removes a child from the layout completely: no empty line, no gap.

## 3. Keep it live

A tooltip that shows changing data stays the same table. Change its fields from your own event or timer and call
`RefreshTooltip`. It redraws only if that owner's tooltip is shown, so you can call it unconditionally.

```lua
local invitesLine = { text = L.CALENDAR_PENDING, color = { 1, 0.5, 0.1 }, hidden = true }
local clockTooltip = {
  style = "tooltip",
  invitesLine,
  { text = L.TIME_TOOLTIP_CALENDAR, style = "hint" },
  { text = L.TIME_TOOLTIP_CLOCK, style = "hint" },
}

local function updateInvites() -- on CALENDAR_UPDATE_PENDING_INVITES
  invitesLine.hidden = C_Calendar.GetNumPendingInvites() == 0
  UI.RefreshTooltip(timeButton)
end
```

::: tip Use color for meaning
`color` on an element is for information (pending invites in orange, an error in red). Decoration belongs in the
theme, so a theme addon can restyle it.
:::

## 4. Lay out rows

Children of a block sit in a grid. With two columns, children fill the cells left to right, row by row:

```lua
local mailTooltip = {
  style = "tooltip",
  columns = { "auto", "1fr" },   -- labels as wide as the widest label, values get the rest
  gap = { 12, 2 },               -- 12 between columns, 2 between rows
  { text = "Mail", style = "title", colSpan = 2 },
  { text = "From", style = "label" },    { text = "Auction House", style = "value", align = "right" },
  { text = "Items", style = "label" },   { text = "3", style = "value", align = "right" },
}
```

```
┌──────────────────────────────┐
│ Mail                         │
│ From            Auction House│
│ Items                       3│
└──────────────────────────────┘
```

[Layout](/guide/layout) explains how the column widths are chosen.

## If the framework can't load

If **Ordaen Core - UI** is disabled in the AddOns list or missing, the first `ShowTooltip` prints one chat line
naming the reason. After that, tooltips stay off quietly. Your code doesn't need to check anything.
