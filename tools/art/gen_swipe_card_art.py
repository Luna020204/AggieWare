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
    "sky": (178, 222, 244), "sky_lt": (216, 238, 250),
    "roof": (93, 90, 87), "roof_dk": (69, 66, 63), "roof_lt": (119, 115, 110),
    "cedar": (184, 114, 74), "cedar_dk": (143, 84, 52), "cedar_lt": (208, 138, 92),
    "red": (168, 66, 58), "red_dk": (127, 47, 41),
    "trim": (242, 240, 234), "trim_dk": (204, 200, 192),
    "awning": (43, 95, 168), "awning_dk": (30, 69, 128), "awning_lt": (74, 124, 196),
    "glass": (47, 79, 85), "glass_lt": (111, 154, 162), "glass_hi": (198, 221, 224),
    "concrete": (217, 214, 207), "concrete_dk": (184, 180, 171), "concrete_lt": (236, 235, 230), "step_sh": (169, 165, 156),
    "trunk": (91, 70, 54), "trunk_dk": (64, 48, 36),
    "leaf": (63, 107, 53), "leaf_dk": (43, 77, 37), "leaf_lt": (92, 140, 72),
    "blossom": (244, 242, 234), "blossom_dk": (226, 218, 190),
    "chair": (196, 81, 46), "chair_dk": (150, 58, 30),
    "rail": (216, 221, 226), "rail_dk": (154, 161, 168),
    "sign": (29, 42, 51), "poster": (230, 160, 60), "poster_b": (60, 120, 180),
    "interior": (70, 48, 34), "interior_lt": (150, 104, 66),
    # the student
    "cap": (240, 240, 236), "cap_dk": (200, 200, 196), "hair": (52, 40, 32), "skin": (214, 168, 132),
    "shirt": (150, 196, 228), "shirt_dk": (112, 158, 196), "pack": (150, 150, 156), "pack_dk": (108, 108, 116),
    "pants": (44, 48, 62), "shoe": (28, 28, 32),
}
DOOR_RECT = (196, 74, 226, 118)  # the double doors in the exterior art


def exterior():
    """Outside the Peet's Coffee on campus, 256x144."""
    E = EXT
    img = Image.new("RGB", (W, H), E["sky"])
    vgrad(img, 0, 0, W, 60, E["sky_lt"], E["sky"])

    # Upper roof with shingle rows, then its white fascia.
    rect(img, 70, 14, W, 30, E["roof"])
    for y in range(15, 30, 3):
        rect(img, 70, y, W, y + 1, E["roof_dk"])
        for x in range(70 + (y % 2) * 3, W, 6):
            px(img, x, y + 1, E["roof_lt"])
    rect(img, 66, 30, W, 32, E["trim"])
    rect(img, 66, 32, W, 33, E["trim_dk"])

    # Cedar shingle walls.
    rect(img, 58, 33, W, 96, E["cedar"])
    for row, y in enumerate(range(33, 96, 3)):
        rect(img, 58, y + 2, W, y + 3, E["cedar_dk"])
        for x in range(58 + (row % 2) * 2, W, 4):
            rect(img, x, y, x + 1, y + 2, E["cedar_dk"])
            px(img, x + 1, y, E["cedar_lt"])
    # Upper window in the gable.
    rect(img, 72, 36, 94, 50, E["trim"])
    rect(img, 74, 38, 92, 48, E["glass_lt"])
    rect(img, 82, 38, 84, 48, E["trim"])
    rect(img, 74, 38, 92, 40, E["glass_hi"])

    # Lower roof over the front, with its fascia.
    rect(img, 118, 33, W, 50, E["roof"])
    for y in range(34, 50, 3):
        rect(img, 118, y, W, y + 1, E["roof_dk"])
    rect(img, 116, 50, W, 52, E["trim"])
    rect(img, 116, 52, W, 53, E["trim_dk"])

    # Red lower wall with white trim, left of the storefront.
    rect(img, 58, 88, 188, 118, E["red"])
    rect(img, 58, 86, 188, 88, E["trim"])
    rect(img, 58, 114, 188, 118, E["trim_dk"])
    speckle(img, 58, 88, 188, 114, [E["red_dk"]], 0.06, 11)

    # Small side window with a blue awning.
    for i in range(10):
        rect(img, 94 + i // 3, 70 + i, 120 - i // 3, 71 + i, E["awning"])
    rect(img, 94, 79, 120, 81, E["awning_dk"])
    rect(img, 98, 82, 116, 106, E["trim"])
    rect(img, 100, 84, 114, 104, E["glass"])
    rect(img, 100, 84, 114, 87, E["glass_lt"])

    # Shop sign: a dark square with the shop name.
    rect(img, 124, 72, 156, 88, E["sign"])
    outline(img, 124, 72, 156, 88, E["trim_dk"])
    name = "Peet's"
    write(img, 140 - width(name, SIGN) // 2, 77, name, E["trim"], SIGN)

    # Storefront: big blue awning, white frames, glass, double doors.
    rect(img, 184, 60, W, 68, E["awning"])
    rect(img, 184, 60, W, 62, E["awning_lt"])
    rect(img, 184, 68, W, 71, E["awning_dk"])
    rect(img, 188, 71, W, 118, E["trim"])
    for x0, x1 in ((190, 195), (228, 241), (243, 255)):
        rect(img, x0, 74, x1, 116, E["glass"])
        rect(img, x0, 74, x1, 78, E["glass_lt"])
    rect(img, 230, 86, 236, 94, E["poster"])
    rect(img, 245, 84, 251, 92, E["poster_b"])
    x0, y0, x1, y1 = DOOR_RECT
    for dx0, dx1 in ((x0, x0 + 14), (x0 + 16, x1)):
        rect(img, dx0, y0, dx1, y1, E["trim"])
        rect(img, dx0 + 2, y0 + 2, dx1 - 2, y1 - 2, E["glass"])
        for i in range(8):
            px(img, dx0 + 3 + i, y0 + 14 - i, E["glass_hi"])
    rect(img, x0 + 12, y0 + 22, x0 + 13, y0 + 28, E["rail_dk"])
    rect(img, x0 + 17, y0 + 22, x0 + 18, y0 + 28, E["rail_dk"])

    # Ground: a landing, then three steps down to the sidewalk.
    rect(img, 40, 118, W, 126, E["concrete"])
    rect(img, 40, 118, W, 119, E["concrete_lt"])
    for i, y in enumerate((126, 132, 138)):
        rect(img, 56 - i * 4, y, W, y + 6, E["concrete"])
        rect(img, 56 - i * 4, y, W, y + 1, E["concrete_lt"])
        rect(img, 56 - i * 4, y + 5, W, y + 6, E["step_sh"])
    speckle(img, 40, 118, W, H, [E["concrete_dk"]], 0.05, 12)

    # Tree and the white flowering shrub on the left.
    rect(img, 22, 0, 31, 104, E["trunk"])
    rect(img, 22, 0, 24, 104, E["trunk_dk"])
    rng = random.Random(13)
    for y in range(0, 34):
        for x in range(0, 90):
            d = (x - 30) ** 2 / 56.0 ** 2 + (y - 4) ** 2 / 28.0 ** 2
            if d < 1.0 - rng.random() * 0.15:
                shade = E["leaf_lt"] if y < 10 and rng.random() < 0.4 else rng.choice([E["leaf"], E["leaf"], E["leaf_dk"]])
                px(img, x, y, shade)
    for y in range(44, 100):
        for x in range(0, 48):
            if (x - 18) ** 2 / 30.0 ** 2 + (y - 72) ** 2 / 28.0 ** 2 < 1.0 and rng.random() < 0.9:
                px(img, x, y, rng.choice([E["blossom"], E["blossom"], E["blossom_dk"], E["leaf"]]))

    # Low concrete wall in front, the handrail and a bollard.
    rect(img, 0, 100, 54, H, E["concrete_dk"])
    rect(img, 0, 100, 54, 102, E["concrete_lt"])
    rect(img, 0, 120, 54, 121, E["step_sh"])
    rect(img, 48, 94, 68, 96, E["rail"])
    for x in (48, 66):
        rect(img, x, 94, x + 2, 132, E["rail"])
        rect(img, x + 1, 96, x + 2, 132, E["rail_dk"])
    rect(img, 246, 104, 250, 118, E["trim"])
    rect(img, 249, 104, 250, 118, E["trim_dk"])

    # Patio chairs by the wall.
    for cx in (70, 82):
        rect(img, cx, 104, cx + 8, 106, E["chair"])
        rect(img, cx, 106, cx + 1, 118, E["chair_dk"])
        rect(img, cx + 7, 106, cx + 8, 118, E["chair_dk"])
        rect(img, cx, 98, cx + 1, 104, E["chair"])
    return img


def door_open():
    """The left door swung open, 30x44, laid over DOOR_RECT."""
    E = EXT
    x0, y0, x1, y1 = DOOR_RECT
    img = Image.new("RGBA", (x1 - x0, y1 - y0), (0, 0, 0, 0))
    rect(img, 0, 0, 14, 44, E["trim"])
    vgrad(img, 2, 2, 12, 42, E["interior_lt"], E["interior"])
    rect(img, 0, 0, 3, 44, E["trim_dk"])  # the open door, edge-on
    return img


def walker(frame):
    """The student seen from behind, 12x18. Frame 0 stands, 1 and 2 step."""
    E = EXT
    img = Image.new("RGBA", (12, 18), (0, 0, 0, 0))
    rect(img, 3, 0, 9, 3, E["cap"])
    rect(img, 3, 2, 9, 3, E["cap_dk"])
    rect(img, 3, 3, 9, 5, E["hair"])
    rect(img, 4, 5, 8, 6, E["skin"])
    rect(img, 2, 6, 10, 12, E["shirt"])
    rect(img, 1, 7, 2, 11, E["skin"])
    rect(img, 10, 7, 11, 11, E["skin"])
    rect(img, 3, 6, 9, 12, E["pack"])
    rect(img, 3, 11, 9, 12, E["pack_dk"])
    px(img, 3, 6, E["pack_dk"])
    px(img, 8, 6, E["pack_dk"])
    rect(img, 3, 12, 9, 15, E["pants"])
    legs = {0: ((3, 5), (7, 9)), 1: ((2, 4), (7, 9)), 2: ((3, 5), (8, 10))}[frame]
    lifts = {0: (0, 0), 1: (1, 0), 2: (0, 1)}[frame]
    for (lx0, lx1), lift in zip(legs, lifts):
        rect(img, lx0, 15, lx1, 17 - lift, E["pants"])
        rect(img, lx0, 17 - lift, lx1, 18 - lift, E["shoe"])
    outline_alpha(img, P["ink"])
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
