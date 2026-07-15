"""Generate the Secret Browser logo (shield + incognito mask).

Draws two 1024x1024 master PNGs used by flutter_launcher_icons:
  - assets/branding/icon.png            full icon (dark rounded-square bg)
  - assets/branding/icon_foreground.png shield+mask on transparent bg
                                        (Android adaptive foreground; in-app logo)

Rendered at 4x and downscaled with LANCZOS for smooth edges. Pillow only.
Run:  python3 tool/generate_logo.py
"""

from __future__ import annotations

import os

from PIL import Image, ImageDraw

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "branding")

SIZE = 1024
SS = 4  # supersample factor
S = SIZE * SS

# Brand colors.
BG = (23, 20, 31, 255)          # #17141F dark
SHIELD_TOP = (167, 139, 250)    # #A78BFA
SHIELD_BOTTOM = (124, 77, 255)  # #7C4DFF
MASK = (245, 243, 255, 255)     # near-white


def _lerp(a: int, b: int, t: float) -> int:
    return int(round(a + (b - a) * t))


def _gradient(w: int, h: int, top: tuple[int, int, int],
              bottom: tuple[int, int, int]) -> Image.Image:
    grad = Image.new("RGB", (1, h))
    px = grad.load()
    for y in range(h):
        t = y / max(1, h - 1)
        px[0, y] = (_lerp(top[0], bottom[0], t),
                    _lerp(top[1], bottom[1], t),
                    _lerp(top[2], bottom[2], t))
    return grad.resize((w, h))


def _shield_mask(cx: float, cy: float, w: float, h: float) -> Image.Image:
    """White shield silhouette on black (L mode), at supersample scale."""
    mask = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(mask)
    left, right = cx - w / 2, cx + w / 2
    top, bottom = cy - h / 2, cy + h / 2
    mid = top + 0.56 * h
    r = 0.16 * w
    # Rounded-top body.
    d.rounded_rectangle([left, top, right, mid + r], radius=r, fill=255)
    # Tapered bottom to a soft point (overlaps the body to avoid notches).
    tip_y = bottom
    d.polygon(
        [(left, mid), (right, mid), (cx + 0.10 * w, tip_y - 0.02 * h),
         (cx, tip_y), (cx - 0.10 * w, tip_y - 0.02 * h)],
        fill=255,
    )
    return mask


def _draw_incognito(d: ImageDraw.ImageDraw, cx: float, cy: float, w: float) -> None:
    """Draw a clean incognito 'glasses' glyph centered at (cx, cy)."""
    glasses_w = 0.66 * w
    lens_w = 0.27 * w
    lens_h = 0.24 * w
    gap = glasses_w - 2 * lens_w
    brow_h = 0.085 * w
    left = cx - glasses_w / 2
    right = cx + glasses_w / 2

    # Brow bar across the top of the lenses.
    brow_y = cy - lens_h / 2 - brow_h * 0.55
    d.rounded_rectangle(
        [left, brow_y, right, brow_y + brow_h],
        radius=brow_h / 2, fill=MASK,
    )

    # Two lenses hanging below the brow (slightly trapezoidal look via rounding).
    lens_top = brow_y + brow_h * 0.35
    d.rounded_rectangle(
        [left, lens_top, left + lens_w, lens_top + lens_h],
        radius=lens_h * 0.42, fill=MASK,
    )
    d.rounded_rectangle(
        [right - lens_w, lens_top, right, lens_top + lens_h],
        radius=lens_h * 0.42, fill=MASK,
    )
    # Bridge connecting the two lenses.
    bridge_y = lens_top + lens_h * 0.18
    d.rounded_rectangle(
        [cx - gap / 2 - 0.01 * w, bridge_y,
         cx + gap / 2 + 0.01 * w, bridge_y + brow_h * 0.7],
        radius=brow_h * 0.35, fill=MASK,
    )


def _compose(with_background: bool) -> Image.Image:
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))

    if with_background:
        bg = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        ImageDraw.Draw(bg).rounded_rectangle(
            [0, 0, S - 1, S - 1], radius=int(0.22 * S), fill=BG,
        )
        img = Image.alpha_composite(img, bg)
        shield_w, shield_h = 0.60 * S, 0.66 * S
        cy = S * 0.50
    else:
        # Foreground for adaptive icons: keep art inside the central safe zone.
        shield_w, shield_h = 0.52 * S, 0.58 * S
        cy = S * 0.50

    cx = S * 0.5
    # Shield with vertical purple gradient.
    grad = _gradient(S, S, SHIELD_TOP, SHIELD_BOTTOM).convert("RGBA")
    smask = _shield_mask(cx, cy, shield_w, shield_h)
    img.paste(grad, (0, 0), smask)

    # Incognito glasses in the upper-middle of the shield.
    d = ImageDraw.Draw(img)
    _draw_incognito(d, cx, cy - 0.05 * shield_h, shield_w)

    return img.resize((SIZE, SIZE), Image.LANCZOS)


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    _compose(with_background=True).save(os.path.join(OUT_DIR, "icon.png"))
    _compose(with_background=False).save(
        os.path.join(OUT_DIR, "icon_foreground.png"))
    print("Wrote icon.png and icon_foreground.png to", os.path.normpath(OUT_DIR))


if __name__ == "__main__":
    main()
