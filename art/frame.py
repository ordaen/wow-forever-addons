"""Build minimap border textures procedurally, plus in-game-accurate previews.

Usage:
    art/.venv/Scripts/python art/frame.py <style> [--map some.png] [--edge-size 24] [--frame-px 256]

Writes addons/OrdaenMinimap/media/<style>-frame.tga (and with --backdrop <style>.tga) plus previews
in art/out/frames/:

- <style>.tga: a backdrop edge file (8 slices). Layout (Blizzard_SharedXML/Backdrop.lua, `textureUVs`):
  8 square cells side by side (left, right, top, bottom edge, TL, TR, BL, BR corner). Backdrop only samples
  the inner part of each cell (x inset 1/128 of the file width = 4 px of a 64 px cell, y from 0.0625 to
  0.9375), so the art lives in a 56 px content square and the 4 px margin is padding. Top and bottom edges
  are drawn rotated: the cell's x axis runs down the screen (left column = top of the frame). Side edges
  tile every edgeSize screen px, so this version has no chips (they would repeat).
- <style>-frame.tga: the whole frame as one square texture (transparent middle), stretched over the border
  frame. Nothing repeats, so this one carries the wear: chips in the outer edge, scratches across the bar,
  dull spots on the ridge.

Everything is drawn from one distance field of a square frame, so corners and edges always match.
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
FRAME_TEX = 256  # side of the whole-frame texture (~1.2 texture px per screen px at a 220 px frame)
UNITS_PER_SCREEN_PX = CONTENT / 24  # style units are content px of an edgeSize-24 backdrop


def rgb(hexstr):
    return np.array([int(hexstr[i:i + 2], 16) for i in (0, 2, 4)], dtype=float) / 255


# A style is a cross-section profile across the rim, from the outer edge inward, in style units
# (1 screen px = 2.33 units). The bar is a ridge lit from the top-left, so each slope's colour goes from
# `dark` (facing away from the light) to `lit` (facing it): on the top and left sides the outer slope is lit
# and the inner slope dark, on the bottom and right sides the other way round.
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
        grain=0.06,            # fine scratches along the bar
        # Wear for the whole-frame texture, per side (counts are ranges; sizes in screen px).
        wear=dict(seed=11, chips=(2, 4), chip_len=(3, 10), chip_depth=(2.0, 4.5),
                  gashes=(0, 2), gash_width=(0.8, 1.4), dull=(1, 3), dull_len=(10, 30)),
    ),
}


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def lerp(a, b, t):
    return a + (b - a) * t[..., None]


def wear_maps(s, side, along, length):
    """Per-pixel wear for one side: chip depth into the outer edge, gash strength, dullness (style units)."""
    w = s["wear"]
    rng = np.random.default_rng(w["seed"] * 10 + side)
    u = UNITS_PER_SCREEN_PX
    chip = np.zeros_like(along)
    gash = np.zeros_like(along)
    gash_lit = np.zeros_like(along)
    dull = np.zeros_like(along)
    margin = 0.08 * length
    for _ in range(rng.integers(w["chips"][0], w["chips"][1] + 1)):
        a = rng.uniform(margin, length - margin)
        hl = rng.uniform(*w["chip_len"]) * u / 2
        dp = rng.uniform(*w["chip_depth"]) * u
        t = np.clip(1 - ((along - a) / hl) ** 2, 0, 1)
        # Uneven break: a couple of sine wobbles over the chip.
        wobble = 1 + 0.25 * np.sin((along - a) / hl * rng.uniform(4, 8) + rng.uniform(0, 6))
        chip = np.maximum(chip, dp * np.sqrt(t) * wobble)
    for _ in range(rng.integers(w["gashes"][0], w["gashes"][1] + 1)):
        a = rng.uniform(margin, length - margin)
        hw = rng.uniform(*w["gash_width"]) * u / 2
        reach = rng.uniform(0.4, 1.0)  # how far across the bar it goes, from the outer side
        g = np.exp(-((along - a) / hw) ** 2)
        gash = np.maximum(gash, g * reach)
        gash_lit = np.maximum(gash_lit, np.exp(-((along - a - 1.6 * hw) / hw) ** 2) * reach)
    for _ in range(rng.integers(w["dull"][0], w["dull"][1] + 1)):
        a = rng.uniform(margin, length - margin)
        hl = rng.uniform(*w["dull_len"]) * u / 2
        dull = np.maximum(dull, smoothstep(hl, hl * 0.4, np.abs(along - a)) * rng.uniform(0.4, 0.8))
    return chip, gash, gash_lit, dull


def render_frame(s, n, unit, worn):
    """RGBA float array of a square frame n px on a side. `unit` = texture px per style unit."""
    N = n * SS
    c = (np.arange(N) + 0.5)
    x, y = np.meshgrid(c, c)
    h, r = N / 2, s["radius"] * unit * SS
    px, py = x - h, y - h
    qx, qy = np.abs(px) - (h - r), np.abs(py) - (h - r)
    to_units = 1 / (unit * SS)
    d = -(np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0) - r) * to_units

    # Outward normal of the nearest side, blended softly across the corner mitres.
    b = s["mitre_softness"] * unit * SS
    m = np.maximum(qx, qy)
    nx, ny = np.sign(px) * np.exp((qx - m) / b), np.sign(py) * np.exp((qy - m) / b)
    norm = np.hypot(nx, ny)
    lx, ly = np.array(s["light"]) / np.hypot(*s["light"])
    k_out = np.clip(0.5 + (nx * lx + ny * ly) / norm / (2 * 0.7071), 0, 1)  # 1 = outer slope faces the light

    o, a, rw, iw, lip = s["outline"], s["outer"], s["ridge"], s["inner"], s["lip"]
    e1, e2, e3, e4 = o, o + a, o + a + rw, o + a + rw + iw
    width = e4 + lip

    vertical = np.abs(px) > np.abs(py)
    along = np.where(vertical, y, x) * to_units  # coordinate along the nearest side
    chip = gash = gash_lit = dull = np.zeros_like(d)
    if worn:
        side = np.where(vertical, np.where(px < 0, 0, 1), np.where(py < 0, 2, 3))
        length = N * to_units
        chip, gash, gash_lit, dull = (np.zeros_like(d) for _ in range(4))
        for sd in range(4):
            mask = side == sd
            maps = wear_maps(s, sd, along, length)
            for acc, mp in zip((chip, gash, gash_lit, dull), maps):
                acc[mask] = mp[mask]

    def slope(lit, dark, t, k):
        return lerp(lerp(dark[0], dark[1], t), lerp(lit[0], lit[1], t), k)

    outer = slope(s["outer_lit"], s["outer_dark"], np.clip((d - e1) / a, 0, 1), k_out)
    ridge = lerp(s["ridge_dark"], s["ridge_lit"], k_out)
    ridge = lerp(ridge, outer * 1.1, dull)  # worn ridge loses its shine
    inner = slope(s["inner_lit"], s["inner_dark"], np.clip((d - e3) / iw, 0, 1), 1 - k_out)
    # A chip moves the outer edge inward; its fresh break gets the outline colour.
    edge = chip
    body = np.select([(d < e2)[..., None], (d < e3)[..., None], (d < e4)[..., None]],
                     [outer, ridge, inner], s["lip_color"] + 0 * outer)
    color = np.where((d < edge + o * np.where(chip > 0, 0.7, 1))[..., None], s["outline_color"] + 0 * outer, body)
    # Rough, darker metal just inside a chip.
    color = lerp(color, color * 0.7, smoothstep(edge + o + 3, edge + o, d) * (chip > 0))

    # Fine scratches along the bar, periodic over CONTENT units so backdrop edges tile.
    rng = np.random.default_rng(7)
    ks = np.arange(1, 7)
    phases = rng.uniform(0, 2 * np.pi, (len(ks), 2))
    grain = sum(np.sin(2 * np.pi * kk * along / CONTENT + p[0]) * np.sin(2 * np.pi * (kk + 2) * d / width + p[1])
                for kk, p in zip(ks, phases)) / len(ks)
    rim = (d >= edge + o) & (d < e4)
    color = np.where(rim[..., None], color * (1 + s["grain"] * grain[..., None]), color)
    # Gashes across the bar from the outer side: a dark cut with a lit lip beside it.
    across = smoothstep(0, 0.15, 1 - (d - e1) / (e4 - e1)) * (d >= e1) * (d < e4)
    reach_ok = (d - e1) / (e4 - e1)
    cut = gash * across * (reach_ok < np.maximum(gash, 1e-6) * 1.0)
    color = lerp(color, color * 0.45, np.clip(cut * 1.6, 0, 1))
    lit_lip = gash_lit * across * (reach_ok < np.maximum(gash_lit, 1e-6))
    color = lerp(color, np.minimum(color * 1.5, 1), np.clip(lit_lip * 0.8, 0, 1))
    color = np.clip(color, 0, 1)

    alpha = smoothstep(edge - 0.5, edge + 0.5, d) * (1 - smoothstep(width - 0.5, width + 0.5, d))
    # Downsample (premultiplied, box filter).
    pre = np.dstack([color * alpha[..., None], alpha])
    pre = pre.reshape(n, SS, n, SS, 4).mean(axis=(1, 3))
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


def to_image(arr):
    return Image.fromarray((np.clip(arr, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA")


def save_tga(arr, path):
    # Bottom-left origin, uncompressed 32-bit: the most widely supported TGA flavor.
    to_image(arr).save(path, orientation=1, compression=None)


def resize_premultiplied(arr, size):
    """Bilinear-ish downscale of an RGBA float array, premultiplied like the GPU's filtering."""
    pre = np.dstack([arr[..., :3] * arr[..., 3:], arr[..., 3:]])
    chans = [np.asarray(Image.fromarray(pre[..., i].astype(np.float32), "F").resize((size, size), Image.BOX))
             for i in range(4)]
    out = np.dstack(chans)
    a = out[..., 3:]
    return np.dstack([np.where(a > 0, out[..., :3] / np.maximum(a, 1e-6), 0), np.clip(a, 0, 1)])


def preview(mapimg, border, outset, path):
    """Map with the border drawn around it on a dark game-like background, at 2x."""
    fw = border.shape[0]
    canvas = np.zeros((fw + 40, fw + 40, 4))
    canvas[..., :3] = rgb("1d2a1c")
    canvas[..., 3] = 1
    m = fw - 2 * outset
    mp = mapimg.resize((m, m), Image.LANCZOS)
    over(canvas, np.asarray(mp, dtype=float) / 255, 20 + outset, 20 + outset)
    over(canvas, border, 20, 20)
    img = to_image(canvas).convert("RGB")
    img.resize((img.width * 2, img.height * 2), Image.NEAREST).save(path)
    print(path)


def build_backdrop(s, e, fw, outset, mapimg, media, prev_dir, name):
    """Backdrop edge file. 1 texture px = 1 style unit by construction of the 56 px content cell."""
    tex = cut_edge_file(render_frame(s, 3 * CONTENT, 1.0, worn=False))
    tga = media / f"{name}.tga"
    save_tga(tex, tga)
    preview(mapimg, simulate_backdrop(tex, fw, fw, e), outset, prev_dir / f"{name}-preview.png")
    print(f"{tga.relative_to(REPO)}  backdrop edgeSize={e} outset={outset}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("style", choices=sorted(STYLES))
    ap.add_argument("--map", type=Path, help="image to stand in for the map in the preview")
    ap.add_argument("--edge-size", type=int, default=24)
    ap.add_argument("--map-size", type=int, default=200, help="map size on screen for the previews")
    ap.add_argument("--backdrop", action="store_true",
                    help="also write <style>.tga as a backdrop edge file (no wear; edges repeat)")
    ap.add_argument("--frame-px", type=int, default=220,
                    help="on-screen size of the whole frame the -frame texture is designed for")
    args = ap.parse_args()
    s = STYLES[args.style]
    media = REPO / "addons" / "OrdaenMinimap" / "media"
    media.mkdir(parents=True, exist_ok=True)
    prev_dir = ART / "out" / "frames"
    prev_dir.mkdir(parents=True, exist_ok=True)

    width = s["outline"] + s["outer"] + s["ridge"] + s["inner"] + s["lip"]
    outset = round((width - s["lip"] / 2) / UNITS_PER_SCREEN_PX)

    if args.map:
        mp = Image.open(args.map).convert("RGBA")
        side = min(mp.size)
        mapimg = mp.crop(((mp.width - side) // 2, (mp.height - side) // 2,
                          (mp.width + side) // 2, (mp.height + side) // 2))
    else:
        mapimg = Image.new("RGBA", (64, 64), (84, 102, 46, 255))

    fw = args.map_size + 2 * outset
    e = args.edge_size
    if args.backdrop:
        build_backdrop(s, e, fw, outset, mapimg, media, prev_dir, args.style)

    # Whole-frame texture with wear, designed for a frame of --frame-px screen px.
    frame_unit = FRAME_TEX / args.frame_px / UNITS_PER_SCREEN_PX
    whole = render_frame(s, FRAME_TEX, frame_unit, worn=True)
    tga = media / f"{args.style}-frame.tga"
    save_tga(whole, tga)
    border = resize_premultiplied(whole, fw)
    preview(mapimg, border, outset, prev_dir / f"{args.style}-frame-preview.png")
    print(f"{tga.relative_to(REPO)}  whole frame, designed for {args.frame_px} px on screen, outset={outset}")


if __name__ == "__main__":
    main()
