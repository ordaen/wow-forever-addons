# Roadmap

Decisions are recorded in `CLAUDE.md` ("UI framework `OrdaenCore.UI`"). Nothing on this page is built yet.

## Built since the first version

- **Events:** `:On(event, fn)` / `:Off` on components, for the player's input and Blizzard's game events.
- **Components:** `UI.Block`, `UI.Button`, tooltip objects (`UI.Tooltip`).
- **Shortcut** `tooltip = tip` on a component.
- **Hover highlight** for styles that have one (`iconButton`, `slot`), and `LockHighlight` for a highlight shown on
  request.
- **Three themes** (`ordaen`, `blizzard`, `minimal`) and one **design scale** (spacing tokens, text tiers) from the
  player's global text size, both chosen in Ordaen Core's settings; **accent** colours; surfaces drawn without art.
- **Separators** (rule, divider, caption), **bars**, **Shift rows**, **headers** (`UI.Header`).
- **Confirmation dialogs** (`UI.Confirm`), one at a time for every addon, Escape as cancel.

See [Blocks and elements](/guide/blocks#components) and the [API](/reference/api).

## Decided

### Elements and components

- New elements, because they need WoW's own widgets: **text entry** (EditBox), **checkbox** (CheckButton),
  **slider**.
- **Dropdowns** are components made of blocks, not elements.
- **Settings pages** built from UI components, from the `settings = { ... }` spec in `NewAddon` (replacing the
  Blizzard Settings builder in Ordaen Core): dropdowns, sliders, checkboxes, colour pickers, text input, key
  bindings, action buttons, settings that grey out when their parent is off.
- **Windows** are top-level components with a fixed, saved position and size. The framework remembers them.
- **Your own components** later: `UI.Component(name, { build = ..., methods = ... })`, so an addon can define a kind
  of thing once and reuse it.

### Out of scope for v1

Secure actions (casting, using items, targeting). They need Blizzard's secure templates, and touching those from
addon code causes blocked-action errors. An addon that needs one uses Blizzard's templates directly.

## Open

- **More shortcuts** beyond `tooltip = tip`.
- **Positions of top-level blocks**: anchored, at the cursor, fixed and remembered.
- **Interaction states** beyond hover: pressed, disabled, selected.
- **Resizing** windows.
- **Scrolling** and long repeated lists.
- **Theme addon API**: how a theme addon adds its own set of three themes.
- **Library**: packaging the framework for addons outside Ordaen.
- **Blizzard's tooltips**: restyled in place by a future tooltip addon, with the theme.
