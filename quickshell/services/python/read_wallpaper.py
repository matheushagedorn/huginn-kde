#!/usr/bin/env python3
import json
import os
import sys

def read_wallpaper():
    target_variant = sys.argv[1].strip() if len(sys.argv) > 1 else ""
    user_file = os.path.expanduser('~/.config/quickshell_user_wallpaper.json')

    if os.path.exists(user_file):
        try:
            with open(user_file, 'r', encoding='utf-8') as f:
                data = json.load(f)
                if isinstance(data, dict):
                    tw = data.get("theme_wallpapers", {})
                    active_v = target_variant or data.get("active_variant", "")

                    if active_v and isinstance(tw, dict) and tw.get(active_v):
                        cached_wp = tw.get(active_v)
                        raw = cached_wp.replace("file://", "")
                        if os.path.exists(raw):
                            print(json.dumps({"wallpaper": cached_wp, "variant": active_v, "theme_wallpapers": tw}), flush=True)
                            return

                    if data.get("wallpaper"):
                        raw = data["wallpaper"].replace("file://", "")
                        if os.path.exists(raw):
                            print(json.dumps({"wallpaper": data["wallpaper"], "variant": active_v, "theme_wallpapers": tw}), flush=True)
                            return

                    print(json.dumps({"wallpaper": "", "variant": active_v, "theme_wallpapers": tw}), flush=True)
                    return
        except Exception:
            pass

    print(json.dumps({"wallpaper": "", "variant": target_variant, "theme_wallpapers": {}}), flush=True)

if __name__ == '__main__':
    read_wallpaper()
