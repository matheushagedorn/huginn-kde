pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// Huginn is the notification server.
//
// It used to only eavesdrop: `notification_service.py` ran `dbus-monitor`
// filtered on `member='Notify'` and parsed the text output. That needs somebody
// else to actually own org.freedesktop.Notifications, and on this setup nobody
// does — Plasma serves notifications from the panel applet, and Huginn's own
// README tells you to remove the panel. The result was that no notification
// from any application reached anything at all.
//
// Owning the name instead also means notifications can be dismissed and their
// actions invoked, which snooping could never do.
Item {
    id: root

    property bool isDnd: false

    // Plain objects in the shape the UI already expects: {id, app, summary,
    // body, time}, newest first. `ref` carries the live Notification so it can
    // be dismissed properly rather than just dropped from the list.
    property var notifications: []

    readonly property int maxKept: 20

    function toggleDnd() {
        isDnd = !isDnd
    }

    function dismissNotification(id) {
        var kept = []
        for (var i = 0; i < notifications.length; i++) {
            var entry = notifications[i]
            if (entry.id === id) {
                if (entry.ref) entry.ref.dismiss()
            } else {
                kept.push(entry)
            }
        }
        notifications = kept
    }

    function clearAll() {
        for (var i = 0; i < notifications.length; i++) {
            if (notifications[i].ref) notifications[i].ref.dismiss()
        }
        notifications = []
    }

    signal notificationReceived(var notification)

    function formatTime(date) {
        var h = date.getHours()
        var m = date.getMinutes()
        return (h < 10 ? "0" : "") + h + ":" + (m < 10 ? "0" : "") + m
    }

    NotificationServer {
        id: server

        // Held across a config reload, so editing the shell does not wipe the
        // list or drop notifications that arrive while it reloads.
        keepOnReload: true

        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        actionsSupported: true

        onNotification: notification => {
            // Tracked means the server keeps the object alive for us; without
            // this it is destroyed as soon as this handler returns.
            notification.tracked = true

            if (root.isDnd) {
                notification.dismiss()
                return
            }

            var entry = {
                "id": notification.id,
                "app": notification.appName && notification.appName !== ""
                       ? notification.appName : "Notification",
                "summary": notification.summary,
                "body": notification.body,
                "time": root.formatTime(new Date()),
                "ref": notification
            }

            var arr = root.notifications.slice()
            arr.unshift(entry)
            while (arr.length > root.maxKept) {
                var dropped = arr.pop()
                if (dropped.ref) dropped.ref.dismiss()
            }
            root.notifications = arr
            root.notificationReceived(entry)
        }
    }

    // An application can withdraw its own notification. Drop it from the list
    // when that happens, instead of leaving a row that no longer exists.
    Connections {
        target: server.trackedNotifications
        // The signal is objectRemovedPost, not objectRemoved. QML only warns
        // about a Connections handler that matches nothing, so the wrong name
        // was silently doing nothing at all.
        function onObjectRemovedPost(object, index) {
            var kept = []
            for (var i = 0; i < root.notifications.length; i++) {
                if (root.notifications[i].ref !== object) {
                    kept.push(root.notifications[i])
                }
            }
            if (kept.length !== root.notifications.length) {
                root.notifications = kept
            }
        }
    }
}
