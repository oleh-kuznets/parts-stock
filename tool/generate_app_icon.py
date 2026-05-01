#!/usr/bin/env python3
"""Generate Parts Stock platform icons from `assets/branding/logo.svg`.

Produces:
  - `assets/branding/app_icon_256.png`            (used by README and inside the app)
  - `windows/runner/resources/app_icon.ico`       (multi-size Windows icon)
  - `macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_*.png`
                                                  (macOS app icon, 16..1024)
  - `linux/app_icon.png` (256px)                  (referenced by Linux desktop file)

Requires: `rsvg-convert` (brew install librsvg) and Pillow (`pip install Pillow`).

Run from repo root:
    python3 tool/generate_app_icon.py
"""

from __future__ import annotations

import io
import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SVG = ROOT / "assets" / "branding" / "logo.svg"

OUT_BRAND_PNG = ROOT / "assets" / "branding" / "app_icon_256.png"
OUT_WIN_ICO = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"
OUT_MACOS_DIR = ROOT / "macos" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
OUT_LINUX_PNG = ROOT / "linux" / "app_icon.png"

# Windows .ico embedded sizes.
WIN_SIZES = (16, 24, 32, 48, 64, 128, 256)

# macOS expects fixed PNGs whose names match Contents.json in the appiconset.
MACOS_SIZES = (16, 32, 64, 128, 256, 512, 1024)


def render(size: int) -> Image.Image:
    """Rasterise the SVG at `size`x`size` using rsvg-convert."""
    if shutil.which("rsvg-convert") is None:
        sys.stderr.write(
            "rsvg-convert not found. Install with `brew install librsvg`.\n"
        )
        sys.exit(2)
    cmd = [
        "rsvg-convert",
        "--width",
        str(size),
        "--height",
        str(size),
        "--format",
        "png",
        str(SVG),
    ]
    result = subprocess.run(cmd, check=True, capture_output=True)
    return Image.open(io.BytesIO(result.stdout)).convert("RGBA")


def write_windows_ico(images: list[Image.Image]) -> None:
    OUT_WIN_ICO.parent.mkdir(parents=True, exist_ok=True)
    images[-1].save(
        OUT_WIN_ICO,
        format="ICO",
        sizes=[(im.width, im.height) for im in images],
    )
    print(f"wrote {OUT_WIN_ICO.relative_to(ROOT)} ({len(images)} sizes)")


def write_macos_iconset() -> None:
    OUT_MACOS_DIR.mkdir(parents=True, exist_ok=True)
    for size in MACOS_SIZES:
        im = render(size)
        target = OUT_MACOS_DIR / f"app_icon_{size}.png"
        im.save(target, "PNG")
        print(f"wrote {target.relative_to(ROOT)}")


def write_brand_png() -> None:
    OUT_BRAND_PNG.parent.mkdir(parents=True, exist_ok=True)
    render(256).save(OUT_BRAND_PNG, "PNG")
    print(f"wrote {OUT_BRAND_PNG.relative_to(ROOT)}")


def write_linux_png() -> None:
    if not OUT_LINUX_PNG.parent.exists():
        # Linux scaffold not present — skip silently.
        return
    render(256).save(OUT_LINUX_PNG, "PNG")
    print(f"wrote {OUT_LINUX_PNG.relative_to(ROOT)}")


def main() -> int:
    if not SVG.exists():
        sys.stderr.write(f"SVG missing: {SVG}\n")
        return 1

    write_brand_png()
    write_windows_ico([render(size) for size in WIN_SIZES])
    write_macos_iconset()
    write_linux_png()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
