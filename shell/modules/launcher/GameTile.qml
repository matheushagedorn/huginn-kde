import QtQuick
import Quickshell.Widgets
import "../../services"
import "../../theme"

// One game in the launcher's Games tab: the portrait cover stores use for
// their libraries, with the title under it and where it comes from in the
// machine's voice.
//
// Hover, selection and press behave exactly like AppTile, so moving between
// the app grid and the game grid does not change what "selected" looks like.
Item {
    id: root

    property var game: null
    property bool selected: false

    // Height of the two text lines under the cover. The launcher sizes its
    // cells with the same number, so the tile never outgrows its cell.
    readonly property int labelHeight: 40

    signal activated()
    signal contextRequested(real globalX, real globalY)
    signal hoverEntered()

    // False while something is drawn over the grid, such as the context menu.
    property bool interactive: true

    readonly property bool isFavorite: AppLauncherService.isFavorite(game)

    Rectangle {
        id: surface
        anchors.fill: parent
        anchors.margins: Theme.sp1
        radius: Theme.radiusCard
        color: root.selected
               ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.16)
               : (tileMouse.containsMouse ? Theme.surface : "transparent")

        Behavior on color { ColorAnimation { duration: 120 } }

        scale: tileMouse.pressed ? 0.96 : 1.0
        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }

        // ClippingRectangle, not a Rectangle with clip: Qt Quick's own clip
        // is rectangular whatever the radius, and the cover's corners would
        // poke out of the rounded frame.
        ClippingRectangle {
            id: coverFrame
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: Theme.sp2
            height: Math.round(width * 1.5)
            radius: Theme.radiusChip
            color: Theme.surface

            Image {
                id: cover
                anchors.fill: parent
                source: AppLauncherService.coverSource(root.game)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
                // Only the width, so the height follows the file's own
                // aspect; twice the drawn size keeps the art crisp.
                sourceSize.width: Math.round(coverFrame.width * 2)
                visible: status === Image.Ready
            }

            // No cover yet (still downloading, or the store has none): the
            // title on a card tinted with the accent, so the grid keeps its
            // rhythm instead of showing a hole.
            Rectangle {
                anchors.fill: parent
                visible: !cover.visible
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.30) }
                    GradientStop { position: 1.0; color: Qt.rgba(Theme.subAccent.r, Theme.subAccent.g, Theme.subAccent.b, 0.14) }
                }

                Text {
                    anchors.fill: parent
                    anchors.margins: Theme.sp3
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: root.game ? root.game.name : ""
                    color: Theme.fg
                    font.pixelSize: Theme.fsHead
                    font.family: Theme.fontFamily
                    font.weight: Font.Medium
                    wrapMode: Text.WordWrap
                    elide: Text.ElideRight
                    maximumLineCount: 5
                }
            }

            // Favourite marker, as on app tiles. It sits on artwork here, so
            // it gets a ring in the panel colour to stay visible on any cover.
            Rectangle {
                visible: root.isFavorite
                width: 9
                height: 9
                radius: 4.5
                color: Theme.accent
                border.color: Theme.bg
                border.width: 2
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: Theme.sp2
            }
        }

        Column {
            anchors.top: coverFrame.bottom
            anchors.topMargin: Theme.sp2
            anchors.left: coverFrame.left
            anchors.right: coverFrame.right
            height: root.labelHeight
            spacing: 2

            Text {
                width: parent.width
                text: root.game ? root.game.name : ""
                color: Theme.fg
                font.pixelSize: Theme.fsBody
                font.family: Theme.fontFamily
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Text {
                width: parent.width
                text: root.game && root.game.source ? root.game.source.toLowerCase() : ""
                color: Theme.textMuted
                font.pixelSize: Theme.fsCaption
                font.family: Theme.fontMono
                elide: Text.ElideRight
            }
        }
    }

    MouseArea {
        id: tileMouse
        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: root.interactive
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onEntered: root.hoverEntered()
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                let pt = root.mapToItem(null, mouse.x, mouse.y)
                root.contextRequested(pt.x, pt.y)
            } else {
                root.activated()
            }
        }
    }
}
