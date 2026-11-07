"""Build the dropdown arrow: a small gold downward triangle for our dropdown (a2's Bags v2 design, 2026-11-07).

Usage:
    art/.venv/Scripts/python art/arrow.py

Writes addons/OrdaenCore/media/dropdown-arrow.tga: 32x32, 32-bit, meant to be drawn at 16x16 UI units (2 texture
px per unit). The triangle is 10x7 units (20x14 px), centred: x 6..26, y 9..23 of the file, its shadow 1 unit down
and to the right (light from the top-left, like every other piece). Gold #f0c860, a touch lighter on its upper
edge, a 1 px dark rim.
"""

from pathlib import Path

import numpy as np
from PIL import Image

ART = Path(__file__).resolve().parent
REPO = ART.parent
SIZE, SS = 32, 8


def rgb(h):
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], dtype=float) / 255


GOLD, LIGHT, RIM, SHADOW = rgb("f0c860"), rgb("fff0b0"), rgb("5a3d10"), np.zeros(3)


def triangle(x, y, x0, y0, w, h):
    """Signed distance-ish inside a downward triangle with top edge (x0..x0+w, y0) and tip (x0+w/2, y0+h)."""
    cx = x0 + w / 2
    # inside if below the top edge and within the two slanted sides
    top = y - y0
    k = (w / 2) / h
    side = (h - (y - y0)) * k - np.abs(x - cx)  # horizontal room left at this height
    side = side / np.hypot(1, k)  # distance to the slanted side
    return np.minimum(top, side)


def main():
    n = SIZE * SS
    ys, xs = np.mgrid[0:n, 0:n].astype(float)
    x, y = (xs + 0.5) / SS, (ys + 0.5) / SS
    x0, y0, w, h = 6.0, 9.0, 20.0, 14.0
    d = triangle(x, y, x0, y0, w, h)
    ds = triangle(x, y, x0 + 2, y0 + 2, w, h)  # shadow, 1 UI unit down-right
    t = np.clip((y - y0) / h, 0, 1)[..., None]
    body = LIGHT + (GOLD - LIGHT) * np.clip(t * 3, 0, 1)  # the upper edge catches the light
    col = np.where((d < 2)[..., None], RIM, body)  # a 1 px (2 texture px) dark rim
    a_body = np.clip(d * SS / SS + 0.5, 0, 1)
    a_shadow = np.clip(ds + 0.5, 0, 1) * 0.75
    alpha = np.maximum(a_body, a_shadow * (1 - a_body))
    col = np.where((a_body > 0)[..., None], col, SHADOW)
    img = np.dstack([col * a_body[..., None] + SHADOW * (a_shadow * (1 - a_body))[..., None], alpha])
    img = img.reshape(SIZE, SS, SIZE, SS, 4).mean((1, 3))
    al = img[..., 3:]
    rgbp = np.where(al > 0, img[..., :3] / np.maximum(al, 1e-6), 0)
    out = (np.clip(np.dstack([rgbp, al]), 0, 1) * 255 + 0.5).astype(np.uint8)
    path = REPO / "addons" / "OrdaenCore" / "media" / "dropdown-arrow.tga"
    Image.fromarray(out, "RGBA").save(path, compression=None)
    prev = Image.new("RGBA", (SIZE * 8, SIZE * 8), (40, 30, 20, 255))
    prev.alpha_composite(Image.fromarray(out, "RGBA").resize((SIZE * 8, SIZE * 8), Image.NEAREST))
    (ART / "out").mkdir(exist_ok=True)
    prev.save(ART / "out" / "dropdown-arrow.png")
    print("wrote", path)


if __name__ == "__main__":
    main()
