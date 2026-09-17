#!/usr/bin/env python3
"""Publish the dock's icon rectangles for the minimize animation.

This used to load a KWin script that called win.setMinimizeIconGeometry().
None of it ever ran: that method does not exist in KWin 6's scripting API,
Qt.rect is undefined in that context, and Window::iconGeometry is read-only.
On Wayland the rectangles can only reach KWin through
org_kde_plasma_window_management, which minimize_geometry_service.py speaks.

So the dock writes them here and that service picks them up. The write is
atomic because the service watches the file's timestamp and would otherwise
read a half-written map.
"""
import json
import os
import sys

CACHE_DIR = os.path.expanduser('~/.cache/huginn')
ICON_MAP_PATH = os.path.join(CACHE_DIR, 'icon_geometry.json')


def update_geometries(geom_json_str):
    try:
        # Parsed and re-serialised so a broken map never reaches the service.
        data = json.loads(geom_json_str)
        os.makedirs(CACHE_DIR, exist_ok=True)
        tmp_path = ICON_MAP_PATH + '.tmp'
        with open(tmp_path, 'w', encoding='utf-8') as f:
            json.dump(data, f)
        os.replace(tmp_path, ICON_MAP_PATH)
    except Exception:
        pass


if __name__ == '__main__':
    if len(sys.argv) >= 2:
        update_geometries(sys.argv[1])
