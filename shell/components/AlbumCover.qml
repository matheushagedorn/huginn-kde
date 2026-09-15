import QtQuick
import Quickshell.Widgets
import "../theme"

// Album art, cropped to a disc.
//
// The previous version set `radius` on a plain Rectangle with `clip: true`
// and expected a circle. Qt Quick's clip is rectangular regardless of radius,
// so the artwork rendered as a square poking out of a rounded border.
// ClippingRectangle does the rounded clip properly.
Item {
    id: root
    implicitWidth: 54
    implicitHeight: 54

    property string artUrl: ""
    property real size: Math.min(width, height)

    ClippingRectangle {
        width: root.size
        height: root.size
        anchors.centerIn: parent
        radius: root.size / 2
        color: Theme.bg
        border.color: Theme.separator
        border.width: 1

        Image {
            id: albumImg
            anchors.fill: parent
            source: root.artUrl
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            // Rasterise at the size actually drawn, so a 20px panel thumbnail
            // does not decode a full-resolution cover.
            sourceSize.width: Math.round(root.size * 2)
            sourceSize.height: Math.round(root.size * 2)
            visible: root.artUrl !== "" && status === Image.Ready
        }

        // Shown while the art loads or when there is none.
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.accent }
                GradientStop { position: 1.0; color: Theme.subAccent }
            }
            visible: !albumImg.visible

            Canvas {
                id: musicCanvas
                anchors.fill: parent
                antialiasing: true

                Connections {
                    target: Theme
                    function onAccentFgChanged() { musicCanvas.requestPaint() }
                }

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    var w = width
                    var h = height
                    ctx.fillStyle = Theme.accentFg

                    ctx.beginPath()
                    ctx.arc(w * 0.4, h * 0.64, w * 0.13, 0, Math.PI * 2)
                    ctx.fill()

                    ctx.fillRect(w * 0.48, h * 0.25, w * 0.08, h * 0.42)
                    ctx.fillRect(w * 0.48, h * 0.25, w * 0.24, h * 0.09)
                }
            }
        }
    }
}
