---
name: debug-in-game
description: Debug an Ordaen addon's in-game behavior in WoW Forever. Use when the user reports a bug, error, odd layout or "it doesn't work" from the game, says "check" after a /reload, or when a feature needs testing in game. Covers the repro script for the user, which files to read (SavedVariables debug log/dump/errors, BugGrabber, screenshots) and how to make code observable with the OrdaenDebug kit.
---

# Debugging Ordaen addons in game

You cannot see the game; the user can. Work from files the game writes to disk, never from guesses about what it showed.

## Paths

- Game: `C:\Program Files (x86)\World of Warcraft\_forever_\` (below: `_forever_\`)
- SavedVariables: `_forever_\WTF\Account\1170042654#1\SavedVariables\`. If this folder is missing, list `_forever_\WTF\Account\`.
- Screenshots: `_forever_\Screenshots\` (Print Screen in game)
- Client logs: `_forever_\Logs\`

## 1. Make the code observable before testing

- New code logs its decisions with `Debug.Log(...)` / `Debug.Logf(fmt, ...)`: what was collected or skipped and why, sizes, positions, events. `Debug.Log` returns early when debug is off, but guard expensive string building with `if Debug.IsEnabled() then ... end`.
- The `dump` callback passed to `Debug.Init` returns the state the feature owns. Frames can go in as they are: `Debug.Snapshot` stores name, parent, shown/visible, size, points, strata, level, alpha and scale.
- Event, script and slash handlers are wrapped in `Debug.Wrap(fn)`, so errors are recorded with stack and locals and still reach BugSack.
- Run `bash scripts/test.sh` (Git Bash; runs luacheck and busted in WSL) and get it green.

## 2. Hand over with a repro script

Tell the user exactly what to do, with the addon's own slash command (`/om` for OrdaenMinimap):

1. Restart the client or `/reload`: say which. **A new file or any `.toc` change needs a full client restart.**
2. `/om debug on`, then `/om debug clear`
3. Reproduce the problem
4. `/om dump` if layout or state matters; Print Screen if it's visual
5. `/reload` (SavedVariables are written to disk only on reload or logout), then tell Claude "check"

The game loads addons through junctions to the main checkout `C:\Users\f3oal\code\forever-addons`. If the code is on another worktree or branch, tell the user to check it out there, or relink: `pwsh ./scripts/link.ps1 -Unlink` in the main checkout, then `pwsh ./scripts/link.ps1` in the worktree.

## 3. Read the results in this order

1. `SavedVariables\<Addon>.lua`: `<Addon>DB.debug.errors` (message, count, stack, locals, versions), then `debug.log` (timestamped, newest last), then `debug.dump`.
2. `SavedVariables\!BugGrabber.lua`: errors from every addon, including ones raised outside our wrapped handlers. Needs BugSack and BugGrabber installed.
3. The newest file in `Screenshots\`: open the image and compare it with the dump's sizes and points.
4. `Logs\`: only for addon-loading or TOC problems.

Read only our own addons' files and BugGrabber's, not other addons' saved data.

## 4. Decide

- The data explains the bug: fix it, add a busted spec when the logic is pure, run `scripts/test.sh`, and go back to step 2.
- It doesn't: add logging or dump fields where the gap is and do another round. Don't ship speculative fixes, and say plainly what is still unknown.
- Once a bug is fixed, keep the useful log lines and remove the noisy ones.

## Kit reference (`OrdaenCore.NewDebug(addonName)`, in `addons/OrdaenCore/Debug.lua`)

| In game | Effect |
|---|---|
| `/<cmd> debug [on\|off\|echo\|clear]` | Toggle the log; `echo` also prints it to chat; `clear` empties the log and the dump |
| `/<cmd> dump` | Save `Debug.Meta()` and the addon's dump to `debug.dump` |
| `/<cmd> errors [clear]` | Copyable report window that links to `.github/ISSUE_TEMPLATE/bug_report.yml` |
| `/<cmd> debug error` | Raise a test error through the whole pipeline |

Limits: 1000 log lines, 50 distinct errors (repeats are counted), snapshots 5 levels deep and 200 keys per table.
