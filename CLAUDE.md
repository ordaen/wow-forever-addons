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
  (Performance tab; Claude reads it with `wow_perf`) and time hot spots with `local t = Debug:TimeStart()` ...
  `Debug:TimeEnd(t, "label")` or the statement `Debug:Time("label", fn, ...)` (stripped from release builds, so never
  use its results: forever-lint FL7). Mention the numbers when handing work over.

## Lua code style (user's decision; applies to every session and repo with addon Lua)

- **Object style.** Anything with state or identity is an object whose methods are called with `:`
  (`tooltip:Show(owner)`, `button:On("click", fn)`, `A:OnLogin(fn)`), never a free function that takes the object as
  an argument (`UI.ShowTooltip(owner, tooltip)`). Methods live on one shared metatable per kind (`__index`), never
  copied into each instance.
- **Events:** `obj:On(event, fn)` / `obj:Off(event, fn)` with plain functions only; no `On(event, object, "Method")`
  form. Lua has no bound methods (`obj.Method` loses `obj`, `obj:Method` without a call isn't valid syntax), so a
  callback that needs its object is a closure created once (at load or at creation), never per call or event.
- **Cost:** object style must not hurt performance noticeably: shared metatables, instances created once, no tables or
  closures per call or event. A method call through `__index` is one table lookup and is fine.
- **Stateless helpers stay module functions:** pure math and data (`Layout.Run`, `ns.RingOffset`) need no object.

## Preventing bugs (user's decision; applies to every session)

Every bug class we hit gets a **static check** first; tests and in-game checks come after. A fix without a check that
would have caught it is half a fix: say which check now catches it, or add one.

1. **Typed objects.** Every object kind is a LuaLS `---@class` whose methods are defined with `:`
   (`function Kit:Logf(fmt, ...)`), never assigned as untyped fields (`Logf = noop`), so a dot call is a type error.
   LuaLS findings (`param-type-mismatch`, `missing-parameter`, `undefined-field`, ...) fail `ordaen check` like lint.
   forever-lint FL6 also flags known object methods called with `.`. (Caught by none of these before:
   `debug().Logf(...)` in the drawer, 2026-11-06.)
2. **Lint-first refactors.** Before reshaping an API (renames, `.` to `:`, removed functions), add the check that fails
   on the old form, then convert until it reports nothing. The check decides when the conversion is done, never a
   regex or a reading of the code.
3. **Strict, shared fakes.** Specs use the shared fakes in `tests/OrdaenCore/helpers.lua`, generated from the API
   dump: unknown fields and methods are `nil`, and object fakes check `self` like the real thing. No per-spec stub that
   is looser than the game (a lenient stub made `frame.Button` look real; the no-op kit made dot calls look fine).
4. **Merge only when green.** `develop` moves only through `ordaen merge <branch>` (rebase, `ordaen check`,
   fast-forward only if everything passes). Don't decide "green" from filtered output; read the summary. Check
   `git status`/`git diff --stat` before each commit (a refused file write once left a stale file in a green build).
5. **Isolated features.** Each feature of an addon is an `A:Feature(...)` (Core `Feature.lua`): the framework
   starts each one in its own protected call, so one feature's error is reported and the rest still start.
6. **Check the game after a merge.** After merging and the user's `/reload`, the merging session reads `wow_errors`
   (and `wow_log`/`wow_screenshot` for what it changed) before reporting the change as done.
7. **Handovers happen on an event, never on a timer.** When one addon takes something over from another (a frame,
   a position), the side that comes second completes it: the owner announces its thing when it creates it
   (`EventRegistry:TriggerEvent("OrdaenDevButton.Created", b)`) and the taker also checks at its own start. A
   fixed delay has no ordering guarantee (the Ordaen Dev gear button sat on the minimap border for seconds after
   each reload until a 5 s retry found it, 2026-11-06). Specs cover both orders: created before and after login.

## Game install

- Forever client: `C:\Program Files (x86)\World of Warcraft\_forever_\`
- AddOns folder: `C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\`
- The game loads the **built** addons: `ordaen link` makes a directory junction in the AddOns folder for each addon in `dist/` (nested ones too, e.g. `OrdaenCore_UI`; no admin needed; `--unlink` removes them). They point at `dist/` of the main checkout `C:\Users\f3oal\code\ordaen\wow-forever-addons`, which stays on `develop` (see Branches). Keep `ordaen watch` running there while working: it rebuilds `dist/` on every change, then `/reload`. Without it the game runs the last build.

## Decisions so far

- User wants things done properly from the start (full tooling, not "add later").
- Repo: public GitHub repo `ordaen/wow-forever-addons` (org; user is admin). The org forbids GITHUB_TOKEN from opening PRs, so release-please uses an org GitHub App token (`vars.RELEASE_APP_CLIENT_ID`, `secrets.RELEASE_APP_PRIVATE_KEY`). Default branch `main`, squash-merge only, PR title = commit message.
- Commit identity (global git config): `David Iunevich <1751835+f3oall@users.noreply.github.com>`. GitHub user `f3oall`.
- Signed commits are required on every branch (ordaen org ruleset). Commits are SSH-signed with `~/.ssh/id_ed25519` (global `commit.gpgsign`/`tag.gpgsign`). Commits GitHub creates (squash merges, release-please via the App, Dependabot) are signed by GitHub.
- `main` ruleset: PR-only, squash-only, linear history, required checks `Conventional commits`, `Lint & test (Lua)`, `Package (dry run)`; repo admins may bypass only when merging a PR. Work on a branch and open a PR.
- **Branches (local-only until the user says otherwise: no push, PR or merge on GitHub):**
  - `develop` is the integration branch and the **game checkout**: the main checkout `C:\Users\f3oal\code\ordaen\wow-forever-addons` stays on `develop`, and the game loads it through the junctions. Never switch that checkout to another branch.
  - Do feature work on a branch off `develop` in its own worktree: `git worktree add ../wow-forever-addons-<topic> -b feat/<topic> develop`, then `npm install` there (installs the commit hook).
  - When `scripts/test.sh` is green, rebase onto `develop` and run `git merge --ff-only feat/<topic>` from the main checkout. That keeps the signed conventional commits. Then `ordaen watch` (running in the main checkout) rebuilds `dist/` and the user does `/reload`: on Forever that also picks up new files, TOC changes and even new addon folders (observed 2026-11-06 with OrdaenCore_UI). A new addon must be linked first (`ordaen link`).
  - Revisit at release: `main` is squash-only, so one develop→main PR gives each addon a single changelog line, and a commit touching several addons shows in each addon's changelog. Prefer one PR per addon or feature with a player-facing title. The merged rename PR #4 and release PR #5 need a `BEGIN_COMMIT_OVERRIDE` block so the rename line stays out of the first changelog.
- Line endings: LF everywhere via `.gitattributes`. On Windows, set the exec bit with `git add --chmod=+x scripts/package.sh`.
- Commits: Conventional Commits via commitlint (`commitlint.config.mjs`; scope = addon folder name or repo scope), enforced by husky `commit-msg` hook and in CI (PR title + PR commits).
- Versioning: release-please manifest mode (`release-please-config.json`, `.release-please-manifest.json`), one component per addon, tags `<Addon>-vX.Y.Z`. release-please bumps `"version"` in the addon's `addon.jsonc` (the line marked `// x-release-please-version`; nested addons take their parent's) — never edit it by hand.
- Quality: luacheck + busted (pure-logic tests only, Lua 5.1) in CI; manual testing in game with dev mode (Ordaen Core - Debug).
- **Forever lacks many retail/classic FrameXML helpers** (e.g. no global `MouseIsOver`; it errored every frame in the
  drawer). **The source of truth is the in-game API dump in `api/forever/`** (see "Forever API dump" below): never use,
  list or stub a WoW global, namespace function or widget method that isn't in `api/forever/$(cat CURRENT)/`. luacheck
  and the specs enforce this once a dump is imported. Before the first dump (or for things a dump can't see), confirm
  by a Forever-specific addon using it (`*Camelot*`/`Forever*` files) or a `/dump` in game; unconfirmed APIs get a
  fallback and go in the dev-mode `api:` log line (`UNCONFIRMED_APIS` in `addons/OrdaenMinimap/Core.lua`).
- Dev environment is Windows + WSL only (README "Development" describes nothing else). Lua 5.1, luacheck and busted live in the WSL distro `Ubuntu`; `ordaen` (and `scripts/test.sh`, which calls it) runs them there. From Git Bash, call WSL with `MSYS_NO_PATHCONV=1` and `--exec` (otherwise Git Bash rewrites `/mnt/...` paths and WSL's shell expands `$1` early).
- Packaging: BigWigs packager (pinned in `scripts/package.sh`). It requires a git repo root as topdir, so the script copies the addon into a temp git repo and tags it. Packager handles CurseForge/Wago uploads; the zip is attached to release-please's GitHub release with `gh release upload` (packager's own GitHub upload would overwrite the release notes). Packager maps interface `16???` to the `forever` flavor (CurseForge game id 88568).

## Layout

```
addons/<Addon>/                 addon source: addon.jsonc, *.lua, locales/<code>.json, media (no .toc/.pkgmeta/
                                Locale*.lua: the build generates them)
addons/OrdaenCore/              shared code every addon depends on (global OrdaenCore; addon framework: Addon.lua,
                                Settings.lua; no-op debug stand-in; OrdaenCore.UI framework: UI.lua + OrdaenCore_UI/)
dist/<Addon>/                   the built addons the game loads (ordaen build / watch; gitignored)
ordaen.jsonc                    repo-wide build settings: interface version, languages, category names
tests/<Addon>/*_spec.lua        busted specs (helpers.loadAddon loads a built addon from dist/ in TOC order)
tests/OrdaenCore/helpers.lua    WoW API stubs + Core loader, for any spec that needs the Core
scripts/package.sh              package one addon from its release build (CI + Git Bash)
scripts/test.sh                 `ordaen check` (build, luacheck, forever-lint, busted); with args: ordaen test -- args
.ordaen-version                 the ordaen CLI release CI installs (.github/actions/ordaen)
scripts/api-import.sh           import the in-game API dump into api/forever/ (api_import.lua does the work)
scripts/forever_lint.lua        forever-lint: addon code against api/forever/<CURRENT>/api.json (json.lua: its JSON)
api/forever/<version>-<build>/  the real Forever API per client version (generated; history in git)
docs/                           OrdaenCore.UI docs site (VitePress, own package.json): cd docs && npm i && npm run dev
.github/ISSUE_TEMPLATE/         bug report form the in-game error report links to
.claude/skills/debug-in-game/   how Claude debugs in-game behavior (loaded on demand)
.github/workflows/ci.yml        commitlint, luacheck, busted, packaging dry run
.github/workflows/release.yml   release-please, then package + upload per released addon
```

## Branding

Every addon is named `Ordaen<Name>` (folder, .toc, globals) with TOC title `Ordaen <Name>`, so CurseForge search
finds them all. One CurseForge project per addon (no pack). Every addon sets `"category"` in its addon.jsonc; the
build writes `## Category:` plus the localized `## Category-xxXX:` lines from `ordaen.jsonc` (copied from an installed
addon that uses the same category, so ours share a group in the addon list): OrdaenCore is `Libraries`, feature
addons use e.g. `User Interface`.

## Build (`ordaen`, private CLI in `../wow-dev-tools/cli`)

The source in `addons/` is built into `dist/`, which the game, the specs and the release zips use. The code is the
source of truth; `addon.jsonc` holds only what code can't say (title, notes, category, icon, version, minCore,
loadOnDemand, CurseForge slug/ids). `ordaen build` writes per addon:

- the **TOC**: header from addon.jsonc + `ordaen.jsonc`; `## Dependencies` from the globals the code uses (reading
  `OrdaenCore` means OrdaenCore; then `## OptionalDeps: OrdaenCore_Debug` too); `## SavedVariables` from
  `OrdaenCore.NewAddon(…, { db = "…", charDb = "…" })`; the **file list in load order derived from the code**: a file
  that reads `ns.X` (or a global of the addon) at load comes after the file defining it, ties alphabetical. Only code
  that runs at load counts: the top level and functions it calls; reads inside other functions don't.
  `ordaen build --explain` prints why each file has its place.
- **locales**: `locales/<code>.json` -> `Locale.lua` + `Locale_<code>.lua` (see Localization);
- **settings and themes**: `settings.jsonc` -> `SettingsSchema.lua` (`ns.SETTINGS_SCHEMA`) + `settings.schema.json`, and
  `## SavedVariables` from its `db`/`charDb`; Ordaen Core's `themes.jsonc` -> `ThemeTokens.lua` (`ns.THEME_TOKENS`) +
  `themes.json`; dev builds write LuaLS classes (`<Addon>Settings`, `<Addon>Addon`) to `.ordaen/types/` (gitignored);
- **conflicts**: `conflicts = { ... }` in the NewAddon spec or an `A:Feature` -> `## X-Ordaen-Conflicts`;
- the **.pkgmeta**: package-as, changelog, `move-folders` for nested addons, required-dependencies (slugs);
- release builds (`--release`, used by `scripts/package.sh`): the debug kit's statements
  (`Debug:Log/Logf/Warn/Warnf/Verbose/Verbosef/Dump/Trace/TraceFrame(…)`, dot or colon form) and
  `if Debug:IsEnabled() then … end` / `if Debug:TraceEnabled() then … end` blocks become spaces (line numbers in players' error reports still match the
  source); `*.dev.lua` and `dev/` are left out. So Debug call arguments must not have side effects.

The build refuses, with file:line (also in `ordaen check` and CI): B1 `ns.X` read at load that no file defines, B2 the
same `ns.X`/global defined in two files, B3 files reading each other at load (a cycle), B4 a call at load into
another file's `ns` function (do it in `OnLoad`/`OnLogin`), B5 locale problems, B6 manifest problems (also a
hand-written .toc/.pkgmeta/Locale*.lua in addons/), B7 settings and theme manifests (`settings.jsonc`, `themes.jsonc`: types, ranges, choices, assets, tokens, locale keys, db named in one place, the `--[[@as <Addon>Addon]]` cast on NewAddon; docs/reference/settings.md). Commands: `ordaen build|watch|link|lint|test|check`
(`--json` for tools; `cli/README.md` in wow-dev-tools).

## Localization

- English and Russian for now; the user's client is ruRU. Every user-facing string goes through `ns.L`.
- **Writing player-facing text** (user's rules): the skills `text-en` and `text-ru` (`.claude/skills/`), for every
  string in a locale file, addon.jsonc, popups and CurseForge pages. In short: no fluff, clear instructions, the
  game's own words; mouse buttons are `Left-click`/`Right-click` in English and `ЛКМ`/`ПКМ` in Russian.
  `tests/repo/locale_text_spec.lua` fails on the wording the rules forbid.
- Per addon: `locales/<code>.json` (`{ "KEY": "text" }`, keys UPPER_SNAKE_CASE), one file per language in
  `ordaen.jsonc` `"locales"`. The build generates `Locale.lua` (English base and fallback: an unknown key shows as
  itself; sets `ns.L` and `ns.LOCALE`) and one `Locale_<code>.lua` per other language, which returns at once unless
  the client is in that language, so only the client's language stays in memory (see Performance).
- The build refuses missing or unknown keys and different format placeholders (`%s`, `%d`) between languages. Add a
  key to every `locales/*.json` together. Ordaen Core's own strings (help, reset) are in its own locales.
- Labels in declarations (settings, command help) are locale keys, not strings.
- Use Blizzard's own translated globals for common words where they fit (`CLOSE`, `OKAY`, `CANCEL`, `RESET`, `NONE`,
  `SETTINGS`), after confirming they exist on Forever.
- TOC: `"notes"` (and `"title"`) in addon.jsonc may be `{ "enUS": …, "ruRU": … }`, giving `## Notes-ruRU` lines;
  categories come localized from ordaen.jsonc. Whether titles get a `## Title-ruRU` (e.g. "Ordaen Миникарта") is
  still for the user to decide; until then titles stay English.
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
  from theme data (`Theme.lua`: per style role the surface, colours and layout defaults; per text style font, size
  tier, colour, shadow, caps). No second renderer, no fallback branches. `color` on an element is for meaning (a
  pending invite), not decoration; `accent = { r, g, b }` on a block tints it for meaning (quality, PvP).
- **Three themes, always** (user's rule for every theme set): our own `ordaen` look is the default (flat surfaces
  drawn without art, tinted by an accent; approach credited to PrettyTooltip, values our own), `blizzard` (Blizzard's
  art and shadowed text) is an option, and `minimal` (flat, hairlines, no effects) is the third. Every theme defines
  every role. A theme addon later adds a set of three, never one.
- **Addons follow the theme** (user's rule, 2026-11-06): addons never define their look. Every look setting (frame
  art, font, colour, bar texture, sound, fade) defaults to a **theme token** (`"default": { "theme": "frame.border" }`
  in the addon's `settings.jsonc`); only behaviour settings (columns, on/off, positions) have plain defaults. The
  tokens, the shared assets (frame art, fonts, bar textures) and each theme's value for every token live in
  `addons/OrdaenCore/themes.jsonc`, checked by the build (every theme defines every token; every reference names a
  token of the right type; `asset`/`color`/`sound` settings must follow a token). The UI renderer's `Theme.lua`
  reads its accent and fonts from the same tokens. Saved settings hold only the player's choices and override the
  theme in the Core: a player may pick another theme's asset for one addon. Contract:
  `docs/reference/settings.md` (Core session: the build checks; UI session: runtime, page, manifests).
- **One design scale, global settings** (user's decision): sizes, fonts and spacing are global for every Ordaen addon,
  chosen in Ordaen Core's settings (`OrdaenCoreDB.ui.theme`, `.textSize` = body px 10-16; c4 owns the page,
  `CoreSettings.lua`, which calls `OrdaenCore.UI._SettingsChanged()`). Spacing tokens `xs sm md lg xl` and text
  tiers `tiny small body large title` are derived from the text size; addons name tokens and roles, never numbers
  for text-related sizes. Edges and lines are whole physical pixels (`PixelUtil`).
- **Layout** (`OrdaenCore_UI/Layout.lua`, pure Lua, `layout_spec.lua`): two passes like CSS grid: column widths
  (fixed, auto, then fr shares; too little room shrinks fr then auto columns, never below 8 px), then row heights from
  text wrapped to those widths. Text is measured by the renderer with the theme's fonts, cached per element.
- **Loading:** `addons/OrdaenCore/UI.lua` (always loaded, tiny) loads the module `OrdaenCore_UI` (`LoadOnDemand`,
  shipped in the Core zip via `move-folders`, versioned with Core) on the first `ShowTooltip`; Hide/Refresh never
  load it. If it can't load (disabled, missing), one chat line says why and tooltips stay off quietly.
- **Cost:** callers build their block tables once and change fields (`text`, `hidden`, `args`), then `:Refresh()` from
  their own timer or event. One shared tooltip surface; font strings and textures are pooled; layout results are
  reused tables; nothing is copied per show; no timers or `OnUpdate` in the framework. Text that changes often is
  `{ format = "...", args = { ... } }`, drawn with `SetFormattedText` (no Lua string per change).
- **Components** (user's decision, object style): a **block** is data; a **component** is a kind of thing on screen
  (Tooltip, Block, Button; later windows, inputs, bars, dropdowns, and addon-defined ones); an **instance** is an
  object with `:` methods sharing one metatable per component, owning its WoW frame (`instance.frame`).
  - `local tip = UI.Tooltip(block, opts)`: the same table with methods `:Show(owner)`, `:Hide(owner?)`, `:Refresh()`,
    `:IsShown()`; made in the always-loaded `UI.lua`, so it loads nothing until the first `:Show`.
    `opts = { side = "right" | "left" | "below" | "above" | "default", x, y }`.
  - `UI.Block(spec)`, `UI.Button(spec)` (style `button` by default): spec = block + `name`, `parent`, `strata`,
    `level`, `tooltip`, `on`. Methods `:On(event, fn)`, `:Off`, `:Tooltip(tip)`, `:Refresh()`, `:SetText()`, and
    placement passed to the frame (`SetPoint`, `Show`, `GetCenter`, `LockHighlight`, ...). They load the framework
    and return nil if it can't load.
  - Block styles in every theme: `tooltip`, `header` (`UI.Header` preset: icon, title, subtitle, band), `button`,
    `iconButton` (the gear-button look), `slot`; text styles `title`, `subtitle`, `body` (default), `label`, `value`,
    `hint`, `caption`, `normal`, `small` (the last two for text on the world, with a shadow). Elements also include
    separators (`rule`, `divider`, `caption`) and bars; `shift = true/false` rows show only with/without Shift.
- **Scale and position** (user's decision): our blocks live on the global UI scale only (children of `UIParent`, sizes
  in UI units, no scale property). A block attached to a scaled Blizzard frame inherits that frame's scale; the
  renderer measures text on the surface it draws on, so either way it fits. An anchored tooltip takes only its
  position from its owner, never its scale. Tooltips anchored to nothing (`side = "default"`) sit where Blizzard
  puts its own: Edit Mode's "HUD Tooltip" position (`GameTooltipDefaultContainer`, bottom-right to bottom-right).
- **Tooltips** (user's rules, 2026-11-06): everything on our UI shows OrdaenCore.UI tooltips, including Blizzard
  buttons we adopt (the minimap's tracking, mail, expansion buttons: hook their OnEnter, hide GameTooltip, show
  ours from Blizzard's data); ask other Ordaen addons (Ordaen Dev) to do the same. A tooltip anchored beside what
  it describes has **no title** naming that thing (the clock's tooltip doesn't say "Time"): it's obvious from the
  mouse. Titles only for custom things whose purpose isn't self-evident (the drawer button, compartment entries,
  Ordaen Dev).
- **Every tooltip in our style** (user's decision 2026-11-06, replacing "restyle in place, never redraw"): the addon
  **Ordaen Tooltips** draws Blizzard's and other addons' tooltips with OrdaenCore.UI. The native tooltip
  (GameTooltip, ItemRefTooltip, later the comparison tooltips) stays the owner of its content and stays shown at
  alpha 0, so every addon that fills or checks it works as before; we read it (`Reader.lua`: its lines, and its
  tooltip data for prices and later per-type layouts) and draw our view in its place. Anything secret
  (`issecretvalue`, combat) or forbidden stays native for that show. Only hooks (`hooksecurefunc`, `HookScript`),
  never replaced methods. It replaces PrettyTooltip for the user; native types (items, units, spells, quests,
  auras) get their own layouts step by step.
- **Events** (user's decision, built in `OrdaenCore_UI/Component.lua`): `instance:On(event, fn)` / `:Off(event, fn)`
  with plain functions only, or `on = { ... }` in the spec, for both sources. User events are lower case (`click`,
  `enter`, `leave`, `mousedown`, `mouseup`, `dragstart`, `dragstop`, `wheel`, later keyboard); system events are
  Blizzard's own UPPER_CASE event names (`CALENDAR_UPDATE_PENDING_INVITES`) and get Blizzard's arguments unchanged.
  Listeners get the instance first. No bubbling: only the block with the listener gets it (as in native WoW). One
  shared event frame registers a game event only while some instance listens and unregisters it after the last; a
  frame takes the mouse only once it has a user listener. WoW scripts are set to dispatchers made once at load, so
  `:On` creates no closure. High-frequency game events are allowed but must exit early.
- **Elements:** text, image, blocks, and the inputs that can't be composed from blocks because they need WoW's own
  widgets: text entry (EditBox), checkbox (CheckButton) and slider. Buttons, bars and dropdowns are composite blocks.
- **Out of scope for v1:** secure actions (casting, using items, targeting). They need Blizzard's secure templates,
  and touching those from addon code causes blocked-action (taint) errors; an addon that needs one uses Blizzard's
  templates directly.
- **Open:** declarative shortcuts (e.g. `tooltip = block` for enter/leave; to be decided); positions of top-level
  blocks (anchored, cursor, fixed and remembered) and interaction states (hover, pressed, disabled, selected); resizing;
  scrolling and repeated lists; theme addon API; packaging the framework as an embeddable library for other addons.
- PrettyTooltip (MIT, © 2026 FallenShard) is a reference and a source of features, not a base to fork. Any code taken
  from it keeps its copyright notice and license text.
- **Docs:** `docs/` is the framework's documentation site (guide, reference, roadmap). Every change to the UI API, the
  block format, layout rules or the theme updates the matching page in the same commit; planned parts stay on
  `docs/roadmap.md` until built. Check with `npm run build` in `docs/` (fails on dead links).

## First addon: OrdaenMinimap

Our own specialized take on **SexyMap** (installed reference: `_forever_\Interface\AddOns\SexyMap\`), deliberately with
little configuration: opinionated defaults instead of option panels. Renamed from MinimapCompartment before its first
release; the button drawer + addon compartment is one feature of it. Feature scope beyond the drawer is still to be
decided with the user.

- SavedVariables `OrdaenMinimapDB`; slash `/om` opens the settings (alias `/ordaenminimap`), `/om reset` restores defaults.
- Forever runs the **modern (mainline) minimap code** with Forever tweaks (SexyMap loads its mainline files there; its
  `Init_Camelot.lua` sets `isForever`). Frame names differ between clients, so `Map.lua` looks up each Blizzard piece by
  several names, skips missing ones and records what it found (dev-mode dump: "Send state" in the Ordaen Dev window, read with `wow_dump`). Toggling "rotate minimap"
  runs `MinimapCluster:UpdateMinimapConfig`, which resets the mask and sizes: we hook it and re-apply.
- Settings page: declared in `Core.lua` (`settings` of `OrdaenCore.NewAddon`); the Core's `Settings.lua` builds it
  with Blizzard's Settings API and keeps the saved values valid.
- Files: `locales/*.json` (enUS + ruRU; the user's client is ruRU), `Borders.lua` (border styles as data, defaults,
  pure helpers), `Ring.lua`/`Buttons.lua` (buttons around the map), `Info.lua` (zone, coordinates, clock), `Map.lua`
  (square mask, hide Blizzard pieces, wheel zoom, border frame, scale, `GetMinimapShape`), `Core.lua` (the
  `NewAddon` declaration: SavedVariables, settings page, slash; starts the features). Specs: `borders_spec.lua`
  (logic) and `smoke_spec.lua` (loads the whole built addon against stubbed WoW objects).
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

- `addons/OrdaenCore/` holds the code every addon shares. It publishes the global `OrdaenCore` and contains no features. The build gives every addon that uses it `## Dependencies: OrdaenCore`, `## OptionalDeps: OrdaenCore_Debug` and `required-dependencies: [ordaen-core]` in `.pkgmeta` (the CurseForge slug, `"package"` in addon.jsonc, is a guess until the project exists); `"minCore"` in addon.jsonc becomes `## X-Ordaen-MinCore`.
- **The Core API only grows.** Users update the Core and the addons independently. Never change the behavior of a released Core function or remove one; add a new name instead. When an addon starts using a new Core API, raise its `"minCore"`. `OrdaenCore.IsCompatible(addonName)` enforces that in packaged builds; git checkouts are detected by the unreplaced `@project-version@` token in `Core.lua` and skip the check.
- **Every addon starts through the framework** (`addons/OrdaenCore/Addon.lua`, example `addons/OrdaenMinimap/Core.lua`): `local A = OrdaenCore.NewAddon(addonName, ns, { db = "…DB", defaults = {…}, slash = {…}, settings = {…}, dump = fn })`, then `if not A then return end` (Core too old; the player was told). The spec is a table written in the file (the build reads `db`/`charDb`). The framework checks compatibility, takes the addon's debug kit (`A.Debug`; `Debug:Init` with the SavedVariables on its ADDON_LOADED, slash input through `Debug:HandleSlash`), fills defaults (deep, never overwriting), builds the settings page (`Settings.lua`: dropdown for `choices`, slider for numbers with min/max, checkbox for booleans; labels are locale keys; saved values kept valid), and registers the slash commands (`/x` opens settings, `/x reset` restores defaults then runs `A:OnReset`, `A:Command(name, fn, helpKey)`, help for anything else). Lifecycle: `A:OnLoad(fn(db, charDb))`, `A:OnLogin(fn)` (right away for load-on-demand addons loaded after login). Events: `A:On(event, fn(event, ...))` / `A:Off` on one frame shared by all Ordaen addons, handlers in the order added, each through `securecallfunction` so one failing handler doesn't stop the others; register only while a feature needs it. Unit events: `A:OnUnit(event, unit, fn)` / `A:OffUnit` (`RegisterUnitEvent` on one frame per unit). **Features** (`Feature.lua`): `local F = A:Feature(name, { setting = "drawerEnabled", when = fn(db) })` is on after login while its boolean setting and `when` say so (`F:Refresh()` re-checks `when`); `F:OnEnable(fn(db))`, `F:OnDisable`, `F:OnChange(fn(key, value))` (other settings, while on); what it registers runs only while it is on and is released when it goes off: `F:On/Off`, `F:OnUnit/OffUnit`, `F:Every`, `F:Hook`. **Timers** (`Timer.lua`): `A:Every(seconds, fn)` / `F:Every` return a ticker (`:Start()`, `:Stop()`, `:IsRunning()`); all tickers of all Ordaen addons share one `C_Timer.After` chain set for the next one due (no `OnUpdate`, no garbage per tick); make tickers once and Start/Stop them. **Hooks**: `A:Hook(object, "Method", fn)` / `A:Hook("GlobalFn", fn)` / `F:Hook` (`hooksecurefunc` once per function; false and a dev-log warning when the function is missing). **Migrations**: `migrations = { fn(db), ... }` (and `charMigrations`) in the spec: each runs once, in order, before defaults are filled; `db._schema` counts them, new SavedVariables start counted, a failing one is reported and retried next load; append only. **Conflicts** (`Conflict.lua`) with third-party addons are declared in code: `conflicts = { "SexyMap" }` in the spec (at login, before OnLogin, `A:OnConflict(fn(other))` runs for each one loaded; unhandled ones are recorded as such) or in `A:Feature(name, { conflicts = { "MinimapButtonButton" } })` (the feature stays off while it is loaded). The build writes them to the TOC as `## X-Ordaen-Conflicts` (the companion reads it from disk). Runtime findings: `A:Conflict(other, what, handled)` (`what` short English for developers; `handled` = we adapted). Records stay in memory (max 20 per addon, `A:Conflicts()`); dev mode sends each to the companion (`Debug:Conflict`). Also `A:AfterCombat(fn)`, `A:Compartment{ onClick, onEnter, onLeave, icon }` (Blizzard's addon compartment), `A:OpenSettings()`, `A:Print(...)`. New code logs its decisions with `A.Debug:Log` (stripped from release builds). In dev builds the framework traces for the companion: each event handled (per owning addon), slash input and settings changes, through `Debug:Trace(what, detail)` guarded by `if Debug:TraceEnabled() then … end`; frames worth tracing (hover, click, show) are registered with `Debug:TraceFrame(frame)` in the same guarded form.
- Before handing code over for an in-game test, run `bash scripts/test.sh` (= `ordaen check`) until it is green, with `ordaen watch` running so `dist/` is current. `/reload` is enough on Forever, also for new files, TOC changes and new (linked) addon folders.
- **Debugging is opt-in development mode.** Players get a no-op stand-in from the Core: nothing is recorded and errors take WoW's normal path (BugSack, Blizzard). The real kit is the dev-only addon `OrdaenCore_Debug` ("Ordaen Core - Debug"), which lives in the **private repo `../wow-dev-tools`** next to the companion app and is never shipped (decided by the user: dev tooling, including the pixel channel, stays private). Its own `scripts/link.ps1` junctions it into the AddOns folder; its specs load the built Core (`dist/OrdaenCore/`, TOC order) and `api/forever/` from this checkout. Keep the stand-in's API in step with it: the kit is an object (methods on a shared metatable, called with `:`): `Init, IsEnabled, Log, Logf, Warn, Warnf, Verbose, Verbosef, Wrap, Call, Dump, Snapshot, HandleSlash, HelpLines, Trace, TraceFrame, TraceEnabled, TimeStart, TimeEnd, Time, Conflict`; levels error/warn/info (Log)/debug (Verbose, Trace). Installing and enabling it turns on dev mode: our own error catcher (global error handler chained to the previous one, or BugGrabber's callback when BugGrabber keeps the handler; plus taint events), per-addon logs and dumps, the Ordaen Dev window, and a live stream to the companion app (wow-dev-tools), which serves it to Claude as the MCP server `ordaen`: `wow_status`, `wow_errors`, `wow_log`, `wow_watch`, `wow_screenshot`, `wow_dump` (after the user clicks "Send state"), `wow_perf` (Performance tab: memory, CPU, `Debug:Time` labels), `wow_check`. The user describes what they saw in chat; Claude reads the rest live (no notes, no reload just for Claude). All dev data goes to one SavedVariables table, `OrdaenCoreDebugDB`, never into players' addon settings. Never make players' builds record anything. Plan for the window: Errors and Performance (done), then Log, Inspect (frame picker, outlines). Prefer UI in the window over new slash commands.
- For anything observed in game (bugs, errors, layout, "check" after a reload), follow the `debug-in-game` skill (`.claude/skills/debug-in-game/SKILL.md`).
- Addons have no network access, so there is no telemetry. Players report errors through BugSack/Blizzard's error frame and the GitHub issue form; add each new addon to the form's dropdown.

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
- **LuaLS type checking**: the import also writes `api/forever/luals/*.lua` (`scripts/luals_defs.lua`, from the
  current api.json): widget classes with inheritance worked out from the method sets (`Frame`, `Button : Frame`,
  `Texture`, … unprefixed, as `GetObjectType()` names them; `CreateFrame("Button")` returns `Button`, with
  `"BackdropTemplate"` a `ButtonWithBackdrop`), typed documented functions (arguments after the first are optional
  until the dump records defaults), `WowEvent` (every documented event name) for `RegisterEvent` & co., the dumped
  objects (`MinimapObject`, `MinimapCluster_TrackingObject`, …), every other global. `.luarc.json` points
  lua-language-server at it (editors use it too); `ordaen lint`/`check` run `lua-language-server --check` and report
  its warnings (tool `luals`). Our own types: classes prefixed by addon (`OrdaenUI…` for OrdaenCore.UI,
  `OrdaenMinimap…`), custom fields on frames declared with `---@class X : Button` + `---@field`, casts with
  `--[[@as X]]`. Other addons' globals (LibStub, BugGrabber) and our SavedVariables are listed in `.luarc.json`.
