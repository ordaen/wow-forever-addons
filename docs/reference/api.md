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
| `ZONE_CHANGED`, any Blizzard event | the game | Blizzard's arguments, unchanged |

The frame takes the mouse only once a user listener exists, so a label without listeners lets clicks through to what's
under it. Game events share one frame, which registers an event only while some component listens. Unknown event
names are an error.

Only plain functions: there is no `On(event, object, "Method")` form. A listener that needs another object is a
closure made once.

### c:Tooltip(tip)

Shows `tip` while the mouse is over the component. The same as `tooltip = tip` in the spec.

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

## UI.Dress

```lua
local dress = UI.Dress(CharacterMicroButton, { atlas = "UI-HUD-MicroMenu-CharacterInfo-Up" })
```

Puts one of Blizzard's buttons in our look without taking it over. Its art goes to alpha 0 and our block is drawn
under it (style `iconButton` unless `style` says otherwise). Blizzard's frame stays on top and keeps its clicks,
menus and scripts. While the mouse is over Blizzard's button, ours shows its highlight. The frame takes our block's
size. Dressing the same frame again returns the same object.

| Option | Default | |
|---|---|---|
| `icon` | | texture path or file ID |
| `atlas` | | atlas, instead of `icon` |
| `iconSize` | 20 | |
| `style` | `"iconButton"` | |
| `clickable` | `frame.Button`, else the frame | the frame that gets the mouse |

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
