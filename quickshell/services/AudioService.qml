pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property int volume: 100
    property bool isMuted: false
    property string volumeStr: isMuted ? "Muted" : volume + "%"

    property var sinks: []
    property var sources: []

    function setVolume(pct) {
        var valid = Math.max(0, Math.min(100, Math.round(pct)))
        volume = valid
        setVolProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", (valid / 100.0).toFixed(2)]
        setVolProc.running = true
    }

    function volumeUp() {
        setVolume(volume + 5)
    }

    function volumeDown() {
        setVolume(volume - 5)
    }

    function toggleMute() {
        isMuted = !isMuted
        muteProc.running = true
    }

    function setDefaultDevice(devId) {
        switchDevProc.command = ["wpctl", "set-default", devId.toString()]
        switchDevProc.running = true
    }

    Process { id: setVolProc }
    Process { id: muteProc; command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"] }
    Process {
        id: switchDevProc
        onExited: {
            volProc.running = true
            devProc.running = true
        }
    }

    Process {
        id: volProc
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                let text = data.trim()
                if (text.indexOf("Volume:") !== -1) {
                    root.isMuted = text.indexOf("[MUTED]") !== -1
                    let parts = text.split(" ")
                    if (parts.length >= 2) {
                        let v = parseFloat(parts[1])
                        if (!isNaN(v)) {
                            root.volume = Math.round(v * 100)
                        }
                    }
                }
            }
        }
    }

    Process {
        id: devProc
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/services/python/audio_service.py"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    let parsed = JSON.parse(data.trim())
                    if (parsed.sinks) root.sinks = parsed.sinks
                    if (parsed.sources) root.sources = parsed.sources
                } catch (e) {}
            }
        }
    }

    // Refresh volume and devices state
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            if (!setVolProc.running && !switchDevProc.running) {
                volProc.running = true
                devProc.running = true
            }
        }
    }
}
