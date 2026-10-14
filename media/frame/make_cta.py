"""Make the addon's call-to-action banner from a clean 960x540 screenshot.

    python make_cta.py SCREENSHOT.png OUTPUT.png
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import make_feature_panel  # noqa: E402
import make_frame  # noqa: E402

FONTS = os.path.expandvars(r"%LOCALAPPDATA%\Microsoft\Windows\Fonts")
W, H = 960, 540
COPPER = (198, 126, 74)  # the config panel accent, for the rules
CREAM = (244, 241, 234)


def font(name, size):
    return ImageFont.truetype(os.path.join(FONTS, name), size)


def main():
    src, out = sys.argv[1], sys.argv[2]
    img = Image.open(src).convert("RGB")
    a = np.asarray(img, np.float32)

    # darken the lower half and the corners so the lettering reads
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    low = np.clip((yy / H - 0.38) / 0.62, 0, 1) ** 1.4
    vig = np.clip(((xx / W - 0.5) ** 2 * 1.2 + (yy / H - 0.45) ** 2 * 0.9) * 1.6, 0, 1)
    shade = np.clip(low * 0.88 + vig * 0.45, 0, 0.93)[..., None]
    a = a * (1 - shade) + np.array([10, 8, 7], np.float32) * shade
    canvas = Image.fromarray(a.astype(np.uint8))

    # logo, large and centred
    logo = make_frame.title_logo(120)
    lx, ly = (W - logo.width) // 2, 286
    glow = Image.new("L", canvas.size, 0)
    glow.paste(logo.split()[3], (lx, ly))
    glow = glow.filter(ImageFilter.GaussianBlur(14))
    canvas = Image.composite(Image.new("RGB", canvas.size, (0, 0, 0)), canvas, glow.point(lambda v: int(v * 0.6)))
    canvas.paste(logo, (lx, ly), logo)

    d = ImageDraw.Draw(canvas)
    # short pitch under the logo, with a thin copper rule fading out to both sides
    for side in (-1, 1):
        for i in range(110):
            alpha = 1 - i / 110
            px = W / 2 + side * (30 + i * 3.4)
            c = tuple(int(COPPER[k] * alpha + 20 * (1 - alpha)) for k in range(3))
            d.line([(px, 424), (px + side * 3.4, 424)], fill=c, width=1)
    pitch = ["Modern action-game controls for World of Warcraft,", "replacing tab-targeting with intuitive aiming and immersive combat."]
    pitch_font = font("FRIZQT_.ttf", 21)
    y = 442
    for line in pitch:
        lw = d.textlength(line, font=pitch_font)
        d.text(((W - lw) / 2, y), line, font=pitch_font, fill=CREAM)
        y += 30
    # the same dark metal border and inner shadow as the feature panels; the corner notches stay transparent
    frame = make_feature_panel.panel_frame(W, H)
    rgba = canvas.convert("RGBA")
    rgba.alpha_composite(frame)
    fa, ca = np.asarray(frame.split()[3]), np.array(rgba.split()[3])
    yy, xx = np.mgrid[0:H, 0:W]
    ch = make_feature_panel.PANEL_CHAMFER
    dx, dy = np.minimum(xx, W - 1 - xx), np.minimum(yy, H - 1 - yy)
    ca[(fa == 0) & (dx < ch) & (dy < ch) & (dx + dy < ch)] = 0
    rgba.putalpha(Image.fromarray(ca))
    rgba.save(out)
    print(out, rgba.size)


if __name__ == "__main__":
    main()
