# wow-forever-addons

World of Warcraft addons for the **WoW Forever** flavor (interface `16001`).

| Addon | Description |
|---|---|
| [Ordaen Core](addons/OrdaenCore) | Shared code every Ordaen addon depends on (debug log, error reports). Does nothing on its own. |
| [Ordaen Minimap](addons/OrdaenMinimap) | Our own SexyMap-style minimap with little configuration; collects minimap buttons and addon compartment entries into one drawer. |

## Development

Development happens on Windows: the game runs there and the repo lives on the Windows drive. Lua tooling (luacheck,
busted) runs in WSL Ubuntu, called from Git Bash by `scripts/test.sh`.

### One-time setup

1. **Windows tools:** [Git for Windows](https://gitforwindows.org/) (includes Git Bash),
   [Node.js](https://nodejs.org/) LTS (commit linting only) and [PowerShell 7](https://aka.ms/powershell) (`pwsh`).
2. **WSL Ubuntu**, from an *admin* terminal (Win+X → Terminal (Admin)):
   ```powershell
   wsl --install -d Ubuntu      # reboot if asked, then open "Ubuntu" from the Start menu once to create a user
   ```
3. **Lua 5.1 + test tools inside Ubuntu** (WoW runs Lua 5.1, so do not use a newer Lua):
   ```bash
   sudo apt-get update
   sudo apt-get install -y lua5.1 liblua5.1-0-dev luarocks build-essential
   sudo luarocks --lua-version=5.1 install busted
   sudo luarocks --lua-version=5.1 install luacheck
   # lua-language-server: type checks against the real Forever API (the version CI uses, see ci.yml)
   v=3.19.2; d=~/.local/share/lua-language-server-$v; mkdir -p $d ~/.local/bin
   curl -fsSL https://github.com/LuaLS/lua-language-server/releases/download/$v/lua-language-server-$v-linux-x64.tar.gz | tar -xz -C $d
   printf '#!/bin/sh\nexec %s/bin/lua-language-server "$@"\n' $d > ~/.local/bin/lua-language-server
   chmod +x ~/.local/bin/lua-language-server
   ```
   Editors with the Lua extension (LuaLS) pick up `.luarc.json`: completion and type checks for the Forever API.
4. **The `ordaen` build tool** (maintainers; it lives in the private `wow-dev-tools` repo): clone `wow-dev-tools` next
   to this repo, install [Rust](https://rustup.rs), then in `wow-dev-tools`: `cargo install --path cli`.
5. **Repo**, in the repo folder:
   ```powershell
   npm install                  # commitlint + the git commit-msg hook (husky)
   ordaen build                 # addons/ -> dist/ (the built addons: generated TOCs and locales)
   ordaen link                  # junction every built addon into the Forever AddOns folder
   ```
   A junction is Windows' directory link (like a symlink; no admin needed). `ordaen link --unlink` removes the
   junctions and leaves the files alone. They point at `dist/` of this checkout, so keep it on `develop`
   (`git switch develop`): what's on `develop` is what the game runs.
6. **Dev mode** (maintainers): run `pwsh ./scripts/link.ps1` in `wow-dev-tools`, then enable
   **Ordaen Core - Debug** in the AddOns list (see "Debugging in game").

### Everyday loop

`develop` collects finished work and is what the game runs. Each feature gets its own branch in its own
[git worktree](https://git-scm.com/docs/git-worktree) (a second working folder of the same repo), so the game
checkout never changes branch.

1. Start a feature (Git Bash, in the repo folder):
   ```bash
   git worktree add ../wow-forever-addons-<topic> -b feat/<topic> develop
   cd ../wow-forever-addons-<topic> && npm install    # installs the commit hook in the new folder
   ```
2. Edit and commit there (signed, [Conventional Commits](#commits)).
3. Run the same checks as CI: `scripts/test.sh` (= `ordaen check`: build, luacheck, forever-lint, busted). Extra
   arguments go to busted (`scripts/test.sh --filter Snapshot`).
4. Bring it into the game: `git rebase develop` in the worktree, then from the main checkout
   `git merge --ff-only feat/<topic>`.
5. Keep `ordaen watch` running in the main checkout: it rebuilds `dist/` whenever files change. In game: `/reload`
   (on Forever that also picks up new files and TOC changes).
6. When the feature is done: `git worktree remove ../wow-forever-addons-<topic>` and `git branch -d feat/<topic>`.

### How an addon is built

`addons/<Name>/` is the source; `ordaen build` writes `dist/<Name>/`, which the game, the specs and the release zips
use. Nothing in `dist/` is edited by hand or committed.

- `addon.jsonc` holds only what the code can't say: title, notes, category, icon, version, the oldest Core it works
  with (`minCore`), the CurseForge slug. `ordaen.jsonc` holds what all addons share (interface version, languages,
  category names).
- The TOC's file list comes from the code: a file that uses `ns.Something` while loading is placed after the file
  that defines it (`ordaen build --explain` shows why). Dependencies come from the globals an addon uses,
  SavedVariables from its `OrdaenCore.NewAddon` call.
- Texts live in `locales/<language>.json`; the build checks them (every key translated, same `%s` placeholders) and
  generates the Lua the game loads.
- Release builds strip the dev-only debug calls, keeping line numbers.

Code shared by several addons lives in **Ordaen Core** (`addons/OrdaenCore/`); every addon starts through its
framework, `OrdaenCore.NewAddon` (settings with defaults, settings page, slash commands, events). Users can update
the Core and the addons separately, so the Core's API only grows: never change or remove anything that has been
released; add a new name instead. An addon that needs a newer Core sets `"minCore"` in its `addon.jsonc` (git
checkouts skip that check).

### The real Forever API

`api/forever/<version>-<build>/` lists what the game's Lua API actually has, per client version, dumped in game:
in dev mode (the private dev addon), open the Ordaen Dev window and click **Dump game API** (it reloads), then run `bash scripts/api-import.sh`
and commit the result. `api/forever/CHANGES.md` shows what each Forever patch added or removed. luacheck and the
specs use the newest dump, so code that calls something Forever doesn't have fails before it reaches the game.
Dump again after every Forever patch, and click **Clear API dump** once it's imported.

`ordaen check` (and so `scripts/test.sh`) also runs **forever-lint** (`scripts/forever_lint.lua`), which checks event names, methods per
widget type, argument counts and literal argument types against the dump (`api.json`, the structured form of each
version). Silence a line with `-- forever-lint: ignore FL2` and say why.

### Debugging in game

Players never have errors collected: Ordaen Core only carries a do-nothing debug stand-in, and Lua errors go to
BugSack (if installed) or Blizzard's default handler.

Maintainers have a **development mode**: the dev-only addon `OrdaenCore_Debug` ("Ordaen Core - Debug", with the
Ordaen Dev window, its own error catcher, logs, state dumps, the game API dump and the live channel to the
companion app). It lives in the private `wow-dev-tools` repo, next to the companion app, and is never shipped.
Every Ordaen addon lists it in `## OptionalDeps` (the build adds it), so when it is installed it loads first and replaces the
stand-in. Its data goes to one file, which WoW writes on `/reload` or logout:
`C:\Program Files (x86)\World of Warcraft\_forever_\WTF\Account\<account>\SavedVariables\OrdaenCore_Debug.lua`.

Addons cannot reach the network, so there is no telemetry. To report a bug, a player installs
[BugSack](https://www.curseforge.com/wow/addons/bugsack), reproduces the problem, and pastes the error into the
[bug report form](.github/ISSUE_TEMPLATE/bug_report.yml).

### Commits

[Conventional Commits](https://www.conventionalcommits.org/), checked by a git hook and in CI:

```
feat(OrdaenMinimap): add grow direction option
fix(OrdaenMinimap): keep drawer on screen after scale change
chore(ci): cache luarocks
```

- Scope is an addon folder name, or one of `repo`, `ci`, `deps`, `scripts`, `tests`, `docs`.
- `feat` = minor bump, `fix`/`perf` = patch, `feat!:` or a `BREAKING CHANGE:` footer = major.
  While an addon is `0.x`, breaking changes bump minor instead of major.
- PRs are squash-merged, so the **PR title** is the commit that counts.
- Which addon a commit releases is decided by the files it changes, not by the scope.

### Releases

Handled by [release-please](https://github.com/googleapis/release-please):

1. Merging to `main` opens/updates a release PR with version bumps and `CHANGELOG.md` per addon.
2. Merging the release PR tags `<Addon>-vX.Y.Z` and creates a GitHub release.
3. The release workflow packages the addon with the
   [BigWigs packager](https://github.com/BigWigsMods/packager) (`scripts/package.sh`),
   uploads to CurseForge/Wago when configured, and attaches the zip to the GitHub release.

Never edit `"version"` in an `addon.jsonc` by hand; release-please owns it.

Local package build (Git Bash): `scripts/package.sh OrdaenMinimap` → `.release/` (it runs
`ordaen build --release` first). CI installs the `ordaen` release pinned in `.ordaen-version` with the org App,
which needs read access to `wow-dev-tools`.

### Adding an addon

1. Create `addons/<Name>/` with an `addon.jsonc` (copy one; `"version": "0.0.0"` with its
   `// x-release-please-version` comment), `locales/enUS.json` + `locales/ruRU.json`, and the Lua files.
2. Start it with `OrdaenCore.NewAddon` as in `addons/OrdaenMinimap/Core.lua`; set `"minCore"` to the current Core
   version.
3. Add it to `release-please-config.json` (`packages`, with `"initial-version": "0.1.0"` and
   `"extra-files": ["addon.jsonc"]`) and `.release-please-manifest.json` (`"0.0.0"`).
4. Add the addon to the dropdown in `.github/ISSUE_TEMPLATE/bug_report.yml`.
5. `ordaen build` and `ordaen link`, then `/reload`.

## Repository secrets

| Secret | Needed for |
|---|---|
| `RELEASE_APP_PRIVATE_KEY` (+ variable `RELEASE_APP_CLIENT_ID`) | Org GitHub App that release-please acts as (Contents + Pull requests: read/write). |
| `CF_API_KEY` | CurseForge uploads (plus `"curseforgeId"` under `"package"` in the addon.jsonc). |
| `WAGO_API_TOKEN` | Wago uploads (plus `"wagoId"` under `"package"` in the addon.jsonc). |
