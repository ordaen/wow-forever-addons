# Themes and roles

Every role below exists in all three themes (`ordaen`, `blizzard`, `minimal`). The exact values live in
`OrdaenCore_UI/Theme.lua`, the single source; this page says what each role is for and how the themes differ.
How themes work: [Themes](/guide/themes).

## Block styles

| Style | For | `ordaen` | `blizzard` | `minimal` |
|---|---|---|---|---|
| `tooltip` | tooltips (`UI.Tooltip` sets it) | gradient fill, 2 px accent top edge, 1 px sides, vignette, padding `lg` | tooltip backdrop, padding `md` | flat fill, 1 px grey border, padding `md` |
| `header` | the first block of a tooltip (`UI.Header`) | accent band to the tooltip's edges | no surface | no surface |
| `button` | clickable text without a surface | | | |
| `iconButton` | a small square icon button (a 20 px icon makes 28 px) | dark fill, accent edges, warm highlight | tooltip backdrop, Blizzard highlight | flat fill, grey border |
| `slot` | a cell in a grid of icons (the drawer) | highlight only | Blizzard highlight | highlight only |
| `panel` | a box holding other things (the minimap drawer) | tooltip surface | tooltip backdrop | flat fill, grey border |
| `tab` | a tab not shown (chat tabs, `UI.Dress` states) | dark, thin accent top edge | tooltip backdrop, dim | faint grey fill |
| `tabSelected` | the tab shown | tooltip surface, accent top edge | tooltip backdrop, gold border | grey fill, accent line |
| `tabFlash` | a tab with a new message | accent fill | gold-tinted backdrop | lighter fill, accent line |
| `dialog` | confirmation dialogs (`UI.Confirm`) | like `tooltip`, padding `xl` | Blizzard's popup art | like `tooltip`, padding `xl` |
| `pushButton` | a dialog's buttons | accent band, accent edges, highlight | tooltip backdrop on red, Blizzard highlight | grey fill and border |

Tooltips are 12 to 25 ems wide in `ordaen`, at most 25 ems in the others.

## Text styles

| Style | Tier | Use |
|---|---|---|
| `title` | `title` (`large` in `blizzard`, `minimal`) | the name of the thing; capitals in `ordaen` |
| `subtitle` | `small` (`body` in `blizzard`) | under the title; tinted by the accent |
| `body` | `body` | running text (default) |
| `label` | `small` | the left side of a label/value row |
| `value` | `body` | the right side |
| `hint` | `small` | what a click does |
| `caption` | `tiny` | a section name; capitals |
| `normal` | `body` | names on the world (the minimap's zone), with a shadow |
| `small` | `small` | small readouts on the world (coordinates, clock), with a shadow |

Text without a surface behind it (`normal`, `small`) keeps a shadow in every theme; text on a surface has none in
`ordaen` and `minimal`. Fonts are the client's own files (`GameTooltipText`, `GameTooltipHeaderText`,
`GameFontNormal`), so every language's glyphs are there. An unknown style falls back to `body`.

## Separators and bars

| Element | `ordaen` | `blizzard` | `minimal` |
|---|---|---|---|
| `separator = "rule"` | 1 px accent hairline | 1 px grey | faint 1 px |
| `separator = "divider"` | two hairlines with a gap | one line | one line |
| `separator = "caption"` | caption text between two lines | gold caption, no lines | caption between faint lines |
| `bar` | accent fill on a dark track, flat texture | Blizzard green, Blizzard's bar texture | thin accent fill, flat |

Bar colours by meaning are theme tokens (`themes.jsonc`): `color.xp`, `color.quest`, `color.rested`, and
`color.reputation.hated` .. `color.reputation.exalted`; the texture is `bar.texture`.
