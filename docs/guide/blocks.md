# Blocks and elements

There are three kinds of nodes. A node is a plain Lua table; its fields tell the framework what it is.

| Node | Recognised by | Holds |
|---|---|---|
| **Block** | neither `text` nor `image` | children in its array part, laid out in a grid |
| **Text** | `text = "..."` | one string, always wrapped to its cell |
| **Image** | `image = file` | a texture path or file ID |

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

## Composites

Buttons, bars and dropdowns won't be new element types. They will be blocks made of blocks, text and images, with
event listeners. That part is planned: see [Roadmap](/roadmap).
