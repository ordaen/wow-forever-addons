"""The term underline's dash (design Tooltip.vue: `underline dotted rgba(232, 195, 90, .55)`): one period of the dashed
line, half gold, half clear, as a 32-bit TGA tiled along a term's text (addons/OrdaenTooltips/assets/dash.tga).
Run: python art/tooltip-dash.py"""
from PIL import Image

W, H = 8, 2  # one period: drawn 1 px high, it repeats every 4 px (2 on, 2 off)
GOLD = (232, 195, 90, round(0.55 * 255))
out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
for y in range(H):
    for x in range(W // 2):
        out.putpixel((x, y), GOLD)
out.save("addons/OrdaenTooltips/assets/dash.tga")
