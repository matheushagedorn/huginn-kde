#!/usr/bin/env python3
import subprocess
import json
import sys

def scan_storage():
    devices = []
    try:
        out = subprocess.check_output(
            ['lsblk', '-J', '-o', 'NAME,LABEL,SIZE,TYPE,MOUNTPOINTS,RM,HOTPLUG,VENDOR,MODEL'],
            text=True,
            stderr=subprocess.DEVNULL,
            timeout=2.0
        )
        data = json.loads(out)

        def process_node(node, parent_vendor='', parent_model=''):
            vendor = (node.get('vendor') or parent_vendor or '').strip()
            model = (node.get('model') or parent_model or '').strip()
            dev_type = node.get('type')
            rm = node.get('rm', False)
            hotplug = node.get('hotplug', False)
            name = node.get('name', '')
            size = node.get('size', '')
            label = node.get('label') or name
            mountpoints = node.get('mountpoints') or []

            if dev_type == 'part' or (dev_type == 'disk' and not node.get('children')):
                if size != '0B' and (rm or hotplug or name.startswith('sd')):
                    dev_path = '/dev/' + name
                    mp = [m for m in mountpoints if m]
                    is_mounted = len(mp) > 0
                    vendor_model = (vendor + ' ' + model).strip() or 'External Drive'
                    
                    devices.append({
                        'dev': dev_path,
                        'label': label,
                        'vendor': vendor_model,
                        'size': size,
                        'isMounted': is_mounted,
                        'mountpoint': mp[0] if is_mounted else ''
                    })

            for child in node.get('children', []):
                process_node(child, vendor, model)

        for dev in data.get('blockdevices', []):
            process_node(dev)

    except Exception:
        pass

    print(json.dumps(devices), flush=True)

if __name__ == '__main__':
    scan_storage()
