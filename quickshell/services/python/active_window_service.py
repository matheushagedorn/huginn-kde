#!/usr/bin/env python3
import os
import getpass
import sys
import glob
import json
import time
import subprocess
import shutil
import configparser
import dbus
import dbus.service
import dbus.mainloop.glib
import signal
import atexit
from gi.repository import GLib

ACTIVE_FILE = "/tmp/huginn_active_app.txt"
OPEN_WINS_FILE = "/tmp/huginn_open_windows.json"

_icon_cache = {}

def get_icon_search_dirs():
    theme = 'hicolor'
    # Falls back to the real account name instead of a hardcoded one: the
    # upstream default was the original author's username, which silently
    # built paths for a user that does not exist here.
    user_name = os.environ.get('USER') or getpass.getuser()
    kde_cfg = os.path.expanduser('~/.config/kdeglobals')
    if os.path.exists(kde_cfg):
        cp = configparser.ConfigParser(interpolation=None)
        try:
            cp.read(kde_cfg)
            t = cp.get('Icons', 'Theme', fallback=None)
            if t: theme = t
        except Exception: pass

    bases = [
        os.path.expanduser('~/.local/share/icons'),
        os.path.expanduser('~/.nix-profile/share/icons'),
        f'/etc/profiles/per-user/{user_name}/share/icons',
        '/run/current-system/sw/share/icons',
        '/usr/share/icons'
    ]
    for xdg_dir in os.environ.get('XDG_DATA_DIRS', '').split(':'):
        if xdg_dir:
            p = os.path.join(xdg_dir, 'icons')
            if os.path.exists(p) and p not in bases:
                bases.append(p)
            pix = os.path.join(xdg_dir, 'pixmaps')
            if os.path.exists(pix) and pix not in bases:
                bases.append(pix)

    themes_to_search = [theme]
    def add_inherits(t_name):
        for base in bases:
            idx = os.path.join(base, t_name, 'index.theme')
            if os.path.exists(idx):
                cp = configparser.ConfigParser(interpolation=None)
                try:
                    cp.read(idx)
                    inh = cp.get('Icon Theme', 'Inherits', fallback='')
                    for parent in inh.split(','):
                        parent = parent.strip()
                        if parent and parent not in themes_to_search:
                            themes_to_search.append(parent)
                            add_inherits(parent)
                except Exception: pass

    add_inherits(theme)
    for fallback_theme in ['hicolor', 'breeze', 'Papirus', 'Adwaita']:
        if fallback_theme not in themes_to_search:
            themes_to_search.append(fallback_theme)

    dirs = []
    subdirs = [
        '1024x1024/apps', '512x512/apps', '256x256/apps', '128x128/apps', '64x64/apps', '48x48/apps', '32x32/apps', '24x24/apps', '16x16/apps',
        '64x64@2x/apps', '48x48@2x/apps', 'apps/1024', 'apps/512', 'apps/256', 'apps/128', 'apps/64', 'apps/48', 'apps/32', 'apps/scalable', 'scalable/apps', 'apps', ''
    ]

    for t in themes_to_search:
        for b in bases:
            for sd in subdirs:
                d = os.path.join(b, t, sd)
                if os.path.exists(d) and d not in dirs:
                    dirs.append(d)

    for b in bases:
        if os.path.exists(b) and b not in dirs:
            dirs.append(b)

    dirs.append('/usr/share/pixmaps')
    return dirs

_search_dirs = get_icon_search_dirs()

def parse_desktop(f):
    entry = {}
    in_desktop = False
    try:
        with open(f, 'r', encoding='utf-8', errors='ignore') as fp:
            for line in fp:
                line = line.strip()
                if not line or line.startswith('#'): continue
                if line.startswith('['):
                    in_desktop = (line == '[Desktop Entry]')
                    continue
                if in_desktop and '=' in line:
                    k, v = line.split('=', 1)
                    k = k.strip()
                    if k not in entry:
                        entry[k] = v.strip()
    except Exception: pass
    return entry

def get_steam_library_paths():
    paths = [
        os.path.expanduser('~/.steam/root/steamapps'),
        os.path.expanduser('~/.local/share/Steam/steamapps'),
        os.path.expanduser('~/.var/app/com.valvesoftware.Steam/data/Steam/steamapps')
    ]
    lib_vdf = os.path.expanduser('~/.local/share/Steam/steamapps/libraryfolders.vdf')
    if os.path.exists(lib_vdf):
        try:
            with open(lib_vdf, 'r', encoding='utf-8', errors='ignore') as f:
                for line in f:
                    if '"path"' in line:
                        parts = line.split('"path"')
                        if len(parts) > 1:
                            lib_path = parts[1].replace('"', '').strip()
                            sa_path = os.path.join(lib_path, 'steamapps')
                            if os.path.exists(sa_path) and sa_path not in paths:
                                paths.append(sa_path)
        except Exception:
            pass
    return paths

def resolve_game_info(app_lower):
    # Handle Steam Apps (e.g. steam_app_1245620 or steam_app_2357570 or steam_app_570)
    if 'steam_app_' in app_lower:
        parts = app_lower.split('steam_app_')
        if len(parts) > 1:
            steam_id = parts[1].split('.')[0]
            game_name = None
            game_icon = None

            # 1. Search for steam_app_<id>.desktop
            desktop_paths = glob.glob(os.path.expanduser(f'~/.local/share/applications/*{steam_id}*.desktop')) + \
                            glob.glob(f'/usr/share/applications/*{steam_id}*.desktop')
            for dp in desktop_paths:
                entry = parse_desktop(dp)
                if entry:
                    game_name = entry.get('Name')
                    game_icon = entry.get('Icon')
                    if game_name: break

            # 2. Search Steam App Manifest VDF files across all discovered Steam libraries
            if not game_name:
                vdf_paths = []
                for lib_dir in get_steam_library_paths():
                    vdf_file = os.path.join(lib_dir, f'appmanifest_{steam_id}.vdf')
                    if os.path.exists(vdf_file):
                        vdf_paths.append(vdf_file)
                for vp in vdf_paths:
                    try:
                        with open(vp, 'r', encoding='utf-8', errors='ignore') as f:
                            for line in f:
                                if '"name"' in line:
                                    game_name = line.split('"name"')[1].replace('"', '').strip()
                                    break
                    except Exception: pass

            if not game_icon:
                icon_candidates = glob.glob(os.path.expanduser(f'~/.steam/root/steam/games/*{steam_id}*.png')) + \
                                  glob.glob(os.path.expanduser(f'~/.local/share/Steam/steam/games/*{steam_id}*.png')) + \
                                  glob.glob(os.path.expanduser(f'~/.var/app/com.valvesoftware.Steam/data/Steam/steam/games/*{steam_id}*.png'))
                if icon_candidates:
                    game_icon = icon_candidates[0]
                else:
                    game_icon = "com.valvesoftware.Steam"

            if steam_id == '2357570':
                if not game_name: game_name = "Overwatch 2"
                ow_full = None
                for d in _search_dirs:
                    if not os.path.exists(d): continue
                    for ext in ['.svg', '.png']:
                        t = os.path.join(d, "overwatch" + ext)
                        if os.path.exists(t): ow_full = t; break
                        t2 = os.path.join(d, "lutris_overwatch" + ext)
                        if os.path.exists(t2): ow_full = t2; break
                    if ow_full: break
                game_icon = ow_full or "overwatch"

            if not game_name:
                game_name = f"Steam Game ({steam_id})"

            return {
                "appId": app_lower,
                "name": game_name,
                "icon": game_icon or "com.valvesoftware.Steam"
            }

    # Handle Overwatch & Battle.net games
    if 'overwatch' in app_lower:
        ow_icon = "overwatch"
        for d in _search_dirs:
            if not os.path.exists(d): continue
            for ext in ['.svg', '.png']:
                t = os.path.join(d, "overwatch" + ext)
                if os.path.exists(t):
                    ow_icon = t
                    break
        return {
            "appId": app_lower,
            "name": "Overwatch",
            "icon": ow_icon
        }

    if 'battle.net' in app_lower or 'battlenet' in app_lower:
        return {
            "appId": app_lower,
            "name": "Battle.net",
            "icon": "battle.net"
        }

    # Handle Heroic & Bottles games
    if 'heroic' in app_lower:
        return {
            "appId": app_lower,
            "name": "Heroic Games Launcher",
            "icon": "com.heroicgameslauncher.hgl"
        }

    if 'bottles' in app_lower:
        return {
            "appId": app_lower,
            "name": "Bottles Game",
            "icon": "com.usebottles.bottles"
        }

    # Handle Lutris games
    if 'lutris' in app_lower:
        lutris_desktops = glob.glob(os.path.expanduser('~/.local/share/applications/lutris-*.desktop'))
        for ld in lutris_desktops:
            entry = parse_desktop(ld)
            if entry and entry.get('Name'):
                return {
                    "appId": app_lower,
                    "name": entry.get('Name'),
                    "icon": entry.get('Icon') or "net.lutris.Lutris"
                }

    # Handle Wine / Proton / Gamescope generic titles
    if app_lower in ['wine', 'wine64', 'proton', 'gamescope'] or 'wine' in app_lower or 'proton' in app_lower or app_lower.endswith('.exe'):
        clean_name = os.path.basename(app_lower).replace('.exe', '').replace('_', ' ').title()
        return {
            "appId": app_lower,
            "name": clean_name if clean_name else "Game",
            "icon": "com.valvesoftware.Steam"
        }

    return None

_desktop_file_cache = None

def get_all_desktop_files():
    global _desktop_file_cache
    if _desktop_file_cache is None:
        _desktop_file_cache = (
            glob.glob(os.path.expanduser('~/.nix-profile/share/applications/*.desktop')) +
            glob.glob('/run/current-system/sw/share/applications/*.desktop') +
            glob.glob(os.path.expanduser('~/.local/share/applications/*.desktop')) +
            glob.glob('/usr/share/applications/*.desktop') +
            glob.glob(os.path.expanduser('~/.local/share/flatpak/exports/share/applications/*.desktop')) +
            glob.glob('/var/lib/flatpak/exports/share/applications/*.desktop')
        )
    return _desktop_file_cache

def resolve_app_info(app_id):
    if not app_id:
        return {"appId": "", "name": "Application", "icon": ""}

    app_lower = app_id.lower().strip()
    if app_lower in _icon_cache:
        return _icon_cache[app_lower]

    game_info = resolve_game_info(app_lower)
    if game_info:
        _icon_cache[app_lower] = game_info
        return game_info

    desktop_files = get_all_desktop_files()

    icon_name = None
    app_name = None

    for df in desktop_files:
        basename = os.path.basename(df).lower()
        base_no_ext = basename.replace('.desktop', '')
        if app_lower == base_no_ext:
            entry = parse_desktop(df)
            if entry:
                icon_name = entry.get('Icon')
                app_name = entry.get('Name')
                if icon_name and app_name:
                    break

    if not icon_name or not app_name:
        for df in desktop_files:
            basename = os.path.basename(df).lower()
            base_no_ext = basename.replace('.desktop', '')
            if app_lower in basename or base_no_ext in app_lower:
                entry = parse_desktop(df)
                if entry:
                    if 'Icon' in entry and not icon_name:
                        icon_name = entry['Icon']
                    if 'Name' in entry and not app_name:
                        app_name = entry['Name']
                    if icon_name and app_name:
                        break

    if not icon_name:
        icon_name = app_lower
    if not app_name:
        clean = app_lower.split('.')[-1].replace('-', ' ').replace('_', ' ')
        app_name = clean.title()

    resolved_icon_path = ""
    if os.path.isabs(icon_name) and os.path.exists(icon_name):
        resolved_icon_path = icon_name
    else:
        for d in _search_dirs:
            if not os.path.exists(d): continue
            for ext in ['.svg', '.png', '.xpm']:
                target = os.path.join(d, icon_name + ext)
                if os.path.exists(target):
                    resolved_icon_path = target
                    break
            if resolved_icon_path:
                break

    if not resolved_icon_path:
        resolved_icon_path = icon_name

    info = {
        "appId": app_lower,
        "name": app_name,
        "icon": resolved_icon_path
    }
    _icon_cache[app_lower] = info
    return info

FULLSCREEN_FILE = "/tmp/huginn_is_fullscreen.txt"

class ActiveAppService(dbus.service.Object):
    def __init__(self, bus_name):
        super().__init__(bus_name, "/ActiveApp")

    @dbus.service.method("io.quickshell.ActiveApp", in_signature="sss")
    def updateState(self, active_app, open_windows_json, is_fullscreen_str="false"):
        try:
            with open(ACTIVE_FILE, "w") as f:
                f.write(str(active_app).strip().lower())
            
            with open(FULLSCREEN_FILE, "w") as f:
                f.write("1" if str(is_fullscreen_str).strip().lower() == "true" else "0")

            raw_wins = json.loads(open_windows_json)
            enriched_wins = []
            for item in raw_wins:
                if isinstance(item, dict):
                    app_id = item.get("appId", "")
                    info = resolve_app_info(app_id)
                    enriched_wins.append({
                        "id": item.get("id", app_id),
                        "appId": app_id,
                        "name": info.get("name", app_id),
                        "icon": info.get("icon", app_id),
                        "caption": item.get("caption", info.get("name", app_id)),
                        "minimized": item.get("minimized", False),
                        "active": item.get("active", False)
                    })
                elif isinstance(item, str):
                    enriched_wins.append(resolve_app_info(item))

            with open(OPEN_WINS_FILE, "w") as f:
                f.write(json.dumps(enriched_wins))

            state_payload = {
                "active": str(active_app).strip().lower(),
                "open": enriched_wins,
                "fullscreen": (str(is_fullscreen_str).strip().lower() == "true")
            }
            print(json.dumps(state_payload), flush=True)
        except Exception:
            pass
        return True

    @dbus.service.method("io.quickshell.ActiveApp")
    def toggleLauncher(self):
        try:
            print("TOGGLE_LAUNCHER", flush=True)
        except Exception:
            pass
        return True

def cleanup_kwin_listener():
    js_path = "/tmp/kwin_state_listener.js"
    try:
        subprocess.run(
            ["busctl", "--user", "call", "org.kde.KWin", "/Scripting", "org.kde.kwin.Scripting", "unloadScript", "s", js_path],
            capture_output=True, timeout=2.0
        )
    except Exception:
        pass

def setup_kwin_listener():
    js_template = os.path.expanduser("~/.config/quickshell/services/js/kwin_state_listener.js")
    if not os.path.exists(js_template):
        script_dir = os.path.dirname(os.path.abspath(__file__))
        alt_template = os.path.join(script_dir, "..", "js", "kwin_state_listener.js")
        if os.path.exists(alt_template):
            js_template = alt_template

    js_path = "/tmp/kwin_state_listener.js"
    try:
        if os.path.exists(js_template):
            shutil.copyfile(js_template, js_path)
        
        # Unload previous script instance to prevent KWin memory leaks & duplicate listeners
        cleanup_kwin_listener()

        res = subprocess.check_output(
            ["busctl", "--user", "call", "org.kde.KWin", "/Scripting", "org.kde.kwin.Scripting", "loadScript", "s", js_path],
            text=True, stderr=subprocess.DEVNULL, timeout=3.0
        )
        sid = res.strip().split()[-1]
        subprocess.check_output(
            ["busctl", "--user", "call", "org.kde.KWin", f"/Scripting/Script{sid}", "org.kde.kwin.Script", "run"],
            text=True, stderr=subprocess.DEVNULL, timeout=3.0
        )
    except Exception:
        pass

def _on_signal(signum, frame):
    cleanup_kwin_listener()
    sys.exit(0)

def main():
    try:
        atexit.register(cleanup_kwin_listener)
        signal.signal(signal.SIGTERM, _on_signal)
        signal.signal(signal.SIGINT, _on_signal)
        if hasattr(signal, "SIGHUP"):
            signal.signal(signal.SIGHUP, _on_signal)

        if not os.path.exists(ACTIVE_FILE):
            with open(ACTIVE_FILE, "w") as f:
                f.write("")
        if not os.path.exists(OPEN_WINS_FILE):
            with open(OPEN_WINS_FILE, "w") as f:
                f.write("[]")

        dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
        bus_name = dbus.service.BusName("io.quickshell.ActiveApp", bus=dbus.SessionBus())
        service = ActiveAppService(bus_name)
        setup_kwin_listener()
        
        loop = GLib.MainLoop()
        loop.run()
    except Exception:
        cleanup_kwin_listener()
        pass


def _ensure_single_instance():
    """Replaces any older copy of this script before starting.

    These watchers are long-lived and were being started from more than one
    place, so every shell restart left the previous pair running. Seventeen
    recolor watchers all invoking papirus-folders is how the account got
    locked by faillock once already.
    """
    import glob
    me = os.path.realpath(__file__)
    mypid = os.getpid()
    for entry in glob.glob('/proc/[0-9]*/cmdline'):
        try:
            pid = int(entry.split('/')[2])
            if pid == mypid:
                continue
            argv = open(entry, 'rb').read().split(b'\0')
            if not any(os.path.realpath(a.decode('utf-8', 'replace')) == me
                       for a in argv if a):
                continue
            os.kill(pid, signal.SIGTERM)
        except Exception:
            continue


if __name__ == "__main__":
    _ensure_single_instance()
    main()
