# forever-addons

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
   ```
4. **Repo**, in the repo folder:
   ```powershell
   npm install                  # commitlint + the git commit-msg hook (husky)
   pwsh ./scripts/link.ps1      # junction every addon into the Forever AddOns folder
   ```
   A junction is Windows' directory link (like a symlink; no admin needed). `pwsh ./scripts/link.ps1 -Unlink` removes
   the junctions and leaves the repo files alone. The junctions point at this checkout, so keep it on `develop`
   (`git switch develop`): what's on `develop` is what the game runs.
5. **In game:** enable **Ordaen Core - Debug** in the AddOns list (dev mode, see below). BugSack/BugGrabber are
   not needed; dev mode has its own error catcher.

### Everyday loop

`develop` collects finished work and is what the game runs. Each feature gets its own branch in its own
[git worktree](https://git-scm.com/docs/git-worktree) (a second working folder of the same repo), so the game
checkout never changes branch.

1. Start a feature (Git Bash, in the repo folder):
   ```bash
   git worktree add ../forever-addons-<topic> -b feat/<topic> develop
   cd ../forever-addons-<topic> && npm install    # installs the commit hook in the new folder
   ```
2. Edit and commit there (signed, [Conventional Commits](#commits)).
3. Run the same Lua checks as CI: `scripts/test.sh`. Extra arguments go to busted
   (`scripts/test.sh --filter Snapshot`).
4. Bring it into the game: `git rebase develop` in the worktree, then from the main checkout
   `git merge --ff-only feat/<topic>`.
5. In game: `/reload`. A **new file or a changed `.toc` needs a full client restart**; WoW only scans the AddOns
   folder at startup.
6. When the feature is done: `git worktree remove ../forever-addons-<topic>` and `git branch -d feat/<topic>`.

Code shared by several addons lives in **Ordaen Core** (`addons/OrdaenCore/`), which every addon lists in
`## Dependencies`. Users can update the Core and the addons separately, so the Core's API only grows: never change
or remove anything that has been released; add a new name instead. An addon that needs a newer Core sets
`## X-Ordaen-MinCore: <version>` in its TOC (git checkouts skip that check).

### Debugging in game

Debugging is an optional **development mode**, so players never have errors collected. To turn it on, enable
**Ordaen Core - Debug** in the in-game AddOns list (it ships with Ordaen Core, disabled by default) and restart
the game. When it is disabled, nothing is recorded and errors go to BugSack or Blizzard's default handler.

In dev mode a **gear button** sits on the minimap edge (drag it around the minimap); a red number on it counts
new errors. It is not an addon compartment entry, so the Ordaen Minimap drawer leaves it alone. Click it (or use
`/ordaen` or `/om debug`) to open the **Ordaen Dev** window:

- **Errors**: every Lua error in the game (ours, other addons, Blizzard) and every blocked action (taint), with
  stack trace, local variables and versions. Filters for Ordaen / other addons / blocked actions,
  **Test error**, **Clear all**, and **Select for copy** for bug reports. Repeats are counted, not stored again.
  In dev mode the window replaces Blizzard's error popup (no sounds, no popup that keeps reopening on a
  repeating error). If BugSack is installed too, it still gets every error.
- **Performance**, **Log** and **Inspect** are coming next.
- **Note for Claude** + **Save for Claude & reload**: saves every Ordaen addon's state and your note, then
  reloads so everything is written to disk. This is the usual way to hand a test result to Claude.

Everything lives in one file, which WoW writes on `/reload` or logout:
`C:\Program Files (x86)\World of Warcraft\_forever_\WTF\Account\<account>\SavedVariables\OrdaenCore_Debug.lua`.
Screenshots (Print Screen) go to `_forever_\Screenshots\`.

Addons cannot reach the network, so there is no telemetry. To report a bug, a player enables Ordaen Core - Debug,
reproduces the problem, selects the error in the Ordaen Dev window and pastes it into the
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

Never edit `## Version` in a `.toc` by hand; release-please owns it.

Local package build (Git Bash): `scripts/package.sh OrdaenMinimap` → `.release/`.

### Adding an addon

1. Create `addons/<Name>/` with `<Name>.toc` (copy the version block markers and the `## Category` lines from an
   existing addon), `.pkgmeta`, Lua files.
2. Add it to `release-please-config.json` (`packages`, with `"initial-version": "0.1.0"`) and `.release-please-manifest.json` (`"0.0.0"`).
3. Depend on the Core: `## Dependencies: OrdaenCore` and `## X-Ordaen-MinCore: <current Core version>` in the TOC,
   `## OptionalDeps: OrdaenCore_Debug` in the TOC, `required-dependencies: [ordaen-core]` in `.pkgmeta`, and wire up
   the debug kit as in
   `addons/OrdaenMinimap/Core.lua`.
4. Add the addon to the dropdown in `.github/ISSUE_TEMPLATE/bug_report.yml`.
5. Rerun `pwsh ./scripts/link.ps1`, then restart the game client.

## Repository secrets

| Secret | Needed for |
|---|---|
| `RELEASE_APP_PRIVATE_KEY` (+ variable `RELEASE_APP_CLIENT_ID`) | Org GitHub App that release-please acts as (Contents + Pull requests: read/write). |
| `CF_API_KEY` | CurseForge uploads (plus `## X-Curse-Project-ID` in the TOC). |
| `WAGO_API_TOKEN` | Wago uploads (plus `## X-Wago-ID` in the TOC). |
