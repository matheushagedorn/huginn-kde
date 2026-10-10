import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../services"
import "../../components"

// Desktop system monitor: one quiet column in the top-left corner.
//
// It used to be four framed cards on a 2x2 grid, each with a heading, a
// device name, a bar, two to four rows and a graph. That is a lot of chrome
// for something glanced at, and against the wallpaper it read as a stack of
// windows. What is left at rest is one line per reading: label, number,
// trace. No frames, muted text, and colour only when a threshold is crossed,
// so a calm machine is nearly invisible and a hot one is not.
//
// Nothing was dropped. Resting the pointer on a reading unfolds it in place
// with everything its card used to carry (see AmbientMetric), and the
// Dashboard under the clock still has the four headline bars.
//
// Only hardware the machine has is shown: no GPU line without a GPU that
// answered, no fan without a fan sensor, no Wi-Fi without a wireless
// interface, no drive temperature without a sensor reporting it.
PanelWindow {
    id: widgetWindow

    anchors {
        top: true
        left: true
    }
    // Under the bar and flush with its left edge. The text itself sits a
    // small step further in (AmbientMetric's own padding), which is where the
    // hover backdrop needs its margin and where the bar's first capsule
    // keeps its content, so the two columns read as one.
    // The gap below the bar is wider than a popup's: this is not attached
    // to the bar, and should not look like it hangs from it.
    margins {
        top: 10 + Theme.barHeight + Theme.sp5
        left: 10
    }

    screen: Quickshell.screens.find(s => s.name === "DP-2") || Quickshell.screens[0]

    WlrLayershell.layer: WlrLayershell.Bottom
    WlrLayershell.namespace: "desktop"
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    // Input only where the readings are, so the rest of the window, which is
    // sized for the tallest reading opened, never swallows a desktop click.
    mask: Region { item: strip }

    // The window does not follow the unfolding reading: resizing a layer
    // surface on every animation frame is what makes it stutter. It is sized
    // once for every reading at rest plus the tallest one open.
    readonly property var metrics: [cpu, gpu, ram, net, disk].filter(m => m.visible)
    implicitWidth: 240
    implicitHeight: {
        let rest = 0
        let open = 0
        for (let m of metrics) {
            rest += m.restHeight
            open = Math.max(open, m.detailHeight)
        }
        return rest + open + Math.max(0, metrics.length - 1) * strip.spacing
    }

    // Warning and critical lines for each reading. Load uses the scale of
    // Theme.loadColor and temperature the one of Theme.tempColor; memory
    // warns later, because a desktop sitting at 60% RAM is just a desktop
    // with a browser open, and a disk later still, because full is not busy.
    function levelOf(v, warn, crit) {
        return v >= crit ? 2 : v >= warn ? 1 : 0
    }

    readonly property int cpuTempLevel: levelOf(SystemMonitorService.cpuTemp, 75, 85)
    readonly property int gpuTempLevel: levelOf(SystemMonitorService.gpuTemp, 75, 85)
    readonly property int nvmeTempLevel: levelOf(SystemMonitorService.nvmeTemp, 60, 70)
    readonly property int swapLevel: levelOf(SystemMonitorService.swapPct, 20, 60)

    // A temperature that is the reason for the colour gets named next to the
    // number; otherwise the number would turn red with nothing on screen to
    // say why.
    function tempFlag(level, deg) {
        return level > 0 ? Math.round(deg) + "°" : ""
    }

    ColumnLayout {
        id: strip
        width: widgetWindow.implicitWidth
        spacing: 0

        AmbientMetric {
            id: cpu
            Layout.fillWidth: true
            label: "CPU"
            value: SystemMonitorService.cpuPct + "%"
            flag: widgetWindow.tempFlag(widgetWindow.cpuTempLevel, SystemMonitorService.cpuTemp)
            level: Math.max(widgetWindow.levelOf(SystemMonitorService.cpuPct, 60, 85), widgetWindow.cpuTempLevel)
            history: SystemMonitorService.cpuHistory
            subtitle: SystemMonitorService.cpuName
            details: {
                let rows = [
                    { label: "Temperature", value: SystemMonitorService.cpuTemp + "°C", level: widgetWindow.cpuTempLevel },
                    { label: "Clock", value: SystemMonitorService.cpuFreq },
                    { label: "Cores", value: String(SystemMonitorService.cpuCores) }
                ]
                if (SystemMonitorService.cpuFan > 0)
                    rows.push({ label: "Fan", value: SystemMonitorService.cpuFan + " RPM" })
                return rows
            }
        }

        AmbientMetric {
            id: gpu
            Layout.fillWidth: true
            visible: SystemMonitorService.hasGpu
            label: "GPU"
            value: SystemMonitorService.gpuPct + "%"
            flag: widgetWindow.tempFlag(widgetWindow.gpuTempLevel, SystemMonitorService.gpuTemp)
            level: Math.max(widgetWindow.levelOf(SystemMonitorService.gpuPct, 60, 85), widgetWindow.gpuTempLevel)
            history: SystemMonitorService.gpuHistory
            subtitle: SystemMonitorService.gpuName
            details: {
                let rows = [
                    { label: "Temperature", value: SystemMonitorService.gpuTemp + "°C", level: widgetWindow.gpuTempLevel },
                    { label: "Power", value: SystemMonitorService.gpuPower },
                    { label: "VRAM", value: SystemMonitorService.gpuVramUsed + " / " + SystemMonitorService.gpuVramTotal + " MB" }
                ]
                if (SystemMonitorService.gpuFan > 0)
                    rows.push({ label: "Fan", value: SystemMonitorService.gpuFan + " RPM" })
                return rows
            }
        }

        AmbientMetric {
            id: ram
            Layout.fillWidth: true
            label: "RAM"
            value: SystemMonitorService.ramPct + "%"
            level: widgetWindow.levelOf(SystemMonitorService.ramPct, 75, 90)
            history: SystemMonitorService.ramHistory
            subtitle: SystemMonitorService.ramTotal + " GB installed"
            details: {
                let rows = [
                    { label: "Used", value: SystemMonitorService.ramUsed + " / " + SystemMonitorService.ramTotal + " GB" }
                ]
                if (SystemMonitorService.swapTotal > 0)
                    rows.push({ label: "Swap", value: SystemMonitorService.swapUsed + " / " + SystemMonitorService.swapTotal + " GB", level: widgetWindow.swapLevel })
                return rows
            }
        }

        AmbientMetric {
            id: net
            Layout.fillWidth: true
            label: "NET"
            // Download is the direction a desktop mostly waits on; upload is
            // one line down when the reading is open.
            value: SystemMonitorService.netRx
            history: SystemMonitorService.netHistory
            // Throughput has no ceiling to draw against.
            autoScale: true
            details: {
                let rows = [
                    { label: "Down", value: SystemMonitorService.netRx },
                    { label: "Up", value: SystemMonitorService.netTx }
                ]
                if (SystemMonitorService.hasWifi)
                    rows.push({ label: "Wi-Fi signal", value: SystemMonitorService.wifiSignal })
                if (NetworkService.hasEthernet)
                    rows.push({ label: "Ethernet", value: NetworkService.ethernetConnected ? "Connected" : "Disconnected" })
                return rows
            }
        }

        AmbientMetric {
            id: disk
            Layout.fillWidth: true
            label: "DISK"
            value: SystemMonitorService.diskPct + "%"
            flag: widgetWindow.tempFlag(widgetWindow.nvmeTempLevel, SystemMonitorService.nvmeTemp)
            level: Math.max(widgetWindow.levelOf(SystemMonitorService.diskPct, 80, 92), widgetWindow.nvmeTempLevel)
            // How full a disk is barely moves in a minute, so a history of it
            // would be a flat line; the slot shows the fill instead.
            fill: SystemMonitorService.diskPct
            subtitle: SystemMonitorService.diskName
            details: {
                let rows = [
                    { label: "Used", value: SystemMonitorService.diskUsed + " / " + SystemMonitorService.diskTotal + " GB" }
                ]
                if (SystemMonitorService.nvmeTemp > 0)
                    rows.push({ label: "Temperature", value: SystemMonitorService.nvmeTemp + "°C", level: widgetWindow.nvmeTempLevel })
                return rows
            }
        }
    }
}
