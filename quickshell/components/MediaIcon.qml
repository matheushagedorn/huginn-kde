import QtQuick

Item {
    id: root
    implicitWidth: 14
    implicitHeight: 14
    property string iconType: "play" // "play", "pause", "prev", "next"
    property color color: "#f8f8f2"

    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: true

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            var w = width;
            var h = height;
            ctx.fillStyle = root.color;
            ctx.strokeStyle = root.color;
            ctx.lineWidth = 1.8;
            ctx.lineCap = "round";

            if (root.iconType === "play") {
                ctx.beginPath();
                ctx.moveTo(w * 0.25, h * 0.15);
                ctx.lineTo(w * 0.85, h * 0.5);
                ctx.lineTo(w * 0.25, h * 0.85);
                ctx.closePath();
                ctx.fill();
            } else if (root.iconType === "pause") {
                ctx.fillRect(w * 0.2, h * 0.15, w * 0.22, h * 0.7);
                ctx.fillRect(w * 0.58, h * 0.15, w * 0.22, h * 0.7);
            } else if (root.iconType === "prev") {
                ctx.fillRect(w * 0.12, h * 0.18, w * 0.16, h * 0.64);
                ctx.beginPath();
                ctx.moveTo(w * 0.82, h * 0.15);
                ctx.lineTo(w * 0.35, h * 0.5);
                ctx.lineTo(w * 0.82, h * 0.85);
                ctx.closePath();
                ctx.fill();
            } else if (root.iconType === "next") {
                ctx.fillRect(w * 0.72, h * 0.18, w * 0.16, h * 0.64);
                ctx.beginPath();
                ctx.moveTo(w * 0.18, h * 0.15);
                ctx.lineTo(w * 0.65, h * 0.5);
                ctx.lineTo(w * 0.18, h * 0.85);
                ctx.closePath();
                ctx.fill();
            }
        }

        Connections {
            target: root
            function onIconTypeChanged() { canvas.requestPaint() }
            function onColorChanged() { canvas.requestPaint() }
        }
    }
}
