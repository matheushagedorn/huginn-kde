#!/usr/bin/env python3
"""Build a shell palette out of a wallpaper.

Prints one JSON object with the colours Theme.setVariant expects. The point is
the thing every Material You config gets for free and this shell did not: the
bar, the popups and the cards picking up the picture behind them.

matugen and wallust are the usual tools for this and neither is installed here
(the `wallust run` call in Theme.qml has been a no-op the whole time). Pillow
is already a dependency of nothing in particular but is present, so the whole
extraction is done here: quantise the image, score the colours, and build a
dark palette around the one that carries the picture.
"""
import colorsys
import json
import os
import sys

CACHE = os.path.expanduser("~/.config/huginn_wallpaper_palette.json")


def _hsv_to_hex(h, s, v):
    r, g, b = colorsys.hsv_to_rgb(h % 1.0, max(0.0, min(1.0, s)), max(0.0, min(1.0, v)))
    return "#%02x%02x%02x" % (round(r * 255), round(g * 255), round(b * 255))


def extract(path):
    from PIL import Image

    img = Image.open(path).convert("RGB")
    img.thumbnail((240, 240))
    # 16 buckets is enough to separate the subject from the ground without
    # splitting one gradient into a dozen near-identical entries.
    quantised = img.quantize(colors=16, method=Image.MEDIANCUT).convert("RGB")
    counts = sorted(quantised.getcolors(maxcolors=4096) or [], reverse=True)
    if not counts:
        raise ValueError("no colours in image")

    total = sum(c for c, _ in counts)
    entries = []
    for count, (r, g, b) in counts:
        h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
        entries.append({"h": h, "s": s, "v": v, "weight": count / total})

    # The accent is the colour a person would name if asked what colour the
    # wallpaper is: vivid enough to register, present enough to matter, and
    # not so dark that it disappears against the panel it will sit on.
    def accent_score(e):
        return (e["s"] ** 1.6) * (e["v"] ** 0.6) * (e["weight"] ** 0.25)

    vivid = [e for e in entries if e["s"] >= 0.18 and e["v"] >= 0.15]
    accent_src = max(vivid, key=accent_score) if vivid else max(entries, key=lambda e: e["weight"])

    # The ground takes the picture's dominant hue but almost none of its
    # colour: a bar has to stay readable under any wallpaper, so the hue is a
    # tint, never a wash.
    ground_src = max(entries, key=lambda e: e["weight"] * (1.2 - e["v"]))
    gh = ground_src["h"]

    accent_h = accent_src["h"]
    accent_s = max(0.45, min(0.85, accent_src["s"] * 1.1))
    accent_v = max(0.78, min(0.98, accent_src["v"] * 1.25))

    # A second hue for the places that need to differ from the accent without
    # arguing with it. A quarter turn reads as related, not as a clash.
    sub_h = accent_h + 0.12

    palette = {
        "name": "From wallpaper",
        # Which picture this came from, so a cached palette left over from
        # another wallpaper is recognised as stale rather than applied.
        "source": os.path.abspath(path),
        "isDark": True,
        "accent": _hsv_to_hex(accent_h, accent_s, accent_v),
        "subAccent": _hsv_to_hex(sub_h, accent_s * 0.95, accent_v),
        "bg": _hsv_to_hex(gh, 0.22, 0.11),
        "surface": _hsv_to_hex(gh, 0.20, 0.17),
        "currentLine": _hsv_to_hex(gh, 0.17, 0.30),
        "fg": _hsv_to_hex(gh, 0.05, 0.97),
        "comment": _hsv_to_hex(gh, 0.28, 0.62),
    }
    return palette


def main():
    if len(sys.argv) < 2:
        print(json.dumps({"error": "no wallpaper given"}), flush=True)
        return

    path = sys.argv[1]
    if path.startswith("file://"):
        path = path[7:]

    if not os.path.exists(path):
        print(json.dumps({"error": "wallpaper not found"}), flush=True)
        return

    try:
        palette = extract(path)
    except Exception as exc:
        print(json.dumps({"error": str(exc)}), flush=True)
        return

    # Cached so the next start can paint the right colours on the first frame
    # instead of showing the fallback palette until this script answers.
    try:
        with open(CACHE, "w") as f:
            json.dump(palette, f)
    except Exception:
        pass

    print(json.dumps(palette), flush=True)


if __name__ == "__main__":
    main()
