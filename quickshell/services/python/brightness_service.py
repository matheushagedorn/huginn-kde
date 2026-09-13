#!/usr/bin/env python3
import subprocess
import re
import json
import sys

def scan_brightness_devices():
    devices = []

    # 1. DDC/CI External Monitors
    try:
        out = subprocess.check_output(
            ['ddcutil', 'detect', '--sleep-multiplier=0.1'],
            text=True,
            stderr=subprocess.DEVNULL,
            timeout=1.0
        )
        curr_disp = None
        for line in out.splitlines():
            if line.startswith('Display '):
                parts = line.split()
                if len(parts) >= 2:
                    curr_disp = parts[1].strip()
            elif 'Model:' in line and curr_disp:
                model = line.split('Model:', 1)[1].strip()
                try:
                    b_out = subprocess.check_output(
                        ['ddcutil', 'getvcp', '10', '--display', curr_disp, '--sleep-multiplier=0.1'],
                        text=True,
                        stderr=subprocess.DEVNULL,
                        timeout=1.0
                    )
                    m = re.search(r'current value =\s*(\d+)', b_out)
                    val = int(m.group(1)) if m else 100
                    devices.append({
                        'id': 'ddc_' + curr_disp,
                        'type': 'ddc',
                        'display_num': curr_disp,
                        'name': 'External (' + model + ')',
                        'brightness': val
                    })
                except Exception:
                    pass
                curr_disp = None
    except Exception:
        pass

    # 2. Built-in Display Backlights
    try:
        out = subprocess.check_output(
            ['brightnessctl', '--class=backlight', '--list'],
            text=True,
            stderr=subprocess.DEVNULL,
            timeout=2.0
        )
        for line in out.splitlines():
            if 'Device' in line and 'of class' in line:
                dev_id = line.split("'")[1]
                if dev_id != 'nvidia_0':
                    try:
                        g = float(subprocess.check_output(['brightnessctl', '--device=' + dev_id, 'g'], text=True).strip())
                        m = float(subprocess.check_output(['brightnessctl', '--device=' + dev_id, 'm'], text=True).strip())
                        val = int(round((g / m) * 100)) if m > 0 else 100
                        devices.append({
                            'id': 'sys_' + dev_id,
                            'type': 'sys',
                            'dev_name': dev_id,
                            'name': 'Built-in Display',
                            'brightness': val
                        })
                    except Exception:
                        pass
    except Exception:
        pass

    # 3. Keyboard Backlights
    try:
        out = subprocess.check_output(
            ['brightnessctl', '--class=leds', '--list'],
            text=True,
            stderr=subprocess.DEVNULL,
            timeout=2.0
        )
        for line in out.splitlines():
            if 'Device' in line and 'kbd' in line:
                dev_id = line.split("'")[1]
                try:
                    g = float(subprocess.check_output(['brightnessctl', '--device=' + dev_id, 'g'], text=True).strip())
                    m = float(subprocess.check_output(['brightnessctl', '--device=' + dev_id, 'm'], text=True).strip())
                    val = int(round((g / m) * 100)) if m > 0 else 100
                    devices.append({
                        'id': 'kbd_' + dev_id,
                        'type': 'kbd',
                        'dev_name': dev_id,
                        'name': 'Keyboard Backlight',
                        'brightness': val
                    })
                except Exception:
                    pass
    except Exception:
        pass

    print(json.dumps(devices), flush=True)

if __name__ == '__main__':
    scan_brightness_devices()
