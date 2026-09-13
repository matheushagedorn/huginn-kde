import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import "../../components"
import "../../services"
import "../../theme"

// Full-screen Elegant Application Dashboard
PanelWindow {
    id: root

    screen: Quickshell.screens.find(s => s.name === "DP-2") || Quickshell.screens[0]
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.keyboardFocus: WlrLayershell.Exclusive

    visible: PopupService.appLauncherOpen && !LockscreenService.isLocked

    // Currently highlighted app index for keyboard navigation
    property int selectedIndex: 0

    // Math Evaluator Result
    property string mathResult: {
        let txt = searchField.text.trim()
        if (!txt || !/^[\d\s\+\-\*\/\(\)\.\%\^]+$/.test(txt) || !/\d/.test(txt)) return ""
        try {
            let clean = txt.replace(/\^/g, "**")
            let res = Function('"use strict"; return (' + clean + ')')()
            if (typeof res === "number" && !isNaN(res) && isFinite(res)) {
                return String(res)
            }
        } catch (e) {}
        return ""
    }

    // ── Open / Close animation state ─────────────────────────────────────
    property real openProgress: 0.0

    NumberAnimation on openProgress {
        id: openAnim
        running: false
        to: 1.0
        duration: 250
        easing.type: Easing.OutCubic
    }

    NumberAnimation on openProgress {
        id: closeAnim
        running: false
        to: 0.0
        duration: 180
        easing.type: Easing.InCubic
        onFinished: PopupService.appLauncherOpen = false
    }

    onVisibleChanged: {
        if (visible) {
            closeAnim.running = false
            openProgress = 0.0
            openAnim.restart()
            AppLauncherService.reset()
            AppLauncherService.reload()
            searchField.text = ""
            root.selectedIndex = 0
            Qt.callLater(() => {
                searchField.forceActiveFocus()
                if (appGrid.count > 0) appGrid.positionViewAtIndex(0, GridView.Contain)
            })
        }
    }

    function closeWithAnimation() {
        openAnim.running = false
        closeAnim.restart()
    }

    // ── Dim background ────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.72 * root.openProgress)

        // Click outside panel → close
        MouseArea {
            anchors.fill: parent
            onClicked: root.closeWithAnimation()
        }
    }

    // ── Center launcher card ─────────────────────────────────────────────
    Item {
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.88, 1080)
        height: Math.min(parent.height * 0.85, 740)

        focus: root.visible
        Keys.onEscapePressed: root.closeWithAnimation()

        opacity: Math.max(0.0, Math.min(1.0, root.openProgress))
        scale: 0.88 + 0.12 * root.openProgress

        // Ambient Background Accent Glow
        Rectangle {
            anchors.fill: parent
            anchors.margins: -12
            radius: 28
            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18 * root.openProgress)
        }

        // Panel glass card
        Rectangle {
            anchors.fill: parent
            radius: 20
            color: Theme.bg
            border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.28)
            border.width: 1

            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on border.color { ColorAnimation { duration: 150 } }

            // Stop clicks from falling through to dim background
            MouseArea { anchors.fill: parent; onClicked: {} }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 26
                spacing: 16

                // ── Header Bar: Search input & Status Pill ────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    // Search input container
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        radius: 12
                        color: Theme.surface
                        border.color: searchField.activeFocus
                                  ? Theme.accent
                                  : Qt.rgba(Theme.currentLine.r, Theme.currentLine.g, Theme.currentLine.b, 0.8)
                        border.width: searchField.activeFocus ? 2 : 1

                        Behavior on border.color { ColorAnimation { duration: 120 } }
                        Behavior on border.width { NumberAnimation { duration: 120 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            spacing: 12

                            // Search icon (magnifier)
                            Item {
                                width: 18; height: 18
                                Layout.alignment: Qt.AlignVCenter

                                Canvas {
                                    id: searchIcon
                                    anchors.fill: parent
                                    onPaint: {
                                        let ctx = getContext("2d")
                                        ctx.clearRect(0, 0, width, height)
                                        ctx.strokeStyle = searchField.activeFocus ? Theme.accent : Theme.comment
                                        ctx.lineWidth = 2.0
                                        ctx.beginPath()
                                        ctx.arc(7.5, 7.5, 5.5, 0, Math.PI * 2)
                                        ctx.stroke()
                                        ctx.beginPath()
                                        ctx.moveTo(11.5, 11.5)
                                        ctx.lineTo(16.5, 16.5)
                                        ctx.stroke()
                                    }
                                    Component.onCompleted: requestPaint()
                                    Connections {
                                        target: searchField
                                        function onActiveFocusChanged() { searchIcon.requestPaint() }
                                    }
                                }
                            }

                            TextInput {
                                id: searchField
                                focus: true
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                color: Theme.fg
                                font.pixelSize: 15
                                font.family: "Inter"
                                selectionColor: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35)
                                selectedTextColor: Theme.fg
                                clip: true

                                // Placeholder
                                Text {
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    text: "Search apps, calculate, or type commands..."
                                    color: Theme.comment
                                    font.pixelSize: 15
                                    font.family: "Inter"
                                    visible: !searchField.text && !searchField.activeFocus
                                }

                                onTextChanged: {
                                    AppLauncherService.searchQuery = text
                                    root.selectedIndex = 0
                                    if (appGrid.count > 0) appGrid.positionViewAtIndex(0, GridView.Contain)
                                }

                                Keys.onPressed: (event) => {
                                    let count = AppLauncherService.filteredApps.length
                                    if (count === 0) return

                                    let cols = Math.max(1, Math.floor(appGrid.width / appGrid.cellWidth))

                                    if (event.key === Qt.Key_Right) {
                                        root.selectedIndex = Math.min(count - 1, root.selectedIndex + 1)
                                        appGrid.positionViewAtIndex(root.selectedIndex, GridView.Contain)
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_Left) {
                                        root.selectedIndex = Math.max(0, root.selectedIndex - 1)
                                        appGrid.positionViewAtIndex(root.selectedIndex, GridView.Contain)
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_Down) {
                                        root.selectedIndex = Math.min(count - 1, root.selectedIndex + cols)
                                        appGrid.positionViewAtIndex(root.selectedIndex, GridView.Contain)
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_Up) {
                                        root.selectedIndex = Math.max(0, root.selectedIndex - cols)
                                        appGrid.positionViewAtIndex(root.selectedIndex, GridView.Contain)
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                        if (root.selectedIndex >= 0 && root.selectedIndex < count) {
                                            AppLauncherService.launch(AppLauncherService.filteredApps[root.selectedIndex])
                                            root.closeWithAnimation()
                                        }
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_Escape) {
                                        root.closeWithAnimation()
                                        event.accepted = true
                                    }
                                }
                            }

                            // Clear button
                            Rectangle {
                                width: 20; height: 20
                                radius: 10
                                color: clearMouse.containsMouse ? Theme.currentLine : "transparent"
                                visible: searchField.text.length > 0
                                Layout.alignment: Qt.AlignVCenter

                                Behavior on color { ColorAnimation { duration: 100 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "✕"
                                    color: Theme.comment
                                    font.pixelSize: 11
                                }

                                MouseArea {
                                    id: clearMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        searchField.text = ""
                                        searchField.forceActiveFocus()
                                    }
                                }
                            }
                        }
                    }

                    // Result count badge
                    Rectangle {
                        implicitWidth: resultCountText.implicitWidth + 20
                        implicitHeight: 48
                        radius: 12
                        color: Theme.surface
                        border.color: Theme.currentLine
                        border.width: 1

                        Text {
                            id: resultCountText
                            anchors.centerIn: parent
                            text: appGrid.count + " app" + (appGrid.count !== 1 ? "s" : "")
                            color: Theme.accent
                            font.pixelSize: 12
                            font.family: "Inter"
                            font.weight: Font.Bold
                        }
                    }
                }

                // ── Math & Calculator Result Card ──────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 52
                    radius: 12
                    color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                    border.color: Theme.accent
                    border.width: 1.5
                    visible: root.mathResult !== ""

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 12

                        Text { text: "🧮"; font.pixelSize: 18 }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                text: searchField.text + " ="
                                color: Theme.comment
                                font.pixelSize: 11
                            }

                            Text {
                                text: root.mathResult
                                color: Theme.accent
                                font.pixelSize: 18
                                font.weight: Font.Bold
                            }
                        }

                        Rectangle {
                            implicitWidth: copyMathBtnText.implicitWidth + 14
                            implicitHeight: 26
                            radius: 6
                            color: copyMathMouse.containsMouse ? Theme.accent : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.3)

                            Text {
                                id: copyMathBtnText
                                anchors.centerIn: parent
                                text: "Copy Result"
                                color: copyMathMouse.containsMouse ? (Theme.isDark ? Theme.bg : "#ffffff") : Theme.fg
                                font.pixelSize: 10
                                font.weight: Font.Bold
                            }

                            MouseArea {
                                id: copyMathMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    Quickshell.execDetached(["wl-copy", root.mathResult])
                                }
                            }
                        }
                    }
                }

                // ── Category Filter Pills ──────────────────────────────────
                ListView {
                    id: categoryList
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    orientation: ListView.Horizontal
                    model: AppLauncherService.categories
                    spacing: 8
                    clip: true

                    ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AlwaysOff }

                    delegate: Rectangle {
                        property bool isActive: modelData === AppLauncherService.activeCategory
                        width: catLabel.implicitWidth + 24
                        height: 32
                        radius: 10
                        color: isActive
                               ? Theme.accent
                               : (catMouse.containsMouse ? Theme.currentLine : Theme.surface)
                        border.color: isActive
                                      ? Theme.accent
                                      : (catMouse.containsMouse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.3) : Theme.currentLine)
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        Text {
                            id: catLabel
                            anchors.centerIn: parent
                            text: modelData
                            color: isActive ? (Theme.isDark ? Theme.bg : "#ffffff") : (catMouse.containsMouse ? Theme.accent : Theme.fg)
                            font.pixelSize: 12
                            font.family: "Inter"
                            font.weight: isActive ? Font.Bold : Font.Medium

                            Behavior on color { ColorAnimation { duration: 120 } }
                        }

                        MouseArea {
                            id: catMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                AppLauncherService.activeCategory = modelData
                                root.selectedIndex = 0
                            }
                        }
                    }
                }

                // ── Application Grid ──────────────────────────────────────
                GridView {
                    id: appGrid
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    model: AppLauncherService.filteredApps
                    cellWidth: Math.floor(width / Math.max(1, Math.floor(width / 128)))
                    cellHeight: 116

                    ScrollBar.vertical: ScrollBar {
                        id: gridScroll
                        policy: ScrollBar.AsNeeded
                        contentItem: Rectangle {
                            implicitWidth: 4
                            radius: 2
                            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.4)
                        }
                        background: Rectangle { color: "transparent" }
                    }

                    // Empty state
                    Text {
                        anchors.centerIn: parent
                        visible: appGrid.count === 0
                        text: "No applications found"
                        color: Theme.comment
                        font.pixelSize: 14
                        font.family: "Inter"
                    }

                    delegate: Item {
                        width: appGrid.cellWidth
                        height: appGrid.cellHeight

                        property var app: modelData
                        property bool isSelected: index === root.selectedIndex

                        Rectangle {
                            id: appTile
                            anchors.fill: parent
                            anchors.margins: 4
                            radius: 14
                            color: isSelected
                                   ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22)
                                   : (tileMouse.containsMouse ? Theme.surface : "transparent")
                            border.color: isSelected ? Theme.accent : (tileMouse.containsMouse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.4) : "transparent")
                            border.width: isSelected ? 1.5 : (tileMouse.containsMouse ? 1 : 0)

                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on border.color { ColorAnimation { duration: 120 } }

                            scale: tileMouse.pressed ? 0.95 : (isSelected || tileMouse.containsMouse ? 1.05 : 1.0)
                            Behavior on scale {
                                NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                            }

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 8
                                width: parent.width - 12

                                // App icon container
                                Item {
                                    Layout.alignment: Qt.AlignHCenter
                                    width: 52
                                    height: 52

                                    Image {
                                        id: appIcon
                                        anchors.fill: parent
                                        sourceSize.width: 52
                                        sourceSize.height: 52
                                        fillMode: Image.PreserveAspectFit
                                        source: resolveIcon(app.icon)
                                        smooth: true
                                        asynchronous: true

                                        visible: status === Image.Ready

                                        onStatusChanged: {
                                            if (status === Image.Error && source !== resolveIcon("")) {
                                                source = resolveIcon("")
                                            }
                                        }
                                    }

                                    // Fallback badge container if icon fails or is unavailable
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 12
                                        color: Theme.surface
                                        border.color: Theme.currentLine
                                        border.width: 1
                                        visible: appIcon.status !== Image.Ready

                                        Text {
                                            anchors.centerIn: parent
                                            text: app.name ? app.name.charAt(0).toUpperCase() : "A"
                                            color: Theme.accent
                                            font.pixelSize: 18
                                            font.weight: Font.Bold
                                        }
                                    }
                                }

                                // App name
                                Text {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignHCenter
                                    text: app.name
                                    color: isSelected ? Theme.accent : Theme.fg
                                    font.pixelSize: 11
                                    font.family: "Inter"
                                    font.weight: isSelected ? Font.Bold : Font.Medium
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                    maximumLineCount: 2
                                    wrapMode: Text.WordWrap

                                    Behavior on color { ColorAnimation { duration: 100 } }
                                }
                            }

                            MouseArea {
                                id: tileMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onEntered: root.selectedIndex = index
                                onClicked: {
                                    root.selectedIndex = index
                                    AppLauncherService.launch(app)
                                    root.closeWithAnimation()
                                }
                            }
                        }
                    }
                }

                // ── Footer: Keyboard Shortcuts Hint ───────────────────────
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 16

                    Text {
                        text: "↑↓←→ Navigate"
                        color: Theme.comment
                        font.pixelSize: 10
                        font.family: "Inter"
                    }

                    Text {
                        text: "•"
                        color: Theme.comment
                        font.pixelSize: 10
                    }

                    Text {
                        text: "↵ Launch"
                        color: Theme.comment
                        font.pixelSize: 10
                        font.family: "Inter"
                    }

                    Text {
                        text: "•"
                        color: Theme.comment
                        font.pixelSize: 10
                    }

                    Text {
                        text: "Esc Close"
                        color: Theme.comment
                        font.pixelSize: 10
                        font.family: "Inter"
                    }
                }
            }
        }
    }

    // ── Icon resolution helper ────────────────────────────────────────────
    function resolveIcon(iconName) {
        if (!iconName || iconName === "") {
            return AppLauncherService.fallbackIconPath ? "file://" + AppLauncherService.fallbackIconPath : ""
        }
        if (iconName.startsWith("/")) return "file://" + iconName

        let lower = iconName.toLowerCase().trim()
        if (AppLauncherService.iconMap && AppLauncherService.iconMap[lower]) {
            let mapped = AppLauncherService.iconMap[lower]
            return mapped.startsWith("/") ? "file://" + mapped : mapped
        }

        return AppLauncherService.fallbackIconPath ? "file://" + AppLauncherService.fallbackIconPath : ""
    }
}
