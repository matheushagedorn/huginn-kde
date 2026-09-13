#!/usr/bin/env python3
import time
import signal
import sys
import subprocess

def run_inhibitor():
    try:
        import dbus
        bus = dbus.SessionBus()
        obj = bus.get_object('org.freedesktop.Notifications', '/org/freedesktop/Notifications')
        iface = dbus.Interface(obj, 'org.freedesktop.Notifications')
        cookie = iface.Inhibit('quickshell', 'Do Not Disturb', {})

        def stop(sig, frame):
            try:
                iface.UnInhibit(cookie)
            except Exception:
                pass
            sys.exit(0)

        signal.signal(signal.SIGTERM, stop)
        signal.signal(signal.SIGINT, stop)

        while True:
            time.sleep(3600)
    except Exception:
        sys.exit(1)

if __name__ == '__main__':
    run_inhibitor()
