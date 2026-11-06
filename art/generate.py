"""Generate texture material with a local ComfyUI server (FLUX.1 [schnell]).

Usage:
    art/.venv/Scripts/python art/generate.py art/prompts/<set>.json [--server http://127.0.0.1:8188]

A prompt set is JSON:
    {
      "width": 1024, "height": 1024, "steps": 4,
      "items": [
        {"name": "gold-filigree", "prompt": "...", "seeds": [1, 2, 3]}
      ]
    }

Images land in art/out/<set>/<name>/<seed>.png (gitignored). Keep the prompt set and the
seeds of the picks in git so every shipped texture can be regenerated.

Licence: only FLUX.1 [schnell] (Apache 2.0) or SDXL (OpenRAIL++) outputs may ship, because the
addons are distributed on CurseForge. Never use FLUX.1 [dev].
"""

import argparse
import json
import sys
import time
import urllib.parse
import urllib.request
import uuid
from pathlib import Path

CHECKPOINT = "flux1-schnell-fp8.safetensors"
ART = Path(__file__).resolve().parent


def workflow(prompt, seed, width, height, steps, prefix):
    """ComfyUI API-format graph for FLUX schnell (cfg 1, no negative prompt needed)."""
    return {
        "1": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": CHECKPOINT}},
        "2": {"class_type": "CLIPTextEncode", "inputs": {"text": prompt, "clip": ["1", 1]}},
        "3": {"class_type": "CLIPTextEncode", "inputs": {"text": "", "clip": ["1", 1]}},
        "4": {"class_type": "EmptySD3LatentImage",
              "inputs": {"width": width, "height": height, "batch_size": 1}},
        "5": {"class_type": "KSampler", "inputs": {
            "model": ["1", 0], "positive": ["2", 0], "negative": ["3", 0], "latent_image": ["4", 0],
            "seed": seed, "steps": steps, "cfg": 1.0, "sampler_name": "euler",
            "scheduler": "simple", "denoise": 1.0}},
        "6": {"class_type": "VAEDecode", "inputs": {"samples": ["5", 0], "vae": ["1", 2]}},
        "7": {"class_type": "SaveImage", "inputs": {"images": ["6", 0], "filename_prefix": prefix}},
    }


def call(server, path, data=None):
    req = urllib.request.Request(server + path)
    if data is not None:
        req.data = json.dumps(data).encode()
        req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req) as resp:
        body = resp.read()
    return body if path.startswith("/view") else json.loads(body)


def run(server, client_id, graph, timeout=600):
    prompt_id = call(server, "/prompt", {"prompt": graph, "client_id": client_id})["prompt_id"]
    deadline = time.time() + timeout
    while time.time() < deadline:
        hist = call(server, f"/history/{prompt_id}")
        if prompt_id in hist:
            entry = hist[prompt_id]
            if entry.get("status", {}).get("status_str") == "error":
                raise RuntimeError(json.dumps(entry["status"], indent=2))
            return [img for out in entry["outputs"].values() for img in out.get("images", [])]
        time.sleep(0.5)
    raise TimeoutError(prompt_id)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("promptset", type=Path)
    ap.add_argument("--server", default="http://127.0.0.1:8188")
    ap.add_argument("--only", help="generate only the item with this name")
    args = ap.parse_args()

    spec = json.loads(args.promptset.read_text(encoding="utf-8"))
    set_name = args.promptset.stem
    client_id = str(uuid.uuid4())
    for item in spec["items"]:
        if args.only and item["name"] != args.only:
            continue
        out_dir = ART / "out" / set_name / item["name"]
        out_dir.mkdir(parents=True, exist_ok=True)
        for seed in item["seeds"]:
            target = out_dir / f"{seed}.png"
            if target.exists():
                continue
            t0 = time.time()
            graph = workflow(item["prompt"], seed, item.get("width", spec.get("width", 1024)),
                             item.get("height", spec.get("height", 1024)),
                             spec.get("steps", 4), f"ordaen/{set_name}-{item['name']}-{seed}")
            for img in run(args.server, client_id, graph):
                query = urllib.parse.urlencode(
                    {"filename": img["filename"], "subfolder": img["subfolder"], "type": img["type"]})
                target.write_bytes(call(args.server, "/view?" + query))
            print(f"{target.relative_to(ART)}  {time.time() - t0:.1f}s", flush=True)


if __name__ == "__main__":
    sys.exit(main())
