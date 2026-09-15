#!/usr/bin/env python3
# Writes the launcher state atomically: a half-written file here would cost
# the user their favourites and usage ranking on the next start.
import json
import os
import sys
import tempfile

STATE_PATH = os.path.expanduser('~/.config/huginn_launcher_state.json')

def main():
    if len(sys.argv) < 2:
        return
    try:
        data = json.loads(sys.argv[1])
    except Exception as e:
        print(f'Error parsing launcher state: {e}', file=sys.stderr, flush=True)
        return
    try:
        os.makedirs(os.path.dirname(STATE_PATH), exist_ok=True)
        fd, tmp = tempfile.mkstemp(dir=os.path.dirname(STATE_PATH), prefix='.huginn_launcher_state.')
        with os.fdopen(fd, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2)
        os.replace(tmp, STATE_PATH)
    except Exception as e:
        print(f'Error saving launcher state: {e}', file=sys.stderr, flush=True)

if __name__ == '__main__':
    main()
