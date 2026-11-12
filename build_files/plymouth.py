"""Makes SuperAwesomeMagicalLinux's boot splash: Fedora's spinner theme with our mark and wordmark
in Lexend Bold over the slate background, and the spinner in aurora purple.

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
INK = (0xE6, 0xE9, 0xF2)

SS = 4  # supersampling for smooth edges


def arc_points(x1, y1, r, large, sweep, x2, y2, n=240):
    """Points along an SVG arc (circular, no rotation), per the SVG spec's centre parametrisation."""
    dx, dy = (x1 - x2) / 2, (y1 - y2) / 2
    sign = -1 if large == sweep else 1
    k = sign * math.sqrt(max(r * r - dx * dx - dy * dy, 0) / (dx * dx + dy * dy))
    cx, cy = k * dy + (x1 + x2) / 2, -k * dx + (y1 + y2) / 2
    a1 = math.atan2(y1 - cy, x1 - cx)
    a2 = math.atan2(y2 - cy, x2 - cx)
    delta = a2 - a1
    if sweep and delta < 0:
        delta += 2 * math.pi
    elif not sweep and delta > 0:
        delta -= 2 * math.pi
    return [(cx + r * math.cos(a1 + delta * i / n), cy + r * math.sin(a1 + delta * i / n)) for i in range(n + 1)]


def bezier_points(p0, p1, p2, p3, n=40):
    out = []
    for i in range(n + 1):
        t = i / n
        u = 1 - t
        out.append(tuple(u**3 * a + 3 * u * u * t * b + 3 * u * t * t * c + t**3 * d for a, b, c, d in zip(p0, p1, p2, p3)))
    return out


def logo(size: int) -> Image.Image:
    """The mark from components/Logo.qml (a 128 x 128 design), at size x size."""
    s = size * SS / 128
    img = Image.new("RGBA", (size * SS, size * SS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    radius = 17 / 2 * s
    for points, colour in (
        (arc_points(88, 34, 26, 1, 0, 62, 64), PRIMARY),
        (arc_points(62, 64, 26, 1, 1, 36, 94), SECONDARY),
    ):
        for x, y in points:  # a round-capped stroke: a disc at every step along the arc
            draw.ellipse((x * s - radius, y * s - radius, x * s + radius, y * s + radius), fill=colour)
    sparkle = []
    for seg in (
        ((108, 6), (110, 18), (112, 20), (124, 22)),
        ((124, 22), (112, 24), (110, 26), (108, 38)),
        ((108, 38), (106, 26), (104, 24), (92, 22)),
        ((92, 22), (104, 20), (106, 18), (108, 6)),
    ):
        sparkle += bezier_points(*seg)
    draw.polygon([(x * s, y * s) for x, y in sparkle], fill=PRIMARY)
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
    mark, words = logo(104), wordmark(30)
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
