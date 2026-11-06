---
name: debug-in-game
description: Debug an Ordaen addon's in-game behavior in WoW Forever. Use when the user reports a bug, error, odd layout or "it doesn't work" from the game, says "check" or "done" after testing, after merging a change the user will /reload, or when a feature needs testing in game. Covers the companion's live tools (wow_status, wow_errors, wow_log, wow_watch, wow_screenshot), what the user does in game, the saved data as a fallback, and how to make code observable with the debug kit.
---

# Debugging Ordaen addons in game

You cannot touch the game; the user plays it. You can see it: the companion app (wow-dev-tools) reads a live stream
from the dev addon and serves it as the MCP server `ordaen`. Work from that data and from what the user tells you in
chat, never from guesses about what the game showed.

## 0. Dev mode and the companion must be on

- The dev-only addon **Ordaen Core - Debug** (`OrdaenCore_Debug`, private repo `C:\Users\f3oal\code\ordaen\wow-dev-tools`,
  junctioned into AddOns by its `scripts/link.ps1`, never shipped) must be enabled in the in-game AddOns list. When
  it's on, a gear button sits on the minimap edge and the **Ordaen Dev** window is available.
- The companion (`ordaen-companion.exe`) must be running. `wow_status` says whether WoW runs, whether the stream is
  connected and which session it is. If the `ordaen` tools are missing in this session, the MCP server was registered
  after the session started: ask the user to restart the session.

## 1. Make the code observable before testing

- New code logs its decisions with `Debug:Log(...)` / `Debug:Logf(fmt, ...)` (info), `Debug:Warn/Warnf` (warn),
  `Debug:Verbose/Verbosef` (debug): what was collected or skipped and why, sizes, positions, events. Guard expensive
  string building with `if Debug:IsEnabled() then ... end`. Release builds strip all of it.
- Make every user action you want to verify leave a log line, otherwise you can't tell from the log whether it
  happened (e.g. opening a settings page leaves none today).
- The `dump` callback passed to `Debug:Init` returns the state the feature owns; `Debug:Snapshot` turns frames into
  name, parent, shown/visible, size, points, strata, level, alpha and scale.
- Wrap event, script and slash handlers in `Debug:Wrap(fn)` (the framework's `A:On` does it already). Dev mode also
  catches errors globally and blocked actions (taint), so wrapping is about clean stacks, not coverage.
- `ordaen check` green before handing over.

## 2. Hand over

The game runs the build of `develop` in the main checkout `C:\Users\f3oal\code\ordaen\wow-forever-addons`: its `dist/`,
through the AddOns junctions, kept current by `ordaen watch` running there (else `ordaen build` there). Get the change
there with `ordaen merge <branch>`. Never switch the main checkout to another branch or re-point the junctions; a new
addon folder needs `ordaen link`.

Note the newest message id (`wow_status` → `newest_id`), then tell the user exactly what to do:

1. `/reload` (on Forever it also picks up new files, TOC changes and new linked addon folders).
2. The steps to reproduce or test, one per line.
3. Say in chat what they saw. A screenshot is optional: you can take one yourself.

Instead of waiting for "done", you can `wow_watch` for the session start or the log line the change produces.

## 3. Read the results

1. `wow_errors` (`since` = the id you noted): grouped Lua errors and blocked actions with stacks and locals, by source
   addon. Our addons are `OrdaenCore`, `OrdaenMinimap`, ...; `other` is other addons and Blizzard. An error group
   counts every repeat; check `last_seen` before blaming the current build.
2. `wow_log` (`sources = {"OrdaenMinimap"}`, `since`, `levels` incl. `"debug"` when needed): the timestamped log,
   including `---- session N start`. Match the user's description to log lines.
3. `wow_screenshot`: the WoW window. Compare with the code's sizes and points.
4. `wow_dump { addon? }`: each addon's state (its `dump` callback: settings, frame snapshots), with the time and
   session it was taken. The companion can't ask the game for it (the channel is one-way), so first ask the user to
   open the Ordaen Dev window (gear button on the minimap) and click **Send state**; no reload needed.
5. Fallback when the companion isn't running: the saved data in
   `_forever_\WTF\Account\1170042654#1\SavedVariables\OrdaenCore_Debug.lua` (`OrdaenCoreDebugDB`: `errors`,
   `addons[<Addon>].log`, `addons[<Addon>].dump`, `sessions`). WoW writes it only on `/reload` or logout. Paths:
   game `C:\Program Files (x86)\World of Warcraft\_forever_\`, screenshots in `_forever_\Screenshots\`, client logs in
   `_forever_\Logs\` (only for addon-loading or TOC problems).

Read only our own addons' data, not other addons' saved data.

## 4. Decide

- The data explains the bug: fix it, add the static check that would have caught it (CLAUDE.md "Preventing bugs"),
  add a busted spec when the logic is pure, `ordaen merge`, and go back to step 2.
- It doesn't: add logging or dump fields where the gap is and do another round. Don't ship speculative fixes, and
  say plainly what is still unknown.
- After every merge the user reloads, read `wow_errors` (and `wow_log`/`wow_screenshot` for what changed) before
  reporting the change as done.
- Once a bug is fixed, keep the useful log lines and remove the noisy ones.

## Reference

- Dev addon code: `../wow-dev-tools/addons/OrdaenCore_Debug/` (`Store.lua` data, `Capture.lua` error catcher,
  `Debug.lua` per-addon kit, `Channel.lua` pixel channel, `ApiDump.lua`, `UI.lua` window). It's owned by the dev-tools
  session; send it requests. The players' no-op stand-in is `addons/OrdaenCore/Core.lua`.
- The Ordaen Dev window opens from the gear button, `/ordaen`, or `/<addon cmd> debug`. Errors tab: filters (All,
  Ordaen, Other addons, Blocked actions), **Test error**, **Clear all** (old errors stay listed until cleared),
  **Select for copy**.
- Limits: 100 distinct errors (repeats are counted), 1000 log lines per addon, snapshots 5 levels deep and 200 keys
  per table.
