#!/usr/bin/env python3
import sys
import os
import dbus

JS_TEMPLATE_PATH = os.path.expanduser('~/.config/huginn/services/js/kwin_focus.js')

def focus_window(app_name, ix=0, iy=0, target_id=""):
    try:
        if not os.path.exists(JS_TEMPLATE_PATH):
            return
        with open(JS_TEMPLATE_PATH, 'r', encoding='utf-8') as f:
            template = f.read()

        script = (template
                  .replace('%APP_NAME%', app_name.replace('"', '\\"'))
                  .replace('%TARGET_ID%', target_id.replace('"', '\\"'))
                  .replace('%ICON_X%', str(ix))
                  .replace('%ICON_Y%', str(iy)))
        
        target_js = f'/tmp/kwin_focus_{os.getpid()}.js'
        with open(target_js, 'w', encoding='utf-8') as f:
            f.write(script)

        bus = dbus.SessionBus()
        kwin_obj = bus.get_object('org.kde.KWin', '/Scripting')
        scripting_iface = dbus.Interface(kwin_obj, 'org.kde.kwin.Scripting')

        try:
            scripting_iface.unloadScript(target_js)
        except Exception:
            pass

        sid = scripting_iface.loadScript(target_js)
        if sid is not None:
            script_obj = bus.get_object('org.kde.KWin', f'/Scripting/Script{int(sid)}')
            script_iface = dbus.Interface(script_obj, 'org.kde.kwin.Script')
            script_iface.run()
            try:
                script_iface.stop()
            except Exception:
                pass
            try:
                scripting_iface.unloadScript(target_js)
            except Exception:
                pass

        if os.path.exists(target_js):
            try:
                os.remove(target_js)
            except Exception:
                pass
    except Exception:
        pass

if __name__ == '__main__':
    if len(sys.argv) >= 2:
        app_name = sys.argv[1]
        ix = sys.argv[2] if len(sys.argv) >= 3 else 0
        iy = sys.argv[3] if len(sys.argv) >= 4 else 0
        target_id = sys.argv[4] if len(sys.argv) >= 5 else ""
        focus_window(app_name, ix, iy, target_id)

