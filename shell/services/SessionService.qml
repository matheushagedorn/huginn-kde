pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Session actions.
//
// These go through Plasma's own Shutdown service rather than straight to
// systemd, so open applications get the chance to save and close the way they
// would from the KDE menu. loginctl is the fallback for a session where that
// service is not around.
Item {
    id: root

    readonly property string plasmaShutdown: "qdbus6 org.kde.Shutdown /Shutdown org.kde.Shutdown."

    function lock() {
        lockProc.running = true
    }

    function logout() {
        // The previous command was `loginctl terminate-session ""`, with the
        // session id left empty. It always failed with "Caller does not belong
        // to any known session", so logging out simply did nothing.
        logoutProc.command = ["bash", "-c",
            plasmaShutdown + "logout || loginctl terminate-session \"${XDG_SESSION_ID:-$(loginctl --no-legend list-sessions | awk 'NR==1{print $1}')}\""]
        logoutProc.running = true
    }

    function reboot() {
        rebootProc.command = ["bash", "-c", plasmaShutdown + "logoutAndReboot || systemctl reboot"]
        rebootProc.running = true
    }

    function shutdown() {
        shutdownProc.command = ["bash", "-c", plasmaShutdown + "logoutAndShutdown || systemctl poweroff"]
        shutdownProc.running = true
    }

    Process { id: lockProc; command: ["loginctl", "lock-session"] }
    Process { id: logoutProc }
    Process { id: rebootProc }
    Process { id: shutdownProc }
}
