import QtQuick
import "../theme"

// Ethernet and Wi-Fi share one slot; the glyph says which link is in use and,
// for Wi-Fi, how strong it is.
UiIcon {
    property bool isConnected: true
    property int signalPercent: 100
    property bool isEthernet: false
    property bool isWifiPowered: true

    implicitWidth: 16
    implicitHeight: 16

    name: isEthernet ? (isConnected ? "ethernet-port" : "cable")
        : (!isWifiPowered || !isConnected) ? "wifi-off"
        : signalPercent > 66 ? "wifi"
        : signalPercent > 33 ? "signal-medium" : "signal-low"
}
