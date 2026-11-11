#!/usr/bin/env python3
"""Draw SuperAwesomeMagicalLinux's wallpapers.

The images in system_files/usr/share/backgrounds/superawesomemagical/ come from this script, so
they can be redrawn at any size or with new colours:

    python3 tools/wallpapers.py [--width 3840 --height 2160] [--out DIR]

Needs numpy and Pillow. Everything is drawn from seeded noise, so each run gives the same pictures.

The colours are the ecosystem's: the cool slate neutrals every app shares, Weather's blue,
Cockpit Manager's teal and Music's violet and rose.
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


def aurora(w: int, h: int, seed: int = 7) -> Image.Image:
    """Northern lights over a night sky, above a Maine ridge of white pines."""
    rng = np.random.default_rng(seed)
    sky = vertical_gradient(h, w, [(0.0, "#05080F"), (0.45, "#0B1A2C"), (0.78, "#0E2A35"), (1.0, "#0B1220")])

    ys = np.arange(h, dtype=np.float32)[:, None] / h
    light = np.zeros((h, w, 3), dtype=np.float32)

    # Two curtains: a bright green one and a fainter violet one behind it. Each is a thin ribbon
    # with a bright, rippled lower fringe and rays that fade upwards at different heights.
    curtains = [
        (0.47, ["#B6FFD9", "#6EF2B0", "#5EDBC8", "#8DB4FF", "#B28CFF"], 1.0,
         [(0.8, 0.09), (1.9, 0.05), (4.1, 0.018), (11, 0.006)]),
        (0.33, ["#9FE7FF", "#7CCBF2", "#8DB4FF", "#B28CFF", "#FFB1C8"], 0.5,
         [(0.6, 0.07), (1.4, 0.04), (3.2, 0.015), (9, 0.005)]),
    ]
    for base, palette, strength, waves in curtains:
        edge = base + smooth_noise_1d(w, waves, rng)  # lower edge of the curtain, per column
        # Rays: vertical streaks whose brightness and height vary along x.
        rays = 0.5 + 0.5 * smooth_noise_1d(w, [(13, 0.45), (37, 0.35), (83, 0.2)], rng)
        rays = np.clip(rays, 0, 1) ** 2.2
        height = 0.10 + 0.10 * np.clip(0.5 + smooth_noise_1d(w, [(7, 0.4), (19, 0.3)], rng), 0, 1)
        # Brightness wanders along the curtain so it breaks into separate ribbons.
        swell = np.clip(smooth_noise_1d(w, [(1.3, 0.6), (2.9, 0.35), (6.1, 0.15)], rng) + 0.35, 0, 1) ** 1.5
        d = edge[None, :] - ys  # >0 above the edge
        below = np.exp(-((np.minimum(d, 0) / 0.008) ** 2))  # sharp fade under the edge
        above = np.exp(-np.maximum(d, 0) / height[None, :])  # rays fade upwards
        fringe = np.exp(-((d - 0.006) / 0.012) ** 2) * 0.6  # the bright lower fringe
        shape = (np.where(d >= 0, above * (0.35 + 0.65 * rays[None, :]), below) + fringe * (d > -0.02))
        shape *= swell[None, :] * strength
        # Colour climbs the palette with height above the edge.
        t = np.clip(d / 0.30, 0, 1)
        stops = np.stack([hex_rgb(c) for c in palette])
        tpos = np.linspace(0, 1, len(palette), dtype=np.float32)
        col = np.stack([np.interp(t, tpos, stops[:, c]) for c in range(3)], axis=-1)
        light += col * shape[..., None]
        # A faint diffuse glow beneath, so the sky under the curtain isn't a flat dark shape.
        under = np.exp(-np.abs(np.minimum(d, 0)) / 0.10) * swell[None, :] * strength * 0.10
        light += hex_rgb(palette[1])[None, None, :] * under[..., None]

    # Soften the curtains a touch and let them glow.
    glow_img = Image.fromarray((np.clip(light, 0, 1) * 255).astype(np.uint8))
    glow = np.asarray(glow_img.filter(ImageFilter.GaussianBlur(radius=w / 160)), dtype=np.float32) / 255
    sky = 1 - (1 - sky) * (1 - np.clip(light * 0.75 + glow * 0.6, 0, 1))  # screen blend

    # Stars, dimmer where the aurora is bright and near the horizon.
    n_stars = int(w * h / 3500)
    sx = rng.integers(0, w, n_stars)
    sy = (rng.random(n_stars) ** 1.4 * h * 0.8).astype(int)
    mag = rng.random(n_stars) ** 3
    stars = np.zeros((h, w), dtype=np.float32)
    stars[sy, sx] = 0.35 + 0.65 * mag
    stars_img = Image.fromarray((stars * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.7))
    stars = np.asarray(stars_img, dtype=np.float32) / 255 * 2.2
    stars *= np.clip(1 - glow.mean(axis=-1) * 2.5, 0, 1) * np.clip((0.82 - ys) / 0.3, 0, 1)
    sky += stars[..., None] * hex_rgb("#E5E9F0")[None, None, :]

    # Ridge of white pines along the bottom.
    land = np.zeros((h, w), dtype=bool)
    ridge = 0.86 + smooth_noise_1d(w, [(0.6, 0.025), (1.7, 0.012), (5, 0.004)], rng)
    land |= ys >= ridge[None, :]
    x = 0
    while x < w:
        tw = int(rng.uniform(0.010, 0.022) * w)
        th = rng.uniform(0.05, 0.13) * h
        base_y = ridge[min(x + tw // 2, w - 1)] * h + 2
        top = base_y - th
        cols_ = np.arange(max(x, 0), min(x + tw, w))
        # Tiered pine: the half-width grows towards the base, with a little jaggedness per tier.
        half = tw / 2
        cx = x + half
        yy = np.arange(int(top), int(base_y) + 1)
        frac = (yy - top) / th
        tiers = 5 + int(rng.integers(0, 3))
        jag = (frac * tiers) % 1.0
        width = half * frac * (0.55 + 0.45 * jag)
        for i, row in enumerate(yy):
            if 0 <= row < h:
                lo = int(max(cx - width[i], 0))
                hi = int(min(cx + width[i] + 1, w))
                land[row, lo:hi] = True
        x += int(tw * rng.uniform(0.45, 1.1))
        if rng.random() < 0.06:
            x += int(rng.uniform(0.02, 0.06) * w)  # a clearing
        _ = cols_
    land_col = hex_rgb("#03060B")
    # Slight haze: the treeline catches a little of the aurora's colour at its top.
    sky = np.where(land[..., None], land_col[None, None, :] + glow * 0.05, sky)

    # Gentle vignette.
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    r = np.sqrt(((xx - w / 2) / (w * 0.75)) ** 2 + ((yy - h * 0.45) / (h * 0.85)) ** 2)
    sky *= np.clip(1.08 - 0.35 * r ** 2, 0.55, 1)[..., None]
    return finish(sky, rng, 0.010)


def orbs(w: int, h: int, dark: bool, seed: int = 11) -> Image.Image:
    """Soft blurred light in the three apps' accents over slate: blue, teal, violet and rose."""
    rng = np.random.default_rng(seed)
    if dark:
        base = vertical_gradient(h, w, [(0, "#0C1E27"), (0.5, "#0B1220"), (1, "#0B1220")])
        blobs = [("#2563EB", 0.75), ("#0F766E", 0.70), ("#5B3FD1", 0.80), ("#B0457A", 0.40), ("#0E7FB8", 0.5)]
    else:
        base = vertical_gradient(h, w, [(0, "#E3F2EF"), (0.5, "#F5F7FB"), (1, "#F5F7FB")])
        blobs = [("#8DB4FF", 0.55), ("#5EDBC8", 0.45), ("#CFBDFF", 0.60), ("#FFB1C8", 0.40), ("#7CCBF2", 0.40)]
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
        "aurora.jpg": lambda: aurora(a.width, a.height),
        "orbs-dark.jpg": lambda: orbs(a.width, a.height, dark=True),
        "orbs-light.jpg": lambda: orbs(a.width, a.height, dark=False),
    }
    for name, make in jobs.items():
        img = make()
        img.save(a.out / name, quality=90, optimize=True, progressive=True)
        print(f"wrote {a.out / name} ({(a.out / name).stat().st_size // 1024} KiB)")


if __name__ == "__main__":
    main()
