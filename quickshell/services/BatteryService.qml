pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property int percentage: 100
    property bool isCharging: false
    property string statusStr: percentage + "%"
    property int healthPercent: 100
    property string activeProfile: "balanced"
    property bool isSleepBlocked: false

    function setProfile(profileName) {
        activeProfile = profileName
        profileProc.command = ["powerprofilesctl", "set", profileName]
        profileProc.running = true
    }

    function toggleSleepBlock() {
        isSleepBlocked = !isSleepBlocked
        if (isSleepBlocked) {
            inhibitProc.running = true
        } else {
            inhibitProc.running = false
        }
    }

    Process { id: profileProc }

    Process {
        id: inhibitProc
        command: ["systemd-inhibit", "--what=idle:sleep", "--who=quickshell", "--why=Prevent sleep", "sleep", "infinity"]
    }

    Process {
        id: batProc
        command: ["bash", "-c", "CAP=$(cat /sys/class/power_supply/BAT1/capacity 2>/dev/null); STAT=$(cat /sys/class/power_supply/BAT1/status 2>/dev/null); FULL=$(cat /sys/class/power_supply/BAT1/charge_full 2>/dev/null); DESIGN=$(cat /sys/class/power_supply/BAT1/charge_full_design 2>/dev/null); PROF=$(powerprofilesctl get 2>/dev/null); echo \"$CAP|||$STAT|||$FULL|||$DESIGN|||$PROF\""]
        running: true
        stdout: SplitParser {
            onRead: data => {
                let parts = data.trim().split("|||")
                if (parts.length >= 2) {
                    let cap = parseInt(parts[0])
                    if (!isNaN(cap)) {
                        root.percentage = cap
                    }
                    root.isCharging = parts[1] === "Charging"

                    if (parts.length >= 4) {
                        let full = parseFloat(parts[2])
                        let design = parseFloat(parts[3])
                        if (!isNaN(full) && !isNaN(design) && design > 0) {
                            root.healthPercent = Math.min(100, Math.round((full / design) * 100))
                        }
                    }

                    if (parts.length >= 5 && parts[4] && parts[4] !== "") {
                        root.activeProfile = parts[4].trim()
                    }
                }
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: {
            if (!profileProc.running) {
                batProc.running = true
            }
        }
    }
}
