# Blocks and elements

Three ideas, from data to objects:

| Concept | What it is | Example |
|---|---|---|
| **Block** | data: a box with a style and a grid of children | `{ style = "tooltip", { text = "…" } }` |
| **Component** | a kind of thing on screen: builds on a block, has behaviour and methods | `Tooltip`, `Block`, `Button` |
| **Instance** | what a component call returns: an object with methods; owns its WoW frame | `local zone = UI.Button({ … })` |

## Nodes

There are three kinds of nodes. A node is a plain Lua table; its fields tell the framework what it is.

| Node | Recognised by | Holds |
|---|---|---|
| **Block** | no `text`, `format`, `image` or `atlas` | children in its array part, laid out in a grid |
| **Text** | `text = "..."` or `format = "..."` | one string, always wrapped to its cell |
| **Image** | `image = file` or `atlas = name` | a texture |

```lua
local block = {
  style = "tooltip",                                    -- a block
  { text = "Deadmines", style = "title" },              -- text
  { image = "Interface\\Icons\\INV_Misc_Map_01", size = 24 }, -- image
  { columns = { "auto", "1fr" },                        -- a nested block
    { text = "Level" }, { text = "17-26", align = "right" } },
}
```

## Blocks

A block is a box. It has a **style role** (which part of the theme it uses), optional size limits, and children.
The children are cells of the block's grid: see [Layout](/guide/layout).

The style role gives a block its look **and** its layout defaults. A `tooltip` block gets the tooltip backdrop, a
padding of 10, a row gap of 2 and a maximum width of 300 from the theme, unless the block sets those fields itself.

```lua
{ style = "tooltip", padding = 4, { text = "Tight" } }  -- theme look, own padding
```

Only the top-level block's style draws a surface (backdrop and colours) today. Nested blocks are used for
arrangement: a two-column section inside a one-column tooltip, for example.

## Text

```lua
{ text = "You have new calendar invitations", style = "body", color = { 1, 0.5, 0.1 }, align = "left" }
```

- `style` picks a text style from the theme (font and colour): `title`, `subtitle`, `body` (default), `label`,
  `value`, `hint`.
- `color` overrides the style's colour, as `{ r, g, b }` or `{ r, g, b, a }` from 0 to 1. Use it for meaning only.
- Text is never cut off. It wraps at word boundaries, and a word longer than its cell breaks inside the word.

See [Text](/guide/text) for how text is measured.

## Images

```lua
{ image = 134400, size = 16 }                       -- file ID, 16 x 16
{ image = "Interface\\Icons\\Spell_Nature_Sleep", width = 32, height = 16 }
```

Without a size an image is 16 × 16. `height` defaults to `width`. An image wider than its cell is narrowed to the
cell; its height stays.

## Fields every child can have

| Field | Effect |
|---|---|
| `hidden = true` | Skipped entirely: no cell, no gap. Toggle it and refresh. |
| `colSpan = n` | Takes `n` columns (capped at the block's column count). |
| `align` | `"left"`, `"center"` or `"right"` inside its cell. Default: left. |

## Components

A component puts a block on screen as an object. Today there are three:

| Component | Made with | Frame | Use |
|---|---|---|---|
| Tooltip | `UI.Tooltip(block, opts)` | the one shared tooltip surface | hover information |
| Block | `UI.Block(spec)` | its own | labels, icons, readouts |
| Button | `UI.Button(spec)` | its own | the same with the `button` style; clickable once it has a `click` listener |

```lua
local bag = UI.Button({
  name = "MyBagButton", parent = Minimap, style = "iconButton",
  { image = "Interface\\Icons\\INV_Misc_Bag_10", size = 20 },
})
bag:On("click", function(self, mouseButton) ToggleBackpack() end)
bag:On("dragstart", startDragging)
```

The spec is a block (style, columns, children) plus the component's own fields: `name`, `parent`, `strata`,
`level`, `tooltip`, `on`. Change the block's fields and call `:Refresh()`; `:SetText()` is a shortcut for the first
text. Placement (`SetPoint`, `Show`, ...) goes straight to the frame, and `instance.frame` is the frame itself.

All instances of a component share one metatable, so methods cost one table lookup and nothing is copied per
instance. Bars and dropdowns will be components made the same way: see [Roadmap](/roadmap).
