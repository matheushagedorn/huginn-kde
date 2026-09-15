import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../services"
import "../../components"

// Desktop system monitor: four cards on one 2x2 grid.
//
// Each card says the same things in the same order, because they all come
// from MonitorCard: what is being watched, the one reading that names its
// state, the device behind it, a usage bar, the detail rows, and the history
// graph on the bottom edge. Anything a card wants to add goes in `content`.
PanelWindow {
    id: widgetWindow

    anchors {
        top: true
        left: true
    }
    // Lined up with the bar, not with the screen: the bar floats 10px in from
    // the left, so cards indented by 20 left a step between the two edges.
    // The top is the bar's own bottom edge (10 + barHeight) plus a gap of its
    // own, which the old 55 did not leave: the cards were touching it.
    margins {
        top: 10 + Theme.barHeight + Theme.sp4
        left: 10
    }

    screen: Quickshell.screens.find(s => s.name === "DP-2") || Quickshell.screens[0]

    WlrLayershell.layer: WlrLayershell.Bottom
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    mask: Region {}

    implicitWidth: mainCol.implicitWidth
    implicitHeight: mainCol.implicitHeight

    ColumnLayout {
        id: mainCol
        spacing: Theme.sp3
        implicitWidth: 640

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.sp3

            MonitorCard {
                title: "CPU"
                headline: SystemMonitorService.cpuPct + "%"
                subtitle: SystemMonitorService.cpuName
                gaugeValue: SystemMonitorService.cpuPct
                gaugeColor: Theme.loadColor(SystemMonitorService.cpuPct)
                history: SystemMonitorService.cpuHistory

                content: [
                    MetricRow {
                        label: "Temp"
                        value: SystemMonitorService.cpuTemp + "°C"
                        valueColor: Theme.tempColor(SystemMonitorService.cpuTemp)
                        trailingLabel: "Fan"
                        trailingValue: SystemMonitorService.cpuFan > 0
                            ? SystemMonitorService.cpuFan + " RPM"
                            : "Auto"
                    },
                    MetricRow {
                        label: "Clock"
                        value: SystemMonitorService.cpuFreq
                        trailingLabel: "Cores"
                        trailingValue: String(SystemMonitorService.cpuCores)
                    }
                ]
            }

            MonitorCard {
                title: "GPU"
                headline: SystemMonitorService.gpuPct + "%"
                subtitle: SystemMonitorService.gpuName
                gaugeValue: SystemMonitorService.gpuPct
                gaugeColor: Theme.loadColor(SystemMonitorService.gpuPct)
                history: SystemMonitorService.gpuHistory

                content: [
                    MetricRow {
                        label: "Temp"
                        value: SystemMonitorService.gpuTemp + "°C"
                        valueColor: Theme.tempColor(SystemMonitorService.gpuTemp)
                        trailingLabel: "Power"
                        trailingValue: SystemMonitorService.gpuPower
                    },
                    MetricRow {
                        label: "VRAM"
                        value: SystemMonitorService.gpuVramUsed + " / " + SystemMonitorService.gpuVramTotal + " MB"
                    }
                ]
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.sp3

            MonitorCard {
                title: "Memory"
                headline: SystemMonitorService.ramPct + "%"
                subtitle: SystemMonitorService.ramTotal + " GB installed"
                gaugeValue: SystemMonitorService.ramPct
                gaugeColor: Theme.loadColor(SystemMonitorService.ramPct)
                history: SystemMonitorService.ramHistory

                content: [
                    MetricRow {
                        label: "Used"
                        value: SystemMonitorService.ramUsed + " / " + SystemMonitorService.ramTotal + " GB"
                    },
                    // Swap reads as a second memory with its own bar, and the
                    // row under it says what the bar just showed.
                    GaugeBar {
                        value: SystemMonitorService.swapPct
                        fillColor: Theme.loadColor(SystemMonitorService.swapPct, 20, 60)
                        Layout.preferredHeight: Theme.cardSlot
                    },
                    MetricRow {
                        label: "Swap"
                        value: SystemMonitorService.swapUsed + " / " + SystemMonitorService.swapTotal + " GB"
                    }
                ]
            }

            MonitorCard {
                title: "Storage and network"
                headline: SystemMonitorService.diskPct + "%"
                subtitle: SystemMonitorService.diskName
                gaugeValue: SystemMonitorService.diskPct
                // A disk is not busy at 60% full the way a CPU is busy at 60%
                // load, so this reading warns later than the others.
                gaugeColor: Theme.loadColor(SystemMonitorService.diskPct, 80, 92)
                history: SystemMonitorService.netHistory
                // Throughput has no ceiling to draw against.
                graphAutoScale: true

                content: [
                    MetricRow {
                        label: "Temp"
                        value: SystemMonitorService.nvmeTemp + "°C"
                        valueColor: Theme.tempColor(SystemMonitorService.nvmeTemp, 60, 70)
                        trailingLabel: "Used"
                        trailingValue: SystemMonitorService.diskUsed + " / " + SystemMonitorService.diskTotal + " GB"
                    },
                    MetricRow {
                        label: SystemMonitorService.hasWifi ? "Wi-Fi" : "Ethernet"
                        value: SystemMonitorService.hasWifi
                            ? SystemMonitorService.wifiSignal
                            : (NetworkService.ethernetConnected ? "Connected" : "Disconnected")
                    },
                    MetricRow {
                        label: "Down"
                        value: SystemMonitorService.netRx
                        trailingLabel: "Up"
                        trailingValue: SystemMonitorService.netTx
                    }
                ]
            }
        }
    }
}
