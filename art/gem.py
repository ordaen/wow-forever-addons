"""Build the "new" marker: a small glowing blue gem (the user's pick, 2026-11-07, preview new.html #2).

Usage:
    art/.venv/Scripts/python art/gem.py

Writes addons/OrdaenCore/media/new-gem.tga (32x32, 32-bit; drawn at 16x16 UI units, so ~2 texture px per screen px
on a 1440p screen): an 8x8 square turned 45 degrees, lit from the top-left (#d6f0ff -> #3fa9ff -> #0b4f9e),
a 1-unit #0a2a4d edge and a soft blue glow around it, all in the file.
"""

from pathlib import Path

import numpy as np
from PIL import Image

ART = Path(__file__).resolve().parent
REPO = ART.parent
SIZE, SS = 32, 4
UNIT = SIZE / 16  # texture px per UI unit
HALF = 8 * UNIT * 1.41421 / 2  # an 8x8 square turned 45 degrees (as in the preview): half its diagonal
EDGE = 1 * UNIT


def rgb(h):
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], dtype=float) / 255


LIGHT, MID, DARK, RIM, GLOW = rgb("d6f0ff"), rgb("3fa9ff"), rgb("0b4f9e"), rgb("0a2a4d"), rgb("3fa9ff")


def main():
    n = SIZE * SS
    ys, xs = np.mgrid[0:n, 0:n].astype(float)
    x = (xs + 0.5) / SS - SIZE / 2
    y = (ys + 0.5) / SS - SIZE / 2
    d = np.abs(x) + np.abs(y)  # diamond distance: d = HALF on its outline
    # body: gradient along the top-left to bottom-right diagonal
    t = np.clip((x + y) / (2 * HALF) + 0.5, 0, 1)[..., None]
    body = np.where(t < 0.55, LIGHT + (MID - LIGHT) * (t / 0.55), MID + (DARK - MID) * ((t - 0.55) / 0.45))
    # a small bright facet near the top-left tip
    facet = np.clip(1 - np.hypot(x + HALF * 0.35, y + HALF * 0.35) / (HALF * 0.35), 0, 1)[..., None]
    body = body + (1 - body) * facet * 0.6
    inside = d <= HALF
    rim = (d > HALF - EDGE) & inside
    col = np.where(rim[..., None], RIM, body)
    # glow: fades from the outline out to 5 units
    g = np.clip(1 - (d - HALF) / (5 * UNIT), 0, 1) ** 2 * 0.85
    alpha = np.where(inside, 1.0, g)
    col = np.where(inside[..., None], col, GLOW)
    img = np.dstack([col, alpha])
    img = img.reshape(SIZE, SS, SIZE, SS, 4).mean((1, 3))
    # un-premultiply the averaged colour where alpha was mixed
    out = (np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8)
    path = REPO / "addons" / "OrdaenCore" / "media" / "new-gem.tga"
    Image.fromarray(out, "RGBA").save(path, compression=None)
    prev = Image.new("RGBA", (SIZE * 8, SIZE * 8), (26, 19, 12, 255))
    prev.alpha_composite(Image.fromarray(out, "RGBA").resize((SIZE * 8, SIZE * 8), Image.NEAREST))
    (ART / "out").mkdir(exist_ok=True)
    prev.save(ART / "out" / "new-gem.png")
    print("wrote", path)


if __name__ == "__main__":
    main()
