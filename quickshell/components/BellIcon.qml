import QtQuick
import "../theme"

// Notification bell, from the active icon theme so it matches the weight and
// fill of the other panel indicators instead of being a hand-drawn outline.
//
// Papirus ships the two states as separate files. The unread dot is drawn on
// top rather than using the theme's own `notification-active`, whose dot is a
// hardcoded blue that ignores the palette.
Item {
    id: root
    implicitWidth: 16
    implicitHeight: 16

    property bool isDnd: false
    property bool hasUnread: false

    Image {
        id: glyph
        anchors.fill: parent
        sourceSize.width: Math.round(width)
        sourceSize.height: Math.round(height)
        fillMode: Image.PreserveAspectFit
        source: "file://" + Theme.iconsDir + "/" + Theme.panelIconDir + "/24x24/panel/"
                + (root.isDnd ? "notifications-disabled.svg" : "notifications.svg")
        visible: status === Image.Ready
    }

    // Drawn fallback, in case the icon theme has no bell.
    Canvas {
        anchors.fill: parent
        visible: glyph.status === Image.Error || glyph.status === Image.Null
        antialiasing: true
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var w = width, h = height
            ctx.fillStyle = Theme.fg
            ctx.beginPath()
            ctx.moveTo(w * 0.16, h * 0.68)
            ctx.quadraticCurveTo(w * 0.28, h * 0.62, w * 0.29, h * 0.44)
            ctx.arc(w * 0.5, h * 0.44, w * 0.21, Math.PI, 0, false)
            ctx.quadraticCurveTo(w * 0.72, h * 0.62, w * 0.84, h * 0.68)
            ctx.closePath()
            ctx.fill()
            ctx.beginPath()
            ctx.arc(w * 0.5, h * 0.78, w * 0.1, 0, Math.PI, false)
            ctx.fill()
        }
    }

    // Unread marker. The ring is the panel background, so the dot stays legible
    // wherever it lands on the bell.
    Rectangle {
        visible: root.hasUnread && !root.isDnd
        // Kept inside the icon's own box: hanging it outside gets clipped by
        // the capsule the icon sits in.
        width: Math.max(6, root.width * 0.44)
        height: width
        radius: width / 2
        anchors.right: parent.right
        anchors.top: parent.top
        color: Theme.bg

        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.66
            height: width
            radius: width / 2
            color: Theme.accent
        }
    }
}
