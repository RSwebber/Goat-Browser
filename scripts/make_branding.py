"""Regenerate Goat Browser branding images from branding/GOAT.png.

Usage (from C:\\goat):
    .venv-tools\\Scripts\\python.exe scripts\\make_branding.py

1. Makes branding/goat-logo.png: the outer white background flood-filled to
   transparency (white inside the black circle is kept), cropped to a square.
2. Rewrites every raster image in branding/goat/ with a Goat version at the
   same pixel size and format. Private-browsing images use an inverted logo.
3. Writes about-logo.svg (embedded PNG) and text "Goat" wordmarks.
"""

import base64
import io
import pathlib

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageOps

ROOT = pathlib.Path(__file__).resolve().parent.parent
BRANDING = ROOT / "branding"
GOAT_DIR = BRANDING / "goat"

# Images that represent private browsing get the inverted logo.
PRIVATE = ("private", "pbmode")
# Non-square or photographic images get the logo centered on a backdrop.
BACKDROP_BLACK = {"background.png", "bgstub.jpg", "about.png"}


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


def render(logo, size, backdrop=None, margin=0.04):
    w, h = size
    canvas = Image.new("RGBA", (w, h), backdrop or (0, 0, 0, 0))
    side = min(w, h)
    margin = margin if w == h else 0.12
    icon = fit(logo, side, margin)
    canvas.alpha_composite(icon, ((w - side) // 2, (h - side) // 2))
    return canvas


def logo_for(path, logo, logo_private):
    return logo_private if any(k in path.name.lower() for k in PRIVATE) else logo


def regenerate(path, logo, logo_private):
    src = Image.open(path)
    fmt = src.format
    lg = logo_for(path, logo, logo_private)
    name = path.name

    if fmt == "ICO":
        sizes = sorted(src.info.get("sizes", {src.size}))
        big = render(lg, (max(s[0] for s in sizes),) * 2)
        big.save(path, format="ICO", sizes=sizes)
    elif fmt == "ICNS":
        render(lg, (1024, 1024)).save(path, format="ICNS")
    elif fmt in ("BMP", "JPEG") or src.mode == "RGB":
        # Opaque formats: installer bitmaps on white, splash art on black.
        back = (0, 0, 0, 255) if name in BACKDROP_BLACK else (255, 255, 255, 255)
        img = render(lg, src.size, back).convert("RGB")
        img.save(path, format=fmt, **({"quality": 92} if fmt == "JPEG" else {}))
    else:
        back = (0, 0, 0, 255) if name in BACKDROP_BLACK else None
        render(lg, src.size, back).save(path, format="PNG", optimize=True)
    return f"{path.relative_to(GOAT_DIR)} {fmt} {src.size}"


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
    logo = make_transparent_logo(BRANDING / "GOAT.png")
    logo.save(BRANDING / "goat-logo.png", optimize=True)
    print(f"goat-logo.png {logo.size}")
    logo_private = invert_logo(logo)

    for path in sorted(GOAT_DIR.rglob("*")):
        if path.suffix.lower() in (".png", ".ico", ".icns", ".bmp", ".jpg"):
            print(regenerate(path, logo, logo_private))
    write_svgs(logo)
    print("svgs written")


if __name__ == "__main__":
    main()
