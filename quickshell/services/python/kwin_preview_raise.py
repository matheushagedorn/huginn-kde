#!/usr/bin/env python3
import sys
import os
import dbus

JS_TEMPLATE_PATH = os.path.expanduser('~/.config/quickshell/services/js/kwin_preview_raise.js')

def preview_raise(target_id="", app_name=""):
    if not target_id and not app_name:
        return
    try:
        if not os.path.exists(JS_TEMPLATE_PATH):
            return

        with open(JS_TEMPLATE_PATH, 'r', encoding='utf-8') as f:
            template = f.read()

        script = (template
                  .replace('%TARGET_ID%', target_id.replace('"', '\\"'))
                  .replace('%APP_NAME%', app_name.replace('"', '\\"')))
        
        target_js = '/tmp/kwin_preview_raise.js'
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
        if sid is not None and int(sid) >= 0:
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
    except Exception:
        pass

if __name__ == '__main__':
    target_id = sys.argv[1] if len(sys.argv) >= 2 else ""
    app_name = sys.argv[2] if len(sys.argv) >= 3 else ""
    preview_raise(target_id, app_name)
