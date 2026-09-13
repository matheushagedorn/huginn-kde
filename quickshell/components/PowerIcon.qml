import QtQuick

Item {
    id: root
    implicitWidth: 13
    implicitHeight: 13
    property color color: "#bd93f9"
    property real strokeWidth: 1.6

    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: true

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            var cx = width / 2;
            var cy = height / 2;
            var r = Math.min(width, height) / 2 - (root.strokeWidth / 2) - 0.5;

            ctx.strokeStyle = root.color;
            ctx.lineWidth = root.strokeWidth;
            ctx.lineCap = "round";

            ctx.beginPath();
            ctx.arc(cx, cy + 0.5, r, -Math.PI * 0.35, Math.PI * 1.35, false);
            ctx.stroke();

            ctx.beginPath();
            ctx.moveTo(cx, cy - r);
            ctx.lineTo(cx, cy);
            ctx.stroke();
        }

        Connections {
            target: root
            function onColorChanged() { canvas.requestPaint() }
            function onStrokeWidthChanged() { canvas.requestPaint() }
        }
    }
}
