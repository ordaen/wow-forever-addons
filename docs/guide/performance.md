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

**Build tables once**, at file load. Don't build a block in `OnEnter`:

```lua
-- Good: built once, a field changes
local title = { text = "", style = "title" }
local tip = { style = "tooltip", title }
local function onEnter(self)
  title.text = self.name
  UI.ShowTooltip(self, tip)
end

-- Bad: a new table tree (and new cache entries) on every hover
local function onEnter(self)
  UI.ShowTooltip(self, { style = "tooltip", { text = self.name, style = "title" } })
end
```

**Build opts once** too: `local BELOW = { side = "below" }`.

**Refresh from your own events.** `RefreshTooltip` is cheap when the tooltip isn't shown (it returns at once), so
call it whenever your data changes instead of tracking whether the tooltip is open.

**Use `hidden`** for optional lines instead of rebuilding the block.
