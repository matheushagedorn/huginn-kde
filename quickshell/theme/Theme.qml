pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../services"

Item {
    id: root

    property string currentVariant: "Pro"
    property string wallpaperPath: "file://" + Quickshell.env("HOME") + "/Pictures/Wallpapers/Pro/lutgen_Pro_wallhaven.png"

    readonly property var themeCategories: [
        "All", "Dracula Pro", "Everblush", "Gruvbox", "Rosé Pine", "Catppuccin", "Everforest", "Tokyo Night", "Nord", "Solarized", "One Theme", "Monokai", "Cyberpunk"
    ]

    readonly property var variants: [

        // Dracula Pro (Official Palette from dracula-pro/design/palette.md)
        { category: "Dracula Pro", name: "Pro",      isDark: true,  accent: "#9580ff", subAccent: "#ff80bf", bg: "#22212c", surface: "#2b2938", currentLine: "#454158", fg: "#f8f8f2", comment: "#7970a9", cyan: "#80ffea", green: "#8aff80", orange: "#ffca80", pink: "#ff80bf", purple: "#9580ff", red: "#ff9580", yellow: "#ffff80" },
        { category: "Dracula Pro", name: "Blade",    isDark: true,  accent: "#80ffea", subAccent: "#8aff80", bg: "#212c2a", surface: "#293835", currentLine: "#415854", fg: "#f8f8f2", comment: "#70a99f", cyan: "#80ffea", green: "#8aff80", orange: "#ffca80", pink: "#ff80bf", purple: "#9580ff", red: "#ff9580", yellow: "#ffff80" },
        { category: "Dracula Pro", name: "Buff",     isDark: true,  accent: "#ff80bf", subAccent: "#ff9580", bg: "#2a212c", surface: "#352938", currentLine: "#544158", fg: "#f8f8f2", comment: "#9f70a9", cyan: "#80ffea", green: "#8aff80", orange: "#ffca80", pink: "#ff80bf", purple: "#9580ff", red: "#ff9580", yellow: "#ffff80" },
        { category: "Dracula Pro", name: "Cyan",     isDark: true,  accent: "#80ffea", subAccent: "#9580ff", bg: "#0b0d0f", surface: "#181b1f", currentLine: "#414d58", fg: "#f8f8f2", comment: "#708ca9", cyan: "#80ffea", green: "#8aff80", orange: "#ffca80", pink: "#ff80bf", purple: "#9580ff", red: "#ff9580", yellow: "#ffff80" },
        { category: "Dracula Pro", name: "Lincoln",  isDark: true,  accent: "#ffff80", subAccent: "#8aff80", bg: "#2c2a21", surface: "#38352a", currentLine: "#585441", fg: "#f8f8f2", comment: "#a99f70", cyan: "#80ffea", green: "#8aff80", orange: "#ffca80", pink: "#ff80bf", purple: "#9580ff", red: "#ff9580", yellow: "#ffff80" },
        { category: "Dracula Pro", name: "Morpheus", isDark: true,  accent: "#ff9580", subAccent: "#ffca80", bg: "#2c2122", surface: "#382a2b", currentLine: "#584145", fg: "#f8f8f2", comment: "#a97079", cyan: "#80ffea", green: "#8aff80", orange: "#ffca80", pink: "#ff80bf", purple: "#9580ff", red: "#ff9580", yellow: "#ffff80" },
        { category: "Dracula Pro", name: "Alucard",  isDark: false, accent: "#644ac9", subAccent: "#a3144d", bg: "#f5f5f5", surface: "#cfcfde", currentLine: "#cfcfde", fg: "#1f1f1f", comment: "#635d97", cyan: "#036a96", green: "#14710a", orange: "#a34d14", pink: "#a3144d", purple: "#644ac9", red: "#cb3a2a", yellow: "#846e15" },

        // Everblush
        { category: "Everblush",   name: "Everblush",   isDark: true,  accent: "#8ccf7e", subAccent: "#67b0e8", bg: "#141b1e", surface: "#232a2d", currentLine: "#2d3437", fg: "#dadada", comment: "#676e7d", cyan: "#67cbe8", green: "#8ccf7e", orange: "#e59e67", pink: "#c47fd5", purple: "#c47fd5", red: "#e57474", yellow: "#e5c76b" },

        // Gruvbox
        { category: "Gruvbox",     name: "Gruvbox Dark",     isDark: true,  accent: "#fe8019", subAccent: "#fabd2f", bg: "#282828", surface: "#3c3836", currentLine: "#504945", fg: "#ebdbb2", cyan: "#8ec07c", green: "#b8bb26", orange: "#fe8019", pink: "#d3869b", purple: "#d3869b", red: "#fb4934", yellow: "#fabd2f" },
        { category: "Gruvbox",     name: "Gruvbox Material", isDark: true,  accent: "#ea698c", subAccent: "#a9b665", bg: "#1d2021", surface: "#282828", currentLine: "#3c3836", fg: "#ddc7a1", cyan: "#7daea3", green: "#a9b665", orange: "#e78a4e", pink: "#ea698c", purple: "#d3869b", red: "#ea698c", yellow: "#d8a657" },
        { category: "Gruvbox",     name: "Gruvbox Light",    isDark: false, accent: "#af3a03", subAccent: "#b57614", bg: "#fbf1c7", surface: "#ebdbb2", currentLine: "#d5c4a1", fg: "#3c3836", cyan: "#427b58", green: "#79740e", orange: "#af3a03", pink: "#b51a00", purple: "#8f3f71", red: "#9d0006", yellow: "#b57614" },

        // Rosé Pine
        { category: "Rosé Pine",   name: "Rosé Pine",        isDark: true,  accent: "#ebbcba", subAccent: "#c4a7e7", bg: "#191724", surface: "#1f1d2e", currentLine: "#26233a", fg: "#e0def4", cyan: "#9ccfd8", green: "#31748f", orange: "#f6c177", pink: "#ebbcba", purple: "#c4a7e7", red: "#eb6f92", yellow: "#f6c177" },
        { category: "Rosé Pine",   name: "Rosé Pine Moon",   isDark: true,  accent: "#ea9a97", subAccent: "#c4a7e7", bg: "#232136", surface: "#2a273f", currentLine: "#393552", fg: "#e0def4", cyan: "#9ccfd8", green: "#3e8fb0", orange: "#f6c177", pink: "#ea9a97", purple: "#c4a7e7", red: "#eb6f92", yellow: "#f6c177" },
        { category: "Rosé Pine",   name: "Rosé Pine Dawn",   isDark: false, accent: "#d7827e", subAccent: "#907aa9", bg: "#faf4ed", surface: "#f2e9e1", currentLine: "#e4d7d0", fg: "#575279", cyan: "#56949f", green: "#286983", orange: "#ea9d34", pink: "#d7827e", purple: "#907aa9", red: "#b4637a", yellow: "#ea9d34" },

        // Catppuccin
        { category: "Catppuccin",  name: "Catppuccin Mocha",    isDark: true,  accent: "#cba6f7", subAccent: "#89b4fa", bg: "#1e1e2e", surface: "#313244", currentLine: "#45475a", fg: "#cdd6f4", cyan: "#94e2d5", green: "#a6e3a1", orange: "#fab387", pink: "#f5c2e7", purple: "#cba6f7", red: "#f38ba8", yellow: "#f9e2af" },
        { category: "Catppuccin",  name: "Catppuccin Macchiato",isDark: true,  accent: "#f5bde6", subAccent: "#8aadf4", bg: "#24273a", surface: "#363a4f", currentLine: "#494d64", fg: "#cad3f5", cyan: "#8bd5ca", green: "#a6da95", orange: "#f5a97f", pink: "#f5bde6", purple: "#cba6f7", red: "#ed8796", yellow: "#eed49f" },
        { category: "Catppuccin",  name: "Catppuccin Latte",    isDark: false, accent: "#8839ef", subAccent: "#1e66f5", bg: "#eff1f5", surface: "#e6e9ef", currentLine: "#ccd0da", fg: "#4c4f69", cyan: "#179299", green: "#40a02b", orange: "#fe640b", pink: "#ea76cb", purple: "#8839ef", red: "#d20f39", yellow: "#df8e1d" },

        // Everforest
        { category: "Everforest",  name: "Everforest Dark",  isDark: true,  accent: "#a7c080", subAccent: "#7fbbb3", bg: "#2d353b", surface: "#343f44", currentLine: "#3d484d", fg: "#d3c6aa", cyan: "#7fbbb3", green: "#a7c080", orange: "#e69875", pink: "#e67e80", purple: "#d699b6", red: "#e67e80", yellow: "#dbbc7f" },
        { category: "Everforest",  name: "Everforest Light", isDark: false, accent: "#8da101", subAccent: "#35a77c", bg: "#fdf6e3", surface: "#f4e0c5", currentLine: "#e5d5c5", fg: "#5c6a72", cyan: "#35a77c", green: "#8da101", orange: "#f57d26", pink: "#f85552", purple: "#df69ba", red: "#f85552", yellow: "#dfa000" },

        // Tokyo Night
        { category: "Tokyo Night", name: "Tokyo Night",      isDark: true,  accent: "#7aa2f7", subAccent: "#bb9af7", bg: "#1a1b26", surface: "#24283b", currentLine: "#414868", fg: "#c0caf5", cyan: "#7dcfff", green: "#9ece6a", orange: "#ff9e64", pink: "#f7768e", purple: "#bb9af7", red: "#f7768e", yellow: "#e0af68" },
        { category: "Tokyo Night", name: "Tokyo Night Storm",isDark: true,  accent: "#7aa2f7", subAccent: "#7dcfff", bg: "#24283b", surface: "#1f2335", currentLine: "#414868", fg: "#c0caf5", cyan: "#7dcfff", green: "#9ece6a", orange: "#ff9e64", pink: "#f7768e", purple: "#bb9af7", red: "#f7768e", yellow: "#e0af68" },
        { category: "Tokyo Night", name: "Tokyo Night Day",  isDark: false, accent: "#2e7de9", subAccent: "#9854f6", bg: "#e1e2e7", surface: "#d5d6db", currentLine: "#c4c8da", fg: "#3760bf", cyan: "#007197", green: "#587539", orange: "#b15c00", pink: "#9854f6", purple: "#9854f6", red: "#f52a65", yellow: "#8c6c00" },

        // Nord
        { category: "Nord",        name: "Nord Dark",        isDark: true,  accent: "#88c0d0", subAccent: "#b48ead", bg: "#2e3440", surface: "#3b4252", currentLine: "#434c5e", fg: "#eceff4", cyan: "#88c0d0", green: "#a3be8c", orange: "#d08770", pink: "#b48ead", purple: "#b48ead", red: "#bf616a", yellow: "#ebcb8b" },
        { category: "Nord",        name: "Nord Light",       isDark: false, accent: "#5e81ac", subAccent: "#88c0d0", bg: "#eceff4", surface: "#e5e9f0", currentLine: "#d8dee9", fg: "#2e3440", cyan: "#5e81ac", green: "#a3be8c", orange: "#d08770", pink: "#b48ead", purple: "#b48ead", red: "#bf616a", yellow: "#ebcb8b" },

        // Solarized
        { category: "Solarized",   name: "Solarized Dark",   isDark: true,  accent: "#268bd2", subAccent: "#2aa198", bg: "#002b36", surface: "#073642", currentLine: "#586e75", fg: "#839496", cyan: "#2aa198", green: "#859900", orange: "#cb4b16", pink: "#d33682", purple: "#6c71c4", red: "#dc322f", yellow: "#b58900" },
        { category: "Solarized",   name: "Solarized Light",  isDark: false, accent: "#268bd2", subAccent: "#d33682", bg: "#fdf6e3", surface: "#eee8d5", currentLine: "#93a1a1", fg: "#657b83", cyan: "#2aa198", green: "#859900", orange: "#cb4b16", pink: "#d33682", purple: "#6c71c4", red: "#dc322f", yellow: "#b58900" },

        // One Theme
        { category: "One Theme",   name: "One Dark Pro",     isDark: true,  accent: "#61afef", subAccent: "#c678dd", bg: "#282c34", surface: "#21252b", currentLine: "#3e4451", fg: "#abb2bf", cyan: "#56b6c2", green: "#98c379", orange: "#d19a66", pink: "#e06c75", purple: "#c678dd", red: "#e06c75", yellow: "#e5c07b" },
        { category: "One Theme",   name: "One Light",        isDark: false, accent: "#4078f2", subAccent: "#a626a4", bg: "#fafafa", surface: "#f0f0f0", currentLine: "#e5e5e6", fg: "#383a42", cyan: "#0184bc", green: "#50a14f", orange: "#d19a66", pink: "#e45649", purple: "#a626a4", red: "#e45649", yellow: "#c18401" },

        // Monokai
        { category: "Monokai",     name: "Monokai Pro",      isDark: true,  accent: "#ffd866", subAccent: "#ff6188", bg: "#2d2a2e", surface: "#3a3a3a", currentLine: "#4a4a4a", fg: "#fcfcfa", cyan: "#78dce8", green: "#a9dc76", orange: "#fc9867", pink: "#ff6188", purple: "#ab9df2", red: "#ff6188", yellow: "#ffd866" },

        // Cyberpunk
        { category: "Cyberpunk",   name: "Cyberpunk Neon",   isDark: true,  accent: "#ff007f", subAccent: "#00f0ff", bg: "#120e24", surface: "#22194d", currentLine: "#3a2a80", fg: "#00ff9f", cyan: "#00f0ff", green: "#00ff9f", orange: "#ffaa00", pink: "#ff007f", purple: "#b537f7", red: "#ff0055", yellow: "#fcee0a" }
    ]

    // Active Palette
    property bool isDark: true
    property string iconTheme: isDark ? "Papirus-Dark" : "Papirus-Light"
    property string panelIconDir: isDark ? "Papirus" : "Papirus-Light"

    property string iconsDir: "/usr/share/icons"

    property color bg: "#22212c"
    property color surface: "#2b2938"
    property color currentLine: "#454158"
    property color selection: "#454158"
    property color fg: "#f8f8f2"
    property color comment: "#7970a9"

    readonly property color separator: isDark ? currentLine : Qt.rgba(fg.r, fg.g, fg.b, 0.25)

    property color accent: "#9580ff"
    property color subAccent: "#ff80bf"

    property color cyan: "#80ffea"
    property color green: "#8aff80"
    property color orange: "#ffca80"
    property color pink: "#ff80bf"
    property color purple: "#9580ff"
    property color red: "#ff9580"
    property color yellow: "#ffff80"

    property color glassBg: bg
    property color glassBorder: currentLine
    property color glassHover: currentLine
    property int blurRadius: 0
    property int cornerRadius: 10

    // ---------------------------------------------------------------------
    // Design tokens
    //
    // Every literal size, radius and gap used to live inline in the modules,
    // which is how the same role ended up with four different values. These
    // are the single source now; a module that needs a size reads it here.
    // ---------------------------------------------------------------------

    // Type scale. 12px is the legibility floor: nothing renders below it.
    // The steps are roughly a 1.15 ratio, so the roles stay distinguishable
    // without any one of them shouting.
    readonly property int fsCaption: 12   // badges, day labels, timestamps
    readonly property int fsBody:    13   // interface text, list rows
    readonly property int fsStrong:  14   // card titles, primary readouts
    readonly property int fsSubhead: 16   // section heads inside popups
    readonly property int fsHead:    18   // popup titles, large glyphs
    readonly property int fsTitle:   22
    readonly property int fsDisplay: 26

    // Line height and tracking for the two sizes that carry real reading:
    // small type needs looser leading, and bold small caps need tracking.
    readonly property real lhTight:  1.15
    readonly property real lhBody:   1.35
    readonly property real trackCaps: 0.6

    // Fonts. "Inter" is not installed on this machine and silently resolved
    // to Noto Sans, so the family string was a lie; the stack now names what
    // is actually here first and keeps Inter for machines that do have it.
    readonly property string fontFamily: "Inter, Noto Sans, DejaVu Sans, Sans-Serif"
    readonly property string fontMono: "MesloLGS Nerd Font Mono, Noto Sans Mono, monospace"
    // Icon glyphs (U+F0000 block). JetBrainsMono/Symbols/CaskaydiaCove are
    // NOT installed here and fell through to Noto Sans, which renders tofu.
    // MesloLGS Nerd Font is installed and covers the block.
    readonly property string fontIcon: "MesloLGS Nerd Font, JetBrainsMono Nerd Font, Symbols Nerd Font, Sans-Serif"

    // Spacing scale (4pt grid).
    readonly property int sp1: 4
    readonly property int sp2: 8
    readonly property int sp3: 12
    readonly property int sp4: 16
    readonly property int sp5: 24

    // Radius scale. cornerRadius stays the panel/card value.
    readonly property int radiusChip: 6    // small capsules and buttons
    readonly property int radiusPill: 8    // badges, pills
    readonly property int radiusCard: cornerRadius

    // Bar geometry. The popup gap was hardcoded as 40 in thirteen places and
    // 42 in five, so center popups hung 2px lower than right popups.
    // 44 rather than the previous 40: a 13px body line needs a 28px capsule
    // to keep real padding, and the capsule needs the panel around it.
    readonly property int barHeight: 44
    readonly property int barCapsule: 28
    readonly property int popupGap: barHeight + sp1

    // ---------------------------------------------------------------------
    // Contrast-corrected roles (WCAG AA, 4.5:1 for body-sized text)
    //
    // Measured across all 30 variants, `comment` fell below 4.5:1 against the
    // background on 26 of them (worst: Everforest Dark at 2.79:1, Nord Dark
    // at 2.80:1) and it is used for real secondary text — artist names,
    // timestamps, device labels. These roles lift the palette colour just far
    // enough to clear AA and leave it untouched when it already does.
    // ---------------------------------------------------------------------

    function relLuminance(c) {
        function ch(v) { return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b)
    }

    function contrastRatio(a, b) {
        var la = relLuminance(a), lb = relLuminance(b)
        return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05)
    }

    // Walks `c` toward white (on a dark ground) or black (on a light one) in
    // 4% steps until it clears `target` against BOTH grounds it may sit on.
    // Flattens a translucent colour against its ground, so contrast is
    // measured on what the eye actually sees. Several palettes define their
    // muted text as an alpha over the background.
    function flatten(c, ground) {
        if (c.a >= 0.999) return c
        return Qt.rgba(c.r * c.a + ground.r * (1 - c.a),
                       c.g * c.a + ground.g * (1 - c.a),
                       c.b * c.a + ground.b * (1 - c.a), 1)
    }

    function ensureContrast(rawC, ground, alt, target) {
        var c = flatten(rawC, ground)
        var dest = relLuminance(ground) < 0.5 ? Qt.rgba(1, 1, 1, 1) : Qt.rgba(0, 0, 0, 1)
        var out = c
        for (var i = 0; i <= 25; i++) {
            if (contrastRatio(out, ground) >= target && contrastRatio(out, alt) >= target) return out
            var t = i * 0.04
            out = Qt.rgba(c.r + (dest.r - c.r) * t,
                          c.g + (dest.g - c.g) * t,
                          c.b + (dest.b - c.b) * t, 1)
        }
        return out
    }

    // Secondary text. Readable on the panel ground and on raised surfaces.
    readonly property color textMuted: ensureContrast(comment, bg, surface, 4.5)
    // Accent used as text rather than as a fill.
    readonly property color accentText: ensureContrast(accent, bg, surface, 4.5)
    readonly property color subAccentText: ensureContrast(subAccent, bg, surface, 4.5)
    // Semantic states, contrast-corrected. These replace the hand-written
    // `Theme.isDark ? Theme.green : "#15803d"` ternaries scattered around.
    readonly property color success: ensureContrast(green, bg, surface, 4.5)
    readonly property color warning: ensureContrast(yellow, bg, surface, 4.5)
    readonly property color danger: ensureContrast(red, bg, surface, 4.5)
    // Glyphs and text sitting on top of an accent fill. Picks whichever of
    // white or near-black actually contrasts more against that accent, rather
    // than switching on a fixed luminance threshold: a mid-tone accent such as
    // Rosé Pine Dawn's #d7827e clears 8:1 against dark and only 2.6:1 against
    // white, and a threshold would have handed it white.
    readonly property color accentFg: {
        var light = Qt.rgba(1, 1, 1, 1)
        var dark = isDark ? bg : Qt.rgba(0.08, 0.08, 0.1, 1)
        return contrastRatio(light, accent) >= contrastRatio(dark, accent) ? light : dark
    }

    // Interaction states, so hover/active/disabled are chromatically the same
    // family everywhere instead of each call site inventing an alpha.
    readonly property color stateHover: Qt.rgba(fg.r, fg.g, fg.b, isDark ? 0.10 : 0.08)
    readonly property color stateActive: Qt.rgba(accent.r, accent.g, accent.b, 0.22)
    readonly property color stateFocus: Qt.rgba(accent.r, accent.g, accent.b, 0.55)
    readonly property real disabledOpacity: 0.45

    function setVariant(name, isStartupRestoration) {
        for (let i = 0; i < variants.length; i++) {
            let v = variants[i]
            if (v.name === name) {
                currentVariant = v.name
                isDark = v.isDark !== undefined ? v.isDark : true
                iconTheme = isDark ? "Papirus-Dark" : "Papirus-Light"

                accent = v.accent
                subAccent = v.subAccent ? v.subAccent : v.accent
                bg = v.bg
                surface = v.surface
                glassBg = v.bg
                currentLine = v.currentLine
                selection = v.currentLine
                glassBorder = v.currentLine
                glassHover = v.currentLine
                if (v.fg) fg = v.fg
                else fg = isDark ? "#f8f8f2" : "#282a36"

                if (v.comment) {
                    comment = v.comment
                } else {
                    comment = isDark ? "#7970a9" : Qt.rgba(fg.r, fg.g, fg.b, 0.65)
                }

                cyan   = v.cyan   ? v.cyan   : (isDark ? "#80ffea" : "#0891b2")
                green  = v.green  ? v.green  : (isDark ? "#8aff80" : "#16a34a")
                orange = v.orange ? v.orange : (isDark ? "#ffca80" : "#ea580c")
                pink   = v.pink   ? v.pink   : (isDark ? "#ff80bf" : "#db2777")
                purple = v.purple ? v.purple : (isDark ? "#9580ff" : "#644ac9")
                red    = v.red    ? v.red    : (isDark ? "#ff9580" : "#dc2626")
                yellow = v.yellow ? v.yellow : (isDark ? "#ffff80" : "#d97706")

                // Update system GTK & KDE icon theme and color scheme preference
                Quickshell.execDetached(["gsettings", "set", "org.gnome.desktop.interface", "icon-theme", iconTheme])
                Quickshell.execDetached(["gsettings", "set", "org.gnome.desktop.interface", "color-scheme", isDark ? "prefer-dark" : "prefer-light"])
                Quickshell.execDetached(["kwriteconfig6", "--group", "Icons", "--key", "Theme", iconTheme])
                
                if (!isStartupRestoration) {
                    let imgPath = getVariantWallpaper(v.name)
                    if (WallpaperService) {
                        WallpaperService.applyWallpaper(imgPath, v.name)
                    } else {
                        wallpaperPath = imgPath.startsWith("file://") ? imgPath : "file://" + imgPath
                        let rawPath = imgPath.replace("file://", "")
                        Quickshell.execDetached(["plasma-apply-wallpaperimage", rawPath])
                        Quickshell.execDetached(["kwriteconfig6", "--file", "kscreenlockerrc", "--group", "Greeter", "--group", "Wallpaper", "--group", "org.kde.image", "--group", "General", "--key", "Image", "file://" + rawPath])
                    }
                    let rawPath = imgPath.replace("file://", "")
                    Quickshell.execDetached(["sh", "-c", "wallust run '" + rawPath + "' || ~/.cargo/bin/wallust run '" + rawPath + "' 2>/dev/null || true"])
                }

                Quickshell.execDetached([
                    "python3", Quickshell.env("HOME") + "/.config/quickshell/services/python/theme_sync.py",
                    "--bg", v.bg,
                    "--surface", v.surface,
                    "--currentLine", v.currentLine,
                    "--fg", v.fg ? v.fg : (isDark ? "#f8f8f2" : "#282a36"),
                    "--accent", v.accent,
                    "--subAccent", v.subAccent ? v.subAccent : v.accent,
                    "--isDark", isDark ? "true" : "false",
                    "--variantName", v.name
                ])
                
                AppLauncherService.reload()

                // Persist selected theme variant to disk
                Quickshell.execDetached(["sh", "-c", "echo '" + v.name + "' > ~/.config/huginn_current_theme.txt"])
                break
            }
        }
    }

    // Read saved theme variant on startup
    Process {
        id: readThemeProc
        command: ["bash", "-c", "cat ~/.config/huginn_current_theme.txt 2>/dev/null || echo 'Pro'"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                let saved = data.trim()
                if (!saved || saved === "") saved = "Pro"
                root.setVariant(saved, true)
            }
        }
    }

    function getVariantWallpaper(varName) {
        if (!varName || varName === "") return ""
        let cur = varName.toLowerCase().trim()

        // 1. Check if user set/cached a custom wallpaper for this specific theme variant
        if (WallpaperService && WallpaperService.cachedThemeWallpapers && WallpaperService.cachedThemeWallpapers[varName]) {
            let cached = WallpaperService.cachedThemeWallpapers[varName]
            if (cached && cached !== "") return cached
        }

        // 2. Check scanned wallpapers folder for matching variant folder
        if (WallpaperService && WallpaperService.wallpapers) {
            for (let i = 0; i < WallpaperService.wallpapers.length; i++) {
                let wp = WallpaperService.wallpapers[i]
                if ((wp.variant || "").toLowerCase().trim() === cur) {
                    return wp.path
                }
            }
        }
        return Quickshell.env("HOME") + "/Pictures/Wallpapers/" + varName + "/wallhaven-yqg6r7_1920x1080.png"
    }

    function cycleVariant() {
        let idx = 0
        for (let i = 0; i < variants.length; i++) {
            if (variants[i].name === currentVariant) {
                idx = (i + 1) % variants.length
                break
            }
        }
        setVariant(variants[idx].name)
    }
}
