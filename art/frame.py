"""Build a WoW backdrop edge file (8 slices) procedurally, plus an in-game-accurate preview.

Usage:
    art/.venv/Scripts/python art/frame.py <style> [--map some.png] [--edge-size 24]

Writes addons/OrdaenMinimap/media/<style>.tga and art/out/frames/<style>-preview.png.

Edge file layout (see Blizzard_SharedXML/Backdrop.lua, `textureUVs`): 8 square cells side by side
(left, right, top, bottom edge, TL, TR, BL, BR corner). Backdrop only samples the inner part of each cell
(x inset 1/128 of the file width = 4 px of a 64 px cell, y from 0.0625 to 0.9375), so the art lives in a
56 px content square and the 4 px margin is padding. Top and bottom edges are drawn rotated: the cell's
x axis runs down the screen (left column = top of the frame), its y axis runs right-to-left along the edge.
Side edges tile along y over the whole cell height, so they must be seamless.

Everything is drawn as one virtual square frame from a distance field and then cut into pieces, so the
corners and edges always match.
"""

import argparse
from pathlib import Path

import numpy as np
from PIL import Image

ART = Path(__file__).resolve().parent
REPO = ART.parent
CELL, PAD = 64, 4
CONTENT = CELL - 2 * PAD  # 56
SS = 4  # supersampling for anti-aliasing


def rgb(hexstr):
    return np.array([int(hexstr[i:i + 2], 16) for i in (0, 2, 4)], dtype=float) / 255


# A style is a cross-section profile across the rim, from the outer edge inward (content px; at edgeSize 24
# one screen px is 56/24 = 2.33 content px). The bar is a ridge lit from the top-left, so each slope's colour
# goes from `dark` (facing away from the light) to `lit` (facing it): on the top and left sides the outer
# slope is lit and the inner slope dark, on the bottom and right sides the other way round.
STYLES = {
    # Bevelled bronze ridge in the spirit of the round minimap ring. Colours measured from that ring in game.
    "bronze-rim": dict(
        radius=3.0,            # outer corner rounding
        outline=2.3, outline_color=rgb("0c0e09"),
        outer=9.3,             # outer slope: from the outline up to the ridge
        outer_lit=(rgb("6c5535"), rgb("8e7655")), outer_dark=(rgb("2e1d10"), rgb("36230f")),
        ridge=3.5, ridge_lit=rgb("d6a56b"), ridge_dark=rgb("ab9469"),
        inner=9.3,             # inner slope: from the ridge down to the inner line
        inner_lit=(rgb("947350"), rgb("6b492d")), inner_dark=(rgb("4a2d1b"), rgb("3e281b")),
        lip=2.3, lip_color=rgb("1a1306"),
        light=(-1.0, -1.0),    # direction towards the light, screen coordinates (y down)
        mitre_softness=2.0,    # how gently the lighting turns at the corners
        grain=0.06,            # scratches along the bar
    ),
}


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def lerp(a, b, t):
    return a + (b - a) * t[..., None]


def render_frame(s):
    """RGBA float array of a square frame 3*CONTENT on a side; the middle third is the edge region."""
    n = 3 * CONTENT * SS
    c = (np.arange(n) + 0.5)
    x, y = np.meshgrid(c, c)
    h, r = n / 2, s["radius"] * SS
    px, py = x - h, y - h
    qx, qy = np.abs(px) - (h - r), np.abs(py) - (h - r)
    d = -(np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0) - r) / SS

    # Outward normal of the nearest side, blended softly across the corner mitres.
    b = s["mitre_softness"] * SS
    m = np.maximum(qx, qy)
    nx, ny = np.sign(px) * np.exp((qx - m) / b), np.sign(py) * np.exp((qy - m) / b)
    norm = np.hypot(nx, ny)
    lx, ly = np.array(s["light"]) / np.hypot(*s["light"])
    k_out = np.clip(0.5 + (nx * lx + ny * ly) / norm / (2 * 0.7071), 0, 1)  # 1 = outer slope faces the light

    o, a, rw, iw, lip = s["outline"], s["outer"], s["ridge"], s["inner"], s["lip"]
    e1, e2, e3, e4 = o, o + a, o + a + rw, o + a + rw + iw
    width = e4 + lip

    def slope(lit, dark, t, k):
        return lerp(lerp(dark[0], dark[1], t), lerp(lit[0], lit[1], t), k)

    outer = slope(s["outer_lit"], s["outer_dark"], np.clip((d - e1) / a, 0, 1), k_out)
    ridge = lerp(s["ridge_dark"], s["ridge_lit"], k_out)
    inner = slope(s["inner_lit"], s["inner_dark"], np.clip((d - e3) / iw, 0, 1), 1 - k_out)
    color = np.select([(d < e1)[..., None], (d < e2)[..., None], (d < e3)[..., None], (d < e4)[..., None]],
                      [s["outline_color"] + 0 * outer, outer, ridge, inner], s["lip_color"] + 0 * outer)

    # Scratches along the bar, periodic over CONTENT so the side edges tile.
    along = np.where(np.abs(px) > np.abs(py), y, x) / SS
    rng = np.random.default_rng(7)
    ks = np.arange(1, 7)
    phases = rng.uniform(0, 2 * np.pi, (len(ks), 2))
    grain = sum(np.sin(2 * np.pi * kk * along / CONTENT + p[0]) * np.sin(2 * np.pi * (kk + 2) * d / width + p[1])
                for kk, p in zip(ks, phases)) / len(ks)
    rim = (d >= e1) & (d < e4)
    color = np.where(rim[..., None], color * (1 + s["grain"] * grain[..., None]), color)
    color = np.clip(color, 0, 1)

    alpha = smoothstep(-0.5, 0.5, d) * (1 - smoothstep(width - 0.5, width + 0.5, d))
    # Downsample (premultiplied, box filter).
    pre = np.dstack([color * alpha[..., None], alpha])
    pre = pre.reshape(n // SS, SS, n // SS, SS, 4).mean(axis=(1, 3))
    al = pre[..., 3:]
    return np.dstack([np.where(al > 0, pre[..., :3] / np.maximum(al, 1e-6), 0), al])


def cut_edge_file(frame):
    c = CONTENT
    lo, mid, hi = slice(0, c), slice(c, 2 * c), slice(2 * c, 3 * c)
    pieces = [
        frame[mid, lo],                    # left edge (outer side on the left)
        frame[mid, hi],                    # right edge
        np.rot90(frame[lo, mid]),          # top edge, rotated: cell x = screen y
        np.rot90(frame[hi, mid]),          # bottom edge
        frame[lo, lo], frame[lo, hi],      # TL, TR
        frame[hi, lo], frame[hi, hi],      # BL, BR
    ]
    cells = [np.pad(p, ((PAD, PAD), (PAD, PAD), (0, 0)), mode="edge") for p in pieces]
    return np.concatenate(cells, axis=1)


# Blizzard_SharedXML/Backdrop.lua textureUVs: (ULx, ULy, LLx, LLy, URx, URy, LRx, LRy).
CS, CE = 0.0625, 1 - 0.0625
UVS = {
    "TopLeftCorner": (0.5078125, CS, 0.5078125, CE, 0.6171875, CS, 0.6171875, CE),
    "TopRightCorner": (0.6328125, CS, 0.6328125, CE, 0.7421875, CS, 0.7421875, CE),
    "BottomLeftCorner": (0.7578125, CS, 0.7578125, CE, 0.8671875, CS, 0.8671875, CE),
    "BottomRightCorner": (0.8828125, CS, 0.8828125, CE, 0.9921875, CS, 0.9921875, CE),
    "TopEdge": (0.2578125, "rx", 0.3671875, "rx", 0.2578125, CS, 0.3671875, CS),
    "BottomEdge": (0.3828125, "rx", 0.4921875, "rx", 0.3828125, CS, 0.4921875, CS),
    "LeftEdge": (0.0078125, CS, 0.0078125, "ry", 0.1171875, CS, 0.1171875, "ry"),
    "RightEdge": (0.1328125, CS, 0.1328125, "ry", 0.2421875, CS, 0.2421875, "ry"),
}


def simulate_backdrop(tex, w, h, e):
    """Draw a backdrop border of w x h screen px with edgeSize e, the way Backdrop.lua maps the edge file."""
    th, tw = tex.shape[:2]
    out = np.zeros((h, w, 4))
    rx, ry = max(0, w / e - 2 - CS), max(0, h / e - 2 - CS)
    rects = {
        "TopLeftCorner": (0, 0, e, e), "TopRightCorner": (w - e, 0, e, e),
        "BottomLeftCorner": (0, h - e, e, e), "BottomRightCorner": (w - e, h - e, e, e),
        "TopEdge": (e, 0, w - 2 * e, e), "BottomEdge": (e, h - e, w - 2 * e, e),
        "LeftEdge": (0, e, e, h - 2 * e), "RightEdge": (w - e, e, e, h - 2 * e),
    }
    for name, (x0, y0, pw, ph) in rects.items():
        v = [rx if c == "rx" else ry if c == "ry" else c for c in UVS[name]]
        ul, ll, ur, lr = np.array(v[0:2]), np.array(v[2:4]), np.array(v[4:6]), np.array(v[6:8])
        u = (np.arange(pw) + 0.5) / pw
        t = (np.arange(ph) + 0.5) / ph
        uu, tt = np.meshgrid(u, t)
        uv = ((1 - uu) * (1 - tt))[..., None] * ul + (uu * (1 - tt))[..., None] * ur \
            + ((1 - uu) * tt)[..., None] * ll + (uu * tt)[..., None] * lr
        px = np.clip((uv[..., 0] % 1) * tw, 0, tw - 1).astype(int)
        py = np.clip((uv[..., 1] % 1) * th, 0, th - 1).astype(int)
        out[y0:y0 + ph, x0:x0 + pw] = tex[py, px]
    return out


def over(dst, src, x, y):
    h, w = src.shape[:2]
    region = dst[y:y + h, x:x + w]
    a = src[..., 3:]
    region[..., :3] = src[..., :3] * a + region[..., :3] * (1 - a)
    region[..., 3:] = a + region[..., 3:] * (1 - a)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("style", choices=sorted(STYLES))
    ap.add_argument("--map", type=Path, help="image to stand in for the map in the preview")
    ap.add_argument("--edge-size", type=int, default=24)
    ap.add_argument("--map-size", type=int, default=200)
    args = ap.parse_args()
    s = STYLES[args.style]

    frame = render_frame(s)
    tex = cut_edge_file(frame)
    media = REPO / "addons" / "OrdaenMinimap" / "media"
    media.mkdir(parents=True, exist_ok=True)
    tga = media / f"{args.style}.tga"
    # Bottom-left origin, uncompressed 32-bit: the most widely supported TGA flavor.
    Image.fromarray((tex * 255 + 0.5).astype(np.uint8), "RGBA").save(tga, orientation=1, compression=None)

    # Preview: map + border exactly as Backdrop.lua would draw it, on a dark game-like background, 2x.
    e, m = args.edge_size, args.map_size
    scale = e / CELL * CELL / CONTENT  # screen px per content px (a cell's 56 content px fill e screen px)
    width = s["outline"] + s["outer"] + s["ridge"] + s["inner"] + s["lip"]
    outset = round((width - s["lip"] / 2) * e / CONTENT)
    fw = m + 2 * outset
    canvas = np.zeros((fw + 40, fw + 40, 4))
    canvas[..., :3] = rgb("1d2a1c")
    canvas[..., 3] = 1
    if args.map:
        mp = Image.open(args.map).convert("RGBA")
        side = min(mp.size)
        mp = mp.crop(((mp.width - side) // 2, (mp.height - side) // 2,
                      (mp.width + side) // 2, (mp.height + side) // 2)).resize((m, m), Image.LANCZOS)
        mapimg = np.asarray(mp, dtype=float) / 255
    else:
        mapimg = np.ones((m, m, 4)) * np.array([0.33, 0.40, 0.18, 1])
    over(canvas, mapimg, 20 + outset, 20 + outset)
    over(canvas, simulate_backdrop(tex, fw, fw, e), 20, 20)
    prev_dir = ART / "out" / "frames"
    prev_dir.mkdir(parents=True, exist_ok=True)
    preview = prev_dir / f"{args.style}-preview.png"
    img = Image.fromarray((canvas * 255 + 0.5).astype(np.uint8), "RGBA").convert("RGB")
    img.resize((img.width * 2, img.height * 2), Image.NEAREST).save(preview)
    Image.fromarray((tex * 255 + 0.5).astype(np.uint8), "RGBA").resize((1024, 128), Image.NEAREST) \
        .save(prev_dir / f"{args.style}-sheet.png")
    print(f"{tga.relative_to(REPO)}  edgeSize={e} outset={outset}  (scale {scale:.2f} screen px per content px)")
    print(preview)


if __name__ == "__main__":
    main()
