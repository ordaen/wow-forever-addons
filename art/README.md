# art

How every texture the addons ship came to be, and what makes it again. Not packaged (it is outside `addons/`).
The commands are `lunatype art ...` (in `../lunatype`; `lunatype art` lists them); the skill `art` is the procedure.

| Folder | Holds |
|---|---|
| `pieces/<name>.json` | a piece: the files of `addons/` it is, how it came to be, and the steps that make it again |
| `sets/<name>.json` | candidates to pick from: a ComfyUI workflow, prompts and the seeds to try |
| `workflows/<name>.json` | a ComfyUI workflow in its API format |
| `sources/` | the pictures the steps and the sets start from, each at most 1 MiB, in git |
| `out/` | what generating and the steps between make (ignored) |

`lunatype art check ..` (in the suite, `zig build test` in `../lunatype`) holds every picture under `addons/` to a
piece and to the client's rules, makes every piece with steps again in memory and compares it with what it ships (a
TGA to the byte, a PNG to the pixel), and refuses a source no step or set starts from, or one over 1 MiB.

## A piece

```json
{
  "says": "What it is and where it is drawn (the theme value or addon that names it).",
  "ships": ["addons/OrdaenPanel/assets/micro-questlog.tga"],
  "origin": "Who or what made it, from what. What isn't known is said, never guessed.",
  "steps": [
    { "generate": { "workflow": "flux-schnell", "set": { "2.text": "...", "5.seed": 53 }, "out": "art/sources/x.png" } },
    { "key": { "in": "art/sources/x.png", "out": "art/out/x-keyed.png", "size": 256 } },
    { "fit": { "in": "art/out/x-keyed.png", "out": "addons/OrdaenPanel/assets/micro-questlog.tga", "size": 256, "target": 0.72, "cap": 0.92 } }
  ]
}
```

Paths are from the repository's root. A step reads files of the repository or what an earlier step wrote, and
writes its `out` as PNG or as the client's TGA by the extension. `steps` is left out when the piece can't be made
again; `origin` then says why and the shipped file is the source.

| Step | Does |
|---|---|
| `generate` | runs `workflows/<workflow>.json` on ComfyUI with the inputs `set` names (`<node id>.<input>`), the pictures `upload` names sent to its inputs; its `out` is kept in `sources/` and is generated only when missing |
| `key` | a picture on pure black keyed out (alpha from the brightest channel, `lo` 18 clear to `hi` 60 opaque, colours divided back), trimmed to its subject, squared and scaled to `size` |
| `matte` | `width` x `height` of two shots of a page, on `black` and on `white`: alpha from their difference |
| `fit` | an icon's glyph scaled to its set's optical size (`target` of the canvas, its longest side at most `cap`, times `scale`), centred on a clear `size` square |
| `convert` | a picture as PNG or TGA |

## A set

```json
{
  "says": "What is being tried, and which candidates were picked (the piece that ships them).",
  "workflow": "flux-schnell",
  "seed": "5.seed",
  "set": { "4.width": 512, "4.height": 512, "5.steps": 4 },
  "items": [{ "name": "painted-quests", "set": { "2.text": "..." }, "seeds": [51, 52, 53] }]
}
```

`lunatype art generate .. <set>` writes `out/<set>/<item>/<seed>.png`, `lunatype art sheet out/<set>` puts them
side by side. A workflow that draws nothing at random (an upscale) names no `seed`, and each item runs once.

## The client's rules

A texture is a TGA (24 or 32 bits, uncompressed or run-length) or a BLP2, each side a power of two (256 x 256,
512 x 64, ...), in an addon's own folder, named without its extension (`$asset("@/media/x.tga")` in LunaType). A new
file loads on `/reload`.

## ComfyUI

ComfyUI portable (NVIDIA) in `C:\Users\f3oal\ComfyUI\ComfyUI_windows_portable\`, started with
`run_nvidia_gpu.bat`; it serves http://127.0.0.1:8188. Its models: `models/checkpoints/flux1-schnell-fp8.safetensors`
(from `Comfy-Org/flux1-schnell`), `models/upscale_models/RealESRGAN_x4plus.pth` and
`RealESRGAN_x4plus_anime_6B.pth` (from `xinntao/Real-ESRGAN`'s releases). Every picture ComfyUI saves holds the
workflow that made it: `lunatype art workflow <picture> workflows/<name>.json` keeps it (then blank its prompt,
seed and input picture, which a set or a step gives).

## Licence

The addons ship on CurseForge (which pays authors), so only outputs of **FLUX.1 [schnell]** (Apache 2.0), **SDXL**
(CreativeML OpenRAIL++-M) and **Real-ESRGAN** (BSD-3) may ship. Never FLUX.1 [dev] (non-commercial). Prompts stay
generic; never ask for a copy of Blizzard's or anyone's art.
