#!/usr/bin/env python3
import subprocess
import json
import sys

def parse_audio_devices():
    sinks = []
    sources = []
    curr = None

    try:
        out = subprocess.check_output(
            ['wpctl', 'status'],
            text=True,
            stderr=subprocess.DEVNULL,
            timeout=2.0
        )

        for line in out.splitlines():
            if 'Video' in line:
                break
            if 'Sinks:' in line:
                curr = 'sinks'
                continue
            elif 'Sources:' in line:
                curr = 'sources'
                continue
            elif any(k in line for k in ['Filters:', 'Streams:', 'Devices:']):
                curr = None
                continue

            if curr and any(char in line for char in ['│', '├', '└']):
                clean = line.replace('│', '').replace('├', '').replace('└', '').replace('─', '').strip()
                if clean:
                    is_active = '*' in clean
                    clean = clean.replace('*', '').strip()
                    parts = clean.split('.', 1)
                    if len(parts) == 2:
                        dev_id = parts[0].strip()
                        name = parts[1].split('[vol:')[0].strip()
                        if dev_id.isdigit():
                            device_info = {
                                'id': dev_id,
                                'name': name,
                                'isActive': is_active
                            }
                            if curr == 'sinks':
                                sinks.append(device_info)
                            else:
                                sources.append(device_info)

    except Exception:
        pass

    print(json.dumps({'sinks': sinks, 'sources': sources}), flush=True)

if __name__ == '__main__':
    parse_audio_devices()
