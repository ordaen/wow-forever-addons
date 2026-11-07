"""Build the mitre masks: a window's top corners drawn from Blizzard's own edge art, joined on the diagonal.

Usage:
    art/.venv/Scripts/python art/mitre.py

Lit from the top-left, a top-left corner needs both rims bright on the outside, and no Blizzard corner piece has
that. So the renderer draws each top corner as two textures over the same square (as wide and high as the rim):
the side edge (LeftEdge / RightEdge) and the turned top edge, each through one of these masks, so they meet on the
diagonal like a mitred frame. Blizzard's art at any scale, nothing re-drawn. 64x64, white, the mask in the alpha
(anti-aliased diagonal):

    mitre-tl-side.tga  top-left corner, the left rim: below the diagonal from the top-left (y > x)
    mitre-tl-top.tga   top-left corner, the top rim: the rest
    mitre-tr-side.tga  top-right corner, the right rim: below the diagonal from the top-right
    mitre-tr-top.tga   top-right corner, the top rim: the rest
"""

from pathlib import Path

import numpy as np
from PIL import Image

REPO = Path(__file__).resolve().parent.parent
N, SS = 64, 8


def save(alpha, name):
    a = alpha.reshape(N, SS, N, SS).mean((1, 3))
    img = np.dstack([np.ones((N, N, 3)), a])
    out = (np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8)
    path = REPO / "addons" / "OrdaenCore" / "media" / name
    Image.fromarray(out, "RGBA").save(path, compression=None)
    print("wrote", path)


def main():
    ys, xs = np.mgrid[0:N * SS, 0:N * SS].astype(float)
    x, y = (xs + 0.5) / SS, (ys + 0.5) / SS
    tl_side = (y > x).astype(float)
    tr_side = (y > N - x).astype(float)
    save(tl_side, "mitre-tl-side.tga")
    save(1 - tl_side, "mitre-tl-top.tga")
    save(tr_side, "mitre-tr-side.tga")
    save(1 - tr_side, "mitre-tr-top.tga")


if __name__ == "__main__":
    main()
