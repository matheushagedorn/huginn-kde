#!/usr/bin/env python3
import sys
import os
import getpass
import subprocess
import time

def run_spectacle():
    # 1. Always kill any existing stuck spectacle processes first to ensure DBus single-instance lock is free
    try:
        subprocess.run(["pkill", "-9", "spectacle"], capture_output=True, timeout=2)
        time.sleep(0.1)
    except Exception:
        pass

    # 2. Determine mode/arguments passed from QML
    mode = sys.argv[1] if len(sys.argv) > 1 else "gui"

    # Map options to precise Spectacle CLI arguments
    flag_map = {
        "region": ["spectacle", "-r"],
        "fullscreen": ["spectacle", "-f", "-b", "-c"],
        "window": ["spectacle", "-a", "-b", "-c"],
        "record_region": ["spectacle", "-R", "r"],
        "record_screen": ["spectacle", "-R", "s"],
        "gui": ["spectacle", "-g"]
    }

    if mode in flag_map:
        cmd = flag_map[mode]
    elif mode.startswith("-"):
        cmd = ["spectacle", mode]
    else:
        cmd = ["spectacle", "-g"]

    # For background capture modes (-b), sleep 0.25s to allow the shell's popups to close completely
    if "-b" in cmd:
        time.sleep(0.25)

    # 3. Environment setup for NixOS
    # Falls back to the real account name instead of a hardcoded one: the
    # upstream default was the original author's username, which silently
    # built paths for a user that does not exist here.
    user_name = os.environ.get('USER') or getpass.getuser()
    env_path = os.environ.get("PATH", "")
    extra = [
        f"/etc/profiles/per-user/{user_name}/bin",
        os.path.expanduser("~/.nix-profile/bin"),
        "/run/current-system/sw/bin",
        "/usr/local/bin",
        "/usr/bin"
    ]
    path_dirs = env_path.split(':')
    for p in extra:
        if p and p not in path_dirs:
            path_dirs.insert(0, p)
    run_env = dict(os.environ, PATH=":".join(path_dirs))

    # 4. Launch Spectacle detached in a clean session
    try:
        subprocess.Popen(
            cmd,
            start_new_session=True,
            close_fds=True,
            env=run_env,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )
    except Exception as e:
        print(f"[spectacle_runner error] {e}", flush=True)

if __name__ == '__main__':
    run_spectacle()
