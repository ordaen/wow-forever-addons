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
