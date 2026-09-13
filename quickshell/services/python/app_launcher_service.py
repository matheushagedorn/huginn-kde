#!/usr/bin/env python3
import os
import getpass
import json
import configparser
import sys
import time

def get_system_theme():
    kde_cfg = os.path.expanduser('~/.config/kdeglobals')
    if os.path.exists(kde_cfg):
        cp = configparser.ConfigParser(interpolation=None)
        try:
            cp.read(kde_cfg)
            t = cp.get('Icons', 'Theme', fallback=None)
            if t:
                return t
        except Exception:
            pass

    gtk_cfg = os.path.expanduser('~/.config/gtk-3.0/settings.ini')
    if os.path.exists(gtk_cfg):
        cp = configparser.ConfigParser(interpolation=None)
        try:
            cp.read(gtk_cfg)
            t = cp.get('Settings', 'gtk-icon-theme-name', fallback=None)
            if t:
                return t
        except Exception:
            pass

    return 'hicolor'

def parse_desktop_apps():
    sys_theme = get_system_theme()
    themes_to_search = [sys_theme]
    # Falls back to the real account name instead of a hardcoded one: the
    # upstream default was the original author's username, which silently
    # built paths for a user that does not exist here.
    user_name = os.environ.get('USER') or getpass.getuser()

    bases = [
        os.path.expanduser('~/.local/share/icons'),
        os.path.expanduser('~/.nix-profile/share/icons'),
        f'/etc/profiles/per-user/{user_name}/share/icons',
        '/run/current-system/sw/share/icons',
        os.path.expanduser('~/.local/share/flatpak/exports/share/icons'),
        '/var/lib/flatpak/exports/share/icons',
        '/usr/local/share/icons',
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
                except Exception:
                    pass

    add_inherits(sys_theme)
    for fallback_theme in ['hicolor', 'breeze', 'Papirus', 'Adwaita']:
        if fallback_theme not in themes_to_search:
            themes_to_search.append(fallback_theme)

    search_dirs = []

    subdirs = [
        '1024x1024/apps', '512x512/apps', '256x256/apps', '128x128/apps', '64x64/apps', '48x48/apps', '32x32/apps', '24x24/apps', '16x16/apps',
        '64x64@2x/apps', '48x48@2x/apps', 'apps/1024', 'apps/512', 'apps/256', 'apps/128', 'apps/64', 'apps/48', 'apps/32', 'apps/scalable', 'scalable/apps', 'apps', ''
    ]

    for t in themes_to_search:
        for b in bases:
            for sd in subdirs:
                d = os.path.join(b, t, sd)
                if os.path.exists(d) and d not in search_dirs:
                    search_dirs.append(d)

    # Also add direct Flatpak export directories without subdirs
    for fp_dir in [
        os.path.expanduser('~/.local/share/flatpak/exports/share/icons/hicolor/scalable/apps'),
        os.path.expanduser('~/.local/share/flatpak/exports/share/icons/hicolor/128x128/apps'),
        os.path.expanduser('~/.local/share/flatpak/exports/share/icons/hicolor/64x64/apps'),
        '/var/lib/flatpak/exports/share/icons/hicolor/scalable/apps',
        '/var/lib/flatpak/exports/share/icons/hicolor/128x128/apps',
        '/var/lib/flatpak/exports/share/icons/hicolor/64x64/apps',
        '/usr/share/pixmaps'
    ]:
        if os.path.exists(fp_dir) and fp_dir not in search_dirs:
            search_dirs.append(fp_dir)

    EXTS = ['.svg', '.png', '.xpm']

    def resolve_fallback():
        for fallback_name in ['application-x-executable', 'preferences-system-windows', 'applications-other', 'utilities-terminal']:
            for d in search_dirs:
                for ext in EXTS:
                    p = os.path.join(d, fallback_name + ext)
                    if os.path.exists(p):
                        return p
        return ''

    fallback_path = resolve_fallback()

    def resolve_icon(name):
        if not name:
            return fallback_path
        if os.path.isabs(name) and os.path.exists(name):
            return name

        for d in search_dirs:
            for ext in EXTS:
                p = os.path.join(d, name + ext)
                if os.path.exists(p):
                    return p
                if name.endswith(ext):
                    p2 = os.path.join(d, name)
                    if os.path.exists(p2):
                        return p2

        # Check direct base directories (e.g. share/pixmaps or share/icons directly)
        for b in bases:
            if not os.path.exists(b):
                continue
            for ext in EXTS:
                p = os.path.join(b, name + ext)
                if os.path.exists(p):
                    return p
                if name.endswith(ext):
                    p2 = os.path.join(b, name)
                    if os.path.exists(p2):
                        return p2

        # Substring / Desktop ID matching fallback (essential for Flatpak icons like io.github.zen_browser.zen)
        clean_name = name.lower()
        if clean_name.endswith('.png') or clean_name.endswith('.svg') or clean_name.endswith('.xpm'):
            clean_name = os.path.splitext(clean_name)[0]

        for d in search_dirs:
            if not os.path.exists(d):
                continue
            try:
                for f in os.scandir(d):
                    fn_lower = f.name.lower()
                    if clean_name in fn_lower or fn_lower.startswith(clean_name):
                        return f.path
            except Exception:
                pass

        return fallback_path

    def parse_desktop(f):
        entry = {}
        in_desktop = False
        try:
            with open(f, 'r', encoding='utf-8', errors='ignore') as fp:
                for line in fp:
                    line = line.strip()
                    if not line or line.startswith('#'):
                        continue
                    if line.startswith('['):
                        in_desktop = (line == '[Desktop Entry]')
                        continue
                    if in_desktop and '=' in line:
                        k, v = line.split('=', 1)
                        k = k.strip()
                        if k not in entry:
                            entry[k] = v.strip()
        except Exception:
            pass
        return entry

    desktop_dirs = [
        os.path.expanduser('~/.local/share/applications'),
        os.path.expanduser('~/.nix-profile/share/applications'),
        f'/etc/profiles/per-user/{user_name}/share/applications',
        '/run/current-system/sw/share/applications',
        os.path.expanduser('~/.local/share/flatpak/exports/share/applications'),
        '/usr/local/share/applications',
        '/usr/share/applications',
        '/var/lib/flatpak/exports/share/applications'
    ]
    for xdg_dir in os.environ.get('XDG_DATA_DIRS', '').split(':'):
        if xdg_dir:
            p = os.path.join(xdg_dir, 'applications')
            if p not in desktop_dirs:
                desktop_dirs.append(p)

    import re
    def normalize_exec(cmd):
        if not cmd:
            return ""
        return re.sub(r'%[a-zA-Z]', '', cmd).strip()

    seen_ids = set()
    seen_apps = set()
    apps = []

    for d in desktop_dirs:
        if not os.path.exists(d):
            continue
        try:
            for entry in sorted(os.scandir(d), key=lambda e: e.name):
                if not entry.name.endswith('.desktop'):
                    continue

                desktop_id = entry.name
                if desktop_id in seen_ids:
                    continue

                s = parse_desktop(entry.path)
                if s.get('Type', '') != 'Application':
                    continue
                if s.get('NoDisplay', 'false').strip().lower() == 'true':
                    continue
                if s.get('Hidden', 'false').strip().lower() == 'true':
                    continue
                if s.get('Terminal', 'false').strip().lower() in ['true', '1']:
                    continue

                only_in = [x.strip().lower() for x in s.get('OnlyShowIn', '').split(';') if x.strip()]
                if only_in and not any(env in only_in for env in ['kde', 'gnome', 'nobara', 'fedora', 'ubuntu', 'wayland', 'x-cinnamon', 'pantheon', 'unity', 'xfce']):
                    continue

                name = s.get('Name', '')
                if not name:
                    continue

                exec_cmd = s.get('Exec', '')
                norm_exec = normalize_exec(exec_cmd)
                app_key = (name.strip().lower(), norm_exec.lower())

                if app_key in seen_apps:
                    continue

                seen_ids.add(desktop_id)
                seen_apps.add(app_key)

                cats = [c for c in s.get('Categories', '').split(';') if c.strip()]
                icon = resolve_icon(s.get('Icon', ''))
                apps.append({
                    'id': desktop_id,
                    'name': name,
                    'exec': exec_cmd,
                    'icon': icon,
                    'categories': cats
                })
        except Exception:
            pass

    apps.sort(key=lambda a: a['name'].lower())
    print(json.dumps({'fallback': fallback_path, 'apps': apps}), flush=True)

def watch_directory_changes():
    import select
    import ctypes

    dirs = [
        '/usr/share/applications',
        '/usr/local/share/applications',
        '/var/lib/flatpak/exports/share/applications',
        os.path.expanduser('~/.local/share/applications'),
        os.path.expanduser('~/.local/share/flatpak/exports/share/applications')
    ]

    # Initialize Linux kernel inotify for 0ms instant file creation/deletion notifications
    inotify_fd = -1
    try:
        libc = ctypes.CDLL("libc.so.6")
        inotify_init = libc.inotify_init
        inotify_add_watch = libc.inotify_add_watch
        inotify_init.restype = ctypes.c_int
        inotify_add_watch.argtypes = [ctypes.c_int, ctypes.c_char_p, ctypes.c_uint32]
        inotify_add_watch.restype = ctypes.c_int

        fd = inotify_init()
        if fd >= 0:
            # IN_CREATE | IN_DELETE | IN_MODIFY | IN_MOVED_FROM | IN_MOVED_TO | IN_ATTRIB
            mask = 0x00000100 | 0x00000200 | 0x00000002 | 0x00000040 | 0x00000080 | 0x00000004
            for d in dirs:
                if os.path.exists(d):
                    inotify_add_watch(fd, d.encode('utf-8'), mask)
            inotify_fd = fd
    except Exception:
        inotify_fd = -1

    def get_state_snapshot():
        snapshot = {}
        for d in dirs:
            if os.path.exists(d):
                try:
                    snapshot[d] = os.path.stat(d).st_mtime
                    for entry in os.scandir(d):
                        if entry.name.endswith('.desktop'):
                            try:
                                snapshot[entry.path] = entry.stat().st_mtime
                            except Exception:
                                pass
                except Exception:
                    pass
        return snapshot

    last_snapshot = get_state_snapshot()
    parse_desktop_apps()

    while True:
        try:
            read_fds = [sys.stdin]
            if inotify_fd >= 0:
                read_fds.append(inotify_fd)

            rlist, _, _ = select.select(read_fds, [], [], 0.4)
            if rlist:
                for fd in rlist:
                    if fd == sys.stdin:
                        line = sys.stdin.readline()
                        if line:
                            parse_desktop_apps()
                            last_snapshot = get_state_snapshot()
                    elif fd == inotify_fd:
                        # Flush inotify events and trigger re-parse
                        try:
                            os.read(inotify_fd, 4096)
                        except Exception: pass
                        parse_desktop_apps()
                        last_snapshot = get_state_snapshot()
                continue

            current_snapshot = get_state_snapshot()
            if current_snapshot != last_snapshot:
                last_snapshot = current_snapshot
                parse_desktop_apps()
        except Exception:
            time.sleep(0.4)

if __name__ == '__main__':
    watch_directory_changes()
