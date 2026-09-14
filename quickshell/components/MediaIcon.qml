import QtQuick
import "../theme"

UiIcon {
    property string iconType: "play"   // play, pause, prev, next

    implicitWidth: 16
    implicitHeight: 16

    name: iconType === "pause" ? "pause"
        : iconType === "prev" ? "skip-back"
        : iconType === "next" ? "skip-forward" : "play"
}
