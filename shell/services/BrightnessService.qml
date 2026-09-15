pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Brightness, with the UI decoupled from the hardware write.
//
// Two things used to make this feel slow. The reported value only moved when a
// rescan came back, seconds later; and each hardware write went through
// `ddcutil setvcp`, which costs ~300ms on this machine. Only 4ms of that is
// process startup, the rest is ddcutil's conservative DDC/CI pacing, so a
// direct I2C write does the same job in ~40ms (measured).
//
// The value shown now changes on the same frame as the input, and the panel
// follows about a frame and a half later.
Item {
    id: root

    property var devices: []
    property int masterBrightness: 100
    property string brightnessStr: masterBrightness + "%"
    property bool isUserInteracting: false

    // DDC/CI wants 50ms between commands. Going under it makes monitors drop
    // writes, which reads as the brightness snapping back mid-drag.
    readonly property int minWriteInterval: 50
    property double lastWriteAt: 0

    function scanDevices() {
        if (!setDevProc.running && !applyTimer.running) {
            scanProc.running = true
        }
    }

    function setDeviceBrightness(devId, pct) {
        var valid = Math.max(0, Math.min(100, Math.round(pct)))

        isUserInteracting = true
        userTimer.restart()

        // Mutated in place rather than reassigned: reassigning `devices`
        // rebuilds the Repeater delegates and destroys the MouseArea being
        // dragged out from under the pointer.
        var isFirst = false
        for (var i = 0; i < devices.length; i++) {
            if (devices[i].id === devId) {
                devices[i].brightness = valid
                isFirst = (i === 0)
                break
            }
        }

        // The optimistic half. `masterBrightness` is what the panel icon and
        // the OSD read, and nothing wrote it outside the rescan, so the
        // keyboard keys moved the hardware while the OSD never appeared.
        if (isFirst) masterBrightness = valid

        // Keyed by device: with two monitors, brightnessUp() queues both, and
        // a single pending slot meant the second one overwrote the first.
        pending[devId] = valid
        pendingChanged()

        // Leading edge: a single keypress or click goes straight through, with
        // no debounce sitting in front of it. Only a drag gets paced, and its
        // last value is still delivered by the trailing timer.
        var since = Date.now() - lastWriteAt
        if (!setDevProc.running && since >= minWriteInterval) {
            flush()
        } else {
            applyTimer.interval = Math.max(8, minWriteInterval - since)
            applyTimer.restart()
        }
    }

    property var pending: ({})

    function hasPending() {
        for (var k in pending) return true
        return false
    }

    function flush() {
        var devId = ""
        for (var k in pending) { devId = k; break }
        if (devId === "") return

        var value = pending[devId]
        delete pending[devId]
        pendingChanged()

        var dev = root.devices.find(d => d.id === devId)
        if (!dev) return

        var cmd = ""
        if (dev.type === "ddc") {
            // Direct I2C, with ddcutil as the fallback inside the script.
            var bus = dev.bus ? dev.bus : ""
            if (bus !== "") {
                cmd = "python3 " + Quickshell.env("HOME")
                    + "/.config/huginn/services/python/set_brightness.py "
                    + bus + " " + value
            } else {
                cmd = "ddcutil setvcp 10 " + value
                    + " --display " + dev.display_num + " --noverify"
            }
        } else if (dev.type === "sys" || dev.type === "kbd") {
            cmd = "brightnessctl --device=" + dev.dev_name + " set " + value + "%"
        }

        if (cmd === "") return

        lastWriteAt = Date.now()
        setDevProc.command = ["bash", "-c", cmd + " 2>/dev/null"]
        setDevProc.running = true
    }

    // Delivers whatever the drag ended on, and keeps writes spaced.
    Timer {
        id: applyTimer
        interval: 50
        repeat: false
        onTriggered: {
            if (setDevProc.running) {
                // Still writing. Re-arm rather than overwrite the command of a
                // running process, which used to drop the value outright.
                applyTimer.interval = 16
                applyTimer.restart()
                return
            }
            root.flush()
        }
    }

    Process {
        id: setDevProc
        // A value that arrived while this write was in flight is applied as
        // soon as it finishes, so the last position of a drag always lands.
        onExited: if (root.hasPending()) root.flush()
    }

    // How long an external rescan stays blocked after the last input. Short,
    // now that the UI no longer depends on the rescan to update.
    Timer {
        id: userTimer
        interval: 2000
        repeat: false
        onTriggered: root.isUserInteracting = false
    }

    Process {
        id: scanProc
        command: ["python3", Quickshell.env("HOME") + "/.config/huginn/services/python/brightness_service.py"]
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

    function brightnessUp() {
        for (var i = 0; i < devices.length; i++) {
            setDeviceBrightness(devices[i].id, devices[i].brightness + 5)
        }
    }

    function brightnessDown() {
        for (var i = 0; i < devices.length; i++) {
            setDeviceBrightness(devices[i].id, devices[i].brightness - 5)
        }
    }
}
