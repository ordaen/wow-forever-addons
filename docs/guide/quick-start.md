# Quick start

## Requirements

Your addon depends on Ordaen Core, like every Ordaen addon. The UI framework comes with it: Ordaen Core always loads
the small entry point `OrdaenCore.UI`, and loads the rest (the addon **Ordaen Core - UI**) the first time it's
needed. There is nothing else to install or list.

## 1. A tooltip

Build it once, at file load. `UI.Tooltip` gives your table methods; it stays your data.

```lua
local UI = OrdaenCore.UI

local zoneName = { text = "", style = "title" }
local subzoneName = { text = "", style = "subtitle" }
local zoneTooltip = UI.Tooltip({
  zoneName,
  subzoneName,
  { text = L.ZONE_TOOLTIP_MAP, style = "hint" },
}, { side = "below" })
```

Change fields when your data changes, and refresh. `:Refresh()` redraws only if the tooltip is shown, so you can
call it from any event.

```lua
local function onZoneChanged()
  zoneName.text = GetRealZoneText() or ""
  subzoneName.text = GetSubZoneText() or ""
  subzoneName.hidden = subzoneName.text == "" or subzoneName.text == zoneName.text
  zoneTooltip:Refresh()
end
```

`hidden = true` removes a child from the layout completely: no empty line, no gap.

## 2. A button that has it

A component owns a frame and draws its block on it. `tooltip = …` shows the tooltip while the mouse is over it.

```lua
local zoneLabel = { text = "", style = "normal" }

local zone = UI.Button({
  name = "MyAddonZone",
  parent = Minimap,
  tooltip = zoneTooltip,
  zoneLabel,
})
zone:On("click", function() ToggleWorldMap() end)
zone:SetPoint("BOTTOM", Minimap, "TOP", 0, 9)
```

`zone:SetText(GetMinimapZoneText())` changes the label and redraws it.

## 3. Game events

Components take Blizzard's events with the same `:On`, by their upper-case names:

```lua
local invitesLine = { text = L.CALENDAR_PENDING, color = { 1, 0.5, 0.1 }, hidden = true }
local clockTooltip = UI.Tooltip({ invitesLine, { text = L.TIME_TOOLTIP_CALENDAR, style = "hint" } })

local clock = UI.Button({ name = "MyAddonClock", parent = Minimap, tooltip = clockTooltip,
  { format = "%02d:%02d", args = { 0, 0 }, style = "small" } })

clock:On("CALENDAR_UPDATE_PENDING_INVITES", function(self)
  invitesLine.hidden = C_Calendar.GetNumPendingInvites() == 0
  self:Refresh() -- also redraws its tooltip if it's shown
end)
```

::: tip Use color for meaning
`color` on an element is for information (pending invites in orange, an error in red). Decoration belongs in the
theme, so a theme addon can restyle it.
:::

## 4. Values that change often

For text that changes every second or faster, use `format` and `args` instead of building a string. The renderer
passes them to WoW's `SetFormattedText`, so no Lua string is created per change.

```lua
local coordValue = { format = "%.1f, %.1f", args = { 0, 0 }, style = "small" }
local coords = UI.Block({ name = "MyAddonCoords", parent = Minimap, coordValue })

local function onMove(x, y)
  coordValue.args[1], coordValue.args[2] = x, y
  coords:Refresh()
end
```

`UI.Block` is a component without click semantics: with no listeners it takes no mouse, so clicks go to the minimap.

## 5. Rows

Children of a block sit in a grid. With two columns, children fill the cells left to right, row by row:

```lua
local mailTooltip = UI.Tooltip({
  columns = { "auto", "1fr" },   -- labels as wide as the widest label, values get the rest
  gap = { 12, 2 },               -- 12 between columns, 2 between rows
  { text = "Mail", style = "title", colSpan = 2 },
  { text = "From", style = "label" },  { text = "Auction House", style = "value", align = "right" },
  { text = "Items", style = "label" }, { text = "3", style = "value", align = "right" },
})
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

If **Ordaen Core - UI** is disabled in the AddOns list or missing, the first use prints one chat line naming the
reason. `UI.Block` and `UI.Button` then return `nil`, and tooltips stay off quietly.
