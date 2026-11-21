"""Generates AggiePixel, a chunky 5x5 capitals pixel font, as a BMFont.

Glyphs are drawn for this game: bold capitals with a thick left stroke,
digits, basic punctuation and a few symbols the microgames use. Lowercase
letters map to the capitals. The font is 7 px tall (5 px glyphs plus line
spacing); use font sizes that are multiples of 7 so it scales by whole pixels.

Run from the project root:  python tools/art/gen_pixel_font.py
Writes assets/fonts/aggie_pixel.png and assets/fonts/aggie_pixel.fnt.
"""

from pathlib import Path

from PIL import Image

OUT = Path(__file__).resolve().parents[2] / "assets" / "fonts"
LINE_HEIGHT = 7
BASE = 6

GLYPHS = {
    "A": [".####", "##..#", "#####", "##..#", "##..#"],
    "B": ["####.", "##..#", "####.", "##..#", "####."],
    "C": [".####", "##...", "##...", "##...", ".####"],
    "D": ["####.", "##..#", "##..#", "##..#", "####."],
    "E": ["#####", "##...", "####.", "##...", "#####"],
    "F": ["#####", "##...", "####.", "##...", "##..."],
    "G": [".####", "##...", "##.##", "##..#", ".####"],
    "H": ["##..#", "##..#", "#####", "##..#", "##..#"],
    "I": ["#####", ".##..", ".##..", ".##..", "#####"],
    "J": ["..###", "...##", "...##", "##.##", ".###."],
    "K": ["##..#", "##.#.", "###..", "##.#.", "##..#"],
    "L": ["##...", "##...", "##...", "##...", "#####"],
    "M": ["##..#", "#####", "##.##", "##..#", "##..#"],
    "N": ["##..#", "###.#", "#####", "##.##", "##..#"],
    "O": [".###.", "##..#", "##..#", "##..#", ".###."],
    "P": ["####.", "##..#", "##..#", "####.", "##..."],
    "Q": [".###.", "##..#", "##..#", "##.#.", ".##.#"],
    "R": ["####.", "##..#", "####.", "##.#.", "##..#"],
    "S": [".####", "##...", ".###.", "...##", "####."],
    "T": ["#####", ".##..", ".##..", ".##..", ".##.."],
    "U": ["##..#", "##..#", "##..#", "##..#", ".###."],
    "V": ["##..#", "##..#", ".##.#", ".###.", "..#.."],
    "W": ["##..#", "##..#", "##.##", "#####", ".#.#."],
    "X": ["##..#", ".###.", "..#..", ".###.", "##..#"],
    "Y": ["##..#", ".##.#", "..##.", "..##.", "..##."],
    "Z": ["#####", "...##", "..##.", ".##..", "#####"],
    "0": [".###.", "##.##", "##.##", "##.##", ".###."],
    "1": [".##..", "###..", ".##..", ".##..", "####."],
    "2": ["####.", "...##", ".###.", "##...", "#####"],
    "3": ["####.", "...##", ".###.", "...##", "####."],
    "4": ["##.#.", "##.#.", "#####", "...#.", "...#."],
    "5": ["#####", "##...", "####.", "...##", "####."],
    "6": [".###.", "##...", "####.", "##..#", ".###."],
    "7": ["#####", "...##", "..##.", ".##..", ".##.."],
    "8": [".###.", "##..#", ".###.", "##..#", ".###."],
    "9": [".###.", "##..#", ".####", "...##", ".###."],
    " ": ["...", "...", "...", "...", "..."],
    ".": ["..", "..", "..", "..", "##"],
    ",": ["..", "..", "..", "##", "#."],
    ":": ["..", "##", "..", "##", ".."],
    ";": ["..", "##", "..", "##", "#."],
    "!": ["##", "##", "##", "..", "##"],
    "?": [".###.", "...##", "..##.", ".....", "..##."],
    "'": ["##", "#.", "..", "..", ".."],
    "-": ["....", "....", "####", "....", "...."],
    "+": ["...", ".#.", "###", ".#.", "..."],
    "/": ["...#", "..#.", ".##.", ".#..", "#..."],
    "(": [".#", "#.", "#.", "#.", ".#"],
    ")": ["#.", ".#", ".#", ".#", "#."],
    "%": ["#..#", "..#.", ".##.", ".#..", "#..#"],
    "→": ["..#..", "...#.", "#####", "...#.", "..#.."],
    "←": ["..#..", ".#...", "#####", ".#...", "..#.."],
    "✓": ["....#", "...##", "#.##.", "###..", ".#..."],
    "✗": ["##..#", ".###.", "..#..", ".###.", "##..#"],
    "▼": [".....", "#####", ".###.", "..#..", "....."],
    "▲": [".....", "..#..", ".###.", "#####", "....."],
    "●": [".###.", "#####", "#####", "#####", ".###."],
}
# Characters drawn with another glyph.
ALIASES = {"—": "-", "–": "-", "✔": "✓", "✖": "✗", "·": "."}
ALIASES.update({c.lower(): c for c in GLYPHS if c.isalpha() and c.isascii()})


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    names = list(GLYPHS)
    cols = 16
    cell_w, cell_h = 6, LINE_HEIGHT
    rows = (len(names) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * cell_w, rows * cell_h), (0, 0, 0, 0))
    places = {}
    for i, name in enumerate(names):
        cx, cy = (i % cols) * cell_w, (i // cols) * cell_h
        glyph = GLYPHS[name]
        for row, line in enumerate(glyph):
            for col, v in enumerate(line):
                if v == "#":
                    sheet.putpixel((cx + col, cy + 1 + row), (255, 255, 255, 255))
        places[name] = (cx, cy, len(glyph[0]))
    sheet.save(OUT / "aggie_pixel.png")

    lines = [
        'info face="AggiePixel" size=7 bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=0,0',
        f"common lineHeight={LINE_HEIGHT} base={BASE} scaleW={sheet.width} scaleH={sheet.height} pages=1 packed=0",
        'page id=0 file="aggie_pixel.png"',
    ]
    chars = []
    for name, (x, y, w) in places.items():
        chars.append((ord(name), x, y, w))
    for alias, target in ALIASES.items():
        x, y, w = places[target]
        chars.append((ord(alias), x, y, w))
    lines.append(f"chars count={len(chars)}")
    for cid, x, y, w in sorted(chars):
        lines.append(
            f"char id={cid} x={x} y={y} width={w} height={LINE_HEIGHT} xoffset=0 yoffset=0 xadvance={w + 1} page=0 chnl=15"
        )
    (OUT / "aggie_pixel.fnt").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("wrote", OUT, len(chars), "characters")


if __name__ == "__main__":
    main()
