---
name: debug-in-game
description: Debug an Ordaen addon's in-game behavior in WoW Forever. Use when the user reports a bug, error, odd layout or "it doesn't work" from the game, says "check" or "saved" after testing, or when a feature needs testing in game. Covers the Ordaen Dev window workflow for the user, which file to read (OrdaenCore_Debug.lua SavedVariables: errors, logs, dumps, notes), and how to make code observable with the debug kit.
---

# Debugging Ordaen addons in game

You cannot see the game; the user can. Work from files the game writes to disk, never from guesses about what it showed.

## Paths

- Game: `C:\Program Files (x86)\World of Warcraft\_forever_\` (below: `_forever_\`)
- SavedVariables: `_forever_\WTF\Account\1170042654#1\SavedVariables\`. If this folder is missing, list `_forever_\WTF\Account\`.
- Screenshots: `_forever_\Screenshots\` (Print Screen in game)
- Client logs: `_forever_\Logs\`

## 0. Dev mode must be on

Everything below needs the dev-only addon **Ordaen Core - Debug** (`OrdaenCore_Debug`), which lives in the private repo `C:\Users\f3oal\code\ordaen\wow-dev-tools` (junctioned into AddOns by its `scripts/link.ps1`) and is never shipped to players. It must be enabled in the in-game AddOns list. When it's on, a gear button with a red error badge sits on the minimap edge and the **Ordaen Dev** window is available. If `OrdaenCore_Debug.lua` is missing or its `session` doesn't advance, ask the user to enable the addon and restart the client.

## 1. Make the code observable before testing

- New code logs its decisions with `Debug.Log(...)` / `Debug.Logf(fmt, ...)`: what was collected or skipped and why, sizes, positions, events. Logging is cheap when off, but guard expensive string building with `if Debug.IsEnabled() then ... end`.
- The `dump` callback passed to `Debug.Init` returns the state the feature owns. Frames can go in as they are: `Debug.Snapshot` stores name, parent, shown/visible, size, points, strata, level, alpha and scale.
- Wrap event, script and slash handlers in `Debug.Wrap(fn)`. Dev mode also catches errors globally (any addon, file-load errors, unwrapped code) and blocked actions (taint), so wrapping is about clean stacks, not coverage.
- Run `bash scripts/test.sh` (Git Bash; runs luacheck and busted in WSL) and get it green.

## 2. Hand over with a repro script

The game runs the build of whatever is on `develop` in the main checkout `C:\Users\f3oal\code\ordaen\wow-forever-addons`: its `dist/`, through the AddOns junctions. `ordaen watch` running there keeps `dist/` current; if it isn't running, run `ordaen build` there. Before handing over, get the change there: commit it on the feature branch, rebase onto `develop`, then run `git merge --ff-only <branch>` from the main checkout. Never switch the main checkout to another branch or re-point the junctions. If the change adds an addon folder, run `ordaen link` in the main checkout.

Tell the user exactly what to do:

1. `/reload`. On Forever it also picks up new files, TOC changes and new addon folders (link new ones first with `ordaen link`).
2. Reproduce the problem. Take a screenshot (Print Screen) if it's visual.
3. Open the Ordaen Dev window (gear button), type what they saw in **Note for Claude**, and click **Save for Claude & reload**. That dumps every Ordaen addon's state, stores the note and writes everything to disk.
4. Tell Claude "check".

## 3. Read the results

1. `SavedVariables\OrdaenCore_Debug.lua` (`OrdaenCoreDebugDB`):
   - `saves`: the newest entry has the user's `note`, `time`, `session` and `combat`. Start there.
   - `errors`: newest last. `kind` is `"error"` or `"taint"`. `source` is the Ordaen addon folder, or `"other"` for other addons and Blizzard. Each has `message`, `count`, `stack`, `locals`, `time`/`lastTime` and `session`/`lastSession`. Look at entries whose `session`/`lastSession` matches the save.
   - `addons[<Addon>].log`: timestamped lines, newest last. A `---- session N start` line marks each load.
   - `addons[<Addon>].dump`: the state saved with the click.
   - `sessions[N]`: client build, locale and Core version.
2. The newest file in `Screenshots\`: open the image and compare it with the dump's sizes and points.
3. `SavedVariables\!BugGrabber.lua`, if BugSack is installed. Usually not needed: our catcher records the same errors.
4. `Logs\`: only for addon-loading or TOC problems.

Read only our own addons' files (and BugGrabber's), not other addons' saved data.

## 4. Decide

- The data explains the bug: fix it, add a busted spec when the logic is pure, run `scripts/test.sh`, and go back to step 2.
- It doesn't: add logging or dump fields where the gap is and do another round. Don't ship speculative fixes, and say plainly what is still unknown.
- Once a bug is fixed, keep the useful log lines and remove the noisy ones.

## Reference

- Code: `../wow-dev-tools/addons/OrdaenCore_Debug/` (`Store.lua` data, `Capture.lua` error catcher, `Debug.lua` per-addon kit, `Channel.lua` pixel channel, `ApiDump.lua`, `UI.lua` window). Changes to it are committed in that repo (its `main` is what the game loads). The no-op stand-in for players is in `addons/OrdaenCore/Core.lua`.
- The window opens from the gear button on the minimap edge (not a compartment entry, so the drawer leaves it alone), `/ordaen`, or `/<addon cmd> debug`. In dev mode errors are not passed to Blizzard's error popup (only to BugGrabber if installed). The Errors tab has filters (All, Ordaen, Other addons, Blocked actions), **Test error**, **Clear all**, and **Select for copy** for bug reports.
- Limits: 100 distinct errors (repeats are counted), 1000 log lines per addon, 20 saves, snapshots 5 levels deep and 200 keys per table.
