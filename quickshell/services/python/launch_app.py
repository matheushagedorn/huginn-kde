#!/usr/bin/env python3
import sys
import os
import getpass
import subprocess
import shutil
import re
import shlex

def clean_field_codes(cmd):
    if not cmd:
        return ""
    # Strip Desktop entry field codes (%u, %U, %f, %F, %i, %c, %k, etc.)
    return re.sub(r'%[a-zA-Z]', '', cmd).strip()

def get_nixos_env_path():
    # Falls back to the real account name instead of a hardcoded one: the
    # upstream default was the original author's username, which silently
    # built paths for a user that does not exist here.
    user_name = os.environ.get('USER') or getpass.getuser()
    env_path = os.environ.get("PATH", "")
    extra = [
        f"/etc/profiles/per-user/{user_name}/bin",
        os.path.expanduser("~/.nix-profile/bin"),
        "/run/current-system/sw/bin",
        os.path.expanduser("~/.local/bin"),
        "/usr/local/bin",
        "/usr/bin",
        "/bin",
        "/var/lib/flatpak/exports/bin",
        os.path.expanduser("~/.local/share/flatpak/exports/bin")
    ]
    path_dirs = env_path.split(':')
    for p in extra:
        if p and p not in path_dirs:
            path_dirs.insert(0, p)
    return ":".join(path_dirs)

def get_desktop_dirs():
    # Falls back to the real account name instead of a hardcoded one: the
    # upstream default was the original author's username, which silently
    # built paths for a user that does not exist here.
    user_name = os.environ.get('USER') or getpass.getuser()
    dirs = [
        os.path.expanduser('~/.local/share/applications'),
        os.path.expanduser('~/.nix-profile/share/applications'),
        f'/etc/profiles/per-user/{user_name}/share/applications',
        '/run/current-system/sw/share/applications',
        os.path.expanduser('~/.local/share/flatpak/exports/share/applications'),
        '/var/lib/flatpak/exports/share/applications',
        '/usr/local/share/applications',
        '/usr/share/applications'
    ]
    xdg = os.environ.get('XDG_DATA_DIRS', '')
    if xdg:
        for x in xdg.split(':'):
            if x:
                p = os.path.join(x, 'applications')
                if p not in dirs:
                    dirs.append(p)
    return [d for d in dirs if os.path.exists(d)]

KNOWN_MAPPINGS = {
    "org.kde.dolphin": ["dolphin"],
    "org.kde.kate": ["kate"],
    "org.kde.kwrite": ["kwrite"],
    "org.kde.konsole": ["konsole"],
    "org.kde.systemsettings": ["systemsettings"],
    "com.visualstudio.code": ["antigravity-ide", "code", "codium", "vscode"],
    "code": ["antigravity-ide", "code", "codium", "vscode"],
    "com.heroicgameslauncher.hgl": ["heroic"],
    "com.obsproject.studio": ["obs"],
    "io.github.jeffvli.feishin": ["feishin"],
    "net.lutris.lutris": ["lutris"],
    "io.github.zen_browser.zen": ["zen", "zen-browser"],
    "app.zen_browser.zen": ["zen", "zen-browser"],
    "zen-alpha": ["zen", "zen-browser"],
    "org.mozilla.firefox": ["firefox"],
    "com.spotify.client": ["spotify"],
    "equibop": ["equibop"],
    "webcord": ["webcord"],
    "discord": ["discord", "equibop", "webcord"],
    "org.kde.alacritty": ["alacritty"]
}

def parse_exec_from_desktop(filepath):
    try:
        in_desktop = False
        with open(filepath, 'r', encoding='utf-8', errors='ignore') as fp:
            for line in fp:
                line = line.strip()
                if line.startswith('['):
                    in_desktop = (line == '[Desktop Entry]')
                    continue
                if in_desktop and line.startswith('Exec='):
                    raw_exec = line.split('=', 1)[1].strip()
                    return clean_field_codes(raw_exec)
    except Exception:
        pass
    return None

def resolve_desktop_entry(query, desktop_dirs):
    clean_q = query.strip().lower()
    if clean_q.endswith('.desktop'):
        clean_q = clean_q[:-8]

    # Search strategy 1: Direct filename match
    for d in desktop_dirs:
        for ext in [f"{clean_q}.desktop", f"{query}.desktop"]:
            p = os.path.join(d, ext)
            if os.path.exists(p):
                exec_cmd = parse_exec_from_desktop(p)
                return p, exec_cmd

    # Search strategy 2: Stem or subcomponent match
    for d in desktop_dirs:
        try:
            for fname in os.listdir(d):
                if not fname.endswith('.desktop'):
                    continue
                stem = fname[:-8].lower()
                if stem == clean_q or stem.endswith('.' + clean_q) or clean_q.endswith('.' + stem):
                    p = os.path.join(d, fname)
                    exec_cmd = parse_exec_from_desktop(p)
                    return p, exec_cmd
        except Exception:
            pass

    return None, None

def exec_fast(args_list, run_env):
    """Executes command directly without shell indirection or D-Bus latency for snappy launches."""
    try:
        subprocess.Popen(
            args_list,
            start_new_session=True,
            close_fds=True,
            env=run_env,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )
    except Exception:
        pass

def launch():
    if len(sys.argv) < 2:
        return
    raw_arg = sys.argv[1].strip()
    if not raw_arg:
        return

    env_path = get_nixos_env_path()
    run_env = dict(os.environ, PATH=env_path)
    clean_cmd = clean_field_codes(raw_arg)
    if not clean_cmd:
        return

    if "spectacle" in clean_cmd.lower():
        try:
            import time
            subprocess.run(["pkill", "-9", "spectacle"], capture_output=True, timeout=2)
            time.sleep(0.1)
        except Exception:
            pass

    gio_bin = shutil.which("gio", path=env_path)
    desktop_dirs = get_desktop_dirs()

    # Fast path 1: Absolute path to a .desktop file
    if os.path.isabs(clean_cmd) and os.path.exists(clean_cmd) and clean_cmd.endswith('.desktop'):
        if gio_bin:
            exec_fast([gio_bin, "launch", clean_cmd], run_env)
            sys.exit(0)
        else:
            exec_cmd = parse_exec_from_desktop(clean_cmd)
            if exec_cmd:
                clean_cmd = exec_cmd

    # Fast path 2: Try resolving Desktop ID or app name to a .desktop file
    desktop_path, desktop_exec = resolve_desktop_entry(clean_cmd, desktop_dirs)
    if desktop_path:
        if gio_bin:
            exec_fast([gio_bin, "launch", desktop_path], run_env)
            sys.exit(0)
        elif desktop_exec:
            clean_cmd = desktop_exec

    # Fast path 3: Split command string into args and check executable in PATH
    try:
        cmd_args = shlex.split(clean_cmd)
    except Exception:
        cmd_args = clean_cmd.split()

    if not cmd_args:
        return

    bin_name = cmd_args[0]
    if os.path.isabs(bin_name) or shutil.which(bin_name, path=env_path):
        exec_fast(cmd_args, run_env)
        sys.exit(0)

    # Fast path 4: Known mapping fallbacks (e.g. "org.kde.dolphin" -> "dolphin", "code" -> "antigravity-ide")
    low_bin = bin_name.lower()
    if low_bin in KNOWN_MAPPINGS:
        for alt_bin in KNOWN_MAPPINGS[low_bin]:
            if shutil.which(alt_bin, path=env_path):
                exec_fast([alt_bin] + cmd_args[1:], run_env)
                sys.exit(0)

    # Fallback to direct execution
    exec_fast(cmd_args, run_env)
    sys.exit(0)

if __name__ == '__main__':
    launch()

