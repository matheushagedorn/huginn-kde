import QtQuick
import "../theme"

Image {
    id: icon
    property bool isConnected: true
    property int signalPercent: 100
    property bool isEthernet: false
    property bool isWifiPowered: true

    width: 16
    height: 16
    sourceSize.width: Math.round(width)
    sourceSize.height: Math.round(height)
    fillMode: Image.PreserveAspectFit

    source: {
        let base = "file://" + Theme.iconsDir + "/" + Theme.panelIconDir + "/24x24/panel/"
        if (isEthernet) {
            return isConnected ? base + "network-wired-activated.svg" : base + "network-wired-disconnected.svg"
        } else if (!isWifiPowered || !isConnected) {
            return base + "network-wireless-off.svg"
        } else if (signalPercent > 75) {
            return base + "network-wireless-100.svg"
        } else if (signalPercent > 50) {
            return base + "network-wireless-60.svg"
        } else if (signalPercent > 25) {
            return base + "network-wireless-40.svg"
        } else {
            return base + "network-wireless-20.svg"
        }
    }
}
