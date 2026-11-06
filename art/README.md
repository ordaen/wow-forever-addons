# art

Source for the addons' texture art. Not packaged (it's outside `addons/`).

## Pipeline

1. **Material**: `generate.py` sends prompt sets (`prompts/*.json`) to a local ComfyUI server running
   FLUX.1 [schnell]. Images land in `out/` (gitignored).
2. **Frame**: Pillow scripts cut the picked material into exact frames (corners + edges, alpha, inner shadow)
   and write power-of-two 32-bit `.tga` files into `addons/<Addon>/media/`.

Commit the prompt set, the picked seeds and the build script, so every shipped texture can be regenerated.

## Licence

The addons ship on CurseForge (which pays authors), so only use outputs of **FLUX.1 [schnell]** (Apache 2.0)
or **SDXL** (CreativeML OpenRAIL++-M). Never FLUX.1 [dev] (non-commercial). Keep prompts generic; never ask
for a copy of Blizzard or other existing art.

## Setup (Windows)

- ComfyUI portable (NVIDIA build) in `C:\Users\f3oal\ComfyUI\ComfyUI_windows_portable\`, with
  `flux1-schnell-fp8.safetensors` (from `Comfy-Org/flux1-schnell` on Hugging Face) in `ComfyUI\models\checkpoints\`.
  Start it with `run_nvidia_gpu.bat`; it serves http://127.0.0.1:8188.
- Python tools: `py -3 -m venv art/.venv` then `art/.venv/Scripts/python -m pip install -r art/requirements.txt`.

```sh
art/.venv/Scripts/python art/generate.py art/prompts/materials-01.json
```

## WoW texture rules

32-bit `.tga` with alpha (or `.blp`), power-of-two sides (256x256, 512x64, ...), referenced as
`Interface\AddOns\<Addon>\media\<name>` without the extension. A new texture file needs a full client restart.
