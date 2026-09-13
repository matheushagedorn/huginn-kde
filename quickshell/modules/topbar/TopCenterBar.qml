import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../components"
import "../../services"
import "../../theme"

GlassPanel {
    id: root
    implicitWidth: mainLayout.implicitWidth + 24
    implicitHeight: 36

    RowLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 8

        // Live Weather Capsule Snippet
        Rectangle {
            id: weatherBtn
            Layout.preferredWidth: weatherRow.implicitWidth + 14
            Layout.preferredHeight: 26
            radius: 7
            color: weatherMouse.containsMouse ? Theme.currentLine : "transparent"
            border.color: weatherMouse.containsMouse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25) : "transparent"
            border.width: 1

            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on border.color { ColorAnimation { duration: 120 } }

            RowLayout {
                id: weatherRow
                anchors.centerIn: parent
                spacing: 5

                Text {
                    text: WeatherService.getWeatherIcon(WeatherService.weatherCode)
                    font.pixelSize: 12
                }

                Text {
                    text: WeatherService.currentTempStr
                    color: Theme.fg
                    font.pixelSize: 11
                    font.weight: Font.Medium
                }
            }

            MouseArea {
                id: weatherMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: PopupService.toggleWeather()
            }
        }

        // Minimal Divider Line
        Rectangle {
            Layout.preferredWidth: 1
            Layout.preferredHeight: 14
            color: Theme.separator
        }

        // Time & Date Section with Bell / DND Icon on the left
        Rectangle {
            id: timeBtn
            Layout.preferredWidth: timeRow.implicitWidth + 18
            Layout.preferredHeight: 26
            radius: 8
            color: timeMouse.containsMouse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.20) : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.10)
            border.color: timeMouse.containsMouse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.65) : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.24)
            border.width: 1

            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on border.color { ColorAnimation { duration: 120 } }

            RowLayout {
                id: timeRow
                anchors.centerIn: parent
                spacing: 6

                // Bell / DND Icon (Left side of Time & Date)
                BellIcon {
                    isDnd: NotificationService.isDnd
                    implicitWidth: 14
                    implicitHeight: 14
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    text: DateTimeService.timeStr
                    color: Theme.fg
                    font.pixelSize: 11
                    font.weight: Font.Bold
                }

                Text {
                    text: "•"
                    color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.6)
                    font.pixelSize: 10
                }

                Text {
                    text: DateTimeService.dateStr
                    color: Theme.comment
                    font.pixelSize: 11
                    font.weight: Font.Medium
                }
            }

            MouseArea {
                id: timeMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: PopupService.toggleCalendar()
            }
        }

        // Minimal Divider Line
        Rectangle {
            Layout.preferredWidth: 1
            Layout.preferredHeight: 14
            color: Theme.separator
        }

        // MPRIS Media Player Snippet
        Rectangle {
            id: mediaBtn
            Layout.preferredWidth: mediaRow.implicitWidth + 14
            Layout.preferredHeight: 26
            radius: 7
            color: mediaMouse.containsMouse ? Theme.currentLine : "transparent"
            border.color: mediaMouse.containsMouse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25) : "transparent"
            border.width: 1

            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on border.color { ColorAnimation { duration: 120 } }

            RowLayout {
                id: mediaRow
                anchors.centerIn: parent
                spacing: 6

                // Static 1:1 Album Cover Disc (Top Bar Thumbnail)
                AlbumCover {
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                    implicitWidth: 20
                    implicitHeight: 20
                    artUrl: MediaService.artUrl
                }

                // Active Source Badge Pill (Firefox, Spotify, VLC, etc.)
                Rectangle {
                    visible: MediaService.hasPlayer && MediaService.playerDisplayName !== ""
                    implicitWidth: sourceText.implicitWidth + 10
                    implicitHeight: 16
                    radius: 4
                    color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15)
                    border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.4)
                    border.width: 1

                    Text {
                        id: sourceText
                        anchors.centerIn: parent
                        text: MediaService.playerDisplayName
                        color: Theme.accent
                        font.pixelSize: 9
                        font.weight: Font.Bold
                    }
                }

                // Scrolling Marquee Track Title
                MarqueeText {
                    id: marqueeTitle
                    implicitWidth: 140
                    implicitHeight: 16
                    text: MediaService.hasPlayer && MediaService.title ? MediaService.title + (MediaService.artist ? " - " + MediaService.artist : "") : "No Media Playing"
                    color: MediaService.hasPlayer ? Theme.fg : Theme.comment
                    font.pixelSize: 11
                    font.weight: Font.Medium
                }
            }

            MouseArea {
                id: mediaMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: PopupService.toggleMedia()
            }
        }
    }

    // Detached Full Monthly Calendar Popup Card
    PopupWindow {
        id: timeMenu
        anchor.window: window
        anchor.rect.x: root.x + (root.width / 2) - (implicitWidth / 2)
        anchor.rect.y: 42
        anchor.edges: Edges.Bottom
        visible: false
        color: "transparent"

        implicitWidth: calendarGlass.implicitWidth
        implicitHeight: calendarGlass.implicitHeight

        property real animProgress: 0.0

        NumberAnimation on animProgress {
            id: calPopIn
            running: false
            to: 1.0
            duration: 220
            easing.type: Easing.OutBack
            easing.overshoot: 1.15
        }

        NumberAnimation on animProgress {
            id: calPopOut
            running: false
            to: 0.0
            duration: 160
            easing.type: Easing.InQuad
            onFinished: timeMenu.visible = false
        }

        Connections {
            target: PopupService
            function onCalendarMenuOpenChanged() {
                if (PopupService.calendarMenuOpen) {
                    calPopOut.running = false
                    timeMenu.visible = true
                    calPopIn.restart()
                } else if (timeMenu.visible) {
                    calPopIn.running = false
                    calPopOut.restart()
                }
            }
        }

        GlassPanel {
            id: calendarGlass
            implicitWidth: calWidget.implicitWidth + 24
            implicitHeight: calWidget.implicitHeight + 20
            anchors.fill: parent

            opacity: timeMenu.animProgress
            scale: 0.90 + 0.10 * timeMenu.animProgress
            transformOrigin: Item.Top

            CalendarWidget {
                id: calWidget
                anchors.centerIn: parent
            }
        }
    }

    // Detached MPRIS Player Card Popup Window
    PopupWindow {
        id: mediaMenu
        anchor.window: window
        anchor.rect.x: root.x + (root.width / 2) - (implicitWidth / 2)
        anchor.rect.y: 42
        anchor.edges: Edges.Bottom
        visible: false
        color: "transparent"

        implicitWidth: playerGlass.implicitWidth
        implicitHeight: playerGlass.implicitHeight

        property real animProgress: 0.0

        NumberAnimation on animProgress {
            id: mediaPopIn
            running: false
            to: 1.0
            duration: 220
            easing.type: Easing.OutBack
            easing.overshoot: 1.15
        }

        NumberAnimation on animProgress {
            id: mediaPopOut
            running: false
            to: 0.0
            duration: 160
            easing.type: Easing.InQuad
            onFinished: mediaMenu.visible = false
        }

        Connections {
            target: PopupService
            function onMediaMenuOpenChanged() {
                if (PopupService.mediaMenuOpen) {
                    mediaPopOut.running = false
                    mediaMenu.visible = true
                    mediaPopIn.restart()
                } else if (mediaMenu.visible) {
                    mediaPopIn.running = false
                    mediaPopOut.restart()
                }
            }
        }

        GlassPanel {
            id: playerGlass
            implicitWidth: 240
            implicitHeight: playerLayout.implicitHeight + 24
            anchors.fill: parent

            opacity: mediaMenu.animProgress
            scale: 0.90 + 0.10 * mediaMenu.animProgress
            transformOrigin: Item.Top

            // Full-Card Translucent Ambient Spectrum Visualizer Background (Centered & Full Panel Height)
            Item {
                id: bgVisualizer
                anchors.fill: parent
                visible: MediaService.hasPlayer
                clip: true

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    height: parent.height
                    spacing: Math.max(2, (parent.width - 24 - (28 * 4)) / 27)

                    Repeater {
                        model: 28

                        Rectangle {
                            width: 4
                            height: {
                                let dummy = CavaService.tick;
                                if (MediaService.status !== "Playing") return 6;
                                let rawVal = (CavaService.values && CavaService.values.length > index) ? CavaService.values[index] : 0;
                                let ratio = rawVal / 100.0;
                                return Math.max(6, Math.min(bgVisualizer.height, ratio * bgVisualizer.height));
                            }
                            radius: 2
                            color: MediaService.status === "Playing" 
                                ? Qt.rgba(Theme.pink.r, Theme.pink.g, Theme.pink.b, 0.22) 
                                : Qt.rgba(Theme.comment.r, Theme.comment.g, Theme.comment.b, 0.06)

                            anchors.bottom: parent.bottom

                            Behavior on height { NumberAnimation { duration: 40; easing.type: Easing.OutQuad } }
                        }
                    }
                }
            }

            ColumnLayout {
                id: playerLayout
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                // Source Header Badge
                Rectangle {
                    visible: MediaService.hasPlayer && MediaService.playerDisplayName !== ""
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: popupSourceRow.implicitWidth + 12
                    implicitHeight: 18
                    radius: 5
                    color: Theme.currentLine
                    border.color: Theme.currentLine
                    border.width: 1

                    RowLayout {
                        id: popupSourceRow
                        anchors.centerIn: parent
                        spacing: 5

                        Rectangle {
                            width: 5; height: 5; radius: 2.5
                            color: MediaService.status === "Playing" ? Theme.green : Theme.yellow
                        }

                        Text {
                            text: MediaService.playerDisplayName.toUpperCase()
                            color: Theme.fg
                            font.pixelSize: 9
                            font.weight: Font.Bold
                        }
                    }
                }

                // Static Album Cover Disc (64x64)
                AlbumCover {
                    Layout.preferredWidth: 64
                    Layout.preferredHeight: 64
                    implicitWidth: 64
                    implicitHeight: 64
                    artUrl: MediaService.artUrl
                    Layout.alignment: Qt.AlignHCenter
                }

                // Track Title
                Text {
                    text: MediaService.hasPlayer && MediaService.title ? MediaService.title : "No Media Playing"
                    color: Theme.fg
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }

                // Artist
                Text {
                    text: MediaService.artist !== "" ? MediaService.artist : "Unknown Artist"
                    color: Theme.comment
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }

                // Smooth Progress Bar Section with Circle Scrub Handle
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    visible: MediaService.hasPlayer

                    Item {
                        id: progressTrackContainer
                        Layout.fillWidth: true
                        Layout.preferredHeight: 14

                        property bool isDragging: seekMouse.pressed
                        property real dragRatio: 0.0

                        // Track Background
                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width
                            height: 4
                            radius: 2
                            color: Theme.currentLine

                            // Active Fill
                            Rectangle {
                                width: Math.max(4, parent.width * (progressTrackContainer.isDragging ? progressTrackContainer.dragRatio : MediaService.progress))
                                height: parent.height
                                radius: 2
                                color: Theme.pink

                                Behavior on width {
                                    enabled: !progressTrackContainer.isDragging
                                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                                }
                            }
                        }

                        // Draggable Circle Knob Handle
                        Rectangle {
                            id: knobHandle
                            width: seekMouse.containsMouse || progressTrackContainer.isDragging ? 12 : 8
                            height: width
                            radius: width / 2
                            color: Theme.pink
                            border.color: Theme.bg
                            border.width: 1
                            anchors.verticalCenter: parent.verticalCenter
                            x: Math.max(0, Math.min(progressTrackContainer.width - width, (progressTrackContainer.width * (progressTrackContainer.isDragging ? progressTrackContainer.dragRatio : MediaService.progress)) - (width / 2)))

                            Behavior on width { NumberAnimation { duration: 100 } }
                            Behavior on x {
                                enabled: !progressTrackContainer.isDragging
                                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                            }
                        }

                        // Mouse Scrub & Seek Handler
                        MouseArea {
                            id: seekMouse
                            anchors.fill: parent
                            hoverEnabled: true

                            onPositionChanged: (mouse) => {
                                if (pressed) {
                                    progressTrackContainer.dragRatio = Math.max(0.0, Math.min(1.0, mouse.x / width))
                                }
                            }
                            onPressed: (mouse) => {
                                progressTrackContainer.dragRatio = Math.max(0.0, Math.min(1.0, mouse.x / width))
                            }
                            onReleased: (mouse) => {
                                var ratio = Math.max(0.0, Math.min(1.0, mouse.x / width))
                                progressTrackContainer.dragRatio = ratio
                                MediaService.seek(ratio * MediaService.length)
                            }
                        }
                    }

                    // Timestamps Row
                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: MediaService.positionStr
                            color: Theme.comment
                            font.pixelSize: 10
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: MediaService.lengthStr
                            color: Theme.comment
                            font.pixelSize: 10
                        }
                    }
                }

                // Playback Controls Row
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 14

                    // Previous Button
                    Rectangle {
                        width: 30
                        height: 30
                        radius: 6
                        color: prevMouse.containsMouse ? Theme.currentLine : "transparent"

                        Behavior on color { ColorAnimation { duration: 100 } }

                        MediaIcon {
                            iconType: "prev"
                            color: prevMouse.containsMouse ? Theme.fg : Theme.comment
                            anchors.centerIn: parent
                            implicitWidth: 12
                            implicitHeight: 12
                        }

                        MouseArea {
                            id: prevMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: MediaService.previous()
                        }
                    }

                    // Play/Pause Button
                    Rectangle {
                        width: 34
                        height: 34
                        radius: 8
                        color: playMouse.containsMouse ? Theme.subAccent : Theme.accent

                        Behavior on color { ColorAnimation { duration: 100 } }

                        MediaIcon {
                            iconType: MediaService.status === "Playing" ? "pause" : "play"
                            color: Theme.bg
                            anchors.centerIn: parent
                            implicitWidth: 14
                            implicitHeight: 14
                        }

                        MouseArea {
                            id: playMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: MediaService.playPause()
                        }
                    }

                    // Next Button
                    Rectangle {
                        width: 30
                        height: 30
                        radius: 6
                        color: nextMouse.containsMouse ? Theme.currentLine : "transparent"

                        Behavior on color { ColorAnimation { duration: 100 } }

                        MediaIcon {
                            iconType: "next"
                            color: nextMouse.containsMouse ? Theme.fg : Theme.comment
                            anchors.centerIn: parent
                            implicitWidth: 12
                            implicitHeight: 12
                        }

                        MouseArea {
                            id: nextMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: MediaService.next()
                        }
                    }
                }
            }
        }
    }

    // Detached 5-Day Weather Forecast Popover Window
    PopupWindow {
        id: weatherPopup
        anchor.window: window
        anchor.rect.x: Math.round(root.x + weatherBtn.x)
        anchor.rect.y: 42
        anchor.edges: Edges.Bottom | Edges.Left
        visible: false
        color: "transparent"

        implicitWidth: weatherGlass.implicitWidth
        implicitHeight: weatherGlass.implicitHeight

        property real animProgress: 0.0

        NumberAnimation on animProgress {
            id: weatherPopIn
            running: false
            to: 1.0
            duration: 220
            easing.type: Easing.OutBack
            easing.overshoot: 1.15
        }

        NumberAnimation on animProgress {
            id: weatherPopOut
            running: false
            to: 0.0
            duration: 160
            easing.type: Easing.InQuad
            onFinished: weatherPopup.visible = false
        }

        Connections {
            target: PopupService
            function onWeatherMenuOpenChanged() {
                if (PopupService.weatherMenuOpen) {
                    weatherPopOut.running = false
                    weatherPopup.visible = true
                    weatherPopIn.restart()
                } else if (weatherPopup.visible) {
                    weatherPopIn.running = false
                    weatherPopOut.restart()
                }
            }
        }

        GlassPanel {
            id: weatherGlass
            implicitWidth: 260
            implicitHeight: weatherCol.implicitHeight + 24
            anchors.fill: parent

            opacity: weatherPopup.animProgress
            scale: 0.90 + 0.10 * weatherPopup.animProgress
            transformOrigin: Item.TopLeft

            ColumnLayout {
                id: weatherCol
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                // City & Current Condition Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: WeatherService.getWeatherIcon(WeatherService.weatherCode)
                        font.pixelSize: 24
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: WeatherService.city
                            color: Theme.fg
                            font.pixelSize: 13
                            font.weight: Font.Bold
                        }

                        Text {
                            text: WeatherService.condition + " • " + WeatherService.currentTempStr
                            color: Theme.comment
                            font.pixelSize: 11
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Theme.currentLine
                }

                // 5-Day Forecast Grid
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: WeatherService.forecastData

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 58
                            radius: 8
                            color: Theme.surface
                            border.color: Theme.currentLine
                            border.width: 1

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 2

                                Text {
                                    text: modelData.day
                                    color: Theme.comment
                                    font.pixelSize: 9
                                    font.weight: Font.Medium
                                    Layout.alignment: Qt.AlignHCenter
                                }

                                Text {
                                    text: modelData.icon
                                    font.pixelSize: 14
                                    Layout.alignment: Qt.AlignHCenter
                                }

                                Text {
                                    text: modelData.temp
                                    color: Theme.fg
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
