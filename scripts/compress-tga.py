"""Losslessly RLE-compress uncompressed truecolor TGAs under CombatMode/Assets.

Usage: python scripts/compress-tga.py [--check] [path ...]
Default path is CombatMode/Assets. --check only reports; without it files are
rewritten in place, and only when the RLE result is smaller and decodes back to
the exact same pixels. Already-RLE files are left alone, so re-running is safe.
"""
import os
import struct
import sys


def encode_rle(data, px, w, h):
    out = bytearray()
    for y in range(h):
        row = data[y * w * px:(y + 1) * w * px]
        pixels = [row[i:i + px] for i in range(0, len(row), px)]
        i, n = 0, len(pixels)
        while i < n:
            run = 1
            while i + run < n and run < 128 and pixels[i + run] == pixels[i]:
                run += 1
            if run >= 2:
                out.append(0x80 | (run - 1))
                out += pixels[i]
                i += run
            else:
                j = i + 1
                while j < n and j - i < 128 and not (j + 1 < n and pixels[j] == pixels[j + 1]):
                    j += 1
                out.append(j - i - 1)
                for k in range(i, j):
                    out += pixels[k]
                i = j
    return bytes(out)


def decode_rle(data, px, count):
    out = bytearray()
    i = 0
    while len(out) < count * px:
        head = data[i]
        i += 1
        n = (head & 0x7F) + 1
        if head & 0x80:
            out += data[i:i + px] * n
            i += px
        else:
            out += data[i:i + n * px]
            i += n * px
    return bytes(out), i


def compress(path, write):
    b = open(path, "rb").read()
    idlen, cmap, itype = b[0], b[1], b[2]
    w, h = struct.unpack("<HH", b[12:16])
    bpp = b[16]
    if itype != 2 or cmap != 0 or bpp not in (16, 24, 32):
        return "skip (type %d, %dbpp)" % (itype, bpp), len(b), len(b)
    px = bpp // 8
    off = 18 + idlen
    raw_end = off + w * h * px
    pixels, tail = b[off:raw_end], b[raw_end:]
    body = encode_rle(pixels, px, w, h)
    new = bytearray(b[:off])
    new[2] = 10
    new += body + tail
    if len(new) >= len(b):
        return "skip (not smaller)", len(b), len(b)
    # Verify: decode the new file back and compare against the original pixels.
    back, used = decode_rle(bytes(new[off:]), px, w * h)
    if back != pixels or bytes(new[off + used:]) != tail:
        return "FAILED verify", len(b), len(b)
    if write:
        with open(path, "wb") as f:
            f.write(new)
    return "ok", len(b), len(new)


def main():
    args = sys.argv[1:]
    write = "--check" not in args
    roots = [a for a in args if not a.startswith("--")] or [
        os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "CombatMode", "Assets")
    ]
    before = after = failed = 0
    for root in roots:
        for dp, _, fs in os.walk(root):
            for f in sorted(fs):
                if not f.lower().endswith(".tga"):
                    continue
                p = os.path.join(dp, f)
                status, old, new = compress(p, write)
                before += old
                after += new
                if status == "FAILED verify":
                    failed += 1
                    print("FAILED:", p)
    print("%s: %.1f MB -> %.1f MB" % ("rewritten" if write else "would be", before / 1e6, after / 1e6))
    sys.exit(1 if failed else 0)


main()
