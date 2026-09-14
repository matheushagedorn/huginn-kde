#!/usr/bin/env python3
# Launcher-side user state: which apps were favourited and how often each one
# was launched. Kept apart from the dock's pinned list on purpose: favouriting
# in the launcher and pinning to the dock are two different decisions.
import json
import os

STATE_PATH = os.path.expanduser('~/.config/huginn_launcher_state.json')

def read_state():
    if os.path.exists(STATE_PATH):
        try:
            with open(STATE_PATH, 'r', encoding='utf-8') as f:
                data = json.load(f)
            if isinstance(data, dict):
                print(json.dumps({
                    'favorites': data.get('favorites', []),
                    'usage': data.get('usage', {}),
                    'recent': data.get('recent', [])
                }), flush=True)
                return
        except Exception:
            pass
    print(json.dumps({'favorites': [], 'usage': {}, 'recent': []}), flush=True)

if __name__ == '__main__':
    read_state()
