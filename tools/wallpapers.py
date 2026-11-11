#!/usr/bin/env python3
"""Draw SuperAwesomeMagicalLinux's abstract wallpapers (orbs-dark.jpg and orbs-light.jpg).

    python3 tools/wallpapers.py [--width 3840 --height 2160] [--out DIR]

Needs numpy and Pillow. Everything is drawn from seeded noise, so each run gives the same pictures.
The colours are the brand's: aurora purple and green, with a little of the original blue, over the
cool slate neutrals every app shares. (The default wallpaper, aurora.jpg, is a photo; see the
CREDITS.md beside it.)
"""
from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

DEFAULT_OUT = Path(__file__).resolve().parent.parent / "system_files/usr/share/backgrounds/superawesomemagical"


def hex_rgb(h: str) -> np.ndarray:
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float32) / 255.0


def smooth_noise_1d(n: int, scales: list[tuple[float, float]], rng: np.random.Generator) -> np.ndarray:
    """Sum of randomly phased sines: a smooth wavy line of length n."""
    x = np.linspace(0.0, 1.0, n, dtype=np.float32)
    out = np.zeros(n, dtype=np.float32)
    for freq, amp in scales:
        out += amp * np.sin(2 * np.pi * (freq * x + rng.random()))
    return out


def value_noise_2d(h: int, w: int, cell: int, rng: np.random.Generator) -> np.ndarray:
    """Bilinearly upsampled random grid: soft cloudy noise in 0..1."""
    gh, gw = h // cell + 2, w // cell + 2
    grid = rng.random((gh, gw)).astype(np.float32)
    img = Image.fromarray((grid * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
    return np.asarray(img, dtype=np.float32) / 255.0


def finish(rgb: np.ndarray, rng: np.random.Generator, grain: float = 0.012) -> Image.Image:
    """Add fine grain (hides gradient banding) and convert to an 8-bit image."""
    rgb = rgb + rng.normal(0.0, grain, rgb.shape).astype(np.float32)
    return Image.fromarray((np.clip(rgb, 0, 1) * 255 + 0.5).astype(np.uint8), "RGB")


def vertical_gradient(h: int, w: int, stops: list[tuple[float, str]]) -> np.ndarray:
    y = np.linspace(0, 1, h, dtype=np.float32)
    pos = np.array([s[0] for s in stops], dtype=np.float32)
    cols = np.stack([hex_rgb(s[1]) for s in stops])
    col = np.stack([np.interp(y, pos, cols[:, c]) for c in range(3)], axis=-1)
    return np.broadcast_to(col[:, None, :], (h, w, 3)).copy()


def orbs(w: int, h: int, dark: bool, seed: int = 11) -> Image.Image:
    """Soft blurred light in aurora purple and green, with a touch of blue, over slate."""
    rng = np.random.default_rng(seed)
    if dark:
        base = vertical_gradient(h, w, [(0, "#140F2A"), (0.5, "#0B1220"), (1, "#0B1220")])
        blobs = [("#5B3FD1", 0.85), ("#0B7A4F", 0.75), ("#7B4FE0", 0.70), ("#2563EB", 0.35), ("#12A36A", 0.55)]
    else:
        base = vertical_gradient(h, w, [(0, "#EDE7FB"), (0.5, "#F5F7FB"), (1, "#F5F7FB")])
        blobs = [("#CFBDFF", 0.65), ("#9AF0C4", 0.50), ("#E2D6FF", 0.55), ("#B3CDFF", 0.30), ("#B8F5D6", 0.45)]
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    xx /= w
    yy /= h
    layer = np.zeros((h, w, 3), dtype=np.float32)
    weight = np.zeros((h, w), dtype=np.float32)
    centres = [(0.18, 0.30), (0.78, 0.22), (0.62, 0.78), (0.30, 0.82), (0.95, 0.60)]
    for (col, a), (cx, cy) in zip(blobs, centres):
        cx += rng.uniform(-0.05, 0.05)
        cy += rng.uniform(-0.05, 0.05)
        rx, ry = rng.uniform(0.22, 0.34), rng.uniform(0.25, 0.40)
        g = np.exp(-(((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2) * 1.6) * a
        layer += hex_rgb(col)[None, None, :] * g[..., None]
        weight += g
    mixed = layer / np.maximum(weight, 1e-4)[..., None]
    alpha = np.clip(weight, 0, 1)[..., None]
    # A faint ripple, like the rings on Music's artwork, so it isn't perfectly flat.
    ripple = value_noise_2d(h, w, max(w // 9, 8), rng)
    alpha = alpha * (0.85 + 0.15 * ripple[..., None])
    rgb = base * (1 - alpha) + mixed * alpha
    return finish(rgb, rng, 0.010 if dark else 0.006)


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("--width", type=int, default=3840)
    p.add_argument("--height", type=int, default=2160)
    p.add_argument("--out", type=Path, default=DEFAULT_OUT)
    a = p.parse_args()
    a.out.mkdir(parents=True, exist_ok=True)
    jobs = {
        "orbs-dark.jpg": lambda: orbs(a.width, a.height, dark=True),
        "orbs-light.jpg": lambda: orbs(a.width, a.height, dark=False),
    }
    for name, make in jobs.items():
        img = make()
        img.save(a.out / name, quality=90, optimize=True, progressive=True)
        print(f"wrote {a.out / name} ({(a.out / name).stat().st_size // 1024} KiB)")


if __name__ == "__main__":
    main()
