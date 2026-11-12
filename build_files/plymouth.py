"""Makes SuperAwesomeMagicalLinux's boot splash: Fedora's spinner theme with our mark (the twin
sparkles) and wordmark in Lexend Bold over the slate background, and the spinner in aurora purple.

    python3 plymouth.py <spinner theme dir> <new theme dir> <Lexend variable font>
"""

import math
import shutil
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

SPINNER, THEME, LEXEND = (Path(a) for a in sys.argv[1:4])

BACKGROUND = "0x0B1220"  # the slate neutral
PRIMARY = (0xCF, 0xBD, 0xFF)  # aurora purple
SECONDARY = (0x6E, 0xF2, 0xB0)  # aurora green
MID = (0x9F, 0x8C, 0xFF)  # the deeper violet partway down the big sparkle
INK = (0xE6, 0xE9, 0xF2)

SS = 4  # supersampling for smooth edges


def bezier_points(p0, p1, p2, p3, n=48):
    out = []
    for i in range(n + 1):
        t = i / n
        u = 1 - t
        out.append(tuple(u**3 * a + 3 * u * u * t * b + 3 * u * t * t * c + t**3 * d for a, b, c, d in zip(p0, p1, p2, p3)))
    return out


def path_points(d: str) -> list:
    """Points along an SVG path made only of M, C and Z (how the mark's sparkles are written)."""
    nums = [float(v) for v in d.replace("M", " ").replace("C", " ").replace("Z", " ").split()]
    start, rest = tuple(nums[:2]), nums[2:]
    pts, cur = [start], start
    for i in range(0, len(rest), 6):
        c1, c2, end = tuple(rest[i:i + 2]), tuple(rest[i + 2:i + 4]), tuple(rest[i + 4:i + 6])
        pts += bezier_points(cur, c1, c2, end)[1:]
        cur = end
    return pts


# The same paths as components/Logo.qml and the hicolor superawesomemagical.svg.
BIG = "M56 12 C61 56 72 67 116 72 C72 77 61 88 56 124 C51 88 40 77 4 72 C40 67 51 56 56 12 Z"
SMALL = "M106 4 C108 17 111 20 124 22 C111 24 108 27 106 40 C104 27 101 24 88 22 C101 20 104 17 106 4 Z"


def lerp(c1, c2, t):
    return tuple(round(a + (b - a) * t) for a, b in zip(c1, c2))


def logo(size: int) -> Image.Image:
    """The mark from components/Logo.qml (a 128 x 128 design), at size x size: the big sparkle in
    a purple-to-green gradient, the small one in green."""
    s = size * SS / 128
    full = size * SS
    # The big sparkle's vertical gradient: purple, a deeper violet at 0.55, green, from y 12 to 124.
    gradient = Image.new("RGBA", (1, full))
    for y in range(full):
        t = min(max((y / s - 12) / 112, 0), 1)
        colour = lerp(PRIMARY, MID, t / 0.55) if t < 0.55 else lerp(MID, SECONDARY, (t - 0.55) / 0.45)
        gradient.putpixel((0, y), colour + (255,))
    gradient = gradient.resize((full, full))

    img = Image.new("RGBA", (full, full), (0, 0, 0, 0))
    mask = Image.new("L", (full, full), 0)
    ImageDraw.Draw(mask).polygon([(x * s, y * s) for x, y in path_points(BIG)], fill=255)
    img.paste(gradient, (0, 0), mask)
    ImageDraw.Draw(img).polygon([(x * s, y * s) for x, y in path_points(SMALL)], fill=SECONDARY)
    return img.resize((size, size), Image.LANCZOS)


def font(px: int, weight: int) -> ImageFont.FreeTypeFont:
    f = ImageFont.truetype(str(LEXEND), px * SS)
    f.set_variation_by_axes([weight])
    return f


def wordmark(px: int) -> Image.Image:
    """"SuperAwesomeMagical" in Lexend Bold, then "Linux" in purple."""
    bold, medium = font(px, 700), font(px, 500)
    parts = [("SuperAwesomeMagical", bold, INK), ("Linux", medium, PRIMARY)]
    widths = [draw_font.getlength(text) for text, draw_font, _ in parts]
    ascent, descent = bold.getmetrics()
    img = Image.new("RGBA", (math.ceil(sum(widths)) + 2 * SS, ascent + descent), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    x = 0
    for (text, draw_font, colour), width in zip(parts, widths):
        draw.text((x, 0), text, font=draw_font, fill=colour)
        x += width
    return img.resize((img.width // SS, img.height // SS), Image.LANCZOS)


def watermark() -> Image.Image:
    mark, words = logo(132), wordmark(30)
    gap = 22
    img = Image.new("RGBA", (max(mark.width, words.width), mark.height + gap + words.height), (0, 0, 0, 0))
    img.alpha_composite(mark, ((img.width - mark.width) // 2, 0))
    img.alpha_composite(words, ((img.width - words.width) // 2, mark.height + gap))
    return img


def tint(path: Path, colour) -> None:
    """Recolours one of the spinner's (light grey) frames, keeping its shading and transparency."""
    img = Image.open(path).convert("RGBA")
    r, g, b, a = img.split()
    light = Image.merge("RGB", (r, g, b)).convert("L")
    out = Image.merge("RGBA", tuple(light.point(lambda v, c=c: v * c // 255) for c in colour) + (a,))
    out.save(path)


THEME.mkdir(parents=True, exist_ok=True)
for png in SPINNER.glob("*.png"):
    shutil.copy2(png, THEME / png.name)
for png in list(THEME.glob("throbber-*.png")) + list(THEME.glob("animation-*.png")):
    tint(png, PRIMARY)
watermark().save(THEME / "watermark.png")

(THEME / "superawesomemagical.plymouth").write_text(f"""[Plymouth Theme]
Name=SuperAwesomeMagicalLinux
Description=SuperAwesomeMagicalLinux's boot splash: the aurora mark over slate, in Lexend
ModuleName=two-step

[two-step]
Font=Lexend 12
TitleFont=Lexend Bold 26
ImageDir={THEME}
WatermarkHorizontalAlignment=.5
WatermarkVerticalAlignment=.42
TitleHorizontalAlignment=.5
TitleVerticalAlignment=.64
HorizontalAlignment=.5
VerticalAlignment=.70
DialogHorizontalAlignment=.5
DialogVerticalAlignment=.70
Transition=none
TransitionDuration=0.0
BackgroundStartColor={BACKGROUND}
BackgroundEndColor={BACKGROUND}
ProgressBarBackgroundColor=0x2A3346
ProgressBarForegroundColor=0xCFBDFF
MessageBelowAnimation=true

[boot-up]
UseEndAnimation=false

[shutdown]
UseEndAnimation=false

[reboot]
UseEndAnimation=false

[updates]
SuppressMessages=true
ProgressBarShowPercentComplete=true
UseProgressBar=true
Title=Installing updates…
SubTitle=Your computer will restart by itself

[system-upgrade]
SuppressMessages=true
ProgressBarShowPercentComplete=true
UseProgressBar=true
Title=Upgrading…
SubTitle=Your computer will restart by itself

[firmware-upgrade]
SuppressMessages=true
ProgressBarShowPercentComplete=true
UseProgressBar=true
Title=Updating firmware…
SubTitle=Keep your computer plugged in and on

[system-reset]
SuppressMessages=true
ProgressBarShowPercentComplete=true
UseProgressBar=true
Title=Resetting…
SubTitle=Keep your computer plugged in and on
""")
