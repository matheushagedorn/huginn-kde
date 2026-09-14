import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../components"
import "../../services"
import "../../theme"

GlassPanel {
    id: root
    implicitWidth: mainLayout.implicitWidth + 24
    implicitHeight: Theme.barHeight - 4

    // Where the row of controls starts inside the panel: the GlassPanel
    // inset plus the row margin, read from the items themselves.
    readonly property real contentInset: mainLayout.parent.x + mainLayout.x

    RowLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 8

        // Power / Session Trigger Button
        Rectangle {
            id: sessionBtn
            Layout.preferredWidth: 26
            Layout.preferredHeight: Theme.barCapsule
            radius: 6
            color: PopupService.sessionMenuOpen
                   ? Theme.stateActive
                   : (sessionMouse.containsMouse ? Theme.currentLine : "transparent")
            border.color: PopupService.sessionMenuOpen ? Theme.accent : "transparent"
            border.width: PopupService.sessionMenuOpen ? 1 : 0

            Behavior on color { ColorAnimation { duration: 120 } }

            UiIcon {
                anchors.centerIn: parent
                name: "power"
                color: sessionMouse.containsMouse ? Theme.accent : Theme.fg
                implicitWidth: 16
                implicitHeight: 16
            }

            MouseArea {
                id: sessionMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: PopupService.toggleSession()
            }
        }

        // Minimal Divider Line (Shown only when virtual desktops exist)
        Rectangle {
            Layout.preferredWidth: 1
            Layout.preferredHeight: 14
            color: Theme.separator
            visible: WorkspaceService.hasWorkspaces
        }

        // Dynamic Workspace Switcher
        Item {
            id: workspaceContainer
            visible: WorkspaceService.hasWorkspaces
            Layout.preferredWidth: wsRow.implicitWidth
            Layout.preferredHeight: 22
            Layout.alignment: Qt.AlignVCenter

            RowLayout {
                id: wsRow
                anchors.centerIn: parent
                spacing: 4

                Repeater {
                    model: WorkspaceService.workspaceNames

                    Rectangle {
                        id: wsItem
                        property int wsNumber: index + 1
                        property bool isActive: WorkspaceService.activeWorkspace === wsNumber

                        Layout.preferredWidth: isActive ? Math.max(32, wsText.implicitWidth + 16) : Math.max(26, wsText.implicitWidth + 14)
                        Layout.preferredHeight: 22
                        Layout.fillHeight: false
                        Layout.alignment: Qt.AlignVCenter
                        radius: 7
                        color: isActive 
                            ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.20)
                            : (wsItemMouse.containsMouse ? Qt.rgba(255/255, 255/255, 255/255, 0.08) : "transparent")
                        border.color: isActive 
                            ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.65)
                            : (wsItemMouse.containsMouse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.3) : "transparent")
                        border.width: 1

                        Behavior on Layout.preferredWidth { NumberAnimation { duration: 140; easing.type: Easing.OutQuint } }
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        Text {
                            id: wsText
                            anchors.centerIn: parent
                            text: modelData
                            color: wsItem.isActive ? Theme.accent : (wsItemMouse.containsMouse ? Theme.fg : Theme.comment)
                            font.pixelSize: Theme.fsBody
                            font.family: Theme.fontFamily
                            font.weight: wsItem.isActive ? Font.Bold : Font.Medium
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignHCenter

                            Behavior on color { ColorAnimation { duration: 120 } }
                        }

                        MouseArea {
                            id: wsItemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: {
                                wsHoverTimer.stop()
                                root.hoverWsIndex = wsItem.wsNumber
                                root.isWsHovered = true
                            }
                            onExited: {
                                wsHoverTimer.restart()
                            }
                            onClicked: {
                                PopupService.closeAll()
                                WorkspaceService.switchTo(wsItem.wsNumber)
                            }
                        }
                    }
                }
            }

            // Scroll Throttle Timer (Eliminates scroll lag during rapid mouse wheel scrolling)
            Timer {
                id: scrollThrottleTimer
                interval: 120
                repeat: false
            }

            // Global Mouse Wheel Scroll Area
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton

                onWheel: (wheel) => {
                    if (scrollThrottleTimer.running) return;
                    scrollThrottleTimer.restart();
                    PopupService.closeAll()

                    if (wheel.angleDelta.y < 0) {
                        if (WorkspaceService.activeWorkspace < WorkspaceService.totalWorkspaces) {
                            WorkspaceService.switchTo(WorkspaceService.activeWorkspace + 1)
                        }
                    } else if (wheel.angleDelta.y > 0) {
                        if (WorkspaceService.activeWorkspace > 1) {
                            WorkspaceService.switchTo(WorkspaceService.activeWorkspace - 1)
                        }
                    }
                }
            }
        }
    }

    // Detached Solid Session Popup Window (Controlled by PopupService)
    PopupWindow {
        id: sessionMenu
        anchor.window: window
        anchor.rect.x: Theme.popupX(root, root.contentInset + sessionBtn.x, sessionBtn.width, implicitWidth, window.width, root.contentInset)
        anchor.rect.y: Theme.popupGap
        anchor.edges: Edges.Bottom
        visible: false
        color: "transparent"

        implicitWidth: contentGlass.implicitWidth
        implicitHeight: contentGlass.implicitHeight

        property real animProgress: 0.0

        NumberAnimation on animProgress {
            id: sessPopIn
            running: false
            to: 1.0
            duration: 220
            easing.type: Easing.OutBack
            easing.overshoot: 1.15
        }

        NumberAnimation on animProgress {
            id: sessPopOut
            running: false
            to: 0.0
            duration: 160
            easing.type: Easing.InQuad
            onFinished: sessionMenu.visible = false
        }

        Connections {
            target: PopupService
            function onSessionMenuOpenChanged() {
                if (PopupService.sessionMenuOpen) {
                    sessPopOut.running = false
                    sessionMenu.visible = true
                    sessPopIn.restart()
                } else if (sessionMenu.visible) {
                    sessPopIn.running = false
                    sessPopOut.restart()
                }
            }
        }

        GlassPanel {
            id: contentGlass
            // Fixed width: the rows fill it, so nothing in the layout drives
            // an intrinsic width, and a menu reads better when its items share
            // one hit area than when it hugs the longest label.
            implicitWidth: 172
            // + 8 for the inset GlassPanel puts around its own children.
            implicitHeight: menuLayout.implicitHeight + Theme.sp2 + 8
            anchors.fill: parent

            opacity: sessionMenu.animProgress
            scale: 0.90 + 0.10 * sessionMenu.animProgress
            transformOrigin: Item.TopLeft

            ColumnLayout {
                id: menuLayout
                anchors.fill: parent
                anchors.margins: Theme.sp1
                spacing: 1

                // The four actions used to be marked by coloured dots — purple,
                // cyan, blue, red — which looked like a code and was not one.
                // Only "power off" is destructive, so only it is allowed colour,
                // and only on hover. Everything else is one quiet family, and
                // the glyph carries the meaning.
                //
                // The rule groups them by what they act on: the session above,
                // the machine below.
                component SessionAction: Rectangle {
                    id: action

                    property string label: ""
                    property string icon: ""
                    property bool destructive: false
                    signal triggered

                    readonly property color tint: destructive && hover.containsMouse
                                                  ? Theme.danger : Theme.fg

                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    radius: Theme.radiusChip
                    color: hover.containsMouse
                           ? (destructive ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.12)
                                          : Theme.stateHover)
                           : "transparent"

                    Behavior on color { ColorAnimation { duration: 110; easing.type: Easing.OutCubic } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.sp2
                        anchors.rightMargin: Theme.sp3
                        spacing: Theme.sp2

                        UiIcon {
                            name: action.icon
                            color: action.tint
                            implicitWidth: 15
                            implicitHeight: 15
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Text {
                            text: action.label
                            color: action.tint
                            font.pixelSize: Theme.fsBody
                            font.family: Theme.fontFamily
                            font.weight: Font.Medium
                            Layout.alignment: Qt.AlignVCenter
                            Layout.fillWidth: true
                        }
                    }

                    MouseArea {
                        id: hover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            action.triggered()
                            PopupService.closeAll()
                        }
                    }
                }

                SessionAction {
                    label: "Lock"
                    icon: "lock"
                    onTriggered: SessionService.lock()
                }

                SessionAction {
                    label: "Log out"
                    icon: "log-out"
                    onTriggered: SessionService.logout()
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.sp1
                    Layout.bottomMargin: Theme.sp1
                    Layout.preferredHeight: 1
                    color: Theme.separator
                }

                SessionAction {
                    label: "Restart"
                    icon: "rotate-ccw"
                    onTriggered: SessionService.reboot()
                }

                SessionAction {
                    label: "Shut down"
                    icon: "power"
                    destructive: true
                    onTriggered: SessionService.shutdown()
                }
            }
        }
    }

    // Workspace Preview Floating Glass Popover
    property int hoverWsIndex: -1
    property bool isWsHovered: false

    Timer {
        id: wsHoverTimer
        interval: 600
        repeat: false
        onTriggered: root.isWsHovered = false
    }

    PopupWindow {
        id: wsPreviewPopup
        anchor.window: window
        anchor.rect.x: Theme.popupX(root, root.contentInset + root.hoverWsIndex * 32, 32, implicitWidth, window.width, root.contentInset)
        anchor.rect.y: Theme.popupGap
        anchor.edges: Edges.Bottom
        visible: root.isWsHovered && root.hoverWsIndex >= 1
        color: "transparent"

        implicitWidth: wsPreviewGlass.implicitWidth
        implicitHeight: wsPreviewGlass.implicitHeight

        GlassPanel {
            id: wsPreviewGlass
            implicitWidth: 150
            implicitHeight: 32
            anchors.fill: parent

            MouseArea {
                anchors.fill: parent
                anchors.margins: -10
                hoverEnabled: true
                onEntered: wsHoverTimer.stop()
                onExited: wsHoverTimer.restart()
            }

            RowLayout {
                anchors.centerIn: parent
                spacing: 6

                Rectangle {
                    width: 6; height: 6; radius: 3
                    color: Theme.accent
                }

                Text {
                    text: "Workspace " + root.hoverWsIndex
                    color: Theme.fg
                    font.pixelSize: Theme.fsBody
                    font.family: Theme.fontFamily
                    font.weight: Font.Bold
                }

                Text {
                    text: root.hoverWsIndex === WorkspaceService.activeWorkspace ? "Active" : "Switch"
                    color: root.hoverWsIndex === WorkspaceService.activeWorkspace ? Theme.accent : Theme.comment
                    font.pixelSize: Theme.fsCaption
                    font.family: Theme.fontFamily
                }
            }
        }
    }
}
