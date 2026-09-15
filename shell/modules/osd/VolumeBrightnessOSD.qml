import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../../components"
import "../../services"
import "../../theme"

// Floating On-Screen Display (OSD) for Volume & Brightness Adjustments
PanelWindow {
    id: osdWindow

    anchors {
        bottom: true
        left: true
        right: true
    }
    margins.bottom: 110

    WlrLayershell.layer: WlrLayershell.Overlay
    exclusionMode: ExclusionMode.Ignore
    visible: osdTimer.running
    color: "transparent"

    implicitHeight: 48

    property string osdType: "volume" // "volume" or "brightness"
    property real osdValue: 0.5
    property bool isMuted: false

    function showVolume(val, muted) {
        osdType = "volume"
        osdValue = val
        isMuted = muted
        osdTimer.restart()
    }

    function showBrightness(val) {
        osdType = "brightness"
        osdValue = val
        isMuted = false
        osdTimer.restart()
    }

    Timer {
        id: osdTimer
        interval: 1800
        repeat: false
    }

    Connections {
        target: AudioService
        function onVolumeChanged() {
            osdWindow.showVolume(AudioService.volume / 100.0, AudioService.isMuted)
        }
        function onIsMutedChanged() {
            osdWindow.showVolume(AudioService.volume / 100.0, AudioService.isMuted)
        }
    }

    Connections {
        target: BrightnessService
        function onMasterBrightnessChanged() {
            osdWindow.showBrightness(BrightnessService.masterBrightness / 100.0)
        }
    }

    GlassPanel {
        anchors.horizontalCenter: parent.horizontalCenter
        width: 230
        height: 48
        radius: Theme.radiusCard

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 12

            // The rest of the shell draws its indicators from the icon theme;
            // the OSD was the one place still on colour emoji, which pulled in
            // Noto Color Emoji and ignored the palette entirely.
            Item {
                Layout.preferredWidth: 18
                Layout.preferredHeight: 18
                Layout.alignment: Qt.AlignVCenter

                VolumeIcon {
                    anchors.fill: parent
                    visible: osdWindow.osdType === "volume"
                    volume: Math.round(osdWindow.osdValue * 100)
                    isMuted: osdWindow.isMuted
                }

                BrightnessIcon {
                    anchors.fill: parent
                    visible: osdWindow.osdType === "brightness"
                    brightness: Math.round(osdWindow.osdValue * 100)
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 6
                radius: 3
                color: Theme.currentLine

                Rectangle {
                    width: parent.width * Math.max(0.0, Math.min(1.0, osdWindow.osdValue))
                    height: parent.height
                    radius: 3
                    color: Theme.accent

                    Behavior on width {
                        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                    }
                }
            }

            Text {
                text: Math.round(osdWindow.osdValue * 100) + "%"
                color: Theme.fg
                font.pixelSize: Theme.fsBody
                font.family: Theme.fontFamily
                font.weight: Font.Bold
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}
