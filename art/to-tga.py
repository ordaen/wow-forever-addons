"""The glyph atlas as a 32-bit TGA: alpha from a shot on black and one on white (alpha = 1 - (white - black)),
colour un-premultiplied from the black shot."""
import sys
from PIL import Image

black_path, white_path, dst, w, h = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4]), int(sys.argv[5])
black = Image.open(black_path).convert("RGB").crop((0, 0, w, h))
white = Image.open(white_path).convert("RGB").crop((0, 0, w, h))
out = Image.new("RGBA", (w, h))
bp, wp, op = black.load(), white.load(), out.load()
for y in range(h):
    for x in range(w):
        b, wh = bp[x, y], wp[x, y]
        a = 255 - max(0, min(255, round(sum(wh[i] - b[i] for i in range(3)) / 3)))
        if a == 0:
            op[x, y] = (0, 0, 0, 0)
        else:
            op[x, y] = tuple(min(255, round(b[i] * 255 / a)) for i in range(3)) + (a,)
out.save(dst)
