"""Makes product.img: SuperAwesomeMagicalLinux's look for the installer (Anaconda).

Anaconda's boot scripts unpack images/product.img from the install media over the installer's own
files before it starts, so this replaces Fedora's installer stylesheet (pixmaps/fedora.css, which
Anaconda's Fedora profile loads) and the pictures it uses with ours: the slate sidebar with the
aurora's glow and our mark, and Lexend for the text. The product name ("SuperAwesomeMagicalLinux
45") already comes from the image's os-release.

    python3 branding.py <build_files dir> <Lexend font> <product.img to write>

The ISO workflow runs it inside the published image (which has Pillow and Lexend) and adds the
result to the ISO with mkksiso.
"""

import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

BUILD_FILES, LEXEND, OUT = (Path(a) for a in sys.argv[1:4])

# The mark and Lexend helpers from the boot splash's generator (build_files/plymouth.py), without
# running it.
_source = (BUILD_FILES / "plymouth.py").read_text().split("THEME.mkdir")[0]
_source = _source.replace("SPINNER, THEME, LEXEND = (Path(a) for a in sys.argv[1:4])", f"LEXEND = Path({str(LEXEND)!r})")
_names: dict = {}
exec(compile(_source, "plymouth.py", "exec"), _names)
logo, font, SS = _names["logo"], _names["font"], _names["SS"]

SLATE = (0x0B, 0x12, 0x20)
PRIMARY = (0xCF, 0xBD, 0xFF)
SECONDARY = (0x6E, 0xF2, 0xB0)
INK = (0xE6, 0xE9, 0xF2)

PIXMAPS = "usr/share/anaconda/pixmaps"
OURS = f"{PIXMAPS}/superawesomemagical"


def glow(size, blobs):
    """Slate with soft blurred glows of colour: blobs are (centre x, centre y, radius, colour, alpha)."""
    w, h = size
    img = Image.new("RGB", size, SLATE)
    for cx, cy, r, colour, alpha in blobs:
        layer = Image.new("RGBA", size, colour + (0,))
        ImageDraw.Draw(layer).ellipse((cx - r, cy - r, cx + r, cy + r), fill=colour + (alpha,))
        layer = layer.filter(ImageFilter.GaussianBlur(r * 0.6))
        img = Image.alpha_composite(img.convert("RGBA"), layer).convert("RGB")
    return img


def sidebar_logo():
    """The mark over "SuperAwesome / MagicalLinux" in Lexend Bold, to fit the installer's sidebar."""
    mark = logo(72)
    lines = [("SuperAwesome", INK), ("Magical", INK)]
    bold = font(19, 700)
    ascent, descent = bold.getmetrics()
    line_h = ascent + descent
    width = max(int(bold.getlength(t)) for t, _ in lines) + 2 * SS
    text = Image.new("RGBA", (width, line_h * len(lines)), (0, 0, 0, 0))
    draw = ImageDraw.Draw(text)
    for i, (t, colour) in enumerate(lines):
        draw.text(((width - bold.getlength(t)) / 2, i * line_h), t, font=bold, fill=colour)
    text = text.resize((text.width // SS, text.height // SS), Image.LANCZOS)
    gap = 10
    out = Image.new("RGBA", (max(mark.width, text.width), mark.height + gap + text.height), (0, 0, 0, 0))
    out.alpha_composite(mark, ((out.width - mark.width) // 2, 0))
    out.alpha_composite(text, ((out.width - text.width) // 2, mark.height + gap))
    return out


STYLESHEET = """/* SuperAwesomeMagicalLinux's look for the installer: the desktop's slate and aurora, in Lexend.
 * (This replaces Fedora's installer stylesheet; see disk_config/installer/branding.py.) */

@define-color fedora #0B1220;
@define-color sam_primary #5B3FD1;
@define-color sam_primary_hover #6A50DB;

* {
    font-family: "Lexend";
}

.logo-sidebar {
    background-image: url('/usr/share/anaconda/pixmaps/superawesomemagical/sidebar-bg.png');
    background-color: @fedora;
    background-repeat: no-repeat;
}

.logo {
    background-image: url('/usr/share/anaconda/pixmaps/superawesomemagical/sidebar-logo.png');
    background-position: 50% 24px;
    background-repeat: no-repeat;
    background-color: transparent;
}

.product-logo {
    background-image: none;
    background-color: transparent;
}

AnacondaSpokeWindow #nav-box {
    background-color: @fedora;
    background-image: url('/usr/share/anaconda/pixmaps/superawesomemagical/topbar-bg.png');
    background-repeat: no-repeat;
    color: white;
}

/* "Begin Installation" and the like, in the family's purple. */
button.suggested-action {
    background-image: none;
    background-color: @sam_primary;
    border-color: @sam_primary;
    color: white;
    font-weight: bold;
}

button.suggested-action:hover {
    background-color: @sam_primary_hover;
}
"""


with tempfile.TemporaryDirectory() as tmp:
    root = Path(tmp)
    (root / OURS).mkdir(parents=True)
    glow((406, 767), [(60, 120, 220, PRIMARY, 110), (330, 620, 240, SECONDARY, 70)]).save(root / OURS / "sidebar-bg.png")
    glow((1040, 132), [(120, 20, 160, PRIMARY, 90), (900, 140, 180, SECONDARY, 55)]).save(root / OURS / "topbar-bg.png")
    sidebar_logo().save(root / OURS / "sidebar-logo.png")
    (root / PIXMAPS / "fedora.css").write_text(STYLESHEET)
    fonts = root / "usr/share/fonts/lexend"
    fonts.mkdir(parents=True)
    shutil.copy2(LEXEND, fonts / LEXEND.name)

    # A gzipped cpio archive (newc), as Anaconda's boot scripts unpack it.
    files = sorted(str(p.relative_to(root)) for p in root.rglob("*"))
    cpio = subprocess.run(["cpio", "--quiet", "-o", "-H", "newc", "--owner", "0:0"], cwd=root,
                          input="\n".join(files).encode(), stdout=subprocess.PIPE, check=True).stdout
    OUT.parent.mkdir(parents=True, exist_ok=True)
    with open(OUT, "wb") as f:
        f.write(subprocess.run(["gzip", "-9n"], input=cpio, stdout=subprocess.PIPE, check=True).stdout)
    print(f"{OUT}: {OUT.stat().st_size} bytes, {len(files)} entries")
    for name in files:
        print("  " + name)
