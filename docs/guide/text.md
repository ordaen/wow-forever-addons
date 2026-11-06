# Text

## Styles

A text element names a style; the theme maps it to a font object and a colour.

| Style | Font (default theme) | Colour | Use |
|---|---|---|---|
| `title` | `GameTooltipHeaderText` | white | the first line, names |
| `subtitle` | `GameTooltipText` | gold | a second heading line |
| `body` | `GameTooltipText` | white | default for text without a style |
| `label` | `GameTooltipText` | gold | the left side of a row |
| `value` | `GameTooltipText` | white | the right side of a row |
| `hint` | `GameTooltipTextSmall` | grey | "Click: …" lines at the bottom |

## Wrapping

Text always wraps, and nothing is ever truncated with "…".

- In a shrink-to-fit block, text that fits stays on one line and sets the column width.
- When the block hits its `maxWidth`, or the column is narrower than the text, the text wraps at word boundaries
  and its row grows.
- A single word wider than its cell breaks inside the word, so it still fits.

## Measuring

The layout engine asks the renderer for two sizes per text:

| Question | Answer |
|---|---|
| natural size (`width = nil`) | width on one line + 1, and that line's height |
| wrapped size (`width = n`) | the height when wrapped to `n` |

The extra unit on the natural width makes sure rounding never wraps a line that fits.

Both answers are cached per element and recomputed only when its text, font, width or the scale changes. Changing
one tooltip line measures that line again; the rest come from the cache.

### Measured where it is drawn

WoW rasterizes fonts at whole-pixel sizes for a frame's **effective scale** (its own scale times all its parents').
The same text in the same font is therefore a little wider or narrower in UI units at a different scale.

The renderer measures each text with a hidden font string **on the surface it will draw on**, so measuring and
drawing always share the scale and the font. This was a real bug: text measured on an unparented frame (scale 1)
but drawn under `UIParent` (the UI scale) wrapped onto an extra line and overflowed the tooltip. A spec with
scale-aware fake fonts now guards it.
