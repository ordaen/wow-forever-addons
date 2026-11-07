# Settings manifest

Every Ordaen addon declares its settings in one file, `addons/<Addon>/settings.jsonc`. The build checks it and
turns it into data; Ordaen Core keeps the values, follows the theme and draws the settings page. Addon code reads
settings and never declares, validates or fills them.

## Principles

- **One source.** The manifest names the SavedVariables, every setting, its type, its limits, its labels and its
  default. Nothing about settings is written twice (no `defaults` table, no sanitizing code, no hand-made page).
- **Addons never define their look.** A look setting (frame art, font, colour, bar texture, sounds, fades)
  defaults to a **theme token**: `"default": { "theme": "frame.border" }`. The theme decides its value, so every
  addon follows the theme, and a new theme covers every addon without touching it. Only behaviour settings
  (columns, on/off, positions) have plain defaults. (CLAUDE.md, "Addons follow the theme".)
- **Only the player's choices are saved.** SavedVariables hold the values the player changed. Everything else
  is the current theme's value, so switching the theme moves every untouched setting with it. A player may pick
  another theme's asset for one addon (Blizzard's gold border on the minimap in the Ordaen theme): that is just a
  saved value. Resetting a setting removes it.
- **Checked before the game.** Wrong types, out-of-range defaults, unknown tokens or assets, unknown locale keys
  and mistyped keys in code fail `ordaen check`.

## Theme manifest

`addons/OrdaenCore/themes.jsonc` is the shared part of every theme: the tokens addons may follow, the assets
(art) they refer to, and each theme's value for every token.

```jsonc
{
  // Assets: named art and media, per kind. A setting of type "asset" chooses among one kind's assets.
  "assets": {
    "frame": {
      "bronze-rim": { "label": "FRAME_BRONZE_RIM", "file": "Interface\\AddOns\\OrdaenCore\\media\\bronze-rim-frame", "outset": 11 },
      "gold": { "label": "FRAME_GOLD", "edgeFile": "Interface\\DialogFrame\\UI-DialogBox-Border", "edgeSize": 24, "outset": 7 },
      "tooltip": { "label": "FRAME_TOOLTIP", "edgeFile": "Interface\\Tooltips\\UI-Tooltip-Border", "edgeSize": 16, "outset": 4 },
      "thin": { "label": "FRAME_THIN", "edgeFile": "Interface\\Buttons\\WHITE8X8", "edgeSize": 2, "outset": 2 },
      "none": { "label": "FRAME_NONE" }
    },
    "font": {
      "body": { "label": "FONT_BODY", "object": "GameTooltipText" },
      "header": { "label": "FONT_HEADER", "object": "GameTooltipHeaderText" },
      "ui": { "label": "FONT_UI", "object": "GameFontNormal" },
      "numbers": { "label": "FONT_NUMBERS", "object": "NumberFontNormal" }
    },
    "bar": {
      "flat": { "label": "BAR_FLAT", "file": "Interface\\Buttons\\WHITE8X8" },
      "blizzard": { "label": "BAR_BLIZZARD", "file": "Interface\\TargetingFrame\\UI-StatusBar" }
    }
  },
  // Tokens: what addons follow, each with a type (an asset kind, or color, number, sound).
  "tokens": {
    "frame.border": "frame",
    "font.body": "font", "font.header": "font", "font.numbers": "font", "font.world": "font",
    "color.accent": "color", "color.positive": "color", "color.negative": "color", "color.warning": "color",
    "color.disabled": "color",
    "bar.texture": "bar",
    "icon.crop": "number",
    "motion.fade": "number", "tooltip.delay": "number",
    "sound.open": "sound", "sound.close": "sound", "sound.click": "sound"
  },
  // Every theme gives every token a value: an asset id, a colour, a number, a SOUNDKIT name ("" = silent).
  "themes": {
    "ordaen": { "frame.border": "bronze-rim", "color.accent": [0.72, 0.56, 0.34], "motion.fade": 0.15, "...": "..." },
    "blizzard": { "frame.border": "gold", "color.accent": [1, 0.82, 0], "motion.fade": 0.2, "...": "..." },
    "minimal": { "frame.border": "thin", "color.accent": [0.56, 0.62, 0.72], "motion.fade": 0, "...": "..." }
  }
}
```

The renderer's own look data (surfaces, text styles: `OrdaenCore_UI/Theme.lua`) reads its accent and fonts from
these tokens, so the UI framework and the addons' settings can't disagree.

## Settings file

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
          "type": "asset", "of": "frame",             // every frame asset is a choice
          "default": { "theme": "frame.border" },     // the theme's frame, unless the player picks one
          "label": "BORDER_STYLE", "tooltip": "BORDER_STYLE_TOOLTIP"
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
        },
        "buttonVisibility.tracking": {
          "type": "choice",
          "choices": [
            { "id": "always", "label": "VISIBILITY_ALWAYS" }, { "id": "hover", "label": "VISIBILITY_HOVER" },
            { "id": "hide", "label": "VISIBILITY_HIDE" }
          ],
          "default": "always", "label": "BUTTON_TRACKING"
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
`settings` keeps the order it's written in, which is the order on the page; so does `choices`.

## Setting fields

| Field | Types | |
|---|---|---|
| `type` | all | `boolean`, `number`, `choice`, `asset`, `color`, `text`, `keybinding`, `sound`, `action`, `map` |
| `default` | all but `action` | a plain value of the type, or `{ "theme": "<token>" }` (a token of the same type) |
| `label` | all shown | locale key |
| `tooltip` | optional | locale key |
| `scope` | optional | `"account"` (default, `db`) or `"character"` (`charDb`, which must be named) |
| `enabledBy` | optional | key of a `boolean` setting: greyed out on the page while it is off |
| `page` | optional | `false`: saved and defaulted like the others, not on the page (positions, angles) |
| `min`, `max`, `step` | `number` | required; `step` 1 means whole numbers |
| `format` | `number`, optional | `"percent"`, `"px"` |
| `choices` | `choice` | `[{ "id": ..., "label": locale key }, ...]`, in page order; ids unique |
| `of` | `asset`, `map` | `asset`: an asset kind (`frame`, `font`, `bar`); `map`: the entries' type (`number`, `string`, `boolean`) |
| `maxLength` | `text`, optional | |

An `asset` value is an asset id of its kind; the page lists the kind's assets with their labels (Ordaen Core's
locales). `color` values are arrays `[r, g, b]` or `[r, g, b, a]`, 0 to 1 (`{ r, g, b, a }` in Lua). `sound` values are names in Blizzard's `SOUNDKIT` table (`"IG_MAINMENU_OPEN"`; `""` is silent), resolved at
runtime; the build checks each name against the API dump (`SOUNDKIT.<name>` in `namespaces.txt`). `keybinding`
values are binding strings (`"CTRL-M"`). An `action` is a button on the page; its function is registered at runtime
with `A:Action(key, fn)`.

Which settings must follow the theme: any setting of type `asset`, `color` or `sound`, and any number that is a
look (fade time, alpha) rather than a behaviour. The build enforces the first three (a plain default for an
`asset`, `color` or `sound` setting is an error); the rest is review.

## Build checks

Each fails the build with `file:line` and the key path (code B7).

| Check | Message |
|---|---|
| file shape | `unknown field "<name>"` / `unknown type "<type>"` |
| default type | `default <value> is not a <type>` |
| default range | `default <value> outside <min>..<max>` / `not a multiple of step <step>` |
| default choice | `default "<id>" is not one of its choices` / `not a <kind> asset` |
| theme token | `default follows unknown token "<token>"` / `token "<token>" is a <type>, the setting a <type>` |
| look follows theme | `<type> settings follow the theme: default { "theme": ... }` |
| locale keys | `label "<KEY>" missing in locales/<code>.json` (labels, tooltips, choices, headers, title) |
| unique keys | `declared twice` (also a key that is a prefix of a dotted key) |
| enabledBy | `enabledBy "<other>" is not a boolean setting` |
| scope | `scope "character" but no charDb` |
| db names | `db/charDb given in settings.jsonc and in NewAddon` (one place only) |
| typed db | `NewAddon's result needs --[[@as <Addon>Addon]]` |
| keys in code | reading a setting that doesn't exist is a LuaLS `undefined-field` on the generated class (below) |

Theme manifest (`themes.jsonc`), same code:

| Check | Message |
|---|---|
| every theme, every token | `theme "<name>" has no value for "<token>"` / `unknown token "<token>"` |
| value type | `"<token>" in "<theme>": <value> is not a <type>` / `no <kind> asset "<id>"` / `no SOUNDKIT.<name>` |
| the three themes | `themes need ordaen, blizzard and minimal` |
| asset labels | `asset <kind>.<id>: label "<KEY>" missing in OrdaenCore/locales/<code>.json` |

## Generated files

**`dist/OrdaenCore/ThemeTokens.lua`** (always loaded, before `SettingsStore.lua`): `ns.THEME_TOKENS = { assets,
tokens, themes }`, the theme manifest as Lua data.

**`dist/<Addon>/SettingsSchema.lua`** (loaded first, like `Locale.lua`): pure data, no code.

```lua
local _, ns = ...
ns.SETTINGS_SCHEMA = {
  db = "OrdaenMinimapDB", charDb = nil, title = "SETTINGS_TITLE",
  sections = { -- page order
    { header = "HEADER_BORDER", keys = { "borderStyle", "scale" } },
    { header = "HEADER_DRAWER", keys = { "drawerEnabled", "drawerColumns", "buttonVisibility.tracking" } },
    { keys = { "buttonAngles" } },
  },
  -- by key; `theme` = the token its default follows, or `default` = a plain value; `scope` always set; `page` only
  -- when false; `of` on asset and map; an action has no default.
  settings = {
    borderStyle = { type = "asset", of = "frame", theme = "frame.border", label = "BORDER_STYLE",
      tooltip = "BORDER_STYLE_TOOLTIP", scope = "account" },
    scale = { type = "number", min = 0.8, max = 1.6, step = 0.05, format = "percent", default = 1,
      label = "MAP_SCALE", tooltip = "MAP_SCALE_TOOLTIP", scope = "account" },
    ["buttonVisibility.tracking"] = { type = "choice", choices = { "always", "hover", "hide" },
      choiceLabels = { "VISIBILITY_ALWAYS", "VISIBILITY_HOVER", "VISIBILITY_HIDE" }, default = "always",
      label = "BUTTON_TRACKING", scope = "account" },
    buttonAngles = { type = "map", of = "number", default = {}, page = false, scope = "account" },
    -- ...
  },
}
```

The Core builds the per-theme default tables from `settings` and `THEME_TOKENS` once per theme (at login and on
a theme switch), so the generated file has no per-theme data.

**TOC:** `## SavedVariables` / `## SavedVariablesPerCharacter` from `db` / `charDb`.

**LuaLS** (`.ordaen/types/<Addon>.lua`, gitignored, included by `.luarc.json`): one class per addon, nested
classes for dotted keys, and the addon's own class (`db`, `charDb`, an `OnLoad` typed with both). Asset unions come
from the asset ids in `themes.jsonc`; a number is `integer` when its step and min are whole.

```lua
---@class OrdaenMinimapSettings
---@field borderStyle "bronze-rim"|"gold"|"tooltip"|"thin"|"none"
---@field scale number
---@field drawerEnabled boolean
---@field drawerColumns integer
---@field buttonAngles table<string, number>
---@field buttonVisibility OrdaenMinimapSettings_buttonVisibility

---@class OrdaenMinimapAddon : OrdaenAddon
---@field db OrdaenMinimapSettings
```

```lua
local A = OrdaenCore.NewAddon(addonName, ns, { ... }) --[[@as OrdaenMinimapAddon]]
```

The cast goes right after the call: LuaLS ignores a trailing `---@type` after a multi-line call, and `---@type` on
the line above is an assign-type-mismatch.

So `db.borderStyel` or `db.drawerColumns = "6"` is a finding in `ordaen check`.

**`dist/<Addon>/settings.schema.json`** and **`dist/OrdaenCore/themes.json`**: the same data as JSON, not loaded
by the game, for tools (the companion's Addons tab shows settings and defaults; `wow_dump` can mark what the
player changed).

## Runtime (Ordaen Core)

- **Reading:** `db.key` (and `db.a.b`) returns the player's value, else the current theme's default: the saved
  table's metatable falls back to the defaults for the theme, so a read costs one table lookup and saves nothing.
  Nested tables and maps are raw tables of their own (kept when empty), so writes through them reach the
  player's table. `A:Get("a.b")` reads a dotted key.
- **Writing:** the page (or `A:Set(key, value)`) writes the player's value, validated against the schema, then
  calls `A:_SettingChanged(key, value)` (features) and the addon's `onChange` (`OrdaenCore.NewAddon(…, {
  onChange = fn(key, value) })`). `A:Reset(key)` removes it; `/<slash> reset`
  removes all (keeping `_schema`, the migration count).
- **Theme switch:** the fallbacks point at the new theme's defaults; every setting without a player value whose
  value changed is announced through `_SettingChanged`, then `_SyncFeatures()` runs.
- **Loading:** migrations run on the raw saved table first; then values that the schema refuses (wrong type,
  unknown choice or asset, out of range) are removed, so the default applies.
- **Page:** from `sections`, under Options > AddOns. For now on Blizzard's Settings API (proxy settings that read
  and write through the store): `boolean` checkboxes, `number` sliders, `choice` and `asset` dropdowns, `color`
  Blizzard's colour swatch (opens the colour picker; changes apply while picking, Cancel restores; picking the
  theme's own colour, or Blizzard's Defaults, forgets the player's choice; the picker has no alpha, a saved alpha
  is kept), `enabledBy` greys a control out; the other types aren't on the page yet. A page drawn with OrdaenCore.UI
  components is planned (roadmap).
- **Ordaen Core** has a manifest too (`OrdaenCore/settings.jsonc`: `ui.theme`, `ui.textSize`, `keptConflicts`).
  Its theme is applied when it loads, before the addons that depend on it bind; a theme change from its page
  moves every addon's untouched settings, then OrdaenCore.UI redraws.
