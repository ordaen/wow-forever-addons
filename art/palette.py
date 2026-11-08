"""The Ordaen palette's default tones: each named colour from a Blizzard source, rebalanced for dark backgrounds and
weak monitors in OKLCH (one lightness for bar fills, a lighter one for text, chroma capped), variant #10 of
the preview page. Players can change every tone in Ordaen Core's settings; these are the
Ordaen theme's defaults.

Usage:
    python art/palette.py      # prints the "color.palette.*" values for addons/OrdaenCore/themes.jsonc

Rules (why each exception exists):
- Bar fills at L 0.50 with chroma <= 0.14 keep white text on them at 5:1 or more (the weakest monitor has margin);
  the text on bars gets a 1 px outline and a faint scrim, so white and yellow can be lighter.
- white and yellow stay lighter (0.74 / 0.70): they only read as themselves near the top of the lightness range.
- orange is redder and darker (hue 45) and yellow a gold (hue 85), so the warm neighbours differ in more than hue
  (a washed-out screen erases small hue gaps); tan is the muted warm colour (low chroma).
- blue (Shaman's deep blue) and green are a step deeper and more saturated: blue stays apart from cyan.
- red keeps its saturation (the common cap made it brick).
"""

import math

# Blizzard sources (sRGB 0..1): generic UI colours, and class colours where they add a colour the palette needs
# (cyan from Mage, pink from Paladin, tan from Warrior).
SOURCES = {
    "red": (1.00, 0.13, 0.13), "orange": (1.00, 0.50, 0.00), "yellow": (1.00, 0.82, 0.00),
    "green": (0.12, 1.00, 0.00), "cyan": (0.25, 0.78, 0.92), "blue": (0.00, 0.44, 0.87),
    "violet": (0.64, 0.21, 0.93), "pink": (0.96, 0.55, 0.73), "tan": (0.78, 0.61, 0.43),
    "white": (1.00, 1.00, 1.00), "grey": (0.62, 0.62, 0.62),
}

BASE = {"fill": 0.50, "fillC": 0.14, "text": 0.80, "textC": 0.12}
OWN = {
    "white": {"fill": 0.74, "fillC": 0, "text": 0.95},
    "yellow": {"fill": 0.70, "fillC": 0.15, "hue": 85, "text": 0.90},
    "orange": {"fill": 0.50, "fillC": 0.17, "hue": 45},
    "blue": {"fill": 0.46, "fillC": 0.18, "text": 0.70, "textC": 0.16},
    "green": {"fill": 0.46, "fillC": 0.17},
    "tan": {"fillC": 0.07, "textC": 0.07},
    "red": {"fillC": 0.21, "textC": 0.16},
}


def to_lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def to_srgb(c):
    return 12.92 * c if c <= 0.0031308 else 1.055 * (c ** (1 / 2.4)) - 0.055


def rgb_to_oklch(rgb):
    r, g, b = (to_lin(c) for c in rgb)
    l = (0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b) ** (1 / 3)
    m = (0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b) ** (1 / 3)
    s = (0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b) ** (1 / 3)
    L = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s
    a = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s
    B = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
    return L, math.hypot(a, B), math.atan2(B, a)


def oklch_to_rgb(L, C, h):
    a, b = C * math.cos(h), C * math.sin(h)
    l = (L + 0.3963377774 * a + 0.2158037573 * b) ** 3
    m = (L - 0.1055613458 * a - 0.0638541728 * b) ** 3
    s = (L - 0.0894841775 * a - 1.2914855480 * b) ** 3
    lin = (4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
           -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
           -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s)
    return tuple(to_srgb(max(0.0, c)) if c > 0 else -to_srgb(-c) for c in lin)


def fit(L, C, h):
    """Into the sRGB gamut by lowering chroma, so hue and lightness stay."""
    c = C
    while c >= 0:
        rgb = oklch_to_rgb(L, c, h)
        if all(-0.0005 <= v <= 1.0005 for v in rgb):
            return tuple(min(1.0, max(0.0, v)) for v in rgb)
        c -= 0.002
    return tuple(min(1.0, max(0.0, v)) for v in oklch_to_rgb(L, 0, h))


def tone(name, kind):
    s = dict(BASE, **OWN.get(name, {}))
    _, C, h = rgb_to_oklch(SOURCES[name])
    if "hue" in s:
        h = math.radians(s["hue"])
    cap = s["textC"] if kind == "text" else s["fillC"]
    chroma = cap if "hue" in s else min(C, cap)
    return fit(s["text"] if kind == "text" else s["fill"], chroma, h)


def main():
    for name in SOURCES:
        fill = ", ".join(f"{v:.3f}" for v in tone(name, "fill"))
        text = ", ".join(f"{v:.3f}" for v in tone(name, "text"))
        print(f'      "color.palette.{name}": [{fill}], "color.palette.{name}.text": [{text}],')


if __name__ == "__main__":
    main()
