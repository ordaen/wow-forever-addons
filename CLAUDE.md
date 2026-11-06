# forever-addons

Monorepo of World of Warcraft addons for the **WoW Forever** flavor (interface `16001`).
Developed on Windows (the user normally works on Linux — explain Windows specifics when relevant).

## Game install

- Forever client: `C:\Program Files (x86)\World of Warcraft\_forever_\`
- AddOns folder: `C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\`
- Each addon in `addons/<Name>/` gets a directory junction in the AddOns folder via `scripts/link.ps1` (no admin needed), so edits show after `/reload` in game. The junctions point at the main checkout `C:\Users\f3oal\code\forever-addons`, which stays on `develop` (see Branches).

## Decisions so far

- User wants things done properly from the start (full tooling, not "add later").
- Repo: public GitHub repo `ordaen/forever-addons` (org; user is admin). The org forbids GITHUB_TOKEN from opening PRs, so release-please uses an org GitHub App token (`vars.RELEASE_APP_CLIENT_ID`, `secrets.RELEASE_APP_PRIVATE_KEY`). Default branch `main`, squash-merge only, PR title = commit message.
- Commit identity (global git config): `David Iunevich <1751835+f3oall@users.noreply.github.com>`. GitHub user `f3oall`.
- Signed commits are required on every branch (ordaen org ruleset). Commits are SSH-signed with `~/.ssh/id_ed25519` (global `commit.gpgsign`/`tag.gpgsign`). Commits GitHub creates (squash merges, release-please via the App, Dependabot) are signed by GitHub.
- `main` ruleset: PR-only, squash-only, linear history, required checks `Conventional commits`, `Lint & test (Lua)`, `Package (dry run)`; repo admins may bypass only when merging a PR. Work on a branch and open a PR.
- **Branches (local-only until the user says otherwise: no push, PR or merge on GitHub):**
  - `develop` is the integration branch and the **game checkout**: the main checkout `C:\Users\f3oal\code\forever-addons` stays on `develop`, and the game loads it through the junctions. Never switch that checkout to another branch.
  - Do feature work on a branch off `develop` in its own worktree: `git worktree add ../forever-addons-<topic> -b feat/<topic> develop`, then `npm install` there (installs the commit hook).
  - When `scripts/test.sh` is green, rebase onto `develop` and run `git merge --ff-only feat/<topic>` from the main checkout. That keeps the signed conventional commits. Then the user does `/reload`, or restarts the client if files were added or a `.toc` changed.
  - Revisit at release: `main` is squash-only, so one develop→main PR gives each addon a single changelog line, and a commit touching several addons shows in each addon's changelog. Prefer one PR per addon or feature with a player-facing title. The merged rename PR #4 and release PR #5 need a `BEGIN_COMMIT_OVERRIDE` block so the rename line stays out of the first changelog.
- Line endings: LF everywhere via `.gitattributes`. On Windows, set the exec bit with `git add --chmod=+x scripts/package.sh`.
- Commits: Conventional Commits via commitlint (`commitlint.config.mjs`; scope = addon folder name or repo scope), enforced by husky `commit-msg` hook and in CI (PR title + PR commits).
- Versioning: release-please manifest mode (`release-please-config.json`, `.release-please-manifest.json`), one component per addon, tags `<Addon>-vX.Y.Z`. release-please bumps `## Version` in the TOC via `x-release-please-start-version` block markers — never edit it by hand.
- Quality: luacheck + busted (pure-logic tests only, Lua 5.1) in CI; manual testing in game with BugSack/BugGrabber.
- Dev environment is Windows + WSL only (README "Development" describes nothing else). Lua 5.1, luacheck and busted live in the WSL distro `Ubuntu`; `scripts/test.sh` (run from Git Bash) runs luacheck + busted there. From Git Bash, call WSL with `MSYS_NO_PATHCONV=1` and `--exec` (otherwise Git Bash rewrites `/mnt/...` paths and WSL's shell expands `$1` early).
- Packaging: BigWigs packager (pinned in `scripts/package.sh`). It requires a git repo root as topdir, so the script copies the addon into a temp git repo and tags it. Packager handles CurseForge/Wago uploads; the zip is attached to release-please's GitHub release with `gh release upload` (packager's own GitHub upload would overwrite the release notes). Packager maps interface `16???` to the `forever` flavor (CurseForge game id 88568).

## Layout

```
addons/<Addon>/                 addon source (.toc, .lua, .pkgmeta)
addons/OrdaenCore/              shared code every addon depends on (global OrdaenCore; debug kit)
tests/<Addon>/*_spec.lua        busted specs (load addon files with loadfile(path)(addonName, ns))
tests/OrdaenCore/helpers.lua    WoW API stubs + Core loader, for any spec that needs the Core
scripts/link.ps1                create/remove AddOns junctions
scripts/package.sh              package one addon (CI + Git Bash)
scripts/test.sh                 luacheck + busted (Git Bash -> WSL, or native on Linux/CI)
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

## First addon: OrdaenMinimap

Our own specialized take on **SexyMap** (installed reference: `_forever_\Interface\AddOns\SexyMap\`), deliberately with
little configuration: opinionated defaults instead of option panels. Renamed from MinimapCompartment before its first
release; the button drawer + addon compartment is one feature of it. Feature scope beyond the drawer is still to be
decided with the user.

- SavedVariables `OrdaenMinimapDB`; slash `/om` (alias `/ordaenminimap`).
- Feature: button drawer (replaces MinimapButtonButton, MBB) that also collects **addon compartment** entries.
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
- Each addon starts with `if not OrdaenCore.IsCompatible(addonName) then return end`, then takes its own debug kit with `OrdaenCore.NewDebug(addonName)`. Init it in `ADDON_LOADED` with the addon's SavedVariables table, wrap handlers in `Debug.Wrap`, and forward slash input through `Debug.HandleSlash` (example: `addons/OrdaenMinimap/Core.lua`). New code logs its decisions with `Debug.Log`.
- Before handing code over for an in-game test, run `bash scripts/test.sh` until it is green. Say whether `/reload` is enough or a full client restart is needed (any new file or `.toc` change).
- For anything observed in game (bugs, errors, layout, "check" after a reload), follow the `debug-in-game` skill (`.claude/skills/debug-in-game/SKILL.md`).
- Addons have no network access, so there is no telemetry. Users report errors with `/<cmd> errors` and the GitHub issue form. Add each new addon to its dropdown.
