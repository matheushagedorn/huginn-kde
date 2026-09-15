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

    // The recolor watcher is not started here. It runs as its own systemd
    // unit (huginn-recolor-watcher.service), and starting it from both places
    // meant a second copy on every shell restart.

    // Read saved user wallpaper state on startup.
    //
    // The saved picture is no longer pushed onto Plasma here. It used to be,
    // and that is why a wallpaper chosen in System Settings came back as the
    // old one on the next shell start: the shell overwrote the user's choice
    // with its own memory of it. The saved file is still where the per-theme
    // wallpapers live, and the picture on screen is read from Plasma below.
    Process {
        id: readWallpaperProc
        command: ["python3", Quickshell.env("HOME") + "/.config/huginn/services/python/read_wallpaper.py"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    let parsed = JSON.parse(data.trim())
                    if (parsed) {
                        if (parsed.theme_wallpapers && typeof parsed.theme_wallpapers === "object") {
                            root.cachedThemeWallpapers = parsed.theme_wallpapers
                        }
                        if (parsed.wallpaper && parsed.wallpaper !== "" && root.activeCustomWallpaper === "") {
                            root.adopt(parsed.wallpaper)
                        }
                    }
                } catch (e) {}
                root.isLoaded = true
            }
        }
    }

    // What Plasma is actually showing.
    //
    // plasmashell draws the desktop over Huginn's own wallpaper window, so
    // the picture on screen is Plasma's. The shell follows it instead of
    // guessing: the glass in the bar shows the real thing, and the palette of
    // the "From wallpaper" theme follows a change made anywhere, including
    // System Settings.
    function adopt(path) {
        if (!path || path === "") return
        let raw = path.replace("file://", "")
        if (root.activeCustomWallpaper === raw) return
        root.activeCustomWallpaper = raw
        Theme.wallpaperPath = "file://" + raw
        Quickshell.execDetached(["kwriteconfig6", "--file", "kscreenlockerrc", "--group", "Greeter", "--group", "Wallpaper", "--group", "org.kde.image", "--group", "General", "--key", "Image", "file://" + raw])
    }

    // Read before the first frame, not after it.
    //
    // `Theme.wallpaperPath` used to start on a hardcoded path and the real one
    // arrived whenever a python process got around to answering, so the shell
    // painted a wallpaper nobody had chosen and crossfaded out of it in front
    // of the user. blockLoading reads the file during startup, so the first
    // thing painted is already the right picture.
    //
    // watchChanges replaces the polling this used to do: KDE rewrites this
    // file when the wallpaper changes, and that is exactly when we want to
    // look at it.
    FileView {
        id: plasmaConfig
        path: Quickshell.env("HOME") + "/.config/plasma-org.kde.plasma.desktop-appletsrc"
        blockLoading: true
        watchChanges: true
        printErrors: false

        onLoaded: root.adoptFromPlasmaConfig(text())
        onFileChanged: reload()
    }

    // Plasma keeps the wallpaper per containment, one per screen. The first
    // one wins: a different wallpaper per monitor is a setup this shell does
    // not try to follow.
    function adoptFromPlasmaConfig(text) {
        if (!text) return
        let section = ""
        let lines = text.split("\n")

        for (let i = 0; i < lines.length; i++) {
            let line = lines[i].trim()
            if (line.startsWith("[")) {
                section = line
                continue
            }
            if (!line.startsWith("Image=") || section.indexOf("Wallpaper") < 0) continue

            let path = line.substring(6).trim()
            if (path.startsWith("file://")) path = path.substring(7)
            if (path !== "") {
                root.adopt(path)
                return
            }
        }
    }



    // Auto-scan wallpapers in ~/Pictures/Wallpapers and ~/.config/huginn/wallpapers
    Process {
        id: scanProc
        command: ["python3", Quickshell.env("HOME") + "/.config/huginn/services/python/wallpaper_scanner.py"]
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
        // Plasma first and synchronously: whatever the saved file says is only
        // a fallback for a machine where Plasma has no wallpaper set.
        root.adoptFromPlasmaConfig(plasmaConfig.text())
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
            Quickshell.execDetached(["python3", Quickshell.env("HOME") + "/.config/huginn/services/python/save_wallpaper.py", rawPath, vName])
        }
    }

    function refresh() {
        if (!scanProc.running) scanProc.running = true
    }
}
