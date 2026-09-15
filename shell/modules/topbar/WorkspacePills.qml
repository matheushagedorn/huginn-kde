import QtQuick
import QtQuick.Layouts
import "../../services"
import "../../theme"

// The KWin virtual desktops, as pills.
//
// Lifted out of TopLeftBar so the bars on the other monitors can show the
// same thing without a second copy of it. Hover is reported outwards rather
// than handled here: only the bar that owns a popup window can open one.
Item {
    id: pills

    signal pillEntered(int index)
    signal pillExited()

    // Which pill the pointer is on, held here rather than read off each
    // MouseArea's containsMouse.
    //
    // A layer-shell surface does not always get a leave event: switching
    // desktop changes what is under the pointer without the pointer moving,
    // and the pill the click landed on kept its hover fill for good. Keeping
    // one index means there is one thing to clear, and switching desktop or
    // the pointer leaving the row both clear it.
    property int hoveredIndex: -1

    function clearHover() {
        hoveredIndex = -1
        pillExited()
    }

    HoverHandler {
        id: rowHover
        onHoveredChanged: if (!hovered) pills.clearHover()
    }

    Connections {
        target: WorkspaceService
        // Switching desktop is the moment the stale hover used to appear, and
        // it is only stale if the pointer is no longer on the row. Clearing it
        // while the pointer is still there would make the pill under the
        // cursor go dead until it moved away and back.
        function onActiveWorkspaceChanged() {
            if (!rowHover.hovered) pills.clearHover()
        }
    }

    visible: WorkspaceService.hasWorkspaces
    implicitWidth: visible ? wsRow.implicitWidth : 0
    implicitHeight: 22

    RowLayout {
        id: wsRow
        anchors.centerIn: parent
        spacing: Theme.sp1

        Repeater {
            model: WorkspaceService.workspaceNames

            Rectangle {
                id: wsItem
                required property int index
                required property var modelData

                readonly property int wsNumber: index + 1
                readonly property bool isActive: WorkspaceService.activeWorkspace === wsNumber
                readonly property bool isHovered: pills.hoveredIndex === wsNumber

                Layout.preferredWidth: isActive ? Math.max(32, wsText.implicitWidth + 16) : Math.max(26, wsText.implicitWidth + 14)
                Layout.preferredHeight: 22
                Layout.alignment: Qt.AlignVCenter
                radius: 7
                color: isActive
                    ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.20)
                    : (isHovered ? Theme.stateAccentHover : "transparent")
                border.color: isActive
                    ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.65)
                    : (isHovered ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.3) : "transparent")
                border.width: 1

                Behavior on Layout.preferredWidth { NumberAnimation { duration: 140; easing.type: Easing.OutQuint } }
                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }

                Text {
                    id: wsText
                    anchors.centerIn: parent
                    text: wsItem.modelData
                    color: wsItem.isActive ? Theme.accent : (wsItem.isHovered ? Theme.fg : Theme.comment)
                    font.pixelSize: Theme.fsBody
                    font.family: Theme.fontFamily
                    font.weight: wsItem.isActive ? Font.Bold : Font.Medium

                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                MouseArea {
                    id: wsItemMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: {
                        pills.hoveredIndex = wsItem.wsNumber
                        pills.pillEntered(wsItem.wsNumber)
                    }
                    onExited: if (pills.hoveredIndex === wsItem.wsNumber) pills.clearHover()
                    onClicked: {
                        PopupService.closeAll()
                        WorkspaceService.switchTo(wsItem.wsNumber)
                    }
                }
            }
        }
    }

    // Throttled so a fast wheel does not queue a dozen desktop switches.
    Timer {
        id: scrollThrottleTimer
        interval: 120
        repeat: false
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton

        onWheel: (wheel) => {
            if (scrollThrottleTimer.running) return
            scrollThrottleTimer.restart()
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
