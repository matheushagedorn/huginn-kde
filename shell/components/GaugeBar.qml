import QtQuick
import QtQuick.Layouts
import "../theme"

// The usage bar under a monitoring card's heading.
//
// The root is an Item rather than the track itself so the bar can sit in a
// taller slot without growing into it: inside a card body every line occupies
// the same height, whether it holds text or a bar, and that is what keeps the
// rows of one card level with the rows of the card beside it.
Item {
    id: bar

    property real value: 0                       // 0..100
    property color fillColor: Theme.accent
    property int thickness: 6

    Layout.fillWidth: true
    implicitHeight: thickness

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: bar.thickness
        radius: height / 2
        color: Theme.bg
        clip: true

        Rectangle {
            height: parent.height
            width: Math.min(parent.width, Math.max(0, parent.width * (bar.value / 100.0)))
            radius: parent.radius
            color: bar.fillColor

            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 200 } }
        }
    }
}
