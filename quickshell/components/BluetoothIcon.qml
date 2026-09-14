import QtQuick
import "../theme"

UiIcon {
    property bool isPowered: true
    property bool isConnected: false

    implicitWidth: 16
    implicitHeight: 16

    name: !isPowered ? "bluetooth-off"
        : isConnected ? "bluetooth-connected" : "bluetooth"
}
