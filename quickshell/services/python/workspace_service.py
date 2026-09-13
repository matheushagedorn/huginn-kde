#!/usr/bin/env python3
import sys
import subprocess
import re
import json

def get_status():
    try:
        current_uuid = subprocess.check_output(
            ["qdbus", "org.kde.KWin", "/VirtualDesktopManager", "org.kde.KWin.VirtualDesktopManager.current"],
            text=True, stderr=subprocess.DEVNULL
        ).strip()

        desktops_raw = subprocess.check_output(
            ["qdbus", "--literal", "org.kde.KWin", "/VirtualDesktopManager", "org.kde.KWin.VirtualDesktopManager.desktops"],
            text=True, stderr=subprocess.DEVNULL
        )

        matches = re.findall(r'\(uss\)\s*(\d+),\s*"([^"]+)"(?:,\s*"([^"]*)")?', desktops_raw)
        if not matches:
            return {"hasWorkspaces": False, "activeWorkspace": 0, "totalWorkspaces": 0, "workspaces": []}

        desktops = []
        active_idx = 1
        for i, item in enumerate(matches):
            idx_num = i + 1
            uuid = item[1]
            name = item[2] if len(item) > 2 and item[2] else f"Desktop {idx_num}"
            if uuid == current_uuid:
                active_idx = idx_num
            desktops.append({"index": idx_num, "name": name})

        return {
            "hasWorkspaces": len(desktops) > 0,
            "activeWorkspace": active_idx,
            "totalWorkspaces": len(desktops),
            "workspaces": desktops
        }
    except Exception:
        # Fallback check for Hyprland workspaces if running Hyprland
        try:
            hypr_out = subprocess.check_output(["hyprctl", "workspaces", "-j"], text=True, stderr=subprocess.DEVNULL)
            parsed = json.loads(hypr_out)
            if isinstance(parsed, list) and len(parsed) > 0:
                active_out = subprocess.check_output(["hyprctl", "activeworkspace", "-j"], text=True, stderr=subprocess.DEVNULL)
                active_parsed = json.loads(active_out)
                active_id = active_parsed.get("id", 1)
                
                parsed.sort(key=lambda x: x.get("id", 0))
                desktops = [{"index": w.get("id"), "name": w.get("name", str(w.get("id")))} for w in parsed]
                return {
                    "hasWorkspaces": True,
                    "activeWorkspace": active_id,
                    "totalWorkspaces": len(desktops),
                    "workspaces": desktops
                }
        except Exception:
            pass

        return {
            "hasWorkspaces": False,
            "activeWorkspace": 0,
            "totalWorkspaces": 0,
            "workspaces": []
        }

def switch_to(index):
    try:
        idx_target = int(index)
        desktops_raw = subprocess.check_output(
            ["qdbus", "--literal", "org.kde.KWin", "/VirtualDesktopManager", "org.kde.KWin.VirtualDesktopManager.desktops"],
            text=True, stderr=subprocess.DEVNULL
        )
        matches = re.findall(r'\(uss\)\s*(\d+),\s*"([^"]+)"(?:,\s*"([^"]*)")?', desktops_raw)
        if matches and 1 <= idx_target <= len(matches):
            target_uuid = matches[idx_target - 1][1]
            res = subprocess.run(
                ["qdbus", "org.kde.KWin", "/VirtualDesktopManager", "org.kde.KWin.VirtualDesktopManager.setCurrent", target_uuid],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
            )
            if res.returncode == 0:
                return
    except Exception:
        pass

    try:
        shortcut_name = f"Switch to Desktop {index}"
        res = subprocess.run(
            ["qdbus", "org.kde.kglobalaccel", "/component/kwin", "org.kde.kglobalaccel.Component.invokeShortcut", shortcut_name],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
        )
        if res.returncode != 0:
            subprocess.run(["hyprctl", "dispatch", "workspace", str(index)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        pass

if __name__ == '__main__':
    if len(sys.argv) > 1 and sys.argv[1] == 'switch':
        if len(sys.argv) > 2:
            switch_to(sys.argv[2])
    else:
        print(json.dumps(get_status()), flush=True)
