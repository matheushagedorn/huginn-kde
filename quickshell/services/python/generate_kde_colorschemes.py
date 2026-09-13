#!/usr/bin/env python3
import os, re

variants = [

    # Dracula Pro
    {'name': 'Pro',              'isDark': True,  'accent': '#9580ff', 'subAccent': '#ff80bf', 'bg': '#22212c', 'surface': '#2b2938', 'currentLine': '#454158', 'fg': '#f8f8f2'},
    {'name': 'Blade',            'isDark': True,  'accent': '#80ffea', 'subAccent': '#8aff80', 'bg': '#212c2a', 'surface': '#293835', 'currentLine': '#415854', 'fg': '#f8f8f2'},
    {'name': 'Buff',             'isDark': True,  'accent': '#ffca80', 'subAccent': '#ff9580', 'bg': '#2a212c', 'surface': '#352938', 'currentLine': '#544158', 'fg': '#f8f8f2'},
    {'name': 'Cyan',             'isDark': True,  'accent': '#80ffea', 'subAccent': '#9580ff', 'bg': '#0b0d0f', 'surface': '#181b1f', 'currentLine': '#414d58', 'fg': '#f8f8f2'},
    {'name': 'Lincoln',          'isDark': True,  'accent': '#ffff80', 'subAccent': '#8aff80', 'bg': '#2c2a21', 'surface': '#38352a', 'currentLine': '#585441', 'fg': '#f8f8f2'},
    {'name': 'Morpheus',         'isDark': True,  'accent': '#ff9580', 'subAccent': '#ffca80', 'bg': '#2c2122', 'surface': '#382a2b', 'currentLine': '#584145', 'fg': '#f8f8f2'},
    {'name': 'Alucard',          'isDark': False, 'accent': '#6272a4', 'subAccent': '#ff79c6', 'bg': '#f8f8f2', 'surface': '#e6e6e6', 'currentLine': '#d0d0d0', 'fg': '#282a36'},

    # Gruvbox
    {'name': 'Gruvbox Dark',     'isDark': True,  'accent': '#fe8019', 'subAccent': '#fabd2f', 'bg': '#282828', 'surface': '#3c3836', 'currentLine': '#504945', 'fg': '#ebdbb2'},
    {'name': 'Gruvbox Material', 'isDark': True,  'accent': '#ea698c', 'subAccent': '#a9b665', 'bg': '#1d2021', 'surface': '#282828', 'currentLine': '#3c3836', 'fg': '#ddc7a1'},
    {'name': 'Gruvbox Light',    'isDark': False, 'accent': '#af3a03', 'subAccent': '#b57614', 'bg': '#fbf1c7', 'surface': '#ebdbb2', 'currentLine': '#d5c4a1', 'fg': '#3c3836'},

    # Rosé Pine
    {'name': 'Rosé Pine',        'isDark': True,  'accent': '#ebbcba', 'subAccent': '#c4a7e7', 'bg': '#191724', 'surface': '#1f1d2e', 'currentLine': '#26233a', 'fg': '#e0def4'},
    {'name': 'Rosé Pine Moon',   'isDark': True,  'accent': '#ea9a97', 'subAccent': '#c4a7e7', 'bg': '#232136', 'surface': '#2a273f', 'currentLine': '#393552', 'fg': '#e0def4'},
    {'name': 'Rosé Pine Dawn',   'isDark': False, 'accent': '#d7827e', 'subAccent': '#907aa9', 'bg': '#faf4ed', 'surface': '#f2e9e1', 'currentLine': '#e4d7d0', 'fg': '#575279'},

    # Catppuccin
    {'name': 'Catppuccin Mocha',    'isDark': True,  'accent': '#cba6f7', 'subAccent': '#89b4fa', 'bg': '#1e1e2e', 'surface': '#313244', 'currentLine': '#45475a', 'fg': '#cdd6f4'},
    {'name': 'Catppuccin Macchiato','isDark': True,  'accent': '#f5bde6', 'subAccent': '#8aadf4', 'bg': '#24273a', 'surface': '#363a4f', 'currentLine': '#494d64', 'fg': '#cad3f5'},
    {'name': 'Catppuccin Latte',    'isDark': False, 'accent': '#8839ef', 'subAccent': '#1e66f5', 'bg': '#eff1f5', 'surface': '#e6e9ef', 'currentLine': '#ccd0da', 'fg': '#4c4f69'},

    # Everforest
    {'name': 'Everforest Dark',  'isDark': True,  'accent': '#a7c080', 'subAccent': '#7fbbb3', 'bg': '#2d353b', 'surface': '#343f44', 'currentLine': '#3d484d', 'fg': '#d3c6aa'},
    {'name': 'Everforest Light', 'isDark': False, 'accent': '#8da101', 'subAccent': '#35a77c', 'bg': '#fdf6e3', 'surface': '#f4e0c5', 'currentLine': '#e5d5c5', 'fg': '#5c6a72'},

    # Tokyo Night
    {'name': 'Tokyo Night',      'isDark': True,  'accent': '#7aa2f7', 'subAccent': '#bb9af7', 'bg': '#1a1b26', 'surface': '#24283b', 'currentLine': '#414868', 'fg': '#c0caf5'},
    {'name': 'Tokyo Night Storm','isDark': True,  'accent': '#7aa2f7', 'subAccent': '#7dcfff', 'bg': '#24283b', 'surface': '#1f2335', 'currentLine': '#414868', 'fg': '#c0caf5'},
    {'name': 'Tokyo Night Day',  'isDark': False, 'accent': '#2e7de9', 'subAccent': '#9854f6', 'bg': '#e1e2e7', 'surface': '#d5d6db', 'currentLine': '#c4c8da', 'fg': '#3760bf'},

    # Nord
    {'name': 'Nord Dark',        'isDark': True,  'accent': '#88c0d0', 'subAccent': '#b48ead', 'bg': '#2e3440', 'surface': '#3b4252', 'currentLine': '#434c5e', 'fg': '#eceff4'},
    {'name': 'Nord Light',       'isDark': False, 'accent': '#5e81ac', 'subAccent': '#88c0d0', 'bg': '#eceff4', 'surface': '#e5e9f0', 'currentLine': '#d8dee9', 'fg': '#2e3440'},

    # Solarized
    {'name': 'Solarized Dark',   'isDark': True,  'accent': '#268bd2', 'subAccent': '#2aa198', 'bg': '#002b36', 'surface': '#073642', 'currentLine': '#586e75', 'fg': '#839496'},
    {'name': 'Solarized Light',  'isDark': False, 'accent': '#268bd2', 'subAccent': '#d33682', 'bg': '#fdf6e3', 'surface': '#eee8d5', 'currentLine': '#93a1a1', 'fg': '#657b83'},

    # One Theme
    {'name': 'One Dark Pro',     'isDark': True,  'accent': '#61afef', 'subAccent': '#c678dd', 'bg': '#282c34', 'surface': '#21252b', 'currentLine': '#3e4451', 'fg': '#abb2bf'},
    {'name': 'One Light',        'isDark': False, 'accent': '#4078f2', 'subAccent': '#a626a4', 'bg': '#fafafa', 'surface': '#f0f0f0', 'currentLine': '#e5e5e6', 'fg': '#383a42'},

    # Monokai
    {'name': 'Monokai Pro',      'isDark': True,  'accent': '#ffd866', 'subAccent': '#ff6188', 'bg': '#2d2a2e', 'surface': '#3a3a3a', 'currentLine': '#4a4a4a', 'fg': '#fcfcfa'},

    # Cyberpunk
    {'name': 'Cyberpunk Neon',   'isDark': True,  'accent': '#ff007f', 'subAccent': '#00f0ff', 'bg': '#120e24', 'surface': '#22194d', 'currentLine': '#3a2a80', 'fg': '#00ff9f'}
]

def hex2rgb(hex_str):
    h = hex_str.lstrip('#')
    return [int(h[i:i+2], 16) for i in (0, 2, 4)]

def fmt_rgb(hex_str):
    return ','.join(str(x) for x in hex2rgb(hex_str))

def generate_all():
    target_dir = os.path.expanduser('~/.local/share/color-schemes')
    os.makedirs(target_dir, exist_ok=True)

    for v in variants:
        clean_id = re.sub(r'[^a-zA-Z0-9]', '', v['name'])
        display_name = f"Huginn {v['name']}"
        
        bg_rgb = fmt_rgb(v['bg'])
        surface_rgb = fmt_rgb(v['surface'])
        line_rgb = fmt_rgb(v['currentLine'])
        fg_rgb = fmt_rgb(v['fg'])
        accent_rgb = fmt_rgb(v['accent'])
        sub_rgb = fmt_rgb(v['subAccent'])
        
        colors_content = f"""[General]
Name={display_name}
ColorScheme={clean_id}
accentColor={accent_rgb}

[Colors:Button]
BackgroundAlternate={surface_rgb}
BackgroundNormal={line_rgb}
DecorationFocus={accent_rgb}
DecorationHover={sub_rgb}
ForegroundActive={accent_rgb}
ForegroundInactive={line_rgb}
ForegroundLink={accent_rgb}
ForegroundNegative=255,100,100
ForegroundNeutral=255,200,100
ForegroundNormal={fg_rgb}
ForegroundPositive=100,255,100
ForegroundVisited={sub_rgb}

[Colors:Complementary]
BackgroundAlternate={surface_rgb}
BackgroundNormal={bg_rgb}
DecorationFocus={accent_rgb}
DecorationHover={sub_rgb}
ForegroundActive={accent_rgb}
ForegroundInactive={line_rgb}
ForegroundLink={accent_rgb}
ForegroundNegative=255,100,100
ForegroundNeutral=255,200,100
ForegroundNormal={fg_rgb}
ForegroundPositive=100,255,100
ForegroundVisited={sub_rgb}

[Colors:Header]
BackgroundAlternate={surface_rgb}
BackgroundNormal={bg_rgb}
DecorationFocus={accent_rgb}
DecorationHover={sub_rgb}
ForegroundActive={accent_rgb}
ForegroundInactive={line_rgb}
ForegroundLink={accent_rgb}
ForegroundNegative=255,100,100
ForegroundNeutral=255,200,100
ForegroundNormal={fg_rgb}
ForegroundPositive=100,255,100
ForegroundVisited={sub_rgb}

[Colors:Selection]
BackgroundAlternate={accent_rgb}
BackgroundNormal={accent_rgb}
DecorationFocus={accent_rgb}
DecorationHover={sub_rgb}
ForegroundActive=255,255,255
ForegroundInactive={fg_rgb}
ForegroundLink={sub_rgb}
ForegroundNegative=255,100,100
ForegroundNeutral=255,200,100
ForegroundNormal={'255,255,255' if v['isDark'] else '0,0,0'}

[Colors:View]
BackgroundAlternate={surface_rgb}
BackgroundNormal={bg_rgb}
DecorationFocus={accent_rgb}
DecorationHover={sub_rgb}
ForegroundActive={accent_rgb}
ForegroundInactive={line_rgb}
ForegroundLink={accent_rgb}
ForegroundNegative=255,100,100
ForegroundNeutral=255,200,100
ForegroundNormal={fg_rgb}
ForegroundPositive=100,255,100
ForegroundVisited={sub_rgb}

[Colors:Window]
BackgroundAlternate={surface_rgb}
BackgroundNormal={bg_rgb}
DecorationFocus={accent_rgb}
DecorationHover={sub_rgb}
ForegroundActive={accent_rgb}
ForegroundInactive={line_rgb}
ForegroundLink={accent_rgb}
ForegroundNegative=255,100,100
ForegroundNeutral=255,200,100
ForegroundNormal={fg_rgb}
ForegroundPositive=100,255,100
ForegroundVisited={sub_rgb}
"""
        filepath = os.path.join(target_dir, f"{clean_id}.colors")
        with open(filepath, 'w') as f:
            f.write(colors_content)

if __name__ == '__main__':
    generate_all()
