#!/usr/bin/env python3
"""How much of an icon's box its artwork actually fills.

Application icons do not agree on how much padding they carry. Papirus and
most desktop icons leave a margin inside the square; an icon generated from a
web app, like a Brave PWA, is edge to edge. Drawn at the same box size, the
edge-to-edge one reads as much bigger than everything beside it, which is the
"blown up" WhatsApp tile in the dock and the launcher.

So each icon is measured once and gets a scale that brings its artwork to the
same optical size as the rest. SVGs are assumed to follow the icon theme's own
padding convention and are left alone; Pillow cannot rasterise them anyway.
"""
import json
import os

CACHE_PATH = os.path.expanduser("~/.cache/huginn/icon_metrics.json")

# What share of the box the artwork should cover. Papirus sits around here, so
# icons that already follow the convention are not touched.
TARGET_COVERAGE = 0.84

# Below this the correction is not worth a redraw.
MIN_CORRECTION = 0.97

_cache = None
_dirty = False


def _load_cache():
    global _cache
    if _cache is not None:
        return _cache
    try:
        with open(CACHE_PATH, "r") as f:
            _cache = json.load(f)
    except Exception:
        _cache = {}
    return _cache


def save_cache():
    global _dirty
    if not _dirty:
        return
    try:
        os.makedirs(os.path.dirname(CACHE_PATH), exist_ok=True)
        with open(CACHE_PATH, "w") as f:
            json.dump(_load_cache(), f)
        _dirty = False
    except Exception:
        pass


def _measure(path):
    from PIL import Image

    with Image.open(path) as im:
        im = im.convert("RGBA")
        width, height = im.size
        box = im.getbbox()

    if not box or not width or not height:
        return 1.0

    coverage = max((box[2] - box[0]) / width, (box[3] - box[1]) / height)
    if coverage <= 0:
        return 1.0

    scale = min(1.0, TARGET_COVERAGE / coverage)
    return 1.0 if scale > MIN_CORRECTION else round(scale, 3)


def optical_scale(path):
    """Factor to draw this icon at, between 0 and 1. 1.0 means leave it alone."""
    global _dirty

    if not path or not isinstance(path, str):
        return 1.0
    if path.startswith("file://"):
        path = path[7:]
    if path.lower().endswith(".svg") or not os.path.exists(path):
        return 1.0

    try:
        stat = os.stat(path)
        key = "%s:%d:%d" % (path, stat.st_mtime_ns, stat.st_size)
    except Exception:
        return 1.0

    cache = _load_cache()
    if key in cache:
        return cache[key]

    try:
        scale = _measure(path)
    except Exception:
        scale = 1.0

    cache[key] = scale
    _dirty = True
    return scale
