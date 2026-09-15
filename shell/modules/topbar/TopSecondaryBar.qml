import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../components"
import "../../services"
import "../../theme"

// The bar for the monitors that are not the primary one.
//
// Same slab, same places: desktops on the left where the primary bar keeps
// them, the clock in the middle where the primary bar keeps it. A clock in
// the corner read as a different shell on the other screen.
//
// Every control that opens a popup stays on the primary bar, since a popup
// belongs to one screen and duplicating it would open the same menu twice.
Item {
    id: root

    WorkspacePills {
        anchors.left: parent.left
        anchors.leftMargin: Theme.sp3
        anchors.verticalCenter: parent.verticalCenter
    }

    Rectangle {
        id: clockCapsule
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: clockRow.implicitWidth + 18
        implicitHeight: Theme.barCapsule
        radius: 8
        color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.10)
        border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.24)
        border.width: 1

        RowLayout {
            id: clockRow
            anchors.centerIn: parent
            spacing: 6

            Text {
                text: DateTimeService.timeStr
                color: Theme.fg
                font.pixelSize: Theme.fsBody
                font.family: Theme.fontFamily
                font.weight: Font.Bold
            }

            Text {
                text: "•"
                color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.6)
                font.pixelSize: Theme.fsCaption
                font.family: Theme.fontFamily
            }

            Text {
                text: DateTimeService.dateStr
                color: Theme.textMuted
                font.pixelSize: Theme.fsBody
                font.family: Theme.fontFamily
                font.weight: Font.Medium
            }
        }
    }
}
