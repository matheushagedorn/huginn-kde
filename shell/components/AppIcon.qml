import QtQuick
import "../services"
import "../theme"

// An application's own icon, drawn at a consistent optical size.
//
// Icons do not agree on padding. A Papirus icon leaves a margin inside its
// square; an icon generated from a web app, like a Brave PWA, is edge to edge.
// Drawn in the same box the second one towers over its neighbours, which is
// the blown-up WhatsApp tile in the dock and the launcher.
//
// The correction is measured once per file by icon_metrics.py, since QML
// cannot look at an image's pixels. Anything the services did not measure
// comes back as 1.0 and is drawn exactly as it is.
Item {
    id: root

    property string source: ""
    property real scaleHint: AppLauncherService.iconScale(source)
    property alias status: image.status
    property alias fillMode: image.fillMode

    Image {
        id: image
        anchors.centerIn: parent
        width: Math.round(parent.width * root.scaleHint)
        height: Math.round(parent.height * root.scaleHint)
        // Twice the drawn size: these are photographic PNGs as often as they
        // are vectors, and a 26px slot rasterising at 26 goes soft.
        sourceSize.width: Math.round(width * 2)
        sourceSize.height: Math.round(height * 2)
        source: root.source
        fillMode: Image.PreserveAspectFit
        smooth: true
        asynchronous: true
    }
}
