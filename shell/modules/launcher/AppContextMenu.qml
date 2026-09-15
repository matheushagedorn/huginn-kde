import QtQuick
import QtQuick.Layouts
import "../../services"
import "../../theme"

// Right-click menu for an application tile.
//
// Deliberately NOT a PopupWindow. The launcher already owns a full-screen
// surface, so the menu is drawn inside it: no anchor gravity to get wrong, no
// fixed size to guess, and the height can follow the content — an app with
// three desktop actions and one with none both get a menu that fits.
Item {
    id: root

    property var app: null
    property bool opened: false

    // Where the menu was asked to appear, in this item's coordinates.
    property real originX: 0
    property real originY: 0

    readonly property var actions: app && app.actions ? app.actions : []

    signal closed()

    anchors.fill: parent
    visible: opened || closeAnim.running
    z: 100

    function openAt(x, y, targetApp) {
        app = targetApp
        originX = x
        originY = y
        opened = true
        openAnim.restart()
    }

    function close() {
        if (!opened) return
        opened = false
        closeAnim.restart()
        root.closed()
    }

    // Click anywhere else dismisses the menu without closing the launcher.
    //
    // hoverEnabled is not about this area wanting hover: it is about taking it
    // away from the grid underneath. Without it the tiles kept highlighting
    // and stealing the selection as the pointer crossed the open menu.
    MouseArea {
        anchors.fill: parent
        enabled: root.opened
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: root.close()
    }

    property real animProgress: 0.0

    NumberAnimation on animProgress {
        id: openAnim
        running: false
        to: 1.0
        duration: 140
        easing.type: Easing.OutCubic
    }

    NumberAnimation on animProgress {
        id: closeAnim
        running: false
        to: 0.0
        duration: 100
        easing.type: Easing.InQuad
    }

    Rectangle {
        id: card

        // Kept fully on screen: a menu opened next to the right edge grows to
        // the left instead of off the panel.
        x: Math.max(Theme.sp2, Math.min(root.width - width - Theme.sp2, root.originX))
        y: Math.max(Theme.sp2, Math.min(root.height - height - Theme.sp2, root.originY))

        width: 224
        implicitHeight: menuColumn.implicitHeight + Theme.sp3 * 2
        height: implicitHeight

        radius: Theme.radiusCard
        color: Theme.bg
        border.color: Theme.separator
        border.width: 1

        opacity: root.animProgress
        scale: 0.96 + 0.04 * root.animProgress
        transformOrigin: Item.TopLeft

        // Swallows clicks so the dismiss layer below doesn't get them.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: {}
        }

        ColumnLayout {
            id: menuColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.sp3
            spacing: Theme.sp1

            // Header: which app this menu belongs to
            RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: Theme.sp1
                spacing: Theme.sp2

                Image {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: 18
                    Layout.preferredHeight: 18
                    sourceSize.width: 18
                    sourceSize.height: 18
                    fillMode: Image.PreserveAspectFit
                    source: root.app ? AppLauncherService.iconSource(root.app.icon) : ""
                    smooth: true
                }

                Text {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: root.app ? root.app.name : ""
                    color: Theme.fg
                    font.pixelSize: Theme.fsBody
                    font.family: Theme.fontFamily
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                Layout.bottomMargin: Theme.sp1
                color: Theme.separator
            }

            MenuRow {
                label: "Open"
                onTriggered: {
                    AppLauncherService.launch(root.app)
                    root.close()
                }
            }

            // The app's own desktop actions, in the order the file declares
            // them. Apps without any simply skip this block.
            Repeater {
                model: root.actions
                delegate: MenuRow {
                    required property var modelData
                    label: modelData.name
                    onTriggered: {
                        AppLauncherService.launchAction(root.app, modelData)
                        root.close()
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                Layout.topMargin: Theme.sp1
                Layout.bottomMargin: Theme.sp1
                color: Theme.separator
            }

            MenuRow {
                label: AppLauncherService.isFavorite(root.app) ? "Remove from favorites" : "Add to favorites"
                onTriggered: {
                    AppLauncherService.toggleFavorite(root.app)
                    root.close()
                }
            }

            MenuRow {
                label: AppLauncherService.isPinnedToDock(root.app) ? "Unpin from dock" : "Pin to dock"
                onTriggered: {
                    AppLauncherService.togglePinToDock(root.app)
                    root.close()
                }
            }
        }
    }

    component MenuRow: Rectangle {
        id: row
        property string label: ""
        signal triggered()

        Layout.fillWidth: true
        Layout.preferredHeight: 28
        radius: Theme.radiusChip
        color: rowMouse.containsMouse ? Theme.surface : "transparent"

        Behavior on color { ColorAnimation { duration: 100 } }

        Text {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Theme.sp2
            anchors.rightMargin: Theme.sp2
            anchors.verticalCenter: parent.verticalCenter
            text: row.label
            color: rowMouse.containsMouse ? Theme.accent : Theme.fg
            font.pixelSize: Theme.fsBody
            font.family: Theme.fontFamily
            elide: Text.ElideRight
        }

        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: row.triggered()
        }
    }
}
