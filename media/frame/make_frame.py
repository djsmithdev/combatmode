"""The Action Combat Mode metal frame: transparent PNGs for composing screenshots / GIFs, and the
pieces shared by make_feature_panel.py and make_cta.py.

    python make_frame.py [CONTENT_WIDTH CONTENT_HEIGHT]     (default 640 360)

Writes three files next to this script (WxH in the name is the *content* size):
  frame_overlay_WxH.png       exactly WxH: the metal band + inner shadow, for laying OVER an image or GIF
  frame_overlay_logo_WxH.png  the same with the cmtitle logo in the bottom-right corner
  frame_band_WxH.png          the metal band hugging the content (no padding), with the shadows
The band PNG includes the config panel's two shadows: an outer drop shadow (soft, shifted
down) and an inner shadow (black fading in from the inside edge, darkening the content under it). It
is bigger than the content by the shadow reach and band; the content goes under the
transparent window, whose top-left corner is printed when the script runs.

The metal is cropped from ../welcome_msg.png (an in-game screenshot of the framed panel). Functions used by the other scripts:
  band(fw, fh)         the metal band as RGBA, opaque only on the band, outer corners cut diagonally
  inner_shadow(w, h)   black fading in from every edge of a w x h opening
  outer_shadow(fw, fh) soft drop shadow around a fw x fh frame, with the frame's own rectangle cut out
  title_logo(height)   the addon's cmtitle art cropped to its lettering and scaled to `height`
"""
import os
import sys

from PIL import Image, ImageFilter
from PIL.PngImagePlugin import PngInfo

HERE = os.path.dirname(os.path.abspath(__file__))
SOURCE = os.path.join(HERE, "..", "welcome_msg.png")

# Frame band in welcome_msg.png (outer rect, inclusive): the image is cropped to the band's outer edge.
X0, Y0, X1, Y1 = 0, 0, 539, 347
T = 7  # band thickness
BT = T + 1  # band + 1px outer margin
K = 14  # corner crop size
CHAMFER = 6  # the band's outer corners are cut diagonally by this many pixels
SHADOW_REACH = 40  # transparent margin around the frame that holds the outer drop shadow
SHADOW_BLUR = 13  # gaussian radius of the drop shadow
SHADOW_OFFSET_Y = 6  # the drop shadow sits a little lower than the frame (light from above)
SHADOW_PEAK = 165  # drop shadow alpha (0-255) right at the frame edge
INNER_REACH = 56  # how far the inner shadow fades in from the inside edge of the band
INNER_PEAK = 170  # inner shadow alpha (0-255) at the band

src = Image.open(SOURCE).convert("RGB")
EX1, EY1 = X1 + 1, Y1 + 1


def tile(strip, length, horizontal):
    size = (length, strip.height) if horizontal else (strip.width, length)
    out = Image.new("RGB", size)
    pos = 0
    step = strip.width if horizontal else strip.height
    while pos < length:
        out.paste(strip, (pos, 0) if horizontal else (0, pos))
        pos += step
    return out


def band(fw, fh):
    """Metal band at full size as RGBA: opaque band pixels, transparent outside and inside."""
    L = 112
    mx = (X0 + EX1) // 2 - L // 2
    my = (Y0 + EY1) // 2 - L // 2
    top = src.crop((mx, Y0 - 1, mx + L, Y0 + T))
    bottom = src.crop((mx, EY1 - T, mx + L, EY1 + 1))
    left = src.crop((X0 - 1, my, X0 + T, my + L))
    right = src.crop((EX1 - T, my, EX1 + 1, my + L))
    canvas = Image.new("RGB", (fw, fh))
    canvas.paste(tile(top, fw - 2 * K, True), (K, 0))
    canvas.paste(tile(bottom, fw - 2 * K, True), (K, fh - BT))
    canvas.paste(tile(left, fh - 2 * K, False), (0, K))
    canvas.paste(tile(right, fh - 2 * K, False), (fw - BT, K))
    canvas.paste(src.crop((X0 - 1, Y0 - 1, X0 - 1 + K, Y0 - 1 + K)), (0, 0))
    canvas.paste(src.crop((EX1 + 1 - K, Y0 - 1, EX1 + 1, Y0 - 1 + K)), (fw - K, 0))
    canvas.paste(src.crop((X0 - 1, EY1 + 1 - K, X0 - 1 + K, EY1 + 1)), (0, fh - K))
    canvas.paste(src.crop((EX1 + 1 - K, EY1 + 1 - K, EX1 + 1, EY1 + 1)), (fw - K, fh - K))

    # Alpha: only the band (inside the 1px outer margin, outside the inner opening), with the
    # outer corners cut diagonally.
    alpha = Image.new("L", (fw, fh), 0)
    ap = alpha.load()
    for y in range(fh):
        for x in range(fw):
            in_outer = 1 <= x < fw - 1 and 1 <= y < fh - 1
            in_inner = BT <= x < fw - BT and BT <= y < fh - BT
            if not in_outer or in_inner:
                continue
            # distance from each outer corner, for the diagonal cut
            dx = min(x - 1, fw - 2 - x)
            dy = min(y - 1, fh - 2 - y)
            if dx < CHAMFER and dy < CHAMFER and dx + dy < CHAMFER:
                continue
            ap[x, y] = 255
    rgba = canvas.convert("RGBA")
    rgba.putalpha(alpha)
    return rgba


def inner_shadow(w, h):
    """Black fading in from every edge of the opening (w x h), as RGBA."""
    shade = Image.new("L", (w, h), 0)
    sp = shade.load()
    for y in range(h):
        for x in range(w):
            d = min(x, y, w - 1 - x, h - 1 - y)
            if d < INNER_REACH:
                t = 1 - d / INNER_REACH
                sp[x, y] = int(INNER_PEAK * t * t)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out.putalpha(shade)
    return out


def outer_shadow(fw, fh):
    """Soft drop shadow behind the frame, as RGBA, with the frame's own rectangle cut out."""
    cw, ch = fw + 2 * SHADOW_REACH, fh + 2 * SHADOW_REACH
    mask = Image.new("L", (cw, ch), 0)
    mask.paste(255, (SHADOW_REACH, SHADOW_REACH + SHADOW_OFFSET_Y, SHADOW_REACH + fw, SHADOW_REACH + SHADOW_OFFSET_Y + fh))
    mask = mask.filter(ImageFilter.GaussianBlur(SHADOW_BLUR))
    mask = mask.point(lambda v: int(v * SHADOW_PEAK / 255))
    # Nothing under the frame itself: the window must stay transparent for the content.
    mask.paste(0, (SHADOW_REACH, SHADOW_REACH, SHADOW_REACH + fw, SHADOW_REACH + fh))
    out = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    out.putalpha(mask)
    return out


def build(cw, ch):
    """The metal band hugging a cw x ch window, with both shadows. Returns (image, window origin)."""
    fw = cw + 2 * BT
    fh = ch + 2 * BT
    layer = Image.new("RGBA", (fw, fh), (0, 0, 0, 0))
    layer.alpha_composite(inner_shadow(fw - 2 * BT, fh - 2 * BT), (BT, BT))
    layer.alpha_composite(band(fw, fh))
    final = outer_shadow(fw, fh)
    final.alpha_composite(layer, (SHADOW_REACH, SHADOW_REACH))
    return final, SHADOW_REACH + BT


LOGO_PATH = os.path.join(HERE, "..", "..", "CombatMode", "assets", "cmtitle.blp")
LOGO_HEIGHT = 34  # px, the lettering only (the art's empty margins are cropped away)
LOGO_MARGIN = 14  # distance from the metal band to the logo


def title_logo(height):
    """The addon's cmtitle art, cropped to its lettering and scaled to `height`."""
    art = Image.open(LOGO_PATH).convert("RGBA")
    art = art.crop(art.split()[3].getbbox())
    return art.resize((round(art.width * height / art.height), height), Image.LANCZOS)

def overlay(w, h, logo=False):
    """An overlay exactly w x h: the metal band on the outer edge and the inner shadow fading in
    over the content inside it. No outer shadow, no padding; lay it over a w x h image or GIF."""
    img, _origin = build(w - 2 * (BT - 1), h - 2 * (BT - 1))
    crop = SHADOW_REACH + 1  # pixels from the PNG edge to the metal
    img = img.crop((crop, crop, img.width - crop, img.height - crop))
    if logo:
        art = title_logo(LOGO_HEIGHT)
        x = w - (BT - 1) - LOGO_MARGIN - art.width
        y = h - (BT - 1) - LOGO_MARGIN - art.height
        # No halo: on a GIF its partly transparent edge snaps to a flat box of one palette colour.
        img.alpha_composite(art, (x, y))
    return img


def main():
    cw = int(sys.argv[1]) if len(sys.argv) > 2 else 640
    ch = int(sys.argv[2]) if len(sys.argv) > 2 else 360
    ov = overlay(cw, ch)
    ov.save(os.path.join(HERE, f"frame_overlay_{cw}x{ch}.png"))
    overlay(cw, ch, logo=True).save(os.path.join(HERE, f"frame_overlay_logo_{cw}x{ch}.png"))
    print(f"frame_overlay_logo_{cw}x{ch}.png: the same with the cmtitle logo in the bottom-right corner")
    print(f"frame_overlay_{cw}x{ch}.png: {ov.width}x{ov.height} (lay it over a {cw}x{ch} image)")
    img, origin = build(cw, ch)
    meta = PngInfo()
    meta.add_text("acm_window", f"{cw}x{ch}@{origin}")
    meta.add_text("acm_crop", str(SHADOW_REACH + 1))  # pixels from the PNG edge to the metal
    img.save(os.path.join(HERE, f"frame_band_{cw}x{ch}.png"), pnginfo=meta)
    print(f"frame_band_{cw}x{ch}.png: {img.width}x{img.height}, content goes at ({origin}, {origin})")


if __name__ == "__main__":
    main()
