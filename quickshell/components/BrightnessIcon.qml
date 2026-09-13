import QtQuick
import "../theme"

// Panel brightness glyph. Reads from the active icon theme, with a drawn
// fallback so the slot is never empty if the theme is missing the file.
Item {
    id: root
    property int brightness: 100

    implicitWidth: 16
    implicitHeight: 16

    Image {
        id: img
        anchors.fill: parent
        // Bound to the rendered size instead of a fixed 16, which rasterised
        // the SVG at 16 and then scaled it to 14 in the panel.
        sourceSize.width: Math.round(width)
        sourceSize.height: Math.round(height)
        fillMode: Image.PreserveAspectFit
        // A backlight at zero is a different state, not a dimmer icon.
        source: "file://" + Theme.iconsDir + "/" + Theme.panelIconDir + "/24x24/panel/"
                + (root.brightness <= 0 ? "gpm-brightness-lcd-disabled.svg" : "gpm-brightness-lcd.svg")
        visible: status === Image.Ready
    }

    // Fallback: a sun, drawn from the palette, if the icon theme has no file.
    Canvas {
        anchors.fill: parent
        visible: img.status === Image.Error || img.status === Image.Null
        antialiasing: true
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var c = width / 2
            ctx.strokeStyle = Theme.fg
            ctx.fillStyle = Theme.fg
            ctx.lineWidth = Math.max(1, width / 14)
            ctx.beginPath()
            ctx.arc(c, c, width * 0.22, 0, Math.PI * 2)
            ctx.fill()
            for (var i = 0; i < 8; i++) {
                var a = i * Math.PI / 4
                ctx.beginPath()
                ctx.moveTo(c + Math.cos(a) * width * 0.32, c + Math.sin(a) * width * 0.32)
                ctx.lineTo(c + Math.cos(a) * width * 0.44, c + Math.sin(a) * width * 0.44)
                ctx.stroke()
            }
        }
    }
}
