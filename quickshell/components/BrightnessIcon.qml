import QtQuick
import "../theme"

UiIcon {
    property int brightness: 100

    implicitWidth: 16
    implicitHeight: 16

    name: brightness <= 0 ? "moon" : brightness > 50 ? "sun" : "sun-dim"
}
