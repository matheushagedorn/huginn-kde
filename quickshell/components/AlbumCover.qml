import QtQuick
import "../theme"

Item {
    id: root
    implicitWidth: 54
    implicitHeight: 54

    property string artUrl: ""
    property real size: Math.min(width, height)

    // Outer Container (1:1 Static Circle)
    Rectangle {
        width: root.size
        height: root.size
        anchors.centerIn: parent
        radius: root.size / 2
        color: Theme.bg
        border.color: Theme.currentLine
        border.width: 1
        clip: true

        // Web & Local Album Art Image
        Image {
            id: albumImg
            anchors.fill: parent
            source: root.artUrl
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: root.artUrl !== "" && status !== Image.Error
        }

        // Color-themed Fallback Image (Only if artUrl is empty or fails)
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.accent }
                GradientStop { position: 1.0; color: Theme.subAccent }
            }
            visible: root.artUrl === "" || albumImg.status === Image.Error

            // Minimal Dynamic Vector Music Icon
            Canvas {
                id: musicCanvas
                anchors.fill: parent
                antialiasing: true

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    var w = width;
                    var h = height;
                    ctx.fillStyle = Theme.isDark ? Theme.bg : "#ffffff";

                    // Note Head
                    ctx.beginPath();
                    ctx.arc(w * 0.4, h * 0.64, w * 0.13, 0, Math.PI * 2);
                    ctx.fill();

                    // Note Stem
                    ctx.fillRect(w * 0.48, h * 0.25, w * 0.08, h * 0.42);

                    // Note Flag
                    ctx.fillRect(w * 0.48, h * 0.25, w * 0.24, h * 0.09);
                }
            }
        }
    }
}
