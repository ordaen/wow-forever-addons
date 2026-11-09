# wow-forever-addons

Monorepo of World of Warcraft addons for the **WoW Forever** flavor (interface `16001`).
Developed on Windows (the user normally works on Linux — explain Windows specifics when relevant).

## Performance: every KB and every CPU cycle matters (non-negotiable)

Set in stone: our addons must cost as close to nothing as possible. "It's only 100 KB" or "it's only
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
- **SavedVariables: be deliberate.** They may hold more than settings (each character's
  gold for a realm total, say) when the feature needs it across sessions, but every stored thing is a choice made on
  purpose: say in the code why it's saved, keep it small, give anything that can grow a hard cap, drop entries that go
  stale (a deleted character), and don't save what can be rebuilt cheaply. They are parsed at login and written at
  logout for every character.
- **Hooks only on rarely called functions,** with cheap bodies. Expensive work in a hook (`debugstack`, re-applying a
  layout) is rate-limited or cached.
- **Dependencies:** no library unless Blizzard's API can't do it. OrdaenCore stays small; dev-only code lives in
  `OrdaenCore_Debug`, which players never load.
- **Measure, don't guess:** before merging a feature into `develop`, check its memory and CPU in the Ordaen Dev window
  (Performance tab; Claude reads it with `wow_perf`) and time hot spots with `local t = Debug:TimeStart()` ...
  `Debug:TimeEnd(t, "label")` or the statement `Debug:Time("label", fn, ...)` (stripped from release builds, so never
  use its results: forever-lint FL7). Mention the numbers when handing work over.
- **Measure what players run:** a number counts only from the bench profile (`## X-Ordaen-Build: bench`, release
  stripping). A measurement or a performance review starts by confirming the build, the loaded addons and the settings;
  a wrong build blocks the review, it isn't a footnote.
- **What's already measured:** [performance.md](performance.md) holds the costs measured in game (WoW calls, pixels,
  CPU against GPU, bench findings). Read it before choosing an approach; add to it what a probe or bench round settles.

## Lua code style (applies to every session and repo with addon Lua)

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

## Preventing bugs (applies to every session)

Every bug class we hit gets a **static check** first; tests and in-game checks come after. A fix without a check that
would have caught it is half a fix: say which check now catches it, or add one.

1. **Typed objects.** Every object kind is a LuaLS `---@class` whose methods are defined with `:`
   (`function Kit:Logf(fmt, ...)`), never assigned as untyped fields (`Logf = noop`), so a dot call is a type error.
   LuaLS findings (`param-type-mismatch`, `missing-parameter`, `undefined-field`, ...) fail `ordaen check` like lint.
   forever-lint FL6 also flags known object methods called with `.` (such as `debug().Logf(...)`).
2. **Lint-first refactors.** Before reshaping an API (renames, `.` to `:`, removed functions), add the check that fails
   on the old form, then convert until it reports nothing. The check decides when the conversion is done, never a
   regex or a reading of the code.
3. **Strict, shared fakes.** Tests mount components with the fake `game` (design: development/framework/testing),
   generated from the API dump: unknown fields and methods are `nil`, and object fakes check `self` like the real
   thing. No per-test stub looser than the game (a lenient stub makes a missing frame look real).
4. **No checks by default: the game decides.**
   `develop` moves only by fast-forward (see "Branches"), nothing else. Don't run `ordaen check` before handing over
   or merging, nor after. Run checks only when the debug addon shows errors in game (`wow_errors`), and then for the
   area involved: `ordaen test -- <spec>`, `ordaen lint`. When a check on develop fails, the session that merged last
   fixes it next.
   The checks themselves exist all the same: CI runs them, and every new bug class gets one, as above. Check
   `git status`/`git diff --stat` before each commit (a refused file write can leave a stale file in a build).
5. **Isolated components.** Every setup, effect run and handler runs in its own protected call: one that fails is
   reported and rolled back, and the rest still run (design: development/framework/transaction).
6. **Check the game after a merge.** After merging and the user's `/reload`, the merging session reads `wow_errors`
   (and `wow_log`/`wow_screenshot` for what it changed) before reporting the change as done. What it draws must match
   its design page 1:1: compare `wow_screenshot` regions with the design site's rendering for textures and atlases,
   borders (whole pixels, which sides), sizes, spacing, clipping, overflow, alignment, colours and z-order. Fix every
   difference or raise it; never "close enough".
7. **Player actions stay in the click's own call; reloading needs secure code.** Code that a click runs (UI
   listeners, dialog buttons) calls protected functions only directly, without `securecallfunction`, C_Timer or
   another frame's script in between; catch errors with `xpcall`. `ReloadUI` / `C_UI.Reload` are stricter on
   Forever: blocked from any addon code, even directly in a click. Reload with a
   `UI.Confirm` button's `macro = "/reload"` (a secure overlay runs it), or tell the player to type `/reload`.
   A secure button acts only on the press the player's `ActionButtonUseKeyDown` setting names (key down by
   default): register exactly that half (`RegisterForClicks("LeftButtonDown")` or `"LeftButtonUp"`).
   forever-lint FL8 flags `ReloadUI` passed as a value (`AfterCombat(ReloadUI)`, `C_Timer.After(x, ReloadUI)`);
   specs can't see the rest (fakes have no "hardware event" or secure state), so a protected action gets an in-game
   check.
8. **Handovers happen on an event, never on a timer.** When one addon takes something over from another (a frame,
   a position), the side that comes second completes it: the owner announces its thing when it creates it
   (`EventRegistry:TriggerEvent("OrdaenDevButton.Created", b)`) and the taker also checks at its own start. A
   fixed delay has no ordering guarantee, and whatever it moves sits in the wrong place until it fires. Specs cover
   both orders: created before and after login.
9. **One source of truth** (same rule in wow-dev-tools' CLAUDE.md): every fact
   lives in exactly one place, and everything else reads it from there (requires it, or gets it generated by the
   build), never a copy. The sources here:
   - `addon.jsonc` for an addon's title, icon, notes and category;
   - `settings.jsonc` for setting keys and defaults, `themes.jsonc` for looks;
   - `locales/*.json` for text, Blizzard's globals for the game's own words;
   - `api/forever/` for what the game has;
   - `ns.X` defined by one file (build check B2).

   Before adding a constant, a list or a map, look for where the fact already lives and read it from there.
   - **A copy is a bug:** finding one, remove it and point its users at the source. Where a copy can't go yet, add a
     check that fails on drift, as for any bug class.
   - **Generated files are never edited by hand** (`Locale*.lua`, `SettingsSchema.lua`, `Claims.lua`, the TOC, the
     `api/forever/` files): change the source and rebuild.
10. **State, never log** (same rule in wow-dev-tools' CLAUDE.md): rules, docs, design pages, code comments and
   manifests say how things are now. When something changes, rewrite the text where it stands to the new state. Never
   append the change as a story: no "(the user, <date>)", "moved here from X", "was Y", "first …, then …", "no longer",
   "now" or "Found <date>: …". History lives in git: put it in the commit message. A reason may stay when it isn't
   obvious, written as a reason ("hidden in combat: the frame is protected"), never as an event.
11. **Design checklist before showing any design** (same rule in wow-dev-tools' CLAUDE.md): every API, declaration,
   file format or tool interface is checked against the list in `../wow-dev-tools/design/development/rules.md`
   («Design checklist»: no invalid value can be written, rules hold by construction, nothing listed by hand, no fact
   twice, no Lua traps, one name per concept) before it goes to the user, and what the check caught is said with it.
   The standard is general software engineering, not WoW-addon habit.

## Game install

- Forever client: `C:\Program Files (x86)\World of Warcraft\_forever_\`
- AddOns folder: `C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\`
- The game loads the **built** addons: `ordaen link` makes a directory junction in the AddOns folder for each addon in `dist/` (nested ones too; no admin needed; `--unlink` removes them). They point at `dist/` of the main checkout `C:\Users\f3oal\code\ordaen\wow-forever-addons`, which stays on `develop` (see Branches). Keep `ordaen watch` running there while working: it rebuilds `dist/` on every change, then `/reload`. Without it the game runs the last build.

## Repo and workflow

- Things are done properly from the start: full tooling, never "add later".
- Repo: public GitHub repo `ordaen/wow-forever-addons` (org; user is admin). The org forbids GITHUB_TOKEN from opening PRs, so release-please uses an org GitHub App token (`vars.RELEASE_APP_CLIENT_ID`, `secrets.RELEASE_APP_PRIVATE_KEY`). Default branch `main`, squash-merge only, PR title = commit message.
- Commit identity (global git config): `David Iunevich <1751835+f3oall@users.noreply.github.com>`. GitHub user `f3oall`.
- Signed commits are required on every branch (ordaen org ruleset). Commits are SSH-signed with `~/.ssh/id_ed25519` (global `commit.gpgsign`/`tag.gpgsign`). Commits GitHub creates (squash merges, release-please via the App, Dependabot) are signed by GitHub.
- `main` ruleset: PR-only, squash-only, linear history, required checks `Conventional commits`, `Lint & test (Lua)`, `Package (dry run)`; repo admins may bypass only when merging a PR. Work on a branch and open a PR.
- **Branches (local-only until the user says otherwise: no push, PR or merge on GitHub):**
  - `develop` is the integration branch and the **game checkout**: the main checkout `C:\Users\f3oal\code\ordaen\wow-forever-addons` stays on `develop`, and the game loads it through the junctions. Never switch that checkout to another branch.
  - Do feature work on a branch off `develop` in its own worktree: `git worktree add ../wow-forever-addons-<topic> -b feat/<topic> develop`, then `npm install` there (installs the commit hook).
  - Merge once, with `ordaen merge feat/<topic>` (from any checkout; rule 4: no check): it rebases the worktree onto develop and fast-forwards develop. If it reports develop red after your merge, fixing develop is your next task. Then `git worktree remove ../wow-forever-addons-<topic>` and `git branch -d feat/<topic>`. That keeps the signed conventional commits. Then `ordaen watch` (running in the main checkout) rebuilds `dist/` and the user does `/reload`: on Forever that also picks up new files, new textures (`.tga` in media/: no client restart), TOC changes and even new addon folders. A new addon must be linked first (`ordaen link`).
  - Revisit at release: `main` is squash-only, so one develop→main PR gives each addon a single changelog line, and a commit touching several addons shows in each addon's changelog. Prefer one PR per addon or feature with a player-facing title. The merged rename PR #4 and release PR #5 need a `BEGIN_COMMIT_OVERRIDE` block so the rename line stays out of the first changelog.
- **Help when busy:** when an owner is busy, any session may do the work in its area (the renderer, Core, an addon),
  and a session that needs something from a busy owner does it itself. Tell the owner first what you'll change, work on
  your own branch, merge it (rebase, fast-forward), and report back after.
- **The sessions:** with the user they go by codenames: Plumb (dev tools: the CLI, the companion, the debug addon, the
  design site), Metronome (the engine, the bench, Core), Loom (the drawing backend). Session ids change on a restart:
  find the others with ListAgents.
- **Agree before acting in the game:** before a session reloads the game, runs a bench round, a check run, probes or
  any test in game, every other session working on the addons agrees first: say what will run and why, and wait until
  each has answered (a reload or a round in the middle of someone's in-game test spoils both).
- **What the companion may press:** the dev addon's keys (reload, probes, bench) and the player's own keys that open
  windows (`wow_open`). Never movement, abilities or anything bot-like.
- **Long work runs in the background:** builds, lints, tests, probes, watch loops and repro runs, always; keep talking
  to the user meanwhile.
- **No subagents:** each session does its work itself, until the user says otherwise.
- **Idle bug hunts:** with nothing queued, a session runs bug-hunt and simplification rounds over its own areas until a
  round finds nothing; each round ends green and committed.
- **Shared checkouts:** never `--autostash` (rebase or pull) in a checkout other sessions use, and commit only your own
  paths (`git commit -- <paths>`).
- Line endings: LF everywhere via `.gitattributes`. On Windows, set the exec bit with `git add --chmod=+x scripts/package.sh`.
- Commits: Conventional Commits via commitlint (`commitlint.config.mjs`; scope = addon folder name or repo scope), enforced by husky `commit-msg` hook and in CI (PR title + PR commits).
- Versioning: release-please manifest mode (`release-please-config.json`, `.release-please-manifest.json`), one component per addon, tags `<Addon>-vX.Y.Z`. release-please bumps `"version"` in the addon's `addon.jsonc` (the line marked `// x-release-please-version`; nested addons take their parent's) — never edit it by hand.
- Quality: luacheck + busted (pure-logic tests only, Lua 5.1) in CI; manual testing in game with dev mode (Ordaen Core - Debug).
- **Forever's game:** only the nine original classes (no Death Knight, Monk, Demon Hunter or Evoker; their strings in the
  dump are retail leftovers). Forever sells junk at vendors itself, so we offer no sell-junk button; the automatic sell
  when a merchant opens is ours and approved.
- **Forever lacks many retail/classic FrameXML helpers** (e.g. no global `MouseIsOver`). **The source of truth is the in-game API dump in `api/forever/`** (see "Forever API dump" below): never use,
  list or stub a WoW global, namespace function or widget method that isn't in `api/forever/$(cat CURRENT)/`. luacheck
  and the specs enforce this. For things a dump can't see, confirm by a Forever-specific addon using it (`*Camelot*`/`Forever*` files) or a `/dump` in game; unconfirmed APIs get a
  fallback in their `game` domain and a dev-mode log line.
- Dev environment is Windows, no WSL. `ordaen` has Lua 5.1 built in and runs luacheck, busted and forever-lint in it (threads, no shell); lua-language-server is the pinned native release it downloads once. Scripts and specs therefore never shell out (`io.popen`, `os.execute`): list and make folders with `scripts/fs.lua` (LuaFileSystem). Run any repo script with `ordaen lua <script> [args]`.
- Packaging: BigWigs packager (pinned in `scripts/package.sh`). It requires a git repo root as topdir, so the script copies the addon into a temp git repo and tags it. Packager handles CurseForge/Wago uploads; the zip is attached to release-please's GitHub release with `gh release upload` (packager's own GitHub upload would overwrite the release notes). Packager maps interface `16???` to the `forever` flavor (CurseForge game id 88568).

## Layout

```
addons/Ordaen<Name>/            a module: module.lua, components/, locales/, assets/, version.txt (no .toc: the build
                                writes it)
addons/OrdaenCore/              Ordaen: the framework's engine, drawing backend (Backend/) and the no-op debug stand-in;
                                addon.jsonc, built like before
addons/OrdaenBench/             the benchmark module (dev only, never packaged)
_old/                           the previous code, untracked, for reference
dist/<Addon>/                   the built addons the game loads (ordaen build / watch; gitignored)
ordaen.jsonc                    repo-wide build settings: interface version, languages, category names
addon-categories.json           the in-game AddOn List categories (Warcraft Wiki list, every translation): pick from it
scripts/package.sh              package one addon from its release build (CI + Git Bash)
scripts/test.sh                 `ordaen check` (build, luacheck, forever-lint, busted); with args: ordaen test -- args
.ordaen-version                 the ordaen CLI release CI installs (.github/actions/ordaen)
scripts/api-import.sh           import the in-game API dump into api/forever/ (api_import.lua does the work)
scripts/forever_lint.lua        forever-lint: addon code against api/forever/<CURRENT>/api.json (json.lua: its JSON)
api/forever/<version>-<build>/  the real Forever API per client version (generated; history in git)
.github/ISSUE_TEMPLATE/         bug report form the in-game error report links to
.claude/skills/debug-in-game/   how Claude debugs in-game behavior (loaded on demand)
.github/workflows/ci.yml        commitlint, luacheck, busted, packaging dry run
.github/workflows/release.yml   release-please, then package + upload per released addon
```

## Ordaen: one addon, modules

Like EllesmereUI, but the modules load on demand. The approach and the inventory: the design site's
`general/modules` (http://127.0.0.1:47860/preview/design/general/modules.html; source
`../wow-dev-tools/design/general/modules.md`); the settings window's approved look: `settings/` (http://127.0.0.1:47860/preview/design/settings/).

- **Ordaen** (folder `OrdaenCore`) is the one addon the player installs: always loaded and
  small. It holds the shared code, the **global settings** and the one **Ordaen settings window** (`/ordaen`;
  `/ordaen <module>` and each module's gear open it on that module's page). Blizzard's Settings → AddOns keeps one short
  Ordaen page with a button that opens our window. Every command is `/ordaen <module> <command>`: modules declare
  `commands`, Ordaen Core owns the one slash command, and no module registers its own (design:
  development/framework/module, «Commands»).
- Every other addon (`OrdaenBags`, `OrdaenPanel`, ...) is a **module**: `LoadOnDemand: 1`, depends on OrdaenCore,
  its SavedVariables load with it. At startup Ordaen loads the modules that are on (`C_AddOns.LoadAddOn`, each in
  its own protected call) from its own ADDON_LOADED, so before PLAYER_LOGIN: modules that take over Blizzard frames
  (Panel, Reskin, Minimap, Chat) must be in place before Edit Mode and other addons lay things out. Turning a module on loads it at once; turning one off needs a /reload (code can't be
  unloaded; the reload goes through a secure button, rule 7). A module that is off costs nothing.
- No module calls another's code; links go through Ordaen (Shared.lua items, EventRegistry events), so any module
  can be off while the others run. Every module meets this; keep it that way.
- Modules follow the **globals** (theme, fonts, text size, scale, spacing, colours, bar textures, animations, ...):
  a module's look setting defaults to "as in the globals" and may be overridden for that module only.
- **Design for the weakest monitor:** colours, contrast and textures must hold on the least professional screen: white
  text on fills at least 5:1, similar colours clearly apart in hue and lightness, no meaning carried by subtle shading
  alone; check against a washed-out rendering.
- **Design previews are pages of the design site** (`../wow-dev-tools/design`, one folder per topic, `addons:`
  frontmatter), never loose HTML files. The user views the built site on port 47860: build it (`npm run build`) after a
  design change.
- **Themes:** Ordaen, Blizzard and Minimalism are all listed from the start; the last two show as "in development"
  and can't be picked until built.
- **Release:** one CurseForge project and one zip with every module folder (packaging: TODO in the CLI).
- Open: module on/off per account or per character (with profiles); which new globals to add.

## Branding

Every addon is named `Ordaen<Name>` (folder, .toc, globals) with TOC title `Ordaen <Name>`, so CurseForge search
finds them all. One CurseForge project, **Ordaen**, ships every module in one zip (see "Ordaen: one addon, modules"). Every addon sets `"category"` in its addon.jsonc; the
build writes `## Category:` plus the localized `## Category-xxXX:` lines from `ordaen.jsonc`. Pick the category
from `addon-categories.json` (the Warcraft Wiki's list with every translation: the in-game list groups by exact text, so these names share a group with other addons in every language) and copy its
translations into `ordaen.jsonc` "categories". Never invent a category or a translation; CurseForge's own categories
are set per project on the website (e.g. "Miscellaneous", "Bags & Inventory"), not in the TOC. Ordaen (OrdaenCore,
TOC title `Ordaen`) and every module are `User Interface`; the modules' TOCs also say `## Group: OrdaenCore`
(the build writes it), so Blizzard's AddOns list shows them under Ordaen.

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
hand-written .toc/.pkgmeta/Locale*.lua in addons/), B7 settings and theme manifests (`settings.jsonc`, `themes.jsonc`: types, ranges, choices, assets, tokens, locale keys, db named in one place, the `--[[@as <Addon>Addon]]` cast on NewAddon; docs/reference/settings.md), B8 a takeover method called on a frame found by a built name (`_G[...]`) that matches none (or more than 64) of the dump's widget globals: claim it with `A:Claim`, or mark a deliberate non-claim with `-- ordaen: ignore B8 <reason>` on the call's line or the line above; B9 a module's `ui:` call not written as `game.ui:`, B10 state or attributes the build can't follow (`local a = self.attributes`, a computed name, the lifetime written out as `self.state.ephemeral.x`: write `self.state.x`; a method after a read is the value's own, `self.attributes.value:Get()` calls the Setting the attribute holds), B12 a module's `commands` key that isn't a literal word of lower case letters, digits and hyphens, or is `help`/`reset`, B13 a bound expression in a drawing call that reads another render local (it can't be lifted into a binding: design development/framework/signal, «Bindings»). Commands: `ordaen build|watch|link|lint|test|check`
(`--json` for tools; `cli/README.md` in wow-dev-tools).

## Localization

- Languages: English and Russian; the user's client is ruRU. Every user-facing string goes through `ns.L`.
- **Writing player-facing text:** the skills `text-en` and `text-ru` (`.claude/skills/`), for every
  string in a locale file, addon.jsonc, popups and CurseForge pages. In short: no fluff, clear instructions, the
  game's own words; mouse buttons are `Left-click`/`Right-click` in English and `ЛКМ`/`ПКМ` in Russian.
  `_old/tests/repo/locale_text_spec.lua` holds the check for the wording the rules forbid, until the new tests take it over.
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
  categories come localized from ordaen.jsonc. Titles are English; whether they get a `## Title-ruRU` (e.g.
  "Ordaen Миникарта") is open, for the user to decide.
- The Ordaen Dev window (dev mode) is English only.

## Framework

Every module is written with Ordaen's framework. Its design is the design site's `development/framework` pages
(source `../wow-dev-tools/design/development/framework/`; http://localhost:5173/preview/design/development/framework/):
signals, transactions, effects, components, the box model, state, `game`, modules, the app, files and build, testing,
and a worked example. Those pages are the specification; code follows them, and a change of design changes the page
first.

- **The MVP** (`development/framework/mvp`) is the first build, made to measure the framework in game with the
  benchmark module `OrdaenBench`: its scope, who builds what (engine, drawing backend, module build, debug addon) and
  the contracts between them.
- **The previous code** (the old Core with `NewAddon` and `OrdaenCore.UI`, Bags, Chat, Meter, Minimap, Panel, QoL,
  Reskin, Tooltips, their specs and the UI docs site) is in `_old/`, untracked: a reference for behaviour and for what
  Forever needed, never code to build on.
- **A module's folder** is `addons/Ordaen<Name>/` with `module.lua`, `components/`, `locales/`, `assets/` and
  `version.txt` (development/framework/structure); the Core keeps the `addon.jsonc` build below.

## Ordaen Core and debugging

- `addons/OrdaenCore/` holds the code every addon shares. It publishes the global `OrdaenCore` and contains no features. The build gives every addon that uses it `## Dependencies: OrdaenCore`, `## OptionalDeps: OrdaenCore_Debug` and `required-dependencies: [ordaen-core]` in `.pkgmeta` (the CurseForge slug, `"package"` in addon.jsonc, is a guess until the project exists); `"minCore"` in addon.jsonc becomes `## X-Ordaen-MinCore`.
- **The Core API only grows.** Users update the Core and the addons independently. Never change the behavior of a released Core function or remove one; add a new name instead. When an addon starts using a new Core API, raise its `"minCore"`. `OrdaenCore.IsCompatible(addonName)` enforces that in packaged builds; git checkouts are detected by the unreplaced `@project-version@` token in `Core.lua` and skip the check.
- **What a module calls** is the framework's (`Define`, `game`, `self`), never the Core's internals; the Core holds the engine, the drawing backend and the debug stand-in (`OrdaenCore.NewDebug`).
- Before handing code over for an in-game test, have `ordaen watch` running so `dist/` is current (no check run: rule 4 of "Preventing bugs"; the game's errors decide). `/reload` is enough on Forever, also for new files, new textures, TOC changes and new (linked) addon folders: never ask for a client restart.
- **Debugging is opt-in development mode.** Players get a no-op stand-in from the Core: nothing is recorded and errors take WoW's normal path (BugSack, Blizzard). The real kit is the dev-only addon `OrdaenCore_Debug` ("Ordaen Core - Debug"), which lives in the **private repo `../wow-dev-tools`** next to the companion app and is never shipped (dev tooling, including the pixel channel, stays private). Its own `scripts/link.ps1` junctions it into the AddOns folder; its specs load the built Core (`dist/OrdaenCore/`, TOC order) and `api/forever/` from this checkout. Keep the stand-in's API in step with it: the kit is an object (methods on a shared metatable, called with `:`): `Init, IsEnabled, Log, Logf, Warn, Warnf, Verbose, Verbosef, Wrap, Call, Dump, Snapshot, HandleSlash, HelpLines, Trace, TraceFrame, TraceEnabled, TimeStart, TimeEnd, Time, Conflict`; levels error/warn/info (Log)/debug (Verbose, Trace). Installing and enabling it turns on dev mode: our own error catcher (global error handler chained to the previous one, or BugGrabber's callback when BugGrabber keeps the handler; plus taint events), per-addon logs and dumps, the Ordaen Dev window, and a live stream to the companion app (wow-dev-tools), which serves it to Claude as the MCP server `ordaen`: `wow_status`, `wow_errors`, `wow_log`, `wow_watch`, `wow_screenshot`, `wow_dump` (after the user clicks "Send state"), `wow_perf` (Performance tab: memory, CPU, `Debug:Time` labels), `wow_check`. The user describes what they saw in chat; Claude reads the rest live (no notes, no reload just for Claude). All dev data goes to one SavedVariables table, `OrdaenCoreDebugDB`, never into players' addon settings. Never make players' builds record anything. Plan for the window: Errors and Performance (done), then Log, Inspect (frame picker, outlines). Prefer UI in the window over new slash commands.
- **The companion runs whenever the game does.** The dev addon captures, measures and sends over the strip; the companion
  stores and shows. What the strip carries (errors, logs, records, bench and test results) has no SavedVariables
  fallback and never waits for a `/reload` to reach Claude.
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
  whenever Forever patches; never edit these files by hand. A new dump of a build already imported is merged into it
  (globals, namespaces, widgets, objects: what any dump saw stays; the dump drops fields our addons wrote).
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
  **FL5** unknown `CreateFrame` types; **FL6** debug kit methods called with `.`; **FL7** a `Debug:Time(...)` whose results are used (release builds strip it); **FL8** any `ReloadUI`/`C_UI.Reload` in addon code (Forever blocks it even in a click; a secure `/reload` macro button reloads); **FL9** a unit event (documented with the unit as its first argument) registered for every unit with a literal name (`:RegisterEvent("UNIT_AURA")`, `A:On("UNIT_...")`): use `RegisterUnitEvent` / `A:OnUnit` (a name from a variable gets a dev-mode warning from `A:On` instead). It reports only what it's sure of. Silence a line with
  `-- forever-lint: ignore FL2`, and only with a reason in the comment.
- Dump format the importer understands (written by `ApiDump.lua` in `../wow-dev-tools`): docs args `name:type`, `?`
  = nilable, `=` = has a default (`name:type?=` both); `objects[<dotted path>]` at any depth, `#<n>` for unnamed
  children, `<objectType>` (widget type), `<ref>` (same table as another path), `<truncated>` (node cap hit). Only
  top-level objects with identifier-safe keys become luacheck fields.
  Owner of the linter and `api/` tooling: the Ordaen Core session.
- **`api.json`** per version is the structured form of the text files (globals, namespaces, widgets, objects, and
  documented `functions`/`events` with typed `args`/`returns`/`payload`), for the linter and other tools (e.g. the
  companion app). `bash scripts/api-import.sh` writes it; `ordaen lua scripts/api_import.lua --rebuild .`
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
