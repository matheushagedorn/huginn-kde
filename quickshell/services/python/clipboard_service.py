#!/usr/bin/env python3
import subprocess
import os
import hashlib
import json
import sys

def check_clipboard():
    clip_dir = '/tmp/quickshell_clip'
    os.makedirs(clip_dir, exist_ok=True)
    items = []

    # 1. Try cliphist list if available
    try:
        res = subprocess.check_output(['cliphist', 'list'], text=True, stderr=subprocess.DEVNULL, timeout=0.5)
        lines = [l.strip() for l in res.splitlines() if l.strip()]
        img_count = 0
        for line in lines[:30]:
            parts = line.split('\t', 1)
            item_id = parts[0].strip()
            content = parts[1].strip() if len(parts) > 1 else ""

            is_image = "[image" in content.lower() or "[[ binary data" in content.lower()
            if is_image:
                if img_count >= 5:
                    continue
                img_count += 1
                try:
                    img_data = subprocess.check_output(['cliphist', 'decode', item_id], stderr=subprocess.DEVNULL, timeout=0.5)
                    if img_data:
                        h = hashlib.md5(img_data).hexdigest()
                        path = os.path.join(clip_dir, f'{h}.png')
                        if not os.path.exists(path):
                            with open(path, 'wb') as f:
                                f.write(img_data)
                        items.append({
                            'type': 'image',
                            'path': path,
                            'hash': h,
                            'size': f'{round(len(img_data) / 1024, 1)} KB'
                        })
                except Exception:
                    pass
            elif content:
                h = hashlib.md5(content.encode('utf-8')).hexdigest()
                items.append({
                    'type': 'text',
                    'content': content,
                    'hash': h,
                    'length': len(content)
                })
    except Exception:
        pass

    # 2. Fallback to direct wl-paste if cliphist returns nothing
    if not items:
        # Check text
        try:
            txt = subprocess.check_output(['wl-paste', '--no-newline'], text=True, stderr=subprocess.DEVNULL, timeout=0.5)
            if txt and txt.strip():
                h = hashlib.md5(txt.encode('utf-8')).hexdigest()
                items.append({
                    'type': 'text',
                    'content': txt,
                    'hash': h,
                    'length': len(txt)
                })
        except Exception:
            pass

        # Check image
        try:
            img_data = subprocess.check_output(['wl-paste', '--type', 'image/png'], stderr=subprocess.DEVNULL, timeout=0.5)
            if len(img_data) > 0:
                h = hashlib.md5(img_data).hexdigest()
                path = os.path.join(clip_dir, f'{h}.png')
                if not os.path.exists(path):
                    with open(path, 'wb') as f:
                        f.write(img_data)
                items.append({
                    'type': 'image',
                    'path': path,
                    'hash': h,
                    'size': f'{round(len(img_data) / 1024, 1)} KB'
                })
        except Exception:
            pass

    print(json.dumps(items), flush=True)

def wipe_clipboard():
    clip_dir = '/tmp/quickshell_clip'
    try:
        subprocess.run(['cliphist', 'wipe'], stderr=subprocess.DEVNULL, timeout=1.0)
    except Exception:
        pass
    try:
        subprocess.run(['wl-copy', '--clear'], stderr=subprocess.DEVNULL, timeout=1.0)
    except Exception:
        pass
    try:
        if os.path.exists(clip_dir):
            for f in os.listdir(clip_dir):
                fp = os.path.join(clip_dir, f)
                if os.path.isfile(fp):
                    os.remove(fp)
    except Exception:
        pass

def delete_item(query):
    if not query:
        return
    try:
        subprocess.run(['cliphist', 'delete-query', str(query)], stderr=subprocess.DEVNULL, timeout=1.0)
    except Exception:
        pass

if __name__ == '__main__':
    if len(sys.argv) > 1:
        action = sys.argv[1]
        if action == 'clear':
            wipe_clipboard()
        elif action == 'delete' and len(sys.argv) > 2:
            delete_item(sys.argv[2])
    else:
        check_clipboard()
