pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property var devices: []
    property int masterBrightness: 100
    property string brightnessStr: masterBrightness + "%"
    property bool isUserInteracting: false

    function scanDevices() {
        if (!setDevProc.running && !applyTimer.running) {
            scanProc.running = true
        }
    }

    function setDeviceBrightness(devId, pct) {
        var valid = Math.max(0, Math.min(100, Math.round(pct)))
        isUserInteracting = true
        userTimer.restart()

        // Mutate in-place to prevent QML Repeater delegate destruction mid-drag
        for (var i = 0; i < devices.length; i++) {
            if (devices[i].id === devId) {
                devices[i].brightness = valid
                break
            }
        }

        // Debounce hardware execution per device
        applyTimer.targetDevId = devId
        applyTimer.targetPct = valid
        applyTimer.restart()
    }

    function brightnessUp() {
        for (var i = 0; i < devices.length; i++) {
            var item = devices[i]
            setDeviceBrightness(item.id, item.brightness + 5)
        }
    }

    function brightnessDown() {
        for (var i = 0; i < devices.length; i++) {
            var item = devices[i]
            setDeviceBrightness(item.id, item.brightness - 5)
        }
    }

    Timer {
        id: applyTimer
        interval: 100
        repeat: false
        property string targetDevId: ""
        property int targetPct: 100

        onTriggered: {
            var dev = root.devices.find(d => d.id === targetDevId)
            if (!dev) return

            var cmd = ""
            if (dev.type === "ddc") {
                cmd = "ddcutil setvcp 10 " + targetPct + " --display " + dev.display_num + " 2>/dev/null"
            } else if (dev.type === "sys" || dev.type === "kbd") {
                cmd = "brightnessctl --device=" + dev.dev_name + " set " + targetPct + "% 2>/dev/null"
            }

            if (cmd !== "") {
                setDevProc.command = ["bash", "-c", cmd]
                setDevProc.running = true
            }
        }
    }

    Timer {
        id: userTimer
        interval: 4000
        repeat: false
        onTriggered: root.isUserInteracting = false
    }

    Process { id: setDevProc }

    Process {
        id: scanProc
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/services/python/brightness_service.py"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                if (!root.isUserInteracting) {
                    try {
                        let parsed = JSON.parse(data.trim())
                        if (parsed && parsed.length > 0) {
                            root.devices = parsed
                            root.masterBrightness = parsed[0].brightness
                        }
                    } catch (e) {}
                }
            }
        }
    }
}
