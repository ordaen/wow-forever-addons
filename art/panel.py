"""Build the bottom panel's art (the user's design, approved 2026-11-07 in the browser preview /preview/panel/).

Usage:
    art/.venv/Scripts/python art/panel.py

Everything lit from the top-left, like the buttons, the window borders and the text shadows. Writes to
addons/OrdaenCore/media/:

- panel-cell.tga (256x256): the panel's cells, our push button's side rims only (its plate is cut out, so the wood
  shows through and the icons rest on it). Rows of 64: 0 normal, 1 hover (the button's highlight glow alone: drawn
  over row 0 on the HIGHLIGHT layer), 2 pushed, 3 empty. Sliced like the button: caps x 0-32 and 224-256 (aspect 0.5), centre 32-224; vertically uniform,
  so a cell of any height stretches it.
- portrait-ring.tga (256x256): the round metal ring around the character's portrait (drawn at 152 UI units at 1440p):
  outer radius 126, inner 104 (the portrait fills the inner circle), and portrait-shadow.tga (256x256), its soft
  shadow, drawn offset down-right under it.
- level-badge.tga (64x64): the small round plate for the level, a bronze rim around a dark disc (drawn at 36).
- xp-tube.tga (256x64): the glass tube's bronze setting and dark trough, sliced like a button: caps x 0-64 and
  192-256 (aspect 1: a cap is as wide as the tube is high), centre 64-192. The trough (where the fill goes) is
  inset 10 px from the top and bottom of the file (16% of its height) and from the outer ends of the caps.
- xp-tube-shine.tga (256x64): the glass's highlight, same slicing, drawn over the fill.
- xp-fill-<name>.tga (256x32 each, tiling horizontally): the six fills the player chooses from; deep blue, darker to
  sit with the brown wood. deep (plain), grain, brushed (the default), potion (small bubbles), clouds, steel (muted,
  grain; with it the shine is warmed amber).
"""

from pathlib import Path

import numpy as np
from PIL import Image

ART = Path(__file__).resolve().parent
REPO = ART.parent
MEDIA = REPO / "addons" / "OrdaenCore" / "media"
SS = 4


def rgb(h):
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], dtype=float) / 255


def lerp(a, b, t):
    return a + (b - a) * np.asarray(t)[..., None]


def save(arr, name):
    out = (np.clip(arr, 0, 1) * 255 + 0.5).astype(np.uint8)
    Image.fromarray(out, "RGBA").save(MEDIA / name, compression=None)
    print("wrote", MEDIA / name)


def down(pre, w, h):
    """Box-filter a premultiplied supersampled RGBA array down to w x h, un-premultiplied."""
    p = pre.reshape(h, SS, w, SS, 4).mean((1, 3))
    a = p[..., 3:]
    return np.dstack([np.where(a > 0, p[..., :3] / np.maximum(a, 1e-6), 0), a])


# bronze (art/frame.py's bronze-rim, measured from the minimap ring), at the buttons' softer contrast
OUTL, LITO, DARKO = rgb("0c0e09"), rgb("8e7655"), rgb("36230f")
RIDGE_L, RIDGE_D = rgb("d6a56b"), rgb("8f7a55")
LITI, DARKI, LIP = rgb("947350"), rgb("3e281b"), rgb("1a1306")
MID = (LITO + DARKO) / 2


def soften(col, c):
    return MID + (col - MID) * c


# ---- cells: the button's side rims only ------------------------------------------------------------------------
def cells():
    bt = np.array(Image.open(MEDIA / "button.tga").convert("RGBA")).astype(float) / 255
    out = np.zeros((256, 256, 4))

    def band(r):
        return bt[r * 64 + 24:r * 64 + 40]  # the plate's middle: side rims and the engraved line's sides only

    def rims(b, inside=0.0):
        b = b.copy()
        b[:, 16:240, 3] *= inside
        return b

    def stretch(b):
        return np.repeat(b, 4, axis=0)  # 16 rows -> 64 (vertically uniform anyway)

    normal = rims(band(0))
    hover = band(3)  # the glow alone: the renderer draws highlight over the normal row (rims would double)
    pushed = rims(band(1), 0.35)
    out[0:64], out[64:128], out[128:192] = stretch(normal), stretch(hover), stretch(pushed)
    save(out, "panel-cell.tga")


# ---- the portrait's ring, its shadow, the level badge -----------------------------------------------------------
def ring(size, r_out, r_in, profile, c=0.9):
    n = size * SS
    ys, xs = np.mgrid[0:n, 0:n].astype(float)
    x, y = (xs + 0.5) / SS - size / 2, (ys + 0.5) / SS - size / 2
    dist = np.hypot(x, y)
    d = r_out - dist
    nx, ny = x / np.maximum(dist, 1e-6), y / np.maximum(dist, 1e-6)
    k = np.clip(0.5 + (nx * -0.7071 + ny * -0.7071) * 0.75, 0, 1)  # the outer slope facing the light
    o, a, rw, iw = profile
    outer, inner, ridge = lerp(DARKO, LITO, k), lerp(LITI, DARKI, k), lerp(RIDGE_D, RIDGE_L, k)
    col = np.select([(d < o)[..., None], (d < o + a)[..., None], (d < o + a + rw)[..., None],
                     (d < o + a + rw + iw)[..., None]], [OUTL + 0 * outer, outer, ridge, inner], LIP + 0 * outer)
    col = soften(col, c)
    alpha = np.clip(d + 0.5, 0, 1) * np.clip((dist - r_in) + 0.5, 0, 1)
    return down(np.dstack([col * alpha[..., None], alpha]), size, size), dist


def portrait():
    k = 256 / 152
    arr, _ = ring(256, 75 * k, 62 * k, (1.6 * k, 4.4 * k, 1.8 * k, 4.0 * k))
    save(arr, "portrait-ring.tga")
    n = 256 * SS
    ys, xs = np.mgrid[0:n, 0:n].astype(float)
    dist = np.hypot((xs + 0.5) / SS - 128, (ys + 0.5) / SS - 128)
    a = np.clip((122 - dist) / 14, 0, 1) ** 1.5 * 0.65  # soft-edged disc; the renderer offsets it down-right
    save(down(np.dstack([np.zeros((n, n, 3)), a]), 256, 256), "portrait-shadow.tga")
    # level badge: a dark disc in a thin bronze rim
    badge, dist = ring(64, 31, 0, (1.5, 2.6, 1.0, 1.6), c=0.9)
    disc = np.clip(31 - 6.7 - dist + 0.5, 0, 1)
    n = 64 * SS
    ys, xs = np.mgrid[0:n, 0:n].astype(float)
    t = np.clip(((xs / SS - 20) ** 2 + (ys / SS - 18) ** 2) ** 0.5 / 40, 0, 1)[..., None]
    fill = lerp(rgb("2c2117"), rgb("120c07"), t[..., 0])
    fpre = np.dstack([fill * disc[..., None], disc])
    fill_img = down(fpre, 64, 64)
    a1, a2 = badge[..., 3:], fill_img[..., 3:]
    col = (fill_img[..., :3] * a2 * (1 - a1) + badge[..., :3] * a1)
    al = a1 + a2 * (1 - a1)
    save(np.dstack([np.where(al > 0, col / np.maximum(al, 1e-6), 0), al]), "level-badge.tga")


# ---- the glass tube: setting, shine and fills --------------------------------------------------------------------
TW, TH = 256, 64
INSET = 10  # the trough's inset from the file's top and bottom (and the caps' outer ends)


def capsule(w, h, x, y, r):
    """Signed depth inside a horizontal capsule (rounded ends) of w x h at 0,0, for points x, y."""
    cx = np.clip(x, r, w - r)
    return r - np.hypot(x - cx, y - h / 2)


def tube():
    n_w, n_h = TW * SS, TH * SS
    ys, xs = np.mgrid[0:n_h, 0:n_w].astype(float)
    x, y = (xs + 0.5) / SS, (ys + 0.5) / SS
    # the file's 256 columns hold: cap (0-64), centre (64-192), cap (192-256); drawn as one capsule 256 wide whose
    # centre slice is uniform, so stretching it keeps the shape
    d = capsule(TW, TH, x, y, TH / 2)
    # light from the top-left: on a capsule the normal is the direction from its axis
    cx = np.clip(x, TH / 2, TW - TH / 2)
    nx, ny = x - cx, y - TH / 2
    nn = np.maximum(np.hypot(nx, ny), 1e-6)
    k = np.clip(0.5 + (nx / nn * -0.7071 + ny / nn * -0.7071) * 0.75, 0, 1)
    o, a, rw, iw = 2.2, 3.6, 1.6, 2.6  # the bronze setting, from the outside in (texture px)
    outer, inner, ridge = lerp(DARKO, LITO, k), lerp(LITI, DARKI, k), lerp(RIDGE_D, RIDGE_L, k)
    edge = o + a + rw + iw
    trough_t = np.clip((y - INSET) / (TH - 2 * INSET), 0, 1)
    trough = lerp(rgb("030201"), rgb("0d0906"), trough_t)
    # the trough's inner shadow under its top-left lip
    trough = trough * (1 - 0.5 * np.clip(1 - (d - edge) / 6, 0, 1))[..., None]
    col = np.select([(d < o)[..., None], (d < o + a)[..., None], (d < o + a + rw)[..., None], (d < edge)[..., None]],
                    [OUTL + 0 * outer, outer, ridge, inner], trough)
    col = soften(col, 0.9)
    alpha = np.clip(d + 0.5, 0, 1)
    arr = down(np.dstack([col * alpha[..., None], alpha]), TW, TH)
    save(arr, "xp-tube.tga")
    # the shine: a soft white band across the upper part of the trough, rounded with it
    inner_d = d - edge
    band = np.clip(1 - np.abs(y - (INSET + 7)) / 4.5, 0, 1) * np.clip(inner_d / 3, 0, 1) * np.clip((x - 12) / 6, 0, 1) \
        * np.clip((TW - 12 - x) / 6, 0, 1)
    shine = np.dstack([np.ones((n_h, n_w, 3)), band * 0.32])
    save(down(np.dstack([shine[..., :3] * shine[..., 3:], shine[..., 3:]]), TW, TH), "xp-tube-shine.tga")


def periodic_noise(h, w, scale_x, scale_y, seed):
    """Noise that wraps around horizontally (and vertically): white noise filtered in the frequency domain."""
    rng = np.random.default_rng(seed)
    f = np.fft.fft2(rng.normal(size=(h, w)))
    fy = np.fft.fftfreq(h)[:, None]
    fx = np.fft.fftfreq(w)[None, :]
    f *= np.exp(-((fx * scale_x) ** 2 + (fy * scale_y) ** 2))
    n = np.real(np.fft.ifft2(f))
    return (n - n.mean()) / (n.std() + 1e-9)


def fills():
    w, h = 256, 32
    y = (np.arange(h) + 0.5) / h
    deep = np.stack([np.interp(y, [0, .45, .8, 1], [c0, c1, c2, c3]) for c0, c1, c2, c3 in
                     zip(rgb("3a6db4"), rgb("1d4a8e"), rgb("0f2c5c"), rgb("0a1f44"))], -1)[:, None, :]
    steel = np.stack([np.interp(y, [0, .45, .8, 1], [c0, c1, c2, c3]) for c0, c1, c2, c3 in
                      zip(rgb("5677a3"), rgb("34557f"), rgb("1e3656"), rgb("162840"))], -1)[:, None, :]
    base = np.repeat(deep, w, axis=1)
    grain = periodic_noise(h, w, 2.0, 2.0, 1)[..., None]
    brush = periodic_noise(h, w, 50.0, 1.6, 2)[..., None]  # long along the tube, fine across it
    clouds = periodic_noise(h, w, 30.0, 8.0, 3)[..., None]
    variants = {
        "deep": base,
        "grain": base * (1 + 0.12 * grain),
        "brushed": base * (1 + 0.13 * brush),
        "clouds": base * (1 + 0.16 * clouds),
        "steel": np.repeat(steel, w, axis=1) * (1 + 0.12 * grain),
    }
    # potion: small light bubbles, placed so they wrap around
    pot = base * (1 + 0.06 * grain)
    rng = np.random.default_rng(4)
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    for _ in range(26):
        bx, by, br = rng.uniform(0, w), rng.uniform(5, h - 5), rng.uniform(0.8, 1.8)
        dx = np.minimum(np.abs(xx - bx), w - np.abs(xx - bx))
        v = np.clip(br + 0.5 - np.hypot(dx, yy - by), 0, 1)[..., None] * rng.uniform(0.35, 0.6)
        pot = pot + (rgb("c8e1ff") - pot) * v
    variants["potion"] = pot
    for name, arr in variants.items():
        save(np.dstack([np.clip(arr, 0, 1), np.ones((h, w))]), f"xp-fill-{name}.tga")


def main():
    cells()
    portrait()
    tube()
    fills()


if __name__ == "__main__":
    main()
