import QtQuick
import "../theme"

Rectangle {
    id: root

    property alias contentItem: container
    default property alias data: container.data

    color: Theme.bg
    radius: Theme.cornerRadius
    border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.24)
    border.width: 1

    Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
    Behavior on border.color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }

    Item {
        id: container
        anchors.fill: parent
        anchors.margins: 4
    }
}

