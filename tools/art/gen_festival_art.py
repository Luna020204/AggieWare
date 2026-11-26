"""Generate SCRUM-75 pixel art following Luna's team convention.

Install Pillow, then run: python tools/art/gen_festival_art.py
Use --check to verify committed PNGs match the generated pixel data.
Backgrounds use 256x144; sprites use the same 1/5-resolution grid.
Godot displays them at 5x with nearest filtering. No external artwork.
"""
import argparse
from pathlib import Path
from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parents[2] / 'assets/art/microgames'


def assets():
    # ECS 179 demonstration station in Kemper Hall, UC Davis.
    background = Image.new('RGBA', (256, 144), '#c1b49d')
    draw = ImageDraw.Draw(background)
    draw.rectangle((0, 0, 255, 19), fill='#243b52')
    draw.text((84, 4), 'KEMPER HALL', fill='#ffd04d')
    for x in (4, 228):
        draw.rectangle((x, 26, x+23, 98), fill='#556d7a')
        draw.rectangle((x+2, 28, x+21, 96), fill='#8daab0')
        draw.line((x+12, 28, x+12, 96), fill='#304557', width=2)
    draw.rectangle((7, 23, 249, 129), fill='#172735')
    draw.rectangle((11, 27, 245, 125), fill='#253d50')
    draw.rectangle((0, 130, 255, 143), fill='#705944')
    draw.rectangle((94, 131, 163, 140), fill='#384956')
    for x in range(98, 160, 6):
        draw.line((x, 133, x, 137), fill='#8a9a9c')
    draw.rectangle((176, 132, 190, 139), fill='#b5b8a7')
    vessel = Image.new('RGBA', (16, 11))
    draw = ImageDraw.Draw(vessel)
    draw.rectangle((0, 3, 15, 7), fill='#9ad2db')
    draw.rectangle((4, 0, 11, 3), fill='#4d8dbb')
    draw.rectangle((6, 1, 9, 2), fill='#ffbf00')
    for x in (3, 10):
        draw.rectangle((x, 8, x + 2, 10), fill='#f28553')
    frame = Image.new('RGBA', (43, 33))
    draw = ImageDraw.Draw(frame)
    draw.rectangle((0, 0, 42, 32), outline='white', width=1)
    draw.line((18, 16, 24, 16), fill='white')
    draw.line((21, 13, 21, 19), fill='white')
    shield = Image.new('RGBA', (42, 24))
    ImageDraw.Draw(shield).rectangle((0, 0, 41, 23), outline='white', width=2)
    gun = Image.new('RGBA', (18, 17))
    draw = ImageDraw.Draw(gun)
    draw.rectangle((0, 11, 17, 16), fill='#577494')
    draw.rectangle((4, 6, 13, 11), fill='#9ad2db')
    result = {}
    for game in ('position_lock', 'shield_break'):
        result[f'{game}/festival_bg.png'] = background
        result[f'{game}/vessel.png'] = vessel
    result['position_lock/camera_frame.png'] = frame
    result['shield_break/shield.png'] = shield
    result['shield_break/gun.png'] = gun
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    for relative, expected in assets().items():
        path = OUT / relative
        if args.check:
            with Image.open(path) as actual:
                if actual.size != expected.size or actual.convert('RGBA').tobytes() != expected.tobytes():
                    raise SystemExit(f'Generated pixels differ: {relative}')
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            expected.save(path)
        print(('Verified ' if args.check else 'Wrote ') + relative)


if __name__ == '__main__':
    main()
