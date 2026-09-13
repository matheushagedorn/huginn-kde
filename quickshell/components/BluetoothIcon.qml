import QtQuick
import "../theme"

Image {
    id: root

    property bool isPowered: true
    property bool isConnected: false

    width: 16
    height: 16
    sourceSize.width: Math.round(width)
    sourceSize.height: Math.round(height)
    fillMode: Image.PreserveAspectFit

    source: {
        let base = "file://" + Theme.iconsDir + "/" + Theme.panelIconDir + "/24x24/panel/"
        return isConnected ? base + "bluetooth-paired.svg" : (isPowered ? base + "bluetooth-active.svg" : base + "bluetooth-disabled.svg")
    }
}
