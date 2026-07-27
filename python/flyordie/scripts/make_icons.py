"""Generate platform icon files from ``assets/favicon.ico``.

The source icon is small (32x32), so larger sizes are upscaled with Lanczos
resampling.  Replace ``favicon.ico`` with a 1024x1024 source for crisp Retina
icons; this script needs no changes when that happens.
"""

from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image

PROJECT = Path(__file__).resolve().parents[1]
SOURCE = PROJECT / "assets" / "favicon.ico"
ICNS = PROJECT / "assets" / "flyordie.icns"
ICO = PROJECT / "assets" / "flyordie.ico"
PNG = PROJECT / "assets" / "flyordie.png"

# (pixel size, iconset base name) pairs required by iconutil.
ICNS_ENTRIES = (
    (16, "icon_16x16"),
    (32, "icon_16x16@2x"),
    (32, "icon_32x32"),
    (64, "icon_32x32@2x"),
    (128, "icon_128x128"),
    (256, "icon_128x128@2x"),
    (256, "icon_256x256"),
    (512, "icon_256x256@2x"),
    (512, "icon_512x512"),
    (1024, "icon_512x512@2x"),
)
ICO_SIZES = (16, 24, 32, 48, 64, 128, 256)


def _load() -> Image.Image:
    if not SOURCE.is_file():
        raise SystemExit(f"Missing icon source: {SOURCE}")
    image = Image.open(SOURCE)
    # Pick the largest frame the .ico holds before any upscaling.
    sizes = sorted(getattr(image, "ico", None).sizes()) if hasattr(image, "ico") else []
    if sizes:
        image = image.ico.getimage(sizes[-1])
    return image.convert("RGBA")


def _scaled(image: Image.Image, size: int) -> Image.Image:
    return image.resize((size, size), Image.LANCZOS)


def build_icns(image: Image.Image) -> Path:
    iconset = PROJECT / "build" / "flyordie.iconset"
    if iconset.exists():
        shutil.rmtree(iconset)
    iconset.mkdir(parents=True)
    for size, name in ICNS_ENTRIES:
        _scaled(image, size).save(iconset / f"{name}.png")
    subprocess.run(["iconutil", "-c", "icns", str(iconset), "-o", str(ICNS)], check=True)
    shutil.rmtree(iconset)
    return ICNS


def build_ico(image: Image.Image) -> Path:
    _scaled(image, max(ICO_SIZES)).save(ICO, sizes=[(s, s) for s in ICO_SIZES])
    return ICO


def build_png(image: Image.Image) -> Path:
    _scaled(image, 256).save(PNG)
    return PNG


def main() -> None:
    image = _load()
    written = [build_ico(image), build_png(image)]
    if sys.platform == "darwin":
        written.append(build_icns(image))
    for path in written:
        print(f"wrote {path.relative_to(PROJECT)}")


if __name__ == "__main__":
    main()
