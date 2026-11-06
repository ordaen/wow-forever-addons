---
name: text-en
description: How to write English (enUS) player-facing text for Ordaen addons. Use whenever you add or change a string in any addons/*/locales/enUS.json, addon.jsonc notes or title, or English text on a CurseForge page, changelog or popup. Every key also needs its Russian string: follow the text-ru skill for that.
---

# English player-facing text

enUS is the base language and the fallback for every other client. Players read these strings in the game, in
a tooltip or a settings page, in a second or two. Write so that a second is enough.

## Rules

1. **Mouse buttons are Left-click and Right-click.** Hints read `Left-click: open the drawer`,
   `Right-click: settings`, `Shift+Left-click: …`, `Drag: move it around the minimap`. Never a bare "Click" (it hides
   which button), "LMB/RMB" or "press the left mouse button".
2. **No fluff.** Say what it is or what it does, nothing else: no "This option allows you to…", "Here you can…",
   "please", exclamation marks, marketing words ("handy", "powerful", "seamless"). The first words carry the
   meaning.
3. **Clear instructions.** One action per sentence, in the imperative (`Type /reload`, `Disable one of them`). Give
   the result or the reason only when the player needs it (`…to put the buttons back on the minimap`).
4. **The game's own words.** Use the terms Blizzard's client uses (Minimap, Calendar, World Map, AddOns list,
   Options, Edit Mode), so players find what we name. Prefer Blizzard's globals (`CLOSE`, `OKAY`, `CANCEL`, `RESET`,
   `SETTINGS`) over our own strings when they fit (CLAUDE.md, Localization).
5. **Same thing, same word.** Once a thing has a name ("button drawer"), every string uses that name.
6. **Form.** Labels and buttons: sentence case, no full stop (`Border style`, not `Border Style`). Tooltips and
   messages: full sentences with a full stop. Hint lines `Action: result`, no full stop. Plain words over jargon
   ("button drawer", not "LDB launcher container").
7. **Room for Russian.** The ruRU string runs 20–30% longer; keep the English short so both fit the same place.
8. **Placeholders.** `%s`, `%d` placed so the sentence reads well with any value; the ruRU string needs the same
   placeholders in the same order (the build refuses a mismatch).

## Examples

| Bad | Good |
|---|---|
| Click: open or close the drawer | Left-click: open or close the drawer |
| This option lets you hide Blizzard's addon button. | Hide Blizzard's addon button |
| Please reload your UI for the changes to take effect! | Type /reload to apply. |
