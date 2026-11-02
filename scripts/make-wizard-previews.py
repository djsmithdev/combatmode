"""Build the setup wizard's preview slides and their shared frame from full-screen screenshots.

    python scripts/make-wizard-previews.py [SOURCE_DIR]

SOURCE_DIR (default: Desktop/previews) holds one folder per feature with numbered screenshots
(1.jpg, 2.png, ...). Each one is cropped at 16:9 (the README GIFs' ratio) around the crosshair
(centred horizontally, CROSSHAIR_Y up from the bottom) and written as
CombatMode/Assets/wizard/<key>_<n>.blp, numbered in order.

Slides are BLP2 with DXT1 compression and a full mip chain, like Blizzard's own textures (and the
addon's other .blp art): 4 bits per pixel instead of the 24 an uncompressed TGA needs, and RLE does
next to nothing on photos. The texture is a power-of-two SLIDE_W x SLIDE_H (2:1), so the 16:9 crop is
stored squashed vertically; the game draws it back at 16:9 (Spotlight.lua sizes it 276 x 155). Every
written file is decoded again (Pillow reads BLP) and its PSNR against the source printed.

The frame (the GIFs' metal band, inner + drop shadow and copper glow, transparent window) is one
shared overlay, preview_frame.tga, drawn over every slide in game (UI/Wizard/Spotlight.lua); it keeps
its soft alpha as an RLE TGA (scripts/compress-tga.py). Needs Pillow + numpy.
"""
import glob
import os
import struct
import subprocess
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "media", "frame"))
import make_frame  # noqa: E402

OUT = os.path.join(ROOT, "CombatMode", "Assets", "wizard")
DEFAULT_SOURCE = os.path.join(os.path.expanduser("~"), "Desktop", "previews")

SLIDE_W, SLIDE_H = 512, 256  # stored size (power of two); shown at 16:9 in game
CROP_H = 0.4  # crop height as a share of the screenshot's height (1440 -> 1024x576)
CROP_OVERRIDE = {}  # folder -> CROP_H for sets that need a tighter or looser crop
CROSSHAIR_Y = 840 / 1440  # the crosshair's height above the bottom edge; the crop is centred on it

# Screenshot folder -> asset key (the step's `slides` key in SetupWizard.lua).
FOLDERS = {
    "Mouselook": "mouselook",
    "Crosshair": "crosshair",
    "AssistHUD": "assisthud",
    "ReticleTargeting": "reticle",
    "CastAtCrosshair": "castatcrosshair",
    "TargetLock": "targetlock",
    "ClickCasting": "clickcasting",
    "RadialMenu": "radial",
    "PartyWheelSpells": "partywheel",
    "AllyCycle": "allycycle",
    "AutoUnlock": "autounlock",
}

# The frame is drawn at twice the in-game size (Spotlight.lua: SLIDE_W x SLIDE_H = 276 x 155).
FRAME_WINDOW = (552, 310)
FRAME_MARGIN = 56  # transparent room around the band for the drop shadow and the glow
GLOW_COLOUR = (208, 138, 82)
GLOW_BLUR = 16
GLOW_STRENGTH = 0.5


def crop_centre(img, share):
    """16:9 crop `share` of the image tall, centred horizontally and on the crosshair vertically."""
    w, h = img.size
    ch = round(h * share)
    cw = round(ch * 16 / 9)
    if cw > w:
        cw = w
        ch = round(cw * 9 / 16)
    cy = h * (1 - CROSSHAIR_Y)
    x = (w - cw) // 2
    y = min(max(round(cy - ch / 2), 0), h - ch)
    return img.crop((x, y, x + cw, y + ch))


def to565(c):
    """float RGB (N, 3) -> packed 5:6:5 (N,) and the 8-bit colours those values expand back to."""
    r = np.clip(np.round(c[:, 0] * 31 / 255), 0, 31).astype(np.uint32)
    g = np.clip(np.round(c[:, 1] * 63 / 255), 0, 63).astype(np.uint32)
    b = np.clip(np.round(c[:, 2] * 31 / 255), 0, 31).astype(np.uint32)
    packed = (r << 11) | (g << 5) | b
    expanded = np.stack([(r << 3) | (r >> 2), (g << 2) | (g >> 4), (b << 3) | (b >> 2)], 1).astype(np.float32)
    return packed, expanded


def dxt1(rgb):
    """DXT1 (BC1, opaque 4-colour mode) blocks for an RGB uint8 array; sides are padded to 4 by edge copy.
    Endpoints: the block's colours projected on their principal axis, refined once by least squares."""
    h, w = rgb.shape[:2]
    ph, pw = -(-h // 4) * 4, -(-w // 4) * 4
    if (ph, pw) != (h, w):
        rgb = np.pad(rgb, ((0, ph - h), (0, pw - w), (0, 0)), mode="edge")
    px = rgb.reshape(ph // 4, 4, pw // 4, 4, 3).transpose(0, 2, 1, 3, 4).reshape(-1, 16, 3).astype(np.float32)
    mean = px.mean(1)
    centred = px - mean[:, None]
    cov = np.einsum("nki,nkj->nij", centred, centred)
    axis = np.ones((len(px), 3), np.float32)
    for _ in range(8):  # power iteration for the dominant axis
        axis = np.einsum("nij,nj->ni", cov, axis)
        axis /= np.maximum(np.linalg.norm(axis, axis=1, keepdims=True), 1e-6)
    proj = np.einsum("nki,ni->nk", centred, axis)
    e0 = mean + axis * proj.max(1)[:, None]
    e1 = mean + axis * proj.min(1)[:, None]

    weights = np.array([1, 0, 2 / 3, 1 / 3], np.float32)  # share of e0 in palette entries 0..3

    def nearest(a, b):
        pal = weights[None, :, None] * a[:, None] + (1 - weights[None, :, None]) * b[:, None]
        return ((px[:, :, None] - pal[:, None]) ** 2).sum(-1).argmin(-1)

    # one least-squares pass: the endpoints that best fit the pixels for the chosen indices
    t = weights[nearest(e0, e1)]
    a11, a22, a12 = (t * t).sum(1), ((1 - t) ** 2).sum(1), (t * (1 - t)).sum(1)
    det = a11 * a22 - a12 * a12
    ok = np.abs(det) > 1e-6
    r0 = np.einsum("nk,nki->ni", t, px)
    r1 = np.einsum("nk,nki->ni", 1 - t, px)
    safe = np.where(ok, det, 1)[:, None]
    e0 = np.where(ok[:, None], (a22[:, None] * r0 - a12[:, None] * r1) / safe, e0)
    e1 = np.where(ok[:, None], (a11[:, None] * r1 - a12[:, None] * r0) / safe, e1)

    c0, q0 = to565(np.clip(e0, 0, 255))
    c1, q1 = to565(np.clip(e1, 0, 255))
    swap = c0 < c1  # c0 > c1 selects the 4-colour mode
    c0, c1 = np.where(swap, c1, c0), np.where(swap, c0, c1)
    q0, q1 = np.where(swap[:, None], q1, q0), np.where(swap[:, None], q0, q1)
    idx = nearest(q0, q1).astype(np.uint32)
    idx[c0 == c1] = 0  # flat block: palette entry 0 only
    bits = (idx << (2 * np.arange(16, dtype=np.uint32))).sum(1).astype(np.uint32)
    out = np.zeros(len(px), dtype=[("c0", "<u2"), ("c1", "<u2"), ("bits", "<u4")])
    out["c0"], out["c1"], out["bits"] = c0, c1, bits
    return out.tobytes()


def save_blp_dxt1(img, path):
    """BLP2, DXT1, no alpha, full mip chain down to 1x1 (header: magic, type 1, compression 2, alpha depth
    0, alpha encoding 0, has mips, size, 16 mip offsets + sizes, unused 256-entry palette)."""
    w, h = img.size
    levels = []
    while True:
        levels.append(dxt1(np.asarray(img.resize((w, h), Image.LANCZOS) if img.size != (w, h) else img)))
        if w == 1 and h == 1:
            break
        w, h = max(1, w // 2), max(1, h // 2)
    header = 4 + 4 + 4 + 8 + 64 + 64 + 1024
    offsets, sizes, pos = [], [], header
    for data in levels:
        offsets.append(pos)
        sizes.append(len(data))
        pos += len(data)
    offsets += [0] * (16 - len(levels))
    sizes += [0] * (16 - len(levels))
    with open(path, "wb") as f:
        f.write(b"BLP2" + struct.pack("<I4B2I", 1, 2, 0, 0, 1, *img.size))
        f.write(struct.pack("<16I", *offsets) + struct.pack("<16I", *sizes) + bytes(1024))
        for data in levels:
            f.write(data)


def psnr(a, b):
    mse = ((np.asarray(a, np.float32) - np.asarray(b, np.float32)) ** 2).mean()
    return 10 * np.log10(255**2 / max(mse, 1e-9))


def build_slides(source):
    count, total, worst = 0, 0, 99.0
    for folder, key in FOLDERS.items():
        files = sorted(
            (f for f in glob.glob(os.path.join(source, folder, "*")) if os.path.splitext(f)[0][-1:].isdigit()),
            key=lambda f: int(os.path.splitext(os.path.basename(f))[0]),
        )
        if not files:
            print(f"{folder}: no screenshots, skipped")
            continue
        for old in glob.glob(os.path.join(OUT, f"{key}_*.tga")) + glob.glob(os.path.join(OUT, f"{key}_*.blp")):
            os.remove(old)
        for i, path in enumerate(files, 1):
            img = Image.open(path).convert("RGB")
            img = crop_centre(img, CROP_OVERRIDE.get(folder, CROP_H)).resize((SLIDE_W, SLIDE_H), Image.LANCZOS)
            out = os.path.join(OUT, f"{key}_{i}.blp")
            save_blp_dxt1(img, out)
            with Image.open(out) as check:
                worst = min(worst, psnr(img, check.convert("RGB")))
            total += os.path.getsize(out)
            count += 1
        print(f"{folder}: {len(files)} slides -> {key}_1..{len(files)}")
    print(f"slides: {total / 1e6:.1f} MB, worst PSNR after decoding {worst:.1f} dB")
    return count


def build_frame():
    cw, ch = FRAME_WINDOW
    framed, origin = make_frame.build(cw, ch)  # band + inner shadow + drop shadow
    w, h = cw + 2 * (FRAME_MARGIN + make_frame.BT), ch + 2 * (FRAME_MARGIN + make_frame.BT)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    # copper glow around the band (under it), like the README panels
    glow = Image.new("L", (w, h), 0)
    ImageDraw.Draw(glow).rectangle((FRAME_MARGIN, FRAME_MARGIN, w - FRAME_MARGIN - 1, h - FRAME_MARGIN - 1), fill=255)
    glow = glow.filter(ImageFilter.GaussianBlur(GLOW_BLUR)).point(lambda v: int(v * GLOW_STRENGTH))
    glow.paste(0, (FRAME_MARGIN + make_frame.BT, FRAME_MARGIN + make_frame.BT, w - FRAME_MARGIN - make_frame.BT, h - FRAME_MARGIN - make_frame.BT))
    out.alpha_composite(framed, (FRAME_MARGIN + make_frame.BT - origin, FRAME_MARGIN + make_frame.BT - origin))
    tint = Image.new("RGBA", (w, h), GLOW_COLOUR + (0,))
    tint.putalpha(glow)
    # glow behind the shadow + band: composite the frame over the glow
    base = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    base.alpha_composite(tint)
    base.alpha_composite(out)
    path = os.path.join(OUT, "preview_frame.tga")
    base.save(path)
    print(f"preview_frame.tga: {w}x{h}, window {cw}x{ch} at {FRAME_MARGIN + make_frame.BT}")


def main():
    source = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_SOURCE
    os.makedirs(OUT, exist_ok=True)
    n = build_slides(source)
    build_frame()
    subprocess.run([sys.executable, os.path.join(ROOT, "scripts", "compress-tga.py"), OUT], check=True)
    print(f"{n} slides written to {OUT}")


if __name__ == "__main__":
    main()
