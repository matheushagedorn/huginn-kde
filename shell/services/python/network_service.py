#!/usr/bin/env python3
import subprocess
import json
import sys

def get_net_status():
    res = {
        'wifiPowered': True,
        'hasEthernet': False,
        'ethernetConnected': False,
        'isConnected': False,
        'connectedSsid': '',
        'signalPercent': 100,
        'networks': []
    }
    
    # 1. Wi-Fi Power Radio State
    try:
        rad = subprocess.check_output(['nmcli', 'radio', 'wifi'], text=True, stderr=subprocess.DEVNULL, timeout=2.0).strip()
        res['wifiPowered'] = (rad == 'enabled')
    except Exception:
        pass

    # 2. Instant Device Connection Status (authoritative - never drops while connected!)
    try:
        devs = subprocess.check_output(['nmcli', '-t', '-f', 'TYPE,STATE,CONNECTION', 'dev'], text=True, stderr=subprocess.DEVNULL, timeout=2.0)
        for line in devs.splitlines():
            parts = line.split(':')
            if len(parts) >= 2:
                dev_type = parts[0].strip()
                dev_state = parts[1].strip()
                conn_name = parts[2].strip() if len(parts) >= 3 else ''
                
                if dev_type == 'ethernet':
                    res['hasEthernet'] = True
                    if dev_state == 'connected':
                        res['ethernetConnected'] = True
                        res['isConnected'] = True
                elif dev_type == 'wifi':
                    if dev_state == 'connected':
                        res['isConnected'] = True
                        if conn_name:
                            res['connectedSsid'] = conn_name
    except Exception:
        pass

    # 3. Wi-Fi Scan & Signal Percent (only if wifi is powered)
    if res['wifiPowered']:
        try:
            out = subprocess.check_output(['nmcli', '-t', '-f', 'IN-USE,SSID,SIGNAL,SECURITY', 'dev', 'wifi'], text=True, stderr=subprocess.DEVNULL, timeout=3.0)
            seen = set()
            for line in out.splitlines():
                parts = line.split(':')
                if len(parts) >= 3:
                    in_use = parts[0].strip() == '*'
                    ssid = parts[1].strip()
                    signal = parts[2].strip()
                    sec = parts[3].strip() if len(parts) >= 4 else ''
                    if ssid and ssid not in seen:
                        seen.add(ssid)
                        res['networks'].append({'ssid': ssid, 'signal': signal, 'security': sec, 'inUse': in_use})
                        if in_use:
                            res['isConnected'] = True
                            if not res['connectedSsid']:
                                res['connectedSsid'] = ssid
                            try:
                                res['signalPercent'] = int(signal)
                            except Exception:
                                res['signalPercent'] = 100
        except Exception:
            pass

    return res

if __name__ == '__main__':
    print(json.dumps(get_net_status()), flush=True)
