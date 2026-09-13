import QtQuick
import "../theme"

Canvas {
    id: root
    implicitWidth: 14
    implicitHeight: 14

    property bool isDnd: false
    property color color: isDnd ? Theme.pink : Theme.comment

    onIsDndChanged: requestPaint()
    onColorChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d");
        ctx.reset();
        var w = width;
        var h = height;

        ctx.strokeStyle = root.color;
        ctx.fillStyle = root.color;
        ctx.lineWidth = 1.3;

        // Bell Dome & Body
        ctx.beginPath();
        ctx.arc(w * 0.5, h * 0.42, w * 0.28, Math.PI, 0, false);
        ctx.lineTo(w * 0.78, h * 0.7);
        ctx.lineTo(w * 0.22, h * 0.7);
        ctx.closePath();
        ctx.stroke();

        // Bell Clapper
        ctx.beginPath();
        ctx.arc(w * 0.5, h * 0.78, w * 0.09, 0, Math.PI * 2);
        ctx.fill();

        // DND Slash Indicator
        if (isDnd) {
            ctx.strokeStyle = Theme.red;
            ctx.lineWidth = 1.5;
            ctx.beginPath();
            ctx.moveTo(w * 0.15, h * 0.85);
            ctx.lineTo(w * 0.85, h * 0.15);
            ctx.stroke();
        }
    }
}
