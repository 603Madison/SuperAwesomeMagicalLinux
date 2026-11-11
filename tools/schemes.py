#!/usr/bin/env python3
"""Write SuperAwesomeMagicalLinux's colour schemes for the Caelestia shell.

    pip install materialyoucolor
    git clone https://github.com/caelestia-dots/cli /tmp/caelestia-cli
    python3 tools/schemes.py --cli /tmp/caelestia-cli

The schemes, in dark and light: SuperAwesomeMagical (the default, aurora purple and green), Clear
Sky (the original bright blue), and SuperAwesomeMagicalWeather's named themes (Harbor, Evergreen,
Maple, Lupine, Aurora, Driftwood). For each one, Caelestia's own generator makes a complete scheme
(terminal colours, app colours and so on) from the primary colour, and then the Material colours
are replaced with exactly the ones below: the brand's slate neutrals, and for the named themes the
same tinting Weather's schemeFrom() does.

Output: system_files/usr/share/superawesomemagical/schemes/<name>/default/<mode>.txt, in the
CLI's scheme format (the image build links them into the CLI's scheme folder), and the default
scheme as Hyprland colours in system_files/usr/share/superawesomemagical/hypr/scheme/current.lua,
which is used until the CLI writes an account's own.
"""
from __future__ import annotations

import argparse
import sys
from dataclasses import dataclass
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "system_files/usr/share/superawesomemagical/schemes"

# ---- The colours ----
#
# SuperAwesomeMagical's colours are the aurora's: purple (primary) and green (secondary), with the
# ecosystem's original blue as the tertiary accent, over the cool slate neutrals every app shares.
# The purple is SuperAwesomeMagicalMusic's violet; the green is the aurora green of Weather's Aurora
# theme (deepened a little in light mode so white text on it stays above 4.5:1).
#
# The neutrals, outline and error colours are Weather's (ui/BrandColors.kt), shared by all the apps.

NEUTRALS = {
    "dark": dict(
        background="0B1220", onBackground="E5E9F0", surface="0B1220", onSurface="E5E9F0",
        surfaceVariant="1E293B", onSurfaceVariant="A9B4C6",
        surfaceContainerLowest="070C16", surfaceContainerLow="0F1828", surfaceContainer="131D30",
        surfaceContainerHigh="1A2539", surfaceContainerHighest="223047",
        outline="3B4A63", outlineVariant="263349",
        error="FF8A80", onError="5C0000", errorContainer="6B1515", onErrorContainer="FFDAD6",
    ),
    "light": dict(
        background="F5F7FB", onBackground="111827", surface="F5F7FB", onSurface="111827",
        surfaceVariant="E4E9F2", onSurfaceVariant="4B5565",
        surfaceContainerLowest="FFFFFF", surfaceContainerLow="FBFCFE", surfaceContainer="FFFFFF",
        surfaceContainerHigh="EEF2F8", surfaceContainerHighest="E6EBF3",
        outline="B8C1CF", outlineVariant="DDE3EC",
        error="C62828", onError="FFFFFF", errorContainer="FFDAD6", onErrorContainer="410002",
    ),
}

# The default: aurora purple and green.
BRAND = {
    "dark": dict(
        primary="CFBDFF", onPrimary="341A86", primaryContainer="4B33A8", onPrimaryContainer="E9DDFF",
        secondary="6EF2B0", onSecondary="003822", secondaryContainer="005233", onSecondaryContainer="C0FFD8",
        tertiary="8DB4FF", onTertiary="0A1E4A", tertiaryContainer="1D3B85", onTertiaryContainer="DCE6FF",
        **NEUTRALS["dark"],
    ),
    "light": dict(
        primary="5B3FD1", onPrimary="FFFFFF", primaryContainer="E9DDFF", onPrimaryContainer="1D0060",
        secondary="0B7A4F", onSecondary="FFFFFF", secondaryContainer="DDECE3", onSecondaryContainer="002112",
        tertiary="2563EB", onTertiary="FFFFFF", tertiaryContainer="DCE6FF", onTertiaryContainer="0B2A6B",
        **NEUTRALS["light"],
    ),
}

# "Clear Sky": the ecosystem's original bright blue (Weather's default theme), still offered.
CLEARSKY = {
    "dark": dict(
        primary="8DB4FF", onPrimary="0A1E4A", primaryContainer="1D3B85", onPrimaryContainer="DCE6FF",
        secondary="7CCBF2", onSecondary="00344D", secondaryContainer="0D4A6B", onSecondaryContainer="D5EEFB",
        tertiary="FFB86B", onTertiary="4A2304", tertiaryContainer="6B3A0C", onTertiaryContainer="FFE6C7",
        **NEUTRALS["dark"],
    ),
    "light": dict(
        primary="2563EB", onPrimary="FFFFFF", primaryContainer="DCE6FF", onPrimaryContainer="0B2A6B",
        secondary="0E7FB8", onSecondary="FFFFFF", secondaryContainer="D5EEFB", onSecondaryContainer="07344C",
        tertiary="B45309", onTertiary="FFFFFF", tertiaryContainer="FFE6C7", onTertiaryContainer="4A2304",
        **NEUTRALS["light"],
    ),
}


# Terminal colours: fixed and readable in every theme, so red always means red. Built from the apps'
# status colours (Cockpit Manager's good/bad/warn/info) and accents. Light schemes swap the light
# and dark slots, as Caelestia's do, so "white" is the text colour.
TERMINAL = {
    "dark": ["1a2539", "ff8a80", "4ade80", "ffb86b", "8db4ff", "c3a6ff", "7ccbf2", "c9d1de",
             "6b7891", "ffada6", "86efac", "ffd199", "b3cdff", "dccbff", "a8ddf7", "f5f7fb"],
    "light": ["8a94a6", "c62828", "15803d", "b45309", "2563eb", "6a3fc4", "0e7fb8", "1f2937",
              "4b5565", "dc2626", "16a34a", "d97706", "3b82f6", "8b5cf6", "0891b2", "111827"],
}


@dataclass
class Palette:
    primary: str
    secondary: str
    tertiary: str
    background_top: str
    background_bottom: str


# name -> (dark, light), as in Weather's palette().
THEMES: dict[str, tuple[Palette, Palette]] = {
    "harbor": (Palette("6FD3CF", "8FB8C9", "F2B880", "0D2E31", "061416"),
               Palette("0F7C80", "3F6E80", "B86B2B", "CBE7E6", "F2F8F8")),
    "evergreen": (Palette("7FCB95", "A6B8AE", "E0C27A", "12291B", "07120C"),
                  Palette("2E6B45", "5D7366", "9A6B1F", "D3E6D8", "F4F8F4")),
    "maple": (Palette("FF8F6B", "F2C46B", "C9A0DC", "33150E", "160907"),
              Palette("B83A1E", "B7791F", "7A4E9C", "F8D9C8", "FFF7F1")),
    "lupine": (Palette("C3A6FF", "F2A7D8", "8FD3A6", "221838", "0D0A19"),
               Palette("6A3FC4", "B0458F", "2E7D4F", "E2D6F8", "FAF7FE")),
    "aurora": (Palette("6EF2B0", "B28CFF", "6EC8FF", "0B2530", "05080F"),
               Palette("128A5B", "6A4BC4", "0F78B5", "CDEEE0", "EAE4FA")),
    "driftwood": (Palette("E0B98A", "B4A99B", "9CC3C9", "29221A", "110E0B"),
                  Palette("8A5A2B", "6F655B", "3F7F87", "EADCC8", "FAF6F0")),
}

# ---- Colour maths: Compose's lerp() mixes in Oklab, so this does too ----


def _lin(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def _gam(c: float) -> float:
    c = min(max(c, 0.0), 1.0)
    return 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055


def to_oklab(h: str) -> tuple[float, float, float]:
    r, g, b = (_lin(int(h[i:i + 2], 16) / 255) for i in (0, 2, 4))
    l_ = (0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b) ** (1 / 3)
    m_ = (0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b) ** (1 / 3)
    s_ = (0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b) ** (1 / 3)
    return (0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_,
            1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_,
            0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_)


def from_oklab(L: float, a: float, b: float) -> str:
    l_ = (L + 0.3963377774 * a + 0.2158037573 * b) ** 3
    m_ = (L - 0.1055613458 * a - 0.0638541728 * b) ** 3
    s_ = (L - 0.0894841775 * a - 1.2914855480 * b) ** 3
    r = 4.0767416621 * l_ - 3.3077115913 * m_ + 0.2309699292 * s_
    g = -1.2684380046 * l_ + 2.6097574011 * m_ - 0.3413193965 * s_
    bb = -0.0041960863 * l_ - 0.7034186147 * m_ + 1.7076147010 * s_
    return "".join(f"{round(_gam(c) * 255):02X}" for c in (r, g, bb))


def lerp(a: str, b: str, t: float) -> str:
    x, y = to_oklab(a), to_oklab(b)
    return from_oklab(*(x[i] + (y[i] - x[i]) * t for i in range(3)))


def luminance(h: str) -> float:
    r, g, b = (_lin(int(h[i:i + 2], 16) / 255) for i in (0, 2, 4))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def on(h: str) -> str:
    return "111111" if luminance(h) > 0.45 else "FFFFFF"


def scheme_from(base: dict[str, str], p: Palette, dark: bool) -> dict[str, str]:
    """Weather's schemeFrom(): the palette's accents, with surfaces tinted towards the theme."""
    neutral = "0B0F17" if dark else "FFFFFF"
    surface = lerp(neutral, p.primary, 0.09 if dark else 0.04)

    def container(c: str) -> str:
        return lerp(neutral, c, 0.32 if dark else 0.16)

    s = dict(base)
    s.update(
        primary=p.primary, onPrimary=on(p.primary), primaryContainer=container(p.primary),
        onPrimaryContainer=lerp(p.primary, "FFFFFF", 0.7) if dark else lerp(p.primary, "000000", 0.55),
        secondary=p.secondary, onSecondary=on(p.secondary), secondaryContainer=container(p.secondary),
        onSecondaryContainer=lerp(p.secondary, "FFFFFF", 0.75) if dark else lerp(p.secondary, "000000", 0.6),
        tertiary=p.tertiary, onTertiary=on(p.tertiary), tertiaryContainer=container(p.tertiary),
        onTertiaryContainer=lerp(p.tertiary, "FFFFFF", 0.7) if dark else lerp(p.tertiary, "000000", 0.55),
        background=p.background_bottom, surface=p.background_bottom,
        surfaceVariant=lerp(surface, p.primary, 0.12 if dark else 0.08),
        surfaceContainerLowest=surface, surfaceContainerLow=surface, surfaceContainer=surface,
        surfaceContainerHigh=lerp(surface, p.primary, 0.06 if dark else 0.04),
        surfaceContainerHighest=lerp(surface, p.primary, 0.10 if dark else 0.07),
        outline=lerp(base["outline"], p.primary, 0.2),
        outlineVariant=lerp(base["outlineVariant"], p.primary, 0.12),
    )
    return s


# ---- Fill in everything else with Caelestia's generator ----


@dataclass
class _Scheme:
    mode: str
    variant: str = "tonalspot"
    flavour: str = "default"


def full_scheme(exact: dict[str, str], mode: str) -> dict[str, str]:
    from caelestia.utils.material.generator import darken, gen_scheme, hex_to_hct, mix

    def hx(hct) -> str:
        return f"{hct.to_int() & 0xFFFFFF:06x}"

    colours = gen_scheme(_Scheme(mode), hex_to_hct(exact["primary"]))  # hex strings
    colours.update({k: v.lower() for k, v in exact.items()})
    # Tokens that follow the core ones.
    colours["surfaceTint"] = colours["primary"]
    colours["surfaceDim"] = colours["background"]
    for i, c in enumerate(TERMINAL[mode]):
        colours[f"term{i}"] = c
    # Status green, as in Cockpit Manager's StatusColors.
    colours["success"] = "4ade80" if mode == "dark" else "15803d"
    # The derived names gen_scheme() computes at the end, recomputed from the exact colours.
    surface, outline = hex_to_hct(colours["surface"]), hex_to_hct(colours["outline"])
    colours["text"] = colours["onBackground"]
    colours["subtext1"] = colours["onSurfaceVariant"]
    colours["subtext0"] = colours["outline"]
    for i, w in enumerate((0.57, 0.71, 0.86)):
        colours[f"overlay{i}"] = hx(mix(surface, outline, w))
    for i, w in enumerate((0.14, 0.29, 0.43)):
        colours[f"surface{i}"] = hx(mix(surface, outline, w))
    colours["base"] = colours["surface"]
    colours["mantle"] = hx(darken(hex_to_hct(colours["surface"]), 0.03))
    colours["crust"] = hx(darken(hex_to_hct(colours["surface"]), 0.05))
    return colours


def write(name: str, mode: str, colours: dict[str, str]) -> None:
    path = OUT / name / "default" / f"{mode}.txt"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("".join(f"{k} {v}\n" for k, v in colours.items()))
    print(f"wrote {path}")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--cli", type=Path, required=True, help="a checkout of github.com/caelestia-dots/cli")
    a = ap.parse_args()
    sys.path.insert(0, str(a.cli / "src"))

    for mode in ("dark", "light"):
        write("superawesomemagical", mode, full_scheme(BRAND[mode], mode))
        write("clearsky", mode, full_scheme(CLEARSKY[mode], mode))
        if mode == "dark":
            # The same table `caelestia scheme set` writes to ~/.config/hypr/scheme/current.lua.
            lua = OUT.parent / "hypr/scheme/current.lua"
            lua.parent.mkdir(parents=True, exist_ok=True)
            colours = full_scheme(BRAND[mode], mode)
            lua.write_text("return {\n" + "".join(f'  {k} = "{v}",\n' for k, v in colours.items()) + "}\n")
            print(f"wrote {lua}")
        for name, (dark, light) in THEMES.items():
            exact = scheme_from(BRAND[mode], dark if mode == "dark" else light, mode == "dark")
            write(name, mode, full_scheme(exact, mode))


if __name__ == "__main__":
    main()
