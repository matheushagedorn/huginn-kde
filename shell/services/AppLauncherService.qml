pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    // All parsed desktop apps
    property var allApps: []

    // Category list — deduplicated by display label ("All" always first)
    readonly property var categories: {
        let cats = []
        let seen = {}
        for (let i = 0; i < allApps.length; i++) {
            let appCats = allApps[i].categories || []
            for (let j = 0; j < appCats.length; j++) {
                let rawKey = appCats[j].trim()
                let displayName = knownCategories[rawKey]
                if (displayName && !seen[displayName]) {
                    seen[displayName] = true
                    cats.push(displayName)
                }
            }
        }
        // The Games tab also exists when no desktop file claims the Game
        // category: the store libraries alone are reason enough for it.
        if (allGames.length > 0 && !seen[gamesCategory]) cats.push(gamesCategory)
        cats.sort((a, b) => a.localeCompare(b))
        return ["All"].concat(cats)
    }

    // Human-readable labels for XDG category keys
    readonly property var knownCategories: ({
        "AudioVideo":    "Sound & Video",
        "Audio":         "Sound & Video",
        "Video":         "Sound & Video",
        "Development":   "Development",
        "Education":     "Education",
        "Game":          "Games",
        "Games":         "Games",
        "Graphics":      "Graphics",
        "Network":       "Internet",
        "Internet":      "Internet",
        "Office":        "Office",
        "Science":       "Science",
        "Settings":      "Settings",
        "System":        "System",
        "Utility":       "Utilities",
        "Utilities":     "Utilities"
    })

    property string activeCategory: "All"
    property string searchQuery: ""

    // Filters that come from how the person uses the launcher rather than
    // from the desktop files. They sit before the XDG categories and are
    // hidden while empty, so a fresh install never shows an empty list.
    readonly property string recentCategory: "Recent"
    readonly property string favoritesCategory: "Favorites"

    // ── Games ─────────────────────────────────────────────────────────────
    // Installed games from Steam, Hydra and Heroic, read by
    // game_library_service.py. They are shaped like apps (id, name) so search,
    // ranking, favourites and recents treat them the same, and carry
    // `kind: "game"` so the views know to draw a cover instead of an icon.
    //
    // They take over the Games category: with a store library on hand, the
    // desktop files tagged Game are mostly the store launchers themselves,
    // and those stay one search away under All.
    property var allGames: []
    readonly property string gamesCategory: "Games"
    readonly property bool gamesView: activeCategory === gamesCategory && allGames.length > 0

    function isGame(app) {
        return !!app && app.kind === "game"
    }

    // File paths become URLs one segment at a time, so a cover whose path
    // holds a space or a '#' still loads.
    function coverSource(game) {
        if (!game || !game.cover) return ""
        return "file://" + game.cover.split("/").map(encodeURIComponent).join("/")
    }

    // Filtered app list
    readonly property var filteredApps: {
        let q = searchQuery.toLowerCase().trim()

        // Recent and Favorites carry their own order — by last use and by the
        // order things were favourited — so they skip the alphabetical and
        // ranked sorting below entirely.
        if (activeCategory === recentCategory || activeCategory === favoritesCategory) {
            let source = activeCategory === recentCategory ? recentApps : favoriteApps
            if (!q) return source
            return source.filter(a => a.name.toLowerCase().includes(q))
        }

        if (gamesView) {
            let games = q ? allGames.filter(g => g.name.toLowerCase().includes(q)) : Array.from(allGames)
            if (q) {
                let self = root
                games.sort((a, b) => {
                    let sa = self.matchScore(a.name, q)
                    let sb = self.matchScore(b.name, q)
                    if (sa !== sb) return sa - sb
                    return a.name.localeCompare(b.name)
                })
            }
            return games
        }

        let result = []

        // A query typed from All reaches the games too, so "hogw" and Enter
        // starts the game without a detour through its tab.
        if (q && activeCategory === "All") {
            for (let i = 0; i < allGames.length; i++) {
                if (allGames[i].name.toLowerCase().includes(q)) result.push(allGames[i])
            }
        }

        for (let i = 0; i < allApps.length; i++) {
            let app = allApps[i]

            // Category filter
            if (activeCategory !== "All") {
                let inCat = false
                let appCats = app.categories || []
                for (let j = 0; j < appCats.length; j++) {
                    let rawKey = appCats[j].trim()
                    let displayName = knownCategories[rawKey] || rawKey
                    if (displayName === activeCategory || rawKey === activeCategory) {
                        inCat = true
                        break
                    }
                }
                if (!inCat) continue
            }

            // Search filter
            if (q && !app.name.toLowerCase().includes(q)) continue

            result.push(app)
        }

        if (!q) {
            result.sort((a, b) => a.name.localeCompare(b.name))
            return result
        }

        // With a query on screen, alphabetical order is the wrong answer:
        // "co" should put the editor you open daily above a colour picker you
        // have never launched. Rank by how well the name matches, then by how
        // often the app was actually used, and only then alphabetically.
        let self = root
        result.sort((a, b) => {
            let sa = self.matchScore(a.name, q)
            let sb = self.matchScore(b.name, q)
            if (sa !== sb) return sa - sb
            let ua = self.useCount(a)
            let ub = self.useCount(b)
            if (ua !== ub) return ub - ua
            return a.name.localeCompare(b.name)
        })
        return result
    }

    // 0 = the name starts with the query, 1 = some word does, 2 = it appears
    // somewhere else. Lower sorts first.
    function matchScore(name, q) {
        let lower = name.toLowerCase()
        if (lower.startsWith(q)) return 0
        let words = lower.split(/[\s\-_.]+/)
        for (let i = 0; i < words.length; i++) {
            if (words[i].startsWith(q)) return 1
        }
        return 2
    }

    function launch(app) {
        // A game starts through its own store (steam://, heroic://,
        // hydralauncher://), never through the desktop-file path below.
        if (isGame(app)) {
            if (!app.launch || app.launch.length === 0) return
            recordUse(app)
            Quickshell.execDetached(app.launch)
            return
        }
        if (!app || !app.exec) return
        // Strip desktop-file field codes (%u %U %f %F etc.)
        let cmd = app.exec.replace(/%[a-zA-Z]/g, "").trim()
        recordUse(app)
        TaskService.launchApp(cmd)
    }

    // Launches one of the app's own desktop actions ("New private window").
    // Counts as use of the app itself, so the ranking still reflects reality.
    function launchAction(app, action) {
        if (!action || !action.exec) return
        let cmd = action.exec.replace(/%[a-zA-Z]/g, "").trim()
        recordUse(app)
        TaskService.launchApp(cmd)
    }

    // Sends an app to the dock's pinned list. The dock keys apps by the id
    // KWin reports (a resource class such as "brave-browser"), which is the
    // desktop file id without its extension.
    function dockAppId(app) {
        if (!app || !app.id) return ""
        return app.id.replace(/\.desktop$/, "")
    }

    function isPinnedToDock(app) {
        let id = dockAppId(app)
        return id !== "" && TaskService.isPinned(id)
    }

    function togglePinToDock(app) {
        if (!app) return
        TaskService.togglePin({
            appId: dockAppId(app),
            name: app.name,
            icon: app.icon,
            cmd: app.exec ? app.exec.replace(/%[a-zA-Z]/g, "").trim() : dockAppId(app)
        })
    }

    function reset() {
        activeCategory = "All"
        searchQuery = ""
    }

    function isUserCategory(name) {
        return name === recentCategory || name === favoritesCategory
    }

    // Removing the last favourite while standing in Favorites would leave the
    // person looking at an empty grid whose filter has just disappeared from
    // the row. Step back to All instead.
    onFavoriteIdsChanged: {
        if (activeCategory === favoritesCategory && favoriteIds.length === 0) activeCategory = "All"
    }

    onRecentIdsChanged: {
        if (activeCategory === recentCategory && recentIds.length === 0) activeCategory = "All"
    }

    // ── User state: favourites and usage ──────────────────────────────────
    // Favourites are an explicit choice, recents are earned by use. Both are
    // keyed by desktop file id and live in one file next to the dock's own.
    property var favoriteIds: []
    property var usageCounts: ({})
    property var recentIds: []

    readonly property int recentLimit: 5

    readonly property var favoriteApps: {
        let out = []
        for (let i = 0; i < favoriteIds.length; i++) {
            let app = appById(favoriteIds[i])
            if (app) out.push(app)
        }
        return out
    }

    // Every remembered recent, most recent first. The launcher shows these as
    // a category of their own, so there is no short list to cut down to.
    readonly property var recentApps: {
        let out = []
        for (let i = 0; i < recentIds.length; i++) {
            let app = appById(recentIds[i])
            if (app) out.push(app)
        }
        return out
    }

    // Games live in the same favourites and recents as apps, so the lookup
    // covers both lists.
    function appById(id) {
        for (let i = 0; i < allApps.length; i++) {
            if (allApps[i].id === id) return allApps[i]
        }
        for (let i = 0; i < allGames.length; i++) {
            if (allGames[i].id === id) return allGames[i]
        }
        return null
    }

    function useCount(app) {
        if (!app || !app.id) return 0
        let c = usageCounts[app.id]
        return c ? c : 0
    }

    function isFavorite(app) {
        return !!app && favoriteIds.indexOf(app.id) >= 0
    }

    function toggleFavorite(app) {
        if (!app || !app.id) return
        let list = Array.from(favoriteIds)
        let at = list.indexOf(app.id)
        if (at >= 0) {
            list.splice(at, 1)
        } else {
            list.push(app.id)
        }
        favoriteIds = list
        saveState()
    }

    function recordUse(app) {
        if (!app || !app.id) return
        let counts = Object.assign({}, usageCounts)
        counts[app.id] = (counts[app.id] || 0) + 1
        usageCounts = counts

        let list = Array.from(recentIds)
        let at = list.indexOf(app.id)
        if (at >= 0) list.splice(at, 1)
        list.unshift(app.id)
        // Keep a little more history than the strip shows, so uninstalling an
        // app doesn't leave the row short.
        recentIds = list.slice(0, recentLimit * 3)
        saveState()
    }

    function saveState() {
        saveStateProc.command = ["python3",
                                 Quickshell.env("HOME") + "/.config/huginn/services/python/save_launcher_state.py",
                                 JSON.stringify({ favorites: favoriteIds, usage: usageCounts, recent: recentIds })]
        saveStateProc.running = true
    }

    Process { id: saveStateProc }

    Process {
        id: readStateProc
        command: ["python3", Quickshell.env("HOME") + "/.config/huginn/services/python/read_launcher_state.py"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    let parsed = JSON.parse(data.trim())
                    if (!parsed) return
                    if (Array.isArray(parsed.favorites)) root.favoriteIds = parsed.favorites
                    if (Array.isArray(parsed.recent)) root.recentIds = parsed.recent
                    if (parsed.usage && typeof parsed.usage === "object") root.usageCounts = parsed.usage
                } catch (e) {}
            }
        }
    }

    // Fallback icon path from active system icon theme
    property string fallbackIconPath: ""
    property var iconMap: ({})

    // Icon path -> how big to draw it, from icon_metrics.py. Anything not in
    // here is drawn as it is; see components/AppIcon.qml.
    property var iconScales: ({})

    function iconScale(path) {
        if (!path) return 1.0
        let raw = String(path).replace("file://", "")
        let s = iconScales[raw]
        return (s === undefined || s === null) ? 1.0 : s
    }

    // Turns whatever a desktop file calls its icon into something Image can
    // load. Lives here rather than in the view because the grid, the
    // favourites strip and the context menu all need the same answer.
    function iconSource(iconName) {
        if (!iconName || iconName === "") {
            return fallbackIconPath ? "file://" + fallbackIconPath : ""
        }
        if (iconName.startsWith("/")) return "file://" + iconName

        let lower = iconName.toLowerCase().trim()
        if (iconMap && iconMap[lower]) {
            let mapped = iconMap[lower]
            return mapped.startsWith("/") ? "file://" + mapped : mapped
        }
        return fallbackIconPath ? "file://" + fallbackIconPath : ""
    }

    Process { id: launchProc }

    // Parse desktop files on startup and monitor real-time directory changes
    Process {
        id: parseProc
        command: ["python3", "-u", Quickshell.env("HOME") + "/.config/huginn/services/python/app_launcher_service.py"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    let parsed = JSON.parse(data.trim())
                    if (parsed && typeof parsed === "object") {
                        if (parsed.fallback) root.fallbackIconPath = parsed.fallback
                        if (parsed.apps && Array.isArray(parsed.apps)) {
                            root.allApps = parsed.apps
                            let newMap = {}
                            for (let i = 0; i < parsed.apps.length; i++) {
                                let a = parsed.apps[i]
                                if (a.icon) {
                                    if (a.id) {
                                        let rawId = a.id.toLowerCase()
                                        let cleanId = rawId.replace(/\.desktop$/, "")
                                        newMap[rawId] = a.icon
                                        newMap[cleanId] = a.icon
                                        let parts = cleanId.split(".")
                                        if (parts.length > 1) {
                                            let lastPart = parts[parts.length - 1]
                                            if (lastPart) newMap[lastPart] = a.icon
                                        }
                                    }
                                    if (a.name) newMap[a.name.toLowerCase()] = a.icon
                                    if (a.exec) {
                                        let cleanExec = a.exec.replace(/%[a-zA-Z]/g, "").trim().split(/\s+/)[0]
                                        let execName = cleanExec.split("/").pop().toLowerCase()
                                        newMap[cleanExec.toLowerCase()] = a.icon
                                        newMap[execName] = a.icon
                                    }
                                }
                            }
                            root.iconMap = newMap

                            let newScales = {}
                            for (let i = 0; i < parsed.apps.length; i++) {
                                let a = parsed.apps[i]
                                if (a && a.icon && a.iconScale !== undefined) {
                                    newScales[a.icon] = a.iconScale
                                }
                            }
                            root.iconScales = newScales
                        }
                    }
                } catch (e) {}
            }
        }
    }

    // Builds the game library once, then answers each "reload" with a cheap
    // mtime check of the store files; it only prints again when something
    // changed or a cover finished downloading.
    Process {
        id: gamesProc
        command: ["python3", "-u", Quickshell.env("HOME") + "/.config/huginn/services/python/game_library_service.py"]
        running: true
        stdinEnabled: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    let parsed = JSON.parse(data.trim())
                    if (parsed && Array.isArray(parsed.games)) {
                        root.allGames = parsed.games.map(g => Object.assign({ kind: "game" }, g))
                    }
                } catch (e) {}
            }
        }
    }

    // Losing the library while standing in Games (the last store game was
    // uninstalled) would leave an empty tab whose label just vanished. If
    // desktop files still claim the category, the tab stays and simply falls
    // back to listing them.
    onAllGamesChanged: {
        if (activeCategory === gamesCategory && categories.indexOf(gamesCategory) < 0) activeCategory = "All"
    }

    function reload() {
        if (parseProc.running) {
            parseProc.write("reload\n")
        } else {
            parseProc.running = true
        }
        if (gamesProc.running) {
            gamesProc.write("reload\n")
        } else {
            gamesProc.running = true
        }
    }
}
