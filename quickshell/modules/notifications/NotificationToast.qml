import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../services"

PanelWindow {
    id: toastWindow
    anchors {
        bottom: true
        right: true
    }
    margins {
        bottom: 74
        right: 20
    }

    WlrLayershell.layer: WlrLayershell.Top
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    property var currentToast: null
    visible: currentToast !== null && !NotificationService.isDnd

    implicitWidth: 340
    implicitHeight: toastCard.implicitHeight

    Timer {
        id: dismissTimer
        interval: 4500
        repeat: false
        onTriggered: {
            toastWindow.currentToast = null
        }
    }

    Connections {
        target: NotificationService
        function onNotificationReceived(notif) {
            toastWindow.currentToast = notif
            dismissTimer.restart()
        }
    }

    // Glassmorphism Card Container
    Rectangle {
        id: toastCard
        anchors.fill: parent
        radius: 14
        color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.90)
        border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.40)
        border.width: 1

        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }

        implicitHeight: contentColumn.implicitHeight + 24

        ColumnLayout {
            id: contentColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 6

            // Header Row: App Icon / Title / Time / Close Button
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    width: 24
                    height: 24
                    radius: 6
                    color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22)
                    border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.45)
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "🔔"
                        font.pixelSize: Theme.fsStrong
                    }
                }

                Text {
                    text: toastWindow.currentToast ? (toastWindow.currentToast.app || "Notification") : ""
                    color: Theme.accent
                    font.pixelSize: Theme.fsStrong
                    font.weight: Font.Bold
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                Text {
                    text: toastWindow.currentToast ? (toastWindow.currentToast.time || "") : ""
                    color: Theme.textMuted
                    font.pixelSize: Theme.fsCaption
                    font.family: Theme.fontFamily
                    font.weight: Font.Medium
                }

                // Close Button
                Rectangle {
                    width: 22
                    height: 22
                    radius: 11
                    color: closeMouse.containsMouse ? Qt.rgba(255/255, 85/255, 85/255, 0.85) : Qt.rgba(255/255, 255/255, 255/255, 0.08)

                    Behavior on color { ColorAnimation { duration: 100 } }

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: closeMouse.containsMouse ? Theme.fg : Theme.textMuted
                        font.pixelSize: Theme.fsCaption
                        font.weight: Font.Bold
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: toastWindow.currentToast = null
                    }
                }
            }

            // Summary Title
            Text {
                text: toastWindow.currentToast ? (toastWindow.currentToast.summary || "") : ""
                color: Theme.fg
                font.pixelSize: Theme.fsSubhead
                font.family: Theme.fontFamily
                font.weight: Font.DemiBold
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                visible: text !== ""
            }

            // Body Content
            Text {
                text: toastWindow.currentToast ? (toastWindow.currentToast.body || "") : ""
                color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.8)
                font.pixelSize: Theme.fsBody
                font.family: Theme.fontFamily
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                maximumLineCount: 3
                elide: Text.ElideRight
                visible: text !== ""
            }
        }
    }
}
