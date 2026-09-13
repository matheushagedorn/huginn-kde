pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property bool isPowered: true
    property bool hasAdapter: true
    property var connectedDevices: []
    property var availableDevices: []
    property bool isScanning: false

    function scanBluetooth() {
        if (!scanProc.running && !actionProc.running) {
            scanProc.running = true
        }
    }

    function togglePower() {
        let targetPowered = !isPowered
        isPowered = targetPowered
        
        if (!targetPowered) {
            connectedDevices = []
            availableDevices = []
        }

        if (targetPowered) {
            actionProc.command = ["bash", "-c", "rfkill unblock bluetooth 2>/dev/null; bluetoothctl power on 2>/dev/null &"]
        } else {
            actionProc.command = ["bash", "-c", "rfkill block bluetooth 2>/dev/null; bluetoothctl power off 2>/dev/null &"]
        }
        actionProc.running = true
    }

    function connectDevice(mac) {
        if (mac) {
            actionProc.command = ["bash", "-c", "bluetoothctl connect " + mac + " 2>/dev/null &"]
            actionProc.running = true
        }
    }

    function disconnectDevice(mac) {
        if (mac) {
            actionProc.command = ["bash", "-c", "bluetoothctl disconnect " + mac + " 2>/dev/null &"]
            actionProc.running = true
        }
    }

    Process {
        id: actionProc
        onExited: scanTimer.start()
    }

    Timer {
        id: scanTimer
        interval: 1000
        repeat: false
        onTriggered: scanBluetooth()
    }

    Process {
        id: scanProc
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/services/python/bluetooth_service.py"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    let parsed = JSON.parse(data.trim())
                    root.isPowered = parsed.powered
                    root.hasAdapter = parsed.hasAdapter !== undefined ? parsed.hasAdapter : true
                    root.connectedDevices = parsed.connected || []
                    root.availableDevices = parsed.available || []
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: 3500
        running: true
        repeat: true
        onTriggered: scanBluetooth()
    }

    Component.onCompleted: scanBluetooth()
}
