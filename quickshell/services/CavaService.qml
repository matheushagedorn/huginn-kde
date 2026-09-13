pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property var values: {
        let arr = [];
        for (let i = 0; i < 28; i++) arr.push(0);
        return arr;
    }

    property bool configReady: false
    property bool isRunning: MediaService.status === "Playing"

    // Prepare cava config file
    Process {
        id: initConfigProc
        command: ["bash", "-c", "mkdir -p /tmp/quickshell-cava && cat << 'EOF' > /tmp/quickshell-cava/cava.conf\n[general]\nbars = 28\nframerate = 60\n\n[output]\nmethod = raw\ndata_format = ascii\nascii_max_range = 100\nbar_delimiter = 59\nEOF"]
        running: true
        onExited: root.configReady = true
    }

    // Real-Time Audio FFT Spectrum Process (Robust PATH & fallback runner)
    Process {
        id: cavaProc
        command: ["bash", "-c", "export PATH=$PATH:$HOME/.nix-profile/bin:/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin; if command -v cava >/dev/null 2>&1; then cava -p /tmp/quickshell-cava/cava.conf; else nix-shell -p cava --run 'cava -p /tmp/quickshell-cava/cava.conf'; fi"]
        running: root.isRunning && root.configReady

        stdout: SplitParser {
            onRead: data => {
                let str = data.trim()
                if (!str) return
                let parts = str.split(";")
                if (parts.length >= 28) {
                    let newVals = []
                    for (let i = 0; i < 28; i++) {
                        let v = parseInt(parts[i], 10)
                        newVals.push(isNaN(v) ? 0 : Math.max(0, Math.min(100, v)))
                    }
                    root.values = newVals
                    root.tick++
                }
            }
        }
    }
}
