import QtQuick
import "../theme"

Canvas {
    id: root
    implicitWidth: 20
    implicitHeight: 20

    property int weatherCode: 0
    property bool isDay: true
    property color color: Theme.isDark ? Theme.yellow : "#ea580c"

    onWeatherCodeChanged: requestPaint()
    onIsDayChanged: requestPaint()
    onColorChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d");
        ctx.reset();
        var w = width;
        var h = height;

        ctx.strokeStyle = root.color;
        ctx.fillStyle = root.color;
        ctx.lineWidth = 1.5;

        if (weatherCode === 0 && isDay) {
            // Sun
            ctx.beginPath();
            ctx.arc(w/2, h/2, w*0.24, 0, Math.PI*2);
            ctx.stroke();
            ctx.fill();
            for (var i = 0; i < 8; i++) {
                var angle = (i * Math.PI) / 4;
                var x1 = w/2 + Math.cos(angle) * (w*0.32);
                var y1 = h/2 + Math.sin(angle) * (h*0.32);
                var x2 = w/2 + Math.cos(angle) * (w*0.42);
                var y2 = h/2 + Math.sin(angle) * (h*0.42);
                ctx.beginPath();
                ctx.moveTo(x1, y1);
                ctx.lineTo(x2, y2);
                ctx.stroke();
            }
        } else {
            // Minimal Cloud
            ctx.fillStyle = Theme.isDark ? Theme.cyan : Theme.accent;
            ctx.beginPath();
            ctx.arc(w*0.35, h*0.55, w*0.18, 0, Math.PI*2);
            ctx.arc(w*0.55, h*0.45, w*0.22, 0, Math.PI*2);
            ctx.arc(w*0.72, h*0.58, w*0.15, 0, Math.PI*2);
            ctx.fill();
        }
    }
}
