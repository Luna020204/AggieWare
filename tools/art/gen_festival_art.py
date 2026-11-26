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
    background = Image.new('RGBA', (256, 144), '#101a36')
    draw = ImageDraw.Draw(background)
    for i in range(45):
        draw.point((((i * 197 + 35) % 1260) // 5, ((i * 113 + 110) % 620) // 5), fill='#526582')
    draw.rectangle((0, 130, 255, 143), fill='#233956')
    for x in range(0, 256, 16):
        draw.rectangle((x, 130, x + 7, 131), fill='#ffbf00')
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
