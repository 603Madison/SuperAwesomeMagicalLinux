"""Redraws fastfetch's logo (system_files/usr/share/superawesomemagical/fastfetch-logo.txt) from the
mark's paths in build_files/plymouth.py, in half-block characters: $1 purple, $2 green.

    python3 tools/fastfetch-logo.py
"""

import re
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
# Borrow the path maths and the mark's paths from the splash generator, without running it.
source = (ROOT / "build_files/plymouth.py").read_text().split("THEME.mkdir")[0]
source = source.replace("SPINNER, THEME, LEXEND = (Path(a) for a in sys.argv[1:4])", "")
names: dict = {}
exec(compile(source, "plymouth.py", "exec"), names)
path_points, BIG, SMALL = names["path_points"], names["BIG"], names["SMALL"]

SIZE = 30  # characters wide; each character is two "pixels" tall (half blocks)


def mask(d: str) -> Image.Image:
    m = Image.new("L", (SIZE * 8, SIZE * 8), 0)
    ImageDraw.Draw(m).polygon([(x * SIZE * 8 / 128, y * SIZE * 8 / 128) for x, y in path_points(d)], fill=255)
    return m.resize((SIZE, SIZE), Image.BOX)


big, small = mask(BIG), mask(SMALL)


def on(m: Image.Image, x: int, y: int) -> bool:
    return y < SIZE and m.getpixel((x, y)) > 100


lines = []
for row in range(0, SIZE, 2):
    line, colour = "", None
    for x in range(SIZE):
        top = on(big, x, row) or on(small, x, row)
        bottom = on(big, x, row + 1) or on(small, x, row + 1)
        char = "█" if top and bottom else "▀" if top else "▄" if bottom else " "
        if char != " ":
            # The small sparkle and the big one's lower tip are green, like the gradient's end.
            want = "$2" if on(small, x, row) or on(small, x, row + 1) or row / SIZE > 0.68 else "$1"
            if want != colour:
                line += want
                colour = want
        line += char
    lines.append(line.rstrip())
lines = [l for l in lines if l.replace("$1", "").replace("$2", "").strip()]
lines = [re.sub(r"^\$1(\s*)\$1", r"$1\1", l if l.startswith("$") else "$1" + l) for l in lines]
out = ROOT / "system_files/usr/share/superawesomemagical/fastfetch-logo.txt"
out.write_text("\n".join(lines) + "\n")
print(out.read_text().replace("$1", "\x1b[35m").replace("$2", "\x1b[32m") + "\x1b[0m", end="")
