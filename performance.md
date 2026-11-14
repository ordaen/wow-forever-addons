# Performance: what we measured

What WoW Forever and our code cost, measured in game. Read it before choosing an approach; add to it when a probe or a
bench round settles a question. Each fact gives its number and how it was measured, so it can be measured again.

## How these were measured

- **Client:** WoW Forever 1.60.1, build 70862, ruRU.
- **Machine and settings:** RTX 5080, 32 logical cores; 1280×720, lowest graphics preset, uncapped frame rate, vsync
  off. At these settings frames are CPU-bound (see [CPU or GPU](#cpu-or-gpu)). Idle frame: about 1.8 ms.
- **Code:** the bench build profile (`ordaen watch --profile bench`: stripped like release, `*.dev.lua` kept),
  OrdaenCore_Debug disabled.
- **Probes:** `addons/OrdaenBench/bench/probes.lua`, run with `/obench probes`. Plain WoW calls, no framework.
  Each variant works on 1000 objects made beforehand; a series is 60 calls, 5 of them warm-up and not counted; the
  collector is stopped around each timed call. Results are kept only in `OrdaenBenchDB.probes`, never in the bench
  report.
- **Numbers:** median Lua time per call in ms (debugprofilestop around the call). "Frame" is the median time from one
  frame to the next, which also holds the work WoW defers to drawing.

## WoW calls, per 1000 objects

### Text measuring

1000 font strings, 36 wide, each given a new number of varying width.

| Variant | Lua ms | Frame ms |
| --- | ---: | ---: |
| `SetFormattedText` only | 0.48 | 3.90 |
| + `SetWidth(0)`, `GetStringWidth`, `GetStringHeight`, `SetWidth(36)` | 1.41 | 4.88 |
| + `GetUnboundedStringWidth` | 0.81 | 4.28 |
| + `GetUnboundedStringWidth` + `GetLineHeight` | 0.98 | 4.47 |
| + `GetStringHeight` only | 1.20 | 4.66 |

- Reading a text's size forces WoW to lay it out at once; the frame column shows that work is not paid twice later.
- `GetUnboundedStringWidth` is the cheapest way to get a one-line width: one call, and the font string's width stays
  as it is.
- Changing a font string's width to measure it and back (`SetWidth(0)` … `SetWidth(w)`) almost triples the cost of
  setting the text.

### Fonts

| 1000 font strings | Make, Lua ms | One text change each, Lua ms |
| --- | ---: | ---: |
| `SetFont(STANDARD_TEXT_FONT, 12, "")` per string | 2.16 | 0.43 |
| `SetFontObject` of one `CreateFont` object (as template) | 1.73 | 0.43 |

A shared font object makes creation about 20% cheaper; text changes cost the same. Lua memory is the same (149 KB
for 1000 font strings either way).

### Moving frames between parents

1000 Buttons moved between two parent frames per call.

| Calls per frame | Lua ms |
| --- | ---: |
| `SetParent` | 0.24 |
| + `SetFrameLevel(parent + 1)` | 0.52 |
| + `ClearAllPoints` + `SetPoint` | 1.39 |
| + `Show` | 1.55 |
| `SetUsingParentLevel(true)` set once at creation, then `SetParent` | 0.24 |

- `ClearAllPoints` plus `SetPoint` is the most expensive part. A frame with one anchor point gets it replaced by
  `SetPoint` with the same point name, so `ClearAllPoints` isn't needed.
- With `SetUsingParentLevel(true)` the frame level follows the parent at no cost.

### Frame levels

`SetFrameLevel` 1000 times on a parent with 0, 10 and 100 children: 0.15, 0.18 and 0.43 ms. It costs more with more
children, but little per child.

### Hiding and showing

A parent frame with 1000 child frames, each with a texture.

| | Lua ms |
| --- | ---: |
| `Hide` each child | 0.23 |
| `Show` each child | 0.24 |
| `Hide` the parent | 0.07 |
| `Show` the parent | 0.07 |

Hiding is cheap either way: 1000 calls cost a quarter of a millisecond. Hiding the parent is cheapest.

### Frame types

Making 1000 frames, Lua ms: `Frame` 3.29, `Frame` with `EnableMouse(true)` 3.62, `Button` 3.64, `Button` with
`EnableMouse(true)` 3.50. Lua memory: 125 KB per 1000 in every case. A Button costs about the same as a Frame;
enabling the mouse costs nothing at creation.

### Draw layers

1000 ARTWORK textures, one per frame: `Hide`/`Show` each texture 0.19 ms, `SetDrawLayerEnabled` on each frame
0.18 ms. No difference.

## Pixels

- At 1280×720 with a UI scale of 1, UIParent is 768 units tall: one screen pixel is 768 / 720 ≈ 1.067 UI units.
- The bench font (`STANDARD_TEXT_FONT`, 12) has a string height and line height of 11.733 units: exactly 11 px.
- Sizes that aren't whole pixels draw unevenly once snapped. Lines 12 units apart (11.25 px) land 11 and 12 px apart
  in turn; a 1-unit gap after an 11.733-unit line does the same. Text sizes therefore round up to whole pixels
  (`ceil(v / px - 0.001) * px`) and sizes, gaps and padding round to the nearest whole pixel
  (`floor(v / px + 0.5) * px`), so equal steps stay equal on screen.
- Equal `fr` columns sharing a width that isn't a multiple of their count differ by 1 px; that can't be avoided on
  whole pixels.

## CPU or GPU

- A frame takes as long as the slower of the CPU's work and the GPU's: WoW renders with frames in flight, so light CPU
  work hides behind a busy GPU.
- At 2560×1440 the GPU was partly the limit (about 444 fps, the GPU at 85–90% at times). Lowering to 1920×1080 raised
  the frame rate to about 500–540 fps; 1280×720 halved the GPU load again without raising it. From 1080p down, the
  CPU sets the frame rate.
- The CPU limit is one thread: WoW's main thread (game logic, all Lua, UI layout) ran at about 80% of one core
  while the whole CPU showed about 20%. Every millisecond of addon Lua lands in that thread's frame.
- `C_AddOnProfiler`'s application metric follows the wall-clock frame time (2.25 ms at a 2.27 ms frame), so it is not
  a measure of CPU work.

## Lua tables

- A backend node is a hash table of about 45 fields: 64 hash slots, about 2.5 KB, before its attribute copy and small
  tables (`table.getcountinfo` on a node after a grid make).
- Arrays reused from a pool keep the size of their largest use: a grid box's row arrays held 560 entries while it
  used 20.
- The heap can shrink without a collection: a table resized smaller on a rehash frees memory at once. With the
  collector stopped, closing the large signals scenario shrank the heap by 224 KB per call.
- `table.freeze(t)` (a Blizzard addition to Lua 5.1, in the API dump) freezes `t` in place and returns the same table;
  `table.isfrozen(t)` is then true. A write to a frozen table raises an error, through `rawset` too; reads and `pairs`
  work as before. Checked in game with
  `/run local t={a=1}; local f=table.freeze(t); print(f==t, table.isfrozen(t), pcall(function() t.b=2 end), pcall(rawset,t,"c",3), t.a)`,
  which prints `true true false false 1`. So a table the build freezes can't be changed by mistake without failing
  loudly, and code may cache what it derives from it.

## Garbage collector

- `collectgarbage("stop")` holds only until WoW's next collection step: the client steps the collector between frames
  (5.1's `lua_gc(L, LUA_GCSTEP, …)` resets the threshold `stop` raised), which turns it back on. Stopped once for a
  whole series, opening the large signals scenario took 33.0 ms and added 245 KB per call: about 12 MB of earlier
  garbage was collected inside each timed call. Stopped right before every call, the same open takes 18.8 ms and
  adds 12,511 KB. To keep collection out of a measurement, stop the collector right before the measured code.
- That step also means a frame's time can hold collection work no addon code asked for. In bench round 7, three
  series had a step in 1 to 3 of their 15 measured frames, all closes of large scenarios (the report marks them ᵍ).

## Comparing what two sides draw

The bench checks that the framework and hand-written code end on the same screen
(`addons/OrdaenBench/bench/screen.lua`): every visible text with its glyph position, and textures' rects.

- The framework puts every rect on whole pixels and rounds centring offsets; hand code keeps fractions. Each is up
  to a pixel from the exact position, and positions are read relative to a first text that carries its own pixel,
  so the same element can sit up to 2 px apart on two correct sides. The check allows exactly 2 px; more is a
  difference.
- Within that allowance a list can still step unevenly (lines 11 and 12 px apart in turn), so lists get their own
  check: in a one-column list, consecutive line distances may differ by at most 0.1 unit.
- Both sides space lines by the font's height rounded up to a whole pixel (11.733 units for the bench font) and size
  boxes, gaps and padding on whole pixels (`addons/OrdaenBench/bench/line.lua`, `bench/px.lua`).

## Framework against hand-written code

Bench round 7 (Core 8332ac6), Lua ms per call; the bench report (`bench/README.md`, the design site's Bench page)
has every row. "By hand" is the hand-written best (`addons/OrdaenBench/baseline/`); "typical" is how an addon
usually writes it.

| | Framework | Engine | Backend | By hand | Typical |
| --- | ---: | ---: | ---: | ---: | ---: |
| Large grid (1000 cells), first open | 68.8 | | | 5.7 | 7.7 |
| Large grid, open with warm pools | 43.1 | 15.4 | 27.7 | | |
| Large grid, close | 16.6 | 4.2 | 12.5 | 0.05 (hide) | 0.09 (hide) |
| Large grid, every cell changed | 19.0 | 11.5 | 7.5 | 0.40 | 1.81 |
| Large grid, one cell changed | 1.84 | 1.80 | 0.03 | <0.01 | 0.01 |
| 500 writes to 10,000 values | 3.80 | | | 0.28 | 0.35 |
| 1000 writes to one value, one frame | 10.8 | | | 0.014 | 10.2 |
| One value read by 5000 watches, changed | 19.6 | | | 0.22 | |
| Window moved | 0.30 | 0.28 | 0.03 | <0.01 | |
| Tooltip shown with new content | 0.26 | 0.04 | 0.22 | 0.07 | |
| Hovered item changed (100 cells) | 0.23 | | | 0.02 | |

- A component call that changes nothing is the engine's largest unit cost: one changed cell of 1000 costs 1.8 ms,
  nearly all of it the 999 unchanged calls.
- Memory: the first open of the large grid keeps 18.8 MB of Lua heap, engine and backend together (the split of a
  first open isn't measured yet: the bench's engine-only first open records it from the next round); the
  hand-written grid keeps 3.3 MB, the typical one 0.4 MB. A warm open adds 6.3 MB per open, all of it the engine's
  (the stub backend adds the same).
- A grid on screen with nothing changing adds nothing measurable to the main thread's frame at CPU-bound settings, on
  either side. WoW also draws on worker threads, whose slack hides work, so this doesn't mean drawing is free; for
  what an addon costs players' frames, the main thread is the measure.

## How a changed value reaches the screen

`scripts/vapor.lua` (offline, the fake client, Lua VM instructions; Core 1ac7d2a): a grid of 1000 texts, each
showing one value, drawn three ways. Every way ends with every text right.

| | Mount | Kept per text | All 1000 changed, per text | One changed | 1000 equal writes |
| --- | ---: | ---: | ---: | ---: | ---: |
| A component per text, its render re-run | 7.81 M | 7.0 KB | 3054 | 571 k | 21 k |
| A binding object per text (shared expression) | 6.63 M | 5.1 KB | 2265 | 571 k | 21 k |
| A binding holding a closure per text | 6.61 M | 4.9 KB | 2267 | 571 k | 21 k |

- A binding writes its field without re-running a render: a quarter fewer instructions per change and 2 KB less
  per text (no instance, effect or fragment per text).
- Object or closure costs the same time; the closure's lower memory here is the prototype's object carrying three
  fields a shared metatable would hold. Bindings are objects (one metatable), as the code style asks.
- One changed text costs the same three ways: the backend lays the whole grid out again (the text's width can
  change), about 570 instructions per text in the grid. That is the backend's share to cut, not the engine's.

## An auction house's full scan

The companion's records of a game session (2026-11-14, Ordaen Auction, a dev build; `wow_records`, the client
domain's cassette and the per-minute tap counts) on a house of 159,582 auctions.

| | Before | After |
| --- | ---: | ---: |
| Auctions read a frame | 500, fixed | as many as 4 ms take, asked every 50 |
| LunaType's longest frame while reading | 21.7 ms (about 43 µs an auction) | 4 ms and at most one check's 50 more |
| Auctions of weapons and armour whose item's data hadn't loaded | dropped: 337 of the first 1000 read had no link | asked for (`RequestLoadItemDataByID`, 3,917 items) and read again as each comes, 10 s at most |
| Items counted at the end | about 5,000 | every key the answer gives |
| Setting the prices | one frame for every item, a table and a sort's closure for each | spread over frames under the same 4 ms; no table for an item listed once, one comparator |

- The client's own calls for one scan: `GetReplicateItemInfo` 1,153 ms of client time over 159,582 calls,
  `GetItemInfoInstant` 327 ms, `GetReplicateItemLink` 177 ms over 55,246 calls. They are the floor: a full scan's
  reading is 8 to 9 seconds of 4 ms frames.
- The ten seconds between the click and the first `REPLICATE_ITEM_LIST_UPDATE` are the server's; the status line
  says it waits.
- At rest the house is one deflated string: 10,000 keys with their market and listing 143 KB; with one point of
  history each 213 KB; a key's full history (24 hours and 29 days) about 160 bytes more, 2,000 such keys 317 KB. A
  house keeps a history for 8,000 keys at most.
- The longest frame after is the budget by construction (`clock.test.luna`, a clock that moves with the auctions
  read); it isn't measured in the game yet.
