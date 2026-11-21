"""Generates the pixel art for the Swipe Card microgame (SCRUM-72).

The scene is the Peet's Coffee counter on the UC Davis campus, where students
pay with Aggie Cash. Everything is drawn from scratch at 1/5 of the game's
1280x720 layout, with outlines, shading and dithering, and the game shows it
at 5x with nearest filtering.

Run from the project root:  python tools/art/gen_swipe_card_art.py
Writes the PNGs to assets/art/microgames/swipe_card/.
"""

import random
from pathlib import Path

from PIL import Image

OUT = Path(__file__).resolve().parents[2] / "assets" / "art" / "microgames" / "swipe_card"
W, H = 256, 144
COUNTER_TOP = 102  # the reader stands on this row

P = {
    # room
    "ceil": (226, 216, 196), "ceil_dk": (196, 184, 160), "recess": (255, 250, 232),
    "track": (34, 32, 36), "spot": (255, 236, 170), "spot_glow": (236, 206, 150),
    "wall": (200, 170, 122), "wall_dk": (178, 148, 104), "wall_lt": (214, 186, 140),
    "ink": (20, 18, 22),
    "wood": (98, 64, 40), "wood_dk": (66, 42, 26), "wood_lt": (128, 88, 56),
    "mos_a": (170, 140, 100), "mos_b": (132, 104, 72), "mos_c": (190, 162, 120),
    # entrance
    "frame": (70, 74, 80), "frame_lt": (120, 126, 132),
    "sky": (196, 226, 240), "sky_lt": (230, 244, 250), "glass": (150, 196, 218),
    "bush": (96, 150, 84), "bush_dk": (60, 108, 60), "bush_lt": (140, 186, 110),
    "mat": (30, 80, 104), "mat_lt": (44, 104, 132),
    # signage
    "sign": (58, 52, 50), "board": (30, 24, 24), "board_lt": (56, 46, 44), "board_txt": (226, 210, 170),
    "drink_o": (232, 150, 52), "drink_r": (196, 70, 52), "drink_lt": (250, 214, 140),
    # counter
    "marble": (238, 234, 226), "marble_dk": (204, 198, 188), "marble_lt": (252, 250, 246),
    "black": (26, 25, 30), "black_lt": (44, 42, 50), "black_dk": (14, 13, 16),
    "glass_g": (210, 232, 236), "post": (40, 40, 44),
    # floor
    "floor": (108, 102, 72), "floor_dk": (84, 80, 56), "floor_lt": (150, 144, 108), "floor_sh": (180, 176, 140),
    "decal": (34, 160, 210), "white": (255, 255, 255),
    # props
    "case": (40, 40, 46), "case_glass": (184, 222, 234), "case_lt": (226, 242, 248),
    "pastry": (206, 140, 70), "pastry_dk": (150, 92, 42), "pastry_lt": (240, 196, 120),
    "steel": (190, 196, 202), "steel_dk": (120, 128, 136), "steel_lt": (230, 234, 238),
    "red": (196, 56, 44), "cup": (246, 244, 238), "cup_dk": (206, 200, 190),
    "tea": (240, 170, 40), "tea_dk": (196, 120, 24), "tea_lt": (255, 214, 110), "tea_cap": (44, 40, 40),
    # barista
    "skin": (222, 176, 140), "skin_dk": (190, 140, 106), "cap": (28, 28, 32), "apron": (36, 30, 28), "shirt": (60, 56, 58),
    # Aggie colours
    "aggie_blue": (2, 40, 81), "aggie_gold": (255, 191, 0), "aggie_gold_dk": (214, 150, 0), "card_cyan": (0, 178, 227),
    "card_cyan_dk": (0, 140, 186),
    # reader
    "term": (52, 56, 64), "term_lt": (86, 92, 102), "term_dk": (30, 32, 38),
    "screen": (14, 38, 24), "screen_lt": (34, 70, 46), "screen_px": (90, 190, 120),
    "slot": (8, 10, 14), "key": (196, 202, 208), "key_lt": (236, 240, 244), "key_dk": (140, 146, 152),
    "key_g": (56, 168, 88), "key_r": (204, 64, 56), "key_y": (232, 188, 52),
    "photo_bg": (210, 214, 222), "photo_fig": (70, 86, 110),
    # wallet and other cards
    "leather": (120, 76, 44), "leather_dk": (82, 50, 28), "leather_lt": (154, 104, 64), "stitch": (214, 180, 120),
    "lining": (58, 36, 22),
    "credit": (30, 92, 72), "credit_dk": (18, 62, 48), "credit_lt": (60, 132, 104), "chip": (214, 176, 90), "chip_dk": (160, 124, 54),
    "reward": (92, 58, 36), "reward_dk": (64, 38, 22), "cream": (240, 226, 196),
    "license_band": (40, 84, 150), "license_bg": (236, 240, 246), "license_tint": (206, 222, 238),
}

CAPS = {
    "A": [".#.", "#.#", "###", "#.#", "#.#"], "C": [".##", "#..", "#..", "#..", ".##"],
    "D": ["##.", "#.#", "#.#", "#.#", "##."], "E": ["###", "#..", "##.", "#..", "###"],
    "G": [".##", "#..", "#.#", "#.#", ".##"], "H": ["#.#", "#.#", "###", "#.#", "#.#"],
    "I": ["###", ".#.", ".#.", ".#.", "###"], "S": [".##", "#..", ".#.", "..#", "##."],
    "U": ["#.#", "#.#", "#.#", "#.#", "###"], "V": ["#.#", "#.#", "#.#", "#.#", ".#."],
    "F": ["###", "#..", "##.", "#..", "#.."], "L": ["#..", "#..", "#..", "#..", "###"],
    "N": ["##.", "#.#", "#.#", "#.#", "#.#"], "O": ["###", "#.#", "#.#", "#.#", "###"],
    "R": ["##.", "#.#", "##.", "#.#", "#.#"], "T": ["###", ".#.", ".#.", ".#.", ".#."],
}
# Mixed-case letters for the shop sign, drawn for this game.
SIGN = {
    "P": ["###.", "#..#", "#..#", "###.", "#..."], "e": ["....", ".##.", "####", "#...", ".###"],
    "t": [".#..", "###.", ".#..", ".#..", "..##"], "'": ["#", "#", ".", ".", "."],
    "s": ["....", ".###", "##..", "..##", "###."], " ": [".."] * 5,
    "C": [".###", "#...", "#...", "#...", ".###"], "o": ["....", ".##.", "#..#", "#..#", ".##."],
    "f": ["..##", ".#..", "###.", ".#..", ".#.."],
}


def px(img, x, y, c):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), c)


def rect(img, x0, y0, x1, y1, c):
    for y in range(y0, y1):
        for x in range(x0, x1):
            px(img, x, y, c)


def outline(img, x0, y0, x1, y1, c):
    rect(img, x0, y0, x1, y0 + 1, c)
    rect(img, x0, y1 - 1, x1, y1, c)
    rect(img, x0, y0, x0 + 1, y1, c)
    rect(img, x1 - 1, y0, x1, y1, c)


def dither(img, x0, y0, x1, y1, a, b, density=0.5, seed=0):
    """Ordered checker dither between two colours; density picks how much of b."""
    bayer = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
    for y in range(y0, y1):
        for x in range(x0, x1):
            px(img, x, y, b if bayer[y % 4][x % 4] < density * 16 else a)


def vgrad(img, x0, y0, x1, y1, a, b):
    """Dithered vertical blend from a (top) to b (bottom)."""
    bayer = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
    for y in range(y0, y1):
        t = (y - y0) / max(y1 - y0 - 1, 1)
        for x in range(x0, x1):
            px(img, x, y, b if bayer[y % 4][x % 4] < t * 16 else a)


def speckle(img, x0, y0, x1, y1, colors, chance, seed):
    rng = random.Random(seed)
    for y in range(y0, y1):
        for x in range(x0, x1):
            if rng.random() < chance:
                px(img, x, y, rng.choice(colors))


def write(img, x, y, s, c, font, scale=1, gap=1):
    for ch in s:
        glyph = font[ch]
        for row, line in enumerate(glyph):
            for col, v in enumerate(line):
                if v == "#":
                    rect(img, x + col * scale, y + row * scale, x + (col + 1) * scale, y + (row + 1) * scale, c)
        x += (len(glyph[0]) + gap) * scale


def width(s, font, scale=1, gap=1):
    return (sum(len(font[ch][0]) + gap for ch in s) - gap) * scale


def background():
    img = Image.new("RGB", (W, H), P["wall"])

    # Ceiling, recessed lights, spotlight track with warm pools on the wall.
    rect(img, 0, 0, W, 9, P["ceil"])
    dither(img, 0, 7, W, 9, P["ceil"], P["ceil_dk"], 0.5)
    rect(img, 0, 9, W, 10, P["ink"])
    for x in (12, 40, 68):
        rect(img, x, 2, x + 6, 4, P["recess"])
    speckle(img, 0, 10, W, COUNTER_TOP, [P["wall_dk"]], 0.04, 1)
    rect(img, 96, 4, 254, 5, P["track"])
    for x in range(104, 252, 22):
        rect(img, x, 5, x + 3, 8, P["track"])
        px(img, x + 1, 8, P["spot"])
        for i in range(10):  # light cone, dithered so it fades out
            dither(img, x - i // 2, 10 + i, x + 3 + i // 2, 11 + i, P["wall"], P["wall_lt"], 0.6 - i * 0.06)

    # Entrance: metal frame, glass with sky, bushes and diagonal reflections.
    rect(img, 2, 12, 47, COUNTER_TOP, P["frame"])
    outline(img, 2, 12, 47, COUNTER_TOP, P["ink"])
    for x0, x1 in ((5, 23), (26, 44)):
        vgrad(img, x0, 22, x1, 70, P["sky_lt"], P["sky"])
        rect(img, x0, 70, x1, COUNTER_TOP, P["glass"])
        for bx in range(x0, x1):
            top = 66 + (bx * 7) % 5
            rect(img, bx, top, bx + 1, 84, P["bush"])
        speckle(img, x0, 66, x1, 84, [P["bush_dk"], P["bush_lt"]], 0.35, x0)
        rect(img, x0, 84, x1, 86, P["bush_dk"])
        for i in range(x1 - x0):  # reflection streak
            px(img, x0 + i, 50 - i, P["sky_lt"])
            px(img, x0 + i, 51 - i, P["sky_lt"])
        rect(img, x0 + 1, 56, x0 + 3, 62, P["frame_lt"])
    rect(img, 5, 14, 44, 20, P["sky_lt"])
    rect(img, 23, 14, 26, COUNTER_TOP, P["frame"])
    rect(img, 2, 20, 47, 22, P["frame"])

    # Dark wood wall strip, then a mosaic backsplash behind the counter.
    rect(img, 48, 10, 56, COUNTER_TOP, P["wood"])
    for x in (49, 51, 54):
        rect(img, x, 10, x + 1, COUNTER_TOP, P["wood_dk"])
    speckle(img, 48, 10, 56, COUNTER_TOP, [P["wood_lt"]], 0.08, 2)
    rng = random.Random(3)
    for y in range(74, COUNTER_TOP):
        for x in range(56, W):
            px(img, x, y, P["mos_b"] if (x // 2 + y // 2) % 2 else (P["mos_a"] if rng.random() < 0.85 else P["mos_c"]))
    rect(img, 56, 73, W, 74, P["wood_dk"])

    # Shop sign in the shop's dark grey.
    sign = "Peet's Coffee"
    write(img, 252 - width(sign, SIGN, 2), 14, sign, P["sign"], SIGN, scale=2)

    # Menu screens with a featured drink.
    for bx in (146, 196):
        rect(img, bx, 34, bx + 46, 56, P["board"])
        outline(img, bx - 1, 33, bx + 47, 57, P["ink"])
        rect(img, bx, 34, bx + 46, 35, P["board_lt"])
        for i, y in enumerate(range(38, 54, 3)):
            rect(img, bx + 3, y, bx + 3 + (14 if i % 2 else 19), y + 1, P["board_txt"])
            rect(img, bx + 24, y, bx + 28, y + 1, P["board_txt"])
    rect(img, 228, 38, 238, 53, P["drink_o"])
    rect(img, 230, 40, 236, 51, P["drink_r"])
    rect(img, 229, 38, 231, 52, P["drink_lt"])
    rect(img, 232, 35, 234, 38, P["white"])

    # Back counter: espresso machine, iced tea dispensers, cups.
    rect(img, 196, 84, 232, COUNTER_TOP, P["steel"])
    outline(img, 196, 84, 232, COUNTER_TOP, P["ink"])
    rect(img, 197, 85, 231, 88, P["term_dk"])
    rect(img, 197, 88, 199, COUNTER_TOP - 1, P["steel_lt"])
    rect(img, 228, 88, 231, COUNTER_TOP - 1, P["steel_dk"])
    for x in (203, 214):
        rect(img, x, 92, x + 5, 98, P["term_dk"])
    px(img, 225, 90, P["red"])
    for x in (198, 205, 212, 219):
        rect(img, x, 80, x + 5, 84, P["cup"])
        rect(img, x, 83, x + 5, 84, P["cup_dk"])
    for x in (236, 245):
        rect(img, x, 76, x + 8, COUNTER_TOP, P["tea"])
        outline(img, x, 76, x + 8, COUNTER_TOP, P["ink"])
        rect(img, x + 1, 77, x + 3, COUNTER_TOP - 1, P["tea_lt"])
        rect(img, x + 6, 77, x + 7, COUNTER_TOP - 1, P["tea_dk"])
        rect(img, x + 1, 73, x + 7, 76, P["tea_cap"])

    # Barista behind the counter (a generic figure).
    bx = 172
    rect(img, bx, 78, bx + 12, COUNTER_TOP, P["shirt"])
    rect(img, bx + 2, 82, bx + 10, COUNTER_TOP, P["apron"])
    rect(img, bx + 3, 70, bx + 9, 78, P["skin"])
    rect(img, bx + 3, 76, bx + 9, 78, P["skin_dk"])
    rect(img, bx + 2, 67, bx + 10, 71, P["cap"])
    rect(img, bx + 8, 70, bx + 12, 71, P["cap"])
    px(img, bx + 5, 73, P["ink"])
    px(img, bx + 7, 73, P["ink"])

    # Pastry case with curved glass.
    rect(img, 60, 78, 106, COUNTER_TOP, P["case"])
    outline(img, 59, 77, 107, COUNTER_TOP, P["ink"])
    vgrad(img, 61, 79, 105, 100, P["case_lt"], P["case_glass"])
    for i in range(4):
        px(img, 61 + i, 79 + 3 - i, P["case"])
    for y in (86, 93, 100):
        rect(img, 61, y, 105, y + 1, P["case"])
        for x in range(63, 103, 6):
            rect(img, x, y - 3, x + 4, y, P["pastry"])
            px(img, x, y - 3, P["pastry_lt"])
            px(img, x + 3, y - 1, P["pastry_dk"])

    # Sneeze guard: two posts and a faint pane.
    for x in (150, 248):
        rect(img, x, 80, x + 1, COUNTER_TOP, P["post"])
    for x in range(151, 248, 7):
        px(img, x, 82, P["glass_g"])

    # Aggie Cash placard standing on the counter.
    rect(img, 148, 88, 172, COUNTER_TOP, P["aggie_gold"])
    rect(img, 149, 89, 171, COUNTER_TOP - 1, P["aggie_blue"])
    write(img, 160 - width("AGGIE", CAPS) // 2, 90, "AGGIE", P["aggie_gold"], CAPS)
    write(img, 160 - width("CASH", CAPS) // 2, 96, "CASH", P["white"], CAPS)

    # Counter: marble top and black wood front with panels and grain.
    rect(img, 56, COUNTER_TOP, W, COUNTER_TOP + 3, P["marble"])
    rect(img, 56, COUNTER_TOP, W, COUNTER_TOP + 1, P["marble_lt"])
    speckle(img, 56, COUNTER_TOP + 1, W, COUNTER_TOP + 3, [P["marble_dk"]], 0.25, 4)
    rect(img, 56, COUNTER_TOP + 3, W, COUNTER_TOP + 4, P["ink"])
    rect(img, 56, COUNTER_TOP + 4, W, 133, P["black"])
    for x0 in (60, 110, 160, 210):
        outline(img, x0, 110, x0 + 44, 129, P["black_lt"])
        rect(img, x0 + 1, 111, x0 + 43, 112, P["black_dk"])
    rng = random.Random(5)
    for x in range(56, W):
        if rng.random() < 0.18:
            rect(img, x, COUNTER_TOP + 4, x + 1, 131, P["black_dk"])
    rect(img, 56, 131, W, 133, P["black_dk"])

    # Floor: polished concrete with reflections, the door mat, a floor decal.
    rect(img, 0, COUNTER_TOP, 56, H, P["floor"])
    rect(img, 0, 133, W, H, P["floor"])
    speckle(img, 0, COUNTER_TOP, 56, H, [P["floor_dk"]], 0.12, 6)
    speckle(img, 56, 133, W, H, [P["floor_dk"]], 0.12, 7)
    for x in range(-30, W, 34):
        for i in range(11):
            dither(img, x + i * 2, 133 + i, x + i * 2 + 7, 134 + i, P["floor"], P["floor_lt"], 0.5)
    rect(img, 0, 133, W, 134, P["floor_dk"])
    rect(img, 3, COUNTER_TOP + 1, 46, 112, P["mat"])
    dither(img, 3, COUNTER_TOP + 1, 46, 112, P["mat"], P["mat_lt"], 0.25)
    rect(img, 120, 136, 134, 143, P["decal"])
    rect(img, 123, 139, 129, 140, P["white"])
    for i in range(3):
        rect(img, 129 + i, 137 + i, 130 + i, 142 - i, P["white"])
    rect(img, 38, 80, 40, 110, P["steel"])
    px(img, 38, 80, P["steel_lt"])
    rect(img, 35, 110, 43, 112, P["steel_dk"])
    return img


def terminal():
    """Card reader, 32x52. The swipe slot runs across rows 24-26."""
    img = Image.new("RGBA", (32, 52), (0, 0, 0, 0))
    rect(img, 3, 0, 29, 52, P["term"])
    rect(img, 4, 1, 6, 51, P["term_lt"])
    rect(img, 26, 1, 28, 51, P["term_dk"])
    outline(img, 3, 0, 29, 52, P["ink"])
    rect(img, 6, 3, 26, 13, P["ink"])
    rect(img, 7, 4, 25, 12, P["screen"])
    for y in range(4, 12, 2):
        rect(img, 7, y, 25, y + 1, P["screen_lt"])
    for x in (9, 12, 20, 23):
        px(img, x, 10, P["screen_px"])
    rect(img, 0, 23, 32, 24, P["term_lt"])
    rect(img, 0, 24, 32, 27, P["slot"])
    rect(img, 0, 27, 32, 28, P["term_dk"])
    keys = ["key"] * 9 + ["key_r", "key_y", "key_g"]
    for i, key in enumerate(keys):
        kx = 7 + (i % 3) * 7
        ky = 31 + (i // 3) * 5
        rect(img, kx, ky, kx + 5, ky + 3, P[key])
        rect(img, kx, ky, kx + 5, ky + 1, P["key_lt"] if key == "key" else P["white"])
        rect(img, kx, ky + 3, kx + 5, ky + 4, P["key_dk"])
    return img


def aggie_card():
    """Aggie Card, 48x30, following the real card's layout with a generic photo."""
    img = Image.new("RGBA", (48, 30), (0, 0, 0, 0))
    rect(img, 0, 0, 48, 30, P["white"])
    # Gold California shape with a navy star.
    state = [(4, 2, 8), (4, 3, 9), (5, 4, 10), (5, 5, 11), (6, 6, 13), (6, 7, 14), (7, 8, 16), (8, 9, 18),
             (9, 10, 20), (10, 11, 22), (12, 12, 24), (14, 13, 25), (16, 14, 26), (18, 15, 26), (20, 16, 26)]
    for x0, y, x1 in state:
        rect(img, x0, y, x1, y + 1, P["aggie_gold"])
        px(img, x1 - 1, y, P["aggie_gold_dk"])
    for dx, dy in ((0, 0), (-1, 0), (1, 0), (0, -1), (0, 1)):
        px(img, 8 + dx, 5 + dy, P["aggie_blue"])
    # AGGIES across the state, navy over gold as on the real card.
    write(img, 3, 10, "AGGIES", P["aggie_blue"], CAPS)
    # Photo with a gold border and a generic silhouette.
    rect(img, 33, 2, 45, 17, P["aggie_gold"])
    rect(img, 34, 3, 44, 16, P["photo_bg"])
    rect(img, 37, 5, 41, 10, P["photo_fig"])
    rect(img, 36, 10, 42, 16, P["photo_fig"])
    rect(img, 35, 12, 43, 16, P["photo_fig"])
    # Sky-blue band with UCDAVIS, a small AGGIECARD line and placeholder name lines.
    rect(img, 0, 19, 48, 30, P["card_cyan"])
    rect(img, 0, 19, 48, 20, P["card_cyan_dk"])
    write(img, 3, 21, "UCDAVIS", P["white"], CAPS)
    rect(img, 3, 27, 13, 28, P["aggie_blue"])
    rect(img, 14, 27, 21, 28, P["white"])
    for y, x0 in ((21, 40), (23, 40), (25, 34)):
        rect(img, x0, y, 45, y + 1, P["ink"])
    outline(img, 0, 0, 48, 30, P["ink"])
    for x, y in ((0, 0), (47, 0), (0, 29), (47, 29)):
        img.putpixel((x, y), (0, 0, 0, 0))
    return img


def card_base(fill):
    img = Image.new("RGBA", (48, 30), (0, 0, 0, 0))
    rect(img, 0, 0, 48, 30, fill)
    return img


def finish_card(img):
    outline(img, 0, 0, 48, 30, P["ink"])
    for x, y in ((0, 0), (47, 0), (0, 29), (47, 29)):
        img.putpixel((x, y), (0, 0, 0, 0))
    return img


def credit_card():
    """A generic bank card: dark green, chip, CREDIT."""
    img = card_base(P["credit"])
    rect(img, 1, 1, 47, 6, P["credit_lt"])
    dither(img, 1, 6, 47, 10, P["credit"], P["credit_lt"], 0.3)
    write(img, 3, 1, "CREDIT", P["white"], CAPS)
    rect(img, 5, 12, 14, 19, P["chip"])
    rect(img, 5, 15, 14, 16, P["chip_dk"])
    rect(img, 9, 12, 10, 19, P["chip_dk"])
    for x in range(5, 42, 9):
        rect(img, x, 22, x + 7, 24, P["credit_lt"])
    rect(img, 1, 26, 47, 29, P["credit_dk"])
    return finish_card(img)


def rewards_card():
    """A coffee rewards card: brown with a cup."""
    img = card_base(P["reward"])
    rect(img, 1, 1, 47, 7, P["cream"])
    write(img, 3, 1, "COFFEE", P["reward"], CAPS)
    rect(img, 30, 2, 35, 6, P["reward"])
    px(img, 35, 3, P["reward"])
    px(img, 36, 4, P["reward"])
    rect(img, 18, 12, 30, 22, P["cream"])
    rect(img, 30, 14, 33, 19, P["cream"])
    rect(img, 31, 15, 32, 18, P["reward"])
    rect(img, 18, 12, 30, 14, P["pastry_lt"])
    rect(img, 1, 25, 47, 29, P["reward_dk"])
    return finish_card(img)


def license_card():
    """A generic driver's license. Its white top is the look-alike on HARD."""
    img = card_base(P["license_bg"])
    rect(img, 1, 1, 47, 7, P["white"])
    write(img, 3, 1, "LICENSE", P["license_band"], CAPS)
    rect(img, 1, 7, 47, 9, P["license_band"])
    dither(img, 1, 9, 47, 29, P["license_bg"], P["license_tint"], 0.25)
    rect(img, 3, 11, 13, 24, P["photo_bg"])
    outline(img, 3, 11, 13, 24, P["license_band"])
    rect(img, 6, 13, 10, 17, P["photo_fig"])
    rect(img, 5, 17, 11, 23, P["photo_fig"])
    for y, x1 in ((12, 40), (15, 44), (18, 36), (21, 42)):
        rect(img, 16, y, x1, y + 1, P["license_band"])
    return finish_card(img)


def wallet_back():
    """Inside of the open wallet, drawn behind the cards. 60x40."""
    img = Image.new("RGBA", (60, 40), (0, 0, 0, 0))
    rect(img, 0, 0, 60, 40, P["leather_dk"])
    rect(img, 2, 2, 58, 38, P["lining"])
    outline(img, 0, 0, 60, 40, P["ink"])
    return img


def wallet_front():
    """The card pocket, drawn over the cards. 60x30."""
    img = Image.new("RGBA", (60, 30), (0, 0, 0, 0))
    rect(img, 0, 0, 60, 30, P["leather"])
    rect(img, 0, 0, 60, 2, P["leather_lt"])
    speckle(img, 0, 2, 60, 30, [P["leather_dk"]], 0.04, 8)
    for x in range(3, 57, 3):
        px(img, x, 4, P["stitch"])
        px(img, x, 26, P["stitch"])
    for y in range(4, 27, 3):
        px(img, 3, y, P["stitch"])
        px(img, 56, y, P["stitch"])
    rect(img, 0, 28, 60, 30, P["leather_dk"])
    outline(img, 0, 0, 60, 30, P["ink"])
    return img


EXT = {
    "sky_hi": (126, 190, 232), "sky": (160, 210, 240), "sky_lo": (198, 230, 248),
    "cloud": (250, 252, 255), "cloud_sh": (214, 230, 244),
    "roof_hi": (128, 124, 120), "roof": (98, 94, 90), "roof_dk": (70, 67, 64), "roof_ink": (48, 46, 44),
    "cedar_hi": (214, 146, 98), "cedar": (186, 118, 76), "cedar_b": (172, 106, 66), "cedar_dk": (128, 76, 46),
    "cedar_sh": (104, 60, 38),
    "red_hi": (192, 82, 70), "red": (166, 64, 56), "red_dk": (124, 44, 40),
    "trim": (246, 244, 238), "trim_sh": (206, 202, 194), "trim_dk": (164, 160, 152),
    "aw_hi": (78, 128, 200), "aw": (44, 96, 170), "aw_dk": (30, 66, 126), "aw_ink": (20, 44, 86),
    "glass_hi": (210, 230, 234), "glass_lt": (120, 162, 172), "glass": (52, 84, 92), "glass_dk": (32, 54, 60),
    "warm": (240, 196, 120), "warm_dk": (176, 128, 72),
    "conc_hi": (240, 238, 232), "conc": (220, 216, 208), "conc_md": (196, 192, 183), "conc_dk": (162, 157, 148),
    "conc_ink": (128, 124, 116),
    "trunk_hi": (128, 100, 76), "trunk": (96, 74, 56), "trunk_dk": (66, 50, 38),
    "leaf_hi": (122, 170, 88), "leaf": (84, 132, 62), "leaf_dk": (54, 94, 46), "leaf_ink": (36, 64, 34),
    "flower": (252, 250, 244), "flower_sh": (222, 214, 188), "flower_ctr": (236, 206, 120),
    "chair_hi": (226, 112, 70), "chair": (192, 80, 46), "chair_dk": (138, 54, 28),
    "rail_hi": (246, 248, 250), "rail": (204, 210, 216), "rail_dk": (140, 148, 156),
    "sign": (26, 38, 48), "sign_hi": (60, 76, 90),
    "poster_a": (232, 160, 56), "poster_b": (64, 124, 186),
    "interior": (70, 48, 34), "interior_lt": (150, 104, 66),
    "ink": (24, 22, 26),
    # the student
    "cap": (244, 244, 240), "cap_sh": (204, 204, 200), "hair": (54, 40, 30), "skin": (218, 170, 134), "skin_sh": (184, 136, 104),
    "shirt_hi": (178, 216, 240), "shirt": (146, 192, 226), "shirt_sh": (108, 152, 192),
    "pack_hi": (176, 176, 182), "pack": (138, 138, 146), "pack_sh": (96, 96, 106),
    "jeans": (52, 62, 92), "jeans_sh": (36, 42, 66), "shoe": (30, 30, 34), "sole": (210, 210, 206),
}
DOOR_RECT = (196, 74, 226, 118)  # the double doors in the exterior art


def blob(img, cx, cy, rx, ry, base, hi, dk, ink=None):
    """A shaded leaf or cloud clump, lit from the upper left."""
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            dx, dy = (x - cx) / rx, (y - cy) / ry
            d = dx * dx + dy * dy
            if d > 1.0:
                continue
            light = -dx * 0.6 - dy * 0.8
            if ink and d > 0.82 and light < 0.1:
                c = ink
            elif light > 0.45:
                c = hi
            elif light < -0.35:
                c = dk
            else:
                c = base
            px(img, x, y, c)


def shingles(img, x0, y0, x1, y1, course, width, tones, line, hi, shade):
    """Staggered shingle courses: each course has a shadow line under it and
    the shingles alternate between tones in a fixed pattern (no noise)."""
    for row, y in enumerate(range(y0, y1, course)):
        offset = (row % 2) * (width // 2)
        for i, x in enumerate(range(x0 - offset, x1, width)):
            tone = tones[(i * 3 + row * 2) % len(tones)]
            rect(img, max(x, x0), y, min(x + width, x1), min(y + course, y1), tone)
            if x >= x0:
                rect(img, x, y, x + 1, min(y + course - 1, y1), line)  # gap
                px(img, x + 1, y, hi)
        rect(img, x0, min(y + course - 1, y1 - 1), x1, min(y + course, y1), shade)


def exterior():
    """Outside the Peet's Coffee on campus, 256x144, lit from the upper left."""
    E = EXT
    img = Image.new("RGB", (W, H), E["sky"])
    vgrad(img, 0, 0, W, 34, E["sky_hi"], E["sky"])
    vgrad(img, 0, 34, W, 70, E["sky"], E["sky_lo"])
    for cx, cy, rx in ((196, 8, 9), (208, 6, 7), (186, 10, 6), (238, 14, 6), (247, 12, 5)):
        blob(img, cx, cy, rx, rx * 0.55, E["cloud"], E["cloud"], E["cloud_sh"])

    # Tree canopy behind the building's left end.
    for cx, cy, r in ((12, 6, 12), (34, 2, 13), (56, 8, 11), (24, 20, 11), (48, 22, 10), (70, 16, 9), (8, 28, 9)):
        blob(img, cx, cy, r, r * 0.85, E["leaf"], E["leaf_hi"], E["leaf_dk"], E["leaf_ink"])

    # Upper roof: shingle rows, fascia, and the fascia's shadow on the wall.
    shingles(img, 70, 14, W, 30, 3, 6, [E["roof"], E["roof"], E["roof_dk"]], E["roof_ink"], E["roof_hi"], E["roof_ink"])
    rect(img, 70, 14, W, 15, E["roof_hi"])
    rect(img, 66, 30, W, 32, E["trim"])
    rect(img, 66, 32, W, 33, E["trim_dk"])

    # Cedar shingle walls.
    cedar = [E["cedar"], E["cedar_b"], E["cedar"], E["cedar_hi"], E["cedar_b"]]
    shingles(img, 58, 33, W, 96, 4, 5, cedar, E["cedar_dk"], E["cedar_hi"], E["cedar_sh"])
    rect(img, 58, 33, W, 35, E["cedar_sh"])  # shadow under the fascia

    # Gable window: white frame, inner shadow, reflections.
    rect(img, 72, 37, 94, 51, E["trim"])
    rect(img, 72, 50, 94, 51, E["trim_dk"])
    rect(img, 74, 39, 92, 49, E["glass"])
    rect(img, 74, 39, 92, 40, E["glass_dk"])
    rect(img, 82, 39, 84, 49, E["trim"])
    for i in range(6):
        px(img, 76 + i, 47 - i, E["glass_lt"])
        px(img, 86 + i, 47 - i, E["glass_lt"])

    # Lower roof over the front, fascia and its shadow.
    shingles(img, 118, 34, W, 50, 3, 6, [E["roof"], E["roof_dk"], E["roof"]], E["roof_ink"], E["roof_hi"], E["roof_ink"])
    rect(img, 118, 34, W, 35, E["roof_hi"])
    rect(img, 116, 50, W, 52, E["trim"])
    rect(img, 116, 52, W, 53, E["trim_dk"])
    rect(img, 116, 53, W, 55, E["cedar_sh"])

    # Red lower wall: vertical boards with white trim.
    rect(img, 58, 88, 188, 116, E["red"])
    for x in range(58, 188, 6):
        rect(img, x, 88, x + 1, 116, E["red_dk"])
        rect(img, x + 1, 88, x + 2, 116, E["red_hi"])
    rect(img, 58, 86, 188, 88, E["trim"])
    rect(img, 58, 88, 188, 89, E["red_dk"])
    rect(img, 58, 114, 188, 118, E["trim_sh"])
    rect(img, 58, 117, 188, 118, E["trim_dk"])

    # Side window with its small awning (and the awning's shadow).
    rect(img, 98, 82, 116, 108, E["trim"])
    rect(img, 98, 107, 116, 108, E["trim_dk"])
    rect(img, 100, 84, 114, 106, E["glass"])
    rect(img, 100, 84, 114, 89, E["glass_dk"])
    for i in range(10):
        px(img, 102 + i, 104 - i, E["glass_lt"])
    for i in range(9):  # awning, sloping out and down
        y = 70 + i
        rect(img, 94 - i // 4, y, 120 + i // 4, y + 1, E["aw"] if i < 7 else E["aw_dk"])
        for sx in range(96, 120, 4):
            px(img, sx, y, E["aw_hi"])
    rect(img, 92, 79, 122, 80, E["aw_ink"])
    rect(img, 96, 80, 120, 82, E["cedar_sh"])

    # Shop sign with a small drop shadow.
    rect(img, 126, 74, 158, 90, E["cedar_sh"])
    rect(img, 124, 72, 156, 88, E["sign"])
    outline(img, 124, 72, 156, 88, E["sign_hi"])
    name = "Peet's"
    write(img, 140 - width(name, SIGN) // 2, 77, name, E["trim"], SIGN)

    # Storefront: big awning with folds, its shadow, frames, glass, doors.
    rect(img, 184, 59, W, 61, E["aw_hi"])
    rect(img, 184, 61, W, 68, E["aw"])
    for x in range(186, W, 6):
        rect(img, x, 61, x + 2, 68, E["aw_dk"])
    for x in range(184, W, 4):  # valance
        rect(img, x, 68, x + 2, 70, E["aw_dk"])
        px(img, x + 2, 68, E["aw_ink"])
    rect(img, 186, 70, W, 72, E["glass_dk"])
    rect(img, 188, 72, W, 118, E["trim"])
    rect(img, 188, 116, W, 118, E["trim_sh"])
    for x0, x1 in ((190, 195), (228, 241), (243, 255)):
        rect(img, x0, 74, x1, 116, E["glass"])
        rect(img, x0, 74, x1, 77, E["glass_dk"])
        for i in range(min(x1 - x0, 10)):
            px(img, x0 + i, 96 - i, E["glass_lt"])
            px(img, x0 + i, 97 - i, E["glass_lt"])
        for wx in range(x0 + 1, x1 - 1, 4):  # warm lights inside
            px(img, wx, 80, E["warm"])
    rect(img, 230, 88, 237, 97, E["poster_a"])
    rect(img, 230, 88, 237, 89, E["warm"])
    rect(img, 245, 86, 252, 95, E["poster_b"])
    x0, y0, x1, y1 = DOOR_RECT
    for dx0, dx1 in ((x0, x0 + 14), (x0 + 16, x1)):
        rect(img, dx0, y0, dx1, y1, E["trim"])
        rect(img, dx0 + 2, y0 + 2, dx1 - 2, y1 - 3, E["glass"])
        rect(img, dx0 + 2, y0 + 2, dx1 - 2, y0 + 5, E["glass_dk"])
        for i in range(9):
            px(img, dx0 + 3 + i, y0 + 20 - i, E["glass_lt"])
            px(img, dx0 + 3 + i, y0 + 21 - i, E["glass_hi"] if i % 3 == 0 else E["glass_lt"])
        rect(img, dx0, y1 - 3, dx1, y1, E["trim_sh"])
    rect(img, x0 + 12, y0 + 20, x0 + 13, y0 + 28, E["trim_dk"])
    rect(img, x0 + 17, y0 + 20, x0 + 18, y0 + 28, E["trim_dk"])
    rect(img, x0 + 14, y0, x0 + 16, y1, E["trim_sh"])

    # Landing, with the building's shadow along its back edge.
    rect(img, 40, 118, W, 126, E["conc"])
    rect(img, 56, 118, W, 120, E["conc_md"])
    # Three steps: light tread, a nosing line, a shaded riser.
    for i, y in enumerate((126, 132, 138)):
        left = 56 - i * 4
        rect(img, left, y, W, y + 6, E["conc"])
        rect(img, left, y, W, y + 1, E["conc_hi"])
        rect(img, left, y + 4, W, y + 6, E["conc_md"])
        rect(img, left, y + 5, W, y + 6, E["conc_dk"])
    # Faint, regular expansion joints instead of noise.
    for x in range(72, W, 32):
        rect(img, x, 118, x + 1, 126, E["conc_md"])

    # Tree trunk with bark lines, lit on the left.
    rect(img, 22, 22, 32, 104, E["trunk"])
    rect(img, 22, 22, 24, 104, E["trunk_hi"])
    rect(img, 30, 22, 32, 104, E["trunk_dk"])
    for y in range(26, 104, 7):
        rect(img, 26, y, 27, y + 4, E["trunk_dk"])
        rect(img, 28, y + 3, 29, y + 6, E["trunk_dk"])
    for cx, cy, r in ((26, 30, 9), (14, 34, 8), (40, 30, 7)):
        blob(img, cx, cy, r, r * 0.8, E["leaf"], E["leaf_hi"], E["leaf_dk"], E["leaf_ink"])

    # Flowering shrub: green clumps, then clusters of white flowers on the lit side.
    clumps = ((12, 70, 13, 12), (32, 66, 12, 11), (20, 86, 15, 10), (42, 84, 10, 9), (4, 88, 8, 8))
    for cx, cy, rx, ry in clumps:
        blob(img, cx, cy, rx, ry, E["leaf"], E["leaf_hi"], E["leaf_dk"], E["leaf_ink"])
    rng = random.Random(21)
    for cx, cy, rx, ry in clumps:
        for _ in range(int(rx * ry * 0.35)):
            fx = cx + rng.uniform(-rx, rx) * 0.85
            fy = cy + rng.uniform(-ry, ry) * 0.85
            if ((fx - cx) / rx) ** 2 + ((fy - cy) / ry) ** 2 > 0.75 or (fx - cx) + (fy - cy) > rx * 0.5:
                continue
            ix, iy = int(fx), int(fy)
            px(img, ix, iy, E["flower"])
            px(img, ix + 1, iy, E["flower"])
            px(img, ix, iy + 1, E["flower_sh"])
            px(img, ix + 1, iy + 1, E["flower_ctr"] if rng.random() < 0.3 else E["flower_sh"])

    # Low concrete wall in the foreground: lit top, front face, shaded end.
    rect(img, 0, 100, 54, H, E["conc_md"])
    rect(img, 0, 100, 54, 103, E["conc_hi"])
    rect(img, 0, 103, 54, 104, E["conc_dk"])
    rect(img, 50, 103, 54, H, E["conc_dk"])
    for x in range(10, 50, 14):
        rect(img, x, 104, x + 1, H, E["conc_dk"])

    # Handrail: a rounded tube with highlight and shade.
    rect(img, 48, 93, 68, 95, E["rail"])
    rect(img, 48, 93, 68, 94, E["rail_hi"])
    for x in (48, 66):
        rect(img, x, 94, x + 2, 132, E["rail"])
        rect(img, x, 94, x + 1, 132, E["rail_hi"])
        rect(img, x + 1, 96, x + 2, 132, E["rail_dk"])
    rect(img, 64, 132, 72, 133, E["conc_dk"])  # rail's shadow on the step

    # Patio chairs, lit from the left.
    for cx in (70, 82):
        rect(img, cx, 104, cx + 8, 106, E["chair"])
        rect(img, cx, 104, cx + 8, 105, E["chair_hi"])
        rect(img, cx, 106, cx + 1, 118, E["chair"])
        rect(img, cx + 7, 106, cx + 8, 118, E["chair_dk"])
        rect(img, cx, 97, cx + 1, 104, E["chair_hi"])
        rect(img, cx, 98, cx + 8, 99, E["chair"])
        rect(img, cx + 1, 118, cx + 9, 119, E["conc_md"])

    # Bollard.
    rect(img, 246, 104, 250, 118, E["trim"])
    rect(img, 249, 104, 250, 118, E["trim_dk"])
    rect(img, 246, 104, 250, 105, E["rail_hi"])
    rect(img, 247, 118, 252, 119, E["conc_md"])
    return img


def door_open():
    """The left door swung open, 30x44, laid over DOOR_RECT."""
    E = EXT
    x0, y0, x1, y1 = DOOR_RECT
    img = Image.new("RGBA", (x1 - x0, y1 - y0), (0, 0, 0, 0))
    rect(img, 0, 0, 14, 44, E["trim"])
    vgrad(img, 2, 2, 12, 41, E["interior_lt"], E["interior"])
    rect(img, 4, 6, 10, 8, E["warm"])  # a light inside
    rect(img, 2, 38, 12, 41, E["warm_dk"])
    rect(img, 0, 0, 3, 44, E["trim_dk"])  # the open door, edge-on
    rect(img, 0, 41, 14, 44, E["trim_sh"])
    return img


def walker(frame):
    """The student seen from behind, 16x30. Frame 0 stands, 1 and 2 step."""
    E = EXT
    img = Image.new("RGBA", (16, 30), (0, 0, 0, 0))
    swing = {0: 0, 1: 1, 2: -1}[frame]
    # Cap (seen from behind) and hair.
    rect(img, 5, 1, 11, 4, E["cap"])
    rect(img, 6, 0, 10, 1, E["cap"])
    rect(img, 9, 1, 11, 4, E["cap_sh"])
    rect(img, 5, 4, 11, 5, E["cap_sh"])
    rect(img, 5, 5, 11, 7, E["hair"])
    px(img, 4, 5, E["skin"])
    px(img, 11, 5, E["skin_sh"])
    rect(img, 6, 7, 10, 8, E["skin_sh"])
    # Arms, swinging opposite to the legs.
    rect(img, 2, 9 - swing, 4, 17 - swing, E["shirt"])
    rect(img, 2, 17 - swing, 4, 19 - swing, E["skin"])
    rect(img, 12, 9 + swing, 14, 17 + swing, E["shirt_sh"])
    rect(img, 12, 17 + swing, 14, 19 + swing, E["skin_sh"])
    # Shirt and backpack.
    rect(img, 4, 8, 12, 18, E["shirt"])
    rect(img, 4, 8, 6, 18, E["shirt_hi"])
    rect(img, 10, 8, 12, 18, E["shirt_sh"])
    rect(img, 5, 9, 11, 17, E["pack"])
    rect(img, 5, 9, 7, 17, E["pack_hi"])
    rect(img, 9, 9, 11, 17, E["pack_sh"])
    rect(img, 5, 13, 11, 14, E["pack_sh"])
    rect(img, 7, 10, 9, 11, E["pack_sh"])
    px(img, 5, 8, E["pack_sh"])
    px(img, 10, 8, E["pack_sh"])
    # Jeans and shoes; the stepping leg is lifted and shorter.
    rect(img, 4, 18, 12, 20, E["jeans"])
    legs = {0: ((4, 7, 0), (9, 12, 0)), 1: ((4, 7, 2), (9, 12, 0)), 2: ((4, 7, 0), (9, 12, 2))}[frame]
    for lx0, lx1, lift in legs:
        rect(img, lx0, 20, lx1, 28 - lift, E["jeans"])
        rect(img, lx1 - 1, 20, lx1, 28 - lift, E["jeans_sh"])
        rect(img, lx0, 28 - lift, lx1, 29 - lift, E["shoe"])
        rect(img, lx0, 29 - lift, lx1, 30 - lift, E["sole"])
    outline_alpha(img, E["ink"])
    return img


def outline_alpha(img, color):
    """Adds a 1 px outline around the opaque pixels of a sprite."""
    src = img.copy()
    for y in range(img.height):
        for x in range(img.width):
            if src.getpixel((x, y))[3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < img.width and 0 <= ny < img.height and src.getpixel((nx, ny))[3]:
                    img.putpixel((x, y), color + (255,))
                    break


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    exterior().save(OUT / "peets_exterior.png")
    door_open().save(OUT / "peets_door_open.png")
    for frame in range(3):
        walker(frame).save(OUT / f"student_walk_{frame}.png")
    background().save(OUT / "coffee_counter_bg.png")
    terminal().save(OUT / "card_reader.png")
    aggie_card().save(OUT / "aggie_card.png")
    credit_card().save(OUT / "credit_card.png")
    rewards_card().save(OUT / "rewards_card.png")
    license_card().save(OUT / "license_card.png")
    wallet_back().save(OUT / "wallet_back.png")
    wallet_front().save(OUT / "wallet_front.png")
    print("wrote", OUT)


if __name__ == "__main__":
    main()
