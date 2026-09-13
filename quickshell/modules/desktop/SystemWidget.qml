import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../services"
import "../../components"

PanelWindow {
    id: widgetWindow

    anchors {
        top: true
        left: true
    }
    margins {
        top: 55
        left: 20
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
        spacing: 12
        implicitWidth: 640

        // TOP ROW: 2 Wide Plasmoid Blocks (CPU & GPU)
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            // Top Card 1: CPU Plasmoid Block
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredWidth: 314
                implicitHeight: 175
                radius: 14
                color: Theme.surface
                border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25)
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 5

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "CPU"
                            color: Theme.accent
                            font.pixelSize: 13
                            font.weight: Font.Bold
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: SystemMonitorService.cpuPct + "%"
                            color: Theme.accent
                            font.pixelSize: 16
                            font.weight: Font.Bold
                        }
                    }

                    Text {
                        text: SystemMonitorService.cpuName
                        color: Theme.comment
                        font.pixelSize: 10
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    // CPU Usage Gauge Bar
                    Rectangle {
                        Layout.fillWidth: true
                        height: 6
                        radius: 3
                        color: Theme.bg
                        clip: true

                        Rectangle {
                            height: parent.height
                            width: Math.min(parent.width, Math.max(0, parent.width * (SystemMonitorService.cpuPct / 100.0)))
                            radius: 3
                            color: SystemMonitorService.cpuPct > 80 ? Theme.red : (SystemMonitorService.cpuPct > 50 ? Theme.orange : Theme.accent)
                            Behavior on width { NumberAnimation { duration: 300 } }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        RowLayout {
                            spacing: 4
                            Text { text: "Temp:"; color: Theme.comment; font.pixelSize: 12 }
                            Text { text: SystemMonitorService.cpuTemp + "°C"; color: SystemMonitorService.cpuTemp > 80 ? Theme.red : Theme.fg; font.pixelSize: 12 }
                        }
                        Item { Layout.fillWidth: true }
                        RowLayout {
                            spacing: 4
                            Text { text: "Fan:"; color: Theme.comment; font.pixelSize: 12 }
                            Text { text: (SystemMonitorService.cpuFan > 0 ? SystemMonitorService.cpuFan + " RPM" : "Auto"); color: Theme.fg; font.pixelSize: 12 }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        RowLayout {
                            spacing: 4
                            Text { text: "Clock:"; color: Theme.comment; font.pixelSize: 12 }
                            Text { text: SystemMonitorService.cpuFreq; color: Theme.fg; font.pixelSize: 12 }
                        }
                        Item { Layout.fillWidth: true }
                        Text { text: SystemMonitorService.cpuCores + " Cores"; color: Theme.comment; font.pixelSize: 12 }
                    }

                    Item { Layout.fillHeight: true }

                    // Smooth Sparkline Graph for CPU History
                    SparklineGraph {
                        Layout.fillWidth: true
                        historyData: SystemMonitorService.cpuHistory
                        barColor: Theme.accent
                    }
                }
            }

            // Top Card 2: GPU Plasmoid Block
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredWidth: 314
                implicitHeight: 175
                radius: 14
                color: Theme.surface
                border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25)
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 5

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "GPU"
                            color: Theme.accent
                            font.pixelSize: 13
                            font.weight: Font.Bold
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: SystemMonitorService.gpuPct + "%"
                            color: Theme.accent
                            font.pixelSize: 16
                            font.weight: Font.Bold
                        }
                    }

                    Text {
                        text: SystemMonitorService.gpuName
                        color: Theme.comment
                        font.pixelSize: 10
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    // GPU Usage Gauge Bar
                    Rectangle {
                        Layout.fillWidth: true
                        height: 6
                        radius: 3
                        color: Theme.bg
                        clip: true

                        Rectangle {
                            height: parent.height
                            width: Math.min(parent.width, Math.max(0, parent.width * (SystemMonitorService.gpuPct / 100.0)))
                            radius: 3
                            color: Theme.accent
                            Behavior on width { NumberAnimation { duration: 300 } }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        RowLayout {
                            spacing: 4
                            Text { text: "Temp:"; color: Theme.comment; font.pixelSize: 12 }
                            Text { text: SystemMonitorService.gpuTemp + "°C"; color: SystemMonitorService.gpuTemp > 75 ? Theme.orange : Theme.fg; font.pixelSize: 12 }
                        }
                        Item { Layout.fillWidth: true }
                        RowLayout {
                            spacing: 4
                            Text { text: "Pwr:"; color: Theme.comment; font.pixelSize: 12 }
                            Text { text: SystemMonitorService.gpuPower; color: Theme.fg; font.pixelSize: 12 }
                        }
                    }

                    RowLayout {
                        spacing: 4
                        Text { text: "VRAM:"; color: Theme.comment; font.pixelSize: 12 }
                        Text { text: SystemMonitorService.gpuVramUsed + " / " + SystemMonitorService.gpuVramTotal + " MB"; color: Theme.fg; font.pixelSize: 12 }
                    }

                    Item { Layout.fillHeight: true }

                    // Smooth Sparkline Graph for GPU History
                    SparklineGraph {
                        Layout.fillWidth: true
                        historyData: SystemMonitorService.gpuHistory
                        barColor: Theme.accent
                    }
                }
            }
        }

        // BOTTOM ROW: 2 Wide Plasmoid Blocks (RAM & Sensors/Network)
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            // Bottom Card 1: RAM & Memory Plasmoid Block
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredWidth: 314
                implicitHeight: 175
                radius: 14
                color: Theme.surface
                border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25)
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 5

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "MEMORY"
                            color: Theme.accent
                            font.pixelSize: 13
                            font.weight: Font.Bold
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: SystemMonitorService.ramPct + "%"
                            color: Theme.accent
                            font.pixelSize: 16
                            font.weight: Font.Bold
                        }
                    }

                    // RAM Usage Gauge Bar
                    Rectangle {
                        Layout.fillWidth: true
                        height: 6
                        radius: 3
                        color: Theme.bg
                        clip: true

                        Rectangle {
                            height: parent.height
                            width: Math.min(parent.width, Math.max(0, parent.width * (SystemMonitorService.ramPct / 100.0)))
                            radius: 3
                            color: Theme.accent
                            Behavior on width { NumberAnimation { duration: 300 } }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        RowLayout {
                            spacing: 4
                            Text { text: "Used:"; color: Theme.comment; font.pixelSize: 12 }
                            Text { text: SystemMonitorService.ramUsed + " / " + SystemMonitorService.ramTotal + " GB"; color: Theme.fg; font.pixelSize: 12 }
                        }
                        Item { Layout.fillWidth: true }
                        RowLayout {
                            spacing: 4
                            Text { text: "Swap:"; color: Theme.comment; font.pixelSize: 12 }
                            Text { text: SystemMonitorService.swapUsed + " / " + SystemMonitorService.swapTotal + " GB"; color: Theme.fg; font.pixelSize: 12 }
                        }
                    }

                    // Swap Usage Gauge Bar
                    Rectangle {
                        Layout.fillWidth: true
                        height: 6
                        radius: 3
                        color: Theme.bg
                        clip: true

                        Rectangle {
                            height: parent.height
                            width: Math.min(parent.width, Math.max(0, parent.width * (SystemMonitorService.swapPct / 100.0)))
                            radius: 3
                            color: Theme.orange
                            Behavior on width { NumberAnimation { duration: 300 } }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    // Smooth Sparkline Graph for RAM History
                    SparklineGraph {
                        Layout.fillWidth: true
                        historyData: SystemMonitorService.ramHistory
                        barColor: Theme.accent
                    }
                }
            }

            // Bottom Card 2: Sensors, Network & Processes Plasmoid Block
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredWidth: 314
                implicitHeight: 175
                radius: 14
                color: Theme.surface
                border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25)
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 6

                    Text {
                        text: "SYSTEM & NETWORK"
                        color: Theme.accent
                        font.pixelSize: 13
                        font.weight: Font.Bold
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        RowLayout {
                            spacing: 4
                            Text { text: "NVMe:"; color: Theme.comment; font.pixelSize: 12 }
                            Text { text: SystemMonitorService.nvmeTemp + "°C"; color: Theme.fg; font.pixelSize: 12 }
                        }

                        Item { Layout.fillWidth: true }

                        RowLayout {
                            spacing: 4
                            Text {
                                text: SystemMonitorService.hasWifi ? "Wi-Fi:" : "Ethernet:"
                                color: Theme.comment
                                font.pixelSize: 12
                            }
                            Text {
                                text: SystemMonitorService.hasWifi
                                    ? SystemMonitorService.wifiSignal
                                    : (NetworkService.ethernetConnected ? "Connected" : "Disconnected")
                                color: Theme.fg
                                font.pixelSize: 12
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        RowLayout {
                            spacing: 4
                            Text { text: "Net Dn:"; color: Theme.comment; font.pixelSize: 12 }
                            Text { text: SystemMonitorService.netRx; color: Theme.fg; font.pixelSize: 12 }
                        }

                        Item { Layout.fillWidth: true }

                        RowLayout {
                            spacing: 4
                            Text { text: "Net Up:"; color: Theme.comment; font.pixelSize: 12 }
                            Text { text: SystemMonitorService.netTx; color: Theme.fg; font.pixelSize: 12 }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    // Smooth Sparkline Graph for Network History
                    SparklineGraph {
                        Layout.fillWidth: true
                        historyData: SystemMonitorService.netHistory
                        barColor: Theme.accent
                    }

                    // Storage Gauge Bar
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "Storage"; color: Theme.comment; font.pixelSize: 11 }
                            Item { Layout.fillWidth: true }
                            Text { text: SystemMonitorService.diskUsed + " / " + SystemMonitorService.diskTotal + " GB (" + SystemMonitorService.diskPct + "%)"; color: Theme.fg; font.pixelSize: 11 }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 6
                            radius: 3
                            color: Theme.bg
                            clip: true

                            Rectangle {
                                height: parent.height
                                width: Math.min(parent.width, Math.max(0, parent.width * (SystemMonitorService.diskPct / 100.0)))
                                radius: 3
                                color: Theme.accent
                                Behavior on width { NumberAnimation { duration: 300 } }
                            }
                        }
                    }
                }
            }
        }
    }
}
