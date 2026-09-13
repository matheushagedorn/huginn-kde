pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"

Item {
    id: root

    property var wallpapers: []
    property string activeCustomWallpaper: ""
    property var cachedThemeWallpapers: ({})
    property bool isLoaded: false
    readonly property string currentWallpaper: Theme.wallpaperPath

    // Automatic recolor watcher background daemon
    Process {
        id: recolorProc
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/services/python/recolor_watcher.py"]
        running: true
    }

    // Read saved user wallpaper state on startup
    Process {
        id: readWallpaperProc
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/services/python/read_wallpaper.py"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    let parsed = JSON.parse(data.trim())
                    if (parsed) {
                        if (parsed.theme_wallpapers && typeof parsed.theme_wallpapers === "object") {
                            root.cachedThemeWallpapers = parsed.theme_wallpapers
                        }
                        if (parsed.wallpaper && parsed.wallpaper !== "") {
                            root.activeCustomWallpaper = parsed.wallpaper
                            let fileUrl = parsed.wallpaper.startsWith("file://") ? parsed.wallpaper : "file://" + parsed.wallpaper
                            Theme.wallpaperPath = fileUrl
                            let rawPath = parsed.wallpaper.replace("file://", "")
                            Quickshell.execDetached(["plasma-apply-wallpaperimage", rawPath])
                            Quickshell.execDetached(["kwriteconfig6", "--file", "kscreenlockerrc", "--group", "Greeter", "--group", "Wallpaper", "--group", "org.kde.image", "--group", "General", "--key", "Image", "file://" + rawPath])
                        }
                    }
                } catch (e) {}
                root.isLoaded = true
            }
        }
    }

    // Auto-scan wallpapers in ~/Pictures/Wallpapers and ~/.config/quickshell/wallpapers
    Process {
        id: scanProc
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/services/python/wallpaper_scanner.py"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    let parsed = JSON.parse(data.trim())
                    if (parsed && Array.isArray(parsed)) {
                        root.wallpapers = parsed
                    }
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: {
            if (!scanProc.running) scanProc.running = true
        }
    }

    Component.onCompleted: {
        readWallpaperProc.running = true
        scanProc.running = true
    }

    function applyWallpaper(filePath, variantName, skipSave) {
        if (!filePath) return;
        let vName = variantName || (Theme ? Theme.currentVariant : "")
        activeCustomWallpaper = filePath
        let fileUrl = filePath.startsWith("file://") ? filePath : "file://" + filePath
        Theme.wallpaperPath = fileUrl
        let rawPath = filePath.replace("file://", "")

        if (vName !== "") {
            let updatedMap = Object.assign({}, cachedThemeWallpapers)
            updatedMap[vName] = rawPath
            cachedThemeWallpapers = updatedMap
        }

        Quickshell.execDetached(["plasma-apply-wallpaperimage", rawPath])
        Quickshell.execDetached(["kwriteconfig6", "--file", "kscreenlockerrc", "--group", "Greeter", "--group", "Wallpaper", "--group", "org.kde.image", "--group", "General", "--key", "Image", "file://" + rawPath])

        if (!skipSave) {
            Quickshell.execDetached(["python3", Quickshell.env("HOME") + "/.config/quickshell/services/python/save_wallpaper.py", rawPath, vName])
        }
    }

    function refresh() {
        if (!scanProc.running) scanProc.running = true
    }
}
