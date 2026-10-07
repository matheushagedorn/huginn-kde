#!/usr/bin/env python3
"""Where each window is right now, for the window overview.

The shell already hears about every window from kwin_state_listener.js, but
that stream is tuned for the dock: it leaves out a window's position (a drag
would otherwise flood it with one update per frame) and it does not say which
virtual desktop a window lives on. The overview needs both, once, at the moment
it opens: the desktop to know which windows to show, and the geometry so each
card can start from where its window really is.

KWin answers both over plain D-Bus: getWindowInfo is not one of the restricted
interfaces, so this runs as an ordinary script and not through the helper.

Usage: overview_windows.py <window uuid> [<window uuid> ...]
Prints a single JSON line:
  {"desktop": "<current desktop id>",
   "windows": [{"id", "x", "y", "width", "height", "minimized", "onDesktop"}]}
A window KWin no longer knows about is left out.
"""
import json
import sys


def read_windows(uuids):
    import dbus

    bus = dbus.SessionBus()
    kwin = dbus.Interface(bus.get_object('org.kde.KWin', '/KWin'), 'org.kde.KWin')

    current = ''
    try:
        props = dbus.Interface(bus.get_object('org.kde.KWin', '/VirtualDesktopManager'),
                               'org.freedesktop.DBus.Properties')
        current = str(props.Get('org.kde.KWin.VirtualDesktopManager', 'current'))
    except Exception:
        pass

    windows = []
    for uuid in uuids:
        try:
            info = kwin.getWindowInfo(uuid)
        except Exception:
            continue
        # An unknown uuid comes back as an empty map rather than an error.
        if not info or 'x' not in info:
            continue
        desktops = [str(d) for d in info.get('desktops', [])]
        windows.append({
            'id': uuid,
            'x': round(float(info.get('x', 0))),
            'y': round(float(info.get('y', 0))),
            'width': round(float(info.get('width', 0))),
            'height': round(float(info.get('height', 0))),
            'minimized': bool(info.get('minimized', False)),
            # No desktops at all is how KWin says "on every desktop".
            'onDesktop': not desktops or not current or current in desktops,
        })
    return {'desktop': current, 'windows': windows}


if __name__ == '__main__':
    try:
        result = read_windows(sys.argv[1:])
    except Exception as exc:
        print(f'overview_windows: {exc}', file=sys.stderr)
        result = {'desktop': '', 'windows': []}
    print(json.dumps(result), flush=True)
