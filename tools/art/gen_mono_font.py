"""Generates AggieMono, a monospaced pixel font for code, as a BMFont.

AggiePixel (gen_pixel_font.py) only has capitals, but code is case-sensitive
(Variable Not in Scope tells `y` from `Y`), so code on in-game screens uses
this font instead: upper and lower case, digits and the symbols C++ needs.
Every glyph sits in a 6 px cell (up to 5 px wide plus a gap); capitals are
6 px tall, lowercase has a 4 px x-height with ascenders and descenders. The
line is 8 px tall, so use font sizes that are multiples of 8 (16, 24, 32).

Run from the project root:  python tools/art/gen_mono_font.py
Writes assets/fonts/aggie_mono.png and assets/fonts/aggie_mono.fnt.
"""

from pathlib import Path

from PIL import Image

OUT = Path(__file__).resolve().parents[2] / "assets" / "fonts"
CELL = 6
LINE_HEIGHT = 8
BASE = 6
ROWS = 7  # 6 rows down to the baseline, then one descender row


def tall(*rows):
    """A glyph that fills the 6 rows down to the baseline."""
    return list(rows) + ["." * len(rows[0])]


def small(*rows):
    """A lowercase glyph in the 4-row x-height."""
    return ["." * len(rows[0])] * 2 + list(rows) + ["." * len(rows[0])]


def desc(*rows):
    """A lowercase glyph with a descender: 4 x-height rows and one below."""
    return ["." * len(rows[0])] * 2 + list(rows)


GLYPHS = {
    "A": tall(".##.", "#..#", "#..#", "####", "#..#", "#..#"),
    "B": tall("###.", "#..#", "###.", "#..#", "#..#", "###."),
    "C": tall(".###", "#...", "#...", "#...", "#...", ".###"),
    "D": tall("###.", "#..#", "#..#", "#..#", "#..#", "###."),
    "E": tall("####", "#...", "###.", "#...", "#...", "####"),
    "F": tall("####", "#...", "###.", "#...", "#...", "#..."),
    "G": tall(".###", "#...", "#.##", "#..#", "#..#", ".###"),
    "H": tall("#..#", "#..#", "####", "#..#", "#..#", "#..#"),
    "I": tall("###", ".#.", ".#.", ".#.", ".#.", "###"),
    "J": tall("..##", "...#", "...#", "...#", "#..#", ".##."),
    "K": tall("#..#", "#.#.", "##..", "#.#.", "#..#", "#..#"),
    "L": tall("#...", "#...", "#...", "#...", "#...", "####"),
    "M": tall("#...#", "##.##", "#.#.#", "#...#", "#...#", "#...#"),
    "N": tall("#..#", "##.#", "#.##", "#..#", "#..#", "#..#"),
    "O": tall(".##.", "#..#", "#..#", "#..#", "#..#", ".##."),
    "P": tall("###.", "#..#", "#..#", "###.", "#...", "#..."),
    "Q": tall(".##.", "#..#", "#..#", "#..#", "#.#.", ".#.#"),
    "R": tall("###.", "#..#", "#..#", "###.", "#.#.", "#..#"),
    "S": tall(".###", "#...", ".##.", "...#", "...#", "###."),
    "T": tall("###", ".#.", ".#.", ".#.", ".#.", ".#."),
    "U": tall("#..#", "#..#", "#..#", "#..#", "#..#", ".##."),
    "V": tall("#...#", "#...#", "#...#", ".#.#.", ".#.#.", "..#.."),
    "W": tall("#...#", "#...#", "#.#.#", "#.#.#", "##.##", "#...#"),
    "X": tall("#..#", "#..#", ".##.", ".##.", "#..#", "#..#"),
    "Y": tall("#.#", "#.#", "#.#", ".#.", ".#.", ".#."),
    "Z": tall("####", "...#", "..#.", ".#..", "#...", "####"),
    "a": small(".###", "#..#", "#..#", ".###"),
    "b": tall("#...", "#...", "###.", "#..#", "#..#", "###."),
    "c": small(".###", "#...", "#...", ".###"),
    "d": tall("...#", "...#", ".###", "#..#", "#..#", ".###"),
    "e": small(".##.", "####", "#...", ".###"),
    "f": tall("..##", ".#..", "###.", ".#..", ".#..", ".#.."),
    "g": desc(".###", "#..#", ".###", "...#", ".##."),
    "h": tall("#...", "#...", "###.", "#..#", "#..#", "#..#"),
    "i": tall(".#.", "...", "##.", ".#.", ".#.", "###"),
    "j": ["..#", "...", ".##", "..#", "..#", "..#", "##."],
    "k": tall("#...", "#...", "#.#.", "##..", "#.#.", "#..#"),
    "l": tall("##.", ".#.", ".#.", ".#.", ".#.", "###"),
    "m": small("####.", "#.#.#", "#.#.#", "#.#.#"),
    "n": small("###.", "#..#", "#..#", "#..#"),
    "o": small(".##.", "#..#", "#..#", ".##."),
    "p": desc("###.", "#..#", "#..#", "###.", "#..."),
    "q": desc(".###", "#..#", "#..#", ".###", "...#"),
    "r": small("#.##", "##..", "#...", "#..."),
    "s": small(".###", "##..", "..##", "###."),
    "t": tall("....", ".#..", "###.", ".#..", ".#..", "..##"),
    "u": small("#..#", "#..#", "#..#", ".###"),
    "v": small("#...#", "#...#", ".#.#.", "..#.."),
    "w": small("#...#", "#.#.#", "#.#.#", ".#.#."),
    "x": small("#..#", ".##.", ".##.", "#..#"),
    "y": desc("#..#", "#..#", ".###", "...#", ".##."),
    "z": small("####", "..#.", ".#..", "####"),
    "0": tall(".##.", "#..#", "#.##", "##.#", "#..#", ".##."),
    "1": tall(".#.", "##.", ".#.", ".#.", ".#.", "###"),
    "2": tall(".##.", "#..#", "..#.", ".#..", "#...", "####"),
    "3": tall("###.", "...#", ".##.", "...#", "...#", "###."),
    "4": tall("#..#", "#..#", "####", "...#", "...#", "...#"),
    "5": tall("####", "#...", "###.", "...#", "...#", "###."),
    "6": tall(".##.", "#...", "###.", "#..#", "#..#", ".##."),
    "7": tall("####", "...#", "..#.", ".#..", ".#..", ".#.."),
    "8": tall(".##.", "#..#", ".##.", "#..#", "#..#", ".##."),
    "9": tall(".##.", "#..#", "#..#", ".###", "...#", ".##."),
    " ": tall("...", "...", "...", "...", "...", "..."),
    ";": [".", ".", "#", ".", ".", "#", "#"],
    ":": tall(".", ".", "#", ".", ".", "#"),
    ".": tall(".", ".", ".", ".", ".", "#"),
    ",": [".", ".", ".", ".", ".", "#", "#"],
    "'": tall("#", "#", ".", ".", ".", "."),
    '"': tall("#.#", "#.#", "...", "...", "...", "..."),
    "!": tall("#", "#", "#", "#", ".", "#"),
    "?": tall(".##.", "#..#", "..#.", ".#..", "....", ".#.."),
    "=": tall("....", "....", "####", "....", "####", "...."),
    "+": tall("...", "...", ".#.", "###", ".#.", "..."),
    "-": tall("...", "...", "...", "###", "...", "..."),
    "*": tall("...", "#.#", ".#.", "#.#", "...", "..."),
    "/": tall("...#", "...#", "..#.", ".#..", "#...", "#..."),
    "<": tall("...", "..#", ".#.", "#..", ".#.", "..#"),
    ">": tall("...", "#..", ".#.", "..#", ".#.", "#.."),
    "_": ["....", "....", "....", "....", "....", "....", "####"],
    "(": tall(".#", "#.", "#.", "#.", "#.", ".#"),
    ")": tall("#.", ".#", ".#", ".#", ".#", "#."),
    "{": ["..#", ".#.", ".#.", "#..", ".#.", ".#.", "..#"],
    "}": ["#..", ".#.", ".#.", "..#", ".#.", ".#.", "#.."],
    "[": tall("##", "#.", "#.", "#.", "#.", "##"),
    "]": tall("##", ".#", ".#", ".#", ".#", "##"),
    "#": tall(".#.#.", "#####", ".#.#.", ".#.#.", "#####", ".#.#."),
    "&": tall(".#..", "#.#.", ".#..", "#.#.", "#..#", ".##."),
    "|": tall("#", "#", "#", "#", "#", "#"),
    "%": tall("#..#", "...#", "..#.", ".#..", "#...", "#..#"),
    "✓": tall(".....", "....#", "...#.", "#.#..", ".#...", "....."),
    "✗": tall(".....", "#...#", ".#.#.", "..#..", ".#.#.", "#...#"),
}
ALIASES = {"—": "-", "–": "-", "✔": "✓", "✖": "✗", "·": "."}


def main():
    for name, glyph in GLYPHS.items():
        assert len(glyph) == ROWS, f"{name!r} has {len(glyph)} rows"
        assert len({len(row) for row in glyph}) == 1, f"{name!r} has ragged rows"
        assert len(glyph[0]) <= CELL - 1, f"{name!r} is too wide"
    OUT.mkdir(parents=True, exist_ok=True)
    names = list(GLYPHS)
    cols = 16
    rows = (len(names) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * CELL, rows * LINE_HEIGHT), (0, 0, 0, 0))
    places = {}
    for i, name in enumerate(names):
        cx, cy = (i % cols) * CELL, (i // cols) * LINE_HEIGHT
        glyph = GLYPHS[name]
        for row, line in enumerate(glyph):
            for col, v in enumerate(line):
                if v == "#":
                    sheet.putpixel((cx + col, cy + row), (255, 255, 255, 255))
        places[name] = (cx, cy, len(glyph[0]))
    sheet.save(OUT / "aggie_mono.png")

    lines = [
        'info face="AggieMono" size=8 bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=0,0',
        f"common lineHeight={LINE_HEIGHT} base={BASE} scaleW={sheet.width} scaleH={sheet.height} pages=1 packed=0",
        'page id=0 file="aggie_mono.png"',
    ]
    chars = [(ord(name), *places[name]) for name in names]
    chars += [(ord(alias), *places[target]) for alias, target in ALIASES.items()]
    lines.append(f"chars count={len(chars)}")
    for cid, x, y, w in sorted(chars):
        # Centre narrow glyphs in the cell so every character advances the same.
        lines.append(
            f"char id={cid} x={x} y={y} width={w} height={LINE_HEIGHT} xoffset={(CELL - 1 - w) // 2} yoffset=0 xadvance={CELL} page=0 chnl=15"
        )
    (OUT / "aggie_mono.fnt").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("wrote", OUT, len(chars), "characters")


if __name__ == "__main__":
    main()
