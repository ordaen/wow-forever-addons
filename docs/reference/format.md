# Block format

## Block

A table without `text` or `image`. Its array part holds the children.

| Field | Type | Default | |
|---|---|---|---|
| `style` | string | none | style role in the theme, e.g. `"tooltip"` |
| `columns` | list of tracks | `{ "1fr" }` | number (fixed), `"auto"`, `"Nfr"` |
| `gap` | number or `{ column, row }` | theme, else 0 | space between cells |
| `padding` | number or `{ top, right, bottom, left }` | theme, else 0 | space inside the edge |
| `width` | number | shrink to fit | exact width |
| `minWidth` | number | theme | |
| `maxWidth` | number | theme | `tooltip`: 300 |
| `height` | number | from content | forces the height |
| `[1..n]` | nodes | | the children, in order |

## Text

| Field | Type | Default | |
|---|---|---|---|
| `text` | string | `text` or `format` | |
| `format` | string | | a format string, drawn with `args` through WoW's `SetFormattedText` |
| `args` | list | | values for `format`; change them in place, then refresh |
| `style` | string | `"body"` | `title`, `subtitle`, `body`, `label`, `value`, `hint`, `normal`, `small` |
| `color` | `{ r, g, b [, a] }` | the style's | 0 to 1; for meaning only |

`format` + `args` is for values that change often (coordinates, a clock): no Lua string is built per change, and
the text is measured again only when an argument's value changes.

## Image

| Field | Type | Default | |
|---|---|---|---|
| `image` | texture path or file ID | `image` or `atlas` | |
| `atlas` | atlas name | | |
| `width` | number | `size`, else 16 | |
| `height` | number | `size`, else `width` | |
| `size` | number | | sets both |
| `texCoord` | `{ left, right, top, bottom }` | whole texture | e.g. `{ 0.08, 0.92, 0.08, 0.92 }` trims an icon's border |

## Any child

| Field | Type | Default | |
|---|---|---|---|
| `hidden` | boolean | false | skipped: no cell, no gap |
| `colSpan` | number | 1 | capped at the column count |
| `align` | `"left"`, `"center"`, `"right"` | left | placement inside the cell |

## Tracks

| Track | Meaning |
|---|---|
| `24` | fixed width |
| `"auto"` | widest one-line content of the column |
| `"1fr"`, `"2.5fr"` | share of the remaining width, by weight |

A column never shrinks below 8 units. See [Layout](/guide/layout) for the full algorithm.
