#!/usr/bin/env python3
import time
import json
import sys
import os
import glob
import subprocess
import re

cpu_history = [10] * 30
gpu_history = [5] * 30
ram_history = [20] * 30
net_history = [0] * 30

def get_cpu_usage():
    try:
        with open('/proc/stat', 'r') as f:
            fields = [float(column) for column in f.readline().strip().split()[1:]]
        idle_time = fields[3] + fields[4]
        total_time = sum(fields)
        return idle_time, total_time
    except Exception:
        return 0, 1

def get_cpu_freq_and_cores():
    cores = os.cpu_count() or 8
    freq_str = "4.0 GHz"
    try:
        with open('/proc/cpuinfo', 'r') as f:
            for line in f:
                if 'cpu MHz' in line:
                    mhz = float(line.split(':')[1].strip())
                    freq_str = f"{mhz / 1000.0:.1f} GHz"
                    break
    except Exception:
        pass
    return freq_str, cores

_cpu_name_cache = None
def get_cpu_name():
    global _cpu_name_cache
    if _cpu_name_cache is not None:
        return _cpu_name_cache
    name = "CPU"
    try:
        with open('/proc/cpuinfo', 'r') as f:
            for line in f:
                if line.lower().startswith('model name'):
                    name = line.split(':', 1)[1].strip()
                    break
    except Exception:
        pass
    _cpu_name_cache = name
    return name

_gpu_name_cache = None
def get_gpu_name():
    global _gpu_name_cache
    if _gpu_name_cache is not None:
        return _gpu_name_cache
    name = "GPU"
    try:
        res = subprocess.check_output(
            ["nvidia-smi", "--query-gpu=name", "--format=csv,noheader"],
            text=True, stderr=subprocess.DEVNULL, timeout=2.0
        )
        line = res.strip().splitlines()[0].strip() if res.strip() else ""
        if line:
            # Encurta prefixos comuns pra caber no card ("NVIDIA GeForce RTX 5060 Ti" -> "RTX 5060 Ti")
            for prefix in ("NVIDIA GeForce ", "NVIDIA ", "AMD Radeon ", "AMD "):
                if line.startswith(prefix):
                    line = line[len(prefix):]
                    break
            name = line
    except Exception:
        pass
    _gpu_name_cache = name
    return name

_has_wifi_cache = None
def get_has_wifi():
    global _has_wifi_cache
    if _has_wifi_cache is not None:
        return _has_wifi_cache
    has_wifi = bool(glob.glob('/sys/class/net/*/wireless'))
    _has_wifi_cache = has_wifi
    return has_wifi

def get_ram_and_swap():
    mem = {}
    try:
        with open('/proc/meminfo', 'r') as f:
            for line in f:
                parts = line.split(':')
                if len(parts) == 2:
                    key = parts[0].strip()
                    val = parts[1].strip().split()[0]
                    mem[key] = int(val)
        
        total = mem.get('MemTotal', 1) / (1024 * 1024)
        available = mem.get('MemAvailable', 0) / (1024 * 1024)
        used = total - available
        ram_pct = int((used / total) * 100) if total > 0 else 0

        swap_total = mem.get('SwapTotal', 0) / (1024 * 1024)
        swap_free = mem.get('SwapFree', 0) / (1024 * 1024)
        swap_used = max(0.0, swap_total - swap_free)

        return round(used, 1), round(total, 1), ram_pct, round(swap_used, 1), round(swap_total, 1)
    except Exception:
        return 0.0, 16.0, 0, 0.0, 8.0

def get_disk_usage():
    try:
        st = os.statvfs('/')
        total = (st.f_blocks * st.f_frsize) / (1024 ** 3)
        free = (st.f_bavail * st.f_frsize) / (1024 ** 3)
        used = total - free
        percent = int((used / total) * 100) if total > 0 else 0
        return round(used, 1), round(total, 1), percent
    except Exception:
        return 0.0, 500.0, 0

_disk_name_cache = None
def get_disk_name():
    """Model of the drive holding /, the way get_cpu_name names the CPU.

    The storage card names the device it is measuring, like the CPU and GPU
    cards do. The device comes from the mount source in /proc/self/mountinfo
    rather than from st_dev: on btrfs the root filesystem reports an anonymous
    major:minor that has no entry under /sys/dev/block at all. The partition
    suffix is trimmed because the model lives on the whole drive.
    """
    global _disk_name_cache
    if _disk_name_cache is not None:
        return _disk_name_cache

    name = "Internal storage"
    try:
        source = ''
        with open('/proc/self/mountinfo', 'r') as f:
            for line in f:
                fields = line.split(' - ')
                if len(fields) < 2 or fields[0].split()[4] != '/':
                    continue
                source = fields[1].split()[1]
                break

        node = os.path.basename(source)
        candidates = [node]
        # nvme0n1p2 -> nvme0n1, sda1 -> sda
        trimmed = re.sub(r'p?\d+$', '', node)
        if trimmed and trimmed != node:
            candidates.append(trimmed)

        for disk in candidates:
            model_file = '/sys/block/%s/device/model' % disk
            if os.path.exists(model_file):
                with open(model_file, 'r') as f:
                    model = f.read().strip()
                if model:
                    name = model
                    break
    except Exception:
        pass

    _disk_name_cache = name
    return name

def get_net_io():
    rx, tx = 0, 0
    try:
        with open('/proc/net/dev', 'r') as f:
            for line in f.readlines()[2:]:
                parts = line.split()
                if len(parts) >= 10:
                    iface = parts[0].strip(':')
                    if iface != 'lo':
                        rx += int(parts[1])
                        tx += int(parts[9])
    except Exception:
        pass
    return rx, tx

def format_bytes(bytes_val):
    if bytes_val >= 1024 * 1024:
        return f"{bytes_val / (1024 * 1024):.1f} MB/s"
    elif bytes_val >= 1024:
        return f"{bytes_val / 1024:.0f} KB/s"
    return f"{bytes_val:.0f} B/s"

def get_uptime():
    try:
        with open('/proc/uptime', 'r') as f:
            up_secs = float(f.readline().split()[0])
        hours = int(up_secs // 3600)
        mins = int((up_secs % 3600) // 60)
        if hours > 0:
            return f"{hours}h {mins}m"
        return f"{mins}m"
    except Exception:
        return "0m"

def get_wifi_signal():
    if not get_has_wifi():
        return "N/A"
    try:
        if os.path.exists('/proc/net/wireless'):
            with open('/proc/net/wireless', 'r') as f:
                lines = f.readlines()
                if len(lines) > 2:
                    parts = lines[2].split()
                    link_quality = float(parts[2].rstrip('.'))
                    pct = min(100, int((link_quality / 70.0) * 100))
                    return f"{pct}%"
    except Exception:
        pass
    return "N/A"

def get_hardware_metrics():
    hw = {
        "cpu_temp": 0.0,
        "cpu_fan": 0,
        "gpu_pct": 0,
        "gpu_temp": 0.0,
        "gpu_vram_used": 0,
        "gpu_vram_total": 8188,
        "gpu_power": "20W / 78W",
        "gpu_fan": 0,
        "nvme_temp": 0.0,
        "wifi_temp": 0.0,
        "wifi_signal": get_wifi_signal()
    }

    # NVIDIA GPU metrics via nvidia-smi
    try:
        res = subprocess.check_output(
            ["nvidia-smi", "--query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total,power.draw,power.limit", "--format=csv,noheader,nounits"],
            text=True, stderr=subprocess.DEVNULL
        )
        parts = [p.strip() for p in res.strip().split(',')]
        if len(parts) >= 6:
            hw["gpu_pct"] = int(parts[0])
            hw["gpu_temp"] = float(parts[1])
            hw["gpu_vram_used"] = int(parts[2])
            hw["gpu_vram_total"] = int(parts[3])
            p_draw = float(parts[4])
            p_lim = float(parts[5])
            hw["gpu_power"] = f"{int(p_draw)}W / {int(p_lim)}W"
    except Exception:
        pass

    # Hwmon temperatures and fan speeds
    try:
        for hwmon_dir in glob.glob('/sys/class/hwmon/hwmon*'):
            name = ""
            name_file = os.path.join(hwmon_dir, 'name')
            if os.path.exists(name_file):
                with open(name_file, 'r') as f:
                    name = f.read().strip()

            if name in ['k10temp', 'coretemp', 'zenpower']:
                for temp_input in glob.glob(os.path.join(hwmon_dir, 'temp*_input')):
                    try:
                        with open(temp_input, 'r') as f:
                            val = float(f.read().strip()) / 1000.0
                            if val > hw["cpu_temp"]:
                                hw["cpu_temp"] = round(val, 1)
                    except Exception: pass

            elif name == 'nvme':
                for temp_input in glob.glob(os.path.join(hwmon_dir, 'temp1_input')):
                    try:
                        with open(temp_input, 'r') as f:
                            hw["nvme_temp"] = round(float(f.read().strip()) / 1000.0, 1)
                    except Exception: pass

            elif any(k in name for k in ['mt79', 'ath', 'iwl', 'wlan']):
                for temp_input in glob.glob(os.path.join(hwmon_dir, 'temp1_input')):
                    try:
                        with open(temp_input, 'r') as f:
                            hw["wifi_temp"] = round(float(f.read().strip()) / 1000.0, 1)
                    except Exception: pass

            elif name in ['asus', 'asus_wmi', 'asus_custom_fan_curve']:
                for fan_input in glob.glob(os.path.join(hwmon_dir, 'fan*_input')):
                    label_file = fan_input.replace('_input', '_label')
                    lbl = ""
                    if os.path.exists(label_file):
                        try:
                            with open(label_file, 'r') as f:
                                lbl = f.read().strip().lower()
                        except Exception: pass
                    try:
                        with open(fan_input, 'r') as f:
                            val = int(f.read().strip())
                            if 'cpu' in lbl or 'fan1' in fan_input:
                                hw["cpu_fan"] = val
                            elif 'gpu' in lbl or 'fan2' in fan_input:
                                hw["gpu_fan"] = val
                    except Exception: pass
    except Exception:
        pass

    return hw

def stream_stats():
    global cpu_history, gpu_history, ram_history, net_history
    prev_idle, prev_total = get_cpu_usage()
    prev_rx, prev_tx = get_net_io()
    last_time = time.time()

    while True:
        try:
            # Pause system monitoring completely when a fullscreen game or video is active
            is_fullscreen = False
            if os.path.exists('/tmp/huginn_is_fullscreen.txt'):
                try:
                    with open('/tmp/huginn_is_fullscreen.txt', 'r') as f:
                        is_fullscreen = (f.read().strip() == '1')
                except Exception: pass

            if is_fullscreen:
                time.sleep(3.0)
                continue

            time.sleep(1.5)
            now = time.time()
            dt = max(0.1, now - last_time)
            last_time = now

            idle, total = get_cpu_usage()
            diff_idle = idle - prev_idle
            diff_total = total - prev_total
            prev_idle, prev_total = idle, total

            cpu_pct = 0
            if diff_total > 0:
                cpu_pct = int(100 * (1.0 - (diff_idle / diff_total)))
            cpu_pct = max(0, min(100, cpu_pct))

            rx, tx = get_net_io()
            rx_speed = (rx - prev_rx) / dt if rx >= prev_rx else 0
            tx_speed = (tx - prev_tx) / dt if tx >= prev_tx else 0
            prev_rx, prev_tx = rx, tx

            ram_used, ram_total, ram_pct, swap_used, swap_total = get_ram_and_swap()
            swap_pct = int((swap_used / swap_total) * 100) if swap_total > 0 else 0
            disk_used, disk_total, disk_pct = get_disk_usage()
            uptime_str = get_uptime()
            cpu_freq, cpu_cores = get_cpu_freq_and_cores()
            hw = get_hardware_metrics()

            net_kbps = (rx_speed + tx_speed) / 1024.0

            # Maintain last 30 history points
            cpu_history.pop(0)
            cpu_history.append(cpu_pct)

            gpu_history.pop(0)
            gpu_history.append(hw["gpu_pct"])

            ram_history.pop(0)
            ram_history.append(ram_pct)

            net_history.pop(0)
            net_history.append(round(net_kbps, 1))

            data = {
                "cpu": cpu_pct,
                "cpu_name": get_cpu_name(),
                "cpu_temp": hw["cpu_temp"],
                "cpu_fan": hw["cpu_fan"],
                "cpu_freq": cpu_freq,
                "cpu_cores": cpu_cores,
                "cpu_history": list(cpu_history),
                "gpu_name": get_gpu_name(),
                "gpu_pct": hw["gpu_pct"],
                "gpu_temp": hw["gpu_temp"],
                "gpu_vram_used": hw["gpu_vram_used"],
                "gpu_vram_total": hw["gpu_vram_total"],
                "gpu_power": hw["gpu_power"],
                "gpu_fan": hw["gpu_fan"],
                "gpu_history": list(gpu_history),
                "nvme_temp": hw["nvme_temp"],
                "wifi_temp": hw["wifi_temp"],
                "has_wifi": get_has_wifi(),
                "wifi_signal": hw["wifi_signal"],
                "ram_used": ram_used,
                "ram_total": ram_total,
                "ram_pct": ram_pct,
                "ram_history": list(ram_history),
                "swap_used": swap_used,
                "swap_total": swap_total,
                "swap_pct": swap_pct,
                "disk_name": get_disk_name(),
                "disk_used": disk_used,
                "disk_total": disk_total,
                "disk_pct": disk_pct,
                "net_rx": format_bytes(rx_speed),
                "net_tx": format_bytes(tx_speed),
                "net_history": list(net_history),
                "uptime": uptime_str
            }
            print(json.dumps(data), flush=True)
        except Exception:
            time.sleep(1.0)

if __name__ == '__main__':
    stream_stats()
