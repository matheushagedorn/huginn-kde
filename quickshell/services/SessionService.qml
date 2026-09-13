pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    function lock() {
        lockProc.running = true
    }

    function logout() {
        logoutProc.running = true
    }

    function reboot() {
        rebootProc.running = true
    }

    function shutdown() {
        shutdownProc.running = true
    }

    Process { id: lockProc; command: ["loginctl", "lock-session"] }
    Process { id: logoutProc; command: ["loginctl", "terminate-session", ""] }
    Process { id: rebootProc; command: ["systemctl", "reboot"] }
    Process { id: shutdownProc; command: ["systemctl", "poweroff"] }
}
