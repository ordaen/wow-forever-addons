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


# A style is a cross-section profile: what the rim looks like at distance d (content px) from the outer edge.
STYLES = {
    # Thin bevelled bronze bar with a dark outline, a dark inner lip and a soft shadow onto the map.
    "bronze-rim": dict(
        radius=3.0,         # outer corner rounding, content px
        outline=1.5,        # dark outer line
        width=15.0,         # outline + bar + inner lip
        lip=1.75,           # dark inner line
        shadow=10.0,        # inner shadow falloff length onto the map
        shadow_alpha=0.5,
        dark=rgb("26170c"),
        base=rgb("7a5232"),
        light=rgb("d9a86c"),
        lip_color=rgb("2b1a0d"),
        highlight_at=0.32,  # 0 = outer side of the bar, 1 = inner side
        highlight_width=0.22,
        grain=0.05,         # strength of brushed-metal streaks along the bar
    ),
}


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def inward_distance(size, radius):
    """Distance (px) from the outer boundary of a rounded square, positive inside."""
    c = (np.arange(size) + 0.5)
    x, y = np.meshgrid(c, c)
    h = size / 2
    qx, qy = np.abs(x - h) - (h - radius), np.abs(y - h) - (h - radius)
    outside = np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0) - radius
    return -outside, x, y


def render_frame(s):
    """RGBA float array of a square frame 3*CONTENT on a side; the middle third is the edge region."""
    n = 3 * CONTENT * SS
    d, x, y = inward_distance(n, s["radius"] * SS)
    d = d / SS
    along = np.where(np.abs(x - n / 2) > np.abs(y - n / 2), y, x) / SS  # coordinate along the nearest side

    w, o, lip = s["width"], s["outline"], s["lip"]
    t = np.clip((d - o) / (w - o - lip), 0, 1)
    # Round bar: dark at both sides, bright band near the outer third.
    shade = 0.55 + 0.45 * np.sin(np.pi * t) ** 0.8
    hi = np.exp(-((t - s["highlight_at"]) / s["highlight_width"]) ** 2)
    # Brushed streaks along the bar, periodic over CONTENT so the side edges tile.
    rng = np.random.default_rng(7)
    k = np.arange(1, 6)
    phases = rng.uniform(0, 2 * np.pi, (len(k), 2))
    streak = sum(np.sin(2 * np.pi * kk * along / CONTENT + p[0]) * np.sin(2 * np.pi * (kk + 3) * d / w + p[1])
                 for kk, p in zip(k, phases)) / len(k)
    color = (s["base"] * shade[..., None] + (s["light"] - s["base"]) * hi[..., None])
    color = color * (1 + s["grain"] * streak[..., None])
    color = np.where((d < o)[..., None], s["dark"], color)
    color = np.where((d > w - lip)[..., None], s["lip_color"], color)
    # Soften the transitions between outline / bar / lip.
    color = np.clip(color, 0, 1)

    alpha_rim = smoothstep(-0.5, 0.5, d) * (1 - smoothstep(w - 0.5, w + 0.5, d))
    shadow = s["shadow_alpha"] * np.exp(-np.maximum(d - w, 0) / (s["shadow"] / 3)) * (d > w) \
        * (1 - smoothstep(w + s["shadow"] * 0.8, w + s["shadow"], d))
    alpha = alpha_rim + shadow * (1 - alpha_rim)
    rgb_out = np.where((alpha_rim > 0)[..., None], color * alpha_rim[..., None] / np.maximum(alpha, 1e-6)[..., None], 0)

    img = np.dstack([rgb_out, alpha])
    # Downsample (premultiplied, box filter).
    pre = np.dstack([img[..., :3] * img[..., 3:], img[..., 3:]])
    pre = pre.reshape(n // SS, SS, n // SS, SS, 4).mean(axis=(1, 3))
    a = pre[..., 3:]
    return np.dstack([np.where(a > 0, pre[..., :3] / np.maximum(a, 1e-6), 0), a])


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
    outset = round((s["width"] - s["lip"] / 2) * e / CONTENT)
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
