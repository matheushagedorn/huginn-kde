#!/usr/bin/env python3
import sys
import os
import json
import subprocess

JS_TEMPLATE_PATH = os.path.expanduser('~/.config/quickshell/services/js/update_icon_geometries.js')

def update_geometries(geom_json_str):
    try:
        with open(JS_TEMPLATE_PATH, 'r', encoding='utf-8') as f:
            template = f.read()

        script = template.replace('%ICON_MAP_JSON%', geom_json_str)
        
        target_js = '/tmp/kwin_update_geometries.js'
        with open(target_js, 'w', encoding='utf-8') as f:
            f.write(script)

        res = subprocess.check_output(
            ['busctl', '--user', 'call', 'org.kde.KWin', '/Scripting', 'org.kde.kwin.Scripting', 'loadScript', 's', target_js],
            text=True, stderr=subprocess.DEVNULL
        )
        sid = res.strip().split()[-1]
        subprocess.check_output(['busctl', '--user', 'call', 'org.kde.KWin', f'/Scripting/Script{sid}', 'org.kde.kwin.Script', 'run'], text=True, stderr=subprocess.DEVNULL)
        subprocess.check_output(['busctl', '--user', 'call', 'org.kde.KWin', f'/Scripting/Script{sid}', 'org.kde.kwin.Script', 'stop'], text=True, stderr=subprocess.DEVNULL)
    except Exception:
        pass

if __name__ == '__main__':
    if len(sys.argv) >= 2:
        geom_json_str = sys.argv[1]
        update_geometries(geom_json_str)
