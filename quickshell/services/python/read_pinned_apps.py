#!/usr/bin/env python3
import json
import os
import sys

def read_pinned():
    user_file = os.path.expanduser('~/.config/quickshell_user_pinned.json')
    template_file = os.path.expanduser('~/.config/quickshell/config/pinned_apps.json')

    target = user_file if os.path.exists(user_file) else template_file

    if os.path.exists(target):
        try:
            with open(target, 'r', encoding='utf-8') as f:
                data = json.load(f)
                print(json.dumps(data), flush=True)
                return
        except Exception:
            pass
    print('DEFAULT', flush=True)

if __name__ == '__main__':
    read_pinned()
