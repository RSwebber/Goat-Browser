"""Regenerate Goat Browser branding images from branding/GOAT.png.

Usage (from C:\\goat):
    .venv-tools\\Scripts\\python.exe scripts\\make_branding.py

1. Makes branding/goat-logo.png: the outer white background flood-filled to
   transparency (white inside the black circle is kept), cropped to a square.
2. Writes every raster image listed in IMAGES below into branding/goat/.
   Private-browsing images use an inverted logo.
3. Writes about-logo.svg (embedded PNG) and text "Goat" wordmarks.

IMAGES is the single source of truth for each image's size, format, variant,
backdrop and margin. The script stops if branding/goat holds a raster that
isn't listed, or the table lists one that doesn't exist. On a major ESR
update, compare the table with upstream's browser/branding/unofficial.
"""

import base64
import io
import pathlib
import sys
from typing import NamedTuple, Optional

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageOps

ROOT = pathlib.Path(__file__).resolve().parent.parent
BRANDING = ROOT / "branding"
GOAT_DIR = BRANDING / "goat"

RASTER_SUFFIXES = (".png", ".ico", ".icns", ".bmp", ".jpg")

BLACK = (0, 0, 0, 255)
WHITE = (255, 255, 255, 255)


class Spec(NamedTuple):
    # PNG (transparent unless backdrop is set), PNG-RGB (opaque PNG), ICO,
    # ICNS, BMP or JPEG.
    format: str
    # (width, height). ICO: the largest size; ICNS: always 1024x1024.
    size: tuple
    # Logo margin as a fraction of the shorter side.
    margin: float = 0.04
    private: bool = False
    backdrop: Optional[tuple] = None
    # ICO only: the sizes stored in the file.
    ico_sizes: tuple = ()


def png(w, h=None, **kw):
    return Spec("PNG", (w, h or w), **kw)


def ico(*sizes, **kw):
    sizes = tuple((s, s) for s in sizes)
    return Spec("ICO", max(sizes), ico_sizes=sizes, **kw)


ICNS = Spec("ICNS", (1024, 1024))

# Non-square images use a 0.12 margin, square ones 0.04.
IMAGES = {
    "background.png": png(1440, 880, margin=0.12, backdrop=BLACK),
    "content/about-logo-private.png": png(192, private=True),
    "content/about-logo-private@2x.png": png(384, private=True),
    "content/about-logo.png": png(192),
    "content/about-logo@2x.png": png(384),
    "content/about.png": Spec("PNG-RGB", (300, 236), margin=0.12, backdrop=BLACK),
    "default128.png": png(128),
    "default16.png": png(16),
    "default22.png": png(22),
    "default24.png": png(24),
    "default256.png": png(256),
    "default32.png": png(32),
    "default48.png": png(48),
    "default64.png": png(64),
    "disk.icns": ICNS,
    "document.icns": ICNS,
    "document.ico": ico(16, 32, 48, 256),
    "document_pdf.ico": ico(256),
    "firefox.icns": ICNS,
    "firefox.ico": ico(16, 32, 48, 256),
    "firefox64.ico": ico(16, 32, 48, 64),
    "msix/Assets/Document44x44.png": png(44),
    "msix/Assets/LargeTile.scale-200.png": png(620),
    "msix/Assets/MedTile.scale-200.png": png(300),
    "msix/Assets/SmallTile.scale-200.png": png(142),
    "msix/Assets/Square150x150Logo.scale-200.png": png(300),
    "msix/Assets/Square44x44Logo.altform-lightunplated_targetsize-256.png": png(256),
    "msix/Assets/Square44x44Logo.altform-unplated_targetsize-256.png": png(256),
    "msix/Assets/Square44x44Logo.scale-200.png": png(88),
    "msix/Assets/Square44x44Logo.targetsize-256.png": png(256),
    "msix/Assets/StoreLogo.scale-200.png": png(100),
    "msix/Assets/Wide310x150Logo.scale-200.png": png(620, 300, margin=0.12),
    "newtab.ico": ico(16, 32),
    "newwindow.ico": ico(16, 32),
    "pbmode.ico": ico(256, private=True),
    "PrivateBrowsing_150.png": png(300, private=True),
    "PrivateBrowsing_70.png": png(142, private=True),
    "stubinstaller/bgstub.jpg": Spec("JPEG", (1344, 822), margin=0.12, backdrop=BLACK),
    "VisualElements_150.png": png(300),
    "VisualElements_70.png": png(142),
    # Installer bitmaps, on white.
    "wizHeader.bmp": Spec("BMP", (150, 57), margin=0.12, backdrop=WHITE),
    "wizHeaderRTL.bmp": Spec("BMP", (150, 57), margin=0.12, backdrop=WHITE),
    "wizWatermark.bmp": Spec("BMP", (164, 314), margin=0.12, backdrop=WHITE),
}


def make_transparent_logo(src):
    im = Image.open(src).convert("RGB")
    w, h = im.size
    # Flood-fill the outer background from each corner with a marker colour.
    marker = (255, 0, 255)
    filled = im.copy()
    for xy in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        if filled.getpixel(xy) != marker:
            ImageDraw.floodfill(filled, xy, marker, thresh=60)
    diff = ImageChops.difference(filled, Image.new("RGB", (w, h), marker))
    bg = diff.convert("L").point(lambda v: 255 if v == 0 else 0)

    # Anti-aliased edge: in a thin band around the background, take alpha from
    # darkness (the edge is black ink blended onto white).
    gray = im.convert("L")
    band = ImageChops.subtract(bg.filter(ImageFilter.MaxFilter(7)), bg)
    darkness = ImageOps.invert(gray)
    alpha = Image.new("L", (w, h), 255)
    alpha.paste(0, mask=bg)
    alpha.paste(darkness, mask=band)

    rgba = im.convert("RGBA")
    # Edge pixels become pure black ink with partial alpha.
    rgba.paste((0, 0, 0, 255), mask=band)
    rgba.putalpha(alpha)

    # Crop to content and pad to a centred square.
    left, top, right, bottom = alpha.point(lambda a: 255 if a > 8 else 0).getbbox()
    rgba = rgba.crop((left, top, right, bottom))
    side = max(rgba.size)
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.paste(rgba, ((side - rgba.width) // 2, (side - rgba.height) // 2))
    return square


def invert_logo(logo):
    r, g, b, a = logo.split()
    rgb = ImageOps.invert(Image.merge("RGB", (r, g, b)))
    out = rgb.convert("RGBA")
    out.putalpha(a)
    return out


def fit(logo, size, margin=0.0):
    """Logo scaled into a square of `size`, with fractional margin."""
    inner = max(1, round(size * (1 - 2 * margin)))
    scaled = logo.resize((inner, inner), Image.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.paste(scaled, ((size - inner) // 2, (size - inner) // 2))
    return canvas


def render(logo, size, backdrop, margin):
    w, h = size
    canvas = Image.new("RGBA", (w, h), backdrop or (0, 0, 0, 0))
    side = min(w, h)
    icon = fit(logo, side, margin)
    canvas.alpha_composite(icon, ((w - side) // 2, (h - side) // 2))
    return canvas


def write_image(rel, spec, logo, logo_private):
    path = GOAT_DIR / rel
    lg = logo_private if spec.private else logo
    img = render(lg, spec.size, spec.backdrop, spec.margin)
    if spec.format == "ICO":
        img.save(path, format="ICO", sizes=list(spec.ico_sizes))
    elif spec.format == "ICNS":
        img.save(path, format="ICNS")
    elif spec.format == "PNG":
        img.save(path, format="PNG", optimize=True)
    elif spec.format == "PNG-RGB":
        img.convert("RGB").save(path, format="PNG")
    elif spec.format == "JPEG":
        img.convert("RGB").save(path, format="JPEG", quality=92)
    elif spec.format == "BMP":
        img.convert("RGB").save(path, format="BMP")
    else:
        raise ValueError(f"{rel}: unknown format {spec.format}")
    return f"{rel} {spec.format} {spec.size}"


def check_table():
    """Every raster in branding/goat is in IMAGES, and vice versa."""
    on_disk = {
        p.relative_to(GOAT_DIR).as_posix()
        for p in GOAT_DIR.rglob("*")
        if p.suffix.lower() in RASTER_SUFFIXES
    }
    missing = sorted(on_disk - IMAGES.keys())
    stale = sorted(IMAGES.keys() - on_disk)
    for rel in missing:
        print(f"not in IMAGES: branding/goat/{rel}", file=sys.stderr)
    for rel in stale:
        print(f"in IMAGES but missing: branding/goat/{rel}", file=sys.stderr)
    return not (missing or stale)


LICENSE_HEADER = (
    "<!-- This Source Code Form is subject to the terms of the Mozilla Public\n"
    "   - License, v. 2.0. If a copy of the MPL was not distributed with this\n"
    "   - file, You can obtain one at http://mozilla.org/MPL/2.0/. -->\n"
)


def write_svgs(logo):
    buf = io.BytesIO()
    fit(logo, 512).save(buf, format="PNG", optimize=True)
    data = base64.b64encode(buf.getvalue()).decode("ascii")
    (GOAT_DIR / "content" / "about-logo.svg").write_text(
        LICENSE_HEADER
        + '<svg xmlns="http://www.w3.org/2000/svg" '
        'xmlns:xlink="http://www.w3.org/1999/xlink" width="512" height="512">'
        f'<image width="512" height="512" href="data:image/png;base64,{data}"/>'
        "</svg>\n",
        encoding="utf-8",
    )
    wordmark = (
        LICENSE_HEADER
        + '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 220 99">\n'
        '    <text x="0" y="78" fill="context-fill" '
        'font-family="Segoe UI, Helvetica, Arial, sans-serif" '
        'font-size="92" font-weight="700">Goat</text>\n'
        "</svg>\n"
    )
    for name in ("about-wordmark.svg", "firefox-wordmark.svg"):
        (GOAT_DIR / "content" / name).write_text(wordmark, encoding="utf-8")


def main():
    if not check_table():
        sys.exit("make_branding: IMAGES doesn't match branding/goat; fix the table first")

    logo = make_transparent_logo(BRANDING / "GOAT.png")
    logo.save(BRANDING / "goat-logo.png", optimize=True)
    print(f"goat-logo.png {logo.size}")
    logo_private = invert_logo(logo)

    for rel, spec in sorted(IMAGES.items()):
        print(write_image(rel, spec, logo, logo_private))
    write_svgs(logo)
    print("svgs written")


if __name__ == "__main__":
    main()
