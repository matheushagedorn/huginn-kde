#!/usr/bin/env python3
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import icon_metrics
import icon_theme

def read_pinned():
    user_file = os.path.expanduser('~/.config/huginn_user_pinned.json')
    template_file = os.path.expanduser('~/.config/huginn/config/pinned_apps.json')

    target = user_file if os.path.exists(user_file) else template_file

    if os.path.exists(target):
        try:
            with open(target, 'r', encoding='utf-8') as f:
                data = json.load(f)

            # The icon path was captured when the app was pinned, so a pin made
            # before the icon rules existed keeps whatever was right back then.
            # Resolving on read means an old pin picks up the themed icon and
            # the optical size without the user having to unpin and pin again.
            if isinstance(data, list):
                for app in data:
                    if not isinstance(app, dict):
                        continue
                    icon = icon_theme.prefer_themed(app.get('icon', ''), app.get('name', ''))
                    app['icon'] = icon
                    app['iconScale'] = icon_metrics.optical_scale(icon)
                icon_metrics.save_cache()

            print(json.dumps(data), flush=True)
            return
        except Exception:
            pass
    print('DEFAULT', flush=True)

if __name__ == '__main__':
    read_pinned()
