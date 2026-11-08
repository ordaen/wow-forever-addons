# Roadmap

Decisions are recorded in `CLAUDE.md` ("UI framework `OrdaenCore.UI`"). Nothing on this page is built yet.

## Built since the first version

- **Events:** `:On(event, fn)` / `:Off` on components, for the player's input and Blizzard's game events.
- **Components:** `UI.Block`, `UI.Button`, tooltip objects (`UI.Tooltip`).
- **Shortcut** `tooltip = tip` on a component.
- **Hover highlight** for styles that have one (`iconButton`, `slot`), and `LockHighlight` for a highlight shown on
  request.
- **The `ordaen` theme** (`blizzard` and `minimal` are planned, see below) and one **design scale** (spacing tokens,
  text tiers) from the player's global text size, both chosen in Ordaen Core's settings; **accent** colours.
- **Blizzard's window art** on windows, tooltips, panels, dialogs and insets (NineSlice layouts from theme tokens, the
  border at half size on small surfaces), **open sides** (`open`, `:SetOpen`), background **cover-fit** (an atlas at
  its own aspect, cropped) or tiling.
- **Blizzard's control art** for tabs, side tabs, push and close buttons, check boxes, dropdowns, inputs, scroll bars
  and item slots, drawn in the control's state.
- **Dressing** draws a window, tab or input on Blizzard's frame itself; `track` follows a control's own state
  (pressed, disabled, checked, selected); `borderAbove` puts a window's border over its content; `UI.HasStyle`.
- **Sections** for tooltips: `UI.Stats` (key numbers in columns) and `UI.Rows` (name and value), the theme's
  section gap between parts.
- **Separators** (rule, divider, caption), **bars**, **Shift rows**, **headers** (`UI.Header`).
- **Confirmation dialogs** (`UI.Confirm`), one at a time for every addon, Escape as cancel.
- **Windows** (`UI.Window`): dragged, closed by Escape, their position remembered by the framework; **text entry**
  (`UI.Input`, an EditBox in the theme's look, embedded in a block).

See [Blocks and elements](/guide/blocks#components) and the [API](/reference/api).

## Decided

### Elements and components

- New elements, because they need WoW's own widgets: **checkbox** (CheckButton), **slider**.
- **Dropdowns** are components made of blocks, not elements.
- **Settings pages** built from UI components, from each addon's `settings.jsonc` (replacing the Blizzard
  Settings builder in Ordaen Core): dropdowns, sliders, checkboxes, colour pickers, text input, key
  bindings, action buttons, settings that grey out when their parent is off.
- **Window sizes** the player sets, remembered like their positions.
- **Control art still to draw**: the theme's control `size`, and the masks (a side tab's, an item slot icon's rounded
  mask).
- **Your own components** later: `UI.Component(name, { build = ..., methods = ... })`, so an addon can define a kind
  of thing once and reuse it.

### Out of scope for v1

Secure actions (casting, using items, targeting). They need Blizzard's secure templates, and touching those from
addon code causes blocked-action errors. An addon that needs one uses Blizzard's templates directly.

## Open

- **More shortcuts** beyond `tooltip = tip`.
- **Positions of top-level blocks**: anchored, at the cursor, fixed and remembered.
- **Interaction states** beyond hover for our own components (pressed, disabled, selected); dressed Blizzard
  controls have them (`track`).
- **Partly open sides**: an edge open along part of its length (the panel's top only under the chat).
- **Resizing** windows.
- **Scrolling** and long repeated lists.
- **The `blizzard` and `minimal` themes** (mostly Blizzard's default look; little to no textures): planned, not
  built.
- **Theme addon API**: how a theme addon adds its own set of three themes.
- **Library**: packaging the framework for addons outside Ordaen.
