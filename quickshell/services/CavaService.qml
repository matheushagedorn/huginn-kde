pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Real-time audio spectrum, read from cava's raw ASCII output.
//
// The meter under the media card is functional, not decoration — it follows
// actual output amplitude. It only exists when cava does: `available` gates
// the whole widget, so a machine without cava gets no dead flat line
// promising a visualisation that can never move.
Item {
    id: root

    readonly property int bars: 28

    property var values: {
        let arr = []
        for (let i = 0; i < bars; i++) arr.push(0)
        return arr
    }

    // Declared so the widget can depend on it. It used to be incremented
    // without being declared, which threw a TypeError on every frame cava
    // produced — 60 errors a second into the journal.
    property int tick: 0

    property bool available: false
    property bool configReady: false
    property bool isRunning: available && MediaService.status === "Playing"

    // One-shot probe. The upstream fallback shelled out to `nix-shell -p cava`,
    // which does not exist on this system, so a missing cava turned into a
    // process that failed and respawned forever.
    Process {
        id: probeProc
        command: ["bash", "-c", "command -v cava >/dev/null 2>&1"]
        running: true
        onExited: code => root.available = (code === 0)
    }

    // 30 fps is past the point where the bars read as continuous, and halves
    // the scene-graph work of 28 animated rectangles versus the previous 60.
    Process {
        id: initConfigProc
        // mono: cava's default splits the bars into a mirrored stereo pair, so
        // only half the width carried spectrum and the meter read as symmetric
        // noise. One channel gives all 28 bars to the full frequency range.
        command: ["bash", "-c", "mkdir -p /tmp/huginn-cava && cat << 'CONF' > /tmp/huginn-cava/cava.conf\n[general]\nbars = 28\nframerate = 30\nautosens = 1\n\n[output]\nmethod = raw\ndata_format = ascii\nascii_max_range = 100\nbar_delimiter = 59\nchannels = mono\nmono_option = average\n\n[smoothing]\nnoise_reduction = 35\nCONF"]
        running: true
        onExited: root.configReady = true
    }

    Process {
        id: cavaProc
        command: ["cava", "-p", "/tmp/huginn-cava/cava.conf"]
        running: root.isRunning && root.configReady

        stdout: SplitParser {
            onRead: data => {
                let str = data.trim()
                if (!str) return
                let parts = str.split(";")
                if (parts.length >= root.bars) {
                    let newVals = []
                    for (let i = 0; i < root.bars; i++) {
                        let v = parseInt(parts[i], 10)
                        newVals.push(isNaN(v) ? 0 : Math.max(0, Math.min(100, v)))
                    }
                    root.values = newVals
                    root.tick++
                }
            }
        }
    }

    // Drop the bars to silence when playback stops, instead of freezing them
    // on the last frame cava produced.
    onIsRunningChanged: {
        if (!isRunning) {
            let arr = []
            for (let i = 0; i < bars; i++) arr.push(0)
            values = arr
            tick++
        }
    }
}
