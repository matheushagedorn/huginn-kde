import QtQuick
import QtQuick.Layouts
import "../../components"
import "../../services"
import "../../theme"

// Everything the bar knows, in one panel.
//
// The bar had three separate popups saying three parts of the same thing:
// the calendar under the clock, the forecast under the weather capsule, the
// player under the media capsule. Each one made you go back to the bar to see
// the next. This is the clock's panel now: the time first, then the month,
// what the sky is doing, what is playing, and how the machine is holding up.
//
// It is a plain Item, not a window: the popup that carries it already exists
// under the clock, and a popup belongs to the control that opened it.
Item {
    id: dash

    implicitWidth: 560
    implicitHeight: content.implicitHeight

    // The system readings, as one row each. The desktop cards carry the
    // detail; here a name, a bar and a number are enough to answer "is
    // anything on fire".
    component Reading: RowLayout {
        id: reading
        property string label: ""
        property real value: 0
        property string readout: ""
        property color barColor: Theme.loadColor(reading.value)

        Layout.fillWidth: true
        spacing: Theme.sp2

        Text {
            text: reading.label
            color: Theme.textMuted
            font.pixelSize: Theme.fsCaption
            font.family: Theme.fontFamily
            Layout.preferredWidth: 58
        }

        GaugeBar {
            value: reading.value
            fillColor: reading.barColor
            Layout.fillWidth: true
        }

        Text {
            text: reading.readout
            color: Theme.fg
            font.pixelSize: Theme.fsCaption
            font.family: Theme.fontFamily
            horizontalAlignment: Text.AlignRight
            Layout.preferredWidth: 96
        }
    }

    ColumnLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Theme.sp3

        // The hour is the largest thing here on purpose: it is what the eye
        // came for, and everything under it is context.
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.sp3

            Text {
                text: DateTimeService.timeStr
                color: Theme.fg
                font.pixelSize: Theme.fsDisplay
                font.family: Theme.fontFamily
                font.weight: Font.Bold
            }

            Item { Layout.fillWidth: true }

            Text {
                text: DateTimeService.dateStr
                color: Theme.textMuted
                font.pixelSize: Theme.fsBody
                font.family: Theme.fontFamily
                Layout.alignment: Qt.AlignVCenter
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.separator
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.sp4

            CalendarWidget {
                Layout.alignment: Qt.AlignTop
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: Theme.sp3

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: weatherRow.implicitHeight + Theme.sp2
                    radius: Theme.radiusChip
                    color: cityMouse.containsMouse ? Theme.stateAccentHover : "transparent"

                    Behavior on color { ColorAnimation { duration: 120 } }

                    MouseArea {
                        id: cityMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: PopupService.toggleWeatherPicker()
                    }

                    RowLayout {
                        id: weatherRow
                        anchors.fill: parent
                        anchors.leftMargin: Theme.sp1
                        anchors.rightMargin: Theme.sp1
                        spacing: Theme.sp3

                    UiIcon {
                        name: WeatherService.getWeatherIcon(WeatherService.weatherCode)
                        color: Theme.fg
                        implicitWidth: 38
                        implicitHeight: 38
                        Layout.alignment: Qt.AlignVCenter
                    }

                    ColumnLayout {
                        spacing: 0
                        Layout.fillWidth: true

                        Text {
                            text: WeatherService.available ? WeatherService.currentTempStr : "No forecast"
                            color: Theme.fg
                            font.pixelSize: Theme.fsTitle
                            font.family: Theme.fontFamily
                            font.weight: Font.Bold
                        }

                        Text {
                            text: WeatherService.available
                                  ? WeatherService.condition + (WeatherService.city ? ", " + WeatherService.city : "")
                                  : "Pick a city to see the forecast"
                            color: Theme.textMuted
                            font.pixelSize: Theme.fsCaption
                            font.family: Theme.fontFamily
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Theme.separator
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.sp2

                    Reading {
                        label: "CPU"
                        value: SystemMonitorService.cpuPct
                        readout: SystemMonitorService.cpuPct + "%  " + SystemMonitorService.cpuTemp + "°C"
                    }

                    Reading {
                        label: "GPU"
                        value: SystemMonitorService.gpuPct
                        readout: SystemMonitorService.gpuPct + "%  " + SystemMonitorService.gpuTemp + "°C"
                    }

                    Reading {
                        label: "Memory"
                        value: SystemMonitorService.ramPct
                        readout: SystemMonitorService.ramUsed + " / " + SystemMonitorService.ramTotal + " GB"
                    }

                    Reading {
                        label: "Storage"
                        value: SystemMonitorService.diskPct
                        barColor: Theme.loadColor(SystemMonitorService.diskPct, 80, 92)
                        readout: SystemMonitorService.diskPct + "% of " + SystemMonitorService.diskTotal + " GB"
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.separator
            visible: WeatherService.available
        }

        // The week ahead. This is the one thing the weather capsule in the bar
        // used to hold that the block above does not, so it comes along.
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.sp2
            visible: WeatherService.available

            Repeater {
                model: WeatherService.forecastData

                Rectangle {
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: 62
                    radius: Theme.radiusChip
                    color: Theme.surface
                    border.color: Theme.separator
                    border.width: 1

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 2

                        Text {
                            text: parent.parent.modelData.day
                            color: Theme.textMuted
                            font.pixelSize: Theme.fsCaption
                            font.family: Theme.fontFamily
                            font.weight: Font.Medium
                            Layout.alignment: Qt.AlignHCenter
                        }

                        UiIcon {
                            name: parent.parent.modelData.icon
                            color: Theme.textMuted
                            implicitWidth: 18
                            implicitHeight: 18
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Text {
                            text: parent.parent.modelData.temp
                            color: Theme.fg
                            font.pixelSize: Theme.fsCaption
                            font.family: Theme.fontFamily
                            font.weight: Font.Bold
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }
            }
        }
    }
}
