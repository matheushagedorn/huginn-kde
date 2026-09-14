import QtQuick
import "../theme"

// Battery level. Charging is a different glyph rather than a badge, so the
// state reads at 16px.
UiIcon {
    property int percentage: 100
    property bool isCharging: false

    implicitWidth: 16
    implicitHeight: 16

    name: isCharging ? "battery-charging"
        : percentage <= 10 ? "battery-warning"
        : percentage > 66 ? "battery-full"
        : percentage > 33 ? "battery-medium" : "battery-low"

    color: (!isCharging && percentage <= 10) ? Theme.danger : Theme.fg
}
