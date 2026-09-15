import QtQuick
import Quickshell.Widgets
import "../theme"

Item {
    id: root
    implicitWidth: 54
    implicitHeight: 54

    property string artUrl: ""
    property bool isPlaying: false

    property real size: Math.min(width, height)

    // Outer Stationary Circular Mask Container (Enforces 1:1 Aspect Ratio)
    ClippingRectangle {
        id: discMask
        width: root.size
        height: root.size
        anchors.centerIn: parent
        radius: root.size / 2
        color: Theme.bg
        border.color: Theme.separator
        border.width: 1

        // Inner Rotating Disc Item
        Item {
            anchors.fill: parent

            RotationAnimation on rotation {
                running: root.isPlaying
                loops: Animation.Infinite
                from: 0
                to: 360
                duration: 6000
            }

            // Entire Circular Album Cover Image
            Image {
                id: albumImg
                anchors.fill: parent
                source: root.artUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready && root.artUrl !== ""
            }

            // Palette gradient while there is no artwork. This was three
            // frozen Dracula hex values, so the disc stayed purple/pink on
            // every one of the other 29 variants.
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.accent }
                    GradientStop { position: 1.0; color: Theme.subAccent }
                }
                visible: !albumImg.visible
            }

            // Center Spindle Hole
            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 0.18
                height: parent.height * 0.18
                radius: width / 2
                color: Theme.bg
                border.color: Theme.separator
                border.width: 1
            }
        }
    }
}
