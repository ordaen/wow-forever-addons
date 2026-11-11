# wow-forever-addons

Monorepo of World of Warcraft addons for the **WoW Forever** flavor (interface `16001`), written in LunaType.
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
- **Dependencies:** no library unless Blizzard's API can't do it. Ordaen Core stays small; dev-only code lives in
  `OrdaenCore_Debug`, which players never load.
- **Measure, don't guess:** before merging a feature into `develop`, check its memory and CPU in the Ordaen Dev window
  (Performance tab; Claude reads it with `wow_perf`). What the debug kit measures is left out of release builds, so
  code never uses its results. Mention the numbers when handing work over.
- **Measure what players run:** a number counts only from the bench profile (`## X-Ordaen-Build: bench`, release
  stripping). A measurement or a performance review starts by confirming the build, the loaded addons and the settings;
  a wrong build blocks the review, it isn't a footnote.
- **What's already measured:** [performance.md](performance.md) holds the costs measured in game (WoW calls, pixels,
  CPU against GPU, bench findings). Read it before choosing an approach; add to it what a probe or bench round settles.

## Code: LunaType

The addons are written in LunaType (`.luna`), which compiles to the Lua the game loads. The language's specification
is the design site's `development/language` pages (source `../wow-dev-tools/design/development/language/`); the
compiler, its runtime and the game's host are the `lunatype` repository (`../lunatype`).

- **The compiler is the first check.** Types, who may change what (`mut`, views), what may be `nil`, and what a
  declaration promises are held when the addon is built. A finding is an error: nothing is written until there are
  none.
- **A module holds no state.** Anything computed or changing is a class's field; what follows something else is a
  cell (`$reactive`, `$computed`), read where it is drawn.
- **The game is imported.** An addon reads the client through `"$game"` (the client by its parts, cells it can't
  write) and Ordaen through `Ordaen`; only the game's side (in `lunatype`, `src/game`) reads the client's own API
  (`"$client"`, `"$events"`).
- **Plain Lua beside a declaration** (`name.d.luna` with `name.lua`) is for what isn't LunaType's to say: another
  addon's own API (`OrdaenDev/dev`), generated data (`OrdaenTooltips/talents`).
- **One way to write a file:** `lunatype fmt addons`.

## Preventing bugs (applies to every session)

Every bug class we hit gets a **static check** first; tests and in-game checks come after. A fix without a check that
would have caught it is half a fix: say which check now catches it, or add one.

1. **The compiler's findings.** A wrong type, a write through a view, a value that may be `nil`, a declared module a
   class gives with the wrong members: each is a finding of `lunatype check`, and the build stops on it. A bug
   class the compiler can catch becomes a finding there before it becomes a test.
2. **Lint-first refactors.** Before reshaping an API (renames, `.` to `:`, removed functions), add the check that fails
   on the old form, then convert until it reports nothing. The check decides when the conversion is done, never a
   regex or a reading of the code.
3. **One stand-in for the client.** Tests run the compiled addons on the stand-in client and stand-in game of
   `lunatype` (`src/standin`): frames, textures, the cursor, events, an addon loaded on demand from its TOC. No
   per-test stub looser than the game (a lenient stub makes a missing frame look real).
4. **The suite is `lunatype`'s.** From `../lunatype`: `zig build test -j16` checks, formats, builds and runs
   everything (the language, the host, the game's side, every addon here against its snapshots). Run it in the
   background before a change is handed over. Check `git status`/`git diff --stat` before each commit.
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
   Tests can't see this (the stand-in has no "hardware event" or secure state), so a protected action gets an
   in-game check.
8. **Handovers happen on an event, never on a timer.** When one addon takes something over from another (a frame,
   a position), the side that comes second completes it: the owner announces its thing when it creates it
   (`EventRegistry:TriggerEvent("OrdaenDevButton.Created", b)`) and the taker also checks at its own start. A
   fixed delay has no ordering guarantee, and whatever it moves sits in the wrong place until it fires. Specs cover
   both orders: created before and after login.
9. **One source of truth** (same rule in wow-dev-tools' CLAUDE.md): every fact
   lives in exactly one place, and everything else reads it from there (requires it, or gets it generated by the
   build), never a copy. The sources here:
   - an addon's sources for what it is: its files, its dependencies and its load order come from its imports;
   - `locales/*.json` for text, the client's own texts for the game's own words;
   - `Ordaen/theme.luna` for the theme's measures and art;
   - the client's API dump for what the game has (`lunatype generate api`, in `../lunatype`).

   Before adding a constant, a list or a map, look for where the fact already lives and read it from there.
   - **A copy is a bug:** finding one, remove it and point its users at the source. Where a copy can't go yet, add a
     check that fails on drift, as for any bug class.
   - **Generated files are never edited by hand** (the Lua and the TOCs of a build, `terms.luna`, the client's
     declarations in `lunatype`): change the source and build again.
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
- The game loads the **built** addons: `scripts/link.ps1` makes a directory junction in the AddOns folder for each
  addon of a build (`../lunatype/zig-out/addons`) that the app reaches: the addon that holds the root, what each
  depends on, and what each makes on demand. `-Unlink` removes them. Only junctions are made and removed, never
  files.

## Repo and workflow

- Things are done properly from the start: full tooling, never "add later".
- Repo: public GitHub repo `ordaen/wow-forever-addons` (org; user is admin). The org forbids GITHUB_TOKEN from opening PRs, so release-please uses an org GitHub App token (`vars.RELEASE_APP_CLIENT_ID`, `secrets.RELEASE_APP_PRIVATE_KEY`). Default branch `main`, squash-merge only, PR title = commit message.
- Commit identity (global git config): `David Iunevich <1751835+f3oall@users.noreply.github.com>`. GitHub user `f3oall`.
- Signed commits are required on every branch (ordaen org ruleset). Commits are SSH-signed with `~/.ssh/id_ed25519` (global `commit.gpgsign`/`tag.gpgsign`). Commits GitHub creates (squash merges, release-please via the App, Dependabot) are signed by GitHub.
- `main` ruleset: PR-only, squash-only, linear history, required checks `Conventional commits`, `Lint & test (Lua)`, `Package (dry run)`; repo admins may bypass only when merging a PR. The two last checks are the Lua addons' (their workflows are `_old/lua/workflows/`): CI for the LunaType addons isn't built.
- **Branches (local-only until the user says otherwise: no push, PR or merge on GitHub):**
  - `develop` is the integration branch and the **game checkout**: the main checkout `C:\Users\f3oal\code\ordaen\wow-forever-addons` stays on `develop`, and the game loads it through the junctions. Never switch that checkout to another branch.
  - Do feature work on a branch off `develop` in its own worktree: `git worktree add ../wow-forever-addons-<topic> -b feat/<topic> develop`, then `npm install` there (installs the commit hook).
  - Merge once: rebase the branch onto `develop`, fast-forward `develop`, then `scripts/test.sh` (no check before the merge: rule 4). If develop is red after your merge, fixing it is your next task. Then `git worktree remove ../wow-forever-addons-<topic>` and `git branch -d feat/<topic>`. That keeps the signed conventional commits. `lunatype build addons ../lunatype/zig-out/addons --watch` (running in the main checkout) builds again and the user does `/reload`: on Forever that also picks up new files, new textures (`.tga` in media/: no client restart), TOC changes and even new addon folders. A new addon is linked first (`scripts/link.ps1`).
  - Revisit at release: `main` is squash-only, so one develop→main PR gives each addon a single changelog line, and a commit touching several addons shows in each addon's changelog. Prefer one PR per addon or feature with a player-facing title. The merged rename PR #4 and release PR #5 need a `BEGIN_COMMIT_OVERRIDE` block so the rename line stays out of the first changelog.
- **Help when busy:** when an owner is busy, any session may do the work in its area (the renderer, Core, an addon),
  and a session that needs something from a busy owner does it itself. Tell the owner first what you'll change, work on
  your own branch, merge it (rebase, fast-forward), and report back after.
- **Agree before acting in the game:** before a session reloads the game, runs a bench round, a check run, probes or
  any test in game, every other session working on the addons agrees first: say what will run and why, and wait until
  each has answered (a reload or a round in the middle of someone's in-game test spoils both).
- **Slack:** the sessions and the user share one thread. A message that names no session is answered by one session
  only, the dev-tools one; the others read it and do their part without posting. A message that starts with a
  session's name is that session's to answer. Reaching the user unasked (a blocker, a question, finished work) goes to
  the same thread.
- **What the companion may press:** the dev addon's keys (reload, probes, bench) and the player's own keys that open
  windows (`wow_open`). Never movement, abilities or anything bot-like.
- **Long work runs in the background:** builds, lints, tests, probes, watch loops and repro runs, always; keep talking
  to the user meanwhile.
- **No subagents:** each session does its work itself, until the user says otherwise.
- **Idle bug hunts:** with nothing queued, a session runs bug-hunt and simplification rounds over its own areas until a
  round finds nothing; each round ends green and committed.
- **Shared checkouts:** never `--autostash` (rebase or pull) in a checkout other sessions use, and commit only your own
  paths (`git commit -- <paths>`).
- Line endings: LF everywhere via `.gitattributes`. On Windows, set the exec bit with `git add --chmod=+x scripts/test.sh`.
- Commits: Conventional Commits via commitlint (`commitlint.config.mjs`; scope = addon folder name or repo scope), enforced by husky `commit-msg` hook and in CI (PR title + PR commits).
- Versioning: release-please manifest mode (`release-please-config.json`, `.release-please-manifest.json`), one component per addon, tags `<Addon>-vX.Y.Z`. Its components are the Lua addons' folders: a LunaType addon has no version of its own yet.
- Quality: `scripts/test.sh` (the lunatype suite); manual testing in game with dev mode (Ordaen Core - Debug).
- **Forever's game:** only the nine original classes (no Death Knight, Monk, Demon Hunter or Evoker; their strings in the
  dump are retail leftovers). Forever sells junk at vendors itself, so we offer no sell-junk button; the automatic sell
  when a merchant opens is ours and approved.
- **What the client has** is what its API dump says (see "Forever API dump"): the game's side in `lunatype` is typed against it, so a name the dump doesn't have is a finding. For things a dump can't see, confirm by a Forever-specific addon using it (`*Camelot*`/`Forever*` files) or a `/dump` in game.
- Dev environment is Windows. The suite runs the compiled Lua under Lua 5.1 in WSL (`zig build -Dlua=<command>` names another); the compiler has Lua 5.1 built in for the tests written in LunaType.
- Packaging isn't built (the Lua addons' is `_old/lua/scripts/package.sh`, BigWigs packager; interface `16???` is the `forever` flavor, CurseForge game id 88568).

## Layout

```
addons/Ordaen/                  Ordaen Core: what every addon builds on (Component, Module, Settings), its root
                                (ordaen.luna), the theme (theme.luna) and its art (media/)
addons/OrdaenApp/               the app: its root tells Ordaen Core of every module and starts it
addons/OrdaenLibrary/           the controls every addon draws by name
addons/Ordaen<Name>/            a module: its index.luna gives its root, a class that implements Ordaen::Module;
                                locales/, assets/
addons/OrdaenDev/               the Ordaen Dev window: private (`../wow-dev-tools/modules/OrdaenDev`), a junction
                                here so the build has it; ignored by git
addons/Showcase/                a page of the library's controls and a windowed module, for the tests
_old/lua/                       the Lua addons these replace, with their tests
_old/addons, _old/docs, ...     the code before those
addon-categories.json           the in-game AddOn List categories (Warcraft Wiki list, every translation)
scripts/link.ps1                link a build into the game's AddOns folder
scripts/test.sh                 the lunatype suite over these addons
api/forever/<version>-<build>/  the Forever API per client version, as the Lua tooling read it
.github/ISSUE_TEMPLATE/         bug report form the in-game error report links to
.claude/skills/debug-in-game/   how Claude debugs in-game behavior (loaded on demand)
```

An addon has no TOC and no file list in its sources: the build writes the TOC, with the files in the order their
imports give.

## Ordaen: one addon, modules

Like EllesmereUI, but the modules load on demand. The approach and the inventory: the design site's
`general/modules` (http://127.0.0.1:47860/preview/design/general/modules.html; source
`../wow-dev-tools/design/general/modules.md`); the settings window's approved look: `settings/` (http://127.0.0.1:47860/preview/design/settings/).

- **Ordaen** (folder `Ordaen`) is the core: always loaded and small. Its root (`OrdaenCore`) holds the modules, the
  **global settings**, the theme, and where the player put each part; it is asked for the one **Ordaen settings
  window** (`/ordaen`, `/ordaen <module's folder>`, the Ordaen button by the minimap), which the settings module
  draws.
- **OrdaenApp** is the app: its root tells Ordaen of every module (`Ordaen::register(folder, title, icon, make)`,
  `make` being `() => new? Module()`) and starts it. A module's class is imported by its type only, so the app
  loads without it.
- Every other addon (`OrdaenMinimap`, `OrdaenPanel`, ...) is a **module**: `LoadOnDemand: 1` in its TOC, loaded when
  it is first turned on (`new?` loads its addon), made and drawn at once, ended at once when it is turned off. One
  the player doesn't have stays off. Which modules are off, each module's settings and the parts' places are kept
  between sessions.
- No module calls another's code: a module imports Ordaen and the library, never another module, so any module
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
- **Release:** one CurseForge project and one zip with every module folder (packaging isn't built).
- Open: module on/off per account or per character (with profiles); which new globals to add.

## Branding

Every addon is named `Ordaen<Name>` (folder, .toc, globals) with TOC title `Ordaen <Name>`, so CurseForge search
finds them all. One CurseForge project, **Ordaen**, ships every module in one zip (see "Ordaen: one addon, modules"). The category in the client's AddOn List
comes from `addon-categories.json` (the Warcraft Wiki's list with every translation: the in-game list groups by exact text, so these names share a group with other addons in every language). Never invent a category or a translation; CurseForge's own categories
are set per project on the website (e.g. "Miscellaneous", "Bags & Inventory"), not in the TOC. Ordaen (TOC title
`Ordaen`) and every module are `User Interface`, the modules grouped under Ordaen (`## Group:`). The build writes
neither line yet: a LunaType addon has no manifest.

## Build (`lunatype`, in `../lunatype`)

The sources in `addons/` are built into a folder the game, the tests and a release use:

- `lunatype check addons`: every finding, nothing written.
- `lunatype build addons <out> [--release] [--watch]`: the Lua, one file a source file; per addon its TOC (the
  client's interface number, `Dependencies` from its imports, `LoadOnDemand` where others name it only by type, its
  files in load order) and its `media` folder as it is; `LunaType/`, the runtime and the game's host. `--watch`
  builds again when a file changes. `--release` leaves the debug kit's calls out.
- `lunatype fmt addons [--check]`: every file the one way it is written.
- `lunatype test addons [name]`: the tests written beside the code (`*.test.luna`).

Not built: packaging and release (the workflows in `.github/` are the Lua addons'), an addon's manifest (its
title, icon, notes and category in the TOC; a module's title and icon are written where the app registers it).

## Localization

- Languages: English and Russian; the user's client is ruRU. Every user-facing string is a key of the addon's
  `locales`, read as `Locale::KEY` (`import Locale from "@/locales"`).
- **Writing player-facing text:** the skills `text-en` and `text-ru` (`.claude/skills/`), for every
  string in a locale file, a TOC, popups and CurseForge pages. In short: no fluff, clear instructions, the
  game's own words; mouse buttons are `Left-click`/`Right-click` in English and `ЛКМ`/`ПКМ` in Russian.
  `_old/tests/repo/locale_text_spec.lua` holds the check for the wording the rules forbid; nothing runs it.
- Per addon: `locales/<code>.json` (`{ "KEY": "text" }`, keys UPPER_SNAKE_CASE), one file per language. The build
  writes them as one Lua file, of which the client's language (English where it has none) is the module. A key
  that isn't in the English file is a finding where it is read. Add a key to every `locales/*.json` together.
- Use Blizzard's own translated globals for common words where they fit (`CLOSE`, `OKAY`, `CANCEL`, `RESET`, `NONE`,
  `SETTINGS`), after confirming they exist on Forever.
- The Ordaen Dev window (dev mode) is English only.

## Framework

Every module is written with Ordaen's framework: a component is a class with `render()`, which gives LTML; what it
shows follows cells; a module is a component with a title and its settings pages; a part the player places is a
`Placed`. The language pages (`development/language`) are the specification of what code can say; the framework
pages (`development/framework`) describe the same ideas as the Lua framework had them and wait to be rewritten for
LunaType.

- **A module's folder** is `addons/Ordaen<Name>/`: `index.luna` gives its root, `locales/`, `assets/`.
- **The previous code** is `_old/`: the Lua addons with their framework in `_old/lua/`, the code before them beside
  it.

## Ordaen Core and debugging

- **What a module calls** is the language's, the framework's (`Ordaen`, the library) and `"$game"`, never the
  runtime's internals.
- **Debugging is opt-in development mode.** `Debug::log(...)` (`import Debug from "$debug"`) is in dev builds only.
  With the dev addon loaded (`OrdaenCore_Debug`, in `../wow-dev-tools`; it needs no other addon) the lines go to its
  log and its inspector describes the boxes the host draws; without it they go nowhere. Players don't have it.
- **The companion runs whenever the game does.** The dev addon captures, measures and sends over the strip; the
  companion stores, shows and exposes it to Claude (MCP: `wow_errors`, `wow_log`, `wow_screenshot`, `wow_inspect`,
  `wow_reload`).

## Forever API dump

- **Make a dump** (user, dev mode on): the dev addon's «Dump the game API» (Ordaen Dev window, Tools), then `/reload`
  so the client writes it to disk (`WTF/.../SavedVariables/OrdaenCore_Debug.lua`).
- **Use it:** `lunatype generate api <dump> src/lib` in `../lunatype` writes the client's own API as declarations
  (`"$client"`, `"$events"`) and its interface number. What the client has and its documentation doesn't say is
  written by hand in `../lunatype/src/generate/api.overlay`.
- `api/forever/<version>-<build>/` here is the dump as the Lua tooling imported it (text files and `api.json`), kept
  for reading; nothing builds from it.
- **Forever lacks many retail/classic FrameXML helpers.** The dump is the source of truth for what exists; a name
  from memory or from retail's documentation isn't.
