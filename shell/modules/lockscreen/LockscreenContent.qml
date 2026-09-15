import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../../theme"
import "../../components"
import "../../services"

Item {
    id: root

    focus: true

    // Force focus when lockscreen becomes visible
    onVisibleChanged: {
        if (visible) {
            root.forceActiveFocus()
            secretInput.forceActiveFocus()
        }
    }

    Component.onCompleted: {
        root.forceActiveFocus()
        secretInput.forceActiveFocus()
    }

    // Secret hidden TextInput to capture keyboard presses reliably
    TextInput {
        id: secretInput
        anchors.fill: parent
        opacity: 0
        focus: true
        activeFocusOnTab: true
        echoMode: TextInput.Password

        onTextChanged: {
            // Synchronize with LockscreenService
            if (text !== LockscreenService.userPassword) {
                LockscreenService.userPassword = text
                LockscreenService.typedCount = text.length
            }
        }

        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                event.accepted = true
                LockscreenService.submitPassword()
            } else if (event.key === Qt.Key_Escape) {
                event.accepted = true
                secretInput.text = ""
                LockscreenService.clearPassword()
            }
        }
    }

    Connections {
        target: LockscreenService
        function onIsLockedChanged() {
            if (LockscreenService.isLocked) {
                secretInput.text = ""
                root.forceActiveFocus()
                secretInput.forceActiveFocus()
            }
        }
        function onAuthFailedChanged() {
            if (LockscreenService.authFailed) {
                shakeAnim.restart()
                secretInput.text = ""
            }
        }
    }

    // Shake animation on incorrect password
    SequentialAnimation {
        id: shakeAnim
        running: false
        NumberAnimation { target: cardContainer; property: "anchors.horizontalCenterOffset"; to: -24; duration: 40; easing.type: Easing.OutQuad }
        NumberAnimation { target: cardContainer; property: "anchors.horizontalCenterOffset"; to: 24; duration: 50; easing.type: Easing.OutQuad }
        NumberAnimation { target: cardContainer; property: "anchors.horizontalCenterOffset"; to: -16; duration: 50; easing.type: Easing.OutQuad }
        NumberAnimation { target: cardContainer; property: "anchors.horizontalCenterOffset"; to: 16; duration: 50; easing.type: Easing.OutQuad }
        NumberAnimation { target: cardContainer; property: "anchors.horizontalCenterOffset"; to: -8; duration: 40; easing.type: Easing.OutQuad }
        NumberAnimation { target: cardContainer; property: "anchors.horizontalCenterOffset"; to: 8; duration: 40; easing.type: Easing.OutQuad }
        NumberAnimation { target: cardContainer; property: "anchors.horizontalCenterOffset"; to: 0; duration: 40; easing.type: Easing.OutQuad }
    }

    // Click anywhere to focus input
    MouseArea {
        anchors.fill: parent
        onClicked: {
            root.forceActiveFocus()
            secretInput.forceActiveFocus()
        }
    }

    // Main Centered Content Container
    ColumnLayout {
        id: mainColumn
        anchors.centerIn: parent
        spacing: 24
        width: Math.min(540, parent.width - 40)

        // 1. Sleek Clock & Date Header
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 4

            Text {
                id: clockText
                text: {
                    let date = new Date()
                    let h = date.getHours().toString().padStart(2, '0')
                    let m = date.getMinutes().toString().padStart(2, '0')
                    return `${h}:${m}`
                }
                color: Theme.fg
                font.pixelSize: 76   // display clock, outside the UI scale
                font.weight: Font.Bold
                font.family: Theme.fontFamily
                Layout.alignment: Qt.AlignHCenter

                Timer {
                    interval: 1000
                    running: true
                    repeat: true
                    onTriggered: {
                        let date = new Date()
                        let h = date.getHours().toString().padStart(2, '0')
                        let m = date.getMinutes().toString().padStart(2, '0')
                        clockText.text = `${h}:${m}`
                    }
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 8

                Text {
                    id: dateText
                    text: {
                        let d = new Date()
                        let days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
                        let months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
                        return `${days[d.getDay()]}, ${months[d.getMonth()]} ${d.getDate()}`
                    }
                    color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.85)
                    font.pixelSize: Theme.fsHead
                    font.weight: Font.DemiBold
                    font.family: Theme.fontFamily
                }

                Text { text: "•"; color: Theme.accent; font.pixelSize: Theme.fsSubhead }

                Text {
                    text: WeatherService.currentTempStr
                    color: Theme.textMuted
                    font.pixelSize: Theme.fsHead
                    font.weight: Font.Medium
                    font.family: Theme.fontFamily
                }
            }
        }

        Item { Layout.preferredHeight: 6 }

        // 2. User Avatar & Status Badge
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 10

            // User Avatar Container with Glowing Pulse Ring
            Item {
                width: 104
                height: 104
                Layout.alignment: Qt.AlignHCenter

                // Mask Item for Avatar Image Rounding
                Rectangle {
                    id: avatarMask
                    anchors.fill: parent
                    radius: 52
                    // Mask source for OpacityMask: only its alpha is read.
                    color: "#ffffff"
                    visible: false
                    layer.enabled: true
                }

                // Main Circular Background & Glowing Border
                Rectangle {
                    id: avatarCircle
                    anchors.fill: parent
                    radius: 52
                    color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.20)
                    border.color: Theme.accent
                    border.width: 2.5
                }

                // Profile Image masked to 100% pure circle
                Image {
                    id: avatarImg
                    anchors.fill: parent
                    anchors.margins: 3
                    source: LockscreenService.avatarPath
                    fillMode: Image.PreserveAspectCrop
                    visible: status === Image.Ready && source !== ""
                    smooth: true
                    asynchronous: true
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: avatarMask
                    }
                }

                // Breathing Glow Ring
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -5
                    radius: 57
                    color: "transparent"
                    border.color: Theme.accent
                    border.width: 1.5
                    opacity: avatarPulse.opacityVal

                    Item {
                        id: avatarPulse
                        property real opacityVal: 0.3
                        SequentialAnimation on opacityVal {
                            loops: Animation.Infinite
                            running: true
                            NumberAnimation { to: 0.85; duration: 1600; easing.type: Easing.InOutQuad }
                            NumberAnimation { to: 0.25; duration: 1600; easing.type: Easing.InOutQuad }
                        }
                    }
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 8

                Text {
                    text: LockscreenService.username || "User"
                    color: Theme.fg
                    font.pixelSize: Theme.fsTitle
                    font.weight: Font.Bold
                    font.family: Theme.fontFamily
                }

                Rectangle {
                    implicitWidth: statusText.implicitWidth + 12
                    implicitHeight: 18
                    radius: 9
                    color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2)
                    border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.5)
                    border.width: 1

                    Text {
                        id: statusText
                        anchors.centerIn: parent
                        text: "Locked"
                        color: Theme.accent
                        font.pixelSize: Theme.fsCaption
                        font.weight: Font.Bold
                        font.family: Theme.fontFamily
                    }
                }
            }
        }

        Item { Layout.preferredHeight: 4 }

        // 3. Glass Input Card with Animated Typing Dots & Session Controls
        Item {
            id: cardContainer
            Layout.fillWidth: true
            implicitHeight: cardRect.implicitHeight

            // Ambient Glow behind Card
            Rectangle {
                anchors.fill: cardRect
                anchors.margins: -8
                radius: 28
                color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.16)
            }

            Rectangle {
                id: cardRect
                anchors.left: parent.left
                anchors.right: parent.right
                implicitHeight: cardLayout.implicitHeight + 36
                radius: 22
                color: Theme.surface
                border.color: LockscreenService.authFailed ? Theme.red : (secretInput.activeFocus ? Theme.accent : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.22))
                border.width: LockscreenService.authFailed ? 2 : (secretInput.activeFocus ? 2 : 1)

                Behavior on border.color { ColorAnimation { duration: 180 } }

                ColumnLayout {
                    id: cardLayout
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 18
                    spacing: 16

    // Delete recoil animation for password input box
    property bool isDeleting: false

    SequentialAnimation {
        id: deleteAnim
        running: false
        onStarted: root.isDeleting = true
        onFinished: root.isDeleting = false
        NumberAnimation { target: inputRect; property: "scale"; to: 0.975; duration: 45; easing.type: Easing.OutQuad }
        NumberAnimation { target: inputRect; property: "scale"; to: 1.0; duration: 110; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
    }

    // Centered Password Input Field
    Rectangle {
        id: inputRect
        Layout.fillWidth: true
        implicitHeight: 50
        radius: 12
        color: Theme.bg
        border.color: root.isDeleting
                      ? Qt.rgba(Theme.red.r, Theme.red.g, Theme.red.b, 0.7)
                      : (secretInput.activeFocus ? Theme.accent : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.2))
        border.width: secretInput.activeFocus || root.isDeleting ? 2 : 1

        Behavior on border.color { ColorAnimation { duration: 120 } }
        Behavior on border.width { NumberAnimation { duration: 120 } }

        // Placeholder Text
        Text {
            anchors.centerIn: parent
            visible: LockscreenService.typedCount === 0 && !LockscreenService.isAuthenticating
            text: "Enter password to unlock..."
            color: Theme.textMuted
            font.pixelSize: Theme.fsSubhead
            font.family: Theme.fontFamily
        }

        // Authenticating Spinner / Status Text
        Text {
            anchors.centerIn: parent
            visible: LockscreenService.isAuthenticating
            text: "Verifying password..."
            color: Theme.accent
            font.pixelSize: Theme.fsSubhead
            font.weight: Font.DemiBold
            font.family: Theme.fontFamily
        }

        ListModel {
            id: dotsModel
        }

        Connections {
            target: LockscreenService
            function onTypedCountChanged() {
                let targetCount = LockscreenService.typedCount
                if (targetCount < dotsModel.count) {
                    deleteAnim.restart()
                }
                while (dotsModel.count < targetCount) {
                    dotsModel.append({ "id": dotsModel.count })
                }
                while (dotsModel.count > targetCount) {
                    dotsModel.remove(dotsModel.count - 1)
                }
            }
        }

        // ANIMATED TYPING DOTS
        Item {
            id: dotsContainer
            anchors.centerIn: parent
            implicitWidth: Math.min(320, dotsModel.count * 26)
            implicitHeight: 20
            visible: dotsModel.count > 0 && !LockscreenService.isAuthenticating

            Behavior on implicitWidth {
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }

            ListView {
                id: dotsView
                anchors.centerIn: parent
                width: Math.min(dotsContainer.implicitWidth, count * 26)
                height: 20
                orientation: ListView.Horizontal
                spacing: 12
                interactive: false
                model: dotsModel

                add: Transition {
                    ParallelAnimation {
                        NumberAnimation { property: "scale"; from: 0.1; to: 1.0; duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
                        NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 180; easing.type: Easing.OutCubic }
                    }
                }

                remove: Transition {
                    ParallelAnimation {
                        NumberAnimation { property: "scale"; from: 1.0; to: 0.0; duration: 200; easing.type: Easing.InBack; easing.overshoot: 1.5 }
                        NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: 160; easing.type: Easing.OutCubic }
                        NumberAnimation { property: "y"; from: 0; to: -14; duration: 200; easing.type: Easing.InCubic }
                    }
                }

                removeDisplaced: Transition {
                    NumberAnimation { properties: "x,y"; duration: 180; easing.type: Easing.OutCubic }
                }

                displaced: Transition {
                    NumberAnimation { properties: "x,y"; duration: 200; easing.type: Easing.OutCubic }
                }

                                delegate: Item {
                                    width: 14
                                    height: 14

                                    Rectangle {
                                        id: dot
                                        anchors.fill: parent
                                        radius: 7
                                        color: index === dotsModel.count - 1 ? Theme.accent : Theme.fg

                                        Behavior on color { ColorAnimation { duration: 180 } }

                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: 6
                                            height: 6
                                            radius: 3
                                            color: Theme.fg
                                            opacity: index === dotsModel.count - 1 ? 1.0 : 0.6
                                        }
                                    }
                                }
                            }
                        }

                        // Unlock submit arrow button on right
                        Rectangle {
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            width: 32; height: 32; radius: 8
                            color: LockscreenService.typedCount > 0 ? Theme.accent : "transparent"
                            visible: LockscreenService.typedCount > 0 && !LockscreenService.isAuthenticating

                            Behavior on color { ColorAnimation { duration: 120 } }

                            UiIcon {
                                anchors.centerIn: parent
                                name: "arrow-right"
                                color: Theme.accentFg
                                implicitWidth: 15
                                implicitHeight: 15
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: LockscreenService.submitPassword()
                            }
                        }

                        // Focus Click Area
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                root.forceActiveFocus()
                                secretInput.forceActiveFocus()
                            }
                        }
                    }

                    // Dynamic Auth Error Feedback Message
                    RowLayout {
                        Layout.fillWidth: true
                        visible: LockscreenService.authFailed

                        Item { Layout.fillWidth: true }

                        Text {
                            text: LockscreenService.authErrorMsg
                            color: Theme.red
                            font.pixelSize: Theme.fsStrong
                            font.weight: Font.Bold
                            font.family: Theme.fontFamily
                        }

                        Item { Layout.fillWidth: true }
                    }

                    // Session Action Buttons (Sleep, Restart, Power Off)
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        // Suspend / Sleep Button
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 46
                            radius: 12
                            color: suspendMouse.containsMouse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25) : Theme.bg
                            border.color: suspendMouse.containsMouse ? Theme.accent : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.2)

                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            scale: suspendMouse.pressed ? 0.95 : (suspendMouse.containsMouse ? 1.03 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 120 } }

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 8
                                UiIcon { name: "moon"; color: Theme.fg; implicitWidth: 18; implicitHeight: 18 }
                                Text { text: "Sleep"; color: Theme.fg; font.pixelSize: Theme.fsSubhead; font.weight: Font.SemiBold; font.family: Theme.fontFamily }
                            }

                            MouseArea {
                                id: suspendMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: Quickshell.execDetached(["systemctl", "suspend"])
                            }
                        }

                        // Reboot / Restart Button
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 46
                            radius: 12
                            color: rebootMouse.containsMouse ? Qt.rgba(Theme.orange.r, Theme.orange.g, Theme.orange.b, 0.25) : Theme.bg
                            border.color: rebootMouse.containsMouse ? Theme.orange : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.2)

                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            scale: rebootMouse.pressed ? 0.95 : (rebootMouse.containsMouse ? 1.03 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 120 } }

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 8
                                UiIcon { name: "rotate-ccw"; color: Theme.fg; implicitWidth: 18; implicitHeight: 18 }
                                Text { text: "Restart"; color: Theme.fg; font.pixelSize: Theme.fsSubhead; font.weight: Font.SemiBold; font.family: Theme.fontFamily }
                            }

                            MouseArea {
                                id: rebootMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: SessionService.reboot()
                            }
                        }

                        // Shutdown / Power Off Button
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 46
                            radius: 12
                            color: powerMouse.containsMouse ? Qt.rgba(Theme.red.r, Theme.red.g, Theme.red.b, 0.25) : Theme.bg
                            border.color: powerMouse.containsMouse ? Theme.red : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.2)

                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            scale: powerMouse.pressed ? 0.95 : (powerMouse.containsMouse ? 1.03 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 120 } }

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 8
                                UiIcon { name: "power"; color: Theme.danger; implicitWidth: 18; implicitHeight: 18 }
                                Text { text: "Power Off"; color: Theme.fg; font.pixelSize: Theme.fsSubhead; font.weight: Font.SemiBold; font.family: Theme.fontFamily }
                            }

                            MouseArea {
                                id: powerMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: SessionService.shutdown()
                            }
                        }
                    }
                }
            }
        }
    }
}
