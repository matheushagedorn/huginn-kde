pragma Singleton
import QtQuick

// Game mode: while a game is the active window and fullscreen, the bar and the
// dock on its screen get out of the way and notifications wait.
//
// It keys on games, not on fullscreen. A browser playing a video fullscreen is
// active and fullscreen too, and hiding the bar or swallowing messages there
// would be wrong; which windows are games is decided per process in
// services/python/game_sessions.py and arrives here as `game` on each window.
//
// Nothing here resizes the game. The bar is unmapped rather than faded, which
// takes its reserved area with it, but KWin sizes a fullscreen window to the
// whole output and never to the work area, so the zone coming and going only
// moves the maximized windows behind the game, where nobody sees them.
Item {
    id: root

    // The fullscreen game that has focus, or null. Minimized counts as gone:
    // KWin can leave the flags of a minimized window set.
    readonly property var detectedWindow: {
        let wins = TaskService.openWindowApps
        for (let i = 0; i < wins.length; i++) {
            let w = wins[i]
            if (w && w.game && w.active && w.fullScreen && !w.minimized) return w
        }
        return null
    }
    readonly property string detectedId: detectedWindow ? String(detectedWindow.id) : ""

    // Games often go fullscreen, windowed and fullscreen again while they
    // start. Turning on waits for that to settle so the bar does not blink in
    // and out; turning off does not wait, the desktop comes back at once.
    property bool settled: false
    onDetectedIdChanged: {
        if (detectedId === "") {
            settleTimer.stop()
            settled = false
            // A manual "off" was meant for that game, not for the next one.
            if (manual === "off") manual = ""
        } else if (!settled) {
            settleTimer.restart()
        }
    }
    Timer {
        id: settleTimer
        interval: 400
        onTriggered: root.settled = root.detectedId !== ""
    }

    // "" follows the detection, "on" and "off" are forced from IPC.
    property string manual: ""

    readonly property bool active: manual === "on" || (manual !== "off" && settled)

    readonly property string gameName: detectedWindow && active ? (detectedWindow.name || "") : ""
    readonly property string gameIcon: detectedWindow && active ? (detectedWindow.icon || "") : ""

    // The output the game is on. Empty while forced on with no window to go
    // by, which hides the bar everywhere rather than guessing a screen.
    readonly property string screenName: {
        if (!active) return ""
        if (detectedWindow) return detectedWindow.output || ""
        let wins = TaskService.openWindowApps
        for (let i = 0; i < wins.length; i++) {
            if (wins[i] && wins[i].active) return wins[i].output || ""
        }
        return ""
    }

    function hidesScreen(screen) {
        if (!active) return false
        if (screenName === "") return true
        return !!screen && screen.name === screenName
    }

    // Off means "not for this game" when there is one, and plain automatic
    // when there is not: an "off" with no game to clear it would otherwise
    // outlive the moment and keep the next game from turning it on.
    function toggle() {
        if (active) disable()
        else enable()
    }
    function enable() { manual = "on" }
    function disable() { manual = settled ? "off" : "" }
    function reset() { manual = "" }

    // A popup left open over a game would stay mapped with the bar gone.
    onActiveChanged: if (active) PopupService.closeAll()

    // Shown by NotificationToast once the game has closed. Built here so the
    // toast only has to know it is showing something with its own icon.
    signal sessionSummary(var entry)

    function formatDuration(seconds) {
        let minutes = Math.max(1, Math.round(seconds / 60))
        let h = Math.floor(minutes / 60)
        let m = minutes % 60
        if (h === 0) return m + "m"
        return m === 0 ? h + "h" : h + "h " + m + "m"
    }

    Connections {
        target: TaskService
        function onGameSessionEnded(session) {
            if (!session || !session.name) return
            root.sessionSummary({
                "id": -1,
                "app": "Game session",
                "summary": "Played " + session.name + " for "
                           + root.formatDuration(session.end - session.start),
                "body": "",
                "icon": session.icon || "",
                "time": NotificationService.formatTime(new Date())
            })
        }
    }
}
