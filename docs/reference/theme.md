# Themes and roles

Only the `ordaen` theme is built for now (`blizzard` and `minimal` are planned: [Themes](/guide/themes)). The exact
values live in `OrdaenCore_UI/Theme.lua`, the single source; this page says what each role is for and how it looks.
How themes work: [Themes](/guide/themes).

## Block styles

| Style | For | `ordaen` |
|---|---|---|
| `tooltip` | tooltips (`UI.Tooltip` sets it) | gradient fill, 2 px accent top edge, 1 px sides, vignette, padding `lg` |
| `header` | the first block of a tooltip (`UI.Header`) | accent band to the tooltip's edges |
| `button` | clickable text without a surface | |
| `iconButton` | a small square icon button (a 20 px icon makes 28 px) | dark fill, accent edges, warm highlight |
| `slot` | a cell in a grid of icons (the drawer) | highlight only |
| `stat` | a column of key numbers (a spell's cost, range, cast, cooldown) | a hairline on its left |
| `panel` | a box holding other things (the minimap drawer) | tooltip surface |
| `input` | a text input over other text (the chat input) | opaque tooltip surface |
| `tab` | a tab not shown (chat tabs, `UI.Dress` states) | dark, thin accent top edge |
| `tabSelected` | the tab shown | tooltip surface, accent top edge |
| `tabFlash` | a tab with a new message | accent fill |
| `dialog` | confirmation dialogs (`UI.Confirm`) | like `tooltip`, padding `xl` |
| `pushButton` | a dialog's buttons | accent band, accent edges, highlight |

Tooltips are 12 to 25 ems wide.

## Text styles

| Style | Tier | Use |
|---|---|---|
| `title` | `title` | the name of the thing, as written (the size sets it apart) |
| `subtitle` | `small` | under the title; tinted by the accent |
| `body` | `body` | running text (default) |
| `label` | `small` | the left side of a label/value row |
| `value` | `body` | the right side |
| `hint` | `small` | what a click or key does: a tooltip's `hints` and `hotkey` |
| `onBar` | `body` | white text on a coloured bar (a meter's names, the XP bar's label): outlined, no shadow |
| `onBarValue` | `body` | the numbers on a coloured bar: outlined, no shadow |
| `caption` | `tiny` | a section name; capitals |
| `normal` | `body` | names on the world (the minimap's zone), with a shadow |
| `small` | `small` | small readouts on the world (coordinates, clock), with a shadow |

Text without a surface behind it (`normal`, `small`) keeps a shadow; text on a surface has none.
Fonts are the client's own files (`GameTooltipText`, `GameTooltipHeaderText`,
`GameFontNormal`), so every language's glyphs are there. An unknown style falls back to `body`.

## Separators and bars

| Element | `ordaen` |
|---|---|
| `separator = "rule"` | 1 px accent hairline |
| `separator = "divider"` | two hairlines with a gap |
| `separator = "caption"` | caption text between two lines |
| `bar` | accent fill on a dark gradient track, Blizzard's bar texture, a black 1 px edge |

Bar colours by meaning are theme tokens (`themes.jsonc`): `color.xp`, `color.quest`, `color.rested`, and
`color.reputation.hated` .. `color.reputation.exalted` (Blizzard's own colours, slightly tuned); the
texture is `bar.texture`. A theme's bar may have an `edge` colour: one physical pixel around the bar with its corners
left out, a small radius instead of Blizzard's curved ends. Changes glide (exponential ease-out), a gain flashes
softly over the new part, a new level runs the bar to the end and starts again.
