# The metal frame's curved pieces (border.radius and border.flare, Backend ApplyFrameArt), made from the frame's own
# line: Blizzard's ButtonFrameTemplateNoPortrait left edge (the design site's public/ui/metal/left.png, the atlas at 2x),
# its profile across the line bent round a quarter circle, so a curve shows exactly the straight edge's colours.
#
#   metal-corner-small/large  a top-left corner: the line's outer side on an arc of radius S round the square's
#                             bottom-right corner (S the square's side); the others are this one turned and flipped
#   metal-flare               the bottom-left inward curve where a side meets a line below it (an open tab on its
#                             window's body): the line's outer side on an arc of radius 0 round the square's top-left
#
# The sizes are in the art's units at scale 1, as the Theme's metal reads them (Backend: size times border.scale).
# Run: python tools/metal-curves.py <design public/ui/metal/left.png> <addons/OrdaenCore/media>
import math
import sys
from PIL import Image

LEFT, OUT = sys.argv[1], sys.argv[2]
SS = 4  # supersampling per pixel
RES = 128  # each texture's side in pixels

edge = Image.open(LEFT).convert("RGBA")
EW = edge.width  # the edge's width in the art's pixels (2 per unit at scale 1)
ROW = edge.height // 2
profile = [edge.getpixel((x, ROW)) for x in range(EW)]
UNIT = 2  # art pixels per unit
T = EW / UNIT  # the edge's thickness in units


def sample(u):
    """The line's colour u units in from its outer side (premultiplied rgb, alpha)."""
    c = u * UNIT
    if c < 0 or c >= EW - 1:
        return (0.0, 0.0, 0.0, 0.0)
    i = int(c)
    t = c - i
    a, b = profile[i], profile[i + 1]
    out = []
    for k in range(4):
        out.append(a[k] * (1 - t) + b[k] * t)
    r, g, bl, al = out
    al /= 255
    return (r * al, g * al, bl * al, al)


def render(size, colour_at, path):
    im = Image.new("RGBA", (RES, RES))
    px = im.load()
    for y in range(RES):
        for x in range(RES):
            r = g = b = a = 0.0
            for ky in range(SS):
                for kx in range(SS):
                    ux = (x + (kx + 0.5) / SS) / RES * size
                    uy = (y + (ky + 0.5) / SS) / RES * size
                    cr, cg, cb, ca = colour_at(ux, uy)
                    r, g, b, a = r + cr, g + cg, b + cb, a + ca
            n = SS * SS
            if a == 0:
                px[x, y] = (0, 0, 0, 0)
            else:
                px[x, y] = (round(r / a), round(g / a), round(b / a), round(255 * a / n))
    im.save(path)


# the line's visible part: in from its outer side to where the profile ends (the edge's transparent rest is cut)
VISIBLE = max(i for i, p in enumerate(profile) if p[3] > 0) / UNIT + 0.5
BRONZE = 28 / UNIT  # the bronze stripe's centre, units in from the outer side (column 28 of left.png)
# the corners' radii as the eye reads them, at the bronze stripe: small 8 px, large 14 px at 1.2 px a unit, at scale
# 0.5 (the frame's) that is twice the units in the art's own
SIZES = {}
for name, px_radius in (("small", 8), ("large", 14)):
    S = px_radius / 1.2 / 0.5 + BRONZE
    SIZES[name] = S

    def corner(ux, uy, S=S):
        d = math.hypot(S - ux, S - uy)
        return sample(S - d)

    render(S, corner, f"{OUT}/metal-corner-{name}.tga")

# the inward curve: the line's outer side on an arc of radius 0 round the square's top-left, out to its visible end
FLARE = VISIBLE


def flare(ux, uy):
    return sample(math.hypot(ux, uy))


render(FLARE, flare, f"{OUT}/metal-flare.tga")
print("T", T, "visible", VISIBLE, "corners", SIZES, "flare", FLARE)
