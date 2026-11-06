# Settings manifest

Every Ordaen addon declares its settings in one file, `addons/<Addon>/settings.jsonc`. The build checks it and
turns it into data; Ordaen Core keeps the values, follows the theme and draws the settings page. Addon code reads
settings and never declares, validates or fills them.

## Principles

- **One source.** The manifest names the SavedVariables, every setting, its type, its limits, its labels and its
  defaults. Nothing about settings is written twice (no `defaults` table, no sanitizing code, no hand-made page).
- **A default for every theme.** A setting whose default depends on the look gives one per theme (`ordaen`,
  `blizzard`, `minimal`); one that doesn't gives a single value (CLAUDE.md, "Theme defaults for every setting").
- **Only the player's choices are saved.** SavedVariables hold the values the player changed. Everything else
  is the current theme's default, so switching the theme moves every untouched setting with it. Resetting a
  setting removes the player's value.
- **Checked before the game.** Wrong types, out-of-range defaults, missing themes, unknown locale keys and
  mistyped keys in code fail `ordaen check`.

## File

```jsonc
// addons/OrdaenMinimap/settings.jsonc
{
  "db": "OrdaenMinimapDB",          // account-wide SavedVariables
  "charDb": "OrdaenMinimapCharDB",  // optional: per-character SavedVariables
  "title": "SETTINGS_TITLE",        // page title, locale key (default: the TOC title)
  "sections": [
    {
      "header": "HEADER_BORDER",
      "settings": {
        "borderStyle": {
          "type": "choice",
          "choices": [
            { "id": "bronze-rim", "label": "STYLE_BRONZE_RIM" }, { "id": "gold", "label": "STYLE_GOLD" },
            { "id": "tooltip", "label": "STYLE_TOOLTIP" }, { "id": "thin", "label": "STYLE_THIN" },
            { "id": "none", "label": "STYLE_NONE" }
          ],
          "default": { "ordaen": "bronze-rim", "blizzard": "gold", "minimal": "thin" },
          "label": "BORDER_STYLE",
          "tooltip": "BORDER_STYLE_TOOLTIP"
        },
        "scale": {
          "type": "number", "min": 0.8, "max": 1.6, "step": 0.05, "format": "percent",
          "default": 1, "label": "MAP_SCALE", "tooltip": "MAP_SCALE_TOOLTIP"
        }
      }
    },
    {
      "header": "HEADER_DRAWER",
      "settings": {
        "drawerEnabled": { "type": "boolean", "default": true, "label": "DRAWER_ENABLED" },
        "drawerColumns": {
          "type": "number", "min": 2, "max": 12, "step": 1, "default": 6,
          "label": "DRAWER_COLUMNS", "enabledBy": "drawerEnabled"
        }
      }
    },
    {
      "settings": {
        "buttonAngles": { "type": "map", "of": "number", "default": {}, "page": false }
      }
    }
  ]
}
```

Keys are identifiers; a dot makes a nested table (`"buttonVisibility.tracking"` is `db.buttonVisibility.tracking`).
The order of `choices` is the order on the page.

## Setting fields

| Field | Types | |
|---|---|---|
| `type` | all | `boolean`, `number`, `choice`, `color`, `text`, `keybinding`, `action`, `map` |
| `default` | all but `action` | a value of the type, or `{ "ordaen": v, "blizzard": v, "minimal": v }` |
| `label` | all shown | locale key |
| `tooltip` | optional | locale key |
| `scope` | optional | `"account"` (default, `db`) or `"character"` (`charDb`, which must be named) |
| `enabledBy` | optional | key of a `boolean` setting: greyed out on the page while it is off |
| `page` | optional | `false`: saved and defaulted like the others, not on the page (positions, angles) |
| `min`, `max`, `step` | `number` | required; `step` 1 means whole numbers |
| `format` | `number`, optional | `"percent"`, `"px"` |
| `choices` | `choice` | `[{ "id": ..., "label": locale key }, ...]`, in page order; ids unique |
| `maxLength` | `text`, optional | |
| `of` | `map` | value type of the entries: `number`, `string`, `boolean` |

`color` values are `{ r, g, b }` (0 to 1). `keybinding` values are binding strings (`"CTRL-M"`). An `action` is a
button on the page; its function is registered at runtime with `A:Action(key, fn)`.

## Build checks

Each fails the build with `file:line` (codes assigned by the build).

| Check | Message |
|---|---|
| file shape | `settings.jsonc: unknown field "<name>"` / `<key>: unknown type "<type>"` |
| default type | `<key>: default <value> is not a <type>` |
| default range | `<key>: default <value> outside <min>..<max>` / `not a multiple of step <step>` |
| default choice | `<key>: default "<id>" is not one of its choices` |
| themes | `<key>: theme defaults need ordaen, blizzard and minimal (missing: <names>)` |
| locale keys | `<key>: label "<KEY>" missing in locales/<code>.json` (labels, tooltips, choices, headers, title) |
| unique keys | `<key>: declared twice` (also a key and a nested key under it) |
| enabledBy | `<key>: enabledBy "<other>" is not a boolean setting` |
| scope | `<key>: scope "character" but no charDb` |
| db names | `db/charDb given in settings.jsonc and in NewAddon` (one place only) |
| keys in code | reading a setting that doesn't exist is a LuaLS `undefined-field` on the generated class (below) |

## Generated files

**`SettingsSchema.lua`** (dist only, loaded first, like `Locale.lua`): pure data, no code.

```lua
local _, ns = ...
ns.SETTINGS_SCHEMA = {
  db = "OrdaenMinimapDB", charDb = nil, title = "SETTINGS_TITLE",
  sections = { -- page order
    { header = "HEADER_BORDER", keys = { "borderStyle", "scale" } },
    { header = "HEADER_DRAWER", keys = { "drawerEnabled", "drawerColumns" } },
    { keys = { "buttonAngles" } },
  },
  settings = { -- by key
    borderStyle = { type = "choice", choices = { "bronze-rim", "gold", "tooltip", "thin", "none" },
      choiceLabels = { "STYLE_BRONZE_RIM", "STYLE_GOLD", "STYLE_TOOLTIP", "STYLE_THIN", "STYLE_NONE" },
      label = "BORDER_STYLE", tooltip = "BORDER_STYLE_TOOLTIP", scope = "account", themed = true },
    scale = { type = "number", min = 0.8, max = 1.6, step = 0.05, format = "percent", label = "MAP_SCALE",
      tooltip = "MAP_SCALE_TOOLTIP", scope = "account" },
    -- ...
  },
  -- per theme, nested like the db; keys without theme defaults repeat the single value. Per-character settings
  -- (scope "character") go in charDefaults, same shape; nil without a charDb.
  defaults = {
    ordaen = { borderStyle = "bronze-rim", scale = 1, drawerEnabled = true, drawerColumns = 6, buttonAngles = {} },
    blizzard = { borderStyle = "gold", scale = 1, drawerEnabled = true, drawerColumns = 6, buttonAngles = {} },
    minimal = { borderStyle = "thin", scale = 1, drawerEnabled = true, drawerColumns = 6, buttonAngles = {} },
  },
}
```

**TOC:** `## SavedVariables` / `## SavedVariablesPerCharacter` from `db` / `charDb`.

**LuaLS** (in the build's type output, next to `api/forever/luals/`): one class per addon, nested classes for
dotted keys.

```lua
---@class OrdaenMinimapSettings
---@field borderStyle "bronze-rim"|"gold"|"tooltip"|"thin"|"none"
---@field scale number
---@field drawerEnabled boolean
---@field drawerColumns integer
---@field buttonAngles table<string, number>
---@field buttonVisibility OrdaenMinimapSettings_buttonVisibility
```

`A.db` and the `db` argument of `A:OnLoad` are typed with it, so `db.borderStyel` or `db.drawerColumns = "6"` is a
finding in `ordaen check`.

**`dist/<Addon>/settings.schema.json`**: the same schema as JSON, not loaded by the game, for tools (the
companion's Addons tab shows settings and defaults; `wow_dump` can mark what the player changed).

## Runtime (Ordaen Core)

- **Reading:** `db.key` (and `db.a.b`) returns the player's value, else the current theme's default: the saved
  table's metatable falls back to `defaults[theme]`, so a read costs one table lookup and saves nothing.
  `A:Get("a.b")` does the same for a dotted key.
- **Writing:** the page (or `A:Set(key, value)`) writes the player's value, validated against the schema, then
  calls `A:_SettingChanged(key, value)` and the addon's `onChange`. `A:Reset(key)` removes it; `/<slash> reset`
  removes all (keeping `_schema`, the migration count).
- **Theme switch:** the fallbacks point at the new theme's defaults; every setting without a player value whose
  default changed is announced through `_SettingChanged`, then `_SyncFeatures()` runs.
- **Loading:** migrations run on the raw saved table first; then values that the schema refuses (wrong type,
  unknown choice, out of range) are removed, so the default applies.
- **Page:** drawn with OrdaenCore.UI components from `sections`, under Options > AddOns.
