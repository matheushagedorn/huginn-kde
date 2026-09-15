import QtQuick
import "../theme"

Rectangle {
    id: root

    property alias contentItem: container
    default property alias data: container.data

    // A panel that sits inside another panel should not draw its own ground.
    // The bar is one glass slab now, and its three sections are content on it.
    property bool chrome: true

    color: chrome ? Theme.bg : "transparent"
    radius: Theme.cornerRadius
    border.color: chrome ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.24) : "transparent"
    border.width: chrome ? 1 : 0

    Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
    Behavior on border.color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }

    Item {
        id: container
        anchors.fill: parent
        anchors.margins: 4
    }
}

