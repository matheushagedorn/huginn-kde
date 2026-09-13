#!/usr/bin/env python3
import os, sys, argparse, re

def strip_jsonc_comments(json_str):
    """Safely removes JSON single-line (//...) and block (/*...*/) comments without touching string contents (e.g. URLs)."""
    pattern = r'("(?:\\.|[^"\\])*")|/\*.*?\*/|//.*'
    def replace(match):
        if match.group(1):
            return match.group(1)
        return ''
    return re.sub(pattern, replace, json_str, flags=re.DOTALL)


def get_app_config_dirs(app_names):
    """
    Dynamically discover all config and data directories for any native or Flatpak application.
    Checks ~/.config/, ~/.local/share/, ~/.var/app/* (Flatpak sandboxes), and system paths.
    """
    if isinstance(app_names, str):
        app_names = [app_names]

    dirs = set()
    home = os.path.expanduser('~')

    for name in app_names:
        c1 = os.path.join(home, '.config', name)
        c2 = os.path.join(home, '.local', 'share', name)
        if os.path.exists(c1):
            dirs.add(c1)
        if os.path.exists(c2):
            dirs.add(c2)

    var_app = os.path.join(home, '.var', 'app')
    if os.path.exists(var_app):
        try:
            for entry in os.scandir(var_app):
                if not entry.is_dir():
                    continue
                sub_locations = [
                    os.path.join(entry.path, 'config'),
                    os.path.join(entry.path, 'data'),
                    os.path.join(entry.path, '.config'),
                    os.path.join(entry.path, '.local', 'share')
                ]
                for sub_loc in sub_locations:
                    if not os.path.exists(sub_loc):
                        continue
                    for name in app_names:
                        target = os.path.join(sub_loc, name)
                        if os.path.exists(target):
                            dirs.add(target)
                        try:
                            for item in os.scandir(sub_loc):
                                if any(n.lower() in item.name.lower() for n in app_names):
                                    dirs.add(item.path)
                        except Exception:
                            pass
        except Exception:
            pass

    return list(dirs)

def restart_app_if_running(name, search_patterns, launch_commands):
    """
    Gracefully restarts a native or Flatpak application if it is currently running.
    """
    import subprocess, time

    is_running = False
    for pat in search_patterns:
        res = subprocess.run(["pgrep", "-i", "-f", pat], capture_output=True, text=True)
        if res.returncode == 0:
            is_running = True
            break

    if not is_running:
        return

    # Gracefully terminate running instances
    for pat in search_patterns:
        subprocess.run(["pkill", "-15", "-i", "-f", pat], capture_output=True)

    # Wait for process exit & lock release buffer
    for _ in range(30):
        still_running = False
        for pat in search_patterns:
            check = subprocess.run(["pgrep", "-i", "-f", pat], capture_output=True, text=True)
            if check.returncode == 0:
                still_running = True
                break
        if not still_running:
            time.sleep(0.5)
            break
        time.sleep(0.1)

    # Launch using first available working launch command (Flatpak -> Desktop launcher -> Native binary)
    for cmd in launch_commands:
        try:
            if cmd.startswith("flatpak run"):
                app_id = cmd.split()[-1]
                check_fp = subprocess.run(["flatpak", "info", app_id], capture_output=True, text=True)
                if check_fp.returncode == 0:
                    subprocess.Popen(cmd, shell=True, start_new_session=True)
                    return
            elif cmd.startswith("gtk-launch"):
                app_id = cmd.split()[-1]
                res_gtk = subprocess.run(["gtk-launch", app_id], capture_output=True)
                if res_gtk.returncode == 0:
                    return
            else:
                bin_name = cmd.split()[0]
                res_bin = subprocess.run(f"command -v {bin_name}", capture_output=True, shell=True)
                if res_bin.returncode == 0:
                    subprocess.Popen(cmd, shell=True, start_new_session=True)
                    return
        except Exception:
            pass

    # Generic shell fallback launch
    if launch_commands:
        raw_cmd = " || ".join(launch_commands)
        subprocess.Popen(f"sh -c '{raw_cmd} &'", shell=True, start_new_session=True)

def sync_kde(bg, surface, current_line, fg, accent, sub_accent, is_dark, variant_name):
    import re, subprocess
    clean_name = re.sub(r'[^a-zA-Z0-9]', '', variant_name)
    color_scheme_dir = os.path.expanduser('~/.local/share/color-schemes')
    os.makedirs(color_scheme_dir, exist_ok=True)
    scheme_file = os.path.join(color_scheme_dir, f"{clean_name}.colors")

    def hex_to_rgb(hex_str):
        hex_str = str(hex_str).lstrip('#')
        if len(hex_str) == 3:
            hex_str = ''.join([c*2 for c in hex_str])
        try:
            return f"{int(hex_str[0:2], 16)},{int(hex_str[2:4], 16)},{int(hex_str[4:6], 16)}"
        except Exception:
            return "255,255,255"

    rgb_bg = hex_to_rgb(bg)
    rgb_fg = hex_to_rgb(fg)
    rgb_surf = hex_to_rgb(surface)
    rgb_line = hex_to_rgb(current_line)
    rgb_acc = hex_to_rgb(accent)

    kde_content = f"""[General]
Name={variant_name}
ColorScheme={clean_name}
accentColor={rgb_acc}

[WM]
activeBackground={rgb_bg}
activeBlend=255,255,255
activeForeground={rgb_fg}
inactiveBackground={rgb_surf}
inactiveBlend=255,255,255
inactiveForeground={rgb_line}

[Colors:Window]
BackgroundNormal={rgb_bg}
ForegroundNormal={rgb_fg}
BackgroundAlternate={rgb_surf}
ForegroundInactive={rgb_line}

[Colors:View]
BackgroundNormal={rgb_surf}
ForegroundNormal={rgb_fg}
BackgroundAlternate={rgb_bg}
ForegroundInactive={rgb_line}

[Colors:Button]
BackgroundNormal={rgb_surf}
ForegroundNormal={rgb_fg}
BackgroundAlternate={rgb_line}
ForegroundInactive={rgb_line}

[Colors:Selection]
BackgroundNormal={rgb_acc}
ForegroundNormal={"255,255,255" if is_dark else "0,0,0"}

[Colors:Header]
BackgroundNormal={rgb_bg}
ForegroundNormal={rgb_fg}
BackgroundAlternate={rgb_surf}

[Colors:Header:Active]
BackgroundNormal={rgb_bg}
ForegroundNormal={rgb_fg}

[Colors:Header:Inactive]
BackgroundNormal={rgb_surf}
ForegroundNormal={rgb_line}

[Colors:Tooltip]
BackgroundNormal={rgb_surf}
ForegroundNormal={rgb_fg}
"""
    try:
        with open(scheme_file, 'w', encoding='utf-8') as f:
            f.write(kde_content)
        subprocess.run(["plasma-apply-colorscheme", clean_name], capture_output=True)

        # Explicitly configure kdeglobals groups for KWin window decorations and Konsole headers
        subprocess.run(["kwriteconfig6", "--file", "kdeglobals", "--group", "General", "--key", "ColorScheme", clean_name], capture_output=True)
        subprocess.run(["kwriteconfig6", "--file", "kdeglobals", "--group", "General", "--key", "accentColor", rgb_acc], capture_output=True)
        subprocess.run(["kwriteconfig6", "--file", "kdeglobals", "--group", "WM", "--key", "activeBackground", rgb_bg], capture_output=True)
        subprocess.run(["kwriteconfig6", "--file", "kdeglobals", "--group", "WM", "--key", "activeForeground", rgb_fg], capture_output=True)
        subprocess.run(["kwriteconfig6", "--file", "kdeglobals", "--group", "WM", "--key", "inactiveBackground", rgb_surf], capture_output=True)
        subprocess.run(["kwriteconfig6", "--file", "kdeglobals", "--group", "WM", "--key", "inactiveForeground", rgb_line], capture_output=True)
        subprocess.run(["kwriteconfig6", "--file", "kdeglobals", "--group", "Colors:Header", "--key", "BackgroundNormal", rgb_bg], capture_output=True)
        subprocess.run(["kwriteconfig6", "--file", "kdeglobals", "--group", "Colors:Header", "--key", "ForegroundNormal", rgb_fg], capture_output=True)
        subprocess.run(["kwriteconfig6", "--file", "kdeglobals", "--group", "Colors:Header:Active", "--key", "BackgroundNormal", rgb_bg], capture_output=True)
        subprocess.run(["kwriteconfig6", "--file", "kdeglobals", "--group", "Colors:Header:Active", "--key", "ForegroundNormal", rgb_fg], capture_output=True)
        subprocess.run(["kwriteconfig6", "--file", "kdeglobals", "--group", "Colors:Header:Inactive", "--key", "BackgroundNormal", rgb_surf], capture_output=True)
        subprocess.run(["kwriteconfig6", "--file", "kdeglobals", "--group", "Colors:Header:Inactive", "--key", "ForegroundNormal", rgb_line], capture_output=True)
        subprocess.run(["kwriteconfig6", "--file", "kdeglobals", "--group", "Colors:Window", "--key", "BackgroundNormal", rgb_bg], capture_output=True)
        subprocess.run(["kwriteconfig6", "--file", "kdeglobals", "--group", "Colors:Window", "--key", "ForegroundNormal", rgb_fg], capture_output=True)
        subprocess.run(["qdbus", "org.kde.KWin", "/KWin", "reconfigure"], capture_output=True)
    except Exception:
        pass

    # Synchronize dynamic theme splash screen package with direct QML templating
    try:
        import getpass, pwd
        user_name = getpass.getuser()
        display_name = user_name.capitalize()
        try:
            pw = pwd.getpwnam(user_name)
            gecos = pw.pw_gecos.split(',')[0].strip()
            if gecos:
                display_name = gecos
        except Exception:
            pass

        splash_qml_content = f"""import QtQuick
import QtQuick.Layouts

Item {{
    id: root
    width: 1920
    height: 1080

    property int stage: 0

    // Dynamic Theme Colors (Auto-generated by Quickshell Theme Engine)
    property color bgColor: "{bg}"
    property color surfaceColor: "{surface}"
    property color fgColor: "{fg}"
    property color accentColor: "{accent}"
    property color subAccentColor: "{sub_accent}"
    property string themeName: "{variant_name}"
    property string userName: "{display_name}"

    // Rich Dark Background with dynamic theme color fill
    Rectangle {{
        anchors.fill: parent
        color: bgColor

        // Ambient Glow Orb 1
        Rectangle {{
            width: Math.min(root.width, root.height) * 0.7
            height: width
            radius: width / 2
            anchors.centerIn: parent
            color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.14)

            SequentialAnimation on scale {{
                loops: Animation.Infinite
                NumberAnimation {{ from: 0.85; to: 1.15; duration: 3500; easing.type: Easing.InOutQuad }}
                NumberAnimation {{ from: 1.15; to: 0.85; duration: 3500; easing.type: Easing.InOutQuad }}
            }}
        }}

        // Ambient Glow Orb 2
        Rectangle {{
            width: Math.min(root.width, root.height) * 0.5
            height: width
            radius: width / 2
            anchors.centerIn: parent
            color: Qt.rgba(subAccentColor.r, subAccentColor.g, subAccentColor.b, 0.10)

            SequentialAnimation on scale {{
                loops: Animation.Infinite
                NumberAnimation {{ from: 1.15; to: 0.85; duration: 4500; easing.type: Easing.InOutQuad }}
                NumberAnimation {{ from: 0.85; to: 1.15; duration: 4500; easing.type: Easing.InOutQuad }}
            }}
        }}
    }}

    // Center Content Card
    ColumnLayout {{
        anchors.centerIn: parent
        spacing: 24

        // Animated Pulsing Badge
        Item {{
            Layout.alignment: Qt.AlignHCenter
            width: 110
            height: 110

            // Outer Pulsing Ring
            Rectangle {{
                anchors.fill: parent
                radius: width / 2
                color: "transparent"
                border.color: accentColor
                border.width: 3
                opacity: 0.8

                SequentialAnimation on scale {{
                    loops: Animation.Infinite
                    NumberAnimation {{ from: 1.0; to: 1.3; duration: 2000; easing.type: Easing.InOutQuad }}
                    NumberAnimation {{ from: 1.3; to: 1.0; duration: 2000; easing.type: Easing.InOutQuad }}
                }}

                SequentialAnimation on opacity {{
                    loops: Animation.Infinite
                    NumberAnimation {{ from: 0.8; to: 0.15; duration: 2000; easing.type: Easing.InOutQuad }}
                    NumberAnimation {{ from: 0.15; to: 0.8; duration: 2000; easing.type: Easing.InOutQuad }}
                }}
            }}

            // Inner Glass Badge
            Rectangle {{
                anchors.centerIn: parent
                width: 82
                height: 82
                radius: 41
                color: Qt.rgba(surfaceColor.r, surfaceColor.g, surfaceColor.b, 0.85)
                border.color: Qt.rgba(fgColor.r, fgColor.g, fgColor.b, 0.2)
                border.width: 1

                Text {{
                    anchors.centerIn: parent
                    text: "❖"
                    font.pixelSize: 38
                    color: accentColor
                }}
            }}
        }}

        // Welcome User Title
        Text {{
            Layout.alignment: Qt.AlignHCenter
            text: "Welcome, " + userName
            font.pixelSize: 26
            font.bold: true
            font.family: "Outfit, Inter, Sans-Serif"
            color: fgColor
            opacity: 0.95
        }}

        // Smooth Progress Bar
        Rectangle {{
            Layout.alignment: Qt.AlignHCenter
            width: 260
            height: 6
            radius: 3
            color: Qt.rgba(surfaceColor.r, surfaceColor.g, surfaceColor.b, 0.9)
            border.color: Qt.rgba(fgColor.r, fgColor.g, fgColor.b, 0.12)
            border.width: 1
            clip: true

            Rectangle {{
                id: progressBar
                height: parent.height
                radius: 3
                color: accentColor
                width: Math.min(parent.width, Math.max(12, (Math.max(1, root.stage) / 6.0) * parent.width))

                Behavior on width {{
                    NumberAnimation {{ duration: 300; easing.type: Easing.OutCubic }}
                }}
            }}
        }}

        // Status Label
        Text {{
            Layout.alignment: Qt.AlignHCenter
            text: stage === 0 ? "Initializing Plasma..." :
                  stage === 1 ? "Loading System Services..." :
                  stage === 2 ? "Setting up Desktop..." :
                  stage === 3 ? "Loading Panels & Dock..." :
                  stage === 4 ? "Preparing Workspace..." : "Starting..."
            font.pixelSize: 13
            font.family: "Outfit, Inter, Sans-Serif"
            color: Qt.rgba(fgColor.r, fgColor.g, fgColor.b, 0.65)
        }}
    }}
}}
"""

        user_splash_dir = os.path.expanduser('~/.local/share/plasma/look-and-feel/org.quickshell.splash/contents/splash')
        os.makedirs(user_splash_dir, exist_ok=True)
        with open(os.path.join(user_splash_dir, 'Splash.qml'), 'w', encoding='utf-8') as f:
            f.write(splash_qml_content)

        meta_file = os.path.expanduser('~/.local/share/plasma/look-and-feel/org.quickshell.splash/metadata.json')
        if not os.path.exists(meta_file):
            with open(meta_file, 'w', encoding='utf-8') as f:
                f.write('''{
    "KPlugin": {
        "Authors": [{"Email": "antigravity@google.com", "Name": "QuickShell"}],
        "Description": "Dynamic theme-following splash screen for KDE Plasma 6",
        "Id": "org.quickshell.splash",
        "License": "GPLv2+",
        "Name": "QuickShell Dynamic Splash",
        "ServiceTypes": ["KPackage/Package"],
        "Version": "1.0"
    }
}''')

        repo_splash_dir = os.path.expanduser('~/.config/quickshell/splash/org.quickshell.splash/contents/splash')
        os.makedirs(repo_splash_dir, exist_ok=True)
        with open(os.path.join(repo_splash_dir, 'Splash.qml'), 'w', encoding='utf-8') as f:
            f.write(splash_qml_content)

        subprocess.run(["kwriteconfig6", "--file", "ksplashrc", "--group", "KSplash", "--key", "Theme", "org.quickshell.splash"], capture_output=True)
        subprocess.run(["kwriteconfig6", "--file", "ksplashrc", "--group", "KSplash", "--key", "Engine", "KSplashQML"], capture_output=True)
    except Exception:
        pass

def sync_gtk(bg, surface, current_line, fg, accent, is_dark):
    css_content = f"""/* Auto-generated by Quickshell Theme Engine */
@define-color window_bg_color {bg};
@define-color window_fg_color {fg};
@define-color view_bg_color {surface};
@define-color view_fg_color {fg};
@define-color headerbar_bg_color {bg};
@define-color headerbar_fg_color {fg};
@define-color card_bg_color {surface};
@define-color card_fg_color {fg};
@define-color dialog_bg_color {bg};
@define-color dialog_fg_color {fg};
@define-color popover_bg_color {surface};
@define-color popover_fg_color {fg};
@define-color accent_color {accent};
@define-color accent_bg_color {accent};
@define-color accent_fg_color {'#ffffff' if is_dark else '#000000'};
"""
    for dir_path in [os.path.expanduser('~/.config/gtk-3.0'), os.path.expanduser('~/.config/gtk-4.0')]:
        os.makedirs(dir_path, exist_ok=True)
        css_file = os.path.join(dir_path, 'gtk.css')
        with open(css_file, 'w') as f:
            f.write(css_content)

def sync_alacritty(bg, surface, current_line, fg, accent, sub_accent, is_dark=True, variant_name=""):
    import glob, os, re
    alacritty_dirs = get_app_config_dirs(['alacritty', 'Alacritty'])
    for fb in [
        os.path.expanduser('~/.config/alacritty'),
        os.path.expanduser('~/.var/app/io.github.alacritty.Alacritty/config/alacritty'),
        os.path.expanduser('~/.var/app/org.alacritty.Alacritty/config/alacritty')
    ]:
        if fb not in alacritty_dirs:
            alacritty_dirs.append(fb)

    v_lower = (variant_name or "").lower()

    if "everforest" in v_lower:
        if is_dark:
            c_red = "#e67e80"
            c_green = "#a7c080"
            c_yellow = "#dbbc7f"
            c_blue = "#7fbbb3"
            c_magenta = "#d699b6"
            c_cyan = "#83c092"
        else:
            c_red = "#f85552"
            c_green = "#8da101"
            c_yellow = "#dfa000"
            c_blue = "#3a94c5"
            c_magenta = "#df69ba"
            c_cyan = "#35a77c"

    elif "gruvbox" in v_lower:
        if is_dark:
            c_red = "#fb4934"
            c_green = "#b8bb26"
            c_yellow = "#fabd2f"
            c_blue = "#8ec07c"
            c_magenta = "#d3869b"
            c_cyan = "#7daea3"
        else:
            c_red = "#9d0006"
            c_green = "#79740e"
            c_yellow = "#b57614"
            c_blue = "#076678"
            c_magenta = "#8f3f71"
            c_cyan = "#427b58"

    elif "catppuccin" in v_lower:
        if "latte" in v_lower:
            c_red = "#d20f39"
            c_green = "#40a02b"
            c_yellow = "#df8e1d"
            c_blue = "#1e66f5"
            c_magenta = "#8839ef"
            c_cyan = "#179299"
        else:
            c_red = "#f38ba8"
            c_green = "#a6e3a1"
            c_yellow = "#f9e2af"
            c_blue = "#89b4fa"
            c_magenta = "#cba6f7"
            c_cyan = "#94e2d5"

    elif "tokyo" in v_lower:
        if "day" in v_lower:
            c_red = "#f52a65"
            c_green = "#587539"
            c_yellow = "#8c6c00"
            c_blue = "#2e7de9"
            c_magenta = "#9854f6"
            c_cyan = "#007197"
        else:
            c_red = "#f7768e"
            c_green = "#9ece6a"
            c_yellow = "#e0af68"
            c_blue = "#7aa2f7"
            c_magenta = "#bb9af7"
            c_cyan = "#7dcfff"

    elif "nord" in v_lower:
        c_red = "#bf616a"
        c_green = "#a3be8c"
        c_yellow = "#ebcb8b"
        c_blue = "#81a1c1"
        c_magenta = "#b48ead"
        c_cyan = "#88c0d0"

    elif "rosé" in v_lower or "rose" in v_lower:
        if "dawn" in v_lower:
            c_red = "#b4637a"
            c_green = "#286983"
            c_yellow = "#ea9d34"
            c_blue = "#56949f"
            c_magenta = "#907aa9"
            c_cyan = "#d7827e"
        else:
            c_red = "#eb6f92"
            c_green = "#31748f"
            c_yellow = "#f6c177"
            c_blue = "#9ccfd8"
            c_magenta = "#c4a7e7"
            c_cyan = "#ea9a97"

    elif "solarized" in v_lower:
        c_red = "#dc322f"
        c_green = "#859900"
        c_yellow = "#b58900"
        c_blue = "#268bd2"
        c_magenta = "#d33682"
        c_cyan = "#2aa198"

    elif "one" in v_lower:
        if is_dark:
            c_red = "#e06c75"
            c_green = "#98c379"
            c_yellow = "#e5c07b"
            c_blue = "#61afef"
            c_magenta = "#c678dd"
            c_cyan = "#56b6c2"
        else:
            c_red = "#e45649"
            c_green = "#50a14f"
            c_yellow = "#c18401"
            c_blue = "#4078f2"
            c_magenta = "#a626a4"
            c_cyan = "#0184bc"

    elif "monokai" in v_lower:
        c_red = "#ff6188"
        c_green = "#a9dc76"
        c_yellow = "#ffd866"
        c_blue = "#fc9867"
        c_magenta = "#ab9df2"
        c_cyan = "#78dce8"

    elif "cyberpunk" in v_lower or "emo" in v_lower:
        c_red = "#ff0055"
        c_green = "#00ff9f"
        c_yellow = "#fcee0a"
        c_blue = "#00f0ff"
        c_magenta = "#ff007f"
        c_cyan = "#00f0ff"

    elif "zoey" in v_lower:
        if "nostalgia" in v_lower:
            c_red = "#af3a03"
            c_green = "#79740e"
            c_yellow = "#b57614"
            c_blue = "#d35b80"
            c_magenta = "#8f3f71"
            c_cyan = "#427b58"
        elif is_dark:
            c_red = "#f87171"
            c_green = "#4ade80"
            c_yellow = "#facc15"
            c_blue = "#38bdf8"
            c_magenta = "#c084fc"
            c_cyan = "#38bdf8"
        else:
            c_red = "#ef4444"
            c_green = "#10b981"
            c_yellow = "#eab308"
            c_blue = "#06b6d4"
            c_magenta = "#a855f7"
            c_cyan = "#06b6d4"

    else:
        if "alucard" in v_lower:
            c_red = "#cb3a2a"
            c_green = "#14710a"
            c_yellow = "#846e15"
            c_blue = "#036a96"
            c_magenta = "#a3144d"
            c_cyan = "#036a96"
        else:
            c_red = "#ff9580"
            c_green = "#8aff80"
            c_yellow = "#ffff80"
            c_blue = accent
            c_magenta = sub_accent
            c_cyan = "#80ffea"

    def ensure_high_contrast_fg(fg_hex, is_dark_theme):
        try:
            hex_clean = str(fg_hex).lstrip('#')
            r, g, b = int(hex_clean[0:2], 16)/255.0, int(hex_clean[2:4], 16)/255.0, int(hex_clean[4:6], 16)/255.0
            max_c, min_c = max(r, g, b), min(r, g, b)
            l = (max_c + min_c) / 2.0
            if is_dark_theme and l < 0.70:
                return "#f8f8f2" if l < 0.5 else "#e2e8f0"
            elif not is_dark_theme and l > 0.35:
                return "#1e293b"
        except Exception:
            pass
        return fg_hex

    if is_dark:
        c_black_normal = bg
        c_black_bright = "#9399b2" if "catppuccin" in v_lower else ("#928374" if "gruvbox" in v_lower else ("#83c092" if "everforest" in v_lower else "#94a3b8"))
        c_white_normal = fg
        c_white_bright = "#ffffff"
    else:
        c_black_normal = fg
        c_black_bright = "#475569"
        c_white_normal = bg
        c_white_bright = "#09090b"

    colors_block = f"""[colors.primary]
background = "{bg}"
foreground = "{fg}"

[colors.cursor]
text = "{bg}"
cursor = "{accent}"

[colors.selection]
text = "{bg}"
background = "{accent}"

[colors.normal]
black   = "{c_black_normal}"
red     = "{c_red}"
green   = "{c_green}"
yellow  = "{c_yellow}"
blue    = "{c_blue}"
magenta = "{c_magenta}"
cyan    = "{c_cyan}"
white   = "{c_white_normal}"

[colors.bright]
black   = "{c_black_bright}"
red     = "{c_red}"
green   = "{c_green}"
yellow  = "{c_yellow}"
blue    = "{c_blue}"
magenta = "{c_magenta}"
cyan    = "{c_cyan}"
white   = "{c_white_bright}"
"""

    for alacritty_dir in alacritty_dirs:
        try:
            colors_file = os.path.join(alacritty_dir, 'colors.toml')
            toml_file = os.path.join(alacritty_dir, 'alacritty.toml')

            if os.path.islink(colors_file) or (os.path.exists(colors_file) and not os.access(colors_file, os.W_OK)):
                try: os.chmod(colors_file, 0o666)
                except Exception: pass
                try: os.unlink(colors_file)
                except Exception: pass

            with open(colors_file, 'w', encoding='utf-8') as f:
                f.write(colors_block)
                f.flush()
                os.fsync(f.fileno())

            if os.path.exists(toml_file):
                with open(toml_file, 'r', encoding='utf-8') as f:
                    content = f.read()

                lines = content.splitlines()
                cleaned_lines = []
                in_colors = False
                for line in lines:
                    stripped = line.strip()
                    if stripped.startswith('[colors') or stripped.startswith('[[colors'):
                        in_colors = True
                        continue
                    elif in_colors and stripped.startswith('[') and not stripped.startswith('[colors') and not stripped.startswith('[[colors'):
                        in_colors = False

                    if not in_colors:
                        cleaned_lines.append(line)

                content = '\n'.join(cleaned_lines)

                if 'colors.toml' not in content:
                    import_line = 'import = ["colors.toml"]\n'
                    if '[general]' in content:
                        content = content.replace('[general]', '[general]\n' + import_line)
                    else:
                        content = '[general]\n' + import_line + '\n' + content

                with open(toml_file, 'w', encoding='utf-8') as f:
                    f.write(content.strip() + '\n')
            else:
                with open(toml_file, 'w', encoding='utf-8') as f:
                    f.write('[general]\nimport = ["colors.toml"]\nlive_config_reload = true\n')
        except Exception:
            pass
        except Exception:
            pass

    try:
        os.utime(colors_file, None)
        if os.path.exists(toml_file):
            os.utime(toml_file, None)
    except Exception:
        pass

    # Send live OSC 10/11 color update sequences to all active pseudo-terminals
    osc_sequence = f"\033]10;{fg}\007\033]11;{bg}\007".encode('utf-8')
    for pts in glob.glob('/dev/pts/*'):
        try:
            if os.path.isabs(pts) and os.access(pts, os.W_OK):
                fd = os.open(pts, os.O_WRONLY | os.O_NOCTTY)
                os.write(fd, osc_sequence)
                os.close(fd)
        except Exception:
            pass

def sync_discord(bg, surface, current_line, fg, accent, sub_accent, is_dark):
    import json
    css_content = f"""/* Auto-generated by Quickshell Theme Engine (Catppuccin Discord Architecture) */
.visual-refresh.theme-dark, .visual-refresh .theme-dark, .theme-dark, .theme-light, :root, html, body {{
    --brand-500: {accent} !important;
    --brand-530: {accent} !important;
    --brand-560: {accent} !important;
    --brand-600: {accent} !important;
    --brand-630: {accent} !important;
    --brand-700: {accent} !important;
    --brand-experiment: {accent} !important;
    --accent-color: {accent} !important;

    --__header-bar-background: {surface} !important;
    --text-normal: {fg} !important;
    --text-default: {fg} !important;
    --text-muted: {fg} !important;
    --text-link: {accent} !important;
    --text-brand: {accent} !important;
    --text-strong: {fg} !important;
    --text-subtle: {fg} !important;
    --text-primary: {fg} !important;
    --text-secondary: {fg} !important;
    --header-primary: {fg} !important;
    --header-secondary: {fg} !important;

    --app-frame-background: {bg} !important;
    --background-secondary-alt: {surface} !important;
    --background-accent: {current_line} !important;
    --background-surface-highest: {current_line} !important;
    --background-surface-higher: {surface} !important;
    --background-surface-high: {surface} !important;
    --background-base-lowest: {bg} !important;
    --background-base-lower: {surface} !important;
    --background-base-low: {surface} !important;
    --bg-surface-raised: {surface} !important;
    --background-gradient-highest: {surface} !important;

    --home-background: {bg} !important;
    --chat-background: {bg} !important;
    --chat-background-default: {bg} !important;
    --chat-border: {bg} !important;
    --chat-text-muted: {fg} !important;

    --border-muted: {current_line} !important;
    --border-strong: {surface} !important;
    --border-normal: {bg} !important;
    --border-subtle: {bg} !important;

    --custom-channel-members-bg: {surface} !important;
    --card-background-default: {surface} !important;
    --modal-background: {surface} !important;
    --modal-footer-background: {bg} !important;

    --input-background-default: {bg} !important;
    --input-text-default: {fg} !important;
    --input-placeholder-text-default: {fg} !important;
    --background-code: {surface} !important;

    --channels-default: {fg} !important;
    --channel-icon: {fg} !important;
    --channeltextarea-background: {surface} !important;
    --icon-muted: {fg} !important;
    --icon-default: {fg} !important;
    --icon-strong: {fg} !important;
    --icon-subtle: {fg} !important;
    --icon-primary: {fg} !important;
    --icon-secondary: {fg} !important;

    --interactive-normal: {fg} !important;
    --interactive-hover: {accent} !important;
    --interactive-active: {accent} !important;
    --interactive-muted: {fg} !important;
    --interactive-icon-default: {fg} !important;
    --interactive-icon-hover: {accent} !important;
    --interactive-icon-active: {accent} !important;
    --interactive-text-default: {fg} !important;
    --interactive-text-hover: {accent} !important;
    --interactive-text-active: {accent} !important;

    --user-profile-overlay-background: {surface} !important;
}}
"""

    discord_dirs = get_app_config_dirs(['vesktop', 'Vencord', 'equibop', 'equicord', 'discord', 'Discord'])
    for fb in [
        os.path.expanduser('~/.config/vesktop'),
        os.path.expanduser('~/.config/Vencord'),
        os.path.expanduser('~/.config/equibop'),
        os.path.expanduser('~/.config/equicord'),
        os.path.expanduser('~/.config/discord'),
        os.path.expanduser('~/.var/app/dev.vencord.Vesktop/config/vesktop'),
        os.path.expanduser('~/.var/app/dev.vencord.Vesktop/config/Vencord'),
        os.path.expanduser('~/.var/app/com.discordapp.Discord/config/discord'),
        os.path.expanduser('~/.var/app/com.discordapp.Discord/config/Vencord')
    ]:
        if fb not in discord_dirs:
            discord_dirs.append(fb)

    for base_dir in discord_dirs:
        try:
            # 1. Write quickshell-theme.css to themes/ directory
            themes_dir = os.path.join(base_dir, 'themes')
            os.makedirs(themes_dir, exist_ok=True)
            for theme_filename in ['quickshell-theme.css', 'quickshell.theme.css', 'quickshell.css']:
                with open(os.path.join(themes_dir, theme_filename), 'w', encoding='utf-8') as f:
                    f.write(css_content)

            # 2. Write QuickCSS file
            for qc_path in [
                os.path.join(base_dir, 'settings', 'quickCss.css'),
                os.path.join(base_dir, 'quickCss.css')
            ]:
                os.makedirs(os.path.dirname(qc_path), exist_ok=True)
                with open(qc_path, 'w', encoding='utf-8') as f:
                    f.write(css_content)

            # 3. Enable quickshell-theme.css and QuickCSS in settings.json
            for s_path in [
                os.path.join(base_dir, 'settings', 'settings.json'),
                os.path.join(base_dir, 'settings.json')
            ]:
                try:
                    os.makedirs(os.path.dirname(s_path), exist_ok=True)
                    s_data = {}
                    if os.path.exists(s_path):
                        with open(s_path, 'r', encoding='utf-8') as f:
                            s_data = json.load(f)

                    enabled_themes = s_data.get('enabledThemes', [])
                    if not isinstance(enabled_themes, list):
                        enabled_themes = []
                    if 'quickshell-theme.css' not in enabled_themes:
                        enabled_themes.append('quickshell-theme.css')

                    s_data['enabledThemes'] = enabled_themes
                    s_data['useQuickCss'] = True

                    with open(s_path, 'w', encoding='utf-8') as f:
                        json.dump(s_data, f, indent=2)
                except Exception:
                    pass
        except Exception:
            pass

def sync_vscode(bg, surface, current_line, fg, accent, sub_accent, is_dark, variant_name="Pro"):
    import json
    v_lower = variant_name.lower()

    if "everforest" in v_lower:
        if is_dark:
            comment_color = "#859289"
            keyword_color = "#e67e80"  # Everforest Red for keywords
            function_color = "#83c092" # Everforest Aqua for functions
            type_color = "#dbbc7f"     # Everforest Yellow for types
            string_color = "#a7c080"   # Everforest Green for strings
            number_color = "#e69875"   # Everforest Orange for numbers
            operator_color = "#7fbbb3" # Everforest Blue for operators
        else:
            comment_color = "#939f91"
            keyword_color = "#f85552"  # Everforest Light Red
            function_color = "#35a77c" # Everforest Light Aqua
            type_color = "#dfa000"     # Everforest Light Yellow
            string_color = "#8da101"   # Everforest Light Green
            number_color = "#f57d26"   # Everforest Light Orange
            operator_color = "#3a94c5" # Everforest Light Blue

    elif "gruvbox" in v_lower:
        if is_dark:
            comment_color = "#928374"
            keyword_color = "#fb4934"
            function_color = "#b8bb26"
            type_color = "#fabd2f"
            string_color = "#b8bb26"
            number_color = "#d3869b"
            operator_color = "#fe8019"
        else:
            comment_color = "#928374"
            keyword_color = "#9d0006"
            function_color = "#79740e"
            type_color = "#b57614"
            string_color = "#79740e"
            number_color = "#8f3f71"
            operator_color = "#af3a03"

    elif "catppuccin" in v_lower:
        if "latte" in v_lower:
            comment_color = "#9ca0b0"
            keyword_color = "#8839ef"
            function_color = "#1e66f5"
            type_color = "#df8e1d"
            string_color = "#40a02b"
            number_color = "#fe640b"
            operator_color = "#179299"
        else:
            comment_color = "#6c7086"
            keyword_color = "#cba6f7"
            function_color = "#89b4fa"
            type_color = "#f9e2af"
            string_color = "#a6e3a1"
            number_color = "#fab387"
            operator_color = "#94e2d5"

    elif "tokyo" in v_lower:
        if "day" in v_lower:
            comment_color = "#848cb5"
            keyword_color = "#9854f6"
            function_color = "#2e7de9"
            type_color = "#007197"
            string_color = "#587539"
            number_color = "#b15c00"
            operator_color = "#7847bd"
        else:
            comment_color = "#565f89"
            keyword_color = "#bb9af7"
            function_color = "#7aa2f7"
            type_color = "#2ac3de"
            string_color = "#9ece6a"
            number_color = "#ff9e64"
            operator_color = "#89ddff"

    elif "nord" in v_lower:
        comment_color = "#4c566a" if is_dark else "#616e88"
        keyword_color = "#81a1c1"
        function_color = "#88c0d0"
        type_color = "#8fbcbb"
        string_color = "#a3be8c"
        number_color = "#b48ead"
        operator_color = "#81a1c1"

    elif "rosé" in v_lower or "rose" in v_lower:
        if "dawn" in v_lower:
            comment_color = "#9893a5"
            keyword_color = "#286983"
            function_color = "#56949f"
            type_color = "#ea9d34"
            string_color = "#cebe8d"
            number_color = "#d7827e"
            operator_color = "#907aa9"
        else:
            comment_color = "#6e6a86"
            keyword_color = "#31748f"
            function_color = "#9ccfd8"
            type_color = "#f6c177"
            string_color = "#ebbcba"
            number_color = "#eb6f92"
            operator_color = "#c4a7e7"

    elif "dracula" in v_lower or "pro" in v_lower or "blade" in v_lower or "buff" in v_lower or "cyan" in v_lower or "lincoln" in v_lower or "morpheus" in v_lower or "alucard" in v_lower:
        if "alucard" in v_lower:
            comment_color = "#635d97"
            keyword_color = "#644ac9"
            function_color = "#a3144d"
            type_color = "#036a96"
            string_color = "#14710a"
            number_color = "#a34d14"
            operator_color = "#644ac9"
        else:
            comment_color = "#7970a9"
            keyword_color = accent
            function_color = sub_accent
            type_color = "#80ffea"
            string_color = "#8aff80"
            number_color = "#ffca80"
            operator_color = sub_accent

    elif "solarized" in v_lower:
        if is_dark:
            comment_color = "#586e75"
            keyword_color = "#859900"  # Solarized Green
            function_color = "#268bd2" # Solarized Blue
            type_color = "#b58900"     # Solarized Yellow
            string_color = "#2aa198"   # Solarized Cyan
            number_color = "#d33682"   # Solarized Magenta
            operator_color = "#cb4b16" # Solarized Orange
        else:
            comment_color = "#93a1a1"
            keyword_color = "#859900"
            function_color = "#268bd2"
            type_color = "#b58900"
            string_color = "#2aa198"
            number_color = "#d33682"
            operator_color = "#cb4b16"

    elif "one" in v_lower:
        if is_dark:
            comment_color = "#5c6370"
            keyword_color = "#c678dd"  # One Dark Purple
            function_color = "#61afef" # One Dark Blue
            type_color = "#e5c07b"     # One Dark Yellow
            string_color = "#98c379"   # One Dark Green
            number_color = "#d19a66"   # One Dark Orange
            operator_color = "#56b6c2" # One Dark Cyan
        else:
            comment_color = "#a0a1a7"
            keyword_color = "#a626a4"
            function_color = "#4078f2"
            type_color = "#c18401"
            string_color = "#50a14f"
            number_color = "#986801"
            operator_color = "#0184bc"

    elif "monokai" in v_lower:
        comment_color = "#727072"
        keyword_color = "#ff6188"   # Monokai Pink/Red
        function_color = "#a9dc76"  # Monokai Green
        type_color = "#78dce8"      # Monokai Cyan
        string_color = "#ffd866"    # Monokai Yellow
        number_color = "#ab9df2"    # Monokai Purple
        operator_color = "#fc9867"  # Monokai Orange

    elif "cyberpunk" in v_lower or "emo" in v_lower:
        comment_color = "#7b52ab"
        keyword_color = "#ff007f"   # Neon Pink
        function_color = "#00f0ff"  # Neon Cyan
        type_color = "#ffff00"      # Neon Yellow
        string_color = "#00ff9f"    # Neon Green
        number_color = "#ff9900"    # Neon Orange
        operator_color = "#9d4edd"  # Purple

    elif "zoey" in v_lower:
        if "nostalgia" in v_lower:
            comment_color = "#928374"
            keyword_color = "#d85078"   # Vintage Rose
            function_color = "#8f3f71"  # Gruvbox Vintage Mauve
            type_color = "#b57614"      # Gruvbox Vintage Gold
            string_color = "#79740e"    # Gruvbox Vintage Olive Green
            number_color = "#af3a03"    # Gruvbox Vintage Terracotta
            operator_color = "#427b58"  # Gruvbox Vintage Teal
        elif is_dark:
            comment_color = "#94a3b8"
            keyword_color = "#f472b6"   # Pink
            function_color = "#c084fc"  # Purple
            type_color = "#38bdf8"      # Cyan
            string_color = "#4ade80"    # Green
            number_color = "#fbbf24"    # Yellow
            operator_color = "#f43f5e"  # Rose
        else:
            comment_color = "#9d4edd"
            keyword_color = "#ec4899"
            function_color = "#a855f7"
            type_color = "#0284c7"
            string_color = "#16a34a"
            number_color = "#ea580c"
            operator_color = "#e11d48"

    else:
        comment_color = "#7970a9" if is_dark else "#8c8c8c"
        keyword_color = accent
        function_color = sub_accent
        type_color = "#80ffea" if is_dark else "#008080"
        string_color = "#8aff80" if is_dark else "#22863a"
        number_color = "#ffca80" if is_dark else "#b08800"
        operator_color = sub_accent

    colors_dict = {
        "editor.background": bg,
        "editor.foreground": fg,
        "editor.selectionBackground": current_line,
        "editor.lineHighlightBackground": surface,
        "editorLineNumber.foreground": current_line,
        "editorLineNumber.activeForeground": accent,
        "editorCursor.foreground": accent,
        "sideBar.background": surface,
        "sideBar.foreground": fg,
        "sideBarTitle.foreground": accent,
        "sideBarSectionHeader.background": bg,
        "sideBarSectionHeader.foreground": fg,
        "activityBar.background": bg,
        "activityBar.foreground": accent,
        "activityBarBadge.background": accent,
        "activityBarBadge.foreground": bg,
        "statusBar.background": bg,
        "statusBar.foreground": fg,
        "statusBarItem.remoteBackground": accent,
        "titleBar.activeBackground": bg,
        "titleBar.activeForeground": fg,
        "tab.activeBackground": surface,
        "tab.activeForeground": fg,
        "tab.inactiveBackground": bg,
        "tab.inactiveForeground": current_line,
        "tab.activeBorder": accent,
        "panel.background": surface,
        "panelTitle.activeBorder": accent,
        "terminal.background": bg,
        "terminal.foreground": fg,

        "list.activeSelectionBackground": current_line,
        "list.activeSelectionForeground": fg,
        "list.inactiveSelectionBackground": surface,
        "list.inactiveSelectionForeground": fg,
        "list.focusBackground": current_line,
        "list.focusForeground": fg,
        "list.hoverBackground": current_line,
        "list.hoverForeground": fg,
        "list.highlightForeground": accent,
        "list.focusHighlightForeground": sub_accent,

        "editorSuggestWidget.background": surface,
        "editorSuggestWidget.border": current_line,
        "editorSuggestWidget.foreground": fg,
        "editorSuggestWidget.selectedBackground": current_line,
        "editorSuggestWidget.selectedForeground": fg,
        "editorSuggestWidget.highlightForeground": accent,
        "editorSuggestWidget.focusHighlightForeground": sub_accent,
        "editorSuggestWidget.selectedIconForeground": accent,

        "scrollbar.shadow": current_line,
        "widget.shadow": current_line,
        "editorWidget.background": surface,
        "editorWidget.border": current_line,
        "editorWidget.shadow": current_line,
        "editorStickyScroll.background": surface,
        "editorStickyScroll.border": current_line,
        "editorStickyScroll.shadow": current_line,
        "editorStickyScrollHover.background": current_line,

        "editorBracketHighlight.foreground1": keyword_color,
        "editorBracketHighlight.foreground2": function_color,
        "editorBracketHighlight.foreground3": type_color,
        "editorBracketHighlight.foreground4": string_color,
        "editorBracketHighlight.foreground5": number_color,
        "editorBracketHighlight.foreground6": operator_color,
        "editorBracketHighlight.unexpectedBracket.foreground": "#ff9580" if is_dark else "#dc2626",
        "editorBracketMatch.background": current_line,
        "editorBracketMatch.border": accent,
        "editorBracketPairGuide.activeBackground1": keyword_color,
        "editorBracketPairGuide.activeBackground2": function_color,
        "editorBracketPairGuide.activeBackground3": type_color
    }

    token_colors = {
        "comments": comment_color,
        "strings": string_color,
        "keywords": keyword_color,
        "functions": function_color,
        "variables": fg,
        "numbers": number_color,
        "types": type_color,
        "textMateRules": [
            {
                "scope": [
                    "keyword",
                    "keyword.control",
                    "keyword.control.import",
                    "keyword.control.from",
                    "keyword.control.flow",
                    "keyword.operator.new",
                    "keyword.operator.expression",
                    "keyword.operator.logical",
                    "keyword.operator.word",
                    "storage",
                    "storage.type",
                    "storage.modifier",
                    "punctuation.definition.keyword"
                ],
                "settings": {"foreground": keyword_color}
            },
            {
                "scope": [
                    "entity.name.function",
                    "entity.name.function.member",
                    "entity.name.method",
                    "support.function",
                    "support.function.builtin",
                    "support.function.magic",
                    "support.function.console",
                    "meta.function-call",
                    "meta.function-call.generic",
                    "meta.method-call"
                ],
                "settings": {"foreground": function_color}
            },
            {
                "scope": [
                    "entity.name.type",
                    "entity.name.class",
                    "entity.name.struct",
                    "entity.name.enum",
                    "entity.name.namespace",
                    "entity.name.module",
                    "entity.other.inherited-class",
                    "support.type",
                    "support.class",
                    "support.class.builtin",
                    "support.type.python",
                    "support.other.namespace"
                ],
                "settings": {"foreground": type_color}
            },
            {
                "scope": [
                    "string",
                    "string.quoted",
                    "string.quoted.single",
                    "string.quoted.double",
                    "string.quoted.triple",
                    "string.template",
                    "string.interpolated",
                    "punctuation.definition.string",
                    "string.other.link"
                ],
                "settings": {"foreground": string_color}
            },
            {
                "scope": [
                    "comment",
                    "comment.line",
                    "comment.block",
                    "comment.block.documentation",
                    "punctuation.definition.comment"
                ],
                "settings": {"foreground": comment_color, "fontStyle": "italic"}
            },
            {
                "scope": [
                    "constant",
                    "constant.numeric",
                    "constant.language",
                    "constant.other",
                    "constant.other.caps",
                    "constant.other.symbol",
                    "constant.other.property",
                    "constant.other.placeholder",
                    "constant.character",
                    "constant.character.escape",
                    "support.constant",
                    "support.constant.python",
                    "support.variable",
                    "support.variable.python",
                    "support.variable.property",
                    "support.other.variable",
                    "support.type.object.module",
                    "variable.other.constant",
                    "variable.other.constant.python",
                    "variable.other.enummember",
                    "variable.readonly",
                    "variable.readonly.defaultLibrary",
                    "entity.name.constant",
                    "entity.name.enummember",
                    "meta.symbol",
                    "boolean"
                ],
                "settings": {"foreground": number_color}
            },
            {
                "scope": [
                    "variable",
                    "variable.other",
                    "variable.other.readwrite",
                    "variable.other.property",
                    "variable.other.object",
                    "variable.other.member",
                    "variable.parameter",
                    "variable.language",
                    "variable.name"
                ],
                "settings": {"foreground": fg}
            },
            {
                "scope": [
                    "entity.name.tag",
                    "meta.tag"
                ],
                "settings": {"foreground": keyword_color}
            },
            {
                "scope": [
                    "entity.other.attribute-name"
                ],
                "settings": {"foreground": function_color}
            },
            {
                "scope": [
                    "keyword.operator",
                    "keyword.operator.assignment",
                    "keyword.operator.arithmetic",
                    "keyword.operator.comparison",
                    "punctuation.accessor",
                    "punctuation.separator"
                ],
                "settings": {"foreground": operator_color}
            },
            {
                "scope": [
                    "markup.heading"
                ],
                "settings": {"foreground": keyword_color, "fontStyle": "bold"}
            },
            {
                "scope": [
                    "markup.bold"
                ],
                "settings": {"foreground": function_color, "fontStyle": "bold"}
            },
            {
                "scope": [
                    "markup.italic"
                ],
                "settings": {"foreground": type_color, "fontStyle": "italic"}
            }
        ]
    }

    semantic_rules = {
        "variable.readonly": number_color,
        "variable.readonly.defaultLibrary": number_color,
        "variable.defaultLibrary": number_color,
        "variable.constant": number_color,
        "property.readonly": number_color,
        "property.readonly.defaultLibrary": number_color,
        "property.defaultLibrary": number_color,
        "enumMember": number_color,
        "macro": keyword_color,
        "parameter": fg,
        "property": fg,
        "variable": fg,
        "function": function_color,
        "function.defaultLibrary": function_color,
        "method": function_color,
        "type": type_color,
        "type.defaultLibrary": type_color,
        "class": type_color,
        "class.defaultLibrary": type_color,
        "interface": type_color,
        "enum": type_color,
        "struct": type_color,
        "namespace": type_color,
        "keyword": keyword_color,
        "comment": comment_color,
        "string": string_color,
        "number": number_color,
        "operator": operator_color
    }

    theme_name_str = "Default Dark Modern" if is_dark else "Default Light Modern"

    semantic_token_colors = {
        "enabled": True,
        "rules": semantic_rules,
        f"[{theme_name_str}]": {
            "enabled": True,
            "rules": semantic_rules
        }
    }

    target_dirs = [
        os.path.expanduser('~/.config/Antigravity IDE/User'),
        os.path.expanduser('~/.config/Antigravity/User'),
        os.path.expanduser('~/.config/antigravity/User'),
        os.path.expanduser('~/.config/antigravity-ide/User'),
        os.path.expanduser('~/.config/Antigravity IDE Dev/User'),
        os.path.expanduser('~/.config/Code/User'),
        os.path.expanduser('~/.config/Code - OSS/User'),
        os.path.expanduser('~/.config/VSCodium/User'),
        os.path.expanduser('~/.var/app/com.google.antigravity/config/Antigravity IDE/User'),
        os.path.expanduser('~/.var/app/com.visualstudio.code/config/Code/User'),
        os.path.expanduser('~/.var/app/com.vscodium.codium/config/VSCodium/User')
    ]

    for base_dir in target_dirs:
        try:
            os.makedirs(base_dir, exist_ok=True)
            settings_path = os.path.join(base_dir, 'settings.json')
            data = {}
            if os.path.exists(settings_path):
                try:
                    with open(settings_path, 'r', encoding='utf-8') as f:
                        raw = f.read()
                        cleaned = strip_jsonc_comments(raw)
                        data = json.loads(cleaned) if cleaned.strip() else {}
                except Exception:
                    # Preserve existing data if JSON parse fails
                    pass

            data["workbench.colorCustomizations"] = colors_dict
            data["editor.tokenColorCustomizations"] = token_colors
            data["editor.semanticTokenColorCustomizations"] = semantic_token_colors
            data["editor.bracketPairColorization.enabled"] = True
            data["editor.guides.bracketPairs"] = "active"
            data["workbench.colorTheme"] = theme_name_str
            data["workbench.iconTheme"] = "material-icon-theme"
            data["material-icon-theme.folders.color"] = accent
            if "password-store" not in data:
                data["password-store"] = "gnome-libsecret"

            with open(settings_path, 'w', encoding='utf-8') as f:
                json.dump(data, f, indent=4)
        except Exception:
            pass

def sync_zen(bg, surface, current_line, fg, accent, sub_accent, is_dark):
    import subprocess
    chrome_css = f"""/* Auto-generated by Quickshell Theme Engine */
:root {{
    --zen-main-browser-background: {bg} !important;
    --zen-workspace-background: {bg} !important;
    --zen-colors-bg: {bg} !important;
    --zen-colors-bg-alt: {bg} !important;
    --zen-colors-tertiary: {surface} !important;
    --zen-colors-primary: {accent} !important;
    --zen-colors-secondary: {sub_accent} !important;
    --zen-primary-color: {accent} !important;
    --zen-theme-accent: {accent} !important;
    --zen-colors-input-bg: {surface} !important;
    --zen-colors-text: {fg} !important;
    --zen-colors-border: {bg} !important;
    --zen-borders-color: {bg} !important;
    --zen-border-color: {bg} !important;
    --zen-sidebar-border: {bg} !important;
    --zen-sidebar-bg: {bg} !important;
    --zen-sidebar-background: {bg} !important;
    --zen-sidebar-top-buttons-bg: {bg} !important;
    --zen-element-separation: 0px !important;
    --zen-main-browser-margin: 0px !important;
    --zen-main-browser-padding: 0px !important;
    --zen-user-border-radius: 0px !important;
    
    --lwt-accent-color: {bg} !important;
    --lwt-text-color: {fg} !important;
    --lwt-sidebar-background: {bg} !important;
    --lwt-sidebar-text-color: {fg} !important;
    
    --toolbar-bgcolor: {bg} !important;
    --toolbar-color: {fg} !important;
    --toolbar-field-background-color: {surface} !important;
    --toolbar-field-color: {fg} !important;
    --toolbar-field-focus-background-color: {surface} !important;
    --toolbarbutton-hover-background: {surface} !important;
    
    --arrowpanel-background: {surface} !important;
    --arrowpanel-color: {fg} !important;
    --tab-selected-bgcolor: {current_line} !important;
    --tab-selected-bg: {current_line} !important;
    --urlbar-box-background: {surface} !important;
    --urlbar-background: {surface} !important;
    --chrome-content-separator-color: {bg} !important;
    --toolbox-border-bottom-color: {bg} !important;
}}

*, *::before, *::after {{
    border-color: {bg} !important;
    box-shadow: none !important;
    outline: none !important;
}}

#main-window,
#navigator-toolbox,
#nav-bar,
#PersonalToolbar,
#urlbar-background,
#sidebar-box,
#sidebar-header,
#sidebar-splitter,
.sidebar-splitter,
#TabsToolbar,
.browserStack,
#appcontent,
#tabbrowser-tabpanels,
#zen-main-app-wrapper,
#browser,
.browserContainer,
browser[type="content"],
deck,
tabbox,
vbox,
hbox,
#zen-sidebar-top-buttons,
#zen-sidebar-bottom-buttons,
#zen-sidebar-icons-wrapper,
#zen-current-workspace-indicator,
.sidebar-panel,
#zen-sidebar-box,
#zen-appcontent-navbar-container {{
    background: {bg} !important;
    background-color: {bg} !important;
    color: {fg} !important;
    border: none !important;
    border-color: {bg} !important;
    box-shadow: none !important;
    outline: none !important;
}}

/* Firefox Wide Vertical Sidebar & Expanded Tab Section */
#sidebar-box,
#sidebar,
#sidebar-select-box,
#sidebar-search-container,
#tabbrowser-tabs,
.tabbrowser-tabs,
#tabbrowser-tabs scrollbox,
#tabbrowser-tabs .scrollbox-clip {{
    width: 260px !important;
    min-width: 260px !important;
    padding-left: 6px !important;
    padding-right: 16px !important;
    background-color: {bg} !important;
    border-right: 1px solid {surface} !important;
    box-sizing: border-box !important;
    overflow: visible !important;
}}

#sidebar-header {{
    padding: 10px 14px !important;
    font-weight: 700 !important;
    font-size: 14px !important;
    background-color: {bg} !important;
    color: {fg} !important;
}}

.tabbrowser-tab {{
    min-height: 40px !important;
    height: 40px !important;
    width: 100% !important;
    max-width: calc(100% - 8px) !important;
    margin: 4px 0 !important;
    padding: 0 !important;
    border-radius: 10px !important;
    box-sizing: border-box !important;
    overflow: visible !important;
}}

.tab-stack,
.tab-background {{
    width: 100% !important;
    height: 100% !important;
    border-radius: 10px !important;
    margin: 0 !important;
    box-sizing: border-box !important;
}}

/* Ensure Tab Content & Label Are Expanded & Centered */
.tab-content {{
    display: flex !important;
    flex-direction: row !important;
    align-items: center !important;
    justify-content: flex-start !important;
    padding: 0 12px !important;
    height: 100% !important;
    width: 100% !important;
    box-sizing: border-box !important;
    background: transparent !important;
    background-color: transparent !important;
}}

.tab-icon-stack {{
    display: inline-flex !important;
    align-items: center !important;
    justify-content: center !important;
    margin: 0 10px 0 0 !important;
    padding: 0 !important;
    width: 16px !important;
    height: 16px !important;
    min-width: 16px !important;
    min-height: 16px !important;
    flex-shrink: 0 !important;
}}

.tab-icon-image,
.tab-throbber {{
    display: block !important;
    margin: 0 !important;
    padding: 0 !important;
    width: 16px !important;
    height: 16px !important;
    align-self: center !important;
}}

.tab-label-container,
.tab-label,
.tab-text {{
    display: inline-block !important;
    visibility: visible !important;
    opacity: 1 !important;
    flex: 1 !important;
    margin: 0 !important;
    padding: 0 !important;
    background: transparent !important;
    background-color: transparent !important;
    color: {fg} !important;
    font-size: 13.5px !important;
    font-weight: 600 !important;
    line-height: 16px !important;
    overflow: hidden !important;
    text-overflow: ellipsis !important;
    white-space: nowrap !important;
    align-self: center !important;
}}

/* Single Clean Border & Background for Active Selected Tab */
.tabbrowser-tab,
.tab-stack,
.tab-content {{
    border: none !important;
    outline: none !important;
    box-shadow: none !important;
}}

.tabbrowser-tab[selected],
#tabbrowser-tabs .tabbrowser-tab[selected],
tab[selected="true"] {{
    background: transparent !important;
    background-color: transparent !important;
    border: none !important;
    outline: none !important;
}}

.tabbrowser-tab[selected] .tab-background,
.tab-background[selected="true"] {{
    background: {surface} !important;
    background-color: {surface} !important;
    border: 2px solid {accent} !important;
    border-radius: 10px !important;
    box-shadow: 0 4px 14px rgba(0, 0, 0, 0.35) !important;
}}

.tabbrowser-tab[selected] .tab-label,
.tabbrowser-tab[selected] .tab-text,
.tabbrowser-tab[selected] .tab-content,
.tabbrowser-tab[selected] .tab-label-container {{
    color: {accent} !important;
    font-size: 13.5px !important;
    font-weight: 700 !important;
    opacity: 1 !important;
    visibility: visible !important;
}}

.tabbrowser-tab[selected] .tab-close-button {{
    fill: {accent} !important;
    color: {accent} !important;
}}

/* Hovered Tab Highlight Styling */
.tabbrowser-tab:hover:not([selected]),
.tabbrowser-tab:hover:not([selected]) .tab-background,
.tabbrowser-tab:hover:not([selected]) .tab-content {{
    background: {current_line} !important;
    background-color: {current_line} !important;
    border-radius: 10px !important;
    transition: background-color 0.15s ease-in-out !important;
}}

.tabbrowser-tab:hover:not([selected]) .tab-label,
.tabbrowser-tab:hover:not([selected]) .tab-text {{
    color: {accent} !important;
    font-weight: 700 !important;
}}

#sidebar-splitter,
.sidebar-splitter {{
    width: 0px !important;
    min-width: 0px !important;
    background: {bg} !important;
    border: none !important;
}}

/* Sleek & Elegant Floating URL Bar & Address Dropdown */
#urlbar {{
    border: none !important;
    box-shadow: none !important;
}}

#urlbar-background {{
    background: {surface} !important;
    background-color: {surface} !important;
    border-radius: 12px !important;
    border: 1px solid {current_line} !important;
}}

#urlbar[breakout][breakout-extend] > #urlbar-background {{
    background: {surface} !important;
    background-color: {surface} !important;
    border-radius: 14px !important;
    border: 1px solid {accent} !important;
    box-shadow: 0 12px 32px rgba(0, 0, 0, 0.45) !important;
}}

#urlbar-input-container {{
    background: transparent !important;
    border: none !important;
    padding-left: 8px !important;
    padding-right: 8px !important;
}}

/* URL Bar Dropdown Results Container */
.urlbarView {{
    background: {surface} !important;
    background-color: {surface} !important;
    border-radius: 14px !important;
    border: 1px solid {accent} !important;
    box-shadow: 0 16px 40px rgba(0, 0, 0, 0.5) !important;
    margin-top: 4px !important;
}}

.urlbarView-row {{
    border-radius: 8px !important;
    padding: 6px 10px !important;
}}

.urlbarView-row:hover,
.urlbarView-row[selected] {{
    background: {current_line} !important;
    background-color: {current_line} !important;
}}

.urlbarView-row[selected] .urlbarView-title,
.urlbarView-row:hover .urlbarView-title {{
    color: {accent} !important;
    font-weight: bold !important;
}}

.urlbarView-title {{
    color: {fg} !important;
}}

.urlbarView-secondary,
.urlbarView-url {{
    color: {sub_accent} !important;
    opacity: 0.85 !important;
}}

.urlbarView-action {{
    color: {accent} !important;
    background: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15) !important;
    border-radius: 6px !important;
}}
"""

    content_css = f"""/* Auto-generated Newtab & Content Theme */
@-moz-document url("about:home"), url("about:newtab"), url("about:blank"), url-prefix("about:") {{
    body, #root, .container, .main, html {{
        background: {bg} !important;
        background-color: {bg} !important;
        color: {fg} !important;
    }}
}}
"""
    pref_lines = [
        'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);\n',
        'user_pref("svg.context-properties.content.enabled", true);\n',
        'user_pref("sidebar.revamp", true);\n',
        'user_pref("sidebar.verticalTabs", true);\n',
        'user_pref("sidebar.visibility", "always-show");\n',
        'user_pref("browser.tabs.inTitlebar", 1);\n',
        'user_pref("signon.rememberSignons", true);\n',
        'user_pref("privacy.sanitize.sanitizeOnShutdown", false);\n',
        'user_pref("network.cookie.lifetimePolicy", 0);\n',
        'user_pref("browser.startup.page", 3);\n',
        'user_pref("browser.sessionstore.resume_from_crash", true);\n',
        'user_pref("toolkit.startup.max_resumed_crashes", -1);\n'
    ]

    # Ensure default Firefox profile paths exist so userChrome.css is always present
    ff_default = os.path.expanduser('~/.mozilla/firefox/default')
    os.makedirs(os.path.join(ff_default, 'chrome'), exist_ok=True)

    zen_bases = [
        os.path.expanduser('~/.mozilla/firefox'),
        os.path.expanduser('~/.var/app/org.mozilla.firefox/.mozilla/firefox'),
        os.path.expanduser('~/.config/zen'),
        os.path.expanduser('~/.zen'),
        os.path.expanduser('~/.var/app/app.zen_browser.zen/.zen'),
        os.path.expanduser('~/.var/app/io.github.zen_browser.zen/.zen'),
        os.path.expanduser('~/.var/app/org.zen_browser.zen/.zen'),
        os.path.expanduser('~/.var/app/app.zen_browser.zen/config/zen'),
        os.path.expanduser('~/.var/app/io.github.zen_browser.zen/config/zen')
    ]
    for zen_base in zen_bases:
        if os.path.exists(zen_base):
            for profile in os.listdir(zen_base):
                profile_dir = os.path.join(zen_base, profile)
                if os.path.isdir(profile_dir) and profile not in ["Crash Reports", "Pending Pings", "Profile Groups"]:
                    # Ensure user.js enables stylesheets and disables crash dialogs
                    user_js = os.path.join(profile_dir, 'user.js')
                    js_content = ""
                    if os.path.exists(user_js):
                        try:
                            with open(user_js, 'r') as f:
                                js_content = f.read()
                        except Exception: pass
                    for line in pref_lines:
                        pref_key = line.split('"')[1]
                        if pref_key not in js_content:
                            try:
                                with open(user_js, 'a') as f:
                                    f.write("\n" + line)
                            except Exception: pass

                    # Write userChrome.css and userContent.css
                    chrome_dir = os.path.join(profile_dir, 'chrome')
                    os.makedirs(chrome_dir, exist_ok=True)
                    
                    try:
                        with open(os.path.join(chrome_dir, 'userChrome.css'), 'w', encoding='utf-8') as f:
                            f.write(chrome_css)
                        with open(os.path.join(chrome_dir, 'userContent.css'), 'w', encoding='utf-8') as f:
                            f.write(content_css)
                    except Exception:
                        pass

    restart_app_if_running(
        "firefox",
        ["firefox", "firefox-bin", "org.mozilla.firefox"],
        [
            "flatpak run org.mozilla.firefox",
            "gtk-launch firefox",
            "firefox"
        ]
    )

    restart_app_if_running(
        "zen",
        ["zen-browser", "zen-bin", "zen_browser", "app.zen_browser.zen", "io.github.zen_browser.zen"],
        [
            "flatpak run app.zen_browser.zen",
            "flatpak run io.github.zen_browser.zen",
            "gtk-launch app.zen_browser.zen",
            "gtk-launch io.github.zen_browser.zen",
            "gtk-launch zen-browser",
            "zen-browser",
            "zen-bin",
            "zen"
        ]
    )

def hex_to_rgb(hex_str):
    try:
        h = hex_str.lstrip('#')
        if len(h) == 3:
            h = ''.join([c*2 for c in h])
        r = int(h[0:2], 16)
        g = int(h[2:4], 16)
        b = int(h[4:6], 16)
        return f"rgb({r}, {g}, {b})"
    except Exception:
        return hex_str

def slugify(name):
    import re
    s = re.sub(r'[^a-z0-9]+', '-', name.lower()).strip('-')
    return f"quickshell-{s}" if s else "quickshell"

PREDEFINED_VARIANTS = [

    {"name": "Pro", "isDark": True, "accent": "#9580ff", "bg": "#22212c", "surface": "#2b2938", "currentLine": "#454158", "fg": "#f8f8f2"},
    {"name": "Blade", "isDark": True, "accent": "#80ffea", "bg": "#212c2a", "surface": "#293835", "currentLine": "#415854", "fg": "#f8f8f2"},
    {"name": "Buff", "isDark": True, "accent": "#ffca80", "bg": "#2a212c", "surface": "#352938", "currentLine": "#544158", "fg": "#f8f8f2"},
    {"name": "Cyan", "isDark": True, "accent": "#80ffea", "bg": "#0b0d0f", "surface": "#181b1f", "currentLine": "#414d58", "fg": "#f8f8f2"},
    {"name": "Lincoln", "isDark": True, "accent": "#ffff80", "bg": "#2c2a21", "surface": "#38352a", "currentLine": "#585441", "fg": "#f8f8f2"},
    {"name": "Morpheus", "isDark": True, "accent": "#ff9580", "bg": "#2c2122", "surface": "#382a2b", "currentLine": "#584145", "fg": "#f8f8f2"},
    {"name": "Alucard", "isDark": False, "accent": "#6272a4", "bg": "#f8f8f2", "surface": "#e6e6e6", "currentLine": "#d0d0d0", "fg": "#282a36"},

    {"name": "Gruvbox Dark", "isDark": True, "accent": "#fe8019", "bg": "#282828", "surface": "#3c3836", "currentLine": "#504945", "fg": "#ebdbb2"},
    {"name": "Gruvbox Material", "isDark": True, "accent": "#ea698c", "bg": "#1d2021", "surface": "#282828", "currentLine": "#3c3836", "fg": "#ddc7a1"},
    {"name": "Gruvbox Light", "isDark": False, "accent": "#af3a03", "bg": "#fbf1c7", "surface": "#ebdbb2", "currentLine": "#d5c4a1", "fg": "#3c3836"},

    {"name": "Rosé Pine", "isDark": True, "accent": "#ebbcba", "bg": "#191724", "surface": "#1f1d2e", "currentLine": "#26233a", "fg": "#e0def4"},
    {"name": "Rosé Pine Moon", "isDark": True, "accent": "#ea9a97", "bg": "#232136", "surface": "#2a273f", "currentLine": "#393552", "fg": "#e0def4"},
    {"name": "Rosé Pine Dawn", "isDark": False, "accent": "#d7827e", "bg": "#faf4ed", "surface": "#f2e9e1", "currentLine": "#e4d7d0", "fg": "#575279"},

    {"name": "Catppuccin Mocha", "isDark": True, "accent": "#cba6f7", "bg": "#1e1e2e", "surface": "#313244", "currentLine": "#45475a", "fg": "#cdd6f4"},
    {"name": "Catppuccin Macchiato", "isDark": True, "accent": "#f5bde6", "bg": "#24273a", "surface": "#363a4f", "currentLine": "#494d64", "fg": "#cad3f5"},
    {"name": "Catppuccin Latte", "isDark": False, "accent": "#8839ef", "bg": "#eff1f5", "surface": "#e6e9ef", "currentLine": "#ccd0da", "fg": "#4c4f69"},

    {"name": "Everforest Dark", "isDark": True, "accent": "#a7c080", "bg": "#2d353b", "surface": "#343f44", "currentLine": "#3d484d", "fg": "#d3c6aa"},
    {"name": "Everforest Light", "isDark": False, "accent": "#8da101", "bg": "#fdf6e3", "surface": "#f4e0c5", "currentLine": "#e5d5c5", "fg": "#5c6a72"},

    {"name": "Tokyo Night", "isDark": True, "accent": "#7aa2f7", "bg": "#1a1b26", "surface": "#24283b", "currentLine": "#414868", "fg": "#c0caf5"},
    {"name": "Tokyo Night Storm", "isDark": True, "accent": "#7aa2f7", "bg": "#24283b", "surface": "#1f2335", "currentLine": "#414868", "fg": "#c0caf5"},
    {"name": "Tokyo Night Day", "isDark": False, "accent": "#2e7de9", "bg": "#e1e2e7", "surface": "#d5d6db", "currentLine": "#c4c8da", "fg": "#3760bf"},

    {"name": "Nord Dark", "isDark": True, "accent": "#88c0d0", "bg": "#2e3440", "surface": "#3b4252", "currentLine": "#434c5e", "fg": "#eceff4"},
    {"name": "Nord Light", "isDark": False, "accent": "#5e81ac", "bg": "#eceff4", "surface": "#e5e9f0", "currentLine": "#d8dee9", "fg": "#2e3440"},

    {"name": "Solarized Dark", "isDark": True, "accent": "#268bd2", "bg": "#002b36", "surface": "#073642", "currentLine": "#586e75", "fg": "#839496"},
    {"name": "Solarized Light", "isDark": False, "accent": "#268bd2", "bg": "#fdf6e3", "surface": "#eee8d5", "currentLine": "#93a1a1", "fg": "#657b83"},

    {"name": "One Dark Pro", "isDark": True, "accent": "#61afef", "bg": "#282c34", "surface": "#21252b", "currentLine": "#3e4451", "fg": "#abb2bf"},
    {"name": "One Light", "isDark": False, "accent": "#4078f2", "bg": "#fafafa", "surface": "#f0f0f0", "currentLine": "#e5e5e6", "fg": "#383a42"},

    {"name": "Monokai Pro", "isDark": True, "accent": "#ffd866", "bg": "#2d2a2e", "surface": "#3a3a3a", "currentLine": "#4a4a4a", "fg": "#fcfcfa"},

    {"name": "Cyberpunk Neon", "isDark": True, "accent": "#ff007f", "bg": "#120e24", "surface": "#22194d", "currentLine": "#3a2a80", "fg": "#00ff9f"}
]

def make_feishin_json(bg, surface, current_line, fg, accent, is_dark, name="Quickshell", slug="quickshell"):
    mode = "dark" if is_dark else "light"
    extends_theme = "defaultDark" if is_dark else "defaultLight"

    return {
        "id": slug,
        "name": name,
        "version": "1.0.0",
        "author": "Quickshell",
        "style": mode,
        "mode": mode,
        "extends": extends_theme,
        "colors": {
            "primary": accent,
            "primary-foreground": fg,
            "background": bg,
            "background-alternate": surface,
            "surface": surface,
            "surface-foreground": fg,
            "foreground": fg,
            "foreground-muted": fg,
            "text-muted": fg,
            "muted-foreground": fg,
            "accent": accent,
            "accent-foreground": fg,
            "secondary-foreground": fg,
            "border": current_line,
            "sidebar-background": bg,
            "sidebar-foreground": fg
        }
    }

def sync_feishin(bg, surface, current_line, fg, accent, sub_accent, is_dark, variant_name="Pro"):
    import json, glob
    active_slug = slugify(variant_name)

    feishin_dirs = get_app_config_dirs(['feishin', 'Feishin', 'io.github.jeffvli.feishin'])
    for fb in [
        os.path.expanduser('~/.config/feishin'),
        os.path.expanduser('~/.local/share/feishin'),
        os.path.expanduser('~/.var/app/io.github.jeffvli.feishin/config/feishin'),
        os.path.expanduser('~/.var/app/io.github.jeffvli.feishin/data/feishin'),
        os.path.expanduser('~/.var/app/org.jeffvli.feishin/config/feishin'),
        os.path.expanduser('~/.var/app/org.jeffvli.feishin/data/feishin'),
        os.path.expanduser('~/.var/app/feishin/config/feishin'),
        os.path.expanduser('~/.var/app/feishin/data/feishin')
    ]:
        if fb not in feishin_dirs:
            feishin_dirs.append(fb)

    active_json = make_feishin_json(bg, surface, current_line, fg, accent, is_dark, variant_name, active_slug)
    qs_json = make_feishin_json(bg, surface, current_line, fg, accent, is_dark, "Quickshell", "quickshell")

    for base_dir in feishin_dirs:
        try:
            for t_dir_name in ['Themes', 'themes']:
                themes_dir = os.path.join(base_dir, t_dir_name)
                os.makedirs(themes_dir, exist_ok=True)

                # Clean up backup files or zero-byte corrupted files
                for f_name in os.listdir(themes_dir):
                    f_path = os.path.join(themes_dir, f_name)
                    if f_name.endswith('.backup') or (os.path.isfile(f_path) and os.path.getsize(f_path) == 0):
                        try:
                            os.remove(f_path)
                        except Exception:
                            pass

                # Pre-generate JSON files for all predefined variants so all themes are available
                for v in PREDEFINED_VARIANTS:
                    v_slug = slugify(v["name"])
                    v_json = make_feishin_json(v["bg"], v["surface"], v["currentLine"], v["fg"], v["accent"], v["isDark"], v["name"], v_slug)
                    v_path = os.path.join(themes_dir, f"{v_slug}.json")
                    with open(v_path, 'w', encoding='utf-8') as f:
                        json.dump(v_json, f, indent=2)

                # Write active variant JSON with runtime parameters + quickshell.json
                active_path = os.path.join(themes_dir, f"{active_slug}.json")
                with open(active_path, 'w', encoding='utf-8') as f:
                    json.dump(active_json, f, indent=2)

                with open(os.path.join(themes_dir, "quickshell.json"), 'w', encoding='utf-8') as f:
                    json.dump(qs_json, f, indent=2)

            # Ensure config.json, preferences.json, and settings.json maintain valid Electron themeSource ("dark" or "light") and comfortable window bounds
            valid_electron_theme = "dark" if is_dark else "light"
            for conf_file_name in ['config.json', 'preferences.json', 'settings.json']:
                conf_path = os.path.join(base_dir, conf_file_name)
                if os.path.exists(conf_path):
                    try:
                        with open(conf_path, 'r', encoding='utf-8') as f:
                            cdata = json.load(f)
                        if isinstance(cdata, dict):
                            modified = False
                            if list(cdata.keys()) == ['theme'] and cdata['theme'] not in ['dark', 'light', 'system', 'defaultDark', 'defaultLight']:
                                os.remove(conf_path)
                                continue
                            elif 'theme' in cdata and cdata['theme'] not in ['dark', 'light', 'system', 'defaultDark', 'defaultLight']:
                                cdata['theme'] = valid_electron_theme
                                modified = True

                            bounds = cdata.get('bounds', {})
                            if isinstance(bounds, dict) and (bounds.get('width', 0) < 1000 or bounds.get('height', 0) < 700):
                                cdata['bounds'] = {
                                    'x': bounds.get('x', 50),
                                    'y': bounds.get('y', 50),
                                    'width': 1280,
                                    'height': 800
                                }
                                modified = True

                            if modified:
                                with open(conf_path, 'w', encoding='utf-8') as f:
                                    json.dump(cdata, f, indent=2)
                    except Exception:
                        pass
        except Exception:
            pass

def sync_starship(bg, surface, current_line, fg, accent, sub_accent, is_dark, variant_name=""):
    starship_dir = os.path.expanduser('~/.config')
    os.makedirs(starship_dir, exist_ok=True)
    starship_file = os.path.join(starship_dir, 'starship.toml')

    v_lower = (variant_name or "").lower()

    if "everforest" in v_lower:
        c_cyan, c_purple, c_yellow, c_green, c_blue = ("#83c092", "#d699b6", "#dbbc7f", "#a7c080", "#7fbbb3") if is_dark else ("#35a77c", "#df69ba", "#dfa000", "#8da101", "#3a94c5")
    elif "gruvbox" in v_lower:
        c_cyan, c_purple, c_yellow, c_green, c_blue = ("#7daea3", "#d3869b", "#fabd2f", "#b8bb26", "#8ec07c") if is_dark else ("#427b58", "#8f3f71", "#b57614", "#79740e", "#076678")
    elif "catppuccin" in v_lower:
        c_cyan, c_purple, c_yellow, c_green, c_blue = ("#94e2d5", "#cba6f7", "#f9e2af", "#a6e3a1", "#89b4fa") if is_dark else ("#179299", "#8839ef", "#df8e1d", "#40a02b", "#1e66f5")
    elif "tokyo" in v_lower:
        c_cyan, c_purple, c_yellow, c_green, c_blue = ("#7dcfff", "#bb9af7", "#e0af68", "#9ece6a", "#7aa2f7") if is_dark else ("#007197", "#9854f6", "#8c6c00", "#587539", "#2e7de9")
    elif "nord" in v_lower:
        c_cyan, c_purple, c_yellow, c_green, c_blue = ("#88c0d0", "#b48ead", "#ebcb8b", "#a3be8c", "#81a1c1") if is_dark else ("#5e81ac", "#b48ead", "#ebcb8b", "#a3be8c", "#81a1c1")
    elif "rosé" in v_lower or "rose" in v_lower:
        c_cyan, c_purple, c_yellow, c_green, c_blue = ("#9ccfd8", "#c4a7e7", "#f6c177", "#31748f", "#56949f") if is_dark else ("#56949f", "#907aa9", "#ea9d34", "#286983", "#286983")
    elif "solarized" in v_lower:
        c_cyan, c_purple, c_yellow, c_green, c_blue = "#2aa198", "#d33682", "#b58900", "#859900", "#268bd2"
    elif "monokai" in v_lower:
        c_cyan, c_purple, c_yellow, c_green, c_blue = "#78dce8", "#ab9df2", "#ffd866", "#a9dc76", "#fc9867"
    elif "cyberpunk" in v_lower or "emo" in v_lower:
        c_cyan, c_purple, c_yellow, c_green, c_blue = "#00f0ff", "#ff007f", "#fcee0a", "#00ff9f", "#00f0ff"
    elif "zoey" in v_lower:
        c_cyan, c_purple, c_yellow, c_green, c_blue = ("#38bdf8", "#c084fc", "#facc15", "#4ade80", "#38bdf8") if is_dark else ("#06b6d4", "#a855f7", "#eab308", "#10b981", "#06b6d4")
    else:
        c_cyan, c_purple, c_yellow, c_green, c_blue = (accent, sub_accent, sub_accent, accent, accent)

    red_color = "#ff5555" if is_dark else "#b91c1c"

    starship_config = f"""# Starship Dynamic Theme (Auto-synced with Quickshell)
command_timeout = 2000
add_newline = true

format = \"\"\"
$os\\
$directory\\
$git_branch\\
$git_status\\
$nix_shell\\
$cmd_duration\\
$status\\
$line_break\\
$character\"\"\"

palette = "quickshell"

[os]
disabled = false
style = "cyan"
format = "[$symbol]($style) "

[os.symbols]
Arch = " "
EndeavourOS = " "
NixOS = " "
Fedora = " "
Ubuntu = " "
Debian = " "
Manjaro = " "
Pop = " "
Linux = " "

[directory]
style = "bold cyan"
format = "[$path]($style)[$read_only]($read_only_style) "
truncation_length = 4
truncation_symbol = "…/"
home_symbol = "~"
read_only = " 🔒"
read_only_style = "red"

[git_branch]
symbol = " "
style = "bold purple"
format = "on [$symbol$branch]($style) "

[git_status]
style = "bold yellow"
format = "([$all_status$ahead_behind]($style) )"
conflicted = "󰞇 "
ahead = "⇡${{count}} "
behind = "⇣${{count}} "
diverged = "⇕⇡${{ahead_count}}⇣${{behind_count}} "
untracked = "?${{count}} "
stashed = "📦${{count}} "
modified = "!${{count}} "
staged = "+${{count}} "
renamed = "»${{count}} "
deleted = "✘${{count}} "

[nix_shell]
symbol = "󱄅 "
style = "bold blue"
format = "via [$symbol$state ($name)]($style) "

[cmd_duration]
min_time = 2000
style = "bold yellow"
format = "[⏱ $duration]($style) "

[status]
disabled = false
style = "bold red"
symbol = "✖ "
format = "[$symbol$status]($style) "

[character]
success_symbol = "[❯](bold green)"
error_symbol = "[❯](bold red)"
vimcmd_symbol = "[❮](bold yellow)"

[package]
disabled = true

[palettes.quickshell]
accent = "{accent}"
sub_accent = "{sub_accent}"
bg = "{bg}"
surface = "{surface}"
fg = "{fg}"
current_line = "{current_line}"
red = "{red_color}"
green = "{c_green}"
yellow = "{c_yellow}"
blue = "{c_blue}"
purple = "{c_purple}"
cyan = "{c_cyan}"
"""

    if os.path.islink(starship_file) or (os.path.exists(starship_file) and not os.access(starship_file, os.W_OK)):
        try: os.chmod(starship_file, 0o666)
        except Exception: pass
        try: os.unlink(starship_file)
        except Exception: pass

    try:
        with open(starship_file, 'w', encoding='utf-8') as f:
            f.write(starship_config)
    except Exception:
        pass

def sync_vim(bg, surface, current_line, fg, accent, sub_accent, is_dark):
    mode = "dark" if is_dark else "light"
    comment_color = "#7970a9" if is_dark else "#8c8c8c"
    green_color = "#8aff80" if is_dark else "#16a34a"
    orange_color = "#ffca80" if is_dark else "#ea580c"
    red_color = "#ff9580" if is_dark else "#dc2626"

    vim_theme_content = f"""" Auto-generated by Quickshell Theme Engine
highlight clear
if exists("syntax_on")
  syntax reset
endif
let g:colors_name = "quickshell_theme"

set background={mode}

hi Normal guifg={fg} guibg={bg}
hi Terminal guifg={fg} guibg={bg}
hi CursorLine guibg={surface}
hi CursorColumn guibg={surface}
hi LineNr guifg={current_line} guibg={bg}
hi CursorLineNr guifg={accent} guibg={surface} gui=bold
hi Visual guibg={current_line}
hi StatusLine guifg={fg} guibg={surface} gui=bold
hi StatusLineNC guifg={current_line} guibg={bg}
hi VertSplit guifg={current_line} guibg={bg}
hi Pmenu guifg={fg} guibg={surface}
hi PmenuSel guifg={bg} guibg={accent}
hi Search guifg={bg} guibg={accent}
hi IncSearch guifg={bg} guibg={sub_accent}

hi Comment guifg={comment_color} gui=italic
hi Constant guifg={sub_accent}
hi String guifg={green_color}
hi Character guifg={green_color}
hi Number guifg={orange_color}
hi Boolean guifg={sub_accent}
hi Float guifg={orange_color}
hi Identifier guifg={fg}
hi Function guifg={accent} gui=bold
hi Statement guifg={accent}
hi Conditional guifg={accent}
hi Repeat guifg={accent}
hi Label guifg={accent}
hi Operator guifg={sub_accent}
hi Keyword guifg={accent} gui=bold
hi Exception guifg={accent}
hi PreProc guifg={sub_accent}
hi Include guifg={accent}
hi Define guifg={accent}
hi Macro guifg={sub_accent}
hi PreCondit guifg={accent}
hi Type guifg={sub_accent}
hi StorageClass guifg={accent}
hi Structure guifg={accent}
hi Typedef guifg={accent}
hi Special guifg={sub_accent}
hi SpecialChar guifg={sub_accent}
hi Tag guifg={accent}
hi Delimiter guifg={fg}
hi SpecialComment guifg={comment_color} gui=bold
hi Debug guifg={sub_accent}
hi Underlined guifg={accent} gui=underline
hi Error guifg={fg} guibg={red_color}
hi Todo guifg={bg} guibg={accent} gui=bold

" ── Squiggly Undercurls, Diagnostics & EndOfBuffer ───────────────────────
hi SpellBad guifg={red_color} guisp={red_color} gui=undercurl term=undercurl
hi SpellCap guifg={orange_color} guisp={orange_color} gui=undercurl term=undercurl
hi SpellRare guifg={sub_accent} guisp={sub_accent} gui=undercurl term=undercurl
hi SpellLocal guifg={accent} guisp={accent} gui=undercurl term=undercurl

hi DiagnosticUnderlineError guifg={red_color} guisp={red_color} gui=undercurl term=undercurl
hi DiagnosticUnderlineWarn guifg={orange_color} guisp={orange_color} gui=undercurl term=undercurl
hi DiagnosticUnderlineInfo guifg={sub_accent} guisp={sub_accent} gui=undercurl term=undercurl
hi DiagnosticUnderlineHint guifg={comment_color} guisp={comment_color} gui=undercurl term=undercurl

hi NonText guifg={current_line}
hi SpecialKey guifg={current_line}
hi EndOfBuffer guifg={current_line}
"""

    colors_dir = os.path.expanduser('~/.vim/colors')
    os.makedirs(colors_dir, exist_ok=True)
    with open(os.path.join(colors_dir, 'quickshell_theme.vim'), 'w') as f:
        f.write(vim_theme_content)

    vimrc_path = os.path.expanduser('~/.vimrc')
    vimrc_content = f"""syntax on
set termguicolors
set background={mode}
colorscheme quickshell_theme

" ── Essential Quality of Life Settings ──────────────────────────────────────
set number                  " Show line numbers
set cursorline              " Highlight current cursor line
set scrolloff=8             " Keep 8 lines visible above/below cursor when scrolling
set sidescrolloff=8

set expandtab               " Use spaces instead of tabs
set tabstop=4               " Tab width
set shiftwidth=4            " Indent width
set softtabstop=4
set autoindent              " Copy indent from current line when starting a new line
set smartindent             " Smart autoindenting for C-like syntax

set ignorecase              " Case insensitive search...
set smartcase               " ...unless uppercase letters are used
set incsearch               " Highlight matches dynamically as you type
set hlsearch                " Highlight all search matches

set mouse=a                 " Enable full mouse support (scroll, click, drag)
set clipboard=unnamedplus   " Seamless integration with system/Wayland clipboard
set backspace=indent,eol,start " Modern backspace behavior

set showcmd                 " Show partial commands in status bar
set wildmenu                " Enhanced tab completion menu for commands
set wildmode=longest:full,full

set noswapfile              " Prevent .swp file creation clutter
set nobackup
set undofile                " Maintain persistent undo history across restarts
"""
    with open(vimrc_path, 'w') as f:
        f.write(vimrc_content)

def sync_btop(bg, surface, current_line, fg, accent, sub_accent):
    btop_dir = os.path.expanduser('~/.config/btop')
    themes_dir = os.path.join(btop_dir, 'themes')
    os.makedirs(themes_dir, exist_ok=True)
    
    theme_content = f"""# Auto-generated by Quickshell Theme Engine
theme[main_bg]="{bg}"
theme[main_fg]="{fg}"
theme[title]="{fg}"
theme[hi_fg]="{accent}"
theme[selected_bg]="{surface}"
theme[selected_fg]="{accent}"
theme[inactive_fg]="{current_line}"
theme[graph_text]="{fg}"
theme[meter_bg]="{surface}"
theme[proc_misc]="{sub_accent}"
theme[cpu_box]="{accent}"
theme[mem_box]="{sub_accent}"
theme[net_box]="{accent}"
theme[proc_box]="{sub_accent}"
theme[div_line]="{current_line}"
theme[temp_start]="{accent}"
theme[temp_mid]="{sub_accent}"
theme[temp_end]="#ff9580"
theme[cpu_start]="{accent}"
theme[cpu_mid]="{sub_accent}"
theme[cpu_end]="#ff9580"
theme[free_start]="{accent}"
theme[free_mid]="{sub_accent}"
theme[free_end]="#8aff80"
theme[cached_start]="{accent}"
theme[cached_mid]="{sub_accent}"
theme[cached_end]="#ffff80"
theme[available_start]="{accent}"
theme[available_mid]="{sub_accent}"
theme[available_end]="#80ffea"
theme[used_start]="{accent}"
theme[used_mid]="{sub_accent}"
theme[used_end]="#ff9580"
theme[download_start]="{accent}"
theme[download_mid]="{sub_accent}"
theme[download_end]="#80ffea"
theme[upload_start]="{accent}"
theme[upload_mid]="{sub_accent}"
theme[upload_end]="#ff80bf"
"""
    try:
        with open(os.path.join(themes_dir, 'quickshell.theme'), 'w') as f:
            f.write(theme_content)
    except Exception:
        pass

    conf_file = os.path.join(btop_dir, 'btop.conf')
    if os.path.exists(conf_file):
        try:
            with open(conf_file, 'r') as f:
                conf = f.read()
            if 'color_theme =' in conf:
                lines = conf.splitlines()
                new_lines = []
                for l in lines:
                    if l.strip().startswith('color_theme ='):
                        new_lines.append('color_theme = "quickshell"')
                    else:
                        new_lines.append(l)
                conf = '\n'.join(new_lines) + '\n'
            else:
                conf = 'color_theme = "quickshell"\n' + conf
            with open(conf_file, 'w') as f:
                f.write(conf)
        except Exception:
            pass
    else:
        try:
            with open(conf_file, 'w') as f:
                f.write('color_theme = "quickshell"\n')
        except Exception:
            pass

def sync_fastfetch(bg, surface, current_line, fg, accent, sub_accent, is_dark=True, variant_name=""):
    import json, os, re

    v_lower = (variant_name or "").lower()

    if "everforest" in v_lower:
        c_red, c_green, c_yellow, c_cyan, c_pink = ("#e67e80", "#a7c080", "#dbbc7f", "#83c092", "#d699b6") if is_dark else ("#f85552", "#8da101", "#dfa000", "#35a77c", "#df69ba")
    elif "gruvbox" in v_lower:
        c_red, c_green, c_yellow, c_cyan, c_pink = ("#fb4934", "#b8bb26", "#fabd2f", "#7daea3", "#d3869b") if is_dark else ("#9d0006", "#79740e", "#b57614", "#427b58", "#8f3f71")
    elif "catppuccin" in v_lower:
        c_red, c_green, c_yellow, c_cyan, c_pink = ("#f38ba8", "#a6e3a1", "#f9e2af", "#94e2d5", "#cba6f7") if is_dark else ("#d20f39", "#40a02b", "#df8e1d", "#179299", "#8839ef")
    elif "tokyo" in v_lower:
        c_red, c_green, c_yellow, c_cyan, c_pink = ("#f7768e", "#9ece6a", "#e0af68", "#7dcfff", "#bb9af7") if is_dark else ("#f52a65", "#587539", "#8c6c00", "#007197", "#9854f6")
    elif "nord" in v_lower:
        c_red, c_green, c_yellow, c_cyan, c_pink = ("#bf616a", "#a3be8c", "#ebcb8b", "#88c0d0", "#b48ead") if is_dark else ("#bf616a", "#a3be8c", "#ebcb8b", "#5e81ac", "#b48ead")
    elif "rosé" in v_lower or "rose" in v_lower:
        c_red, c_green, c_yellow, c_cyan, c_pink = ("#eb6f92", "#31748f", "#f6c177", "#9ccfd8", "#c4a7e7") if is_dark else ("#b4637a", "#286983", "#ea9d34", "#56949f", "#907aa9")
    elif "solarized" in v_lower:
        c_red, c_green, c_yellow, c_cyan, c_pink = "#dc322f", "#859900", "#b58900", "#2aa198", "#d33682"
    elif "one" in v_lower:
        c_red, c_green, c_yellow, c_cyan, c_pink = ("#e06c75", "#98c379", "#e5c07b", "#56b6c2", "#c678dd") if is_dark else ("#e45649", "#50a14f", "#c18401", "#0184bc", "#a626a4")
    elif "monokai" in v_lower:
        c_red, c_green, c_yellow, c_cyan, c_pink = "#ff6188", "#a9dc76", "#ffd866", "#78dce8", "#ab9df2"
    elif "cyberpunk" in v_lower or "emo" in v_lower:
        c_red, c_green, c_yellow, c_cyan, c_pink = "#ff0055", "#00ff9f", "#fcee0a", "#00f0ff", "#ff007f"
    elif "zoey" in v_lower:
        c_red, c_green, c_yellow, c_cyan, c_pink = ("#f87171", "#4ade80", "#facc15", "#38bdf8", "#c084fc") if is_dark else ("#ef4444", "#10b981", "#eab308", "#06b6d4", "#a855f7")
    else:
        c_red, c_green, c_yellow, c_cyan, c_pink = ("#ff9580", "#8aff80", "#ffff80", "#80ffea", "#ff80bf") if is_dark else ("#cb3a2a", "#14710a", "#846e15", "#036a96", "#a3144d")

    module_color_map = {
        "uptime": c_cyan,
        "os": c_green,
        "packages": c_pink,
        "terminal": c_red,
        "shell": c_yellow,
        "cpu": sub_accent,
        "memory": c_red,
        "disk": c_green,
        "colors": c_yellow
    }

    fastfetch_dirs = [
        os.path.expanduser('~/.config/fastfetch'),
        os.path.expanduser('~/.var/app/com.github.fastfetch/config/fastfetch')
    ]

    for ff_dir in fastfetch_dirs:
        try:
            os.makedirs(ff_dir, exist_ok=True)
            config_path = os.path.join(ff_dir, 'config.jsonc')

            if os.path.islink(config_path) or (os.path.exists(config_path) and not os.access(config_path, os.W_OK)):
                try: os.chmod(config_path, 0o666)
                except Exception: pass
                try: os.unlink(config_path)
                except Exception: pass

            data = {}
            if os.path.exists(config_path):
                try:
                    with open(config_path, 'r', encoding='utf-8') as f:
                        raw = f.read()
                        cleaned = strip_jsonc_comments(raw)
                        data = json.loads(cleaned, strict=False) if cleaned.strip() else {}
                except Exception:
                    pass

            fastfetch_fg = fg
            fastfetch_keys = c_cyan if is_dark else c_blue
            fastfetch_title = c_pink if is_dark else c_red
            fastfetch_separator = c_yellow

            display_colors = {
                "keys": fastfetch_keys,
                "title": fastfetch_title,
                "output": "default",
                "separator": fastfetch_separator
            }

            if not data:
                data = {
                    "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
                    "logo": {
                        "color": { "1": accent, "2": sub_accent },
                        "padding": { "top": 1, "left": 2, "right": 2 }
                    },
                    "display": {
                        "separator": "  ",
                        "color": display_colors
                    },
                    "modules": [
                        { "type": "custom", "format": "╭──────────────╮" },
                        { "type": "uptime", "key": "│ 󰅐 uptime     │", "keyColor": c_cyan },
                        { "type": "os", "key": "│  distro     │", "keyColor": c_green },
                        { "type": "packages", "key": "│ 󰏖 packages   │", "keyColor": c_pink },
                        { "type": "terminal", "key": "│ 󰞅 term       │", "keyColor": c_red },
                        { "type": "shell", "key": "│ 󰞷 shell      │", "keyColor": c_yellow },
                        { "type": "custom", "format": "├──────────────┤" },
                        { "type": "cpu", "key": "│ % cpu load   │", "keyColor": c_yellow, "temp": False },
                        { "type": "memory", "key": "│ 󰍛 memory     │", "keyColor": c_red, "format": "{1} / {2} ({3})" },
                        { "type": "disk", "key": "│ 󰋊 SSD1       │", "keyColor": c_green, "format": "{1} / {2} ({3})" },
                        { "type": "custom", "format": "├──────────────┤" },
                        { "type": "colors", "key": "│ 🎨 colors    │", "keyColor": c_yellow, "symbol": "circle" },
                        { "type": "custom", "format": "╰──────────────╯" }
                    ]
                }
            else:
                if "logo" in data and isinstance(data["logo"], dict):
                    data["logo"]["color"] = { "1": accent, "2": sub_accent }
                if "display" in data and isinstance(data["display"], dict):
                    data["display"]["color"] = display_colors
                if "modules" in data and isinstance(data["modules"], list):
                    for mod in data["modules"]:
                        if isinstance(mod, dict) and "type" in mod and mod["type"] in module_color_map:
                            mod["keyColor"] = module_color_map[mod["type"]]

            with open(config_path, 'w', encoding='utf-8') as f:
                json.dump(data, f, indent=4, ensure_ascii=False)
        except Exception:
            pass

def sync_ghostty(bg, surface, current_line, fg, accent, sub_accent, is_dark=True, variant_name=""):
    ghostty_dir = os.path.expanduser('~/.config/ghostty')
    os.makedirs(ghostty_dir, exist_ok=True)
    conf_path = os.path.join(ghostty_dir, 'config')

    v_lower = (variant_name or "").lower()
    if is_dark:
        c_red = "#ff9580"
        c_green = "#8aff80"
        c_yellow = "#ffff80"
        c_cyan = "#80ffea"
        c_white = fg
        c_white_intense = "#ffffff"
    elif "nostalgia" in v_lower:
        c_red = "#af3a03"
        c_green = "#79740e"
        c_yellow = "#b57614"
        c_cyan = "#427b58"
        c_white = "#362828"
        c_white_intense = "#1c1917"
    else:
        c_red = "#b91c1c"
        c_green = "#15803d"
        c_yellow = "#b45309"
        c_cyan = "#0e7490"
        c_white = fg
        c_white_intense = "#0f172a"
    
    config_content = f"""# Auto-generated by Quickshell Theme Engine
background = {bg}
foreground = {fg}
selection-background = {current_line}
selection-foreground = {fg}
cursor-color = {accent}
palette = 0={bg}
palette = 1={c_red}
palette = 2={c_green}
palette = 3={c_yellow}
palette = 4={accent}
palette = 5={sub_accent}
palette = 6={c_cyan}
palette = 7={fg}
palette = 8={current_line}
palette = 9={c_red}
palette = 10={c_green}
palette = 11={c_yellow}
palette = 12={accent}
palette = 13={sub_accent}
palette = 14={c_cyan}
palette = 15={c_white_intense}
"""
    try:
        with open(conf_path, 'w') as f:
            f.write(config_content)
    except Exception:
        pass

def sync_micro(bg, surface, current_line, fg, accent, sub_accent):
    micro_dir = os.path.expanduser('~/.config/micro')
    colors_dir = os.path.join(micro_dir, 'colorschemes')
    os.makedirs(colors_dir, exist_ok=True)
    
    colorscheme = f"""color-link default "{fg},{bg}"
color-link comment "#7970a9"
color-link identifier "{sub_accent}"
color-link constant "{sub_accent}"
color-link statement "{accent}"
color-link symbol "{sub_accent}"
color-link preproc "{sub_accent}"
color-link type "{accent}"
color-link special "{sub_accent}"
color-link ignore "default"
color-link error "bold #ff9580"
color-link todo "bold #ffff80"
color-link indent-char "{current_line}"
color-link line-number "{current_line}"
color-link current-line-number "{accent}"
color-link statusline "{fg},{surface}"
color-link tabbar "{fg},{bg}"
color-link cursor-line "{surface}"
color-link color-column "{surface}"
color-link divider "{current_line}"
"""
    try:
        with open(os.path.join(colors_dir, 'quickshell.micro'), 'w') as f:
            f.write(colorscheme)
    except Exception:
        pass

    settings_file = os.path.join(micro_dir, 'settings.json')
    if os.path.exists(settings_file):
        try:
            import json
            with open(settings_file, 'r') as f:
                data = json.load(f)
            data["colorscheme"] = "quickshell"
            with open(settings_file, 'w') as f:
                json.dump(data, f, indent=4)
        except Exception:
            pass
    else:
        try:
            import json
            with open(settings_file, 'w') as f:
                json.dump({"colorscheme": "quickshell"}, f, indent=4)
        except Exception:
            pass

def sync_konsole(bg, surface, current_line, fg, accent, sub_accent, is_dark=True, variant_name=""):
    konsole_dir = os.path.expanduser('~/.local/share/konsole')
    os.makedirs(konsole_dir, exist_ok=True)

    v_lower = (variant_name or "").lower()
    if is_dark:
        c_red = "#ff9580"
        c_green = "#8aff80"
        c_yellow = "#ffff80"
        c_blue = accent
        c_magenta = sub_accent
        c_cyan = "#80ffea"
        c_white = fg
        c_white_intense = "#ffffff"
        c_black = bg
        c_black_intense = current_line
    elif "nostalgia" in v_lower:
        c_red = "#af3a03"
        c_green = "#79740e"
        c_yellow = "#b57614"
        c_blue = "#d35b80"
        c_magenta = "#8f3f71"
        c_cyan = "#427b58"
        c_white = "#1c1917"
        c_white_intense = "#1c1917"
        c_black = "#3c3836"
        c_black_intense = "#d5c4a1"
    else:
        c_red = "#b91c1c"
        c_green = "#15803d"
        c_yellow = "#b45309"
        c_blue = accent
        c_magenta = sub_accent
        c_cyan = "#0e7490"
        c_white = "#0f172a"
        c_white_intense = "#0f172a"
        c_black = fg
        c_black_intense = current_line

    colorscheme = f"""[Background]
Color={bg}

[BackgroundFaint]
Color={surface}

[BackgroundIntense]
Color={surface}

[Color0]
Color={c_black}

[Color0Faint]
Color={c_black}

[Color0Intense]
Color={c_black_intense}

[Color1]
Color={c_red}

[Color1Faint]
Color={c_red}

[Color1Intense]
Color={c_red}

[Color2]
Color={c_green}

[Color2Faint]
Color={c_green}

[Color2Intense]
Color={c_green}

[Color3]
Color={c_yellow}

[Color3Faint]
Color={c_yellow}

[Color3Intense]
Color={c_yellow}

[Color4]
Color={c_blue}

[Color4Faint]
Color={c_blue}

[Color4Intense]
Color={c_blue}

[Color5]
Color={c_magenta}

[Color5Faint]
Color={c_magenta}

[Color5Intense]
Color={c_magenta}

[Color6]
Color={c_cyan}

[Color6Faint]
Color={c_cyan}

[Color6Intense]
Color={c_cyan}

[Color7]
Color={fg}

[Color7Faint]
Color={fg}

[Color7Intense]
Color={c_white_intense}

[Foreground]
Color={fg}

[ForegroundFaint]
Color={fg}

[ForegroundIntense]
Color={c_white_intense}

[General]
Description=Quickshell Dynamic Theme
Opacity=1
Wallpaper=
"""
    try:
        with open(os.path.join(konsole_dir, 'Quickshell.colorscheme'), 'w') as f:
            f.write(colorscheme)

        # Deploy Quickshell.profile
        profile_content = """[General]
Name=Quickshell
Parent=FALLBACK/
ColorScheme=Quickshell

[Appearance]
ColorScheme=Quickshell
Font=Monospace,10,-1,5,50,0,0,0,0,0
"""
        with open(os.path.join(konsole_dir, 'Quickshell.profile'), 'w') as f:
            f.write(profile_content)

        # Set Quickshell.profile as default in ~/.config/konsolerc
        subprocess.run(["kwriteconfig6", "--file", "konsolerc", "--group", "Desktop Entry", "--key", "DefaultProfile", "Quickshell.profile"], capture_output=True)

        # Signal live open Konsole sessions over D-Bus to switch to Quickshell profile immediately
        res = subprocess.check_output(["qdbus"], text=True, stderr=subprocess.DEVNULL)
        for line in res.splitlines():
            svc = line.strip()
            if "org.kde.konsole" in svc:
                try:
                    sessions = subprocess.check_output(["qdbus", svc], text=True, stderr=subprocess.DEVNULL)
                    for s_line in sessions.splitlines():
                        if "/Sessions/" in s_line:
                            s_path = s_line.strip()
                            subprocess.run(["qdbus", svc, s_path, "org.kde.konsole.Session.setProfile", "Quickshell"], capture_output=True)
                except Exception:
                    pass
    except Exception:
        pass

def sync_xresources(bg, surface, current_line, fg, accent, sub_accent, is_dark=True, variant_name=""):
    xres_path = os.path.expanduser('~/.Xresources')
    v_lower = (variant_name or "").lower()
    if is_dark:
        c_red = "#ff9580"
        c_green = "#8aff80"
        c_yellow = "#ffff80"
        c_cyan = "#80ffea"
        c_white = fg
        c_white_intense = "#ffffff"
    elif "nostalgia" in v_lower:
        c_red = "#af3a03"
        c_green = "#79740e"
        c_yellow = "#b57614"
        c_cyan = "#427b58"
        c_white = "#362828"
        c_white_intense = "#1c1917"
    else:
        c_red = "#b91c1c"
        c_green = "#15803d"
        c_yellow = "#b45309"
        c_cyan = "#0e7490"
        c_white = fg
        c_white_intense = "#0f172a"

    xres_content = f"""! Auto-generated by Quickshell Theme Engine
*.background: {bg}
*.foreground: {fg}
*.cursorColor: {accent}
*.color0: {bg}
*.color1: {c_red}
*.color2: {c_green}
*.color3: {c_yellow}
*.color4: {accent}
*.color5: {sub_accent}
*.color6: {c_cyan}
*.color7: {fg}
*.color8: {current_line}
*.color9: {c_red}
*.color10: {c_green}
*.color11: {c_yellow}
*.color12: {accent}
*.color13: {sub_accent}
*.color14: {c_cyan}
*.color15: {c_white_intense}
"""
    try:
        with open(xres_path, 'w') as f:
            f.write(xres_content)
        subprocess.run(["xrdb", "-merge", xres_path], check=False, stderr=subprocess.DEVNULL)
    except Exception:
        pass

def sync_obsidian(bg, surface, current_line, fg, accent, sub_accent, is_dark):
    import json
    home = os.path.expanduser('~')

    # CSS Template for Obsidian Vaults
    obsidian_css = f"""/* Auto-generated by Quickshell Theme Engine */
body, .theme-dark, .theme-light, :root, html {{
    --bg-primary: {bg} !important;
    --bg-primary-alt: {surface} !important;
    --bg-secondary: {surface} !important;
    --bg-secondary-alt: {current_line} !important;

    --background-primary: {bg} !important;
    --background-primary-alt: {surface} !important;
    --background-secondary: {surface} !important;
    --background-secondary-alt: {current_line} !important;
    --background-modifier-border: {current_line} !important;
    --background-modifier-border-hover: {accent} !important;
    --background-modifier-border-focus: {accent} !important;
    --background-modifier-form-field: {surface} !important;
    --background-modifier-form-field-highlighted: {current_line} !important;

    --text-normal: {fg} !important;
    --text-muted: {fg} !important;
    --text-faint: {current_line} !important;

    --interactive-accent: {accent} !important;
    --interactive-accent-hover: {sub_accent} !important;
    --interactive-hover: {current_line} !important;

    --text-accent: {accent} !important;
    --text-accent-hover: {sub_accent} !important;

    --color-red: #ff9580 !important;
    --color-orange: #ffca80 !important;
    --color-yellow: #ffff80 !important;
    --color-green: #8aff80 !important;
    --color-cyan: #80ffea !important;
    --color-blue: {accent} !important;
    --color-purple: {accent} !important;
    --color-pink: {sub_accent} !important;

    --nav-item-color-active: {accent} !important;
    --nav-item-background-active: {surface} !important;
    --tab-text-color-active: {accent} !important;
    --tab-container-background: {bg} !important;

    --bold-color: {accent} !important;
    --italic-color: {sub_accent} !important;
    --title-color: {fg} !important;
    --h1-color: {accent} !important;
    --h2-color: {sub_accent} !important;
    --h3-color: #80ffea !important;
    --h4-color: #8aff80 !important;
    --h5-color: #ffca80 !important;
    --h6-color: {fg} !important;

    --code-normal: {accent} !important;
    --code-background: {surface} !important;

    --scrollbar-thumb-bg: {current_line} !important;
    --status-bar-bg: {surface} !important;
    --titlebar-background: {bg} !important;
    --titlebar-background-focused: {bg} !important;
}}

.app-container, .workspace, .workspace-split, .workspace-leaf, .workspace-leaf-content,
.view-header, .view-content, .markdown-source-view, .cm-editor, .cm-scroller, .cm-content,
.nav-files-container, .workspace-ribbon {{
    background-color: {bg} !important;
    color: {fg} !important;
}}

.sidebar-toggle-button, .workspace-ribbon, .nav-folder-title, .nav-file-title, .view-header {{
    background-color: {surface} !important;
}}
"""

    vault_dirs = set()

    # Search common Documents and Home locations for .obsidian folders
    search_bases = [
        home,
        os.path.join(home, 'Documents'),
        os.path.join(home, 'Obsidian'),
        os.path.join(home, 'Vaults'),
        os.path.join(home, 'Notes'),
        os.path.join(home, 'studies'),
        os.path.join(home, 'Documents', 'studies'),
        os.path.join(home, '.var', 'app', 'md.obsidian.Obsidian', 'config', 'obsidian'),
        os.path.join(home, '.config', 'obsidian')
    ]

    for sb in search_bases:
        if os.path.exists(sb):
            obs_dir = os.path.join(sb, '.obsidian')
            if os.path.isdir(obs_dir):
                vault_dirs.add(obs_dir)
            try:
                for child in os.listdir(sb):
                    child_path = os.path.join(sb, child)
                    if os.path.isdir(child_path):
                        child_obs = os.path.join(child_path, '.obsidian')
                        if os.path.isdir(child_obs):
                            vault_dirs.add(child_obs)
            except Exception: pass

    # Search registered vault paths in obsidian.json
    obsidian_json_paths = [
        os.path.join(home, '.config', 'obsidian', 'obsidian.json'),
        os.path.join(home, '.var', 'app', 'md.obsidian.Obsidian', 'config', 'obsidian', 'obsidian.json')
    ]

    for ojp in obsidian_json_paths:
        if os.path.exists(ojp):
            try:
                with open(ojp, 'r', encoding='utf-8') as f:
                    data = json.load(f)
                    vaults = data.get('vaults', {})
                    if isinstance(vaults, dict):
                        for v_id, v_info in vaults.items():
                            v_path = v_info.get('path')
                            if v_path:
                                obs_folder = os.path.join(v_path, '.obsidian')
                                if os.path.isdir(obs_folder):
                                    vault_dirs.add(obs_folder)
            except Exception: pass

    # Apply quickshell-theme.css and update appearance.json to enable the snippet automatically
    for obs_dir in vault_dirs:
        try:
            snippets_dir = os.path.join(obs_dir, 'snippets')
            os.makedirs(snippets_dir, exist_ok=True)

            css_path = os.path.join(snippets_dir, 'quickshell-theme.css')
            with open(css_path, 'w', encoding='utf-8') as f:
                f.write(obsidian_css)

            app_file = os.path.join(obs_dir, 'appearance.json')
            app_data = {}
            if os.path.exists(app_file):
                try:
                    with open(app_file, 'r', encoding='utf-8') as f:
                        app_data = json.load(f)
                except Exception:
                    app_data = {}

            enabled_snippets = app_data.get('enabledCssSnippets', [])
            if not isinstance(enabled_snippets, list):
                enabled_snippets = []

            if 'quickshell-theme' not in enabled_snippets:
                enabled_snippets.append('quickshell-theme')

            app_data['enabledCssSnippets'] = enabled_snippets
            app_data['baseOption'] = 'dark' if is_dark else 'light'

            with open(app_file, 'w', encoding='utf-8') as f:
                json.dump(app_data, f, indent=2)

            # Touch appearance.json to trigger Obsidian live snippet reload
            os.utime(app_file, None)
        except Exception: pass

def sync_papirus_folders(variant_name, accent="#ff79c6", sub_accent="#bd93f9", is_dark=True):
    """
    Colorizes Papirus icon theme folders to match the active color scheme.
    Uses papirus-folders utility and refreshes system icon cache.
    """
    import os, subprocess, shutil

    if not shutil.which("papirus-folders"):
        return

    name_lower = variant_name.lower().strip()

    color_map = {
        "zoey pink": "pink",
        "zoey night": "pink",
        "emo zoey": "magenta",

        # Dracula Pro
        "pro": "violet",
        "blade": "teal",
        "buff": "pink",
        "cyan": "cyan",
        "lincoln": "yellow",
        "morpheus": "orange",
        "alucard": "violet",

        # Gruvbox
        "gruvbox dark": "orange",
        "gruvbox material": "green",
        "gruvbox light": "brown",

        # Rosé Pine
        "rosé pine moon": "pink",
        "rosé pine dawn": "carmine",
        "rosé pine": "pink",
        "rose pine moon": "pink",
        "rose pine dawn": "carmine",
        "rose pine": "pink",

        # Catppuccin
        "catppuccin mocha": "violet",
        "catppuccin macchiato": "magenta",
        "catppuccin latte": "blue",

        # Everforest
        "everforest dark": "green",
        "everforest light": "green",

        # Tokyo Night
        "tokyo night storm": "indigo",
        "tokyo night day": "blue",
        "tokyo night": "indigo",

        # Nord
        "nord dark": "nordic",
        "nord light": "nordic",

        # Solarized
        "solarized dark": "cyan",
        "solarized light": "cyan",

        # One Theme
        "one dark pro": "blue",
        "one light": "blue",

        # Monokai & Cyberpunk
        "monokai pro": "yellow",
        "cyberpunk neon": "magenta",
    }

    chosen_color = color_map.get(name_lower)

    if not chosen_color:
        for key, col in color_map.items():
            if key in name_lower:
                chosen_color = col
                break

    if not chosen_color:
        hex_c = accent.lstrip('#')
        if len(hex_c) == 6:
            r = int(hex_c[0:2], 16) / 255.0
            g = int(hex_c[2:4], 16) / 255.0
            b = int(hex_c[4:6], 16) / 255.0

            if r > 0.8 and g < 0.5 and b > 0.6:
                chosen_color = "pink"
            elif r > 0.5 and b > 0.7:
                chosen_color = "violet"
            elif b > 0.7 and g > 0.7:
                chosen_color = "cyan"
            elif b > 0.7:
                chosen_color = "blue"
            elif g > 0.7 and r < 0.6:
                chosen_color = "green"
            elif r > 0.8 and g > 0.7:
                chosen_color = "yellow"
            elif r > 0.8 and g > 0.4:
                chosen_color = "orange"
            elif r > 0.8:
                chosen_color = "red"
            else:
                chosen_color = "blue"
        else:
            chosen_color = "blue"

    target_theme = "Papirus-Dark" if is_dark else "Papirus-Light"
    try:
        subprocess.run(["papirus-folders", "-C", chosen_color, "-t", target_theme, "-u"], capture_output=True, timeout=15)
    except Exception:
        pass

    # Signal GTK and KDE to reload icon theme
    try:
        subprocess.run(["gsettings", "set", "org.gnome.desktop.interface", "icon-theme", target_theme], capture_output=True)
        subprocess.run(["kwriteconfig6", "--group", "Icons", "--key", "Theme", target_theme], capture_output=True)
    except Exception:
        pass

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--bg', required=True)
    parser.add_argument('--surface', required=True)
    parser.add_argument('--currentLine', required=True)
    parser.add_argument('--fg', required=True)
    parser.add_argument('--accent', required=True)
    parser.add_argument('--subAccent', required=True)
    parser.add_argument('--isDark', required=True)
    parser.add_argument('--variantName', default='Pro')
    args = parser.parse_args()

    is_dark = args.isDark.lower() == 'true'
    sync_gtk(args.bg, args.surface, args.currentLine, args.fg, args.accent, is_dark)
    sync_kde(args.bg, args.surface, args.currentLine, args.fg, args.accent, args.subAccent, is_dark, args.variantName)
    sync_alacritty(args.bg, args.surface, args.currentLine, args.fg, args.accent, args.subAccent, is_dark, args.variantName)
    sync_discord(args.bg, args.surface, args.currentLine, args.fg, args.accent, args.subAccent, is_dark)
    sync_vscode(args.bg, args.surface, args.currentLine, args.fg, args.accent, args.subAccent, is_dark, args.variantName)
    sync_zen(args.bg, args.surface, args.currentLine, args.fg, args.accent, args.subAccent, is_dark)
    sync_feishin(args.bg, args.surface, args.currentLine, args.fg, args.accent, args.subAccent, is_dark, args.variantName)
    sync_obsidian(args.bg, args.surface, args.currentLine, args.fg, args.accent, args.subAccent, is_dark)
    sync_starship(args.bg, args.surface, args.currentLine, args.fg, args.accent, args.subAccent, is_dark, args.variantName)
    sync_vim(args.bg, args.surface, args.currentLine, args.fg, args.accent, args.subAccent, is_dark)
    sync_btop(args.bg, args.surface, args.currentLine, args.fg, args.accent, args.subAccent)
    sync_fastfetch(args.bg, args.surface, args.currentLine, args.fg, args.accent, args.subAccent, is_dark, args.variantName)
    sync_ghostty(args.bg, args.surface, args.currentLine, args.fg, args.accent, args.subAccent, is_dark, args.variantName)
    sync_micro(args.bg, args.surface, args.currentLine, args.fg, args.accent, args.subAccent)
    sync_konsole(args.bg, args.surface, args.currentLine, args.fg, args.accent, args.subAccent, is_dark, args.variantName)
    sync_xresources(args.bg, args.surface, args.currentLine, args.fg, args.accent, args.subAccent, is_dark, args.variantName)
    sync_papirus_folders(args.variantName, args.accent, args.subAccent, is_dark)

if __name__ == '__main__':
    main()
