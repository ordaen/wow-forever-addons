# Roadmap

Decisions are recorded in `CLAUDE.md` ("UI framework `OrdaenCore.UI`"). Nothing on this page is built yet.

## Decided

### Events

One `on` table per block, for both kinds of event. Lower-case names are the player's input; Blizzard's upper-case
event names are game events, with Blizzard's arguments unchanged.

```lua
local clock = {
  { text = "14:05" },
  on = {
    click = function(block, mouseButton) ToggleCalendar() end,
    CALENDAR_UPDATE_PENDING_INVITES = function(block) --[[ update fields ]] end,
  },
}
```

- User events: `click`, `enter`, `leave`, `mousedown`, `mouseup`, `dragstart`, `dragstop`, `wheel`; keyboard later.
- No bubbling: only the block with the listener gets the event, as in native WoW.
- One shared event frame registers a game event only while some block listens, and unregisters it after the last.
- A block becomes a mouse-enabled frame only if it has user listeners.

### Elements and composites

- New elements, because they need WoW's own widgets: **text entry** (EditBox), **checkbox** (CheckButton),
  **slider**.
- **Buttons, bars, dropdowns** are composite blocks, not elements.
- **Windows** are top-level blocks with a fixed, saved position and size. The framework remembers them.

### Out of scope for v1

Secure actions (casting, using items, targeting). They need Blizzard's secure templates, and touching those from
addon code causes blocked-action errors. An addon that needs one uses Blizzard's templates directly.

## Open

- **Shortcuts**, e.g. `tooltip = block` on a block instead of `enter`/`leave` listeners.
- **Positions of top-level blocks**: anchored, at the cursor, fixed and remembered.
- **Interaction states**: hover, pressed, disabled, selected.
- **Resizing** windows.
- **Scrolling** and long repeated lists.
- **Theme addon API**: how a theme addon replaces the default theme.
- **Library**: packaging the framework for addons outside Ordaen.
- **Blizzard's tooltips**: restyled in place by a future tooltip addon, with the theme.
