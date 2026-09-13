#!/usr/bin/env python3
import os
import signal
import getpass
import time
import sys
import glob
import shutil
import subprocess
import re

# Variant Palettes Mapping
PALETTES = {

    # Dracula Pro
    'Pro':               ['#22212c', '#2b2938', '#454158', '#f8f8f2', '#9580ff', '#ff80bf', '#80ffea', '#ffff80', '#ff9580'],
    'Blade':             ['#212c2a', '#293835', '#415854', '#f8f8f2', '#80ffea', '#8aff80', '#9580ff', '#ffff80', '#ff9580'],
    'Buff':              ['#2a212c', '#352938', '#544158', '#f8f8f2', '#ffca80', '#ff9580', '#ff80bf', '#9580ff', '#80ffea'],
    'Cyan':              ['#0b0d0f', '#181b1f', '#414d58', '#f8f8f2', '#80ffea', '#9580ff', '#8aff80', '#ffff80', '#ff9580'],
    'Lincoln':           ['#2c2a21', '#38352a', '#585441', '#f8f8f2', '#ffff80', '#8aff80', '#ffca80', '#ff9580', '#ff80bf'],
    'Morpheus':          ['#2c2122', '#382a2b', '#584145', '#f8f8f2', '#ff9580', '#ffca80', '#ff80bf', '#9580ff', '#ffff80'],
    'Alucard':           ['#f8f8f2', '#e6e6e6', '#d0d0d0', '#282a36', '#6272a4', '#ff79c6', '#8be9fd', '#50fa7b', '#ff5555'],

    # Everblush
    'Everblush':         ['#141b1e', '#232a2d', '#2d3437', '#dadada', '#8ccf7e', '#67b0e8', '#67cbe8', '#e59e67', '#c47fd5', '#e57474', '#e5c76b'],

    # Gruvbox
    'Gruvbox Dark':      ['#282828', '#3c3836', '#504945', '#ebdbb2', '#fe8019', '#fabd2f', '#b8bb26', '#83a598', '#d3869b', '#fb4934'],
    'Gruvbox Material':  ['#1d2021', '#282828', '#3c3836', '#ddc7a1', '#ea698c', '#a9b665', '#d8a657', '#7daea3', '#d3869b', '#e78a4e'],
    'Gruvbox Light':     ['#fbf1c7', '#ebdbb2', '#d5c4a1', '#3c3836', '#af3a03', '#b57614', '#9d0006', '#076678', '#79740e', '#8f3f71'],

    # Rosé Pine
    'Rosé Pine':         ['#191724', '#1f1d2e', '#26233a', '#e0def4', '#ebbcba', '#c4a7e7', '#9ccfd8', '#eb6f92', '#f6c177', '#31748f'],
    'Rosé Pine Moon':    ['#232136', '#2a273f', '#393552', '#e0def4', '#ea9a97', '#c4a7e7', '#3e8fb0', '#eb6f92', '#f6c177', '#9ccfd8'],
    'Rosé Pine Dawn':    ['#faf4ed', '#f2e9e1', '#e4d7d0', '#575279', '#d7827e', '#907aa9', '#286983', '#b4637a', '#ea9d34', '#56949f'],

    # Catppuccin
    'Catppuccin Mocha':  ['#1e1e2e', '#313244', '#45475a', '#cdd6f4', '#cba6f7', '#89b4fa', '#f38ba8', '#fab387', '#a6e3a1', '#94e2d5'],
    'Catppuccin Macchiato': ['#24273a', '#363a4f', '#494d64', '#cad3f5', '#f5bde6', '#8aadf4', '#ed8796', '#f5a97f', '#a6da95', '#8bd5ca'],
    'Catppuccin Latte':  ['#eff1f5', '#e6e9ef', '#ccd0da', '#4c4f69', '#8839ef', '#1e66f5', '#d20f39', '#fe640b', '#40a02b', '#179299'],

    # Everforest
    'Everforest Dark':   ['#2d353b', '#343f44', '#3d484d', '#d3c6aa', '#a7c080', '#7fbbb3', '#e67e80', '#dbbc7f', '#e6935c', '#a7c080'],
    'Everforest Light':  ['#fdf6e3', '#f4e0c5', '#e5d5c5', '#5c6a72', '#8da101', '#35a77c', '#f57d00', '#df69ba', '#3a94c5', '#df69ba'],

    # Tokyo Night
    'Tokyo Night':       ['#1a1b26', '#24283b', '#414868', '#c0caf5', '#7aa2f7', '#bb9af7', '#f7768e', '#ff9e64', '#9ece6a', '#7dcfff'],
    'Tokyo Night Storm': ['#24283b', '#1f2335', '#414868', '#c0caf5', '#7aa2f7', '#7dcfff', '#f7768e', '#bb9af7', '#9ece6a', '#e0af68'],
    'Tokyo Night Day':   ['#e1e2e7', '#d5d6db', '#c4c8da', '#3760bf', '#2e7de9', '#9854f6', '#f52a65', '#b15c00', '#587539', '#007197'],

    # Nord
    'Nord Dark':         ['#2e3440', '#3b4252', '#434c5e', '#eceff4', '#88c0d0', '#b48ead', '#bf616a', '#d08770', '#ebcb8b', '#a3be8c'],
    'Nord Light':        ['#eceff4', '#e5e9f0', '#d8dee9', '#2e3440', '#5e81ac', '#88c0d0', '#bf616a', '#b48ead', '#ebcb8b', '#a3be8c'],

    # Solarized
    'Solarized Dark':    ['#002b36', '#073642', '#586e75', '#839496', '#268bd2', '#2aa198', '#cb4b16', '#dc322f', '#859900', '#b58900'],
    'Solarized Light':   ['#fdf6e3', '#eee8d5', '#93a1a1', '#657b83', '#268bd2', '#d33682', '#cb4b16', '#dc322f', '#859900', '#b58900'],

    # One Theme
    'One Dark Pro':      ['#282c34', '#21252b', '#3e4451', '#abb2bf', '#61afef', '#c678dd', '#e06c75', '#d19a66', '#98c379', '#56b6c2'],
    'One Light':         ['#fafafa', '#f0f0f0', '#e5e5e6', '#383a42', '#4078f2', '#a626a4', '#e45649', '#986801', '#50a14f', '#0184bc'],

    # Monokai
    'Monokai Pro':       ['#2d2a2e', '#3a3a3a', '#4a4a4a', '#fcfcfa', '#ffd866', '#ff6188', '#fc9867', '#a9dc76', '#78dce8', '#ab9df2'],

    # Cyberpunk
    'Cyberpunk Neon':    ['#120e24', '#22194d', '#3a2a80', '#00ff9f', '#ff007f', '#00f0ff', '#ffe600', '#ff0055', '#7b00ff']
}

def find_lutgen():
    # Falls back to the real account name instead of a hardcoded one: the
    # upstream default was the original author's username, which silently
    # built paths for a user that does not exist here.
    user = os.environ.get('USER') or getpass.getuser()
    for p in [
        f'/etc/profiles/per-user/{user}/bin/lutgen',
        f'/etc/profiles/per-user/{user}/bin/lutgen-cli',
        '/run/current-system/sw/bin/lutgen',
        '/run/current-system/sw/bin/lutgen-cli',
        os.path.expanduser('~/.nix-profile/bin/lutgen'),
        os.path.expanduser('~/.nix-profile/bin/lutgen-cli'),
        os.path.expanduser('~/.cargo/bin/lutgen'),
        os.path.expanduser('~/.cargo/bin/lutgen-cli'),
        os.path.expanduser('~/.local/bin/lutgen'),
        os.path.expanduser('~/.local/bin/lutgen-cli'),
        '/usr/bin/lutgen',
        '/usr/local/bin/lutgen',
        '/usr/bin/lutgen-cli'
    ]:
        if os.path.exists(p):
            return p
    return shutil.which('lutgen') or shutil.which('lutgen-cli')

def get_palette(variant_name):
    if variant_name in PALETTES:
        return PALETTES[variant_name]
    
    # Dynamic fallback: Parse Theme.qml to support any newly added or custom themes
    theme_qml = os.path.expanduser('~/.config/quickshell/theme/Theme.qml')
    if not os.path.exists(theme_qml):
        theme_qml = os.path.expanduser('~/Documents/themes/quickshell/theme/Theme.qml')

    if os.path.exists(theme_qml):
        try:
            with open(theme_qml, 'r', encoding='utf-8') as f:
                content = f.read()

            pattern = rf'name:\s*"{re.escape(variant_name)}".*?\n'
            match = re.search(pattern, content)
            if match:
                line = match.group(0)
                hexes = re.findall(r'#[0-9a-fA-F]{6}', line)
                if hexes:
                    return hexes
        except Exception:
            pass
    return None

def recolor_image(img_path, palette_hex_list, out_path, remove_original=True):
    lutgen_bin = find_lutgen()
    try:
        if lutgen_bin:
            os.makedirs(os.path.dirname(out_path), exist_ok=True)
            cmd = [lutgen_bin, 'apply', img_path, '-o', out_path, '--'] + palette_hex_list
            res = subprocess.run(cmd, capture_output=True, text=True)
            if res.returncode == 0 and os.path.exists(out_path):
                print(f"[Lutgen Success] {img_path} -> {out_path}", flush=True)
                if remove_original and os.path.exists(img_path) and img_path != out_path:
                    try:
                        os.remove(img_path)
                        print(f"[Cleaned Original] Removed dropped picture: {img_path}", flush=True)
                    except Exception:
                        pass
                return True
    except Exception as e:
        print(f"[Error recoloring] {img_path}: {e}", flush=True)
    return False

def watch_folder():
    base_dirs = [
        os.path.expanduser('~/Pictures/Wallpapers'),
        os.path.expanduser('~/.config/quickshell/wallpapers'),
        os.path.expanduser('~/Documents/themes/quickshell/wallpapers')
    ]
    processed = set()
    
    print(f"[*] Starting Lutgen Auto-Recolor Watcher Daemon...", flush=True)
    
    while True:
        try:
            for base_dir in base_dirs:
                if not os.path.exists(base_dir):
                    continue

                for root, dirs, files in os.walk(base_dir):
                    variant_name = os.path.basename(root)
                    is_root = (root == base_dir)
                    is_custom = (variant_name.lower() == 'custom')

                    for f in files:
                        ext = os.path.splitext(f)[1].lower()
                        if ext in ['.png', '.jpg', '.jpeg', '.webp'] and not f.startswith('lutgen_'):
                            full_path = os.path.join(root, f)
                            if full_path in processed:
                                continue

                            base_name = os.path.splitext(f)[0]
                            recolored_filename = f"lutgen_{base_name}.png"

                            if is_root or is_custom:
                                # When a picture is placed in root Wallpapers folder or Custom, recolor for all variants
                                success_count = 0
                                for v_name, palette in PALETTES.items():
                                    target_dir = os.path.join(base_dir, v_name)
                                    target_file = os.path.join(target_dir, recolored_filename)
                                    if not os.path.exists(target_file):
                                        if recolor_image(full_path, palette, target_file, remove_original=False):
                                            success_count += 1
                                
                                processed.add(full_path)
                                if success_count > 0 and os.path.exists(full_path):
                                    try:
                                        os.remove(full_path)
                                        print(f"[Cleaned Root Original] {full_path}", flush=True)
                                    except Exception:
                                        pass
                            else:
                                # Picture placed in a specific variant folder (e.g. ~/Pictures/Wallpapers/Pro/)
                                palette = get_palette(variant_name)
                                if palette:
                                    target_file = os.path.join(root, recolored_filename)
                                    if not os.path.exists(target_file):
                                        recolor_image(full_path, palette, target_file, remove_original=True)
                                        processed.add(full_path)
        except Exception as e:
            print(f"[Watcher Exception] {e}", flush=True)
            
        time.sleep(2)


def _ensure_single_instance():
    """Replaces any older copy of this script before starting.

    These watchers are long-lived and were being started from more than one
    place, so every shell restart left the previous pair running. Seventeen
    recolor watchers all invoking papirus-folders is how the account got
    locked by faillock once already.
    """
    import glob
    me = os.path.realpath(__file__)
    mypid = os.getpid()
    for entry in glob.glob('/proc/[0-9]*/cmdline'):
        try:
            pid = int(entry.split('/')[2])
            if pid == mypid:
                continue
            argv = open(entry, 'rb').read().split(b'\0')
            if not any(os.path.realpath(a.decode('utf-8', 'replace')) == me
                       for a in argv if a):
                continue
            os.kill(pid, signal.SIGTERM)
        except Exception:
            continue


if __name__ == '__main__':
    _ensure_single_instance()
    watch_folder()
