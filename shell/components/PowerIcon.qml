import QtQuick
import "../theme"

UiIcon {
    // Kept for call sites that still set it; the stroke now comes from the
    // shared icon set instead of being drawn per component.
    property real strokeWidth: 0

    implicitWidth: 16
    implicitHeight: 16
    name: "power"
}
