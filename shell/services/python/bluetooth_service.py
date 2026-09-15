#!/usr/bin/env python3
import subprocess
import json
import sys

def scan_bluetooth():
    result = {
        'powered': True,
        'hasAdapter': False,
        'connected': [],
        'available': []
    }

    # 0/1. Check for a real adapter and the rfkill power state in the same call:
    # rfkill lists nothing at all when there is no bluetooth hardware.
    try:
        rf = subprocess.check_output(
            ['rfkill', 'list', 'bluetooth'],
            text=True,
            stderr=subprocess.DEVNULL,
            timeout=1.0
        )
        result['hasAdapter'] = bool(rf.strip())
        if not result['hasAdapter']:
            print(json.dumps(result), flush=True)
            return
        if 'Soft blocked: yes' in rf or 'Hard blocked: yes' in rf:
            result['powered'] = False
            print(json.dumps(result), flush=True)
            return
    except Exception:
        pass

    # 2. Get currently connected bluetooth devices
    try:
        out = subprocess.check_output(
            ['bluetoothctl', 'devices', 'Connected'],
            text=True,
            stderr=subprocess.DEVNULL,
            timeout=1.0
        )
        for line in out.splitlines():
            parts = line.split(maxsplit=2)
            if len(parts) >= 3:
                result['connected'].append({
                    'mac': parts[1],
                    'name': parts[2],
                    'connected': True
                })
    except Exception:
        pass

    # 3. Get paired but available bluetooth devices
    try:
        out = subprocess.check_output(
            ['bluetoothctl', 'devices', 'Paired'],
            text=True,
            stderr=subprocess.DEVNULL,
            timeout=1.0
        )
        connected_macs = set(d['mac'] for d in result['connected'])
        for line in out.splitlines():
            parts = line.split(maxsplit=2)
            if len(parts) >= 3:
                mac = parts[1]
                name = parts[2]
                if mac not in connected_macs:
                    result['available'].append({
                        'mac': mac,
                        'name': name,
                        'connected': False
                    })
    except Exception:
        pass

    print(json.dumps(result), flush=True)

if __name__ == '__main__':
    scan_bluetooth()
