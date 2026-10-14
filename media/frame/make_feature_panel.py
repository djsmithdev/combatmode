"""Put a feature GIF inside a 960x540 panel with the feature's name and description above it.

    python make_feature_panel.py CLIP.gif OUTPUT.gif --title "MOUSE LOOK" --description "..."
                                 [--trim-start N] [--trim-end N]

CLIP.gif is the original feature GIF (about 640x360). The panel has a stone-style dark background, a
thick dark metal border with an inner shadow, the title and description, the cmtitle logo in the
bottom-right corner, and the clip in its own thin metal frame with a drop shadow and a copper glow.
The clip's frames are laid into the panel with gifsicle and reused untouched (re-encoding them makes
the file much bigger), so the footage keeps its exact quality. --trim-start / --trim-end cut idle
frames off the loop to stay under a size budget. Needs gifsicle on PATH and Friz Quadrata installed.
"""
import argparse
import os
import shutil
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont, ImageSequence

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import make_frame  # noqa: E402

FONTS = os.path.expandvars(r"%LOCALAPPDATA%\Microsoft\Windows\Fonts")  # Friz Quadrata, installed per user
TITLE_FONT = "FRIZQT_.ttf"
BODY_FONT = "FRIZQT_.ttf"
TITLE_TOP, TITLE_BOTTOM = (255, 232, 206), (204, 126, 72)
WIDTH, HEIGHT = 960, 540
BASE_DITHER = Image.Dither.NONE  # dithering the dark panel costs ~250 KB for no visible gain
PANEL_T = 14  # thickness of the panel's own border
PANEL_CHAMFER = 12
PANEL_DARKEN = 0.55  # how much of the metal's brightness the panel border keeps
GLOW_COLOUR = (208, 138, 82)
GLOW_BLUR = 16
GLOW_STRENGTH = 0.5
DESC_WRAP_W = 800
CLIP_Y = 122  # leaves room under the clip like the config panel's button row


def font(name, size):
    return ImageFont.truetype(os.path.join(FONTS, name), size)


def vertical_gradient(w, h, top, bottom):
    t = np.linspace(0, 1, h)[:, None, None]
    top, bottom = np.array(top, float), np.array(bottom, float)
    return Image.fromarray(np.broadcast_to(top + (bottom - top) * t, (h, w, 3)).astype(np.uint8))


def stone_background(w, h):
    """Dark cracked-stone look of the config panel's evergreen frame art: a warm centre falling off to
    near-black at the edges, with faint stone mottling and hairline cracks."""
    rng = np.random.default_rng(7)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    nx, ny = (xx - w / 2) / (w / 2), (yy - h * 0.42) / (h / 2)
    vignette = np.clip(1 - (nx**2 * 0.55 + ny**2 * 0.75), 0, 1) ** 1.15

    def smooth(scale, seed):
        small = np.random.default_rng(seed).random((h // scale + 2, w // scale + 2)).astype(np.float32)
        img = Image.fromarray((small * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
        return np.asarray(img, np.float32) / 255

    mottle = (smooth(64, 1) - 0.5) * 0.55 + (smooth(24, 2) - 0.5) * 0.35 + (smooth(9, 3) - 0.5) * 0.15
    # cracks: cell borders of a coarse random point field
    pts = rng.random((46, 2)) * [w, h]
    ds = np.stack([np.hypot(xx - px, yy - py) for px, py in pts])
    ds.sort(axis=0)
    cracks = np.clip(1 - (ds[1] - ds[0]) / 2.2, 0, 1)
    base = 8 + 30 * vignette
    lum = base * (1 + mottle * 0.5) * (1 - cracks * 0.28)
    r, g, b = lum * 1.0, lum * 0.84, lum * 0.74  # warm brown-grey
    out = np.clip(np.stack([r, g, b], -1), 0, 255).astype(np.int32)
    return Image.fromarray((out // 3 * 3).astype(np.uint8))  # coarser levels compress far better; invisible on this dark art


def panel_frame(w, h):
    """The panel's own border: the config panel's real metal band (cropped from the in-game screenshot)
    drawn at twice the size, so it is twice as thick and bold with the same stone and metal look, darkened
    so it sits back from the footage, plus the inner shadow. RGBA; the outer corner notches are transparent."""
    scale = 2
    small = make_frame.band(w // scale + 2, h // scale + 2)
    rgb = small.convert("RGB").resize((small.width * scale, small.height * scale), Image.LANCZOS)
    rgb = rgb.filter(ImageFilter.UnsharpMask(radius=1.2, percent=70, threshold=2))
    rgb = rgb.point(lambda v: int(v * PANEL_DARKEN))
    alpha = small.split()[3].resize(rgb.size, Image.NEAREST)
    big = rgb.convert("RGBA")
    big.putalpha(alpha)
    band_img = big.crop((scale, scale, scale + w, scale + h))  # drops the transparent outer margin
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out.alpha_composite(make_frame.inner_shadow(w - 2 * PANEL_T, h - 2 * PANEL_T), (PANEL_T, PANEL_T))
    out.alpha_composite(band_img)
    return out


def wrap(draw, text, fnt, max_w):
    lines, line = [], ""
    for word in text.split():
        trial = (line + " " + word).strip()
        if draw.textlength(trial, font=fnt) <= max_w or not line:
            line = trial
        else:
            lines.append(line)
            line = word
    lines.append(line)
    return lines


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("clip")
    ap.add_argument("output")
    ap.add_argument("--title", required=True)
    ap.add_argument("--description", required=True)
    ap.add_argument("--trim-start", type=int, default=0, help="frames to cut from the start of the loop")
    ap.add_argument("--trim-end", type=int, default=0, help="frames to cut from the end of the loop")
    args = ap.parse_args()

    gifsicle = shutil.which("gifsicle")
    if not gifsicle:
        sys.exit("gifsicle not found on PATH (scoop install gifsicle)")

    clip_path = args.clip
    if args.trim_start or args.trim_end:
        # gifsicle drops whole frames without re-encoding the rest
        n = Image.open(args.clip).n_frames
        trimmed = tempfile.NamedTemporaryFile(suffix=".gif", delete=False).name
        # The new first frame must be a complete picture (frames in the file are mostly partial updates that
        # build on the previous ones), so it is exported whole; every later frame is kept as it is.
        full = tempfile.NamedTemporaryFile(suffix=".gif", delete=False).name
        subprocess.run([gifsicle, "--unoptimize", args.clip, f"#{args.trim_start}", "-o", full], check=True)
        subprocess.run([gifsicle, "--loopcount=forever", full, args.clip, f"#{args.trim_start + 1}-{n - 1 - args.trim_end}", "-o", trimmed], check=True)
        clip_path = trimmed
    clip = Image.open(clip_path)
    cw, ch = clip.size
    clip_x = (WIDTH - cw) // 2
    clip_y = CLIP_Y
    if clip_y + ch + make_frame.BT > HEIGHT - 40:
        sys.exit(f"clip {cw}x{ch} is too tall for a {WIDTH}x{HEIGHT} panel")

    canvas = stone_background(WIDTH, HEIGHT)

    # The clip itself is left untouched (re-encoding it is what makes framed GIFs bigger), so its frame is
    # drawn here on the panel instead: the metal band around the clip's edge plus the soft drop shadow.
    fw, fh = cw + 2 * make_frame.BT, ch + 2 * make_frame.BT
    ox = clip_x - make_frame.BT
    oy = clip_y - make_frame.BT
    rgba = canvas.convert("RGBA")
    shadow_layer = make_frame.outer_shadow(fw, fh)
    rgba.alpha_composite(shadow_layer, (ox - make_frame.SHADOW_REACH, oy - make_frame.SHADOW_REACH))
    # soft copper glow around the window, over the dark shadow and under the band
    glow = Image.new("L", (WIDTH, HEIGHT), 0)
    ImageDraw.Draw(glow).rectangle((ox, oy, ox + fw - 1, oy + fh - 1), fill=255)
    glow = glow.filter(ImageFilter.GaussianBlur(GLOW_BLUR)).point(lambda v: int(v * GLOW_STRENGTH))
    rgba.paste(Image.new("RGBA", (WIDTH, HEIGHT), GLOW_COLOUR + (255,)), (0, 0), glow)
    rgba.alpha_composite(make_frame.band(fw, fh), (ox, oy))
    canvas = rgba.convert("RGB")

    # the panel's own border + inner shadow (corner notches stay transparent)
    frame_overlay = panel_frame(WIDTH, HEIGHT)
    rgba = canvas.convert("RGBA")
    rgba.alpha_composite(frame_overlay)
    canvas = rgba.convert("RGB")
    notch = Image.new("L", (WIDTH, HEIGHT), 0)
    nm, ov = notch.load(), frame_overlay.load()
    chamfer = PANEL_CHAMFER
    for y in range(HEIGHT):
        for x in range(WIDTH):
            if ov[x, y][3] == 0:
                dx, dy = min(x, WIDTH - 1 - x), min(y, HEIGHT - 1 - y)
                if dx < chamfer and dy < chamfer and dx + dy < chamfer:
                    nm[x, y] = 255

    # heading: a large title with a light-to-copper gradient, a soft copper glow and a dark drop shadow
    d = ImageDraw.Draw(canvas)
    head = font(TITLE_FONT, 44)
    title = args.title.upper()
    tw = d.textlength(title, font=head)
    title_xy = ((WIDTH - tw) / 2, 18)
    tmask = Image.new("L", canvas.size, 0)
    ImageDraw.Draw(tmask).text(title_xy, title, font=head, fill=255, stroke_width=1, stroke_fill=255)
    shadow = tmask.filter(ImageFilter.GaussianBlur(3)).point(lambda v: int(v * 0.85))
    shadow = ImageChops.offset(shadow, 0, 3)
    glow = tmask.filter(ImageFilter.GaussianBlur(11)).point(lambda v: int(v * 0.42))
    canvas.paste((0, 0, 0), (0, 0), shadow)
    canvas.paste((208, 138, 82), (0, 0), glow)
    box = tmask.getbbox()
    grad = vertical_gradient(WIDTH, box[3] - box[1] + 2, TITLE_TOP, TITLE_BOTTOM)
    fill = Image.new("RGB", canvas.size)
    fill.paste(grad, (0, box[1]))
    canvas.paste(fill, (0, 0), tmask)

    # description (wrapped, centred)
    dfont = font(BODY_FONT, 19)
    lines = wrap(d, args.description, dfont, DESC_WRAP_W)
    y = 74
    desc_mask = Image.new("L", (WIDTH, HEIGHT), 0)
    md = ImageDraw.Draw(desc_mask)
    for line in lines:
        lw = d.textlength(line, font=dfont)
        md.text(((WIDTH - lw) / 2, y), line, font=dfont, fill=255)
        y += 25
    if y > clip_y - 4:
        sys.exit(f"description wraps to {len(lines)} lines and collides with the clip; shorten it")

    # frame 0: panel with the clip's first frame inside (the loop never flashes an empty window)
    first = next(iter(ImageSequence.Iterator(clip))).convert("RGBA")
    joined = canvas.convert("RGBA")
    # This copy of the first frame is on screen for 20 ms before the real one replaces it, so it is
    # posterized to keep its cost down (the real frames are laid over it untouched).
    ph = np.asarray(first.convert("RGB"), np.int32) // 24 * 24 + 12
    placeholder = Image.fromarray(np.clip(ph, 0, 255).astype(np.uint8)).convert("RGBA")
    placeholder.putalpha(first.split()[3])
    joined.alpha_composite(placeholder, (clip_x, clip_y))
    # The description is painted onto the quantized image with a reserved grey ramp: a palette built from
    # this dark image would turn white text yellow, and putting greys into the dithered background
    # scatters light specks across it.
    ramp = [255, 216, 178, 140, 102, 64]
    LOGO_COLOURS = 16
    n_bg = 255 - len(ramp) - LOGO_COLOURS
    base = joined.convert("RGB").quantize(colors=n_bg, method=Image.Quantize.MEDIANCUT, dither=BASE_DITHER)
    # The logo gets reserved colours of its own too (its cream and orange must stay true).
    logo = make_frame.title_logo(make_frame.LOGO_HEIGHT)
    lx = WIDTH - PANEL_T - make_frame.LOGO_MARGIN - logo.width
    ly = HEIGHT - PANEL_T - make_frame.LOGO_MARGIN - logo.height
    region = joined.crop((lx, ly, lx + logo.width, ly + logo.height)).convert("RGBA")
    region.alpha_composite(logo)
    comp = np.asarray(region.convert("RGB"), np.int32)
    warm = (comp[..., 0] - comp[..., 2]) > 70  # the orange of "MODE" and its rules
    def group_palette(mask, n):
        pix = sorted({tuple(c) for c in comp[mask]})
        strip = Image.new("RGB", (len(pix), 1))
        strip.putdata(pix)
        q = strip.quantize(colors=min(n, len(pix)), method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
        return [tuple(q.getpalette()[3 * i : 3 * i + 3]) for i in range(min(n, len(pix)))]
    logo_cols = group_palette(warm, 7) + group_palette(~warm, LOGO_COLOURS - 7)
    logo_cols += [logo_cols[0]] * (LOGO_COLOURS - len(logo_cols))
    logo_pal = [v for c in logo_cols for v in c]
    dist = ((comp[:, :, None, :] - np.array(logo_cols)[None, None]) ** 2).sum(-1)
    logo_q = dist.argmin(-1)
    pal = base.getpalette()[: 3 * n_bg] + [v for g in ramp for v in (g, g, g)] + logo_pal
    idx = np.array(base)
    m = np.asarray(desc_mask, np.float32) / 255
    bg_lum = 24.0  # the panel behind the text is near-black
    lum = bg_lum + (255 - bg_lum) * m  # luminance the antialiased pixel should have
    pick = np.abs(lum[..., None] - np.array(ramp, np.float32)).argmin(-1)
    idx = np.where(m > 0.06, n_bg + pick, idx).astype(np.uint8)
    logo_idx = logo_q + n_bg + len(ramp)
    logo_a = np.asarray(logo.split()[3]) > 64
    sub = idx[ly : ly + logo.height, lx : lx + logo.width]
    idx[ly : ly + logo.height, lx : lx + logo.width] = np.where(logo_a, logo_idx, sub)
    base = Image.fromarray(idx, "P")
    base.putpalette(pal + [0] * (768 - len(pal)))
    base.paste(255, mask=notch)

    with tempfile.TemporaryDirectory() as tmp:
        bg = os.path.join(tmp, "bg.gif")
        base.save(bg, save_all=True, duration=20, loop=0, transparency=255, disposal=1)
        merged = os.path.join(tmp, "merged.gif")
        subprocess.run(
            [gifsicle, f"--logical-screen={WIDTH}x{HEIGHT}", "--loopcount=forever", bg,
             f"--position={clip_x},{clip_y}", clip_path, "-o", merged],
            check=True,
        )
        subprocess.run([gifsicle, "--no-interlace", merged, "-o", args.output], check=True)
    print(f"{args.output}: {WIDTH}x{HEIGHT}, {os.path.getsize(args.output) // 1024} KB (clip {os.path.getsize(clip_path) // 1024} KB)")


if __name__ == "__main__":
    main()
