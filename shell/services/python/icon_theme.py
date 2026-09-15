#!/usr/bin/env python3
"""Find a themed icon for apps whose own icon is a generated one.

A web app installed from Brave or Chrome does not ship an icon: the browser
renders one from the site's favicon into ~/.local/share/icons/hicolor. Those
files are whatever the site provides, which for WhatsApp is a white disc that
fills its whole box. Next to a row of Papirus icons it reads as a blown-out
white circle, and no amount of scaling fixes a white disc on a dark dock.

The icon theme almost always has a proper icon for the same service, so when
the app's own icon is one of these generated files, the theme is asked first
by the app's name. Anything the theme does not know keeps the generated icon.
"""
import os
import re

GENERATED_ICON = re.compile(r"^(brave|chrome|chromium|msedge|vivaldi)-[a-z0-9]{20,}-", re.I)

SIZES = ["scalable/apps", "512x512/apps", "256x256/apps", "128x128/apps",
         "64x64/apps", "48x48/apps", "32x32/apps"]

EXTS = [".svg", ".png"]

_search_dirs = None


def _icon_themes():
    """The user's icon theme first, then the usual fallbacks."""
    themes = []
    try:
        section = ""
        with open(os.path.expanduser("~/.config/kdeglobals"), "r", errors="replace") as f:
            for line in f:
                line = line.strip()
                if line.startswith("["):
                    section = line
                elif section == "[Icons]" and line.startswith("Theme="):
                    themes.append(line.split("=", 1)[1].strip())
    except Exception:
        pass

    for fallback in ("Papirus-Dark", "Papirus", "breeze", "hicolor"):
        if fallback not in themes:
            themes.append(fallback)
    return themes


def _dirs():
    global _search_dirs
    if _search_dirs is not None:
        return _search_dirs

    bases = [os.path.expanduser("~/.local/share/icons"), "/usr/share/icons"]
    dirs = []
    for theme in _icon_themes():
        for base in bases:
            for size in SIZES:
                d = os.path.join(base, theme, size)
                if os.path.isdir(d):
                    dirs.append(d)

    _search_dirs = dirs
    return dirs


def is_generated_web_icon(path):
    if not path:
        return False
    return bool(GENERATED_ICON.match(os.path.basename(str(path))))


def _slugs(name):
    """Names to ask the theme for, most specific first."""
    clean = re.sub(r"[^a-z0-9]+", "-", str(name).lower()).strip("-")
    if not clean:
        return []

    out = [clean]
    # "whatsapp-web" also answers to "whatsapp", which is what the theme calls it
    parts = clean.split("-")
    if len(parts) > 1:
        out.append(parts[0])
        out.append("".join(parts))
    return out


def themed_icon_for(name):
    """Absolute path of a themed icon for this app name, or "" if unknown."""
    for slug in _slugs(name):
        for d in _dirs():
            for ext in EXTS:
                p = os.path.join(d, slug + ext)
                if os.path.exists(p):
                    return p
    return ""


def prefer_themed(icon_path, app_name):
    """Swap a browser-generated icon for the theme's, when there is one."""
    if not is_generated_web_icon(icon_path):
        return icon_path
    return themed_icon_for(app_name) or icon_path
