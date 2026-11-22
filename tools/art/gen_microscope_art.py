"""Generates the pixel art for the Microscope microgame (SCRUM-84).

The round opens outside the science lab building (beige tiled walls, red
window frames, a glass stair tower over the entrance, a big pink flowering
tree on the lawn) as a student in a lab
coat and goggles walks in. Play happens in a teaching lab: a bench with a
microscope, a clipboard showing the bacteria to find, and a monitor for the
slide map. The bacteria are small sprites drawn on the slide by the game.
Drawn at 1/5 of the 1280x720 layout and shown at 5x with nearest filtering,
lit from the upper left.

Run from the project root:  python tools/art/gen_microscope_art.py
Writes the PNGs to assets/art/microgames/microscope/.
"""

import random
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gen_swipe_card_art import CAPS, blob, dither, outline, outline_alpha, px, rect, vgrad, width, write  # noqa: E402

OUT = Path(__file__).resolve().parents[2] / "assets" / "art" / "microgames" / "microscope"
W, H = 256, 144
LAB_DOOR = (116, 94, 140, 122)  # the entrance doors, in scene pixels
MONITOR_SCREEN = (180, 84, 236, 116)  # where the game draws the slide map
CLIPBOARD_SHEET = (172, 30, 204, 70)  # where the game draws the bacteria to find
# The shared 3x5 capitals plus a space for the clipboard label.
LABEL = dict(CAPS, **{" ": ["."] * 5})

C = {
    "ink": (24, 22, 26),
    # building
    "sky_hi": (96, 160, 226), "sky": (132, 188, 240),
    "tile_hi": (236, 226, 208), "tile": (216, 204, 184), "tile_dk": (188, 176, 156), "tile_line": (170, 158, 140),
    "red_hi": (196, 92, 76), "red": (164, 66, 54), "red_dk": (120, 44, 38),
    "glass_hi": (168, 214, 236), "glass": (86, 150, 196), "glass_dk": (44, 90, 130), "glass_ink": (30, 58, 86),
    "roof": (150, 70, 56), "vent": (60, 60, 64),
    "walk": (216, 212, 202), "walk_dk": (188, 184, 174), "lawn_hi": (126, 186, 84), "lawn": (96, 160, 64),
    "brick": (172, 92, 70), "brick_dk": (132, 66, 50),
    "shrub_hi": (138, 168, 90), "shrub": (104, 134, 70), "shrub_dk": (72, 100, 52), "shrub_ink": (46, 66, 36),
    "flower": (232, 120, 170), "flower_dk": (190, 80, 130),
    "blossom_hi": (255, 196, 222), "blossom": (240, 150, 190), "blossom_dk": (204, 104, 152),
    "blossom_ink": (150, 66, 108),
    "lamp": (52, 54, 60), "lamp_hi": (110, 112, 120), "lamp_glass": (240, 236, 210),
    # lab
    "wall": (214, 222, 216), "wall_dk": (190, 200, 194), "cab": (236, 238, 234), "cab_dk": (200, 204, 200),
    "cab_line": (160, 166, 162), "shelf": (150, 112, 72), "shelf_dk": (110, 80, 50),
    "bench": (40, 42, 48), "bench_hi": (70, 74, 82), "base": (176, 182, 186), "base_dk": (140, 146, 150),
    "window_sky": (150, 200, 240), "window_frame": (230, 232, 230),
    "liquid_g": (90, 200, 120), "liquid_b": (90, 150, 230), "liquid_r": (230, 100, 90), "liquid_y": (240, 210, 80),
    "flask": (220, 236, 240), "flask_dk": (160, 186, 196),
    "scope": (230, 232, 236), "scope_dk": (140, 146, 156), "scope_ink": (60, 64, 72),
    "monitor": (30, 32, 38), "monitor_hi": (64, 68, 78), "screen": (14, 36, 28),
    "clip": (176, 132, 82), "clip_dk": (130, 94, 54), "paper": (246, 244, 236), "metal": (190, 196, 204),
    # student in a lab coat
    "hair": (58, 42, 30), "hair_hi": (90, 66, 46), "strap": (30, 30, 34), "lens": (150, 210, 230),
    "skin": (218, 170, 134), "skin_sh": (184, 136, 104),
    "coat_hi": (255, 255, 255), "coat": (236, 238, 242), "coat_sh": (196, 202, 212),
    "jeans": (52, 62, 92), "jeans_sh": (36, 42, 66), "shoe": (30, 30, 34),
    # bacteria
    "gold": (232, 184, 74), "gold_hi": (250, 220, 130), "gold_dk": (138, 95, 18), "navy": (31, 61, 122),
    "blue": (122, 167, 216), "blue_hi": (170, 204, 240), "blue_dk": (44, 79, 124),
    "rod": (127, 176, 105), "rod_hi": (170, 210, 140), "rod_dk": (53, 94, 59),
}


def lab_building():
    """The science lab building's entrance, 256x144, after the front photo."""
    img = Image.new("RGB", (W, H), C["sky"])
    vgrad(img, 0, 0, W, 24, C["sky_hi"], C["sky"])

    # Rooftop: red parapet and vents.
    rect(img, 20, 8, 236, 12, C["roof"])
    rect(img, 20, 8, 236, 9, C["red_hi"])
    for vx in (60, 186):
        rect(img, vx, 3, vx + 8, 8, C["vent"])
    # Tiled facade on both wings.
    rect(img, 20, 12, 236, 122, C["tile"])
    for y in range(12, 122, 6):
        rect(img, 20, y, 236, y + 1, C["tile_line"])
        offset = 0 if (y // 6) % 2 == 0 else 6
        for x in range(20 + offset, 236, 12):
            rect(img, x, y, x + 1, y + 6, C["tile_line"])
    rect(img, 20, 12, 236, 14, C["tile_hi"])
    rect(img, 20, 12, 22, 122, C["tile_hi"])
    rect(img, 234, 12, 236, 122, C["tile_dk"])

    # Three rows of windows with red frames and sills.
    for wy in (22, 52, 82):
        for wx in (28, 50, 72, 92, 154, 174, 196, 218):
            rect(img, wx - 1, wy - 1, wx + 13, wy + 15, C["red"])
            rect(img, wx - 1, wy - 1, wx + 13, wy, C["red_hi"])
            rect(img, wx + 1, wy + 1, wx + 11, wy + 13, C["glass_dk"])
            rect(img, wx + 6, wy + 1, wx + 7, wy + 13, C["red_dk"])
            for i in range(4):
                px(img, wx + 2 + i, wy + 11 - i, C["glass"])
            rect(img, wx - 2, wy + 15, wx + 14, wy + 17, C["red_dk"])

    # The glass stair tower over the entrance, framed in red.
    rect(img, 110, 14, 146, 96, C["red"])
    rect(img, 110, 14, 146, 16, C["red_hi"])
    rect(img, 113, 17, 143, 92, C["glass"])
    vgrad(img, 113, 17, 143, 60, C["glass_hi"], C["glass"])
    for y in range(26, 92, 10):
        rect(img, 113, y, 143, y + 1, C["glass_ink"])
    for x in (123, 133):
        rect(img, x, 17, x + 1, 92, C["glass_ink"])
    for i in range(16):
        px(img, 116 + i, 56 - i, C["glass_hi"])
        px(img, 117 + i, 56 - i, C["glass_hi"])
    rect(img, 110, 92, 146, 94, C["red_dk"])
    # Entrance doors.
    x0, y0, x1, y1 = LAB_DOOR
    rect(img, x0 - 2, y0, x1 + 2, y1, C["red_dk"])
    for dx0, dx1 in ((x0, x0 + 11), (x0 + 13, x1)):
        rect(img, dx0, y0, dx1, y1, C["glass_ink"])
        rect(img, dx0 + 1, y0 + 1, dx1 - 1, y1 - 1, C["glass_dk"])
        for i in range(6):
            px(img, dx0 + 2 + i, y0 + 12 - i, C["glass"])
    rect(img, x0 + 10, y0 + 14, x0 + 11, y0 + 20, C["metal"])
    rect(img, x0 + 13, y0 + 14, x0 + 14, y0 + 20, C["metal"])

    # Walkway to the doors, lawns, red brick planters with shrubs and flowers.
    rect(img, 0, 122, W, H, C["lawn"])
    rect(img, 0, 122, W, 124, C["lawn_hi"])
    for y in range(122, H):
        half = 14 + (y - 122)
        rect(img, 128 - half, y, 128 + half, y + 1, C["walk"])
    for y in range(124, H, 5):
        half = 14 + (y - 122)
        rect(img, 128 - half, y, 128 + half, y + 1, C["walk_dk"])
    for px0, px1 in ((40, 104), (152, 216)):
        rect(img, px0, 112, px1, 122, C["brick"])
        rect(img, px0, 112, px1, 113, C["red_hi"])
        rect(img, px0, 120, px1, 122, C["brick_dk"])
        for cx in range(px0 + 5, px1 - 2, 10):
            blob(img, cx, 109, 7, 5, C["shrub"], C["shrub_hi"], C["shrub_dk"], C["shrub_ink"])
        rng = random.Random(px0)
        for _ in range(10):
            fx, fy = rng.randint(px0 + 2, px1 - 3), rng.randint(105, 111)
            rect(img, fx, fy, fx + 2, fy + 1, C["flower"])
            px(img, fx, fy + 1, C["flower_dk"])

    # Lamp posts either side of the walk.
    for lx in (102, 152):
        rect(img, lx, 92, lx + 2, 124, C["lamp"])
        rect(img, lx, 92, lx + 1, 124, C["lamp_hi"])
        rect(img, lx - 2, 86, lx + 4, 92, C["lamp"])
        rect(img, lx - 1, 87, lx + 3, 91, C["lamp_glass"])

    # The big pink flowering tree on the left of the lawn.
    trunk, trunk_dk = C["clip_dk"], (92, 62, 36)
    rect(img, 22, 70, 30, 124, trunk)
    rect(img, 27, 70, 30, 124, trunk_dk)
    for i in range(14):  # two limbs reaching up into the crown
        rect(img, 22 - i, 76 - i * 2, 25 - i, 78 - i * 2, trunk)
        rect(img, 28 + i, 78 - i * 2, 31 + i, 80 - i * 2, trunk_dk)
    rect(img, 18, 122, 36, 124, trunk_dk)  # roots
    for cx, cy, rx, ry in ((14, 44, 14, 11), (40, 42, 15, 12), (26, 30, 15, 11), (6, 62, 10, 10),
                           (48, 60, 13, 10), (26, 56, 18, 12), (16, 74, 9, 6), (40, 74, 10, 6)):
        blob(img, cx, cy, rx, ry, C["blossom"], C["blossom_hi"], C["blossom_dk"], C["blossom_ink"])
    rng = random.Random(7)
    for _ in range(60):  # single flowers dotted through the crown
        fx, fy = rng.randint(0, 58), rng.randint(22, 78)
        if img.getpixel((fx, fy)) in (C["blossom"], C["blossom_dk"]):
            px(img, fx, fy, C["blossom_hi"] if rng.random() < 0.6 else (255, 236, 244))
    for _ in range(28):  # petals fallen on the lawn
        fx, fy = rng.randint(0, 70), rng.randint(124, H - 1)
        px(img, fx, fy, C["blossom_hi"])
    return img


def lab_door_open():
    """Both entrance doors swung open onto the lit lobby, laid over LAB_DOOR."""
    x0, y0, x1, y1 = LAB_DOOR
    w, h = x1 - x0, y1 - y0
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    vgrad(img, 0, 0, w, h, C["window_frame"], C["wall_dk"])
    rect(img, 0, h - 4, w, h, C["base"])  # lobby floor
    for dx0 in (0, w - 3):  # the open doors, edge-on
        rect(img, dx0, 0, dx0 + 3, h, C["glass_ink"])
        rect(img, dx0 + 1, 1, dx0 + 2, h - 1, C["glass"])
    return img


def coat_walker(frame):
    """The student from behind in a lab coat and goggles, 16x30. Frame 0 stands."""
    img = Image.new("RGBA", (16, 30), (0, 0, 0, 0))
    swing = {0: 0, 1: 1, 2: -1}[frame]
    # Hair with the goggle strap across the back of the head; lens edges at the sides.
    rect(img, 5, 0, 11, 7, C["hair"])
    rect(img, 6, 0, 9, 2, C["hair_hi"])
    rect(img, 4, 3, 12, 5, C["strap"])
    rect(img, 3, 3, 4, 5, C["lens"])
    rect(img, 12, 3, 13, 5, C["lens"])
    rect(img, 6, 7, 10, 8, C["skin_sh"])
    # Arms in white sleeves, swinging.
    rect(img, 2, 9 - swing, 4, 18 - swing, C["coat"])
    rect(img, 2, 18 - swing, 4, 20 - swing, C["skin"])
    rect(img, 12, 9 + swing, 14, 18 + swing, C["coat_sh"])
    rect(img, 12, 18 + swing, 14, 20 + swing, C["skin_sh"])
    # The lab coat, down to the knees, with a back seam and vent.
    rect(img, 4, 8, 12, 23, C["coat"])
    rect(img, 4, 8, 6, 23, C["coat_hi"])
    rect(img, 10, 8, 12, 23, C["coat_sh"])
    rect(img, 7, 8, 9, 9, C["coat_sh"])  # collar
    rect(img, 8, 15, 9, 23, C["coat_sh"])  # seam and vent
    rect(img, 4, 15, 12, 16, C["coat_sh"])  # belt
    # Jeans and shoes; the stepping leg is lifted.
    legs = {0: ((5, 7, 0), (9, 11, 0)), 1: ((5, 7, 2), (9, 11, 0)), 2: ((5, 7, 0), (9, 11, 2))}[frame]
    for lx0, lx1, lift in legs:
        rect(img, lx0, 23, lx1, 28 - lift, C["jeans"])
        rect(img, lx1 - 1, 23, lx1, 28 - lift, C["jeans_sh"])
        rect(img, lx0, 28 - lift, lx1, 30 - lift, C["shoe"])
    outline_alpha(img, C["ink"])
    return img


def lab_interior():
    """The teaching lab, 256x144: cabinets and shelves, a window, a black bench
    with a microscope, a clipboard on the wall and a monitor on the bench."""
    img = Image.new("RGB", (W, H), C["wall"])
    rect(img, 0, 0, W, 4, C["wall_dk"])
    # Upper cabinets across the back.
    rect(img, 0, 6, 156, 26, C["cab"])
    for x in range(0, 156, 26):
        outline(img, x, 6, x + 26, 26, C["cab_line"])
        rect(img, x + 11, 15, x + 15, 16, C["cab_line"])
    rect(img, 0, 26, 156, 28, C["cab_dk"])
    # Window with campus sky, on the right.
    rect(img, 208, 6, 252, 28, C["window_frame"])
    rect(img, 210, 8, 250, 26, C["window_sky"])
    rect(img, 229, 8, 231, 26, C["window_frame"])
    blob(img, 238, 22, 10, 5, C["shrub"], C["shrub_hi"], C["shrub_dk"])
    # Open shelf with flasks and beakers.
    rect(img, 0, 40, 40, 42, C["shelf"])
    rect(img, 0, 42, 40, 43, C["shelf_dk"])
    for fx, liquid in ((4, "liquid_g"), (14, "liquid_b"), (24, "liquid_r"), (32, "liquid_y")):
        rect(img, fx + 1, 30, fx + 3, 33, C["flask"])
        rect(img, fx, 33, fx + 5, 40, C["flask"])
        rect(img, fx, 36, fx + 5, 40, C[liquid])
        px(img, fx, 33, C["flask_dk"])
        outline(img, fx - 1, 32, fx + 6, 40, C["flask_dk"])
    # Clipboard on the wall (the game draws the bacteria on its sheet).
    x0, y0, x1, y1 = CLIPBOARD_SHEET
    rect(img, x0 - 3, y0 - 6, x1 + 3, y1 + 3, C["clip"])
    rect(img, x0 - 3, y1 + 2, x1 + 3, y1 + 3, C["clip_dk"])
    rect(img, x0, y0, x1, y1, C["paper"])
    rect(img, x0 + 10, y0 - 8, x1 - 10, y0 - 3, C["metal"])
    write(img, (x0 + x1) // 2 - width("FIND THIS", LABEL) // 2, y0 + 2, "FIND THIS", C["navy"], LABEL)
    for y in (y1 - 6, y1 - 4):
        rect(img, x0 + 4, y, x1 - 4, y + 1, C["cab_line"])

    # Bench: black top, grey cabinets below.
    rect(img, 0, 128, W, 132, C["bench"])
    rect(img, 0, 128, W, 129, C["bench_hi"])
    rect(img, 0, 132, W, H, C["base"])
    for x in range(0, W, 32):
        outline(img, x, 133, x + 32, H, C["base_dk"])
        rect(img, x + 14, 137, x + 18, 138, C["base_dk"])
    # Computer on the bench: a monitor on a stand, keyboard and mouse in front
    # (the game draws the slide map on its screen).
    x0, y0, x1, y1 = MONITOR_SCREEN
    mid = (x0 + x1) // 2
    rect(img, mid - 6, 125, mid + 6, 128, C["monitor"])  # stand foot
    rect(img, mid - 6, 125, mid + 6, 126, C["monitor_hi"])
    rect(img, mid - 2, y1 + 5, mid + 2, 125, C["monitor"])  # neck
    rect(img, mid, y1 + 5, mid + 2, 125, C["bench"])
    rect(img, x0 - 4, y0 - 4, x1 + 4, y1 + 6, C["monitor"])  # bezel with a chin
    rect(img, x0 - 4, y0 - 4, x1 + 4, y0 - 3, C["monitor_hi"])
    rect(img, x0 - 4, y0 - 4, x0 - 3, y1 + 6, C["monitor_hi"])
    rect(img, x0 - 1, y0 - 1, x1 + 1, y1 + 1, C["ink"])
    rect(img, x0, y0, x1, y1, C["screen"])
    rect(img, x1 - 2, y1 + 3, x1, y1 + 4, C["liquid_g"])  # power light
    # Keyboard and mouse.
    rect(img, x0 - 6, 125, x0 + 30, 128, C["base_dk"])
    rect(img, x0 - 6, 125, x0 + 30, 126, C["base"])
    for kx in range(x0 - 5, x0 + 29, 3):
        px(img, kx, 126, C["cab_line"])
    rect(img, x1 - 4, 126, x1 + 1, 128, C["base"])
    px(img, x1 - 2, 126, C["base_dk"])
    # The microscope itself, between the eyepiece view and the monitor.
    rect(img, 140, 124, 158, 128, C["scope_ink"])  # foot
    rect(img, 150, 98, 154, 124, C["scope"])  # arm
    rect(img, 153, 98, 154, 124, C["scope_dk"])
    rect(img, 142, 112, 156, 114, C["scope_dk"])  # stage
    rect(img, 144, 100, 150, 104, C["scope"])  # head
    rect(img, 142, 92, 146, 100, C["scope"])  # eyepiece tube
    rect(img, 141, 90, 147, 92, C["scope_ink"])
    rect(img, 146, 104, 148, 111, C["scope_dk"])  # objective
    return img


def bacteria(kind):
    """A bacterium sprite, 13x13 (the rod is 13x7)."""
    if kind == "rod":
        img = Image.new("RGBA", (13, 7), (0, 0, 0, 0))
        rect(img, 1, 1, 12, 6, C["rod"])
        rect(img, 1, 1, 12, 2, C["rod_hi"])
        rect(img, 1, 5, 12, 6, C["rod_dk"])
        outline_alpha(img, C["ink"])
        return img
    img = Image.new("RGBA", (13, 13), (0, 0, 0, 0))
    base, hi, dk = {"aggie": ("gold", "gold_hi", "gold_dk"), "gold": ("gold", "gold_hi", "gold_dk"),
                    "blue": ("blue", "blue_hi", "blue_dk")}[kind]
    for y in range(3, 13):
        for x in range(0, 13):
            if ((x - 6) / 6.2) ** 2 + ((y - 8) / 4.6) ** 2 <= 1.0:
                px(img, x, y, C[base])
    rect(img, 3, 4, 7, 5, C[hi])
    if kind == "aggie":
        for hx in (2, 9):  # two horns
            rect(img, hx, 1, hx + 2, 4, C["gold_dk"])
            px(img, hx + (0 if hx < 6 else 1), 0, C["gold_dk"])
        write(img, 5, 6, "A", C["navy"], CAPS)
    elif kind == "gold":
        rect(img, 5, 7, 8, 10, C["gold_dk"])
    else:
        rect(img, 3, 7, 5, 9, C["blue_dk"])
        rect(img, 8, 9, 10, 11, C["blue_dk"])
    outline_alpha(img, C["ink"])
    return img


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    lab_building().save(OUT / "lab_building.png")
    lab_door_open().save(OUT / "lab_door_open.png")
    for frame in range(3):
        coat_walker(frame).save(OUT / f"student_coat_{frame}.png")
    lab_interior().save(OUT / "lab_interior.png")
    for kind in ("aggie", "gold", "blue", "rod"):
        bacteria(kind).save(OUT / f"bacteria_{kind}.png")
    print("wrote", OUT)


if __name__ == "__main__":
    main()
