pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Item {
    id: root

    // Pinned Application Defaults (Loaded dynamically from disk on startup)
    property var pinnedApps: [
        { appId: "alacritty", name: "Alacritty", icon: "Alacritty", cmd: "alacritty" },
        { appId: "dolphin", name: "Dolphin", icon: "org.kde.dolphin", cmd: "dolphin" },
        { appId: "firefox", name: "Firefox", icon: "firefox", cmd: "firefox" },
        { appId: "code", name: "VS Code", icon: "com.visualstudio.code", cmd: "code" },
        { appId: "kate", name: "Kate", icon: "kate", cmd: "kate" }
    ]

    property var runningWindows: []
    property var openWindowApps: []
    property bool isFullscreen: false
    property string activeAppId: ""
    property string activeWindowTitle: ""

    // Outputs where a window covers the whole screen. The bar fills its screen
    // on these: with nothing of the desktop left to float over, a floating bar
    // is a strip of wallpaper nobody asked for.
    readonly property var filledScreens: {
        let names = []
        for (let i = 0; i < openWindowApps.length; i++) {
            let w = openWindowApps[i]
            if (!w || w.minimized) continue
            if (!w.maximized && !w.fullScreen) continue
            if (!w.output || names.indexOf(w.output) >= 0) continue
            names.push(w.output)
        }
        return names
    }


    // Dynamic Unified Dock Model (Pinned Apps + Unpinned REAL Desktop Open Windows ONLY)
    readonly property var allDockApps: {
        let list = []

        // 1. Pinned Apps (Always present)
        for (let i = 0; i < pinnedApps.length; i++) {
            let p = pinnedApps[i]
            list.push({
                appId: p.appId,
                name: p.name || p.appId,
                icon: p.icon || p.appId,
                cmd: p.cmd || p.appId,
                isPinned: true
            })
        }

        // 2. Unpinned Apps (ONLY if they have a real open desktop window reported by KWin!)
        let addedAppIds = []
        for (let i = 0; i < pinnedApps.length; i++) {
            addedAppIds.push(pinnedApps[i].appId.toLowerCase())
        }

        for (let w = 0; w < openWindowApps.length; w++) {
            let winObj = openWindowApps[w]
            if (!winObj) continue;
            let winApp = typeof winObj === "string" ? winObj.toLowerCase().trim() : (winObj.appId || "").toLowerCase().trim()
            if (!winApp || winApp === "") continue;

            let isAlreadyAdded = false
            for (let k = 0; k < addedAppIds.length; k++) {
                let pinId = addedAppIds[k]
                if (appIdsMatch(pinId, winApp)) {
                    isAlreadyAdded = true
                    break
                }
            }

            if (!isAlreadyAdded) {
                addedAppIds.push(winApp)
                let name = typeof winObj === "object" ? (winObj.name || winApp) : winApp
                let icon = typeof winObj === "object" ? (winObj.icon || winApp) : winApp

                list.push({
                    appId: winApp,
                    name: name,
                    icon: icon,
                    cmd: winApp,
                    isPinned: false
                })
            }
        }

        return list
    }

    function isPinned(appId) {
        if (!appId) return false;
        let lower = appId.toLowerCase()
        for (let i = 0; i < pinnedApps.length; i++) {
            if (appIdsMatch(pinnedApps[i].appId, lower)) {
                return true
            }
        }
        return false
    }

    function appIdsMatch(id1, id2) {
        if (!id1 || !id2) return false;
        let a = id1.toLowerCase().trim()
        let b = id2.toLowerCase().trim()

        if (a === b) return true;

        let aliases = [
            ["equibop", "discord", "equicord", "vencord", "webcord"],
            ["code", "vscode", "visual-studio-code", "code-oss", "com.visualstudio.code"],
            ["org.kde.konsole", "konsole", "terminal", "alacritty"],
            ["org.kde.dolphin", "dolphin"],
            ["org.kde.kate", "kate"],
            ["org.kde.systemsettings", "systemsettings", "kdesystemsettings"],
            ["feishin", "org.jeffvli.feishin", "io.github.jeffvli.feishin"],
            ["zen-alpha", "zen", "zen-browser"],
            ["firefox", "org.mozilla.firefox", "firefox-default", "mozilla-firefox"],
            ["com.antigravity.app", "antigravity", "antigravity-ide", "google-antigravity-ide", "google-antigravity"]
        ]

        for (let i = 0; i < aliases.length; i++) {
            let grp = aliases[i]
            let aIn = grp.some(x => a === x || a.endsWith("." + x) || x.endsWith("." + a))
            let bIn = grp.some(x => b === x || b.endsWith("." + x) || x.endsWith("." + b))
            if (aIn && bIn) return true;
        }

        // Prevent web browsers from matching non-browser desktop app IDs
        let isBrowserA = a.includes("firefox") || a.includes("zen") || a.includes("chrome") || a.includes("mozilla")
        let isBrowserB = b.includes("firefox") || b.includes("zen") || b.includes("chrome") || b.includes("mozilla")
        if (isBrowserA !== isBrowserB) {
            return false;
        }

        // Dot-separated or dash-separated sub-component exact match (e.g. org.kde.dolphin vs dolphin)
        if (a.endsWith("." + b) || b.endsWith("." + a) || a.endsWith("-" + b) || b.endsWith("-" + a)) {
            return true;
        }

        return false;
    }

    function isRunning(appId) {
        if (!appId) return false;
        let target = appId.toLowerCase().trim()

        for (let i = 0; i < openWindowApps.length; i++) {
            let winObj = openWindowApps[i]
            if (!winObj) continue;
            let winApp = typeof winObj === "string" ? winObj : (winObj.appId || "")

            if (appIdsMatch(target, winApp)) {
                return true
            }
        }
        return false
    }

    function isActive(appId) {
        if (!appId) return false;
        let lower = appId.toLowerCase().trim()

        if (!isRunning(lower)) return false;

        if (activeAppId && activeAppId !== "") {
            let actLower = activeAppId.toLowerCase().trim()
            if (appIdsMatch(lower, actLower)) {
                return true
            }
        }
        return false
    }

    function getWindowsForApp(appId) {
        if (!appId) return [];
        let target = appId.toLowerCase().trim()
        let matching = []

        for (let i = 0; i < openWindowApps.length; i++) {
            let winObj = openWindowApps[i]
            if (!winObj) continue;
            let winApp = typeof winObj === "string" ? winObj : (winObj.appId || "")

            if (appIdsMatch(target, winApp)) {
                matching.push({
                    id: typeof winObj === "object" ? (winObj.id || winApp) : winApp,
                    appId: winApp,
                    name: typeof winObj === "object" ? (winObj.name || winApp) : winApp,
                    icon: typeof winObj === "object" ? (winObj.icon || winApp) : winApp,
                    caption: typeof winObj === "object" ? (winObj.caption || winObj.name || winApp) : winApp,
                    width: typeof winObj === "object" ? (winObj.width || 1280) : 1280,
                    height: typeof winObj === "object" ? (winObj.height || 800) : 800,
                    preview: typeof winObj === "object" ? (winObj.preview || "") : "",
                    minimized: typeof winObj === "object" ? (winObj.minimized || false) : false,
                    active: typeof winObj === "object" ? (winObj.active || false) : false
                })
            }
        }
        return matching
    }

    property var originalActiveWin: null

    function clearOriginalActiveWin() {
        originalActiveWin = null
    }

    function previewRaiseWindow(winObj) {
        if (!winObj) return;
        let winId = (winObj.id || "").toString().trim()
        let query = (winObj.caption || winObj.appId || winObj.name || "").toLowerCase().trim()
        if (winId === "" && query === "") return;
        
        if (!originalActiveWin) {
            for (let i = 0; i < openWindowApps.length; i++) {
                let w = openWindowApps[i]
                if (w && typeof w === "object" && (w.active === true || w.active === "true")) {
                    originalActiveWin = w
                    break
                }
            }
        }
        
        Quickshell.execDetached(["python3", Quickshell.env("HOME") + "/.config/huginn/services/python/kwin_preview_raise.py", winId, query])
    }

    function previewRestoreWindow() {
        if (originalActiveWin) {
            let target = originalActiveWin
            originalActiveWin = null
            let winId = (target.id || "").toString().trim()
            let query = (target.caption || target.appId || target.name || "").toLowerCase().trim()
            Quickshell.execDetached(["python3", Quickshell.env("HOME") + "/.config/huginn/services/python/kwin_preview_raise.py", winId, query])
        }
    }

    function focusSpecificWindow(winObj, iconX, iconY) {
        if (!winObj) return;
        originalActiveWin = null
        let query = (winObj.caption || winObj.appId || "").toLowerCase().trim()
        let winId = (winObj.id || "").toString().trim()
        let ix = Math.round(iconX || 0)
        let iy = Math.round(iconY || 0)

        root.activeAppId = (winObj.appId || "").toLowerCase().trim()
        proc.running = false
        proc.command = ["python3", Quickshell.env("HOME") + "/.config/huginn/services/python/kwin_focus.py", query, ix.toString(), iy.toString(), winId]
        proc.running = true
    }

    function closeSpecificWindow(winObj) {
        if (!winObj) return;
        let winId = (winObj.id || "").toString().trim()
        let query = (winObj.caption || winObj.appId || "").toLowerCase().trim()

        Quickshell.execDetached(["python3", Quickshell.env("HOME") + "/.config/huginn/services/python/kwin_close.py", winId, query])
    }

    function focusApp(appId, cmd, iconX, iconY) {
        if (!appId) return;
        originalActiveWin = null
        let lower = appId.toLowerCase().trim()
        let ix = Math.round(iconX || 0)
        let iy = Math.round(iconY || 0)

        if (isRunning(appId)) {
            let currentlyActive = isActive(appId)
            if (currentlyActive) {
                root.activeAppId = ""
            } else {
                root.activeAppId = lower
            }

            proc.running = false
            proc.command = ["python3", Quickshell.env("HOME") + "/.config/huginn/services/python/kwin_focus.py", lower, ix.toString(), iy.toString()]
            proc.running = true
        } else if (cmd || appId) {
            launchApp(cmd || appId)
        }
    }

    property real lastLaunchTime: 0
    property string lastLaunchCmd: ""

    function launchApp(cmd) {
        if (!cmd) return;
        originalActiveWin = null
        let cleanCmd = cmd.trim()
        if (cleanCmd === "") return;

        let now = Date.now()
        if (cleanCmd === lastLaunchCmd && (now - lastLaunchTime) < 500) {
            return; // Ignore rapid double-clicks within 500ms
        }
        lastLaunchTime = now
        lastLaunchCmd = cleanCmd

        let execCmd = cleanCmd.replace(/%[a-zA-Z]/g, "").trim()
        root.activeAppId = execCmd.toLowerCase()

        Quickshell.execDetached(["python3", Quickshell.env("HOME") + "/.config/huginn/services/python/launch_app.py", cleanCmd])
    }

    function closeApp(appId) {
        if (appId) {
            if (isActive(appId)) root.activeAppId = ""
            proc.running = false
            proc.command = ["python3", Quickshell.env("HOME") + "/.config/huginn/services/python/kwin_close.py", appId]
            proc.running = true
        }
    }

    function toggleLauncher() {
        PopupService.toggleAppLauncher()
    }

    function togglePin(app) {
        if (!app || !app.appId) return;
        let existsIndex = -1
        let lower = app.appId.toLowerCase()
        for (let i = 0; i < pinnedApps.length; i++) {
            if (pinnedApps[i].appId.toLowerCase() === lower || lower.includes(pinnedApps[i].appId.toLowerCase())) {
                existsIndex = i
                break
            }
        }
        let list = Array.from(pinnedApps)
        if (existsIndex >= 0) {
            list.splice(existsIndex, 1)
        } else {
            list.push({
                appId: app.appId,
                name: app.name || app.appId,
                icon: app.icon || app.appId,
                cmd: app.cmd || app.appId
            })
        }
        pinnedApps = list
        savePinnedApps()
    }

    function reorderPinnedApps(fromIndex, toIndex) {
        if (fromIndex < 0 || fromIndex >= pinnedApps.length || toIndex < 0 || toIndex >= pinnedApps.length || fromIndex === toIndex) return;
        let list = Array.from(pinnedApps)
        let item = list.splice(fromIndex, 1)[0]
        list.splice(toIndex, 0, item)
        pinnedApps = list
        savePinnedApps()
    }

    function savePinnedApps() {
        let jsonStr = JSON.stringify(pinnedApps)
        saveProc.command = ["python3", Quickshell.env("HOME") + "/.config/huginn/services/python/save_pinned_apps.py", jsonStr]
        saveProc.running = true
    }

    function updateIconGeometries(map) {
        if (!map || typeof map !== "object") return;
        let jsonStr = JSON.stringify(map)
        updateGeomProc.command = ["python3", Quickshell.env("HOME") + "/.config/huginn/services/python/update_icon_geometries.py", jsonStr]
        updateGeomProc.running = true
    }

    Process { id: proc }
    Process { id: saveProc }
    Process { id: updateGeomProc }

    // Read saved pinned apps from JSON as a SINGLE LINE stream on startup
    Process {
        id: readPinnedProc
        command: ["python3", Quickshell.env("HOME") + "/.config/huginn/services/python/read_pinned_apps.py"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                let txt = data.trim()
                if (txt === "DEFAULT" || txt === "") return;
                try {
                    let parsed = JSON.parse(txt)
                    if (parsed && Array.isArray(parsed)) {
                        root.pinnedApps = parsed
                    }
                } catch (e) {}
            }
        }
    }

    // Event-driven Active Window & Open Windows DBus Daemon
    Process {
        id: activeDaemon
        command: ["python3", "-u", Quickshell.env("HOME") + "/.config/huginn/services/python/active_window_service.py"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                let txt = data.trim()
                if (txt === "TOGGLE_LAUNCHER") {
                    PopupService.toggleAppLauncher()
                } else if (txt.startsWith("{")) {
                    try {
                        let parsed = JSON.parse(txt)
                        if (parsed) {
                            if (parsed.active !== undefined) {
                                root.activeAppId = parsed.active
                            }
                            if (parsed.open && Array.isArray(parsed.open)) {
                                root.openWindowApps = parsed.open
                            }
                            if (parsed.fullscreen !== undefined) {
                                root.isFullscreen = parsed.fullscreen
                            }
                        }
                    } catch (e) {}
                }
            }
        }
    }

    Component.onCompleted: {
        if (!readPinnedProc.running) readPinnedProc.running = true
        if (!activeDaemon.running) activeDaemon.running = true
    }
}
