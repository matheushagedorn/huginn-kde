import QtQuick

Item {
    id: root
    implicitWidth: 160
    implicitHeight: textItem.implicitHeight
    clip: true

    property alias text: textItem.text
    property alias color: textItem.color
    property alias font: textItem.font

    Text {
        id: textItem
        x: 0
        anchors.verticalCenter: parent.verticalCenter

        property bool isOverflow: textItem.implicitWidth > root.width

        SequentialAnimation on x {
            running: textItem.isOverflow
            loops: Animation.Infinite

            PauseAnimation { duration: 1500 }

            NumberAnimation {
                to: root.width - textItem.implicitWidth - 10
                duration: Math.max(3000, (textItem.implicitWidth - root.width) * 40)
                easing.type: Easing.Linear
            }

            PauseAnimation { duration: 1500 }

            NumberAnimation {
                to: 0
                duration: 800
                easing.type: Easing.InOutQuad
            }
        }

        onTextChanged: {
            x = 0
        }
    }
}
