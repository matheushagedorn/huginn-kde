#!/usr/bin/env python3
import sys
import json
import os

CONFIG_PATH = os.path.expanduser("~/.config/quickshell_user_pinned.json")

def main():
    if len(sys.argv) > 1:
        try:
            raw = sys.argv[1]
            data = json.loads(raw)
            os.makedirs(os.path.dirname(CONFIG_PATH), exist_ok=True)
            with open(CONFIG_PATH, "w") as f:
                json.dump(data, f, indent=2)
            print("Successfully saved pinned apps", flush=True)
        except Exception as e:
            print(f"Error saving pinned apps: {e}", file=sys.stderr, flush=True)

if __name__ == "__main__":
    main()
