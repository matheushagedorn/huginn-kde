#!/usr/bin/env python3
import os
import json
import sys

def scan_wallpapers():
    search_dirs = [
        os.path.expanduser('~/Pictures/Wallpapers'),
        os.path.expanduser('~/.config/quickshell/wallpapers'),
        '/usr/share/wallpapers',
        '/usr/share/backgrounds'
    ]
    res = []
    seen_realpaths = set()
    seen_file_signatures = set()

    for base_dir in search_dirs:
        if not os.path.exists(base_dir):
            continue
        for root, dirs, files in os.walk(base_dir):
            for filename in files:
                if filename.lower().endswith(('.png', '.jpg', '.jpeg', '.webp', '.svg')):
                    full_path = os.path.join(root, filename)
                    real_path = os.path.realpath(full_path)
                    
                    if real_path in seen_realpaths:
                        continue

                    try:
                        file_size = os.path.getsize(full_path)
                    except Exception:
                        file_size = 0

                    # Determine parent variant name
                    folder_name = os.path.basename(root)
                    if folder_name.lower() in ("contents", "screenshots", "images"):
                        parent_folder = os.path.basename(os.path.dirname(root))
                        variant_name = parent_folder if parent_folder and parent_folder != os.path.basename(base_dir) else os.path.splitext(filename)[0]
                    elif root != base_dir:
                        variant_name = folder_name
                    else:
                        variant_name = os.path.splitext(filename)[0]

                    sig = (variant_name.lower(), filename.lower(), file_size)

                    if sig in seen_file_signatures:
                        continue

                    seen_realpaths.add(real_path)
                    seen_file_signatures.add(sig)

                    res.append({
                        'variant': variant_name,
                        'name': filename,
                        'path': full_path
                    })

    res.sort(key=lambda x: (x['variant'].lower(), x['name'].lower()))
    print(json.dumps(res), flush=True)

if __name__ == '__main__':
    scan_wallpapers()
