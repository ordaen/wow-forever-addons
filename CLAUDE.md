# wow-forever-addons

Monorepo of World of Warcraft addons for the **WoW Forever** flavor (interface `16001`).
Developed on Windows (the user normally works on Linux — explain Windows specifics when relevant).

## Performance: every KB and every CPU cycle matters (non-negotiable)

The user's rule, set in stone: our addons must cost as close to nothing as possible. "It's only 100 KB" or "it's only
a few microseconds" is **never** an acceptable argument. Players run dozens of addons and the cost adds up. When
simpler code and leaner code conflict, choose leaner, or ask the user. A performance regression is a bug.

- **Nothing runs per frame by default.** `OnUpdate` only while its frame is shown and only when an event or timer
  can't do the job; throttle it, and remove the script (`SetScript("OnUpdate", nil)`) when it isn't needed. Prefer
  events and one-shot `C_Timer.After` over polling.
- **Events:** register only what a feature needs, only while it's enabled, and unregister when it's off. Prefer
  unit-filtered registration (`RegisterUnitEvent`) where it exists on Forever. Avoid high-frequency events
  (combat log, auras, unit health) unless the feature can't exist without them; bail out early in their handlers.
- **Load nothing until needed.** Create frames, textures and tables on first use, not at login. Anything not needed
  for the first screen (big options UIs, data sets, dev tools) goes in a load-on-demand addon (`## LoadOnDemand: 1`,
  loaded with `C_AddOns.LoadAddOn`; confirmed on Forever). Strings and data for other locales are not kept in memory.
- **No garbage in hot paths:** no table/closure/string creation (`..`, `format`, `{}`) in per-frame or per-event code;
  reuse tables; cache globals used in hot code as upvalues.
- **SavedVariables hold settings only:** no history, no caches that can be rebuilt; anything that can grow has a hard
  cap. They are parsed at login and written at logout for every character.
- **Hooks only on rarely called functions,** with cheap bodies. Expensive work in a hook (`debugstack`, re-applying a
  layout) is rate-limited or cached.
- **Dependencies:** no library unless Blizzard's API can't do it. OrdaenCore stays small; dev-only code lives in
  `OrdaenCore_Debug`, which players never load.
- **Measure, don't guess:** before merging a feature into `develop`, check its memory and CPU in the Ordaen Dev window
  (Performance tab, once it exists) and wrap hot spots in `Debug.Time`. Mention the numbers when handing work over.

## Game install

- Forever client: `C:\Program Files (x86)\World of Warcraft\_forever_\`
- AddOns folder: `C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\`
- Each addon in `addons/<Name>/` gets a directory junction in the AddOns folder via `scripts/link.ps1` (no admin needed), so edits show after `/reload` in game. The junctions point at the main checkout `C:\Users\f3oal\code\ordaen\wow-forever-addons`, which stays on `develop` (see Branches).

## Decisions so far

- User wants things done properly from the start (full tooling, not "add later").
- Repo: public GitHub repo `ordaen/wow-forever-addons` (org; user is admin). The org forbids GITHUB_TOKEN from opening PRs, so release-please uses an org GitHub App token (`vars.RELEASE_APP_CLIENT_ID`, `secrets.RELEASE_APP_PRIVATE_KEY`). Default branch `main`, squash-merge only, PR title = commit message.
- Commit identity (global git config): `David Iunevich <1751835+f3oall@users.noreply.github.com>`. GitHub user `f3oall`.
- Signed commits are required on every branch (ordaen org ruleset). Commits are SSH-signed with `~/.ssh/id_ed25519` (global `commit.gpgsign`/`tag.gpgsign`). Commits GitHub creates (squash merges, release-please via the App, Dependabot) are signed by GitHub.
- `main` ruleset: PR-only, squash-only, linear history, required checks `Conventional commits`, `Lint & test (Lua)`, `Package (dry run)`; repo admins may bypass only when merging a PR. Work on a branch and open a PR.
- **Branches (local-only until the user says otherwise: no push, PR or merge on GitHub):**
  - `develop` is the integration branch and the **game checkout**: the main checkout `C:\Users\f3oal\code\ordaen\wow-forever-addons` stays on `develop`, and the game loads it through the junctions. Never switch that checkout to another branch.
  - Do feature work on a branch off `develop` in its own worktree: `git worktree add ../wow-forever-addons-<topic> -b feat/<topic> develop`, then `npm install` there (installs the commit hook).
  - When `scripts/test.sh` is green, rebase onto `develop` and run `git merge --ff-only feat/<topic>` from the main checkout. That keeps the signed conventional commits. Then the user does `/reload`, or restarts the client if files were added or a `.toc` changed.
  - Revisit at release: `main` is squash-only, so one develop→main PR gives each addon a single changelog line, and a commit touching several addons shows in each addon's changelog. Prefer one PR per addon or feature with a player-facing title. The merged rename PR #4 and release PR #5 need a `BEGIN_COMMIT_OVERRIDE` block so the rename line stays out of the first changelog.
- Line endings: LF everywhere via `.gitattributes`. On Windows, set the exec bit with `git add --chmod=+x scripts/package.sh`.
- Commits: Conventional Commits via commitlint (`commitlint.config.mjs`; scope = addon folder name or repo scope), enforced by husky `commit-msg` hook and in CI (PR title + PR commits).
- Versioning: release-please manifest mode (`release-please-config.json`, `.release-please-manifest.json`), one component per addon, tags `<Addon>-vX.Y.Z`. release-please bumps `## Version` in the TOC via `x-release-please-start-version` block markers — never edit it by hand.
- Quality: luacheck + busted (pure-logic tests only, Lua 5.1) in CI; manual testing in game with dev mode (Ordaen Core - Debug).
- **Forever lacks many retail/classic FrameXML helpers** (e.g. no global `MouseIsOver`; it errored every frame in the
  drawer). **The source of truth is the in-game API dump in `api/forever/`** (see "Forever API dump" below): never use,
  list or stub a WoW global, namespace function or widget method that isn't in `api/forever/$(cat CURRENT)/`. luacheck
  and the specs enforce this once a dump is imported. Before the first dump (or for things a dump can't see), confirm
  by a Forever-specific addon using it (`*Camelot*`/`Forever*` files) or a `/dump` in game; unconfirmed APIs get a
  fallback and go in the dev-mode `api:` log line (`UNCONFIRMED_APIS` in `addons/OrdaenMinimap/Core.lua`).
- Dev environment is Windows + WSL only (README "Development" describes nothing else). Lua 5.1, luacheck and busted live in the WSL distro `Ubuntu`; `scripts/test.sh` (run from Git Bash) runs luacheck + busted there. From Git Bash, call WSL with `MSYS_NO_PATHCONV=1` and `--exec` (otherwise Git Bash rewrites `/mnt/...` paths and WSL's shell expands `$1` early).
- Packaging: BigWigs packager (pinned in `scripts/package.sh`). It requires a git repo root as topdir, so the script copies the addon into a temp git repo and tags it. Packager handles CurseForge/Wago uploads; the zip is attached to release-please's GitHub release with `gh release upload` (packager's own GitHub upload would overwrite the release notes). Packager maps interface `16???` to the `forever` flavor (CurseForge game id 88568).

## Layout

```
addons/<Addon>/                 addon source (.toc, .lua, .pkgmeta)
addons/OrdaenCore/              shared code every addon depends on (global OrdaenCore; no-op debug stand-in;
                                OrdaenCore.UI framework: UI.lua, Tooltip.lua)
tests/<Addon>/*_spec.lua        busted specs (load addon files with loadfile(path)(addonName, ns))
tests/OrdaenCore/helpers.lua    WoW API stubs + Core loader, for any spec that needs the Core
scripts/link.ps1                create/remove AddOns junctions
scripts/package.sh              package one addon (CI + Git Bash)
scripts/test.sh                 luacheck + busted (Git Bash -> WSL, or native on Linux/CI)
scripts/api-import.sh           import the in-game API dump into api/forever/ (api_import.lua does the work)
scripts/forever_lint.lua        forever-lint: addon code against api/forever/<CURRENT>/api.json (json.lua: its JSON)
api/forever/<version>-<build>/  the real Forever API per client version (generated; history in git)
.github/ISSUE_TEMPLATE/         bug report form the in-game error report links to
.claude/skills/debug-in-game/   how Claude debugs in-game behavior (loaded on demand)
.github/workflows/ci.yml        commitlint, luacheck, busted, packaging dry run
.github/workflows/release.yml   release-please, then package + upload per released addon
```

## Branding

Every addon is named `Ordaen<Name>` (folder, .toc, globals) with TOC title `Ordaen <Name>`, so CurseForge search
finds them all. One CurseForge project per addon (no pack). Every TOC sets `## Category:` plus the localized
`## Category-xxXX:` lines, copied from an installed addon that uses the same category so they share a group in the
addon list: OrdaenCore is `Libraries`, feature addons use e.g. `User Interface`.

## Localization

- English and Russian for now; the user's client is ruRU. Every user-facing string goes through `ns.L`.
- Per addon: `Locale.lua` holds the English base (and the fallback; an unknown key shows as itself) and defines
  `ns.ApplyTranslation`. Each other language is `Locale_<code>.lua` (e.g. `Locale_ruRU.lua`), listed after
  `Locale.lua` in the TOC. It returns at once unless `ns.LOCALE` is its language, so other clients never build its
  table. Only the client's language stays in memory (see Performance).
- `tests/repo/locales_spec.lua` checks every addon automatically: no missing or unknown keys, and identical format
  placeholders (`%s`, `%d`) in every language. Add a key to `Locale.lua` and every `Locale_<code>.lua` together.
- Use Blizzard's own translated globals for common words where they fit (`CLOSE`, `OKAY`, `CANCEL`, `RESET`, `NONE`,
  `SETTINGS`), after confirming they exist on Forever.
- TOC: localized `## Notes-ruRU` and `## Category-ruRU` lines. Whether titles get a `## Title-ruRU` (e.g. "Ordaen
  Миникарта") is still for the user to decide; until then titles stay English.
- The Ordaen Dev window (dev mode) is English only.

## UI framework `OrdaenCore.UI`: design philosophy (set in stone by the user)

Owner (user's decision): the Ordaen Minimap session owns `OrdaenCore.UI`: `addons/OrdaenCore/UI.lua`, the
load-on-demand module `addons/OrdaenCore/OrdaenCore_UI/`, and their specs (`tests/OrdaenCore/ui_spec.lua`,
`layout_spec.lua`). Requests go to it. The Ordaen Core session owns the rest of the Core (`Core.lua`, the
`OrdaenCore.toc` file list, `.pkgmeta`, `tests/OrdaenCore/helpers.lua`) and gets a heads-up before the UI owner touches
those. Core API names become permanent at the first release of OrdaenCore; until then the UI shape may change.

- **Addons declare, they never render.** Addon code describes what it wants in our block format and hands it to
  `OrdaenCore.UI`; it never draws, styles or measures. Same calls in every addon, one place to change behavior.
- **Everything is a block.** A block is a box (style role, optional size) whose children are cells of a grid
  (`columns` of tracks: number = fixed, `"auto"` = widest natural content, `"Nfr"` = share of the rest; `gap`,
  `padding`; `width`/`minWidth`/`maxWidth`; children may `colSpan`, `align`, be `hidden`). Elements: `text` (always
  wraps, never truncated), `image`, and blocks. A top-level block has a trigger and a position; a tooltip is one with
  a hover trigger, anchored to its owner, passive, on the tooltip layer, one at a time. Later: buttons (composite
  blocks with click), windows (fixed, saved position/size: the framework remembers them), more roles.
- **One renderer, themes are data.** The only drawing code is the framework's (`OrdaenCore_UI/Render.lua`). Looks come
  from a theme table (`Theme.lua`: per style role the art, colors and layout defaults; per text style a font object
  and color). The default theme uses Blizzard's art and fonts; a theme addon will only replace that data. No second
  renderer, no fallback branches. `color` on an element is for meaning (a pending invite), not decoration.
- **Layout** (`OrdaenCore_UI/Layout.lua`, pure Lua, `layout_spec.lua`): two passes like CSS grid: column widths
  (fixed, auto, then fr shares; too little room shrinks fr then auto columns, never below 8 px), then row heights from
  text wrapped to those widths. Text is measured by the renderer with the theme's fonts, cached per element.
- **Loading:** `addons/OrdaenCore/UI.lua` (always loaded, tiny) loads the module `OrdaenCore_UI` (`LoadOnDemand`,
  shipped in the Core zip via `move-folders`, versioned with Core) on the first `ShowTooltip`; Hide/Refresh never
  load it. If it can't load (disabled, missing), one chat line says why and tooltips stay off quietly.
- **Cost:** callers build their block tables once and change fields (`text`, `hidden`), then `RefreshTooltip(owner)`
  from their own timer or event while shown. One shared tooltip surface; font strings and textures are pooled;
  layout results are reused tables; nothing is copied per show; no timers or `OnUpdate` in the framework.
- **Tooltips API:** `OrdaenCore.UI.ShowTooltip(owner, block, opts)`, `HideTooltip(owner)`, `RefreshTooltip(owner)`;
  `opts = { side = "right" | "left" | "below" | "above", x, y }`. Text styles in the default theme: `title`,
  `subtitle`, `body` (default), `label`, `value`, `hint`; block style `tooltip`.
- **Blizzard's own tooltips** (items, units, spells) and other addons' are a separate matter: restyled in place by a
  future tooltip addon (taking its look from the theme), never hidden and redrawn as a lookalike.
- **Open:** buttons and windows (triggers, fixed positions with remembering, resizing); theme addon API; packaging
  the framework as an embeddable library for third-party addons.
- PrettyTooltip (MIT, © 2026 FallenShard) is a reference and a source of features, not a base to fork. Any code taken
  from it keeps its copyright notice and license text.

## First addon: OrdaenMinimap

Our own specialized take on **SexyMap** (installed reference: `_forever_\Interface\AddOns\SexyMap\`), deliberately with
little configuration: opinionated defaults instead of option panels. Renamed from MinimapCompartment before its first
release; the button drawer + addon compartment is one feature of it. Feature scope beyond the drawer is still to be
decided with the user.

- SavedVariables `OrdaenMinimapDB`; slash `/om` opens the settings (alias `/ordaenminimap`), `/om reset` restores defaults.
- Forever runs the **modern (mainline) minimap code** with Forever tweaks (SexyMap loads its mainline files there; its
  `Init_Camelot.lua` sets `isForever`). Frame names differ between clients, so `Map.lua` looks up each Blizzard piece by
  several names, skips missing ones and records what it found (dev-mode dump: "Save for Claude & reload" in the Ordaen Dev window). Toggling "rotate minimap"
  runs `MinimapCluster:UpdateMinimapConfig`, which resets the mask and sizes: we hook it and re-apply.
- Settings page: Blizzard Settings API in its newer form (`Settings.RegisterAddOnSetting(category, variable, key, tbl,
  type, name, default)`, `Settings.CreateDropdown/CreateSlider/CreateCheckbox`), registered on `ADDON_LOADED` because it
  binds to the SavedVariables table. Reference: `MinimapButtonButton\Settings\SettingsMenu.lua`, `ForeverLootSparkles`.
- Files: `Locale.lua` (enUS + ruRU; the user's client is ruRU), `Borders.lua` (border styles as data, defaults, pure
  helpers), `Ring.lua`/`Buttons.lua` (buttons around the map), `Info.lua` (zone, coordinates, clock), `Map.lua`
  (square mask, hide Blizzard pieces, wheel zoom, border frame, scale, `GetMinimapShape`),
  `Options.lua` (settings page), `Core.lua` (events, slash). Specs: `borders_spec.lua` (logic) and `smoke_spec.lua`
  (loads the whole addon against stubbed WoW objects).
- Conflicts (`Conflicts.lua` pure logic, `Guard.lua` WoW side): at login, a known list of dedicated minimap addons
  (SexyMap, BasicMinimap, Chinchilla, pMinimap) plus generic detection: who defined `GetMinimapShape`
  (`issecurevariable` names the tainting addon), hooks on everything `Map.lua` changes (changes made outside
  `withApplying` are attributed with `debugstack`: first `Interface/AddOns/<Name>/` that isn't ours or `Blizzard_*`),
  and a check 5 s after login for changes that bypassed hooks. On a conflict we step aside and show a StaticPopup:
  keep ours (dedicated addon: `C_AddOns.DisableAddOn` + reload; multi-purpose/unknown: remember
  `conflictChoice[addon] = "ours"` and override), keep the other (disable ours + reload), or decide later.
  Multi-purpose addons (ElvUI, EnhanceQoL, Leatrix Plus) are deliberately not in the known list. The BigWigs packager
  has no `incompatible` relation; set that on the CurseForge project page by hand.
- Feature: square map with a configurable border. Styles in `ns.BORDER_STYLES` are backdrops drawn by a frame around the
  map; built-in ones use game textures (gold dialog, tooltip, thin line). Custom art goes in `media/` as a new style.
- Layout rule (user's decision): nothing sits on or inside the map frame. Zone name above the border, coordinates
  (left) and clock (right) below it (`Info.lua`); every button outside the border on a ring (`Ring.lua` pure math,
  `Buttons.lua` WoW side), placed by angle (`db.buttonAngles[id]`, 0 = right, CCW) and dragged around the map like
  the Ordaen Dev gear button. Hidden for good (`Map.lua` `HIDDEN_PIECES`): Blizzard's zone bar, clock, calendar button
  (`GameTimeFrame`) and day/night icon (`MinimapCluster.DielFrame`). A click on our clock opens the calendar,
  right-click the clock settings; the clock turns orange with pending calendar invites.
  - Our buttons share one style (`Buttons.Style`: the gear button's 28 px dark tooltip backdrop + icon). Blizzard's
    tracking button is dressed in it: its own art is set to alpha 0 and it stays on top, so its menu works unchanged.
    Other Blizzard buttons (mail, crafting orders, expansion page) are moved as they are. `hooksecurefunc` on their
    `SetPoint`/`SetParent` puts them back when Blizzard's layout code moves them (no method replacement on Blizzard
    frames, to keep taint away).
  - Cost: coordinates from `UnitPosition` + the map's world rectangle (read once per zone, HereBeDragons' method), so
    ticks create no tables; a 1 s `C_Timer.After` chain for clock and coordinates, plus 0.1 s only between
    `PLAYER_STARTED_MOVING` and `PLAYER_STOPPED_MOVING`. Dev mode logs our coordinates next to
    `C_Map.GetPlayerMapPosition` once per zone to verify the math.
- Feature: button drawer (replaces MinimapButtonButton, MBB) that also collects **addon compartment** entries.
  Implemented in `DrawerData.lua` (pure: grid, entry merging) and `Drawer.lua`; settings `drawerEnabled` (default
  on), `hideBlizzardCompartment` (default on), `drawerColumns`; the main button sits on the button ring
  (`buttonAngles.drawer`; drag moves it, right-click opens settings). Needed on a square map anyway: addons like
  Altoholic (AddonFactory template) and AutoBiographer place their buttons on a circle with their own math and never
  ask `GetMinimapShape`. MBB's code is "All rights reserved": use it as a behavior reference only, never copy it.
  - One main button; clicking it toggles a grid "drawer" of buttons.
  - Collects minimap buttons the way MBB does (`_forever_\Interface\AddOns\MinimapButtonButton\Logic\Main.lua` is the reference):
    LibDBIcon buttons (+ `LibDBIcon_IconCreated` callback), Minimap children whose names match
    `MinimapButton|MinimapFrame|MinimapIcon|[-_]Minimap[-_]|Minimap$|^LibDBIcon10_`, skipping secure (Blizzard) globals,
    names ending in digits, and map pins (HandyNotes, TomTom, Questie, GatherMate, ...). Reparent into the drawer, then
    neutralize `SetPoint/ClearAllPoints/SetParent/SetScale` on the button and position via `UIParent.SetPoint` etc.
    Defer collecting protected frames in combat.
  - Compartment entries (`AddonCompartmentFrame` exists in Forever):
    - TOC entries: read `## AddonCompartmentFunc / FuncOnEnter / FuncOnLeave`, `IconTexture`/`IconAtlas`, `Title` via
      `C_AddOns.GetAddOnMetadata`. Call the globals directly: `Click(addonName, mouseButton, frame)`,
      `Enter(addonName, frame)`, `Leave(addonName, frame)`. Fall back to a plain title tooltip.
    - Runtime entries in `AddonCompartmentFrame.registeredAddons` not from a TOC: call
      `info.func(button, { buttonName = mouseButton }, button)`, `info.funcOnEnter(button, info)`, `info.funcOnLeave(button, info)`.
    - De-duplicate: if an addon also has a LibDBIcon minimap button that is shown, hide its compartment twin (decide at layout time).
  - Hide Blizzard's compartment button (default on). Warn if MBB is also loaded (they would conflict).
  - Drawer settings: columns, grow direction, autoClose, ignore list. Slash: reset, list, ignore/unignore.
  - Addons in Forever that use the compartment today: Altoholic, Baganator, Details, DialogueUI, Pawn, Prat.

## Ordaen Core and debugging

- `addons/OrdaenCore/` holds the code every addon shares. It publishes the global `OrdaenCore` and contains no features. Every addon has `## Dependencies: OrdaenCore` in its TOC, `## X-Ordaen-MinCore: <version>`, and `required-dependencies: [ordaen-core]` in `.pkgmeta` (the CurseForge slug is a guess until the project exists).
- **The Core API only grows.** Users update the Core and the addons independently. Never change the behavior of a released Core function or remove one; add a new name instead. When an addon starts using a new Core API, raise its `X-Ordaen-MinCore`. `OrdaenCore.IsCompatible(addonName)` enforces that in packaged builds; git checkouts are detected by the unreplaced `@project-version@` token in `Core.lua` and skip the check.
- Each addon starts with `if not OrdaenCore.IsCompatible(addonName) then return end`, then takes its own debug kit with `OrdaenCore.NewDebug(addonName)`. Every addon lists `## OptionalDeps: OrdaenCore_Debug` so the dev-mode module loads first when enabled. Init it in `ADDON_LOADED` with the addon's SavedVariables table, wrap handlers in `Debug.Wrap`, and forward slash input through `Debug.HandleSlash` (example: `addons/OrdaenMinimap/Core.lua`). New code logs its decisions with `Debug.Log`.
- Before handing code over for an in-game test, run `bash scripts/test.sh` until it is green. Say whether `/reload` is enough or a full client restart is needed (any new file or `.toc` change).
- **Debugging is opt-in development mode.** Players get a no-op stand-in from the Core: nothing is recorded and errors take WoW's normal path (BugSack, Blizzard). The real kit is the dev-only addon `OrdaenCore_Debug` ("Ordaen Core - Debug"), which lives in the **private repo `../wow-dev-tools`** next to the companion app and is never shipped (decided by the user: dev tooling, including the pixel channel, stays private). Its own `scripts/link.ps1` junctions it into the AddOns folder; its specs load `addons/OrdaenCore/Core.lua` and `api/forever/` from this checkout. Keep the stand-in's API in step with it. Installing and enabling it turns on dev mode: our own error catcher (global error handler chained to the previous one, or BugGrabber's callback when BugGrabber keeps the handler; plus taint events), per-addon logs and dumps, and the Ordaen Dev window with "Save for Claude & reload". All dev data goes to one SavedVariables table, `OrdaenCoreDebugDB`, never into players' addon settings. Never make players' builds record anything. Plan for the window: Errors (done), then Performance (memory, `C_AddOnProfiler` if present, `Debug.Time`), Log, Inspect (frame picker, outlines). Prefer UI in the window over new slash commands.
- For anything observed in game (bugs, errors, layout, "check" after a reload), follow the `debug-in-game` skill (`.claude/skills/debug-in-game/SKILL.md`).
- Addons have no network access, so there is no telemetry. Users report errors with `/<cmd> errors` and the GitHub issue form. Add each new addon to its dropdown.

## Forever API dump (`api/forever/`)

The real Lua API of each Forever client version, dumped in game, so nobody guesses what exists.

- **Make a dump** (user, dev mode on; the dev addon lives in `../wow-dev-tools`): Ordaen Dev window → **Dump game API**. It walks `_G` once (a short hitch),
  stores names and types (never values) of Blizzard-defined globals only (`issecurevariable` drops anything other
  addons added), one level into tables (`C_*`, `Enum`…), the methods of every widget type, the members of key Blizzard
  objects (`Minimap`, `MinimapCluster`…), and Blizzard's API documentation if the client ships it. It saves to
  `OrdaenCoreDebugDB.apiDump` and reloads. Afterwards the same button reads **Clear API dump**: click it once imported.
- **Import it** (Claude, Git Bash): `bash scripts/api-import.sh` → `api/forever/<version>-<build>/` (`meta.txt`,
  `globals.txt`, `namespaces.txt`, `widgets.txt`, `objects.txt`, `docs.txt` if available: sorted, one entry per line),
  `api/forever/CURRENT` (newest build), `api/forever/CHANGES.md` (what each version added/removed) and
  `api/forever/luacheck.lua`. Commit them as `chore(api): import Forever <version>-<build> API dump`. Dump again
  whenever Forever patches; never edit these files by hand.
- **Enforced:** `.luacheckrc` uses `api/forever/luacheck.lua` as `read_globals` (exact fields for namespaces and the
  dumped objects), so any missing global or `C_X.Function` fails the lint. `tests/repo/forever_api_spec.lua` checks
  every `:Method(` call in `addons/` against the dumped widget/object methods (non-widget methods, e.g. Settings or
  LibDBIcon objects, need an entry with proof in `tests/repo/method_allowlist.lua`), and specs refuse to stub a global
  the dump lacks (`tests/repo/forever_api.lua`, used by `helpers.stubGlobals` and the Minimap smoke spec).
- **forever-lint** (`scripts/forever_lint.lua`, runs in `scripts/test.sh` and CI after luacheck) reads
  `api/forever/<CURRENT>/api.json` and checks what luacheck can't: **FL1** event names in
  `RegisterEvent`/`RegisterUnitEvent`/`UnregisterEvent`/`IsEventRegistered` against Blizzard's API documentation;
  **FL2** methods per widget type on variables it can type (`CreateFrame("Type", …, "Template")`, `:CreateTexture()`,
  `:CreateFontString()`, …; `BackdropTemplate` adds `BackdropTemplateMixin`; other templates allow any method), and
  on dumped Blizzard objects at any depth (`Minimap:…`, `MinimapCluster.Tracking.Button:…`, following `<ref>` and the
  node's `<objectType>`; truncated trees aren't checked);
  **FL3** more arguments than a documented function takes, and fewer than it needs once the dump records argument
  defaults (`meta.docsDefaults`; Blizzard marks defaulted arguments non-nilable); **FL4** literals of the wrong kind;
  **FL5** unknown `CreateFrame` types. It reports only what it's sure of. Silence a line with
  `-- forever-lint: ignore FL2`, and only with a reason in the comment.
- Dump format the importer understands (written by `ApiDump.lua` in `../wow-dev-tools`): docs args `name:type`, `?`
  = nilable, `=` = has a default (`name:type?=` both); `objects[<dotted path>]` at any depth, `#<n>` for unnamed
  children, `<objectType>` (widget type), `<ref>` (same table as another path), `<truncated>` (node cap hit). Only
  top-level objects with identifier-safe keys become luacheck fields.
  Owner of the linter and `api/` tooling: the Ordaen Core session.
- **`api.json`** per version is the structured form of the text files (globals, namespaces, widgets, objects, and
  documented `functions`/`events` with typed `args`/`returns`/`payload`), for the linter and other tools (e.g. the
  companion app). `bash scripts/api-import.sh` writes it; `lua5.1 scripts/api_import.lua --rebuild .` (in WSL)
  regenerates every derived file from the committed text files without a new dump.
