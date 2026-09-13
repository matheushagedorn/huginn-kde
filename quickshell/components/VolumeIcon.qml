import QtQuick
import "../theme"

Image {
    id: icon
    property int volume: 100
    property bool isMuted: false

    width: 16
    height: 16
    sourceSize.width: 16
    sourceSize.height: 16
    fillMode: Image.PreserveAspectFit

    source: {
        let base = "file://" + Theme.iconsDir + "/" + Theme.panelIconDir + "/24x24/panel/"
        if (isMuted || volume === 0) {
            return base + "audio-volume-muted-panel.svg"
        } else if (volume > 66) {
            return base + "audio-volume-high-panel.svg"
        } else if (volume > 33) {
            return base + "audio-volume-medium-panel.svg"
        } else {
            return base + "audio-volume-low-panel.svg"
        }
    }
}
