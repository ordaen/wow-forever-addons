# Layout

Every block is a grid, in the spirit of CSS grid. You declare columns; children fill the cells in reading order; the
engine works out every width, height and position. The engine is pure Lua (`OrdaenCore_UI/Layout.lua`) with no WoW
calls, so all of it is tested outside the game.

## Columns

`columns` is a list of tracks. Without it a block has one column, `{ "1fr" }`.

| Track | Width |
|---|---|
| `40` | Fixed: exactly 40 UI units. |
| `"auto"` | As wide as the widest content in that column (on one line). |
| `"1fr"`, `"2fr"` | A share of the width that is left, by weight. |

```lua
{ columns = { 20, "1fr", "3fr" }, gap = 0, width = 100,
  { text = "a" }, { text = "b" }, { text = "c" } }
-- 20 | 20 | 60
```

## Placement

Children go left to right and wrap to the next row when the row is full. A child with `colSpan` that doesn't fit
the rest of the row starts a new row. Hidden children take no cell.

```lua
{ columns = { "auto", "auto" }, gap = { 4, 0 },
  { text = "A rather long title", colSpan = 2 },  -- row 1, both columns
  { text = "a" }, { text = "b" },                  -- row 2
}
```

## Gap and padding

```lua
gap = 4             -- 4 between columns and 4 between rows
gap = { 12, 2 }     -- { column gap, row gap }
padding = 8         -- all sides
padding = { 2, 4, 6, 8 } -- { top, right, bottom, left }
```

Both default to the style's theme values (`tooltip`: padding 10, gap 2), else 0.

## Width

| Declared | Result |
|---|---|
| nothing | **Shrink to fit**: as wide as the content needs. |
| `width = n` | Exactly `n`. |
| `minWidth`, `maxWidth` | Clamp either of the above. A `tooltip` has `maxWidth = 300` from the theme. |

Height is never declared for content: it follows from the rows. `height = n` forces it.

## How sizes are worked out

Two passes, like a browser.

**Pass 1: column widths.**

1. Fixed columns take their width.
2. `auto` columns take the widest one-line width of their single-column children. When the block shrinks to fit,
   `fr` columns do the same, so a tooltip is as wide as its longest line.
3. A spanning child that needs more than its columns give widens them: `fr` columns first, else `auto` columns,
   else the last column it covers.
4. The block's width is now its declared width, or the sum of columns, gaps and padding, clamped by
   `minWidth`/`maxWidth`.
5. Room left over goes to `fr` columns by weight. Too little room shrinks `fr` columns first, then `auto` columns,
   in proportion to their width. No column goes below 8 units.

**Pass 2: heights.** Each child is sized in its cell: text is wrapped to the cell width and measured, images keep
their height, nested blocks are laid out at the cell width. A row is as tall as its tallest cell. `align` then places
each child inside its cell.

## Examples

### Label and value rows

```lua
{ columns = { "auto", "1fr" }, gap = { 10, 0 }, width = 200,
  { text = "Mail" },     { text = "3",  align = "right" },
  { text = "Auctions" }, { text = "12", align = "right" } }
```

```
|Mail     |                       3|
|Auctions |                      12|
 ^ auto: widest label   ^ 1fr: the rest, values right-aligned
```

### Text wider than the tooltip

```lua
{ maxWidth = 60, { text = "one two three four" } } -- natural width 108
```

The block stops at 60, the text wraps to two lines, and the row grows to fit them. Nothing is cut off.

### A nested block in a column

```lua
local details = { padding = 2, { text = "Elite" }, { text = "Level 60" } }
{ columns = { "auto", "1fr" }, gap = 0, width = 100,
  { image = "icon", size = 16 }, details }
```

The icon column is 16 wide; `details` is laid out at the remaining 84 and the row takes the taller of the two.

## Guarantees

The specs check these on varied trees (spans, nested blocks, narrow widths, long text):

- No child extends past its block's padding box, sideways or at the bottom.
- Every text gets at least the height it needs when wrapped to its width.
- Results are reused tables: laying out the same block again creates nothing.
