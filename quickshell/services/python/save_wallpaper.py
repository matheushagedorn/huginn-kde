#!/usr/bin/env python3
import json
import os
import sys

def save_wallpaper():
    if len(sys.argv) < 2:
        return
    wp_path = sys.argv[1].strip()
    variant = sys.argv[2].strip() if len(sys.argv) > 2 else ""

    user_file = os.path.expanduser('~/.config/quickshell_user_wallpaper.json')
    data = {"theme_wallpapers": {}, "active_variant": ""}

    if os.path.exists(user_file):
        try:
            with open(user_file, 'r', encoding='utf-8') as f:
                data = json.load(f)
                if not isinstance(data, dict):
                    data = {"theme_wallpapers": {}, "active_variant": ""}
        except Exception:
            data = {"theme_wallpapers": {}, "active_variant": ""}

    if "theme_wallpapers" not in data or not isinstance(data["theme_wallpapers"], dict):
        data["theme_wallpapers"] = {}

    if variant:
        data["theme_wallpapers"][variant] = wp_path
        data["active_variant"] = variant

    data["wallpaper"] = wp_path

    try:
        with open(user_file, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2)
    except Exception:
        pass

    try:
        import subprocess
        file_url = wp_path if wp_path.startswith("file://") else f"file://{wp_path}"
        subprocess.run(["kwriteconfig6", "--file", "kscreenlockerrc", "--group", "Greeter", "--group", "Wallpaper", "--group", "org.kde.image", "--group", "General", "--key", "Image", file_url], capture_output=True, timeout=2)
    except Exception:
        pass

if __name__ == '__main__':
    save_wallpaper()
