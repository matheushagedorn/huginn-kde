pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property bool isDnd: false
    property var notifications: []

    function toggleDnd() {
        isDnd = !isDnd
        if (isDnd) {
            dndHoldProc.running = false
            dndHoldProc.running = true
            syncProc.command = ["kwriteconfig6", "--file", "plasmanotifyrc", "--group", "Notifications", "--key", "DoNotDisturb", "true"]
        } else {
            dndHoldProc.running = false
            syncProc.command = ["kwriteconfig6", "--file", "plasmanotifyrc", "--group", "Notifications", "--key", "DoNotDisturb", "false"]
        }
        syncProc.running = true
    }

    function dismissNotification(id) {
        var arr = []
        for (var i = 0; i < notifications.length; i++) {
            if (notifications[i].id !== id) {
                arr.push(notifications[i])
            }
        }
        notifications = arr
        notificationsChanged()
    }

    function clearAll() {
        notifications = []
        notificationsChanged()
    }

    Process { id: syncProc }

    // Enforce BottomRight Popup Position for KDE notifications on startup
    Process {
        id: initPositionProc
        command: ["kwriteconfig6", "--file", "plasmanotifyrc", "--group", "Notifications", "--key", "PopupPosition", "BottomRight"]
        running: true
    }

    // Disable KDE Plasma default popups so only Quickshell's notification toasts appear
    Process {
        id: disableKdePopupsProc
        command: ["kwriteconfig6", "--file", "plasmanotifyrc", "--group", "Notifications", "--key", "ShowPopups", "false"]
        running: true
    }

    // Persistent DBus Notification Inhibitor Process (Suppresses Plasmashell default top-left popups)
    Process {
        id: dndProc
        command: ["python3", "-u", Quickshell.env("HOME") + "/.config/quickshell/services/python/dnd_inhibitor.py"]
        running: true
        stdout: SplitParser {
            onRead: data => root.dndActive = (data.trim() === "true")
        }
    }

    signal notificationReceived(var notification)

    // Real-Time DBus Notification Monitor Process
    Process {
        id: notifProc
        command: ["python3", "-u", Quickshell.env("HOME") + "/.config/quickshell/services/python/notification_service.py"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                if (!root.isDnd) {
                    try {
                        let parsed = JSON.parse(data.trim())
                        if (parsed && parsed.id) {
                            let arr = root.notifications.slice()
                            arr.unshift(parsed)
                            if (arr.length > 20) arr.pop()
                            root.notifications = arr
                            root.notificationReceived(parsed)
                        }
                    } catch (e) {}
                }
            }
        }
    }
}
