"""Draw the addons' small UI icons procedurally: white glyphs on transparency, tinted in game by the theme.

Usage:
    art/.venv/Scripts/python art/icons.py

Writes 64x64 32-bit .tga files into addons/OrdaenCore/media/ (icon-<name>.tga), shared by every Ordaen addon
through OrdaenCore.UI images (`image = "Interface\\AddOns\\OrdaenCore\\media\\icon-chat"`, `color` from the theme).
Each glyph is drawn at 8x and scaled down, so its edges are smooth. Nothing here copies Blizzard's art.
"""

from pathlib import Path

from PIL import Image, ImageDraw

ART = Path(__file__).resolve().parent
OUT = ART.parent / "addons" / "OrdaenCore" / "media"
SIZE = 64
SS = 8  # supersampling
WHITE = (255, 255, 255, 255)


def canvas():
    img = Image.new("RGBA", (SIZE * SS, SIZE * SS), (255, 255, 255, 0))
    return img, ImageDraw.Draw(img)


def s(*values):
    """Scale 64 px coordinates to the supersampled canvas."""
    return [v * SS for v in values]


def chat():
    """A speech bubble: the chat menu (emotes, languages)."""
    img, d = canvas()
    d.rounded_rectangle(s(6, 9, 58, 45), radius=13 * SS, fill=WHITE)
    d.polygon([tuple(s(15, 40)), tuple(s(29, 40)), tuple(s(11, 57))], fill=WHITE)
    return img


def channels():
    """A hash sign: the channels list."""
    img, d = canvas()
    w = 7
    # Two slanted uprights and two crossbars, all the same weight.
    d.polygon([tuple(s(22, 8)), tuple(s(22 + w, 8)), tuple(s(18 + w, 56)), tuple(s(18, 56))], fill=WHITE)
    d.polygon([tuple(s(39, 8)), tuple(s(39 + w, 8)), tuple(s(35 + w, 56)), tuple(s(35, 56))], fill=WHITE)
    d.rectangle(s(9, 20, 56, 20 + w), fill=WHITE)
    d.rectangle(s(8, 37, 55, 37 + w), fill=WHITE)
    return img


ICONS = {"chat": chat, "channels": channels}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, draw in ICONS.items():
        img = draw().resize((SIZE, SIZE), Image.LANCZOS)
        path = OUT / f"icon-{name}.tga"
        img.save(path)
        print(path.relative_to(ART.parent))


if __name__ == "__main__":
    main()
