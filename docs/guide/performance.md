# Performance

Ordaen addons follow one rule: cost as close to nothing as possible. The framework is built for it, and asks the same
of your code.

## What the framework guarantees

| | |
|---|---|
| **Not loaded until used** | Players load only `UI.lua`. The framework loads on the first tooltip. |
| **Nothing per frame** | No `OnUpdate`, no timers. Work happens only on Show and Refresh. |
| **No garbage per show** | Layout results are reused tables. Font strings and textures are pooled per surface. |
| **Measure once** | Text sizes are cached per element; only changed text is measured again. |
| **One surface** | All tooltips share one frame. Hovering a hundred buttons creates nothing new. |

## What your code should do

**Build tables once**, at file load or creation. Don't build a block in an `enter` listener:

```lua
-- Good: built once, a field changes
local title = { text = "", style = "title" }
local tip = UI.Tooltip({ title })
local function onEnter(button)
  title.text = nameOf(button)
  tip:Show(button.frame)
end

-- Bad: a new table tree (and new cache entries) on every hover
local function onEnter(button)
  UI.Tooltip({ { text = nameOf(button), style = "title" } }):Show(button.frame)
end
```

**Make listeners once.** `:On(event, fn)` stores `fn`; a function written inline in a loop or an event handler is a
new closure each time. Define listeners at file level and pass them.

**Refresh from your own events.** `tip:Refresh()` is cheap when the tooltip isn't shown (it returns at once), so
call it whenever your data changes instead of tracking whether the tooltip is open.

**Use `format` + `args`** for text that changes often. `{ format = "%.1f, %.1f", args = { x, y } }` is drawn with
WoW's `SetFormattedText`: no Lua string per change, and the text is measured again only when an argument changes.

**Use `hidden`** for optional lines instead of rebuilding the block.

**Object style costs nothing that matters.** All instances of a component share one metatable; a method call is one
table lookup.
