pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property bool isConnected: false
    property string connectedSsid: ""
    property int signalPercent: 0
    property bool isWifiPowered: true
    property bool hasEthernet: false
    property bool ethernetConnected: false
    property var networks: []

    function scanWifi() {
        if (!scanProc.running && !actionProc.running) {
            scanProc.running = true
        }
    }

    function toggleWifiPower() {
        let targetPowered = !isWifiPowered
        isWifiPowered = targetPowered
        if (!targetPowered) {
            networks = []
            if (!ethernetConnected) isConnected = false
        }

        if (targetPowered) {
            actionProc.command = ["bash", "-c", "nmcli radio wifi on 2>/dev/null &"]
        } else {
            actionProc.command = ["bash", "-c", "nmcli radio wifi off 2>/dev/null &"]
        }
        actionProc.running = true
    }

    function connectNetwork(targetSsid, password) {
        if (!targetSsid) return;
        if (password && password !== "") {
            actionProc.command = ["bash", "-c", "nmcli dev wifi connect '" + targetSsid + "' password '" + password + "' 2>/dev/null &"]
        } else {
            actionProc.command = ["bash", "-c", "nmcli dev wifi connect '" + targetSsid + "' 2>/dev/null &"]
        }
        actionProc.running = true
    }

    Process {
        id: actionProc
        onExited: scanTimer.start()
    }

    Timer {
        id: scanTimer
        interval: 400
        repeat: false
        onTriggered: scanWifi()
    }

    Process {
        id: scanProc
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/services/python/network_service.py"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    let parsed = JSON.parse(data.trim())
                    root.isWifiPowered = parsed.wifiPowered
                    root.hasEthernet = parsed.hasEthernet
                    root.ethernetConnected = parsed.ethernetConnected
                    root.isConnected = parsed.isConnected || parsed.ethernetConnected
                    root.connectedSsid = parsed.connectedSsid || ""
                    if (parsed.signalPercent > 0) {
                        root.signalPercent = parsed.signalPercent
                    }
                    if (parsed.networks && parsed.networks.length > 0) {
                        root.networks = parsed.networks
                    }
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: scanWifi()
    }

    Component.onCompleted: scanWifi()
}
