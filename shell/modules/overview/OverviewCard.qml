import QtQuick
import Quickshell.Widgets
import "../../components"
import "../../services"
import "../../theme"

// One window in the overview: its captured frame, and under it the app's icon
// and the window's title.
//
// The frame is what moves. At progress 0 it sits exactly over the real
// window, at 1 in its slot, and in between it is simply the mix of the two:
// the overview opens by the windows themselves shrinking into place and
// closes by them growing back. The caption is not part of the window, so it
// only fades.
Item {
    id: card

    property var overview: null
    property string windowId: ""
    property real screenX: 0
    property real screenY: 0
    // { x, y, width, height, frameHeight } in this screen's coordinates, or
    // null while the search is hiding this card.
    property var slot: null

    readonly property var win: {
        let list = overview ? overview.windows : []
        for (let i = 0; i < list.length; i++) {
            if (list[i].id === windowId) return list[i]
        }
        return null
    }

    readonly property real progress: overview ? overview.progress : 0
    readonly property bool shown: slot !== null
    readonly property bool selected: overview && overview.selectedId === windowId && shown
    readonly property bool closing: overview && overview.closingIds[windowId] !== undefined
    readonly property bool minimized: win ? win.minimized : false
    readonly property string shotPath: overview && overview.shots[windowId] ? overview.shots[windowId] : ""

    // The slot, eased when it changes while the overview is up: a window
    // closing or the search narrowing the set moves the others, and a jump
    // would lose track of which card is which. During the entrance and the
    // exit the mix with the real window is the animation, so the easing
    // steps aside.
    property real slotX: 0
    property real slotY: 0
    property real slotWidth: 1
    property real frameHeight: 1
    readonly property bool settled: progress >= 1

    function takeSlot() {
        if (!slot) return
        slotX = slot.x
        slotY = slot.y
        slotWidth = slot.width
        frameHeight = slot.frameHeight
    }
    onSlotChanged: takeSlot()
    Component.onCompleted: takeSlot()

    Behavior on slotX { enabled: card.settled; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    Behavior on slotY { enabled: card.settled; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    Behavior on slotWidth { enabled: card.settled; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    Behavior on frameHeight { enabled: card.settled; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    // Where the window really is. A minimized one is not anywhere, so its
    // card grows out of its own slot instead of out of a stale position.
    readonly property real realX: win && !minimized ? win.x - screenX : slotX + slotWidth * 0.08
    readonly property real realY: win && !minimized ? win.y - screenY : slotY + frameHeight * 0.08
    readonly property real realWidth: win && !minimized ? win.width : slotWidth * 0.84
    readonly property real realHeight: win && !minimized ? win.height : frameHeight * 0.84

    function mix(a, b) { return a + (b - a) * card.progress }

    x: mix(realX, slotX)
    y: mix(realY, slotY)
    width: mix(realWidth, slotWidth)
    height: frame.height + captionRow.height

    // A card the search hides fades where it stands; a minimized one, or one
    // with no frame yet, fades in rather than covering its window with a bare
    // icon before the wash is there to explain it.
    opacity: {
        let base = shown ? 1 : 0
        if (minimized || frame.readyShot === "") base *= progress
        if (closing) base *= 0.4
        // Only the window in front is drawn solid while the cards are near
        // their windows; the rest come out of, and dissolve back into, the
        // windows they stand for. See frontId in Overview.qml.
        if (!overview || overview.frontCard !== windowId) base *= progress
        return base
    }
    z: overview && overview.frontCard === windowId ? 1 : 0
    visible: opacity > 0.01
    Behavior on opacity { enabled: card.settled; NumberAnimation { duration: 160 } }

    function closeThis() {
        if (overview) overview.closeWindow(windowId)
    }

    // ── The frame ─────────────────────────────────────────────────────────
    ClippingRectangle {
        id: frame
        width: parent.width
        height: card.mix(card.realHeight, card.frameHeight)
        radius: Theme.radiusCard * card.progress
        color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.85)

        // The last frame that finished loading stays up while the next one
        // loads: swapping the source of a single Image blanks it for a beat,
        // and that blink on every opening is the one thing people would see.
        property string readyShot: ""

        Image {
            anchors.fill: parent
            visible: frame.readyShot !== ""
            source: frame.readyShot !== "" ? "file://" + frame.readyShot : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: false
            cache: true
            smooth: true
            opacity: card.minimized ? 0.6 : 1
        }

        Image {
            id: incoming
            visible: false
            source: card.shotPath !== "" ? "file://" + card.shotPath : ""
            asynchronous: true
            cache: true
            onStatusChanged: if (status === Image.Ready) frame.readyShot = card.shotPath
        }

        // No frame to show (not captured yet, or the window has no buffer):
        // the application's icon stands in for it.
        AppIcon {
            anchors.centerIn: parent
            width: Math.min(64, parent.height * 0.4)
            height: width
            visible: frame.readyShot === ""
            source: card.win ? AppLauncherService.iconSource(card.win.icon) : ""
            scaleHint: card.win && card.win.iconScale !== undefined ? card.win.iconScale : 1.0
        }

        // Hover and selection are one state: the keyboard picks up from
        // wherever the pointer last rested.
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            radius: frame.radius
            border.width: card.selected ? 2 : 1
            border.color: card.selected
                ? Theme.accent
                : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.10 * card.progress)

            Behavior on border.color { ColorAnimation { duration: 120 } }
        }
    }

    // ── The caption ───────────────────────────────────────────────────────
    Item {
        id: captionRow
        anchors.top: frame.bottom
        width: parent.width
        height: card.overview ? card.overview.captionHeight : 36
        opacity: card.progress

        Row {
            anchors.centerIn: parent
            spacing: Theme.sp2
            width: Math.min(implicitWidth, parent.width)

            AppIcon {
                width: 20
                height: 20
                anchors.verticalCenter: parent.verticalCenter
                source: card.win ? AppLauncherService.iconSource(card.win.icon) : ""
                scaleHint: card.win && card.win.iconScale !== undefined ? card.win.iconScale : 1.0
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, captionRow.width - 20 - Theme.sp2)
                text: card.win ? (card.win.caption || card.win.name || "") : ""
                color: card.selected ? Theme.fg : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.78)
                font.pixelSize: Theme.fsBody
                font.family: Theme.fontFamily
                font.weight: card.selected ? Font.DemiBold : Font.Normal
                elide: Text.ElideRight
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: card.minimized
                text: "minimized"
                color: Theme.textMuted
                font.pixelSize: Theme.fsCaption
                font.family: Theme.fontMono
            }
        }
    }

    // ── Input ─────────────────────────────────────────────────────────────
    MouseArea {
        id: cardMouse
        anchors.fill: parent
        enabled: card.shown && card.overview && card.overview.open
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        // The pointer moving, not merely being there: cards fly in under a
        // pointer that has not moved, and each one they cross would steal the
        // selection from the window the overview opened on.
        onPositionChanged: {
            if (card.overview && card.settled) card.overview.selectedId = card.windowId
        }
        onClicked: (mouse) => {
            if (mouse.button === Qt.MiddleButton) card.closeThis()
            else if (card.overview) card.overview.activate(card.windowId)
        }
    }

    // Close, in the corner of the frame, only while the pointer is on the card.
    Rectangle {
        id: closeButton
        width: 28
        height: 28
        radius: 14
        anchors.top: frame.top
        anchors.right: frame.right
        anchors.margins: Theme.sp2
        visible: cardMouse.containsMouse || closeMouse.containsMouse
        color: closeMouse.containsMouse
            ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.90)
            : Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.80)
        border.width: 1
        border.color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.14)

        Behavior on color { ColorAnimation { duration: 100 } }

        UiIcon {
            anchors.centerIn: parent
            name: "x"
            width: 14
            height: 14
            color: closeMouse.containsMouse ? Theme.bg : Theme.fg
        }

        MouseArea {
            id: closeMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: cardMouse.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: card.closeThis()
        }
    }
}
