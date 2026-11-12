# wow-forever-addons

World of Warcraft addons for the **WoW Forever** flavor (interface `16001`), written in
LunaType: a typed language for addons that compiles to the Lua the game loads.

| Addon | Description |
|---|---|
| [Ordaen](addons/Ordaen) | Ordaen Core: what every module builds on, the settings, the theme and its art. |
| [OrdaenApp](addons/OrdaenApp) | The app: tells Ordaen Core of every module and starts it. |
| [OrdaenLibrary](addons/OrdaenLibrary) | The controls every module draws. |
| [OrdaenSettings](addons/OrdaenSettings) | The Ordaen settings window (`/ordaen`). |
| [OrdaenMinimap](addons/OrdaenMinimap) | Our own minimap; collects minimap buttons and addon compartment entries into one drawer. |
| [OrdaenPanel](addons/OrdaenPanel) | The bottom panel. |
| [OrdaenProfessions](addons/OrdaenProfessions) | The professions window. |
| [OrdaenTooltips](addons/OrdaenTooltips) | Tooltips. |

A module is loaded when the player first turns it on; one that is off costs nothing.

## Works with other addons

- **Altoholic** is the addon for what your other characters own. Ordaen addons support it: its item counts stay in
  tooltips as Altoholic writes them (Ordaen Tooltips shows them as their own block, after the game's lines), and no
  Ordaen addon tracks other characters' items. Ordaen Bags shows only the current character's bags.

## Development

Development happens on Windows: the game runs there and the repo lives on the Windows drive.

### One-time setup

1. **Node** (for the commit hook): `npm install` in this checkout.
2. **The compiler:** clone `lunatype` next to this repo (`../lunatype`) and install Zig 0.17. `zig build -j16` there
   builds the compiler and writes a build of these addons to `../lunatype/zig-out/addons`.
3. **Lua 5.1 for the run tests** is the compiler's own; another is named with
   `zig build -Dlua=<command>`.
4. **Build into the game:** `npm run dev` in the main checkout
   (`lunatype build addons ../lunatype/zig-out/addons --watch --link <the Forever AddOns folder>`). It builds
   the addons, builds again whenever a file changes, and keeps a directory junction (Windows' directory link; no
   admin needed) in the AddOns folder for `LunaType`, `Ordaen`, `OrdaenApp` and each module. Only junctions are
   made and removed, never files. `lunatype unlink ../lunatype/zig-out/addons <AddOns>` takes them away.

### Everyday loop

1. Work on a branch in its own worktree:
   `git worktree add ../wow-forever-addons-<topic> -b feat/<topic> develop`.
2. Edit the `.luna` files. `lunatype check addons` says every finding; `lunatype fmt addons` writes every file the
   one way it is written.
3. Run everything that checks the addons: the `lunatype` suite, `zig build -j16 test -Daddons=<this checkout>/addons`
   in `../lunatype` (the compiled addons run on a stand-in client against their snapshots; `-Dupdate` writes the
   snapshots anew). Without `-Daddons` it builds the main checkout's addons.
4. Bring it into the game: rebase onto `develop` and fast-forward it. The main checkout stays on `develop`.
5. Keep `npm run dev` running in the main checkout: it builds again whenever a file changes. In game:
   `/reload`.

### How an addon is built

`addons/<Name>/` is the source; `lunatype build` writes `<out>/<Name>/`, which the game and the tests use:

- one Lua file a source file, and the TOC: the interface number of the client, the dependencies and the load order
  the imports give, `LoadOnDemand` for an addon others name only by type;
- `locales/<code>.json` as one Lua file, of which the client's language is what the code reads;
- the `media` folder as it is;
- `LunaType/`, the language's runtime and the game's host, which every addon depends on.

An addon's root is the one class that implements `App`; a module's is the class its `index.luna` gives, which
`OrdaenApp` registers.

### The real Forever API

The client's API is read from a dump the dev addon makes in the game («Dump the game API» in the Ordaen Dev window,
then `/reload`). `lunatype generate api <dump> src/lib` in `../lunatype` writes it as declarations, which the
game's side is typed against: a name the client doesn't have is a finding.

### Debugging in game

Players never have errors collected: Lua errors go to BugSack (if installed) or Blizzard's default handler.

Maintainers have a **development mode**: the dev-only addon `OrdaenCore_Debug` ("Ordaen Core - Debug": its own
error catcher, logs, state dumps, the game API dump and the live channel to the companion app). It lives in the
private `wow-dev-tools` repo, next to the companion app, and is never shipped. Its data goes to one file, which WoW
writes on `/reload` or logout:
`C:\Program Files (x86)\World of Warcraft\_forever_\WTF\Account\<account>\SavedVariables\OrdaenCore_Debug.lua`.

Addons cannot reach the network, so there is no telemetry. To report a bug, a player installs
[BugSack](https://www.curseforge.com/wow/addons/bugsack), reproduces the problem, and pastes the error into the
[bug report form](.github/ISSUE_TEMPLATE/bug_report.yml).

### Commits

[Conventional Commits](https://www.conventionalcommits.org/), checked by a git hook and in CI:

```
feat(OrdaenMinimap): add grow direction option
fix(OrdaenMinimap): keep drawer on screen after scale change
chore(repo): the suite's script
```

- Scope is an addon folder name, or one of `repo`, `ci`, `deps`, `scripts`, `tests`, `docs`.
- `feat` = minor bump, `fix`/`perf` = patch, `feat!:` or a `BREAKING CHANGE:` footer = major.
  While an addon is `0.x`, breaking changes bump minor instead of major.
- PRs are squash-merged, so the **PR title** is the commit that counts.

### Releases

CI (`.github/workflows/ci.yml`) runs the `lunatype` suite over the addons on every push and pull request. Packaging
and the release aren't built for the LunaType addons: the Lua addons' are `_old/lua/workflows/release.yml` and
`_old/lua/scripts/package.sh`, and `release-please-config.json` names their folders.

### Adding a module

1. Create `addons/Ordaen<Name>/` with `index.luna`, which gives the module's root (a class that implements
   `Ordaen::Module`), and `locales/enUS.json` + `locales/ruRU.json`.
2. Register it in `addons/OrdaenApp/index.luna`: `import type` its class and
   `Ordaen::register(folder, title, icon, () => new? Class())`.
3. Add the addon to the dropdown in `.github/ISSUE_TEMPLATE/bug_report.yml`.
4. With `npm run dev` running: `/reload`.

### The previous code

`_old/lua/` holds the Lua addons these replace, with their tests, scripts and workflows.

## Repository secrets

| Secret | Needed for |
|---|---|
| `RELEASE_APP_PRIVATE_KEY` (+ variable `RELEASE_APP_CLIENT_ID`) | Org GitHub App that release-please acts as (Contents + Pull requests: read/write). |
| `CF_API_KEY` | CurseForge uploads. |
| `WAGO_API_TOKEN` | Wago uploads. |
