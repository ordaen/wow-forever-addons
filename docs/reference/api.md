# API

Everything is on `OrdaenCore.UI`. Things with state are objects with `:` methods (see "Lua code style" in
`CLAUDE.md`). Names become permanent at the first release of Ordaen Core; until then they may still change.

## UI.Tooltip

```lua
local tip = OrdaenCore.UI.Tooltip(block, opts)
```

Turns `block` into a tooltip object and returns the same table, now with methods. `style` defaults to `"tooltip"`.
Creating one loads nothing; the framework loads on the first `:Show`.

| Parameter | Type | |
|---|---|---|
| `block` | table | children: text, images, nested blocks; see [Block format](/reference/format) |
| `opts` | table, optional | placement: `{ side, x, y }` |

`opts.side`: `"right"` (default), `"left"`, `"below"`, `"above"`, or `"default"` (Edit Mode's HUD Tooltip position).
`opts.x`, `opts.y`: an extra offset in UI units.

### tip:Show(owner)

Shows the tooltip next to `owner` (a frame), replacing any tooltip that is shown.

### tip:Hide(owner?)

Hides the tooltip if it is the one shown. With `owner`, only if it is shown for that owner. Never loads the framework.

### tip:Refresh()

Redraws the tooltip from its current fields, if it is shown. Does nothing otherwise; cheap to call from any event.

### tip:IsShown()

Whether this tooltip is the one on screen.

## UI.Header

```lua
local header = OrdaenCore.UI.Header({ title = "Stormwind", subtitle = "Trade District", icon = 134400 })
local tip = OrdaenCore.UI.Tooltip({ header, { text = "..." } })
header.titleText.text = "Elwynn Forest"; tip:Refresh()
```

Returns a header block (data, style `header`): the icon on the left with an optional plate under it, the title and
subtitle beside it, on the theme's header band. Put it first in a tooltip. Loads nothing.

| Spec field | Type | |
|---|---|---|
| `title` | string | drawn in the `title` style |
| `subtitle` | string, optional | hidden without one |
| `icon` | texture path or file ID, optional | `iconSize` (default 32), `texCoord` |
| `plate` | string, optional | a short text under the icon (a level, a count) |
| `accent` | `{ r, g, b }`, optional | tints the band |

Fields to change afterwards: `titleText`, `subtitleText`, `iconImage`, `plateText` (elements), `accent`.

## UI.Confirm

```lua
local ask = OrdaenCore.UI.Confirm({
  text = L.CONFLICT_TOOLTIPS,
  buttons = {
    { text = L.KEEP_OURS, onClick = keepOurs },
    { text = L.KEEP_THEIRS, onClick = keepTheirs },
    { text = L.DECIDE_LATER },
  },
  onCancel = decideLater, -- Escape
})
ask:Show()
```

Turns `spec` into a confirm object (the same table, with methods): a message and up to four buttons, centred
near the top of the screen in the theme's `dialog` look, buttons in `pushButton`. Creating one loads nothing.

| Field | Type | |
|---|---|---|
| `text` | string | the message; change it before `:Show()` to reuse the object |
| `buttons` | list | `{ text, onClick? }`, left to right; `onClick` runs after the dialog closed |
| `onCancel` | function, optional | runs when the player closes it with Escape |

`ask:Show()` shows it (loading the framework the first time). There is one dialog for every Ordaen addon: a second
confirm shown while one is open waits until it closes. `ask:Hide()` closes it, or takes it out of the queue,
without running `onCancel`. `ask:IsShown()`. Labels follow the text rules (`text-en`, `text-ru`); Blizzard's
`OKAY`, `CANCEL`, `YES`, `NO` where they fit.

## UI.Block and UI.Button

```lua
local label = OrdaenCore.UI.Block(spec)
local button = OrdaenCore.UI.Button(spec)
```

Create a component: an object that owns a WoW frame and draws `spec` (a block) on it. `UI.Button` uses the
`button` style unless the spec names another. Both load the framework, and return `nil` if it can't load (the
player gets one chat line).

| Spec field | Type | |
|---|---|---|
| `name` | string, optional | global name of the frame |
| `parent` | frame, optional | default `UIParent` |
| `strata`, `level` | optional | frame strata and level |
| `tooltip` | tooltip object, optional | shown while the mouse is over it |
| `on` | table, optional | listeners, as with `:On` |
| block fields | | `style`, `columns`, `width`, children, ... see [Block format](/reference/format) |

### c:On(event, fn) and c:Off(event, fn)

Call `fn(c, ...)` on `event`, until `:Off` with the same function. Several listeners per event run in the order they
were added.

| Event | Source | `...` |
|---|---|---|
| `click` | the player | mouse button (`"LeftButton"`, ...), down |
| `enter`, `leave` | the player | |
| `mousedown`, `mouseup` | the player | mouse button |
| `dragstart`, `dragstop` | the player (left button) | |
| `wheel` | the player | delta |
| `render` | the framework, after it drew the block (created, `:Refresh()`, a theme change, a panel placed) | width, height |
| `ZONE_CHANGED`, any Blizzard event | the game | Blizzard's arguments, unchanged |

Sizes change only when the framework draws a block (or when the UI scale changes, which re-places panels), so anything
that follows a block's size listens to `render` instead of watching the frame's size. The frame takes the mouse only
once a user listener exists, so a label without listeners lets clicks through to what's
under it. Game events share one frame, which registers an event only while some component listens. Unknown event
names are an error.

Only plain functions: there is no `On(event, object, "Method")` form. A listener that needs another object is a
closure made once.

### c:Tooltip(tip)

Shows `tip` while the mouse is over the component. The same as `tooltip = tip` in the spec.

### c:RectOf(element)

Where an element of the block (a child at any depth) was drawn last: x and y from the frame's top left, width and
height; nil when it isn't drawn (hidden). Read it in a `render` listener to put another frame exactly over a cell,
for example a Blizzard button over the cell drawn for it.

### c:Refresh()

Lays out and redraws after the block's fields changed. Also refreshes its tooltip.

### c:SetText(text)

Sets the first text element and redraws.

### Placement and visibility

These go straight to the frame: `SetPoint`, `ClearAllPoints`, `GetPoint`, `SetParent`, `GetParent`, `Show`, `Hide`,
`IsShown`, `IsVisible`, `SetShown`, `SetFrameStrata`, `GetFrameStrata`, `SetFrameLevel`, `GetFrameLevel`, `SetScale`,
`GetScale`, `GetEffectiveScale`, `GetCenter`, `GetWidth`, `GetHeight`, `IsMouseOver`, `LockHighlight`,
`UnlockHighlight`, `SetAlpha`.

`c.frame` is the WoW frame itself, for anchoring other frames to the component.

## UI.Panel

```lua
local bar = UI.Panel({ columns = { "auto", "1fr", "auto" }, left, middle, right }, { edge = "bottom" })
bar:FadeTo(0)   -- hidden: no clicks, but enter/leave still arrive (show on mouseover)
bar:FadeTo(1)
```

A component pinned to a screen edge (style `panel` unless the spec names one), with the methods of
`UI.Block`/`UI.Button` plus:

| Option | Default | |
|---|---|---|
| `edge` | `"bottom"` | `"bottom"`, `"top"`, `"left"`, `"right"` |
| `fit` | `"full"` | `"full"`: the whole edge; `"center"`: as long as its content, centred on the edge |
| `offset` | 0 | distance from the edge |

### p:FadeTo(alpha, seconds?)

Fades to `alpha` over `seconds` (default: the theme's `motion.fade` token), by an animation the game runs (no
OnUpdate). Below full alpha the panel takes no clicks, so they reach what's underneath, but enter and leave still
arrive, so a "show on mouseover" rule can bring it back.

### p:IsFaded()

Whether it is faded or fading below full alpha.

### p:Place()

Places it again after its options changed. A resolution or UI scale change re-places it by itself.

### UI.ScreenInset(edge)

```lua
local bottom = UI.ScreenInset("bottom") -- how far up a bottom panel reaches
EventRegistry:RegisterCallback("OrdaenUI.InsetsChanged", onInsets, owner)
```

How much of a screen edge (`"bottom"`, `"top"`, `"left"`, `"right"`) the panels cover: the thickest panel on that
edge plus its offset, in UI units, 0 when there is none. A faded panel still covers its edge. Frames that sit beside
the panels (Ordaen Chat above a bottom panel) read it and follow `OrdaenUI.InsetsChanged`, which fires when an inset
changes (a panel placed, resized, moved to another edge). Loads nothing.

## UI.Dress

```lua
local dress = UI.Dress(CharacterMicroButton, { atlas = "UI-HUD-MicroMenu-CharacterInfo-Up" })
```

Puts one of Blizzard's frames in our look without taking it over. Its art (textures only, never its text) goes to
alpha 0 and stays there when Blizzard fades it back in; our block is drawn under it (style `iconButton` unless
`style` says otherwise). Blizzard's frame stays on top and keeps its clicks, menus and scripts. While the mouse is
over Blizzard's frame, ours shows its highlight. A button takes our block's size; with `size = "frame"` our block
covers the frame instead and its size stays Blizzard's or Edit Mode's (chat windows, inputs, tabs). Dressing the
same frame again returns the same object.

```lua
UI.Dress(ChatFrame1, { style = "panel", size = "frame", cover = ChatFrame1Background, art = { ChatFrame1Background } })
local tab = UI.Dress(ChatFrame1Tab, { style = "tab", size = "frame", states = { selected = "tabSelected" } })
tab:SetState("selected") -- from a hook on Blizzard's own state change, never by polling
```

| Option | Default | |
|---|---|---|
| `icon` | | texture path or file ID |
| `atlas` | | atlas, instead of `icon` |
| `iconSize` | 20 | |
| `iconColor` | | the icon's tint: a colour or a colour token (`"color.icon"` for glyph icons) |
| `style` | `"iconButton"` | |
| `clickable` | `frame.Button`, else the frame | the frame that gets the mouse |
| `size` | `"look"` | `"frame"`: cover the frame, keep its size |
| `cover` | the frame | with `size = "frame"`: the region to cover (a background reaching past the frame) |
| `extend` | | with `size = "frame"`: `{ left, right, top, bottom }` added around `cover` |
| `art` | every texture of the frame and its children | the textures to hide, when children hold content |
| `states` | | state -> style role for `d:SetState(state)` |

### Dressing with a whole block

`block = { ... }` draws our look as that block (a row of cells, say) instead of an icon, in the role `style`.
`style = "none"` draws nothing: only Blizzard's art is hidden (a button that sits over a cell of another block).

```lua
local row = { columns = { "auto", "1fr" }, gap = 0, padding = 0, menuCell, {} }
local dress = UI.Dress(ChatFrame1EditBox, { style = "panel", size = "frame", block = row })
UI.Dress(ChatFrameMenuButton, { style = "none", size = "frame" })
dress.look:On("render", function(look)
	local x, y, w, h = look:RectOf(menuCell)
	-- put ChatFrameMenuButton over it
end)
```

### d:SetState(state)

Switches to the style `states[state]`, or back to `style` for any other state (nil).

### UI.DressFont(target, style)

```lua
UI.DressFont(ChatFrame1, "body")
UI.DressFont(ChatFrame1Tab:GetFontString(), "label")
```

Puts the theme's font and the global text size of text style `style` (default `body`) on Blizzard's own text: a
FontString, an EditBox or a chat window. Blizzard's font flags stay. When Blizzard sets the font again (the chat
font size menu), ours comes back, and a theme or text size change re-applies it. Addons never call `SetFont`.

### d:SetIcon(icon, atlas)

Changes the icon.

### d:Refresh()

Hides art Blizzard added after dressing (a badge, a re-created child) and redraws our block.

### d:Undress() and d:Apply()

`:Undress()` gives the art back its alpha and the frame its size, and hides our block. `:Apply()` dresses it again.

## Internal

Not for addon code.

| Function | |
|---|---|
| `UI._Provide(functions)` | called by `OrdaenCore_UI` when it loads, to hand over its implementation |
| `UI._Describe()` | the last tooltip as measured and drawn, for dev-mode dumps; builds tables |

## Global settings

The player picks the theme and the text size for every Ordaen addon in Ordaen Core's settings
(`OrdaenCoreDB.ui`); see [Themes](/guide/themes). Ordaen Core calls `OrdaenCore.UI._SettingsChanged()` after a
change, which redraws everything on screen. Addons don't call it and don't read the settings.
