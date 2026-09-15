import QtQuick
import "../theme"

Item {
    id: root
    property var historyData: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    property color barColor: Theme.accent
    property int maxVal: 100
    property bool autoScale: true

    implicitHeight: 30
    implicitWidth: 140

    onHistoryDataChanged: canvas.requestPaint()
    onBarColorChanged: canvas.requestPaint()
    onWidthChanged: canvas.requestPaint()
    onHeightChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: true

        onPaint: {
            let ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            let data = root.historyData
            if (!data || data.length < 2) return

            let w = width
            let h = height
            let step = w / Math.max(1, data.length - 1)

            // Dynamic peak range: if autoScale is enabled, scale relative to current peak (min ceiling 15%)
            let dataMax = 0
            for (let k = 0; k < data.length; k++) {
                if (data[k] > dataMax) dataMax = data[k]
            }
            let peakVal = root.autoScale ? Math.max(12, dataMax * 1.15) : root.maxVal

            // Background Area Gradient under curve
            let grad = ctx.createLinearGradient(0, 0, 0, h)
            grad.addColorStop(0, Qt.rgba(root.barColor.r, root.barColor.g, root.barColor.b, 0.40))
            grad.addColorStop(1, Qt.rgba(root.barColor.r, root.barColor.g, root.barColor.b, 0.02))

            ctx.beginPath()
            ctx.moveTo(0, h)

            for (let i = 0; i < data.length; i++) {
                let val = Math.max(0, Math.min(peakVal, data[i]))
                let x = i * step
                let y = h - (val / peakVal) * (h - 6) - 3
                ctx.lineTo(x, y)
            }

            ctx.lineTo(w, h)
            ctx.closePath()
            ctx.fillStyle = grad
            ctx.fill()

            // Glowing Line Stroke
            ctx.beginPath()
            for (let i = 0; i < data.length; i++) {
                let val = Math.max(0, Math.min(peakVal, data[i]))
                let x = i * step
                let y = h - (val / peakVal) * (h - 6) - 3
                if (i === 0) ctx.moveTo(x, y)
                else ctx.lineTo(x, y)
            }
            ctx.strokeStyle = root.barColor
            ctx.lineWidth = 1.8
            ctx.stroke()
        }
    }
}
