"""Contact sheet of a generated set, for quick review.

Usage: art/.venv/Scripts/python art/contact.py art/out/<set> [--thumb 256]
Writes art/out/<set>/_contact.png: one row per item, labelled with item name and seed.
"""

import argparse
from pathlib import Path

from PIL import Image, ImageDraw


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("setdir", type=Path)
    ap.add_argument("--thumb", type=int, default=256)
    args = ap.parse_args()

    rows = []
    for item in sorted(p for p in args.setdir.iterdir() if p.is_dir()):
        images = sorted(item.glob("*.png"), key=lambda p: int(p.stem) if p.stem.isdigit() else 0)
        if images:
            rows.append((item.name, images))

    t, label = args.thumb, 18
    cols = max(len(images) for _, images in rows)
    sheet = Image.new("RGB", (cols * t, len(rows) * (t + label)), (24, 24, 24))
    draw = ImageDraw.Draw(sheet)
    for r, (name, images) in enumerate(rows):
        y = r * (t + label)
        for c, path in enumerate(images):
            img = Image.open(path).convert("RGB")
            img.thumbnail((t, t))
            sheet.paste(img, (c * t + (t - img.width) // 2, y + label + (t - img.height) // 2))
            draw.text((c * t + 4, y + 3), f"{name} {path.stem}", fill=(230, 230, 230))
    out = args.setdir / "_contact.png"
    sheet.save(out)
    print(out)


if __name__ == "__main__":
    main()
