"""Generates the pixel art for the Stay Awake microgame (SCRUM-76).

The scene is the ECS 179 lecture hall: wood-panelled walls, the projector
screen with a game being played on it, the professor at the lectern with a
controller and a console, and rows of green seats, seen from the middle rows. A drowsy
student sits in the middle, seen from behind, and pixel Z's drift toward
their head. Drawn at 1/5 of the 1280x720 layout and shown at 5x with nearest
filtering, lit from the ceiling.

Run from the project root:  python tools/art/gen_stay_awake_art.py
Writes the PNGs to assets/art/microgames/stay_awake/.
"""

import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import random  # noqa: E402

from gen_swipe_card_art import CAPS, blob, dither, outline, outline_alpha, px, rect, vgrad, width, write  # noqa: E402

OUT = Path(__file__).resolve().parents[2] / "assets" / "art" / "microgames" / "stay_awake"
W, H = 256, 144
# Chalk lettering: the shared capitals plus the digits the board needs.
CHALK = dict(CAPS, **{"1": [".#.", "##.", ".#.", ".#.", "###"], "7": ["###", "..#", ".#.", ".#.", ".#."],
                      "9": ["###", "#.#", "###", "..#", "##."]})
HEAD = (128, 94)
SCREEN_RECT = (88, 50, 172, 76)  # the projected game, in scene pixels
PROFESSOR_POS = (92, 66)  # top-left of the professor sprite, in scene pixels  # the student's head centre in scene pixels (640, 470 on screen)

C = {
    "ceil": (226, 224, 216), "ceil_dk": (196, 194, 186), "ceil_line": (170, 168, 160),
    "light": (252, 250, 238), "light_glow": (238, 236, 222), "beam": (206, 204, 196),
    "wall": (232, 226, 210), "wall_dk": (210, 204, 188),
    "wood_hi": (168, 104, 58), "wood": (138, 82, 44), "wood_dk": (104, 60, 32), "wood_ink": (74, 42, 22),
    "frame": (196, 200, 204), "frame_dk": (150, 154, 160),
    "screen": (240, 238, 228), "screen_dk": (216, 214, 204),
    "board": (34, 38, 36), "board_lt": (52, 58, 54), "chalk": (214, 220, 214), "chalk_dk": (150, 158, 152),
    "clock": (246, 246, 242), "clock_ink": (40, 40, 44),
    "speaker": (204, 204, 200), "speaker_dk": (160, 160, 156),
    "exit": (60, 200, 110), "exit_dk": (28, 120, 60),
    "proj": (30, 30, 34), "proj_lt": (70, 70, 78), "lens": (120, 160, 210),
    "desk_top": (214, 190, 150), "desk": (40, 38, 42), "monitor": (22, 22, 26), "monitor_lt": (60, 64, 72),
    "floor": (120, 112, 104), "floor_dk": (98, 92, 86),
    "seat_hi": (118, 146, 104), "seat": (80, 106, 72), "seat_dk": (50, 70, 46), "seat_ink": (28, 40, 28),
    "arm": (188, 160, 120), "arm_dk": (140, 116, 84),
    "ink": (24, 22, 26),
    # the student and the Z's
    "hair": (58, 42, 30), "hair_hi": (90, 66, 46), "skin": (218, 170, 134), "skin_sh": (184, 136, 104),
    "hood_hi": (120, 120, 170), "hood": (88, 88, 136), "hood_dk": (62, 62, 104),
    "console": (240, 242, 246), "console_hi": (255, 255, 255), "console_dk": (40, 40, 46), "cable": (30, 30, 34),
    "prof_hair": (110, 78, 52), "prof_hair_hi": (146, 108, 74), "prof_hair_dk": (70, 48, 32), "stubble": (170, 128, 98), "sweater": (34, 36, 46), "sweater_hi": (56, 58, 72),
    "pants": (40, 40, 48), "pad": (24, 24, 28), "pad_hi": (70, 70, 80),
    "sky_hi": (110, 170, 240), "sky": (150, 200, 250), "hill": (110, 180, 110), "hill_dk": (80, 150, 90),
    "ground": (120, 80, 50), "grass": (90, 190, 80), "grass_hi": (150, 220, 110), "block": (210, 150, 70), "block_dk": (160, 100, 40),
    "coin": (255, 210, 60), "coin_dk": (210, 150, 20), "hero": (220, 60, 60), "hero_dk": (150, 30, 40), "blob": (130, 70, 170),
    "z": (226, 216, 255), "z_hi": (255, 255, 255), "z_dk": (168, 150, 220), "z_ink": (26, 20, 48),
}


def seat_row(img, y, h, seat_w, gap, colors=C, skip=None):
    """A row of seat backs from behind; `skip` leaves a gap (x0, x1) for the student."""
    x = -((seat_w + gap) // 2)
    while x < W:
        x0, x1 = x, x + seat_w
        if skip is None or x1 <= skip[0] or x0 >= skip[1]:
            rect(img, x0, y, x1, y + h, colors["seat"])
            rect(img, x0, y, x1, y + 1, colors["seat_hi"])
            rect(img, x0, y, x0 + 1, y + h, colors["seat_hi"])
            rect(img, x1 - 1, y + 1, x1, y + h, colors["seat_dk"])
            rect(img, x0 + 1, y + h - max(h // 4, 1), x1 - 1, y + h, colors["seat_dk"])
            outline(img, x0 - 1, y - 1, x1 + 1, y + h, colors["seat_ink"])
            rect(img, x1, y + h // 3, x1 + gap, y + h // 3 + max(h // 6, 1), colors["arm"])
        x += seat_w + gap


def lecture_hall():
    img = Image.new("RGB", (W, H), C["wall"])

    # Ceiling: tiles, recessed light panels, beams.
    rect(img, 0, 0, W, 30, C["ceil"])
    for x in range(0, W, 16):
        rect(img, x, 0, x + 1, 30, C["ceil_line"])
    for y in (8, 18):
        rect(img, 0, y, W, y + 1, C["ceil_line"])
    for x0, y0 in ((16, 2), (64, 2), (176, 2), (224, 2), (32, 11), (200, 11), (88, 20), (152, 20)):
        rect(img, x0, y0, x0 + 18, y0 + 4, C["light"])
        rect(img, x0 - 1, y0 + 4, x0 + 19, y0 + 5, C["light_glow"])
    for x in (60, 196):
        rect(img, x, 0, x + 3, 30, C["beam"])
    rect(img, 0, 27, W, 30, C["beam"])
    rect(img, 0, 30, W, 31, C["ceil_dk"])

    # Projector hanging from the ceiling.
    rect(img, 127, 0, 129, 12, C["proj"])
    rect(img, 116, 12, 140, 22, C["proj"])
    rect(img, 116, 12, 140, 13, C["proj_lt"])
    for x in (120, 126, 132):
        rect(img, x, 15, x + 4, 19, C["proj_lt"])
        px(img, x + 1, 16, C["lens"])

    # Upper wall, then wood panelling with doors on both sides.
    rect(img, 0, 31, W, 54, C["wall"])
    rect(img, 0, 50, W, 54, C["wall_dk"])
    rect(img, 0, 54, W, 98, C["wood"])
    for x in range(0, W, 12):
        rect(img, x, 54, x + 1, 98, C["wood_dk"])
        rect(img, x + 1, 54, x + 2, 98, C["wood_hi"])
    rect(img, 0, 54, W, 56, C["wood_hi"])
    rect(img, 0, 76, W, 77, C["wood_dk"])
    for x0 in (60, 186):  # doors
        rect(img, x0, 58, x0 + 16, 98, C["wood_dk"])
        rect(img, x0 + 1, 59, x0 + 15, 98, C["wood"])
        rect(img, x0 + 12, 78, x0 + 14, 79, C["frame"])
    rect(img, 188, 51, 196, 55, C["exit"])
    rect(img, 188, 54, 196, 55, C["exit_dk"])
    # Clock and wall speakers.
    rect(img, 82, 38, 90, 46, C["clock"])
    outline(img, 82, 38, 90, 46, C["clock_ink"])
    rect(img, 86, 40, 87, 43, C["clock_ink"])
    rect(img, 86, 42, 89, 43, C["clock_ink"])
    for x0 in (50, 198):
        rect(img, x0, 40, x0 + 10, 46, C["speaker"])
        rect(img, x0, 45, x0 + 10, 46, C["speaker_dk"])

    # The projector screen, pulled down over the boards. The game being played
    # on it is drawn separately (game_screen) and animated in the game.
    rect(img, 82, 47, 178, 80, C["frame"])
    rect(img, 82, 79, 178, 80, C["frame_dk"])
    rect(img, 84, 49, 176, 78, C["screen"])
    rect(img, 80, 46, 180, 48, C["frame_dk"])  # screen case
    x0, y0, x1, y1 = SCREEN_RECT
    rect(img, x0 - 1, y0 - 1, x1 + 1, y1 + 1, C["board"])

    # Lectern with the course name on its front, and a strip of floor.
    rect(img, 0, 96, W, 100, C["floor"])
    rect(img, 0, 99, W, 100, C["floor_dk"])
    rect(img, 108, 88, 150, 91, C["desk_top"])
    rect(img, 110, 91, 148, 98, C["desk"])
    write(img, 129 - width("ECS179", CHALK) // 2, 92, "ECS179", C["chalk"], CHALK)
    rect(img, 116, 83, 128, 88, C["monitor"])
    rect(img, 117, 84, 127, 87, C["monitor_lt"])
    # A white game console standing on the desk, with its cable.
    rect(img, 138, 81, 145, 88, C["console"])
    rect(img, 141, 81, 142, 88, C["console_dk"])
    rect(img, 138, 81, 139, 88, C["console_hi"])
    outline(img, 137, 80, 146, 88, C["ink"])
    rect(img, 108, 86, 138, 87, C["cable"])

    # Rows of seats, far to near, growing larger; the student sits mid-row.
    rect(img, 0, 100, W, H, C["seat_ink"])  # shadow between and under the seats
    rows = ((96, 4, 9, 2), (102, 5, 11, 2), (109, 7, 13, 3), (118, 9, 16, 3), (129, 11, 20, 4), (141, 12, 24, 4))
    for i, (y, h, sw, gap) in enumerate(rows):
        seat_row(img, y, h, sw, gap, skip=(114, 142) if i == 2 else None)
    return img


def professor():
    """Our ECS 179 professor, 16x30, holding a game controller: swept-back brown
    hair, a moustache and stubble, and a dark long-sleeved top. Drawn as its own
    layer so he stands in front of the projector screen."""
    img = Image.new("RGBA", (16, 30), (0, 0, 0, 0))
    # Swept-back hair, fuller on top, with a highlight.
    rect(img, 5, 0, 12, 1, C["prof_hair"])
    rect(img, 4, 1, 13, 4, C["prof_hair"])
    rect(img, 5, 1, 10, 2, C["prof_hair_hi"])
    rect(img, 4, 3, 5, 6, C["prof_hair"])
    rect(img, 12, 3, 13, 6, C["prof_hair_dk"])
    # Face.
    rect(img, 5, 3, 12, 11, C["skin"])
    rect(img, 11, 4, 12, 11, C["skin_sh"])
    rect(img, 5, 5, 7, 6, C["prof_hair_dk"])  # brows
    rect(img, 9, 5, 11, 6, C["prof_hair_dk"])
    px(img, 6, 6, C["ink"])  # eyes
    px(img, 9, 6, C["ink"])
    px(img, 8, 7, C["skin_sh"])  # nose
    # Moustache, drooping a little at the ends, and stubble along the jaw.
    rect(img, 6, 8, 11, 9, C["prof_hair_dk"])
    px(img, 6, 9, C["prof_hair_dk"])
    px(img, 10, 9, C["prof_hair_dk"])
    rect(img, 7, 9, 10, 10, C["skin_sh"])
    for x, y in ((5, 9), (5, 10), (6, 10), (8, 10), (10, 10), (11, 9), (11, 10)):
        px(img, x, y, C["stubble"])
    rect(img, 7, 11, 10, 12, C["skin_sh"])  # neck
    # Dark long-sleeved top.
    rect(img, 3, 12, 13, 23, C["sweater"])
    rect(img, 3, 12, 5, 23, C["sweater_hi"])
    rect(img, 7, 12, 10, 13, C["sweater_hi"])  # crew neck
    rect(img, 2, 13, 4, 19, C["sweater"])
    rect(img, 12, 13, 14, 19, C["sweater"])
    # Controller held in both hands.
    rect(img, 4, 17, 12, 20, C["pad"])
    rect(img, 5, 17, 7, 18, C["pad_hi"])
    rect(img, 9, 18, 11, 19, C["pad_hi"])
    rect(img, 3, 17, 4, 20, C["skin"])
    rect(img, 12, 17, 13, 20, C["skin_sh"])
    # Trousers.
    rect(img, 4, 23, 12, 30, C["pants"])
    rect(img, 7, 25, 9, 30, (24, 24, 30))
    outline_alpha(img, C["ink"])
    return img


def game_screen(frame):
    """The platformer being played on the projector screen, 84x32. Frame 1 jumps."""
    x0, y0, x1, y1 = SCREEN_RECT
    img = Image.new("RGB", (x1 - x0, y1 - y0), C["sky"])
    w, h = img.size
    vgrad(img, 0, 0, w, 14, C["sky_hi"], C["sky"])
    for hx, hr in ((14, 10), (40, 14), (70, 9)):
        for y in range(h - 6 - hr, h - 6):
            half = int((hr * hr - (y - (h - 6)) ** 2) ** 0.5) if hr * hr > (y - (h - 6)) ** 2 else 0
            rect(img, hx - half, y, hx + half, y + 1, C["hill"] if hx != 40 else C["hill_dk"])
    rect(img, 0, h - 6, w, h, C["ground"])
    rect(img, 0, h - 6, w, h - 4, C["grass"])
    rect(img, 0, h - 6, w, h - 5, C["grass_hi"])
    for bx, by in ((24, 9), (32, 9), (56, 6), (64, 6)):
        rect(img, bx, by, bx + 8, by + 4, C["block"])
        rect(img, bx, by + 3, bx + 8, by + 4, C["block_dk"])
        px(img, bx, by, C["coin"])
    for i, (cx, cy) in enumerate(((28, 4), (60, 1), (76, 12))):
        if (i + frame) % 2 == 0:
            rect(img, cx, cy, cx + 2, cy + 3, C["coin"])
            px(img, cx + 1, cy + 2, C["coin_dk"])
        else:
            rect(img, cx, cy, cx + 1, cy + 3, C["coin"])
    # The hero: on the ground, or mid-jump.
    hx, hy = (34, h - 13) if frame == 0 else (40, h - 19)
    rect(img, hx, hy, hx + 5, hy + 2, C["hero"])
    rect(img, hx + 1, hy + 2, hx + 4, hy + 4, C["skin"])
    rect(img, hx, hy + 4, hx + 5, hy + 7, C["hero_dk"])
    # A wandering blob.
    bx = 46 if frame == 0 else 48
    rect(img, bx, h - 10, bx + 5, h - 6, C["blob"])
    px(img, bx + 1, h - 9, C["white"] if "white" in C else (255, 255, 255))
    px(img, bx + 3, h - 9, (255, 255, 255))
    write(img, 2, 1, "SCORE", (255, 255, 255), CAPS)
    rect(img, 22, 1, 24 + frame * 2, 6, C["coin"])  # the score ticks up
    return img


def student(drowsy):
    """The student from behind, 28x26, in their seat. Drowsy drops and tilts the head."""
    img = Image.new("RGBA", (28, 26), (0, 0, 0, 0))
    # Seat back behind the shoulders.
    rect(img, 1, 10, 27, 26, C["seat"])
    rect(img, 1, 10, 27, 11, C["seat_hi"])
    rect(img, 1, 10, 2, 26, C["seat_hi"])
    rect(img, 26, 11, 27, 26, C["seat_dk"])
    # Hoodie shoulders.
    rect(img, 5, 13, 23, 26, C["hood"])
    rect(img, 5, 13, 23, 14, C["hood_hi"])
    rect(img, 5, 13, 8, 26, C["hood_hi"])
    rect(img, 20, 14, 23, 26, C["hood_dk"])
    rect(img, 11, 13, 17, 16, C["hood_dk"])  # hood bunched at the neck
    # Head: hair from behind, ears; drowsy sinks 2 px and leans right.
    dy = 2 if drowsy else 0
    dx = 1 if drowsy else 0
    rect(img, 9 + dx, 2 + dy, 19 + dx, 13 + dy, C["hair"])
    rect(img, 10 + dx, 1 + dy, 18 + dx, 2 + dy, C["hair"])
    rect(img, 10 + dx, 2 + dy, 13 + dx, 6 + dy, C["hair_hi"])
    px(img, 8 + dx, 7 + dy, C["skin"])
    px(img, 19 + dx, 7 + dy, C["skin_sh"])
    rect(img, 12 + dx, 13 + dy, 16 + dx, 14 + dy, C["skin_sh"])
    outline_alpha(img, C["ink"])
    return img


def z_sprite(size):
    """A floating Z, size x size, with an outline and a highlight."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    t = max(size // 5, 2)  # stroke
    m = 1
    rect(img, m, m, size - m, m + t, C["z"])
    rect(img, m, size - m - t, size - m, size - m, C["z"])
    for i in range(size - 2 * m - 2 * t):
        x = size - m - t - i
        y = m + t + i
        rect(img, x - t // 2 - 1, y, x + t // 2, y + 1, C["z"])
    rect(img, m, m, size - m, m + 1, C["z_hi"])
    rect(img, m, size - m - 1, size - m, size - m, C["z_dk"])
    outline_alpha(img, C["z_ink"])
    return img


BUILDING = {
    "sky": (170, 214, 244), "sky_hi": (140, 196, 236),
    "conc_hi": (238, 230, 214), "conc": (220, 210, 190), "conc_md": (198, 188, 168), "conc_dk": (166, 156, 138),
    "conc_ink": (120, 112, 98),
    "win": (40, 56, 80), "win_lt": (78, 104, 132), "win_hi": (160, 190, 210), "mullion": (186, 178, 160),
    "door_glass": (34, 44, 58), "door_frame": (90, 96, 102), "door_lt": (120, 150, 170),
    "interior": (70, 60, 50), "interior_lt": (210, 196, 160),
    "hedge_hi": (104, 150, 76), "hedge": (70, 116, 56), "hedge_dk": (44, 82, 40), "hedge_ink": (30, 56, 30),
    "leaf_hi": (150, 196, 92), "leaf": (110, 160, 70), "leaf_dk": (74, 120, 52), "leaf_ink": (48, 84, 38),
    "branch": (96, 84, 72), "branch_dk": (64, 56, 48),
    "red_hi": (226, 96, 86), "red": (190, 60, 56), "red_dk": (130, 40, 40),
    "walk": (214, 206, 192), "walk_dk": (186, 178, 164), "lawn": (106, 156, 72), "lawn_dk": (82, 130, 58),
    "lamp": (60, 62, 66), "lamp_hi": (110, 112, 118),
}
BUILDING_DOOR = (194, 84, 226, 122)  # the entrance doors, in scene pixels


def building_exterior():
    """The lecture building's entrance, 256x144: a beige concrete block with a grid
    of windows, a canopy over the glass doors, hedges, a lamp and a tree, lit
    from the upper left."""
    B = BUILDING
    img = Image.new("RGB", (W, H), B["sky"])
    vgrad(img, 0, 0, W, 8, B["sky_hi"], B["sky"])

    # The facade: four upper floors of windows between ledges.
    rect(img, 0, 4, W, 122, B["conc"])
    for y0 in (8, 27, 46, 65):
        rect(img, 0, y0 - 2, W, y0, B["conc_hi"])  # ledge
        rect(img, 0, y0, W, y0 + 1, B["conc_dk"])  # its shadow
        for x0 in range(4, W, 22):
            rect(img, x0, y0 + 3, x0 + 18, y0 + 15, B["win"])
            rect(img, x0, y0 + 3, x0 + 18, y0 + 4, B["conc_ink"])  # recess shadow
            rect(img, x0, y0 + 3, x0 + 1, y0 + 15, B["conc_ink"])
            for mx in (x0 + 6, x0 + 12):
                rect(img, mx, y0 + 4, mx + 1, y0 + 15, B["mullion"])
            for i in range(4):
                px(img, x0 + 2 + i, y0 + 13 - i, B["win_lt"])
            px(img, x0 + 14, y0 + 6, B["win_hi"])
        for x0 in range(0, W, 22):
            rect(img, x0 + 1, y0 + 1, x0 + 3, y0 + 17, B["conc_md"])  # piers
    rect(img, 0, 82, W, 84, B["conc_hi"])
    rect(img, 0, 84, W, 85, B["conc_dk"])

    # Ground floor: windows, mostly behind the hedges.
    for x0 in range(4, 180, 22):
        rect(img, x0, 88, x0 + 18, 110, B["win"])
        rect(img, x0, 88, x0 + 18, 89, B["conc_ink"])
        rect(img, x0 + 9, 89, x0 + 10, 110, B["mullion"])

    # Entrance: canopy on two columns, glass doors and side lights.
    rect(img, 182, 78, 244, 82, B["conc_hi"])
    rect(img, 182, 82, 244, 84, B["conc_dk"])
    for cx in (184, 238):
        rect(img, cx, 84, cx + 3, 122, B["conc"])
        rect(img, cx + 2, 84, cx + 3, 122, B["conc_dk"])
    rect(img, 188, 84, 238, 122, B["conc_md"])
    x0, y0, x1, y1 = BUILDING_DOOR
    rect(img, x0 - 4, y0, x0, y1, B["door_glass"])
    rect(img, x1, y0, x1 + 6, y1, B["door_glass"])
    for dx0, dx1 in ((x0, x0 + 15), (x0 + 17, x1)):
        rect(img, dx0, y0, dx1, y1, B["door_frame"])
        rect(img, dx0 + 2, y0 + 2, dx1 - 2, y1 - 2, B["door_glass"])
        for i in range(8):
            px(img, dx0 + 3 + i, y0 + 16 - i, B["door_lt"])
    rect(img, x0 + 13, y0 + 18, x0 + 14, y0 + 24, B["door_lt"])
    rect(img, x0 + 18, y0 + 18, x0 + 19, y0 + 24, B["door_lt"])

    # Walkway to the doors and a lawn on the right.
    rect(img, 0, 122, W, H, B["walk"])
    for x in range(0, W, 24):
        rect(img, x, 122, x + 1, H, B["walk_dk"])
    rect(img, 0, 122, W, 123, B["walk_dk"])
    rect(img, 236, 128, W, H, B["lawn"])
    rect(img, 236, 128, W, 129, B["lawn_dk"])

    # Hedges along the base, as shaded clumps.
    for cx in range(4, 176, 12):
        blob(img, cx, 116, 9, 7, B["hedge"], B["hedge_hi"], B["hedge_dk"], B["hedge_ink"])
    for cx in (248, 258):
        blob(img, cx, 117, 9, 7, B["hedge"], B["hedge_hi"], B["hedge_dk"], B["hedge_ink"])
    # Red flowering shrubs in front on the left.
    for cx, cy in ((10, 136), (26, 140), (44, 138), (62, 141)):
        blob(img, cx, cy, 10, 6, B["red"], B["red_hi"], B["red_dk"], B["hedge_ink"])

    # Street lamp by the entrance.
    rect(img, 246, 80, 248, 124, B["lamp"])
    rect(img, 246, 80, 247, 124, B["lamp_hi"])
    rect(img, 243, 77, 251, 80, B["lamp"])

    # The tree in the foreground: a curved branch from the left, with a fork,
    # and dense leaf clusters along its upper end.
    import math
    for start, length, slope, thick in (((0, 116), 74, 1.15, 4), ((44, 66), 46, 0.45, 3)):
        sx, sy = start
        for i in range(length):
            x = sx + i
            y = int(sy - i * slope - math.sin(i / 14.0) * 4)
            t = max(thick - i // 30, 2)
            rect(img, x, y, x + 2, y + t, B["branch"])
            px(img, x, y, (140, 126, 110))
            px(img, x + 1, y + t - 1, B["branch_dk"])
    rng = random.Random(31)
    for _ in range(44):
        cx = rng.randint(0, 140)
        cy = rng.randint(0, 44)
        if cy > 50 - cx * 0.25:
            continue
        blob(img, cx, cy, rng.randint(5, 9), rng.randint(4, 6), B["leaf"], B["leaf_hi"], B["leaf_dk"], B["leaf_ink"])
    return img


def building_door_open():
    """The left entrance door swung open, laid over BUILDING_DOOR."""
    B = BUILDING
    x0, y0, x1, y1 = BUILDING_DOOR
    img = Image.new("RGBA", (x1 - x0, y1 - y0), (0, 0, 0, 0))
    rect(img, 0, 0, 15, y1 - y0, B["door_frame"])
    vgrad(img, 2, 2, 13, y1 - y0 - 2, B["interior_lt"], B["interior"])
    rect(img, 0, 0, 3, y1 - y0, B["conc_ink"])
    return img


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    lecture_hall().save(OUT / "lecture_hall.png")
    building_exterior().save(OUT / "building_exterior.png")
    building_door_open().save(OUT / "building_door_open.png")
    professor().save(OUT / "professor.png")
    for frame in range(2):
        game_screen(frame).save(OUT / f"projector_game_{frame}.png")
    student(False).save(OUT / "student_awake.png")
    student(True).save(OUT / "student_drowsy.png")
    for size in (15, 12, 9):
        z_sprite(size).save(OUT / f"z_{size}.png")
    print("wrote", OUT)


if __name__ == "__main__":
    main()
