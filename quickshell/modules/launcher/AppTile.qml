import QtQuick
import QtQuick.Layouts
import "../../services"
import "../../theme"

// One application in the launcher: icon, name, and the two states it can be
// in (hovered, selected).
//
// Selection used to be signalled three ways at once — background tint, accent
// border and a 1.05 scale — which made the grid twitch on every arrow key.
// Here one filled block says "selected" and nothing moves; the press is the
// only motion, because that one answers the user's own action.
Item {
    id: root

    property var app: null
    property bool selected: false
    property int iconSize: 64
    property int labelLines: 2
    property bool showFavoriteDot: true

    signal activated()
    signal contextRequested(real globalX, real globalY)
    signal hoverEntered()

    readonly property bool isFavorite: AppLauncherService.isFavorite(app)

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

        ColumnLayout {
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: Theme.sp3
            spacing: Theme.sp2
            width: parent.width - Theme.sp3

            Item {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: root.iconSize
                Layout.preferredHeight: root.iconSize

                Image {
                    id: appIcon
                    anchors.fill: parent
                    sourceSize.width: root.iconSize
                    sourceSize.height: root.iconSize
                    fillMode: Image.PreserveAspectFit
                    source: root.app ? AppLauncherService.iconSource(root.app.icon) : ""
                    smooth: true
                    asynchronous: true
                    visible: status === Image.Ready

                    onStatusChanged: {
                        if (status === Image.Error) {
                            let fallback = AppLauncherService.iconSource("")
                            if (source !== fallback) source = fallback
                        }
                    }
                }

                // Shown when the icon theme has nothing for this app: the
                // initial in the app's own accent beats a broken-image box.
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusCard
                    color: Theme.surface
                    visible: appIcon.status !== Image.Ready

                    Text {
                        anchors.centerIn: parent
                        text: root.app && root.app.name ? root.app.name.charAt(0).toUpperCase() : "?"
                        color: Theme.accent
                        font.pixelSize: Math.round(root.iconSize * 0.4)
                        font.family: Theme.fontFamily
                        font.weight: Font.Medium
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.ceil(nameMetrics.height * root.labelLines)
                verticalAlignment: Text.AlignTop
                horizontalAlignment: Text.AlignHCenter

                FontMetrics {
                    id: nameMetrics
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsBody
                }

                text: root.app ? root.app.name : ""
                color: Theme.fg
                font.pixelSize: Theme.fsBody
                font.family: Theme.fontFamily
                font.weight: Font.Normal
                elide: Text.ElideRight
                maximumLineCount: root.labelLines
                wrapMode: Text.WordWrap
            }
        }

        // Favourite marker. A dot, not a star: the grid is already full of
        // application icons competing for attention.
        Rectangle {
            visible: root.showFavoriteDot && root.isFavorite
            width: 5
            height: 5
            radius: 2.5
            color: Theme.accent
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: Theme.sp2
        }
    }

    MouseArea {
        id: tileMouse
        anchors.fill: parent
        hoverEnabled: true
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

    // Lets the launcher track hover for keyboard/mouse selection without the
    // tile owning that state.
    readonly property bool hovered: tileMouse.containsMouse
}
