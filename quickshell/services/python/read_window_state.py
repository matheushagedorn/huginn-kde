#!/usr/bin/env python3
import json
import os
import sys

def read_state():
    act_file = '/tmp/quickshell_active_app.txt'
    win_file = '/tmp/quickshell_open_windows.json'
    fs_file = '/tmp/quickshell_is_fullscreen.txt'

    act = ''
    if os.path.exists(act_file):
        try:
            with open(act_file, 'r', encoding='utf-8') as f:
                act = f.read().strip()
        except Exception:
            pass

    is_fs = False
    if os.path.exists(fs_file):
        try:
            with open(fs_file, 'r', encoding='utf-8') as f:
                is_fs = (f.read().strip() == '1')
        except Exception:
            pass

    wins = []
    if os.path.exists(win_file):
        try:
            with open(win_file, 'r', encoding='utf-8') as f:
                wins = json.load(f)
        except Exception:
            pass

    print(json.dumps({'active': act, 'open': wins, 'fullscreen': is_fs}), flush=True)

if __name__ == '__main__':
    read_state()
