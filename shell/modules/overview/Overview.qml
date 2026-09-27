import QtQuick
import Quickshell
import Quickshell.Io
import "../../services"
import "OverviewLayout.js" as Layout

// Every window of the current desktop, side by side, one screen at a time.
//
// This object holds the state and the geometry; the screens only draw it.
// Keeping the layout here rather than in each screen is what lets the arrow
// keys walk from a card on one monitor to a card on the other: the neighbour
// search needs every card's position in one coordinate space.
//
// Three windows make up the view, for reasons that come from KWin rather than
// taste. Each screen gets an OverviewScreen that stays mapped all the time,
// the same trick LauncherDim uses: KWin animates a surface being mapped with
// its Scale effect, and a full-screen surface scaling up from the middle would
// fight the cards flying out of their windows. What does get mapped on open is
// OverviewKeys, a one-pixel surface that only exists to hold the keyboard.
// Keeping the keyboard on an always-mapped surface is what trapped it in the
// launcher once, because KWin does not hand focus back while the surface
// stays.
Scope {
    id: overview

    // What the person asked for. The cards are still on screen while
    // `progress` runs down after this turns false.
    property bool open: false
    // 0 is every card sitting on its real window, 1 is every card in its slot.
    property real progress: 0
    readonly property bool active: open || progress > 0

    // [{ id, appId, name, icon, iconScale, caption, minimized, active,
    //    screen, x, y, width, height }], geometry global.
    property var windows: []
    // uuid -> path of the frame captured for it. Kept across openings, so a
    // card shows the previous frame at once and swaps to the fresh one when
    // it arrives, instead of starting as a bare icon every time.
    property var shots: ({})
    property string query: ""
    property string selectedId: ""
    // Windows asked to close that have not gone yet. A window can refuse (an
    // editor with unsaved work asks first), so the card only dims until the
    // window list confirms it is gone.
    property var closingIds: ({})
    // The screen that holds the keyboard and the search line: the one with the
    // focused window, so the overview opens where the person was looking.
    property string focusScreen: ""
    // The window that ends up on top when the overview closes: the one picked,
    // or the one that was focused if nothing was. Its card flies back over the
    // others while they fade, because the cards have no idea of the real
    // stacking order and two maximized windows would otherwise land on top of
    // each other in whatever order the list had them. The first frame of the
    // entrance would have the same problem, showing some other window's frame
    // over the one that was really in front.
    property string frontId: ""
    property string focusedAtOpen: ""
    // The same on the way in, where the focused window is the one on top.
    readonly property string frontCard: open ? focusedAtOpen : frontId

    readonly property var primaryScreen: Quickshell.screens.find(s => s.name === "DP-2") || Quickshell.screens[0]

    // Room kept free at the top of every screen for the search line, and
    // around the edges so no card touches the bezel.
    readonly property int topReserve: 112
    readonly property int edgeMargin: 56
    readonly property int cardGap: 28
    readonly property int captionHeight: 36

    readonly property var visibleWindows: {
        let q = query.trim().toLowerCase()
        if (q === "") return windows
        return windows.filter(w => (w.caption || "").toLowerCase().indexOf(q) >= 0
                                   || (w.name || "").toLowerCase().indexOf(q) >= 0
                                   || (w.appId || "").toLowerCase().indexOf(q) >= 0)
    }

    // screen name -> { uuid -> slot }, slot in that screen's own coordinates.
    readonly property var layouts: {
        let result = {}
        let screens = Quickshell.screens
        for (let s = 0; s < screens.length; s++) {
            let scr = screens[s]
            let wins = []
            for (let i = 0; i < visibleWindows.length; i++) {
                let w = visibleWindows[i]
                if (w.screen !== scr.name) continue
                wins.push({
                    id: w.id,
                    aspect: Math.max(0.2, Math.min(5, w.width / Math.max(1, w.height))),
                    // Four fifths of the real size at most: one window alone
                    // drawn at nearly full size looks like nothing happened.
                    maxHeight: w.height * 0.8,
                    cx: w.x - scr.x + w.width / 2,
                    cy: w.y - scr.y + w.height / 2
                })
            }
            result[scr.name] = Layout.arrange(wins, {
                x: edgeMargin,
                y: topReserve,
                width: scr.width - edgeMargin * 2,
                height: scr.height - topReserve - edgeMargin
            }, cardGap, captionHeight)
        }
        return result
    }

    // Every visible card's centre, in global coordinates, for the arrow keys.
    readonly property var globalSlots: {
        let list = []
        let screens = Quickshell.screens
        for (let s = 0; s < screens.length; s++) {
            let slots = layouts[screens[s].name] || {}
            for (let id in slots) {
                let slot = slots[id]
                list.push({
                    id: id,
                    cx: screens[s].x + slot.x + slot.width / 2,
                    cy: screens[s].y + slot.y + slot.height / 2
                })
            }
        }
        // Reading order, so Tab walks the cards the way the eye does.
        list.sort((a, b) => Math.abs(a.cy - b.cy) > 40 ? a.cy - b.cy : a.cx - b.cx)
        return list
    }

    onVisibleWindowsChanged: {
        if (visibleWindows.length === 0) return
        if (!visibleWindows.some(w => w.id === selectedId)) selectedId = visibleWindows[0].id
    }

    NumberAnimation on progress {
        id: enterAnim
        running: false
        to: 1
        duration: 340
        easing.type: Easing.OutCubic
    }

    NumberAnimation on progress {
        id: exitAnim
        running: false
        to: 0
        duration: 240
        easing.type: Easing.InOutCubic
        onFinished: {
            if (overview.open) return
            overview.windows = []
            overview.closingIds = ({})
        }
    }

    function toggle() {
        if (open) hide()
        else show()
    }

    function show() {
        if (open || LockscreenService.isLocked) return
        PopupService.closeAll()
        query = ""
        closingIds = ({})
        let current = TaskService.openWindowApps || []
        let focused = current.find(w => w && w.active)
        focusScreen = focused && focused.output ? focused.output : (primaryScreen ? primaryScreen.name : "")
        selectedId = focused ? String(focused.id || "") : ""
        focusedAtOpen = selectedId
        frontId = ""
        waitingToOpen = true
        requestInfo()
        openFallback.restart()
    }

    function hide() {
        if (!open && !waitingToOpen) return
        if (frontId === "") frontId = focusedAtOpen
        waitingToOpen = false
        openFallback.stop()
        open = false
        enterAnim.stop()
        exitAnim.restart()
    }

    // Brings a window forward and leaves. The cards fly back to their windows
    // on the way out, so the chosen one lands on its window as it rises.
    function activate(id) {
        let w = windows.find(win => win.id === id)
        if (!w) return
        TaskService.focusSpecificWindow(w, 0, 0)
        frontId = id
        hide()
    }

    function closeWindow(id) {
        let w = windows.find(win => win.id === id)
        if (!w) return
        TaskService.closeSpecificWindow(w)
        let next = Object.assign({}, closingIds)
        next[id] = Date.now()
        closingIds = next
        closingExpiry.restart()
    }

    function move(dx, dy) {
        selectedId = Layout.neighbour(globalSlots, selectedId, dx, dy)
    }

    function step(delta) {
        if (globalSlots.length === 0) return
        let at = globalSlots.findIndex(s => s.id === selectedId)
        let next = at < 0 ? 0 : (at + delta + globalSlots.length) % globalSlots.length
        selectedId = globalSlots[next].id
    }

    function activateSelected() {
        if (selectedId !== "" && visibleWindows.some(w => w.id === selectedId)) activate(selectedId)
    }

    // ── Where the windows are ──────────────────────────────────────────────
    //
    // The window list the dock runs on has no position and no desktop (see
    // overview_windows.py), so both are asked for once, as the overview opens.

    property bool waitingToOpen: false

    function requestInfo() {
        let ids = (TaskService.openWindowApps || [])
            .filter(w => w && typeof w === "object" && w.id)
            .map(w => String(w.id))
        infoProc.running = false
        infoProc.command = ["python3", Quickshell.env("HOME") + "/.config/huginn/services/python/overview_windows.py"].concat(ids)
        infoProc.running = true
    }

    function screenFor(x, y, width, height, fallback) {
        let cx = x + width / 2
        let cy = y + height / 2
        let screens = Quickshell.screens
        for (let i = 0; i < screens.length; i++) {
            let s = screens[i]
            if (cx >= s.x && cx < s.x + s.width && cy >= s.y && cy < s.y + s.height) return s.name
        }
        if (fallback && screens.some(s => s.name === fallback)) return fallback
        return primaryScreen ? primaryScreen.name : ""
    }

    // `info` is what overview_windows.py printed, or null when it did not
    // answer in time: then every window is shown, from the middle of its
    // screen, rather than keeping the person waiting on a shortcut.
    function rebuild(info) {
        let geometry = {}
        if (info && Array.isArray(info.windows)) {
            for (let i = 0; i < info.windows.length; i++) geometry[info.windows[i].id] = info.windows[i]
        }
        let list = []
        let source = TaskService.openWindowApps || []
        for (let i = 0; i < source.length; i++) {
            let w = source[i]
            if (!w || typeof w !== "object" || !w.id) continue
            let id = String(w.id)
            let g = geometry[id]
            if (info && !g) continue            // gone by the time KWin was asked
            if (g && !g.onDesktop) continue
            let fallbackScreen = Quickshell.screens.find(s => s.name === w.output) || primaryScreen
            let x = g ? g.x : fallbackScreen.x + fallbackScreen.width / 4
            let y = g ? g.y : fallbackScreen.y + fallbackScreen.height / 4
            let width = g && g.width > 0 ? g.width : fallbackScreen.width / 2
            let height = g && g.height > 0 ? g.height : fallbackScreen.height / 2
            list.push({
                id: id,
                appId: w.appId || "",
                name: w.name || w.appId || "",
                icon: w.icon || w.appId || "",
                iconScale: w.iconScale !== undefined ? w.iconScale : 1.0,
                caption: w.caption || w.name || w.appId || "",
                minimized: g ? g.minimized : !!w.minimized,
                active: !!w.active,
                screen: screenFor(x, y, width, height, w.output),
                x: x,
                y: y,
                width: width,
                height: height
            })
        }
        windows = list

        if (waitingToOpen) {
            waitingToOpen = false
            openFallback.stop()
            if (!list.some(w => w.id === selectedId)) selectedId = list.length > 0 ? list[0].id : ""
            open = true
            exitAnim.stop()
            enterAnim.restart()
            captureShots(list.map(w => w.id))
        }
    }

    Process {
        id: infoProc
        stdout: SplitParser {
            onRead: data => {
                let txt = data.trim()
                if (!txt.startsWith("{")) return
                try {
                    let parsed = JSON.parse(txt)
                    if (overview.waitingToOpen || overview.open) overview.rebuild(parsed)
                } catch (e) {}
            }
        }
    }

    Timer {
        id: openFallback
        interval: 400
        onTriggered: if (overview.waitingToOpen) overview.rebuild(null)
    }

    // A window that opens or closes while the overview is up: KWin is asked
    // again, so a new window arrives with its real place and a closed one
    // takes its card with it. Coalesced, since closing an app can drop
    // several windows in one burst.
    Connections {
        target: TaskService
        function onOpenWindowAppsChanged() {
            if (overview.open) refreshTimer.restart()
        }
    }

    Timer {
        id: refreshTimer
        interval: 120
        onTriggered: {
            if (!overview.open) return
            let known = overview.windows.map(w => w.id)
            overview.requestInfo()
            // New windows have no frame yet.
            let fresh = (TaskService.openWindowApps || [])
                .filter(w => w && w.id && known.indexOf(String(w.id)) < 0)
                .map(w => String(w.id))
            if (fresh.length > 0) overview.captureShots(fresh)
        }
    }

    // A refused close gives the card back after a while.
    Timer {
        id: closingExpiry
        interval: 2500
        onTriggered: {
            let now = Date.now()
            let next = {}
            for (let id in overview.closingIds) {
                if (now - overview.closingIds[id] < interval) next[id] = overview.closingIds[id]
            }
            overview.closingIds = next
            if (Object.keys(next).length > 0) restart()
        }
    }

    Connections {
        target: LockscreenService
        function onIsLockedChanged() {
            if (LockscreenService.isLocked) overview.hide()
        }
    }

    // ── Frames ─────────────────────────────────────────────────────────────
    //
    // The same capture the dock's picker uses (window_shot.py through the
    // privileged helper), asked for at the size the largest card is drawn at.

    function captureShots(ids) {
        if (!ids || ids.length === 0) return
        let widest = 0
        for (let name in layouts) {
            let slots = layouts[name]
            for (let id in slots) widest = Math.max(widest, slots[id].width)
        }
        let maxWidth = Math.max(560, Math.min(1600, Math.ceil(widest / 160) * 160))
        shotProc.running = false
        shotProc.command = [Quickshell.env("HOME") + "/.local/bin/huginn-shell-helper",
                            Quickshell.env("HOME") + "/.config/huginn/services/python/window_shot.py",
                            "--max-width=" + maxWidth].concat(ids)
        shotProc.running = true
    }

    Process {
        id: shotProc
        stdout: SplitParser {
            onRead: data => {
                let parts = data.trim().split("\t")
                if (parts.length < 2) return
                // Reassigned whole: QML only notices a property change, not a
                // mutation inside the object.
                let next = Object.assign({}, overview.shots)
                next[parts[0]] = parts[1]
                overview.shots = next
            }
        }
    }

    // ── The view ───────────────────────────────────────────────────────────

    Variants {
        model: Quickshell.screens

        OverviewScreen {
            required property var modelData
            screen: modelData
            overview: overview
        }
    }

    OverviewKeys {
        overview: overview
    }
}
