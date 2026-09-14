import QtQuick
import "../theme"

// Volume level. Three steps plus muted, drawn from the shared Lucide set.
UiIcon {
    property int volume: 100
    property bool isMuted: false

    implicitWidth: 16
    implicitHeight: 16

    name: (isMuted || volume === 0) ? "volume-x"
        : volume > 50 ? "volume-2" : "volume-1"
}
