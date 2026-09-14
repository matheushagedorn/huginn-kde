import QtQuick
import "../theme"

// Notification bell. Unread is a dot rather than a different glyph, so the
// silhouette stays the same and only the state reads as new.
Item {
    id: root
    implicitWidth: 16
    implicitHeight: 16

    property bool isDnd: false
    property bool hasUnread: false
    property color color: Theme.fg

    UiIcon {
        anchors.fill: parent
        name: root.isDnd ? "bell-off" : "bell"
        color: root.color
    }

    Rectangle {
        visible: root.hasUnread && !root.isDnd
        width: Math.max(6, root.width * 0.44)
        height: width
        radius: width / 2
        anchors.right: parent.right
        anchors.top: parent.top
        color: Theme.bg

        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.62
            height: width
            radius: width / 2
            color: Theme.accent
        }
    }
}
