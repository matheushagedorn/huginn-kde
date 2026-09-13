import QtQuick
import "../theme"

Image {
    id: icon
    property int volume: 100
    property bool isMuted: false

    width: 16
    height: 16
    // Rasterise at the size actually rendered, not a fixed 16.
    sourceSize.width: Math.round(width)
    sourceSize.height: Math.round(height)
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
