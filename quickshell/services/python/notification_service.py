#!/usr/bin/env python3
import subprocess
import time
import json
import sys

def monitor_notifications():
    try:
        proc = subprocess.Popen(
            [
                'dbus-monitor',
                "type='method_call',interface='org.freedesktop.Notifications',member='Notify'"
            ],
            stdout=subprocess.PIPE,
            text=True
        )

        app = ''
        summary = ''
        body = ''
        icon = ''
        state = 0

        for line in proc.stdout:
            line = line.strip()
            if 'member=Notify' in line:
                app = summary = body = icon = ''
                state = 1
                continue
            if state == 1 and line.startswith('string "'):
                app = line[8:-1]
                state = 2
            elif state == 2 and line.startswith('string "'):
                icon = line[8:-1]
                state = 3
            elif state == 3 and line.startswith('string "'):
                summary = line[8:-1]
                state = 4
            elif state == 4 and line.startswith('string "'):
                body = line[8:-1]
                state = 0
                d = time.strftime('%H:%M')
                obj = {
                    'id': str(time.time()),
                    'app': app or 'System',
                    'summary': summary,
                    'body': body,
                    'icon': icon,
                    'time': d
                }
                print(json.dumps(obj), flush=True)

    except Exception:
        sys.exit(1)

if __name__ == '__main__':
    monitor_notifications()
