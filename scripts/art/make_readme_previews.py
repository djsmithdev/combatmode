"""Build the README's feature GIFs from the same screenshots as the setup wizard's slides.

    python scripts/art/make_readme_previews.py [SOURCE_DIR] [FEATURE ...]

SOURCE_DIR (default: Desktop/previews) holds one folder per feature with numbered screenshots, the
same input as scripts/art/make-wizard-previews.py. Each set is cropped the same way (16:9 around the
crosshair, crop_centre from that script), shown in order with the in-game timing (SLIDE_HOLD on each
slide, a SLIDE_FADE cross-fade into the next, looping) as a CLIP_W x CLIP_H clip, then put in its README
panel by make_feature_panel.py (title, description, frame, glow). Writes media/<name>.gif, at the
best QUALITY_STEPS entry that keeps it under BUDGET. Name
features (folder names) to rebuild only those. Needs Pillow, numpy, gifsicle and Friz Quadrata.
"""
import importlib.util
import os
import shutil
import subprocess
import sys
import tempfile

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
MEDIA = os.path.join(ROOT, "media")
DEFAULT_SOURCE = os.path.join(os.path.expanduser("~"), "Desktop", "previews")

sys.dont_write_bytecode = True  # no __pycache__ next to the scripts
_spec = importlib.util.spec_from_file_location("wizard_previews", os.path.join(HERE, "make-wizard-previews.py"))
wizard = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(wizard)

CLIP_W, CLIP_H = 640, 360
SLIDE_HOLD = 0.8  # seconds, as in UI/Wizard/Spotlight.lua
SLIDE_FADE = 0.2
# folder -> (hold, fade) seconds, the step's `slides` timing in SetupWizard.lua
TIMING_OVERRIDE = {"Mouselook": (0.3, 0.1), "AutoUnlock": (0.5, SLIDE_FADE)}
BUDGET = 2_000_000  # bytes per README GIF
# (in-between frames per cross-fade, gifsicle --lossy level), best first: each GIF uses the first step that
# fits BUDGET. Fade frames go first (each is on screen ~60 ms); lossy 80 visibly bands and tints the footage.
QUALITY_STEPS = [(3, 20), (2, 20), (2, 30), (1, 30), (1, 40), (1, 50), (1, 60)]

# Screenshot folder -> (README gif, panel title, one-line description), in README order.
FEATURES = {
    "ReticleTargeting": ("reticle_targeting", "Reticle Targeting",
        "Replace outdated tab targeting entirely: target whatever sits under your crosshair."),
    "CastAtCrosshair": ("cast_at_crosshair", "Cast at Crosshair",
        "Drop ground-targeted spells right where your crosshair points, with no extra click."),
    "Mouselook": ("mouse_look", "Mouse Look",
        "Lock your cursor to the center of the screen and steer by moving the mouse."),
    "ClickCasting": ("click_casting", "Click Casting",
        "Bind up to 8 spells, your whole rotation, to mouse clicks and free up your action bars."),
    "Crosshair": ("crosshair", "Dynamic Crosshair",
        "A reactive, fully customizable HUD that adapts to your target and combat state."),
    "AssistHUD": ("assist_hud", "Assist HUD",
        "Your next suggested cast and interaction prompts, right at the crosshair."),
    "RadialMenu": ("radial_menu", "Radial Menu",
        "Hold a key, flick toward a slice and release to activate its assigned action."),
    "PartyWheelSpells": ("party_wheel", "Party Wheel",
        "Hold a helpful spell's key to open a wheel of your group, then flick to cast on anyone."),
    "TargetLock": ("target_lock", "Target Lock & Cycle",
        "Lock your target to prevent swapping, then cycle the lock to specific units for easy prioritization."),
    "AllyCycle": ("ally_cycle", "Ally Cycle",
        "Cycle through your group to assist allies while still attacking your crosshair target."),
    "AutoUnlock": ("auto_unlock", "Auto Unlock",
        "Your cursor frees itself when you open interface panels, then resumes when you close them."),
}


def load_slides(source, folder):
    files = sorted(
        (f for f in os.listdir(os.path.join(source, folder)) if os.path.splitext(f)[0].isdigit()),
        key=lambda f: int(os.path.splitext(f)[0]),
    )
    slides = []
    for f in files:
        img = Image.open(os.path.join(source, folder, f)).convert("RGB")
        img = wizard.crop_centre(img, wizard.CROP_OVERRIDE.get(folder, wizard.CROP_H))
        slides.append(img.resize((CLIP_W, CLIP_H), Image.LANCZOS))
    return slides


def quantize(img):
    return img.quantize(256, method=Image.Quantize.MEDIANCUT, kmeans=3, dither=Image.Dither.FLOYDSTEINBERG)


def build_raw_clip(slides, held, fade_steps, hold, fade, path):
    """One full frame per slide held `hold` seconds, then fade_steps blends into the next one; each frame
    has its own dithered palette (`held` = the slides already quantized)."""
    frames, durations = [], []
    fade_ms = round(fade * 1000 / fade_steps)
    for i, slide in enumerate(slides):
        nxt = slides[(i + 1) % len(slides)]
        frames.append(held[i])
        durations.append(round(hold * 1000))
        if len(slides) > 1:
            for k in range(1, fade_steps + 1):
                frames.append(quantize(Image.blend(slide, nxt, k / (fade_steps + 1))))
                durations.append(fade_ms)
    frames[0].save(path, save_all=True, append_images=frames[1:], duration=durations, loop=0, disposal=1)


def build_panel(raw, lossy, out, title, description, gifsicle):
    """Optimize the raw clip (gifsicle stores only what changes) and put it in its README panel."""
    clip = raw + f".{lossy}.gif"
    args = [gifsicle, "-w", "-O3", "--no-interlace"] + ([f"--lossy={lossy}"] if lossy else []) + [raw, "-o", clip]
    subprocess.run(args, check=True)
    subprocess.run(
        [sys.executable, os.path.join(HERE, "make_feature_panel.py"), clip, out, "--title", title, "--description", description],
        check=True,
        stdout=subprocess.DEVNULL,
    )
    return os.path.getsize(out)


def main():
    args = sys.argv[1:]
    source = args.pop(0) if args and os.path.isdir(args[0]) else DEFAULT_SOURCE
    only = set(args)
    gifsicle = shutil.which("gifsicle")
    if not gifsicle:
        sys.exit("gifsicle not found on PATH (scoop install gifsicle)")
    with tempfile.TemporaryDirectory() as tmp:
        for folder, (name, title, description) in FEATURES.items():
            if only and folder not in only:
                continue
            slides = load_slides(source, folder)
            if not slides:
                print(f"{folder}: no screenshots, skipped")
                continue
            held = [quantize(s) for s in slides]
            out = os.path.join(tmp, name + ".gif")  # copied to media/ once it fits
            built = None
            for fade_steps, lossy in QUALITY_STEPS:
                raw = os.path.join(tmp, f"{name}_{fade_steps}.gif")
                if not os.path.exists(raw):
                    build_raw_clip(slides, held, fade_steps, *TIMING_OVERRIDE.get(folder, (SLIDE_HOLD, SLIDE_FADE)), raw)
                size = build_panel(raw, lossy, out, title, description, gifsicle)
                if size <= BUDGET:
                    built = (fade_steps, lossy)
                    break
            shutil.copyfile(out, os.path.join(MEDIA, name + ".gif"))
            note = f"fades {built[0]}, lossy {built[1]}" if built else "OVER BUDGET at the lowest step"
            print(f"{name}.gif: {size / 1e6:.2f} MB ({note})")


if __name__ == "__main__":
    main()
