# What the Forever client does

What the WoW Forever client (interface `16001`) does or refuses that an addon or lunatype's stand-in client
(`src/standin`) must follow, as seen in the game or read from the client's own data. Look here before assuming how
the client behaves. A fact learned of the client goes into the stand-in, with a test that fails without it, and into
this page, in the same change.

Each entry: the fact; **Known** (the game session or build it was seen on, or the commit that says so); **Stand-in**
(where `lunatype/src/standin` holds it, and the test that fails without it), or **not held** — the gaps, listed again
at the end. Commits are lunatype's unless named `dev` (wow-dev-tools). What tooltips carry is
[`tooltip-data.md`](tooltip-data.md).

## Loading and TOCs

- **`## LoadFirst` is read only from Blizzard's own addons' TOCs.** Other addons load in the order of their names
  (whatever their case), each after the addons it needs; so the build loads a dev addon first through `!<name>`, an
  addon of one empty file that needs it. Known: b4bf242, dev 6d7c41d (2026-11-15). Stand-in: `Host.clientOrder`
  (`host.lua`); `tests/run/app.out` (OrdaenDev and Showcase in their names' place), `tests/hostless/Tool`.
- **An addon whose `## Dependencies` names one that is off or missing doesn't load:** its files don't run, no
  `ADDON_LOADED`, and `LoadAddOn` gives false with `DISABLED`, `DEP_DISABLED`, `MISSING`, `DEP_MISSING` or
  `NOT_DEMAND_LOADED`. The runtime `LunaType` turned off takes every addon of ours with it. Known: dev 5deb18c (the
  player found every addon off after a dump turned LunaType off), 8f5896d, 7ca726c. Stand-in: `Host.addons`
  (`host.lua`, the reasons); `tests/hostless`.
- **A module's `## Group` lists it under the one addon it needs that the client loads at the start;** one that names
  another `## Category` than its group's is listed apart. Known: 644213b. Not held by the stand-in (the build's
  finding, `tests/grouped`).
- **`/reload` takes new files, TOC changes, new art and new addon folders.** Known: skill `debug-in-game`. Not held
  by the stand-in (it has no files to change between loads).
- **Four Blizzard addons load at login after every addon:** `Blizzard_CombatLog`, `Blizzard_CombatText`,
  `Blizzard_GroupFinder_VanillaStyle`, `Blizzard_PlayerChoice`; their globals, mixins and seven number constants are
  not there while addons load. 24 of the dump's 27 load-on-demand Blizzard addons load on Forever. Known: dev da51ced
  (2026-11-15). Not held by the stand-in.

## The list of addons and saved variables

- **`EnableAddOn`/`DisableAddOn` change the list in memory only;** a `/reload` without `C_AddOns.SaveAddOns()` loses
  the change. Known: dev 9bb16b5 (the dump's session at 11:32, 2026-11-14), d6191b2. Stand-in: `api.SaveAddOns`,
  `api.ResetAddOns` (`host.lua`).
- **The list keeps each character's own state** (`GetAddOnEnableState` is mixed where the account's characters
  differ). Known: 644213b, dev 5deb18c. Stand-in: `Host.addons` (`live.split`).
- **The client reads an addon's whole saved-variables file at every login** (a 26 MB file: about 230 ms and 60 MB of
  Lua heap) and writes it on `/reload` or logout. Known: dev eaf28a9 (2026-11-14); skill `debug-in-game`. Not held by
  the stand-in.
- **The Key Bindings window lists an addon's binding only under the `category` its `Bindings.xml` gives it**
  (`<Binding name="X" category="Title">`); one with a `header` alone isn't listed. Known: OpenMap and
  ForeverDungeonJournal, which name a category, are listed; Ordaen Radial's header-only ones weren't (the user,
  2026-11-20). Stand-in: `Client.listedBindings`, `GetBinding` (`client.lua`, `host.lua`); lunatype
  `tests/layout/Pages/global.test.luna`.
- **The client reads an addon's `Bindings.xml` from its folder by itself;** each binding's body runs on its key.
  Known: 0fdbf8b. Stand-in: `Host.bindings` (`host.lua`), `Test.keyBound`; wow-dev-tools `Keys.test.luna`.

## Taint, protected calls and secret values

- **Forever refuses `ReloadUI` and `C_UI.Reload` from any addon code,** a click's or a key binding's body included,
  with `ADDON_ACTION_FORBIDDEN`. Only the client's own `/reload` reloads: a secure button whose macro is `/reload`.
  Known: build 70938, 2026-11-14 (dev 6852b35: the reload key pressed twice, nothing reloaded). Stand-in:
  `reloadRefused` (`client.lua`); `client_test.lua` «What the client forbids an addon», `Keys.test.luna`.
- **A protected function (`TargetUnit`) is forbidden to addon code** in or out of a fight, inside the player's
  click or not, with `ADDON_ACTION_FORBIDDEN`. Known: c6fcc67. Stand-in: `TargetUnit` (`client.lua`);
  `client_test.lua` «What the client forbids an addon».
- **No addon changes a binding while the player fights** (`SetOverrideBinding*` gives `ADDON_ACTION_BLOCKED`).
  Known: dev 66ad1c3, 6852b35. Stand-in: `protectedInCombat` (`client.lua`).
- **`PLAYER_REGEN_DISABLED` comes before the lockdown, `PLAYER_REGEN_ENABLED` after it ends.** Known: the
  dev-addon stream (`next-archive`, «Driving our windows»). Stand-in: `Client.combat` (`client.lua`).
- **Registering an event kept to Blizzard's code answers `ADDON_ACTION_FORBIDDEN`, no error, and UIParent shows the
  «blocked from an action» dialog;** `C_EventUtils.IsEventValid` asks without registering. Known: build 70888 (dev
  f384798), sessions 465 and 468 (dev c8ad52f). Not held by the stand-in (`Frame:RegisterEvent` takes any event).
- **The client hands some values as secrets** (a unit's health, a nameplate's cast in an event's payload):
  comparing one (even with `nil`), counting with it, taking its length or joining it to a text raises and taints
  the execution; `issecretvalue` tells one. Known: build 70938, 2026-11-14 (ce82077), dev 1b370f2. Stand-in:
  `Client.secret`, `issecretvalue` (`client.lua`), `Test.secret()`; `client_test.lua` «What the client keeps from
  addons». Comparing with `nil` is not held: Lua 5.1 calls `__eq` only between two tables.
- **A table the client keeps raises when walked or read** (`pairs`, `next`, `ipairs`, a key); `canaccesstable`
  tells one. Known: dev d6fe56d, 0fdbf8b. Stand-in: `Client.secretTable`, `canaccesstable` (`client.lua`);
  wow-dev-tools `Json.test`, `Record.test`. `#` of one is not held (Lua 5.1 can't refuse it).
- **A secret used as a table key raises.** Known: the dev-addon stream («Blocked»). Not held by the stand-in (a
  table key is raw in Lua 5.1).

## Frames, strata and the mouse

- **`C_UI.GetUIParent()` gives nothing on Forever** (its documentation is retail's); the screen's frame is the
  global `UIParent`. Known: build 70938, 2026-11-14 (d79fb9d, dev acf6b75). Stand-in: `C_UI` (`client.lua`).
- **A region has no place (`GetLeft()` gives nothing) until a frame has drawn it;** code run in the frame of a show
  is told none, and the mouse finds only drawn frames. Known: build 70938, 2026-11-14 (0fdbf8b). Stand-in:
  `drawnYet`, `Client.draw` (`client.lua`); `client_test.lua` (no place before drawn).
- **A frame of no width or no height has no place either** (`GetLeft()` gives nothing): an empty box, an empty
  text. Known: the first game test (`next-archive:next/tests.md`, «The stand-in kinder than the client»). Not held
  by the stand-in (`Client.rect` gives it a rect).
- **The mouse takes a frame by the strata of the frame round it that stands in `UIParent`,** then as drawn: a list
  told FULLSCREEN_DIALOG inside a window on DIALOG loses every click to a FULLSCREEN frame in `UIParent`; a popup
  stands on a surface of its own. Known: dev build, 2026-11-14 09:06–09:07 (c607af8). Stand-in: `topmost`,
  `mouseAbove` (`client.lua`); wow-forever-addons' dropdown, profile, professions, settings and Showcase tests.
- **A frame given a strata or a level gives its strata to every frame in it whose strata isn't fixed**
  (`SetFixedFrameStrata`), and a frame set in another parent takes that one's. Inferred from the game's records, not
  seen directly. Known: 824ffb3, 0fb1843. Stand-in: `inheritStrata` (`client.lua`); `client_test.lua` «Strata and
  levels».
- **A toplevel frame comes over the others of its strata as it shows and as the mouse goes down in it.** Known:
  4e073f7 (Ordaen System's «AddOns» lost its click to the game menu). Stand-in: `Frame:SetToplevel`, `Frame:Raise`
  (`client.lua`); `client_test.lua` «A toplevel frame comes over the others».
- **The release of a press whose frame went is given to the frame now under the cursor, as a click.** Known: the
  first game test (0fb1843: a module's switch turned with no click of its own). Stand-in: the mouse's release
  (`client.lua`); `client_test.lua` «Mouse sequences».
- **`OnSizeChanged` is told only for a new size.** Known: 0fb1843 (from the client's API, not seen). Stand-in:
  `client.lua`; `client_test.lua` «OnSizeChanged».
- **A frame clamped to the screen stands inside it,** moved in whole, its points as they were set. Known: a03e55e,
  2b06e1e. Stand-in: `heldOnScreen` in `Client.rect` (`client.lua`); `client_test.lua` «A frame clamped to the
  screen».
- **`GetCursorPosition` gives the screen's pixels** (`UIParent`'s scale divides it back); past one edge of the
  game's window it gives the other axis at its start (a window dragged into the left edge fell to the bottom left
  corner). Known: 2b06e1e, dev 2effcfd. Stand-in: `GetCursorPosition` (`client.lua`); `client_test.lua`.
- **`C_Spell.PickupSpell(id)` puts a spell on the cursor** (`CursorHasSpell`, not `CursorHasItem`), outside the
  player's input too; an action button the cursor is let go over takes it. Not yet confirmed in game for a drag that
  starts on an addon's frame. Stand-in: `C_Spell.PickupSpell` (`client.lua`); `spells.test.luna` in `src/game`.
- **Once the cursor has left the game's window the client keeps it on the screen's outermost pixel** and shows what
  lies in the world there: a world tooltip (owned by `UIParent` or `WorldFrame`) shown then is hidden at its show.
  Known: lunatype f9ac480 (2026-11-14, branch `fix/text-and-tips`). Held by the game side (`tooltip.luna`), test
  «a world tooltip with the cursor on the screen's outermost pixel is none…» (`tooltip.test.luna`); not held by the
  stand-in, whose cursor goes past the edge rather than stopping on it.
- **`IsMouseMotionFocus` is the frame the cursor was found on;** a script run by code (`ExecuteFrameScript`) moves
  nothing. Known: a03e55e (the minimap's tracking button lost its hover). Stand-in: `Frame:IsMouseMotionFocus`
  (`client.lua`); `tests/layout` «Relayed».
- **`GetTextureFileID` gives nil for a texture with no file,** not 0. Known: 8c6a4bd (LunaType/game failed to load
  in the game). Stand-in: `Texture:GetTextureFileID` (`client.lua`); the bag buttons' test.
- **The client's item buttons carry their own `SetAlpha` (`ItemButtonMixin`),** which fades the icon and the count
  alone; the frame's own is reached through its metatable. Known: 2c90ffd. Stand-in: the bag buttons' `SetAlpha`,
  `ToggleAllBags` (`client.lua`).

## The keyboard and bindings

- **An EditBox focuses itself** (`SetAutoFocus`, true by default): one made shown, or shown later, takes the
  keyboard and keeps every key from the bindings (W walks nothing, Escape opens no menu). Known: the game,
  2026-11-14 (8884ea8, dev f470f01). Stand-in: `_autoFocus` in `createFrame`, `Frame:SetAutoFocus` (`client.lua`);
  after every test the stand-in presses W and fails where a frame keeps it (`test.lua`).
- **Any shown frame with the keyboard takes keys, script or none,** and keeps the propagate flag from key to key;
  `SetPropagateKeyboardInput` is refused in a fight. A key no frame keeps runs the player's binding (Escape:
  `TOGGLEGAMEMENU`). Known: 0fb1843, 8884ea8. Stand-in: `Frame:SetPropagateKeyboardInput`, the key's path,
  `SetBinding("ESCAPE", "TOGGLEGAMEMENU")` (`client.lua`); `client_test.lua` «Keys».
- **The keyboard's frames hear the key alone ("I"), the bindings the key with its modifiers ("CTRL-I").** Known:
  dca2901. Stand-in: `Client.pressBound`, `IsControlKeyDown` (`client.lua`), `Test.chord`.
- **The client reads Alt, Ctrl and Shift from the real keyboard:** a modifier posted to the window never counts.
  Known: the companion keys (`next-archive:next/dev-addon.md`, «Driving our windows»). Not held by the stand-in.
- **Each override binding makes the client say the bindings changed.** Known: dev 6852b35. Not held by the
  stand-in.
- **`SetOverrideBindingClick` and `ClearOverrideBindings` exist, undocumented.** Known: 0fdbf8b. Stand-in:
  `SetOverrideBindingClick` (`client.lua`).
- **A click binding clicks its button only as the button is registered for:** as the key goes down where it took
  `AnyDown` (or `<mouse>Down`), as it comes up where it took `AnyUp`; with no `RegisterForClicks`, `LeftButtonUp`
  alone. The mouse button the binding names is the button `OnClick` is handed (`LunaTypeGlobalKeys` is handed the
  key's name). Known: Blizzard's binding docs, not yet seen on Forever. Stand-in: `Client.pressBound`.
- **An override set with `isPriority` wins over every one set without it, whatever their order;** among those alike,
  the latest. Known: Blizzard's binding docs, not yet seen on Forever. Stand-in: `overrideOf` (`client.lua`).
- **A frame that takes the keyboard hears a key held go down again as the client repeats it, and its up once;**
  the up is kept from the bindings or let go on by the frame's propagation as it stands. Known: the client's key
  repeat. Stand-in: `Client.key` (`phase`), `Test.keyDown`/`Test.keyUp`.

## Text and fonts

- **A font file the client hasn't loaded yet is measured in its own text font,** and nothing is said as the file
  comes. Known: 70303b0 («Тема» drawn «Те…» in the settings window). Stand-in: `Client.fontWidth`
  (`client.lua`), `Test.fontWidth`; `tests/runtime/Runtime/fonts`.
- **A Battle.net name the client keeps from addons (`|K…|k`, a friend's account name) measures 0 unbounded**
  (`GetUnboundedStringWidth`), while the client draws it as the real name and `GetStringWidth` gives that width.
  Known: the friends list's star drawn over each name (`|Ks3|k` drawn 95 wide, laid out 0). Stand-in:
  `FontString:GetUnboundedStringWidth` (`client.lua`); `tests/layout/Pages/keptName`.

## Tooltips

What a tooltip's data holds: [`tooltip-data.md`](tooltip-data.md).

- **The client fills a held tooltip anew every 0.2 s** (`TOOLTIP_UPDATE_TIME`; `ActionButton_OnUpdate` calls
  `SetTooltip` again): a clear (`OnTooltipCleared`), a fill, a show, with the same or other lines. Known: the game,
  2026-11-14 (a03e55e, 9e4a5a3). Stand-in: the tooltip's refresh and `OnTooltipCleared` (`client.lua`);
  `tooltip.test.luna` «a held tooltip the client fills anew with other lines stays unseen while an addon draws it»,
  `client_test.lua`.
- **Moving straight from one source to another hides the tooltip and owns, fills and shows it again in one
  frame.** Known: 3ea3b34. Stand-in: `GameTooltip:SetUnit` and the tooltip's sources (`client.lua`);
  `tooltip.test.luna` «through every transition between its states».
- **The menu button's tooltip (the addons' memory) is filled anew each second.** Known: f0a405e. Not held by the
  stand-in.

## The game's own windows

- **`GameMenuFrame` is toplevel and takes the mouse;** it lays its buttons out a frame after `InitButtons` marks it
  dirty, and its `ObjectPool` hands the last released button first, so on a reshow a button holds another entry
  while it stands where its last one stood. Known: 1144a2f, 4e073f7. Stand-in: the game menu (`client.lua`,
  `menu:InitButtons`, `menu:Layout`), `Test.gameMenu()`; `client_test.lua` «The game menu's buttons».
- **`ProfessionsFrame` is shown from the client's own `TRADE_SKILL_SHOW`,** which `UIParent` hears before an addon's
  frame. Known: 867878d. Not held by the stand-in.

## Events and data

- **`C_GossipInfo.ForceGossip()` is true for an ordinary vendor:** its one option («I want to browse your goods»,
  `selectOptionWhenOnlyOption` false, `orderIndex` 0) comes with `GOSSIP_SHOW` after
  `PLAYER_INTERACTION_MANAGER_FRAME_SHOW(3)`, and `ForceGossip` says true. Known: the play records of 2026-11-20
  (Stormwind's vendors 1285, 1289). Held by the stand-in (`Test.Npc.forceGossip` true unless a test says).

- **`TRADE_SKILL_LIST_UPDATE` after `TRADE_SKILL_SHOW` may come before the list:** `GetAllRecipeIDs` gives none at
  the first. Known: session 445 (da2daef). Not held by the stand-in.
- **A profession opened while another is open (`OpenTradeSkill`) is shown before its lists come:** at its
  `TRADE_SKILL_SHOW` and the first `TRADE_SKILL_LIST_UPDATE` after it, `GetCategories` and `GetAllRecipeIDs` still
  give the lists of the one that was open; the second update, about 35 ms after the show, brings its own, and a
  third says the same again. Known: session 511. Not held by the stand-in; the game's side leaves the lists unread
  until they are the asked profession's (`professions.luna`, `stale`).
- **What a recipe is doesn't change in a session, and each thing of it that does has its own event:** its name,
  icon and heading never; whether it is known at `NEW_RECIPE_LEARNED` (its id); how likely it is to raise the skill
  with the player's rank (`GetProfessionInfo`); what the bags make of it (`GetCraftableCount`, a number, no table)
  with the bags. A profession's list holds the recipes not known too, so a recipe learned adds none. The game's
  side keeps each of the player's professions once the client has said its list twice running, and asks only what
  the bags make after that (`professions.luna`, `Kept`). Known: session 522.
- **A recipe's `GetRecipeInfo` is answered whatever is open:** straight after a reload with no profession opened,
  and for a recipe of a profession other than the open one (its name and whether it is known; its difficulty and
  what the bags make of it are not confirmed there). `GetAllRecipeIDs` gives the open profession's alone, and
  straight after a reload the list of the one last open. Known: a probe of build 70938. Not held by the stand-in.
- **A full auction scan reads a third of its weapon and armour auctions with no link yet;** the item's data comes
  with `ITEM_DATA_LOAD_RESULT`. Known: ea0652d (337 of the first 1000 read). Not held by the stand-in.
- **`UnitPosition` gives nothing inside an instance** (`client.d.luna` doesn't say so); `IsPlayerMoving` still
  tells. Known: `next-archive:next/runtime.md`. Not held by the stand-in (`UnitPosition` always gives Elwynn's
  place).
- **`C_Map.GetPlayerMapPosition` gives a new table each call** (`Vector2D`). Known: 0f3d2c4. Stand-in:
  `C_Map.GetPlayerMapPosition` (`client.lua`).
- **The letter being written takes items only while the send page shows (`SetSendMailShowing(true)`):** an item
  on the cursor goes in with `ClickSendMailItemButton(place)` or, with no place, into the first empty one (Blizzard's
  `SendMailAttachmentButton_OnDropAny`), and a bag item used (Right-click) goes in too; each change is told with
  `MAIL_SEND_INFO_UPDATE`, and `GetSendMailItem`'s fourth value is the stack's count. Known: Blizzard's
  `MailFrame.lua` of build 70959. Stand-in: `ClickSendMailItemButton`, `UseContainerItem` (`client.lua`). The
  event's timing (at once or a frame later) is not confirmed; `lunatype test` delivers the stand-in's events to no
  `"$events"` listener (a test emits it).
- **`GetMaxPlayerLevel` is 60 and the client still names the last level's experience figure at the cap.** Known:
  2962a90. Stand-in: `GetMaxPlayerLevel`, `IsXPUserDisabled` (`client.lua`). The figure at the cap is not held.

## The API dump

- **A dump taken first of all addons doesn't hold** the names the client makes later in a session (the chat
  settings' `ChatConfig*` and `CombatConfig*` rows, the tooltip's further lines, three number constants set as the
  game runs). Known: `next-archive:next/tools.md` «Blocked».
- **The dump carries no script names** (a frame kind's handlers come from the documented sets) **and lists
  `Enum.TooltipDataLineType` without values.** Known: 9fad87c, `tooltip-data.md`. Stand-in: the scripts each kind
  takes (`client.lua`, `scriptsOf`); `CreateFrame` refuses a kind it doesn't make.
- **Loading `Blizzard_EventTrace` shows its window as it loads.** Known: dev c8ad52f. Not held by the stand-in.

## Not held by the stand-in

- A module listed apart from its group by its `## Category`.
- `/reload` taking new files and folders.
- The four Blizzard addons loaded at login after every addon.
- The saved-variables file read whole at every login.
- An event kept to Blizzard's code answering `ADDON_ACTION_FORBIDDEN` with a dialog.
- A secret compared with `nil`; a secret as a table key; `#` of a kept table.
- A frame of no width or height having no place.
- The cursor kept on the outermost pixel once it left the window.
- A posted modifier never counting.
- An override binding saying the bindings changed.
- The menu button's tooltip filled anew each second.
- `ProfessionsFrame` shown before an addon hears `TRADE_SKILL_SHOW`.
- The first `TRADE_SKILL_LIST_UPDATE` before the list.
- A profession opened over another shown, and updated once, with the other's lists.
- Auctions with no link until `ITEM_DATA_LOAD_RESULT`.
- `UnitPosition` giving nothing in an instance.
- The last level's experience figure at the cap.
- `Blizzard_EventTrace` showing its window as it loads.
