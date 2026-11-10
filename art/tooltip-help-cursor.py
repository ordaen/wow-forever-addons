"""The help cursor over a locked tooltip's terms (design Tooltip.vue: `cursor: help`): the system's arrow with a «?»
beside it, as a 32x32 32-bit TGA the game takes for SetCursor (addons/OrdaenTooltips/assets/help-cursor.tga). The
arrow's tip sits 1 px in from the top-left corner, the cursor's hot spot. Run: python art/tooltip-help-cursor.py"""
from PIL import Image, ImageDraw, ImageFont

SIZE, SCALE = 32, 8  # drawn 8x larger, then scaled down: smooth edges
img = Image.new("RGBA", (SIZE * SCALE, SIZE * SCALE), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
s = SCALE
# the arrow: its tip 1 px in (its outline inside the image), as the system draws it (white with a black outline)
arrow = [(1.5, 1.5), (1.5, 18), (5.5, 14), (8.5, 20.5), (11, 19.5), (8, 13), (13.5, 13)]
d.polygon([(x * s, y * s) for x, y in arrow], fill=(255, 255, 255, 255), outline=(0, 0, 0, 255), width=s)
# the «?»: bold, white with a black outline, beside the arrow
font = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 15 * s)
d.text((14 * s, 6 * s), "?", font=font, fill=(255, 255, 255, 255), stroke_width=s, stroke_fill=(0, 0, 0, 255))
img.resize((SIZE, SIZE), Image.LANCZOS).save("addons/OrdaenTooltips/assets/help-cursor.tga")
