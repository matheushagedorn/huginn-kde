import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import "../../components"
import "../../services"
import "../../theme"

GlassPanel {
    id: root
    implicitWidth: mainLayout.implicitWidth + 24
    implicitHeight: Theme.barHeight - 4

    property var activeTrayItem: null
    property var activeTrayMenuOpener: null
    property real activeTrayX: 12

    function getCleanAppName(item) {
        if (!item) return "Application"
        let title = item.title ? item.title.trim() : ""
        let idStr = item.id ? item.id.trim() : ""
        
        let raw = title
        if (!raw || raw.includes("_status_icon") || raw.includes(".desktop") || raw.includes("org.")) {
            raw = idStr
        }
        if (!raw) raw = idStr
        if (!raw) return "Application"

        raw = raw.replace(/(_status_icon_\d+|_tray_\d+|_\d+)$/i, "")

        if (raw.includes(".")) {
            let parts = raw.split(".")
            raw = parts[parts.length - 1]
        }

        raw = raw.replace(/[-_]/g, " ")
        raw = raw.replace(/([a-z])([A-Z])/g, "$1 $2")

        let words = raw.split(" ").filter(w => w.length > 0).map(w => w.charAt(0).toUpperCase() + w.slice(1))
        let result = words.join(" ")
        if (result.toLowerCase() === "archupdate") return "Arch Update"
        return result || "Application"
    }

    // Where the row of controls starts inside the panel: the GlassPanel
    // inset plus the row margin, read from the items themselves.
    readonly property real contentInset: mainLayout.parent.x + mainLayout.x

    RowLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 6

        // System Tray Section (Active Background Apps)
        RowLayout {
            spacing: 4

            Repeater {
                model: SystemTray.items

                Rectangle {
                    id: trayItemRect
                    width: 24
                    height: 24
                    radius: 5
                    color: trayMouse.containsMouse ? Theme.currentLine : "transparent"

                    // Continuous Background QsMenuOpener (Caches DBus Menu Items for Instant Display)
                    QsMenuOpener {
                        id: itemMenuOpener
                        menu: modelData.menu
                    }

                    IconImage {
                        anchors.centerIn: parent
                        width: 16
                        height: 16
                        source: modelData.icon
                    }

                    MouseArea {
                        id: trayMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton

                        onClicked: (mouse) => {
                            var globalPos = trayItemRect.mapToItem(null, 0, 0)
                            var gx = Math.round(globalPos.x + trayItemRect.width / 2)
                            var gy = Math.round(globalPos.y + trayItemRect.height)

                            if (mouse.button === Qt.LeftButton) {
                                if (modelData.activate) {
                                    modelData.activate(gx, gy)
                                }
                            } else if (mouse.button === Qt.RightButton) {
                                root.activeTrayItem = modelData
                                root.activeTrayMenuOpener = itemMenuOpener
                                var mapped = trayItemRect.mapToItem(root, 0, 0)
                                root.activeTrayX = mapped.x

                                if (modelData.contextMenu) {
                                    modelData.contextMenu(gx, gy)
                                } else if (modelData.secondaryActivate) {
                                    modelData.secondaryActivate(gx, gy)
                                }

                                PopupService.toggleTray()
                            }
                        }
                    }
                }
            }
        }

        // Vertical Separator between Running Apps (System Tray) and Notification Center
        Rectangle {
            Layout.preferredWidth: 1
            Layout.preferredHeight: 16
            color: Theme.separator
            Layout.leftMargin: 4
            Layout.rightMargin: 4
            visible: true
        }

        // Notification Center Icon Snippet (Papirus Panel Icon & Dynamic Unread/DND SVG)
        Rectangle {
            id: notifBtn
            Layout.preferredWidth: 26
            Layout.preferredHeight: Theme.barCapsule
            radius: 6
            color: PopupService.notificationMenuOpen ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2) : (notifMouse.containsMouse ? Theme.currentLine : "transparent")
            border.color: PopupService.notificationMenuOpen ? Theme.accent : "transparent"
            border.width: PopupService.notificationMenuOpen ? 1 : 0

            Behavior on color { ColorAnimation { duration: 120 } }

            // Papirus draws `indicator-notification-*` as a mailbox, which is
            // not what anyone reads as "notifications" in a status bar. This is
            // the theme's own bell, so it keeps the fill and weight of the
            // icons next to it.
            BellIcon {
                anchors.centerIn: parent
                implicitWidth: 16
                implicitHeight: 16
                isDnd: NotificationService.isDnd
                hasUnread: NotificationService.notifications.length > 0
            }

            MouseArea {
                id: notifMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: PopupService.toggleNotification()
            }
        }

        // Screenshot & Screen Recording Icon Snippet (Authentic Papirus Panel SVG)
        Rectangle {
            id: captureBtn
            Layout.preferredWidth: 26
            Layout.preferredHeight: Theme.barCapsule
            radius: 6
            color: PopupService.captureMenuOpen ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2) : (captureMouse.containsMouse ? Theme.currentLine : "transparent")
            border.color: PopupService.captureMenuOpen ? Theme.accent : "transparent"
            border.width: PopupService.captureMenuOpen ? 1 : 0

            Behavior on color { ColorAnimation { duration: 120 } }

            UiIcon {
                anchors.centerIn: parent
                name: "camera"
                implicitWidth: 16
                implicitHeight: 16
            }

            MouseArea {
                id: captureMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: PopupService.toggleCapture()
            }
        }

        // Clipboard Manager Icon Snippet
        Rectangle {
            id: clipBtn
            Layout.preferredWidth: 26
            Layout.preferredHeight: Theme.barCapsule
            radius: 6
            color: PopupService.clipboardMenuOpen ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2) : (clipMouse.containsMouse ? Theme.currentLine : "transparent")
            border.color: PopupService.clipboardMenuOpen ? Theme.accent : "transparent"
            border.width: PopupService.clipboardMenuOpen ? 1 : 0

            Behavior on color { ColorAnimation { duration: 120 } }

            UiIcon {
                anchors.centerIn: parent
                name: "clipboard-list"
                implicitWidth: 16
                implicitHeight: 16
            }

            MouseArea {
                id: clipMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    ClipboardService.scanClipboard()
                    PopupService.toggleClipboard()
                }
            }
        }

        // Audio Icon Snippet (Icon-only, Scroll Wheel + Click Popup)
        Rectangle {
            id: audioBtn
            Layout.preferredWidth: 26
            Layout.preferredHeight: Theme.barCapsule
            radius: 6
            color: PopupService.audioMenuOpen ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2) : (audioMouse.containsMouse ? Theme.currentLine : "transparent")
            border.color: PopupService.audioMenuOpen ? Theme.accent : "transparent"
            border.width: PopupService.audioMenuOpen ? 1 : 0

            Behavior on color { ColorAnimation { duration: 120 } }

            VolumeIcon {
                anchors.centerIn: parent
                volume: AudioService.volume
                isMuted: AudioService.isMuted
                width: 16
                height: 16
            }

            MouseArea {
                id: audioMouse
                anchors.fill: parent
                hoverEnabled: true

                onClicked: PopupService.toggleAudio()

                onWheel: (wheel) => {
                    if (wheel.angleDelta.y > 0) {
                        AudioService.volumeUp()
                    } else if (wheel.angleDelta.y < 0) {
                        AudioService.volumeDown()
                    }
                }
            }
        }

        // Bluetooth Icon Snippet (Placed to the Right of Audio Control)
        Rectangle {
            id: btBtn
            visible: BluetoothService.hasAdapter
            Layout.preferredWidth: visible ? 26 : 0
            Layout.preferredHeight: Theme.barCapsule
            radius: 6
            color: PopupService.bluetoothMenuOpen
                   ? Theme.stateActive
                   : (btMouse.containsMouse ? Theme.currentLine : "transparent")
            border.color: PopupService.bluetoothMenuOpen ? Theme.accent : "transparent"
            border.width: PopupService.bluetoothMenuOpen ? 1 : 0

            Behavior on color { ColorAnimation { duration: 120 } }

            BluetoothIcon {
                anchors.centerIn: parent
                isPowered: BluetoothService.isPowered
                isConnected: BluetoothService.connectedDevices.length > 0
                width: 16
                height: 16
            }

            MouseArea {
                id: btMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    BluetoothService.scanBluetooth()
                    PopupService.toggleBluetooth()
                }
            }
        }

        // Screen Brightness Icon Snippet
        Rectangle {
            id: brightBtn
            Layout.preferredWidth: 26
            Layout.preferredHeight: Theme.barCapsule
            radius: 6
            color: PopupService.brightnessMenuOpen
                   ? Theme.stateActive
                   : (brightMouse.containsMouse ? Theme.currentLine : "transparent")
            border.color: PopupService.brightnessMenuOpen ? Theme.accent : "transparent"
            border.width: PopupService.brightnessMenuOpen ? 1 : 0

            Behavior on color { ColorAnimation { duration: 120 } }

            BrightnessIcon {
                anchors.centerIn: parent
                brightness: BrightnessService.masterBrightness
                width: 16
                height: 16
            }

            MouseArea {
                id: brightMouse
                anchors.fill: parent
                hoverEnabled: true

                onClicked: {
                    BrightnessService.scanDevices()
                    PopupService.toggleBrightness()
                }

                onWheel: (wheel) => {
                    if (wheel.angleDelta.y > 0) {
                        BrightnessService.brightnessUp()
                    } else if (wheel.angleDelta.y < 0) {
                        BrightnessService.brightnessDown()
                    }
                }
            }
        }

        // External Storage Mount Icon Snippet (Placed to the Right of Brightness)
        Rectangle {
            id: mountBtn
            Layout.preferredWidth: 26
            Layout.preferredHeight: Theme.barCapsule
            radius: 6
            color: PopupService.mountMenuOpen
                   ? Theme.stateActive
                   : (mountMouse.containsMouse ? Theme.currentLine : "transparent")
            border.color: PopupService.mountMenuOpen ? Theme.accent : "transparent"
            border.width: PopupService.mountMenuOpen ? 1 : 0

            Behavior on color { ColorAnimation { duration: 120 } }

            UiIcon {
                anchors.centerIn: parent
                name: "hard-drive"
                implicitWidth: 16
                implicitHeight: 16
            }

            MouseArea {
                id: mountMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    MountService.scanDevices()
                    PopupService.toggleMount()
                }
            }
        }

        // Network Icon Snippet (Ethernet & Wi-Fi Dynamic Badge)
        Rectangle {
            id: netBtn
            Layout.preferredWidth: 26
            Layout.preferredHeight: Theme.barCapsule
            radius: 6
            color: PopupService.networkMenuOpen
                   ? Theme.stateActive
                   : (netMouse.containsMouse ? Theme.currentLine : "transparent")
            border.color: PopupService.networkMenuOpen ? Theme.accent : "transparent"
            border.width: PopupService.networkMenuOpen ? 1 : 0

            Behavior on color { ColorAnimation { duration: 120 } }

            NetworkIcon {
                anchors.centerIn: parent
                isConnected: NetworkService.isConnected
                signalPercent: NetworkService.signalPercent
                isEthernet: NetworkService.ethernetConnected
                isWifiPowered: NetworkService.isWifiPowered
                width: 16
                height: 16
            }

            MouseArea {
                id: netMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    NetworkService.scanWifi()
                    PopupService.toggleNetwork()
                }
            }
        }

        // Battery icon removed: this is a desktop, there is no battery.
    }

    // Screenshot & Screen Recording Control Detached Popup Window
    PopupWindow {
        id: captureMenu
        anchor.window: window
        anchor.rect.x: Theme.popupX(root, root.contentInset + captureBtn.x, captureBtn.width, implicitWidth, window.width, root.contentInset)
        anchor.rect.y: Theme.popupGap
        anchor.edges: Edges.Bottom
        visible: false
        color: "transparent"

        implicitWidth: capGlass.implicitWidth
        implicitHeight: capGlass.implicitHeight

        property real animProgress: 0.0

        NumberAnimation on animProgress {
            id: capPopIn
            running: false
            to: 1.0
            duration: 220
            easing.type: Easing.OutBack
            easing.overshoot: 1.15
        }

        NumberAnimation on animProgress {
            id: capPopOut
            running: false
            to: 0.0
            duration: 160
            easing.type: Easing.InQuad
            onFinished: captureMenu.visible = false
        }

        Connections {
            target: PopupService
            function onCaptureMenuOpenChanged() {
                if (PopupService.captureMenuOpen) {
                    capPopOut.running = false
                    captureMenu.visible = true
                    capPopIn.restart()
                } else if (captureMenu.visible) {
                    capPopIn.running = false
                    capPopOut.restart()
                }
            }
        }

        GlassPanel {
            id: capGlass
            implicitWidth: 280
            implicitHeight: Math.min(420, Math.max(260, capCardLayout.implicitHeight + 24))
            anchors.fill: parent

            opacity: captureMenu.animProgress
            scale: 0.90 + 0.10 * captureMenu.animProgress
            transformOrigin: Item.TopRight

            ColumnLayout {
                id: capCardLayout
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 12
                spacing: 10

                // Header
                Text {
                    text: "Capture and record"
                    color: Theme.fg
                    font.pixelSize: Theme.fsStrong
                    font.family: Theme.fontFamily
                    font.weight: Font.Bold
                }

                // Solid Divider
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Theme.currentLine
                }

                // Section 1: Screenshots
                Text {
                    text: "Take a screenshot"
                    color: Theme.textMuted
                    font.pixelSize: Theme.fsCaption
                    font.family: Theme.fontFamily
                    font.weight: Font.Bold
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    // 1. Region / Selection Screenshot
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        radius: 5
                        color: regShotMouse.containsMouse ? Theme.currentLine : (Theme.isDark ? Theme.currentLine : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.08))
                        border.color: Theme.currentLine
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8

                            UiIcon {
                                name: "scissors"
                                implicitWidth: 15
                                implicitHeight: 15
                            }
                            Text { text: "Selected region"; color: Theme.fg; font.pixelSize: Theme.fsCaption; font.weight: Font.Medium; Layout.fillWidth: true }
                            Text { text: "Super+Shift+S"; color: Theme.textMuted; font.pixelSize: Theme.fsCaption }
                        }

                        MouseArea {
                            id: regShotMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                PopupService.closeAll()
                                CaptureService.captureRegion()
                            }
                        }
                    }

                    // 2. Fullscreen Screenshot
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        radius: 5
                        color: fullShotMouse.containsMouse ? Theme.currentLine : (Theme.isDark ? Theme.currentLine : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.08))
                        border.color: Theme.currentLine
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8

                            UiIcon {
                                name: "monitor"
                                implicitWidth: 15
                                implicitHeight: 15
                            }
                            Text { text: "Whole screen"; color: Theme.fg; font.pixelSize: Theme.fsCaption; font.weight: Font.Medium; Layout.fillWidth: true }
                            Text { text: "PrintScreen"; color: Theme.textMuted; font.pixelSize: Theme.fsCaption }
                        }

                        MouseArea {
                            id: fullShotMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                PopupService.closeAll()
                                CaptureService.captureFullscreen()
                            }
                        }
                    }

                    // 3. Active Window Screenshot
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        radius: 5
                        color: winShotMouse.containsMouse ? Theme.currentLine : (Theme.isDark ? Theme.currentLine : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.08))
                        border.color: Theme.currentLine
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8

                            UiIcon {
                                name: "layout-grid"
                                implicitWidth: 15
                                implicitHeight: 15
                            }
                            Text { text: "Active window"; color: Theme.fg; font.pixelSize: Theme.fsCaption; font.weight: Font.Medium; Layout.fillWidth: true }
                            Text { text: "Super+Print"; color: Theme.textMuted; font.pixelSize: Theme.fsCaption }
                        }

                        MouseArea {
                            id: winShotMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                PopupService.closeAll()
                                CaptureService.captureWindow()
                            }
                        }
                    }
                }

                // Solid Divider
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Theme.currentLine
                }

                // Section 2: Screen Recording
                Text {
                    text: "Record video"
                    color: Theme.textMuted
                    font.pixelSize: Theme.fsCaption
                    font.family: Theme.fontFamily
                    font.weight: Font.Bold
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    // 4. Region Screen Recording
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        radius: 5
                        color: regRecMouse.containsMouse ? Theme.currentLine : (Theme.isDark ? Theme.currentLine : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.08))
                        border.color: Theme.currentLine
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8

                            UiIcon {
                                name: "video"
                                implicitWidth: 15
                                implicitHeight: 15
                            }
                            Text { text: "Selected region"; color: Theme.fg; font.pixelSize: Theme.fsCaption; font.weight: Font.Medium; Layout.fillWidth: true }
                            Text { text: "Super+Alt+R"; color: Theme.textMuted; font.pixelSize: Theme.fsCaption }
                        }

                        MouseArea {
                            id: regRecMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                PopupService.closeAll()
                                CaptureService.recordRegion()
                            }
                        }
                    }

                    // 5. Fullscreen Screen Recording
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        radius: 5
                        color: fullRecMouse.containsMouse ? Theme.currentLine : (Theme.isDark ? Theme.currentLine : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.08))
                        border.color: Theme.currentLine
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8

                            UiIcon {
                                name: "cast"
                                implicitWidth: 15
                                implicitHeight: 15
                            }
                            Text { text: "Whole screen"; color: Theme.fg; font.pixelSize: Theme.fsCaption; font.weight: Font.Medium; Layout.fillWidth: true }
                            Text { text: "Super+Alt+F"; color: Theme.textMuted; font.pixelSize: Theme.fsCaption }
                        }

                        MouseArea {
                            id: fullRecMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                PopupService.closeAll()
                                CaptureService.recordScreen()
                            }
                        }
                    }
                }

                // Solid Divider
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Theme.currentLine
                }

                // Section 3: Open Spectacle Full GUI Utility (Text Only)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    radius: 5
                    color: guiBtnMouse.containsMouse ? Theme.currentLine : "transparent"
                    border.color: Theme.accent
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "Open Spectacle"
                        color: Theme.accent
                        font.pixelSize: Theme.fsCaption
                        font.family: Theme.fontFamily
                        font.weight: Font.Bold
                    }

                    MouseArea {
                        id: guiBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            CaptureService.openGui()
                        }
                    }
                }
            }
        }
    }

    // Detached Notification Center Popup Window (Controlled by PopupService)
    PopupWindow {
        id: notifMenu
        anchor.window: window
        anchor.rect.x: Theme.popupX(root, root.contentInset + notifBtn.x, notifBtn.width, implicitWidth, window.width, root.contentInset)
        anchor.rect.y: Theme.popupGap
        anchor.edges: Edges.Bottom
        visible: false
        color: "transparent"

        implicitWidth: notifGlass.implicitWidth
        implicitHeight: notifGlass.implicitHeight

        property real animProgress: 0.0

        NumberAnimation on animProgress {
            id: notifPopIn
            running: false
            to: 1.0
            duration: 220
            easing.type: Easing.OutBack
            easing.overshoot: 1.15
        }

        NumberAnimation on animProgress {
            id: notifPopOut
            running: false
            to: 0.0
            duration: 160
            easing.type: Easing.InQuad
            onFinished: notifMenu.visible = false
        }

        Connections {
            target: PopupService
            function onNotificationMenuOpenChanged() {
                if (PopupService.notificationMenuOpen) {
                    notifPopOut.running = false
                    notifMenu.visible = true
                    notifPopIn.restart()
                } else if (notifMenu.visible) {
                    notifPopIn.running = false
                    notifPopOut.restart()
                }
            }
        }

        GlassPanel {
            id: notifGlass
            implicitWidth: 320
            implicitHeight: Math.min(500, Math.max(100, notifLayout.implicitHeight + 20))
            anchors.fill: parent

            opacity: notifMenu.animProgress
            scale: 0.90 + 0.10 * notifMenu.animProgress
            transformOrigin: Item.Top

            ColumnLayout {
                id: notifLayout
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 10
                spacing: 8

                // Header with DND Toggle & Clear All
                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "Notifications"
                        color: Theme.fg
                        font.pixelSize: Theme.fsStrong
                        font.family: Theme.fontFamily
                        font.weight: Font.Bold
                    }

                    Item { Layout.fillWidth: true }

                    // Do Not Disturb. The label keeps the same name in both
                    // states — a dot and the fill carry which one it is, so
                    // the state does not rely on colour alone. It used to read
                    // "DND: ON" in a fixed 58px pill that the text overran.
                    Rectangle {
                        implicitWidth: dndRow.implicitWidth + Theme.sp3
                        height: 24
                        radius: Theme.radiusChip
                        color: NotificationService.isDnd
                               ? Qt.rgba(Theme.subAccent.r, Theme.subAccent.g, Theme.subAccent.b, 0.2)
                               : (dndBtnMouse.containsMouse ? Theme.stateHover : "transparent")
                        border.color: NotificationService.isDnd ? Theme.subAccent : Theme.separator
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: 120 } }

                        RowLayout {
                            id: dndRow
                            anchors.centerIn: parent
                            spacing: 5

                            Rectangle {
                                width: 6
                                height: 6
                                radius: 3
                                color: NotificationService.isDnd ? Theme.subAccentText : Theme.textMuted
                            }

                            Text {
                                text: "Do not disturb"
                                color: NotificationService.isDnd ? Theme.subAccentText : Theme.textMuted
                                font.pixelSize: Theme.fsCaption
                                font.family: Theme.fontFamily
                                font.weight: Font.DemiBold
                            }
                        }

                        MouseArea {
                            id: dndBtnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: NotificationService.toggleDnd()
                        }
                    }

                    Rectangle {
                        implicitWidth: clearNotifLabel.implicitWidth + Theme.sp3
                        height: 24
                        radius: Theme.radiusChip
                        visible: NotificationService.notifications.length > 0
                        color: clearNotifMouse.containsMouse ? Qt.rgba(Theme.red.r, Theme.red.g, Theme.red.b, 0.2) : "transparent"
                        border.color: Theme.danger
                        border.width: 1

                        Text {
                            id: clearNotifLabel
                            anchors.centerIn: parent
                            text: "Clear all"
                            color: Theme.danger
                            font.pixelSize: Theme.fsCaption
                            font.family: Theme.fontFamily
                            font.weight: Font.DemiBold
                        }

                        MouseArea {
                            id: clearNotifMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: NotificationService.clearAll()
                        }
                    }
                }

                // Solid Divider
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Theme.currentLine
                }

                // Scrollable List of Notifications
                Flickable {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(380, notifListCol.implicitHeight)
                    contentHeight: notifListCol.implicitHeight
                    clip: true

                    ColumnLayout {
                        id: notifListCol
                        width: parent.width
                        spacing: 6

                        // Empty State
                        Text {
                            text: NotificationService.isDnd ? "Do Not Disturb is active" : "No new notifications"
                            color: Theme.textMuted
                            font.pixelSize: Theme.fsCaption
                            font.family: Theme.fontFamily
                            font.italic: true
                            visible: NotificationService.notifications.length === 0
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: 4
                            Layout.bottomMargin: 4
                        }

                        Repeater {
                            model: NotificationService.notifications

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: notifItemCol.implicitHeight + 12
                                radius: 6
                                color: Theme.surface
                                border.color: Theme.currentLine
                                border.width: 1

                                ColumnLayout {
                                    id: notifItemCol
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 4

                                    RowLayout {
                                        Layout.fillWidth: true

                                        // Dynamically Sized App Source Badge Box
                                        Rectangle {
                                            implicitWidth: appText.implicitWidth + 12
                                            implicitHeight: 18
                                            radius: 4
                                            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                                            border.color: Theme.accent
                                            border.width: 1

                                            Text {
                                                id: appText
                                                anchors.centerIn: parent
                                                // The app names itself; shouting
                                                // it back is not our call.
                                                text: modelData.app
                                                color: Theme.accent
                                                font.pixelSize: Theme.fsCaption
                                                font.family: Theme.fontFamily
                                                font.weight: Font.Bold
                                            }
                                        }

                                        Item { Layout.fillWidth: true }

                                        Text {
                                            text: modelData.time
                                            color: Theme.textMuted
                                            font.pixelSize: Theme.fsCaption
                                            font.family: Theme.fontFamily
                                        }

                                        UiIcon {
                                            name: "x"
                                            color: delNotifMouse.containsMouse ? Theme.danger : Theme.textMuted
                                            implicitWidth: 15
                                            implicitHeight: 15

                                            MouseArea {
                                                id: delNotifMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: NotificationService.dismissNotification(modelData.id)
                                            }
                                        }
                                    }

                                    Text {
                                        text: modelData.summary
                                        color: Theme.fg
                                        font.pixelSize: Theme.fsBody
                                        font.family: Theme.fontFamily
                                        font.weight: Font.Bold
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: modelData.body
                                        color: Theme.textMuted
                                        font.pixelSize: Theme.fsCaption
                                        font.family: Theme.fontFamily
                                        maximumLineCount: 3
                                        wrapMode: Text.WrapAnywhere
                                        elide: Text.ElideRight
                                        visible: modelData.body !== ""
                                        Layout.fillWidth: true
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Clipboard Manager
    PopupWindow {
        id: clipMenu
        anchor.window: window
        anchor.rect.x: Theme.popupX(root, root.contentInset + clipBtn.x, clipBtn.width, implicitWidth, window.width, root.contentInset)
        anchor.rect.y: Theme.popupGap
        anchor.edges: Edges.Bottom
        visible: false
        color: "transparent"

        implicitWidth: clipGlass.implicitWidth
        implicitHeight: clipGlass.implicitHeight

        property real animProgress: 0.0

        NumberAnimation on animProgress {
            id: clipPopIn
            running: false
            to: 1.0
            duration: 220
            easing.type: Easing.OutBack
            easing.overshoot: 1.15
        }

        NumberAnimation on animProgress {
            id: clipPopOut
            running: false
            to: 0.0
            duration: 160
            easing.type: Easing.InQuad
            onFinished: clipMenu.visible = false
        }

        Connections {
            target: PopupService
            function onClipboardMenuOpenChanged() {
                if (PopupService.clipboardMenuOpen) {
                    clipPopOut.running = false
                    clipMenu.visible = true
                    clipPopIn.restart()
                } else if (clipMenu.visible) {
                    clipPopIn.running = false
                    clipPopOut.restart()
                }
            }
        }

        GlassPanel {
            id: clipGlass
            implicitWidth: 320
            implicitHeight: Math.min(460, Math.max(180, clipCardLayout.implicitHeight + 24))
            anchors.fill: parent
            color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.98)

            opacity: clipMenu.animProgress
            scale: 0.90 + 0.10 * clipMenu.animProgress
            transformOrigin: Item.TopRight

            ColumnLayout {
                id: clipCardLayout
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 12
                spacing: 10

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: "Clipboard"
                        color: Theme.fg
                        font.pixelSize: Theme.fsStrong
                        font.family: Theme.fontFamily
                        font.weight: Font.Bold
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        width: 58; height: 20; radius: 4
                        color: restartClipMouse.containsMouse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2) : "transparent"
                        border.color: Theme.accent
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "Restart"
                            color: Theme.accent
                            font.pixelSize: Theme.fsCaption
                            font.family: Theme.fontFamily
                            font.weight: Font.Bold
                        }

                        MouseArea {
                            id: restartClipMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: ClipboardService.restartService()
                        }
                    }

                    Rectangle {
                        width: 60; height: 20; radius: 4
                        visible: ClipboardService.items.length > 0
                        color: clearClipMouse.containsMouse ? Qt.rgba(Theme.red.r, Theme.red.g, Theme.red.b, 0.2) : "transparent"
                        border.color: Theme.red
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "Clear all"
                            color: Theme.red
                            font.pixelSize: Theme.fsCaption
                            font.family: Theme.fontFamily
                            font.weight: Font.Bold
                        }

                        MouseArea {
                            id: clearClipMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: ClipboardService.clearAll()
                        }
                    }
                }

                // Solid Divider
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Theme.currentLine
                }

                // Scrollable List of Clipboard Items
                Flickable {
                    Layout.fillWidth: true
                    implicitHeight: Math.min(380, Math.max(40, clipListCol.implicitHeight))
                    Layout.preferredHeight: implicitHeight
                    contentHeight: clipListCol.implicitHeight
                    clip: true

                    ColumnLayout {
                        id: clipListCol
                        width: parent.width
                        spacing: 6

                        // Empty State
                        Text {
                            text: "Clipboard is empty"
                            color: Theme.textMuted
                            font.pixelSize: Theme.fsCaption
                            font.family: Theme.fontFamily
                            font.italic: true
                            visible: ClipboardService.items.length === 0
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: 4
                            Layout.bottomMargin: 4
                        }

                        Repeater {
                            model: ClipboardService.items

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: Math.max(36, itemColLayout.implicitHeight + 16)
                                radius: 6
                                color: clipItemMouse.containsMouse ? Theme.currentLine : Theme.surface
                                border.color: Theme.currentLine
                                border.width: 1

                                MouseArea {
                                    id: clipItemMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        if (modelData && modelData.id) {
                                            ClipboardService.copyEntry(modelData.id)
                                        }
                                        PopupService.closeAll()
                                    }
                                }

                                ColumnLayout {
                                    id: itemColLayout
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 8
                                    spacing: 6

                                    RowLayout {
                                        Layout.fillWidth: true

                                        Rectangle {
                                            width: 48; height: 16; radius: 3
                                            color: (modelData && modelData.type === "image") ? Qt.rgba(Theme.subAccent.r, Theme.subAccent.g, Theme.subAccent.b, 0.2) : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2)

                                            Text {
                                                anchors.centerIn: parent
                                                text: (modelData && modelData.type === "image") ? "IMAGE" : "TEXT"
                                                color: (modelData && modelData.type === "image") ? Theme.subAccent : Theme.accent
                                                font.pixelSize: Theme.fsCaption
                                                font.family: Theme.fontFamily
                                                font.weight: Font.Bold
                                            }
                                        }

                                        Text {
                                            text: modelData ? (modelData.type === "image" ? (modelData.size || "") : ((modelData.length || 0) + " chars")) : ""
                                            color: Theme.textMuted
                                            font.pixelSize: Theme.fsCaption
                                            font.family: Theme.fontFamily
                                        }

                                        Item { Layout.fillWidth: true }

                                        Text {
                                            text: (modelData && modelData.time) ? modelData.time : ""
                                            color: Theme.textMuted
                                            font.pixelSize: Theme.fsCaption
                                            font.family: Theme.fontFamily
                                        }

                                        Rectangle {
                                            width: 20; height: 20; radius: 4
                                            color: delMouse.containsMouse ? Qt.rgba(255/255, 85/255, 85/255, 0.2) : "transparent"
                                            z: 10

                                            UiIcon {
                                                anchors.centerIn: parent
                                                name: "x"
                                                color: delMouse.containsMouse ? Theme.red : Theme.comment
                                                implicitWidth: 15
                                                implicitHeight: 15
                                            }

                                            MouseArea {
                                                id: delMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onClicked: (mouse) => {
                                                    mouse.accepted = true
                                                    if (modelData && modelData.id) {
                                                        ClipboardService.deleteEntry(modelData.id)
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Image {
                                        visible: modelData && modelData.type === "image"
                                        source: (modelData && modelData.type === "image" && modelData.path) ? ("file://" + modelData.path) : ""
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 100
                                        fillMode: Image.PreserveAspectFit
                                        horizontalAlignment: Image.AlignLeft
                                        asynchronous: true
                                        cache: true
                                    }

                                    Text {
                                        visible: modelData && modelData.type === "text"
                                        text: (modelData && modelData.type === "text" && modelData.content) ? modelData.content : ""
                                        color: Theme.fg
                                        font.pixelSize: Theme.fsCaption
                                        font.family: Theme.fontFamily
                                        maximumLineCount: 4
                                        wrapMode: Text.WrapAnywhere
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Bluetooth Control Detached Popup Window
    PopupWindow {
        id: btMenu
        anchor.window: window
        anchor.rect.x: Theme.popupX(root, root.contentInset + btBtn.x, btBtn.width, implicitWidth, window.width, root.contentInset)
        anchor.rect.y: Theme.popupGap
        anchor.edges: Edges.Bottom
        visible: false
        color: "transparent"

        implicitWidth: btGlass.implicitWidth
        implicitHeight: btGlass.implicitHeight

        property real animProgress: 0.0

        NumberAnimation on animProgress {
            id: btPopIn
            running: false
            to: 1.0
            duration: 220
            easing.type: Easing.OutBack
            easing.overshoot: 1.15
        }

        NumberAnimation on animProgress {
            id: btPopOut
            running: false
            to: 0.0
            duration: 160
            easing.type: Easing.InQuad
            onFinished: btMenu.visible = false
        }

        Connections {
            target: PopupService
            function onBluetoothMenuOpenChanged() {
                if (PopupService.bluetoothMenuOpen) {
                    btPopOut.running = false
                    btMenu.visible = true
                    btPopIn.restart()
                } else if (btMenu.visible) {
                    btPopIn.running = false
                    btPopOut.restart()
                }
            }
        }

        GlassPanel {
            id: btGlass
            implicitWidth: 300
            implicitHeight: BluetoothService.isPowered ? 240 : 80
            anchors.fill: parent

            opacity: btMenu.animProgress
            scale: 0.90 + 0.10 * btMenu.animProgress
            transformOrigin: Item.TopRight

            ColumnLayout {
                id: btCardLayout
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                // Header: Title + Power Toggle + Refresh Button
                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "Bluetooth"
                        color: Theme.fg
                        font.pixelSize: Theme.fsStrong
                        font.family: Theme.fontFamily
                        font.weight: Font.Bold
                    }

                    Item { Layout.fillWidth: true }

                    // Power ON/OFF Button
                    Rectangle {
                        width: 50; height: 20; radius: 4
                        color: BluetoothService.isPowered ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18) : Qt.rgba(Theme.comment.r, Theme.comment.g, Theme.comment.b, 0.15)
                        border.color: BluetoothService.isPowered ? Theme.accent : Theme.currentLine
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: BluetoothService.isPowered ? "ON" : "OFF"
                            color: BluetoothService.isPowered ? Theme.accent : Theme.comment
                            font.pixelSize: Theme.fsCaption
                            font.family: Theme.fontFamily
                            font.weight: Font.Bold
                        }

                        MouseArea {
                            id: btPwrMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: BluetoothService.togglePower()
                        }
                    }

                    Rectangle {
                        width: 20; height: 20; radius: 4
                        color: refreshBtMouse.containsMouse ? Theme.currentLine : "transparent"
                        UiIcon {
                            anchors.centerIn: parent
                            name: "refresh-cw"
                            implicitWidth: 15
                            implicitHeight: 15
                        }
                        MouseArea {
                            id: refreshBtMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: BluetoothService.scanBluetooth()
                        }
                    }
                }

                // Solid Divider
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Theme.currentLine
                }

                // Off State Banner
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: !BluetoothService.isPowered

                    Text {
                        anchors.centerIn: parent
                        text: "Bluetooth is turned off"
                        color: Theme.textMuted
                        font.pixelSize: Theme.fsBody
                        font.family: Theme.fontFamily
                        font.italic: true
                    }
                }

                Flickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentHeight: btScrollCol.implicitHeight
                    clip: true
                    visible: BluetoothService.isPowered

                    ColumnLayout {
                        id: btScrollCol
                        width: parent.width
                        spacing: 8

                        // Connected Devices Section
                        Text {
                            text: "Connected"
                            color: Theme.textMuted
                            font.pixelSize: Theme.fsCaption
                            font.family: Theme.fontFamily
                            font.weight: Font.Bold
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            Text {
                                text: "No connected devices"
                                color: Theme.textMuted
                                font.pixelSize: Theme.fsCaption
                                font.family: Theme.fontFamily
                                font.italic: true
                                visible: BluetoothService.connectedDevices.length === 0
                            }

                            Repeater {
                                model: BluetoothService.connectedDevices

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 28
                                    radius: 5
                                    color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                                    border.color: Theme.accent
                                    border.width: 1

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        spacing: 6

                                        Rectangle { width: 6; height: 6; radius: 3; color: Theme.accent }

                                        Text {
                                            text: modelData.name
                                            color: Theme.accent
                                            font.pixelSize: Theme.fsCaption
                                            font.family: Theme.fontFamily
                                            font.weight: Font.Bold
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                        Rectangle {
                                            width: 58; height: 18; radius: 3
                                            color: disconnMouse.containsMouse ? Theme.currentLine : "transparent"
                                            border.color: Theme.red
                                            border.width: 1

                                            Text {
                                                anchors.centerIn: parent
                                                text: "Disconnect"
                                                color: Theme.red
                                                font.pixelSize: Theme.fsCaption
                                                font.family: Theme.fontFamily
                                                font.weight: Font.Bold
                                            }

                                            MouseArea {
                                                id: disconnMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onClicked: BluetoothService.disconnectDevice(modelData.mac)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Available / Paired Devices Section
                        Text {
                            text: "Available and paired"
                            color: Theme.textMuted
                            font.pixelSize: Theme.fsCaption
                            font.family: Theme.fontFamily
                            font.weight: Font.Bold
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            Text {
                                text: "No available devices"
                                color: Theme.textMuted
                                font.pixelSize: Theme.fsCaption
                                font.family: Theme.fontFamily
                                font.italic: true
                                visible: BluetoothService.availableDevices.length === 0
                            }

                            Repeater {
                                model: BluetoothService.availableDevices

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 28
                                    radius: 5
                                    color: btDevMouse.containsMouse ? Theme.currentLine : "transparent"

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        spacing: 6

                                        Rectangle { width: 6; height: 6; radius: 3; color: Theme.textMuted }

                                        Text {
                                            text: modelData.name
                                            color: Theme.fg
                                            font.pixelSize: Theme.fsCaption
                                            font.family: Theme.fontFamily
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                        Rectangle {
                                            width: 46; height: 18; radius: 3
                                            color: connMouse.containsMouse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2) : "transparent"
                                            border.color: Theme.accent
                                            border.width: 1

                                            Text {
                                                anchors.centerIn: parent
                                                text: "Connect"
                                                color: Theme.accent
                                                font.pixelSize: Theme.fsCaption
                                                font.family: Theme.fontFamily
                                                font.weight: Font.Bold
                                            }

                                            MouseArea {
                                                id: connMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onClicked: BluetoothService.connectDevice(modelData.mac)
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: btDevMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Audio Control & Device Selector Detached Popup Window
    PopupWindow {
        id: audioMenu
        anchor.window: window
        anchor.rect.x: Theme.popupX(root, root.contentInset + audioBtn.x, audioBtn.width, implicitWidth, window.width, root.contentInset)
        anchor.rect.y: Theme.popupGap
        anchor.edges: Edges.Bottom
        visible: false
        color: "transparent"

        implicitWidth: audioGlass.implicitWidth
        implicitHeight: audioGlass.implicitHeight

        property real animProgress: 0.0

        NumberAnimation on animProgress {
            id: audioPopIn
            running: false
            to: 1.0
            duration: 220
            easing.type: Easing.OutBack
            easing.overshoot: 1.15
        }

        NumberAnimation on animProgress {
            id: audioPopOut
            running: false
            to: 0.0
            duration: 160
            easing.type: Easing.InQuad
            onFinished: audioMenu.visible = false
        }

Connections {
            target: PopupService
            function onAudioMenuOpenChanged() {
                if (PopupService.audioMenuOpen) {
                    audioPopOut.running = false
                    audioMenu.visible = true
                    audioPopIn.restart()
                } else if (audioMenu.visible) {
                    audioPopIn.running = false
                    audioPopOut.restart()
                }
            }
        }

        GlassPanel {
            id: audioGlass
            implicitWidth: 300
            implicitHeight: Math.min(480, audioCardLayout.implicitHeight + 24)
            anchors.fill: parent

            opacity: audioMenu.animProgress
            scale: 0.90 + 0.10 * audioMenu.animProgress
            transformOrigin: Item.TopRight

            ColumnLayout {
                id: audioCardLayout
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                // Card Header: Volume Title + Percentage
                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "Master volume"
                        color: Theme.fg
                        font.pixelSize: Theme.fsStrong
                        font.family: Theme.fontFamily
                        font.weight: Font.Bold
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: AudioService.volumeStr
                        color: Theme.accent
                        font.pixelSize: Theme.fsBody
                        font.family: Theme.fontFamily
                        font.weight: Font.Bold
                    }
                }

                // Volume Slider Track
                Item {
                    id: volSliderTrack
                    Layout.fillWidth: true
                    Layout.preferredHeight: 16

                    property bool isDragging: volSliderMouse.pressed

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width
                        height: 4
                        radius: 2
                        color: Theme.currentLine

                        Rectangle {
                            width: Math.max(4, parent.width * (AudioService.volume / 100.0))
                            height: parent.height
                            radius: 2
                            color: AudioService.isMuted ? Theme.red : Theme.accent
                        }
                    }

                    // Circle Slider Knob Handle
                    Rectangle {
                        width: volSliderMouse.containsMouse || volSliderTrack.isDragging ? 12 : 8
                        height: width
                        radius: width / 2
                        color: AudioService.isMuted ? Theme.red : Theme.accent
                        border.color: Theme.bg
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter
                        x: Math.max(0, Math.min(volSliderTrack.width - width, (volSliderTrack.width * (AudioService.volume / 100.0)) - (width / 2)))
                    }

                    MouseArea {
                        id: volSliderMouse
                        anchors.fill: parent
                        hoverEnabled: true

                        onPositionChanged: (mouse) => {
                            if (pressed) {
                                var ratio = Math.max(0.0, Math.min(1.0, mouse.x / width))
                                AudioService.setVolume(ratio * 100)
                            }
                        }
                        onPressed: (mouse) => {
                            var ratio = Math.max(0.0, Math.min(1.0, mouse.x / width))
                            AudioService.setVolume(ratio * 100)
                        }
                    }
                }

                // Mute Toggle Button
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.barCapsule
                    radius: 5
                    color: muteBtnMouse.containsMouse ? Theme.currentLine : (Theme.isDark ? Theme.currentLine : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.08))
                    border.color: Theme.currentLine
                    border.width: 1

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6

                        VolumeIcon {
                            volume: AudioService.volume
                            isMuted: AudioService.isMuted
                            width: 14
                            height: 14
                        }

                        Text {
                            text: AudioService.isMuted ? "Unmute Audio" : "Mute Audio"
                            color: AudioService.isMuted ? Theme.red : Theme.fg
                            font.pixelSize: Theme.fsCaption
                            font.family: Theme.fontFamily
                            font.weight: Font.Medium
                        }
                    }

                    MouseArea {
                        id: muteBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: AudioService.toggleMute()
                    }
                }

                // Solid Divider
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Theme.currentLine
                }

                Flickable {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(320, audioScrollCol.implicitHeight)
                    contentHeight: audioScrollCol.implicitHeight
                    clip: true

                    ColumnLayout {
                        id: audioScrollCol
                        width: parent.width
                        spacing: 8

                        // Output Devices Section
                        Text {
                            text: "Outputs"
                            color: Theme.textMuted
                            font.pixelSize: Theme.fsCaption
                            font.family: Theme.fontFamily
                            font.weight: Font.Bold
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            Repeater {
                                model: AudioService.sinks

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 24
                                    radius: 4
                                    color: modelData.isActive ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18) : (sinkItemMouse.containsMouse ? Theme.surface : "transparent")
                                    border.color: modelData.isActive ? Theme.accent : "transparent"
                                    border.width: 1

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 6
                                        anchors.rightMargin: 6
                                        spacing: 6

                                        Rectangle {
                                            width: 6; height: 6; radius: 3
                                            color: modelData.isActive ? Theme.accent : Theme.comment
                                        }

                                        Text {
                                            text: modelData.name
                                            color: modelData.isActive ? (Theme.isDark ? Theme.accent : Theme.fg) : Theme.fg
                                            font.pixelSize: Theme.fsCaption
                                            font.family: Theme.fontFamily
                                            font.weight: modelData.isActive ? Font.Bold : Font.Normal
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }

                                    MouseArea {
                                        id: sinkItemMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: AudioService.setDefaultDevice(modelData.id)
                                    }
                                }
                            }
                        }

                        // Solid Divider
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: Theme.currentLine
                        }

                        // Input Devices Section
                        Text {
                            text: "Inputs"
                            color: Theme.textMuted
                            font.pixelSize: Theme.fsCaption
                            font.family: Theme.fontFamily
                            font.weight: Font.Bold
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            Repeater {
                                model: AudioService.sources

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 24
                                    radius: 4
                                    color: modelData.isActive ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18) : (srcItemMouse.containsMouse ? Theme.surface : "transparent")
                                    border.color: modelData.isActive ? Theme.accent : "transparent"
                                    border.width: 1

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 6
                                        anchors.rightMargin: 6
                                        spacing: 6

                                        Rectangle {
                                            width: 6; height: 6; radius: 3
                                            color: modelData.isActive ? Theme.accent : Theme.comment
                                        }

                                        Text {
                                            text: modelData.name
                                            color: modelData.isActive ? Theme.accent : Theme.fg
                                            font.pixelSize: Theme.fsCaption
                                            font.family: Theme.fontFamily
                                            font.weight: modelData.isActive ? Font.Bold : Font.Normal
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }

                                    MouseArea {
                                        id: srcItemMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: AudioService.setDefaultDevice(modelData.id)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Screen & Backlight Brightness Control Detached Popup Window
    PopupWindow {
        id: brightMenu
        anchor.window: window
        anchor.rect.x: Theme.popupX(root, root.contentInset + brightBtn.x, brightBtn.width, implicitWidth, window.width, root.contentInset)
        anchor.rect.y: Theme.popupGap
        anchor.edges: Edges.Bottom
        visible: false
        color: "transparent"

        implicitWidth: brightGlass.implicitWidth
        implicitHeight: brightGlass.implicitHeight

        property real animProgress: 0.0

        NumberAnimation on animProgress {
            id: brightPopIn
            running: false
            to: 1.0
            duration: 220
            easing.type: Easing.OutBack
            easing.overshoot: 1.15
        }

        NumberAnimation on animProgress {
            id: brightPopOut
            running: false
            to: 0.0
            duration: 160
            easing.type: Easing.InQuad
            onFinished: brightMenu.visible = false
        }

        Connections {
            target: PopupService
            function onBrightnessMenuOpenChanged() {
                if (PopupService.brightnessMenuOpen) {
                    brightPopOut.running = false
                    brightMenu.visible = true
                    brightPopIn.restart()
                } else if (brightMenu.visible) {
                    brightPopIn.running = false
                    brightPopOut.restart()
                }
            }
        }

        GlassPanel {
            id: brightGlass
            implicitWidth: 300
            implicitHeight: Math.min(400, brightCardLayout.implicitHeight + 24)
            anchors.fill: parent

            opacity: brightMenu.animProgress
            scale: 0.90 + 0.10 * brightMenu.animProgress
            transformOrigin: Item.TopRight

            ColumnLayout {
                id: brightCardLayout
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12

                // Card Header: Title + Refresh Button
                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "Brightness"
                        color: Theme.fg
                        font.pixelSize: Theme.fsStrong
                        font.family: Theme.fontFamily
                        font.weight: Font.Bold
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        width: 20; height: 20; radius: 4
                        color: refreshBrightMouse.containsMouse ? Theme.currentLine : "transparent"
                        UiIcon {
                            anchors.centerIn: parent
                            name: "refresh-cw"
                            implicitWidth: 15
                            implicitHeight: 15
                        }
                        MouseArea {
                            id: refreshBrightMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: BrightnessService.scanDevices()
                        }
                    }
                }

                // Solid Divider
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Theme.currentLine
                }

                Flickable {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(300, brightScrollCol.implicitHeight)
                    contentHeight: brightScrollCol.implicitHeight
                    clip: true

                    ColumnLayout {
                        id: brightScrollCol
                        width: parent.width
                        spacing: 12

                        Repeater {
                            model: BrightnessService.devices

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                // Device Label & Percentage Readout
                                RowLayout {
                                    Layout.fillWidth: true

                                    BrightnessIcon {
                                        brightness: Math.round(devSliderTrack.currentPct)
                                        width: 14
                                        height: 14
                                    }

                                    Text {
                                        text: modelData.name
                                        color: Theme.fg
                                        font.pixelSize: Theme.fsCaption
                                        font.family: Theme.fontFamily
                                        font.weight: Font.Bold
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: Math.round(devSliderTrack.currentPct) + "%"
                                        color: modelData.type === "kbd" ? Theme.subAccent : Theme.accent
                                        font.pixelSize: Theme.fsCaption
                                        font.family: Theme.fontFamily
                                        font.weight: Font.Bold
                                    }
                                }

                                // Independent Device Brightness Slider Track
                                Item {
                                    id: devSliderTrack
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 16

                                    property real currentPct: modelData.brightness

                                    Component.onCompleted: {
                                        currentPct = modelData.brightness
                                    }

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: parent.width
                                        height: 4
                                        radius: 2
                                        color: Theme.currentLine

                                        Rectangle {
                                            width: Math.max(4, parent.width * (devSliderTrack.currentPct / 100.0))
                                            height: parent.height
                                            radius: 2
                                            color: modelData.type === "kbd" ? Theme.subAccent : Theme.accent
                                        }
                                    }

                                    // Slider Knob Handle
                                    Rectangle {
                                        width: devSliderMouse.containsMouse || devSliderMouse.pressed ? 12 : 8
                                        height: width
                                        radius: width / 2
                                        color: modelData.type === "kbd" ? Theme.subAccent : Theme.accent
                                        border.color: Theme.bg
                                        border.width: 1
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: Math.max(0, Math.min(devSliderTrack.width - width, (devSliderTrack.width * (devSliderTrack.currentPct / 100.0)) - (width / 2)))
                                    }

                                    MouseArea {
                                        id: devSliderMouse
                                        anchors.fill: parent
                                        hoverEnabled: true

                                        function updatePos(mx) {
                                            var ratio = Math.max(0.0, Math.min(1.0, mx / width))
                                            var val = Math.round(ratio * 100)
                                            devSliderTrack.currentPct = val
                                            BrightnessService.setDeviceBrightness(modelData.id, val)
                                        }

                                        onPressed: (mouse) => updatePos(mouse.x)
                                        onPositionChanged: (mouse) => {
                                            if (pressed) updatePos(mouse.x)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // External Storage Mount Control Detached Popup Window
    PopupWindow {
        id: mountMenu
        anchor.window: window
        anchor.rect.x: Theme.popupX(root, root.contentInset + mountBtn.x, mountBtn.width, implicitWidth, window.width, root.contentInset)
        anchor.rect.y: Theme.popupGap
        anchor.edges: Edges.Bottom
        visible: false
        color: "transparent"

        implicitWidth: mountGlass.implicitWidth
        implicitHeight: mountGlass.implicitHeight

        property real animProgress: 0.0

        NumberAnimation on animProgress {
            id: mountPopIn
            running: false
            to: 1.0
            duration: 220
            easing.type: Easing.OutBack
            easing.overshoot: 1.15
        }

        NumberAnimation on animProgress {
            id: mountPopOut
            running: false
            to: 0.0
            duration: 160
            easing.type: Easing.InQuad
            onFinished: mountMenu.visible = false
        }

        Connections {
            target: PopupService
            function onMountMenuOpenChanged() {
                if (PopupService.mountMenuOpen) {
                    mountPopOut.running = false
                    mountMenu.visible = true
                    mountPopIn.restart()
                } else if (mountMenu.visible) {
                    mountPopIn.running = false
                    mountPopOut.restart()
                }
            }
        }

        GlassPanel {
            id: mountGlass
            implicitWidth: 320
            implicitHeight: Math.min(480, mountCardLayout.implicitHeight + 24)
            anchors.fill: parent

            opacity: mountMenu.animProgress
            scale: 0.90 + 0.10 * mountMenu.animProgress
            transformOrigin: Item.TopRight

            ColumnLayout {
                id: mountCardLayout
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                // Header
                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "External storage"
                        color: Theme.fg
                        font.pixelSize: Theme.fsStrong
                        font.family: Theme.fontFamily
                        font.weight: Font.Bold
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        width: 20; height: 20; radius: 4
                        color: refreshMountMouse.containsMouse ? Theme.currentLine : "transparent"
                        UiIcon {
                            anchors.centerIn: parent
                            name: "refresh-cw"
                            implicitWidth: 15
                            implicitHeight: 15
                        }
                        MouseArea {
                            id: refreshMountMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: MountService.scanDevices()
                        }
                    }
                }

                // Solid Divider
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Theme.currentLine
                }

                Flickable {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(360, mountScrollCol.implicitHeight)
                    contentHeight: mountScrollCol.implicitHeight
                    clip: true

                    ColumnLayout {
                        id: mountScrollCol
                        width: parent.width
                        spacing: 8

                        Repeater {
                            model: MountService.devices

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: devItemCol.implicitHeight + 14
                                radius: 6
                                color: modelData.isMounted ? (Theme.isDark ? Qt.rgba(80/255, 250/255, 123/255, 0.1) : Qt.rgba(80/255, 250/255, 123/255, 0.18)) : Theme.surface
                                border.color: modelData.isMounted ? Theme.success : Theme.currentLine
                                border.width: 1

                                ColumnLayout {
                                    id: devItemCol
                                    anchors.fill: parent
                                    anchors.margins: 7
                                    spacing: 6

                                    // Device Title & Mounted Status Dot
                                    RowLayout {
                                        Layout.fillWidth: true

                                        Rectangle {
                                            width: 6; height: 6; radius: 3
                                            color: modelData.isMounted ? Theme.success : Theme.comment
                                        }

                                        Text {
                                            text: modelData.label + " (" + modelData.size + ")"
                                            color: modelData.isMounted ? Theme.success : Theme.fg
                                            font.pixelSize: Theme.fsCaption
                                            font.family: Theme.fontFamily
                                            font.weight: Font.Bold
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                        Text {
                                            text: modelData.isMounted ? "Mounted" : "Unmounted"
                                            color: modelData.isMounted ? Theme.success : Theme.comment
                                            font.pixelSize: Theme.fsCaption
                                            font.family: Theme.fontFamily
                                        }
                                    }

                                    Text {
                                        text: modelData.vendor
                                        color: Theme.textMuted
                                        font.pixelSize: Theme.fsCaption
                                        font.family: Theme.fontFamily
                                        elide: Text.ElideRight
                                        visible: modelData.vendor !== ""
                                    }

                                    // 3 Action Buttons: [ Mount / Unmount ] | [ Mount & Open ] | [ Auto-Mount ]
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 4

                                        // Button 1: Mount / Unmount
                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 22
                                            radius: 4
                                            color: mntBtnMouse.containsMouse ? Theme.currentLine : (Theme.isDark ? Theme.currentLine : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.08))
                                            border.color: Theme.currentLine
                                            border.width: 1

                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData.isMounted ? "Unmount" : "Mount"
                                                color: modelData.isMounted ? Theme.red : Theme.accent
                                                font.pixelSize: Theme.fsCaption
                                                font.family: Theme.fontFamily
                                                font.weight: Font.Bold
                                            }

                                            MouseArea {
                                                id: mntBtnMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onClicked: MountService.toggleMount(modelData.dev, modelData.isMounted)
                                            }
                                        }

                                        // Button 2: Mount & Open
                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 22
                                            radius: 4
                                            color: openBtnMouse.containsMouse ? Theme.currentLine : (Theme.isDark ? Theme.currentLine : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.08))
                                            border.color: Theme.currentLine
                                            border.width: 1

                                            Text {
                                                anchors.centerIn: parent
                                                text: "Mount and open"
                                                color: Theme.subAccent
                                                font.pixelSize: Theme.fsCaption
                                                font.family: Theme.fontFamily
                                                font.weight: Font.Bold
                                            }

                                            MouseArea {
                                                id: openBtnMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onClicked: MountService.mountAndOpen(modelData.dev)
                                            }
                                        }

                                        // Button 3: Auto-Mount Toggle
                                        Rectangle {
                                            id: autoToggleBtn
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 22
                                            radius: 4
                                            property bool autoOn: MountService.autoMountMap[modelData.dev] === true
                                            color: autoOn ? Qt.rgba(80/255, 250/255, 123/255, 0.2) : (autoBtnMouse.containsMouse ? Theme.currentLine : (Theme.isDark ? Theme.currentLine : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.08)))
                                            border.color: autoOn ? Theme.success : Theme.currentLine
                                            border.width: 1

                                            Text {
                                                anchors.centerIn: parent
                                                text: autoToggleBtn.autoOn ? "Auto: ON" : "Auto: OFF"
                                                color: autoToggleBtn.autoOn ? Theme.success : Theme.comment
                                                font.pixelSize: Theme.fsCaption
                                                font.family: Theme.fontFamily
                                                font.weight: Font.Bold
                                            }

                                            MouseArea {
                                                id: autoBtnMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onClicked: MountService.toggleAutoMount(modelData.dev)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Network Details Popup Window
    PopupWindow {
        id: netMenu
        anchor.window: window
        anchor.rect.x: Theme.popupX(root, root.contentInset + netBtn.x, netBtn.width, implicitWidth, window.width, root.contentInset)
        anchor.rect.y: Theme.popupGap
        anchor.edges: Edges.Bottom
        visible: false
        color: "transparent"

        implicitWidth: netGlass.implicitWidth
        implicitHeight: netGlass.implicitHeight

        property real animProgress: 0.0

        NumberAnimation on animProgress {
            id: netPopIn
            running: false
            to: 1.0
            duration: 220
            easing.type: Easing.OutBack
            easing.overshoot: 1.15
        }

        NumberAnimation on animProgress {
            id: netPopOut
            running: false
            to: 0.0
            duration: 160
            easing.type: Easing.InQuad
            onFinished: netMenu.visible = false
        }

        Connections {
            target: PopupService
            function onNetworkMenuOpenChanged() {
                if (PopupService.networkMenuOpen) {
                    netPopOut.running = false
                    netMenu.visible = true
                    netPopIn.restart()
                } else if (netMenu.visible) {
                    netPopIn.running = false
                    netPopOut.restart()
                }
            }
        }

        GlassPanel {
            id: netGlass
            implicitWidth: 300
            implicitHeight: NetworkService.isWifiPowered ? 240 : 80
            anchors.fill: parent

            opacity: netMenu.animProgress
            scale: 0.90 + 0.10 * netMenu.animProgress
            transformOrigin: Item.TopRight

            ColumnLayout {
                id: netCardLayout
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                // Header
                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "Wi-Fi networks"
                        color: Theme.fg
                        font.pixelSize: Theme.fsStrong
                        font.family: Theme.fontFamily
                        font.weight: Font.Bold
                    }

                    Item { Layout.fillWidth: true }

                    // Wi-Fi Power ON/OFF Toggle Button
                    Rectangle {
                        width: 50; height: 20; radius: 4
                        color: NetworkService.isWifiPowered ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18) : Qt.rgba(Theme.comment.r, Theme.comment.g, Theme.comment.b, 0.15)
                        border.color: NetworkService.isWifiPowered ? Theme.accent : Theme.currentLine
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: NetworkService.isWifiPowered ? "ON" : "OFF"
                            color: NetworkService.isWifiPowered ? Theme.accent : Theme.comment
                            font.pixelSize: Theme.fsCaption
                            font.family: Theme.fontFamily
                            font.weight: Font.Bold
                        }

                        MouseArea {
                            id: wifiPwrMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: NetworkService.toggleWifiPower()
                        }
                    }

                    Rectangle {
                        width: 20; height: 20; radius: 4
                        color: refreshNetMouse.containsMouse ? Theme.currentLine : "transparent"
                        UiIcon {
                            anchors.centerIn: parent
                            name: "refresh-cw"
                            implicitWidth: 15
                            implicitHeight: 15
                        }
                        MouseArea {
                            id: refreshNetMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: NetworkService.scanWifi()
                        }
                    }
                }

                // Solid Divider
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Theme.currentLine
                }

                // 1. Ethernet Card
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: ethColLayout.implicitHeight + 12
                    radius: 6
                    color: NetworkService.ethernetConnected ? (Theme.isDark ? Qt.rgba(80/255, 250/255, 123/255, 0.15) : Qt.rgba(80/255, 250/255, 123/255, 0.22)) : Theme.surface
                    border.color: NetworkService.ethernetConnected ? Theme.success : Theme.currentLine
                    border.width: 1

                    RowLayout {
                        id: ethColLayout
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 6

                        Rectangle { width: 6; height: 6; radius: 3; color: NetworkService.ethernetConnected ? Theme.green : Theme.comment }

                        Text {
                            text: "Ethernet (" + (NetworkService.ethernetConnected ? "Connected" : "Disconnected") + ")"
                            color: NetworkService.ethernetConnected ? Theme.green : Theme.fg
                            font.pixelSize: Theme.fsCaption
                            font.family: Theme.fontFamily
                            font.weight: NetworkService.ethernetConnected ? Font.Bold : Font.Normal
                            Layout.fillWidth: true
                        }
                    }
                }

                // Off State Banner
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: !NetworkService.isWifiPowered

                    Text {
                        anchors.centerIn: parent
                        text: "Wi-Fi is turned off"
                        color: Theme.textMuted
                        font.pixelSize: Theme.fsBody
                        font.family: Theme.fontFamily
                        font.italic: true
                    }
                }

                Flickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentHeight: netScrollCol.implicitHeight
                    clip: true
                    visible: NetworkService.isWifiPowered

                    ColumnLayout {
                        id: netScrollCol
                        width: parent.width
                        spacing: 3

                        Text {
                            text: "Wi-Fi is turned off"
                            color: Theme.textMuted
                            font.pixelSize: Theme.fsCaption
                            font.family: Theme.fontFamily
                            font.italic: true
                            visible: !NetworkService.isWifiPowered
                        }

                        Repeater {
                            model: NetworkService.networks

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: Theme.barCapsule
                                radius: 5
                                color: modelData.inUse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18) : (netItemMouse.containsMouse ? Theme.currentLine : "transparent")
                                border.color: modelData.inUse ? Theme.accent : "transparent"
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 6

                                    NetworkIcon {
                                        isConnected: true
                                        signalPercent: parseInt(modelData.signal)
                                        width: 14
                                        height: 14
                                    }

                                    Text {
                                        text: modelData.ssid
                                        color: modelData.inUse ? Theme.accent : Theme.fg
                                        font.pixelSize: Theme.fsCaption
                                        font.family: Theme.fontFamily
                                        font.weight: modelData.inUse ? Font.Bold : Font.Normal
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: modelData.inUse ? "Connected" : modelData.signal + "%"
                                        color: modelData.inUse ? Theme.accent : Theme.comment
                                        font.pixelSize: Theme.fsCaption
                                        font.family: Theme.fontFamily
                                    }
                                }

                                MouseArea {
                                    id: netItemMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        if (!modelData.inUse) {
                                            NetworkService.connectNetwork(modelData.ssid, "")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Battery & Power Control Detached Popup Window
    PopupWindow {
        id: batMenu
        anchor.window: window
        anchor.rect.x: Theme.popupX(root, root.contentInset + netBtn.x, netBtn.width, implicitWidth, window.width, root.contentInset)
        anchor.rect.y: Theme.popupGap
        anchor.edges: Edges.Bottom
        visible: false
        color: "transparent"

        implicitWidth: batGlass.implicitWidth
        implicitHeight: batGlass.implicitHeight

        property real animProgress: 0.0

        NumberAnimation on animProgress {
            id: batPopIn
            running: false
            to: 1.0
            duration: 220
            easing.type: Easing.OutBack
            easing.overshoot: 1.15
        }

        NumberAnimation on animProgress {
            id: batPopOut
            running: false
            to: 0.0
            duration: 160
            easing.type: Easing.InQuad
            onFinished: batMenu.visible = false
        }

        Connections {
            target: PopupService
            function onBatteryMenuOpenChanged() {
                if (PopupService.batteryMenuOpen) {
                    batPopOut.running = false
                    batMenu.visible = true
                    batPopIn.restart()
                } else if (batMenu.visible) {
                    batPopIn.running = false
                    batPopOut.restart()
                }
            }
        }

        GlassPanel {
            id: batGlass
            implicitWidth: 300
            implicitHeight: Math.min(450, batCardLayout.implicitHeight + 24)
            anchors.fill: parent

            opacity: batMenu.animProgress
            scale: 0.90 + 0.10 * batMenu.animProgress
            transformOrigin: Item.TopRight

            ColumnLayout {
                id: batCardLayout
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                // Header
                Text {
                    text: "Battery and power"
                    color: Theme.fg
                    font.pixelSize: Theme.fsStrong
                    font.family: Theme.fontFamily
                    font.weight: Font.Bold
                }

                // Battery Status & Health Stats Card
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 54
                    radius: 6
                    color: Theme.surface
                    border.color: Theme.currentLine
                    border.width: 1

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 10

                        BatteryIcon {
                            percentage: BatteryService.percentage
                            isCharging: BatteryService.isCharging
                            width: 22
                            height: 14
                            Layout.alignment: Qt.AlignVCenter
                        }

                        ColumnLayout {
                            spacing: 2
                            Layout.alignment: Qt.AlignVCenter

                            Text {
                                text: BatteryService.percentage + "% (" + (BatteryService.isCharging ? "Charging" : "Discharging") + ")"
                                color: Theme.fg
                                font.pixelSize: Theme.fsBody
                                font.family: Theme.fontFamily
                                font.weight: Font.Bold
                            }

                            Text {
                                text: "Battery Health: " + BatteryService.healthPercent + "%"
                                color: Theme.success
                                font.pixelSize: Theme.fsCaption
                                font.family: Theme.fontFamily
                            }
                        }
                    }
                }

                // Solid Divider
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Theme.currentLine
                }

                // Power Profile 3-Point Stepped Slider Section
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "Power profile"
                            color: Theme.textMuted
                            font.pixelSize: Theme.fsCaption
                            font.family: Theme.fontFamily
                            font.weight: Font.Bold
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: BatteryService.activeProfile === "power-saver" ? "Power saver" : (BatteryService.activeProfile === "performance" ? "Performance" : "Balanced")
                            color: BatteryService.activeProfile === "power-saver" ? Theme.success : (BatteryService.activeProfile === "performance" ? Theme.subAccent : Theme.accent)
                            font.pixelSize: Theme.fsCaption
                            font.family: Theme.fontFamily
                            font.weight: Font.Bold
                        }
                    }

                    // Stepped 3-Point Slider Container
                    Item {
                        id: profileSliderTrack
                        Layout.fillWidth: true
                        Layout.preferredHeight: 20

                        property int activeIndex: BatteryService.activeProfile === "power-saver" ? 0 : (BatteryService.activeProfile === "performance" ? 2 : 1)

                        // Track Line
                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width - 16
                            height: 4
                            radius: 2
                            color: Theme.currentLine

                            // Active Fill
                            Rectangle {
                                width: Math.max(0, (parent.width * (profileSliderTrack.activeIndex / 2.0)))
                                height: parent.height
                                radius: 2
                                color: profileSliderTrack.activeIndex === 0 ? Theme.green : (profileSliderTrack.activeIndex === 2 ? Theme.subAccent : Theme.accent)

                                Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                            }
                        }

                        // 3 Snap Point Dots
                        Repeater {
                            model: 3

                            Rectangle {
                                required property int index
                                width: 8
                                height: 8
                                radius: 4
                                color: index <= profileSliderTrack.activeIndex ? (profileSliderTrack.activeIndex === 0 ? Theme.green : (profileSliderTrack.activeIndex === 2 ? Theme.subAccent : Theme.accent)) : Theme.currentLine
                                anchors.verticalCenter: parent.verticalCenter
                                x: 8 + ((profileSliderTrack.width - 24) * (index / 2.0)) - 4

                                Behavior on color { ColorAnimation { duration: 120 } }
                            }
                        }

                        // Stepped Handle Knob
                        Rectangle {
                            id: profileKnob
                            width: 14
                            height: 14
                            radius: 7
                            color: profileSliderTrack.activeIndex === 0 ? Theme.green : (profileSliderTrack.activeIndex === 2 ? Theme.subAccent : Theme.accent)
                            border.color: Theme.bg
                            border.width: 2
                            anchors.verticalCenter: parent.verticalCenter
                            x: 8 + ((profileSliderTrack.width - 24) * (profileSliderTrack.activeIndex / 2.0)) - 7

                            Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }

                        // Mouse Drag / Snap Handler
                        MouseArea {
                            id: profileSliderMouse
                            anchors.fill: parent
                            hoverEnabled: true

                            function applySnap(mouseX) {
                                var ratio = Math.max(0.0, Math.min(1.0, (mouseX - 8) / (width - 24)))
                                var snapIdx = Math.round(ratio * 2.0)
                                var profiles = ["power-saver", "balanced", "performance"]
                                var targetProfile = profiles[snapIdx]
                                if (BatteryService.activeProfile !== targetProfile) {
                                    BatteryService.setProfile(targetProfile)
                                }
                            }

                            onPositionChanged: (mouse) => {
                                if (pressed) applySnap(mouse.x)
                            }
                            onPressed: (mouse) => {
                                applySnap(mouse.x)
                            }
                        }
                    }

                    // 3 Point Labels Row (Power Saver, Balanced, Performance)
                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "Power saver"
                            color: profileSliderTrack.activeIndex === 0 ? Theme.green : Theme.comment
                            font.pixelSize: Theme.fsCaption
                            font.family: Theme.fontFamily
                            font.weight: profileSliderTrack.activeIndex === 0 ? Font.Bold : Font.Normal
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: "Balanced"
                            color: profileSliderTrack.activeIndex === 1 ? Theme.accent : Theme.comment
                            font.pixelSize: Theme.fsCaption
                            font.family: Theme.fontFamily
                            font.weight: profileSliderTrack.activeIndex === 1 ? Font.Bold : Font.Normal
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: "Performance"
                            color: profileSliderTrack.activeIndex === 2 ? Theme.subAccent : Theme.comment
                            font.pixelSize: Theme.fsCaption
                            font.family: Theme.fontFamily
                            font.weight: profileSliderTrack.activeIndex === 2 ? Font.Bold : Font.Normal
                        }
                    }
                }

                // Solid Divider
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Theme.currentLine
                }

                // Block PC Sleep Toggle Button (Caffeine Mode)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    radius: 6
                    color: BatteryService.isSleepBlocked ? Qt.rgba(255/255, 184/255, 108/255, 0.2) : (sleepMouse.containsMouse ? Theme.currentLine : (Theme.isDark ? Theme.currentLine : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.08)))
                    border.color: BatteryService.isSleepBlocked ? Theme.orange : Theme.currentLine
                    border.width: 1

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8

                        Rectangle {
                            width: 8; height: 8; radius: 4
                            color: BatteryService.isSleepBlocked ? Theme.orange : Theme.comment
                        }

                        Text {
                            text: BatteryService.isSleepBlocked ? "Block PC Sleep: ACTIVE" : "Block PC from Falling Asleep"
                            color: BatteryService.isSleepBlocked ? Theme.orange : Theme.fg
                            font.pixelSize: Theme.fsCaption
                            font.family: Theme.fontFamily
                            font.weight: Font.Bold
                        }
                    }

                    MouseArea {
                        id: sleepMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: BatteryService.toggleSleepBlock()
                    }
                }
            }
        }
    }

    // Running Applications System Tray Context Menu Detached Popup Window
    PopupWindow {
        id: trayContextMenu
        anchor.window: window
        anchor.rect.x: Theme.popupX(root, root.contentInset + root.activeTrayX, 24, implicitWidth, window.width, root.contentInset)
        anchor.rect.y: Theme.popupGap
        anchor.edges: Edges.Bottom
        visible: false
        color: "transparent"

        implicitWidth: trayGlass.implicitWidth
        implicitHeight: trayGlass.implicitHeight

        property real animProgress: 0.0

        NumberAnimation on animProgress {
            id: trayPopIn
            running: false
            to: 1.0
            duration: 220
            easing.type: Easing.OutBack
            easing.overshoot: 1.15
        }

        NumberAnimation on animProgress {
            id: trayPopOut
            running: false
            to: 0.0
            duration: 160
            easing.type: Easing.InQuad
            onFinished: trayContextMenu.visible = false
        }

        Connections {
            target: PopupService
            function onTrayMenuOpenChanged() {
                if (PopupService.trayMenuOpen) {
                    trayPopOut.running = false
                    trayContextMenu.visible = true
                    trayPopIn.restart()
                } else if (trayContextMenu.visible) {
                    trayPopIn.running = false
                    trayPopOut.restart()
                }
            }
        }

        GlassPanel {
            id: trayGlass
            implicitWidth: 170
            implicitHeight: trayCol.implicitHeight + 16
            anchors.fill: parent

            opacity: trayContextMenu.animProgress
            scale: 0.90 + 0.10 * trayContextMenu.animProgress
            transformOrigin: Item.TopLeft

            ColumnLayout {
                id: trayCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 8
                spacing: 4

                // Sleek & Uniform App Header (Fixed 22px Height & Clean App Name)
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 22
                    spacing: 6

                    Item {
                        width: 14
                        height: 14
                        Layout.alignment: Qt.AlignVCenter

                        Image {
                            anchors.fill: parent
                            sourceSize.width: 14
                            sourceSize.height: 14
                            source: root.activeTrayItem ? (root.activeTrayItem.icon || "") : ""
                            fillMode: Image.PreserveAspectFit
                            visible: root.activeTrayItem ? (root.activeTrayItem.icon ? true : false) : false
                        }
                    }

                    Text {
                        text: root.getCleanAppName(root.activeTrayItem)
                        color: Theme.accent
                        font.pixelSize: Theme.fsCaption
                        font.family: Theme.fontFamily
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                    }
                }

                // Solid Divider underneath the app name
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Theme.currentLine
                    Layout.topMargin: 2
                    Layout.bottomMargin: 2
                }

                // Render Pure Native DBus App Menu Items (Pre-Cached Real Time Model)
                Repeater {
                    model: (root.activeTrayItem && root.activeTrayItem.hasMenu && root.activeTrayMenuOpener && root.activeTrayMenuOpener.children) ? root.activeTrayMenuOpener.children : 0

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        // Separator Item
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: Theme.currentLine
                            visible: modelData.isSeparator === true
                            Layout.topMargin: 2
                            Layout.bottomMargin: 2
                        }

                        // Normal Native Menu Item Button
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 22
                            radius: 4
                            visible: modelData.isSeparator !== true && (modelData.text ? true : false)
                            color: (menuItemMouse.containsMouse && modelData.enabled) ? Theme.currentLine : "transparent"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 6
                                anchors.rightMargin: 6
                                spacing: 6

                                Image {
                                    width: 12; height: 12
                                    sourceSize.width: 12; sourceSize.height: 12
                                    source: modelData.icon || ""
                                    visible: modelData.icon && modelData.icon !== ""
                                    fillMode: Image.PreserveAspectFit
                                }

                                Text {
                                    text: modelData.text ? modelData.text.replace(/&/g, "") : ""
                                    color: modelData.enabled ? Theme.fg : Theme.comment
                                    font.pixelSize: Theme.fsCaption
                                    font.family: Theme.fontFamily
                                    font.weight: modelData.enabled ? Font.Medium : Font.Normal
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            MouseArea {
                                id: menuItemMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: modelData.enabled
                                onClicked: {
                                    modelData.triggered()
                                    PopupService.closeAll()
                                }
                            }
                        }
                    }
                }

                // Fallback Menu Options for Wine/Proton/Native Apps without DBusMenu
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    visible: !(root.activeTrayMenuOpener && root.activeTrayMenuOpener.children && root.activeTrayMenuOpener.children.length > 0)

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 22
                        radius: 4
                        color: openActMouse.containsMouse ? Theme.currentLine : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 6
                            anchors.rightMargin: 6
                            spacing: 6

                            Text {
                                text: "Open window"
                                color: Theme.fg
                                font.pixelSize: Theme.fsCaption
                                font.family: Theme.fontFamily
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        MouseArea {
                            id: openActMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                if (root.activeTrayItem && root.activeTrayItem.activate) {
                                    root.activeTrayItem.activate(0, 0)
                                }
                                PopupService.closeAll()
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 22
                        radius: 4
                        color: secondaryActMouse.containsMouse ? Theme.currentLine : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 6
                            anchors.rightMargin: 6
                            spacing: 6

                            Text {
                                text: "App menu"
                                color: Theme.fg
                                font.pixelSize: Theme.fsCaption
                                font.family: Theme.fontFamily
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        MouseArea {
                            id: secondaryActMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                if (root.activeTrayItem) {
                                    if (root.activeTrayItem.contextMenu) root.activeTrayItem.contextMenu(0, 0)
                                    else if (root.activeTrayItem.secondaryActivate) root.activeTrayItem.secondaryActivate(0, 0)
                                }
                                PopupService.closeAll()
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: Theme.currentLine
                        Layout.topMargin: 2
                        Layout.bottomMargin: 2
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 22
                        radius: 4
                        color: quitActMouse.containsMouse ? Qt.rgba(255/255, 85/255, 85/255, 0.20) : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 6
                            anchors.rightMargin: 6
                            spacing: 6

                            Text {
                                text: "Close application"
                                color: quitActMouse.containsMouse ? Theme.danger : Theme.fg
                                font.pixelSize: Theme.fsCaption
                                font.family: Theme.fontFamily
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        MouseArea {
                            id: quitActMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                if (root.activeTrayItem) {
                                    let query = (root.activeTrayItem.id || root.activeTrayItem.title || "").toLowerCase()
                                    if (root.activeTrayItem.secondaryActivate) {
                                        root.activeTrayItem.secondaryActivate(0, 0)
                                    }
                                    if (query) {
                                        TaskService.closeApp(query)
                                    }
                                }
                                PopupService.closeAll()
                            }
                        }
                    }
                }
            }
        }
    }
}
