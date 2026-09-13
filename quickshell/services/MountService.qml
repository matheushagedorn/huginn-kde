pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property var devices: []
    property var autoMountMap: ({})

    function scanDevices() {
        if (!actionProc.running) {
            scanProc.running = true
        }
    }

    function toggleMount(devPath, currentMounted) {
        if (currentMounted) {
            actionProc.command = ["udisksctl", "unmount", "-b", devPath]
        } else {
            actionProc.command = ["udisksctl", "mount", "-b", devPath]
        }
        actionProc.running = true
    }

    function mountAndOpen(devPath) {
        openProc.command = ["bash", "-c", "OUT=$(udisksctl mount -b " + devPath + " 2>&1); MP=$(echo \"$OUT\" | grep -o '/run/media/.*'); if [ -n \"$MP\" ]; then xdg-open \"$MP\"; fi"]
        openProc.running = true
    }

    function toggleAutoMount(devPath) {
        var map = Object.assign({}, autoMountMap)
        map[devPath] = !map[devPath]
        autoMountMap = map
    }

    Process {
        id: actionProc
        onExited: scanDevices()
    }

    Process {
        id: openProc
        onExited: scanDevices()
    }

    Process {
        id: scanProc
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/services/python/mount_service.py"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    let parsed = JSON.parse(data.trim())
                    root.devices = parsed

                    // Check Automount per entry
                    for (let i = 0; i < parsed.length; i++) {
                        let item = parsed[i]
                        if (!item.isMounted && root.autoMountMap[item.dev] === true) {
                            actionProc.command = ["udisksctl", "mount", "-b", item.dev]
                            actionProc.running = true
                        }
                    }
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: 4000
        running: true
        repeat: true
        onTriggered: {
            if (!actionProc.running && !openProc.running) {
                scanDevices()
            }
        }
    }
}
