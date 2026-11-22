"""Generates the pixel art for the Variable Not in Scope microgame (SCRUM-23).

The round opens with the student walking into the lecture building (the
Stay Awake exterior), then cuts to their seat in the ECS 179 lecture hall:
a laptop open on the desk, with a code editor on its screen. The game draws
the code, the quick-fix choices and the compiler output on the screen in
AggieMono (gen_mono_font.py). Drawn at 1/5 of the 1280x720 layout and shown
at 5x with nearest filtering, lit from the upper left.

Run from the project root:  python tools/art/gen_variable_scope_art.py
Writes the PNGs to assets/art/microgames/variable_scope/.
"""

import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gen_swipe_card_art import outline, px, rect, vgrad  # noqa: E402
from gen_stay_awake_art import C as HALL, seat_row  # noqa: E402

OUT = Path(__file__).resolve().parents[2] / "assets" / "art" / "microgames" / "variable_scope"
W, H = 256, 144
# Regions of the laptop screen, in scene pixels (the game lays its text out on these).
SCREEN = (31, 17, 225, 113)
TAB_BAR = (31, 17, 225, 24)
GUTTER = (31, 24, 41, 90)
TERMINAL = (31, 90, 225, 113)

C = dict(HALL)
C.update({
    "lid": (58, 62, 70), "lid_hi": (96, 100, 110), "lid_dk": (36, 38, 44),
    "editor": (30, 33, 42), "tabs": (22, 24, 32), "tab_on": (30, 33, 42), "accent": (232, 160, 72),
    "gutter": (26, 29, 37), "term": (18, 16, 22), "term_line": (70, 48, 60),
    "deck": (170, 174, 182), "deck_hi": (200, 204, 210), "deck_dk": (130, 134, 142),
    "key": (44, 46, 52), "key_hi": (70, 72, 80), "pad": (150, 154, 162),
    "desk_hi": (230, 206, 166), "desk_dk": (184, 158, 118),
    "hair2": (24, 20, 20), "hair3": (120, 80, 40),
    "sticker": (232, 184, 74), "sticker_dk": (31, 61, 122),
})


def heads(img, y, xs):
    """Classmates' heads above the seat row, from behind."""
    for i, x in enumerate(xs):
        hair = (C["hair"], C["hair2"], C["hair3"])[i % 3]
        rect(img, x - 4, y - 7, x + 4, y + 1, hair)
        rect(img, x - 3, y - 8, x + 3, y - 7, hair)
        rect(img, x - 3, y - 7, x - 1, y - 5, C["hair_hi"])


def lecture_seat():
    """The student's seat in the lecture hall, 256x144: rows of classmates,
    and the laptop open on the desk with an editor on its screen."""
    img = Image.new("RGB", (W, H), C["wall"])
    # Ceiling with light panels.
    rect(img, 0, 0, W, 10, C["ceil"])
    for x in range(0, W, 16):
        rect(img, x, 0, x + 1, 10, C["ceil_line"])
    for x0 in (8, 52, 188, 232):
        rect(img, x0, 3, x0 + 16, 6, C["light"])
    rect(img, 0, 10, W, 11, C["ceil_dk"])
    rect(img, 0, 11, W, 30, C["wall"])
    rect(img, 0, 30, W, 60, C["wood"])
    rect(img, 0, 30, W, 31, C["wood_hi"])
    # Rows of seats with classmates, getting closer toward the bottom.
    floor_y = 60
    rect(img, 0, floor_y, W, H, C["floor"])
    for y, h, seat_w, gap, xs in ((54, 8, 12, 3, (6, 21, 236, 251)), (70, 12, 16, 4, (10, 30, 230, 250)),
                                  (92, 16, 22, 5, (2, 248))):
        heads(img, y, xs)
        seat_row(img, y, h, seat_w, gap, C)

    # The desk the laptop sits on.
    rect(img, 0, 112, W, H, C["desk_top"])
    rect(img, 0, 112, W, 113, C["desk_hi"])
    rect(img, 0, 140, W, H, C["desk_dk"])

    # Keyboard deck, in perspective, with keys and a trackpad.
    for y in range(116, H):
        inset = (y - 116) * -1 // 2 + 14
        rect(img, max(inset, 2), y, min(W - inset, W - 2), y + 1, C["deck"])
    rect(img, 14, 116, W - 14, 117, C["deck_hi"])
    for row, y in enumerate((119, 123, 127, 131)):
        inset = 22 - (y - 119) // 2
        x = inset + row
        while x + 7 < W - inset:
            rect(img, x, y, x + 7, y + 3, C["key"])
            rect(img, x, y, x + 7, y + 1, C["key_hi"])
            x += 8
    rect(img, 108, 135, 148, H, C["pad"])
    outline(img, 108, 135, 148, H + 1, C["deck_dk"])

    # The lid and screen.
    rect(img, 26, 12, 230, 118, C["lid"])
    rect(img, 26, 12, 230, 13, C["lid_hi"])
    rect(img, 26, 12, 27, 118, C["lid_hi"])
    rect(img, 229, 13, 230, 118, C["lid_dk"])
    rect(img, 126, 14, 130, 16, C["lid_dk"])  # webcam
    px(img, 127, 15, C["lens"])
    rect(img, 26, 116, 230, 118, C["lid_dk"])  # hinge
    x0, y0, x1, y1 = SCREEN
    rect(img, x0, y0, x1, y1, C["editor"])
    # Editor chrome: tab bar with the active tab, gutter, terminal panel.
    rect(img, *TAB_BAR, C["tabs"])
    rect(img, x0, y0, x0 + 32, TAB_BAR[3], C["tab_on"])
    rect(img, x0, y0, x0 + 32, y0 + 1, C["accent"])
    rect(img, *GUTTER, C["gutter"])
    rect(img, *TERMINAL, C["term"])
    rect(img, TERMINAL[0], TERMINAL[1], TERMINAL[2], TERMINAL[1] + 1, C["term_line"])
    # A glint on the glass, top right.
    for i in range(5):
        px(img, 214 + i, 30 - i, (52, 56, 68))
        px(img, 217 + i, 30 - i, (52, 56, 68))
    return img


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    lecture_seat().save(OUT / "lecture_seat.png")
    print("wrote", OUT)


if __name__ == "__main__":
    main()
