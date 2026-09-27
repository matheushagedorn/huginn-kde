#!/usr/bin/env python3
"""Pick the colour of the album art that is playing, for the media island.

Usage: album_tint.py <mpris:artUrl>

Prints one JSON line: {"source": <the url given>, "tint": "#rrggbb"} when a
colour was found, or {"source": ..., "error": ...} when it was not. The bar
falls back to the theme accent on an error, so every failure here (no Pillow,
no network, a cover that is pure black and white) is an answer, never a crash.

MPRIS hands out covers in two shapes: file:// paths (browsers through
plasma-browser-integration, local players) and https URLs (Spotify points at
i.scdn.co). The remote ones are downloaded once into ~/.cache/huginn/covers,
and the colour picked for every cover is remembered there too, so going back
to a track, or restarting the shell, does not decode the image again.

The colour is chosen the way wallpaper_palette.py chooses the wallpaper's
accent: quantise, score by vividness and presence, keep the winner.
"""
import colorsys
import hashlib
import json
import os
import sys
import time
import urllib.parse
import urllib.request

CACHE_DIR = os.path.expanduser("~/.cache/huginn/covers")
TINT_CACHE = os.path.join(CACHE_DIR, "tints.json")
# Covers are small (Spotify's are 640px JPEGs, around 100KB). Anything far
# past this is not a cover and is not worth holding in memory.
MAX_BYTES = 8 * 1024 * 1024
# A downloaded cover is only needed while its track is still likely to come
# round again; after that it is dead weight in the cache.
MAX_AGE = 14 * 24 * 3600
MAX_TINTS = 400


def _key(url):
    return hashlib.sha1(url.encode("utf-8", "replace")).hexdigest()[:20]


def _load_tints():
    try:
        with open(TINT_CACHE) as f:
            data = json.load(f)
        return data if isinstance(data, dict) else {}
    except Exception:
        return {}


def _save_tints(tints):
    # Oldest entries go first once the map is full. Written through a
    # temporary file so a shell restart mid-write cannot leave half a JSON.
    if len(tints) > MAX_TINTS:
        ordered = sorted(tints.items(), key=lambda kv: kv[1].get("t", 0))
        tints = dict(ordered[-MAX_TINTS:])
    tmp = TINT_CACHE + ".tmp"
    with open(tmp, "w") as f:
        json.dump(tints, f)
    os.replace(tmp, TINT_CACHE)


def _prune():
    now = time.time()
    try:
        for name in os.listdir(CACHE_DIR):
            if not name.endswith(".img"):
                continue
            path = os.path.join(CACHE_DIR, name)
            try:
                if now - os.path.getmtime(path) > MAX_AGE:
                    os.remove(path)
            except OSError:
                pass
    except OSError:
        pass


def _local_path(url):
    """The cover as a file on disk, downloading it first if it is remote."""
    if url.startswith("file://"):
        path = urllib.parse.unquote(url[7:])
        if not os.path.isfile(path):
            raise FileNotFoundError("cover not found")
        return path
    if url.startswith("/"):
        return url

    if not url.startswith(("http://", "https://")):
        raise ValueError("unsupported cover url")

    path = os.path.join(CACHE_DIR, _key(url) + ".img")
    if os.path.isfile(path) and os.path.getsize(path) > 0:
        return path

    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=8) as response:
        data = response.read(MAX_BYTES + 1)
    if not data or len(data) > MAX_BYTES:
        raise ValueError("cover download empty or too large")

    tmp = path + ".part"
    with open(tmp, "wb") as f:
        f.write(data)
    os.replace(tmp, path)
    return path


def _cache_key(url, path):
    # A local path can be reused for a different picture (plasma-browser-
    # integration writes the current tab's artwork into /tmp), so its key
    # carries the file's mtime and size. A remote URL names one picture.
    if url.startswith(("http://", "https://")):
        return _key(url)
    st = os.stat(path)
    return _key("%s|%d|%d" % (url, st.st_mtime_ns, st.st_size))


def tint_of(path):
    # Imported here so a machine without Pillow still gets a clean JSON error
    # instead of a traceback, and the bar keeps the theme accent.
    from PIL import Image
    from wallpaper_palette import colour_entries, pick_vivid

    with Image.open(path) as img:
        entries = colour_entries(img)
    src = pick_vivid(entries)
    if src is None:
        raise ValueError("no vivid colour in cover")

    # Pulled into the range where it reads as a colour on a dark bar without
    # glaring: a near-black navy cover would otherwise tint nothing, and a
    # pure neon one would drown the title. Same bounds as the wallpaper
    # accent, a touch less saturated since this sits behind text.
    s = max(0.40, min(0.80, src["s"] * 1.1))
    v = max(0.72, min(0.96, src["v"] * 1.25))
    r, g, b = colorsys.hsv_to_rgb(src["h"] % 1.0, s, v)
    return "#%02x%02x%02x" % (round(r * 255), round(g * 255), round(b * 255))


def resolve(url):
    os.makedirs(CACHE_DIR, exist_ok=True)
    path = _local_path(url)
    key = _cache_key(url, path)

    tints = _load_tints()
    hit = tints.get(key)
    if hit and hit.get("tint"):
        return hit["tint"]

    tint = tint_of(path)
    tints[key] = {"tint": tint, "t": time.time()}
    try:
        _save_tints(tints)
    except OSError:
        pass
    _prune()
    return tint


def main():
    url = sys.argv[1].strip() if len(sys.argv) > 1 else ""
    if not url:
        print(json.dumps({"source": "", "error": "no cover"}), flush=True)
        return
    try:
        print(json.dumps({"source": url, "tint": resolve(url)}), flush=True)
    except Exception as exc:
        print(json.dumps({"source": url, "error": str(exc) or type(exc).__name__}), flush=True)


if __name__ == "__main__":
    main()
