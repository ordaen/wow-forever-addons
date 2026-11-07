"""Build the push button textures: the bronze plate (the default) and the red accent, every state in one file.

Usage:
    art/.venv/Scripts/python art/button.py

Writes addons/OrdaenCore/media/button.tga (256x512, 32-bit) and a preview art/out/buttons.png.

Layout: 8 rows of 64 px, each a whole button 256 wide: rows 0-3 the bronze plate (normal, pushed, disabled,
highlight), rows 4-7 the red accent (same order). The theme slices each row into left cap (x 0-32), centre (32-224,
the same in every column, stretched across) and right cap (224-256). A cap has aspect 0.5: on screen it is half as
wide as the button is high (a 34 px button: 64 texture px over 34 screen px, ~1.9 per px; an icon-only button is
just the two caps), so rim sizes below are in texture px.
The look was picked by the user from the browser preview (2026-11-07): #2 bronze plate, #1 red as the accent.
"""

from pathlib import Path

import numpy as np
from PIL import Image

ART = Path(__file__).resolve().parent
REPO = ART.parent
W, ROW, ROWS = 256, 64, 8
# Transparent rows above and below the plate, like Blizzard's red button art has: buttons stacked with no
# spacing (the game menu's groups) keep a small gap (~1.6 screen px each side on a 34 px button).
PAD_Y = 3
PLATE = ROW - 2 * PAD_Y
SS = 4  # supersampling


def rgb(hexstr):
    return np.array([int(hexstr[i:i + 2], 16) for i in (0, 2, 4)], dtype=float) / 255


# Rim colours from art/frame.py's bronze-rim profile (measured from the round minimap ring), so the buttons belong
# to the windows' metal. Sizes in texture px, from the outside in.
OUTLINE, RIM, LIP, RADIUS = 2.0, 4.0, 2.0, 3.0
OUTLINE_C = rgb("0c0e09")
RIM_LIT, RIM_DARK = rgb("8e7655"), rgb("36230f")
RIM_LIT_SOFT, RIM_DARK_SOFT = rgb("6c5535"), rgb("2e1d10")
RIDGE = rgb("d6a56b")
LIP_C = rgb("1a1306")

PLATES = {
    "bronze": dict(top=rgb("2c2117"), bottom=rgb("1a130c"), shine=rgb("d6a56b"), shine_alpha=0.35),
    "red": dict(top=rgb("8c1a14"), mid=rgb("5e0d0a"), bottom=rgb("470806"), shine=rgb("d6a56b"), shine_alpha=0.45),
}


def grid(h):
    ys, xs = np.mgrid[0:h * SS, 0:W * SS].astype(float)
    return (xs + 0.5) / SS, (ys + 0.5) / SS


def rounded_depth(x, y, w, h, r):
    """Distance inside a rounded rectangle (0 at the edge, negative outside), and which way the edge faces."""
    cx = np.clip(x, r, w - r)
    cy = np.clip(y, r, h - r)
    dx, dy = x - cx, y - cy
    corner = np.hypot(dx, dy)
    straight = np.minimum.reduce([x, y, w - x, h - y])
    in_corner = (np.abs(dx) > 0) & (np.abs(dy) > 0)
    depth = np.where(in_corner, r - corner, straight)
    # facing: +1 towards the light (top or left edge), -1 away (bottom or right); corners split on the diagonal
    to_top, to_left = h - y - y, w - x - x  # >0 nearer the top / left
    near_x = np.minimum(x, w - x) < np.minimum(y, h - y)
    facing = np.where(near_x, np.sign(to_left), np.sign(to_top))
    return depth, facing


def lerp(a, b, t):
    return a + (b - a) * t[..., None]


def plate(name, state):
    p = PLATES[name]
    x, y = grid(ROW)
    y = y - PAD_Y
    depth, facing = rounded_depth(x, y, W, PLATE, RADIUS)
    lit = (facing + 1) / 2  # 1 lit, 0 dark, 0.5 the corners that turn
    t = np.clip(y / PLATE, 0, 1)
    if "mid" in p:
        fill = np.where((t < 0.55)[..., None], lerp(p["top"], p["mid"], t / 0.55), lerp(p["mid"], p["bottom"], (t - 0.55) / 0.45))
    else:
        fill = lerp(p["top"], p["bottom"], t)
    rng = np.random.default_rng(7)
    grain = rng.normal(0, 0.012, (ROW * SS, 1, 1))  # fine horizontal brushing, same in every column (the centre stretches)
    fill = fill + grain
    if state == "pushed":
        fill = fill * 0.62
        lit = 1 - lit * 0.6  # the rim reads sunk: light from the other side, weaker
    rim = lerp(lerp(RIM_DARK_SOFT, RIM_DARK, np.clip(depth / (OUTLINE + RIM), 0, 1)),
               lerp(RIM_LIT_SOFT, RIM_LIT, np.clip(depth / (OUTLINE + RIM), 0, 1)), lit)
    ridge_band = (depth > OUTLINE + RIM * 0.25) & (depth < OUTLINE + RIM * 0.6) & (lit > 0.6)
    rim = np.where(ridge_band[..., None], lerp(rim, RIDGE, np.full(depth.shape, 0.55)), rim)
    col = np.where((depth < OUTLINE)[..., None], OUTLINE_C, np.where((depth < OUTLINE + RIM)[..., None], rim,
                   np.where((depth < OUTLINE + RIM + LIP)[..., None], lerp(LIP_C, fill, np.full(depth.shape, 0.35)), fill)))
    inside = OUTLINE + RIM + LIP
    if state != "pushed":
        # a thin shine just inside the lip along the top: the plate's bevel catching the light
        shine = (y >= inside) & (y < inside + 1.5) & (depth >= inside)
        col = np.where(shine[..., None], lerp(col, p["shine"], np.full(depth.shape, p["shine_alpha"])), col)
    else:
        # an inner shadow under the top lip
        sh = np.clip(1 - (y - inside) / 8, 0, 1) * (depth >= inside)
        col = lerp(col, np.zeros(3), sh * 0.6)
    if state == "disabled":
        grey = col @ np.array([0.3, 0.59, 0.11])
        col = lerp(col, np.repeat(grey[..., None], 3, -1), np.full(depth.shape, 0.75)) * 0.7
    alpha = np.clip(depth + 0.5, 0, 1)  # anti-aliased outer edge
    return np.dstack([np.clip(col, 0, 1), alpha])


def highlight(name):
    """Drawn over the plate on hover: a warm glow inside, brighter at the rim. Its alpha does the work."""
    x, y = grid(ROW)
    y = y - PAD_Y
    depth, _ = rounded_depth(x, y, W, PLATE, RADIUS)
    inside = OUTLINE + RIM + LIP
    col = np.broadcast_to(rgb("ffd27a"), depth.shape + (3,)).copy()
    rim_glow = np.clip(1 - np.abs(depth - (OUTLINE + RIM * 0.5)) / RIM, 0, 1) * 0.5
    body = np.where(depth >= inside, 0.10 + 0.08 * (1 - y / PLATE), 0)
    a = np.clip(np.maximum(rim_glow, body), 0, 1) * (depth > 0)
    if name == "red":
        a = a * 1.2
    return np.dstack([col, np.clip(a, 0, 1)])


def downsample(img):
    h, w = img.shape[0] // SS, img.shape[1] // SS
    a = img[..., 3:4]
    rgb_pm = (img[..., :3] * a).reshape(h, SS, w, SS, 3).mean((1, 3))
    a = a.reshape(h, SS, w, SS, 1).mean((1, 3))
    out = np.where(a > 0, rgb_pm / np.maximum(a, 1e-6), 0)
    return np.dstack([out, a])


def main():
    rows = []
    for name in ("bronze", "red"):
        for state in ("normal", "pushed", "disabled"):
            rows.append(downsample(plate(name, state)))
        rows.append(downsample(highlight(name)))
    img = (np.clip(np.vstack(rows), 0, 1) * 255 + 0.5).astype(np.uint8)
    out = REPO / "addons" / "OrdaenCore" / "media" / "button.tga"
    Image.fromarray(img, "RGBA").save(out, compression=None)
    # preview at game size: a 34 px high button, caps 17 wide (aspect 0.5), the centre stretched; normal and
    # pushed and disabled as they are, the highlight over normal; 234 wide, 112 wide and icon-only (34)
    src = Image.fromarray(img, "RGBA")
    prev = Image.new("RGBA", (470, 8 * 44 + 10), (26, 19, 12, 255))

    def button(row, x, y, w):
        for (x0, x1), dx, dw in (((0, 32), 0, 17), ((32, 224), 17, w - 34), ((224, 256), w - 17, 17)):
            if dw > 0:
                piece = row.crop((x0, 0, x1, 64)).resize((dw, 34), Image.LANCZOS)
                prev.alpha_composite(piece, (x + dx, y))

    for r in range(ROWS):
        y = 10 + r * 44
        rows_ = [r - 3, r] if r % 4 == 3 else [r]
        for rr in rows_:
            row = src.crop((0, rr * ROW, W, (rr + 1) * ROW))
            button(row, 10, y, 234)
            button(row, 254, y, 112)
            button(row, 376, y, 34)
    (ART / "out").mkdir(exist_ok=True)
    prev.save(ART / "out" / "buttons.png")
    print("wrote", out)


if __name__ == "__main__":
    main()
