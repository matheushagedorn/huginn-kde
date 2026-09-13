import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../components"
import "../../services"
import "../../theme"

GlassPanel {
    id: root
    implicitWidth: mainLayout.implicitWidth + 24
    implicitHeight: Theme.barHeight - 4

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
            Layout.preferredHeight: Theme.barCapsule
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
                    font.pixelSize: Theme.fsStrong
                }

                Text {
                    text: WeatherService.currentTempStr
                    color: Theme.fg
                    font.pixelSize: Theme.fsBody
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
            Layout.preferredHeight: Theme.barCapsule
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
                    hasUnread: NotificationService.notifications.length > 0
                    implicitWidth: 15
                    implicitHeight: 15
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    text: DateTimeService.timeStr
                    color: Theme.fg
                    font.pixelSize: Theme.fsBody
                    font.family: Theme.fontFamily
                    font.weight: Font.Bold
                }

                Text {
                    text: "•"
                    color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.6)
                    font.pixelSize: Theme.fsCaption
                    font.family: Theme.fontFamily
                }

                Text {
                    text: DateTimeService.dateStr
                    color: Theme.textMuted
                    font.pixelSize: Theme.fsBody
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
            Layout.preferredHeight: Theme.barCapsule
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
                        font.pixelSize: Theme.fsCaption
                        font.family: Theme.fontFamily
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
                    font.pixelSize: Theme.fsBody
                    font.family: Theme.fontFamily
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
        anchor.rect.y: Theme.popupGap
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
        anchor.rect.y: Theme.popupGap
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
            implicitWidth: 260

            // The spectrum gets its own band at the foot of the card. It used
            // to fill the whole card and grow up through the controls row, so
            // the prev/next glyphs — drawn on a transparent button — had bars
            // crossing them whenever something was playing.
            readonly property int spectrumBand: spectrum.visible ? 26 : 0

            implicitHeight: playerLayout.implicitHeight + Theme.sp5 + spectrumBand
            anchors.fill: parent

            opacity: mediaMenu.animProgress
            scale: 0.90 + 0.10 * mediaMenu.animProgress
            transformOrigin: Item.Top

            // Output spectrum, in its own band along the bottom edge.
            // Driven by cava; hidden entirely when cava is not installed so
            // the card never shows a frozen meter that cannot respond.
            Item {
                id: spectrum
                z: 0
                visible: MediaService.hasPlayer && CavaService.available
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                    leftMargin: Theme.sp3
                    rightMargin: Theme.sp3
                    bottomMargin: Theme.sp2
                }
                height: 22
                clip: true

                Row {
                    id: spectrumRow
                    anchors.fill: parent
                    spacing: Math.max(2, (width - CavaService.bars * 4) / (CavaService.bars - 1))

                    Repeater {
                        model: CavaService.bars

                        Rectangle {
                            width: 4
                            anchors.bottom: parent.bottom
                            radius: 2

                            // One binding on `tick` drives all 28 bars; the
                            // per-bar 40ms NumberAnimation that used to smooth
                            // them ran 28 concurrent animations at 60fps for a
                            // signal cava has already smoothed.
                            height: {
                                let t = CavaService.tick
                                if (MediaService.status !== "Playing") return 2
                                let raw = (CavaService.values && CavaService.values.length > index)
                                    ? CavaService.values[index] : 0
                                // Gamma curve, not a straight ratio. Mapped
                                // linearly, ordinary music peaked at a tenth
                                // of the band and the meter barely moved.
                                let ratio = Math.pow(raw / 100.0, 0.55)
                                return Math.max(2, Math.min(spectrum.height, ratio * spectrum.height))
                            }

                            color: MediaService.status === "Playing"
                                ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.55)
                                : Qt.rgba(Theme.comment.r, Theme.comment.g, Theme.comment.b, 0.18)
                        }
                    }
                }
            }

            ColumnLayout {
                id: playerLayout
                z: 1
                anchors.fill: parent
                anchors.margins: Theme.sp3
                anchors.bottomMargin: Theme.sp3 + playerGlass.spectrumBand
                spacing: Theme.sp2

                // Which app the audio is coming from, plus its transport state.
                Rectangle {
                    visible: MediaService.hasPlayer && MediaService.playerDisplayName !== ""
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: popupSourceRow.implicitWidth + Theme.sp3
                    implicitHeight: 22
                    radius: Theme.radiusPill
                    color: Theme.stateHover
                    border.color: Theme.separator
                    border.width: 1

                    RowLayout {
                        id: popupSourceRow
                        anchors.centerIn: parent
                        spacing: 5

                        Rectangle {
                            width: 6
                            height: 6
                            radius: 3
                            color: MediaService.status === "Playing" ? Theme.success : Theme.warning
                        }

                        Text {
                            // Shown as the app names itself ("Brave"), not
                            // shouted in caps.
                            text: MediaService.playerDisplayName
                            color: Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsCaption
                            font.weight: Font.DemiBold
                        }
                    }
                }

                AlbumCover {
                    Layout.preferredWidth: 64
                    Layout.preferredHeight: 64
                    implicitWidth: 64
                    implicitHeight: 64
                    artUrl: MediaService.artUrl
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    text: MediaService.hasPlayer && MediaService.title ? MediaService.title : "Nothing playing"
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsSubhead
                    font.weight: Font.DemiBold
                    lineHeight: Theme.lhTight
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    text: MediaService.artist !== "" ? MediaService.artist : "Unknown artist"
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsBody
                    lineHeight: Theme.lhBody
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }

                // Position, scrubbing and buffer state.
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.sp1
                    spacing: Theme.sp1
                    visible: MediaService.hasPlayer

                    Item {
                        id: progressTrackContainer
                        Layout.fillWidth: true
                        Layout.preferredHeight: 14

                        // Latched rather than read from seekMouse.pressed.
                        // `pressed` flips to false before onReleased fires, so
                        // the binding fell back to the stale playback position
                        // for one frame and the thumb visibly bounced back
                        // before jumping to where it was dropped.
                        property bool isDragging: false
                        property real dragRatio: 0.0
                        readonly property real shownRatio: isDragging ? dragRatio : MediaService.progress

                        Rectangle {
                            id: seekTrack
                            anchors.centerIn: parent
                            width: parent.width
                            height: 4
                            radius: 2
                            color: Theme.currentLine

                            // Duration unknown yet — a stream still buffering.
                            // An indeterminate sweep says "working on it"
                            // instead of parking the thumb at 0:00.
                            Rectangle {
                                id: bufferSweep
                                visible: MediaService.buffering
                                width: parent.width * 0.3
                                height: parent.height
                                radius: 2
                                color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35)

                                SequentialAnimation on x {
                                    running: bufferSweep.visible
                                    loops: Animation.Infinite
                                    NumberAnimation { from: 0; to: seekTrack.width - bufferSweep.width; duration: 900; easing.type: Easing.InOutQuad }
                                    NumberAnimation { from: seekTrack.width - bufferSweep.width; to: 0; duration: 900; easing.type: Easing.InOutQuad }
                                }
                            }

                            Rectangle {
                                id: seekFill
                                visible: !MediaService.buffering
                                // Accent, not pink. On every palette where the
                                // two differ — Tokyo Night's blue accent
                                // against a salmon pink, for one — this was the
                                // one control in the shell painted off-scheme.
                                width: Math.max(2, parent.width * progressTrackContainer.shownRatio)
                                height: parent.height
                                radius: 2
                                color: Theme.accent

                                Behavior on width {
                                    enabled: !progressTrackContainer.isDragging
                                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                                }
                            }
                        }

                        Rectangle {
                            id: knobHandle
                            visible: !MediaService.buffering
                            width: seekMouse.containsMouse || progressTrackContainer.isDragging ? 12 : 8
                            height: width
                            radius: width / 2
                            color: Theme.accent
                            border.color: Theme.bg
                            border.width: 1
                            anchors.verticalCenter: parent.verticalCenter
                            x: Math.max(0, Math.min(progressTrackContainer.width - width,
                                   (progressTrackContainer.width * progressTrackContainer.shownRatio) - (width / 2)))

                            Behavior on width { NumberAnimation { duration: 100 } }
                            Behavior on x {
                                enabled: !progressTrackContainer.isDragging
                                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                            }
                        }

                        MouseArea {
                            id: seekMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: MediaService.durationKnown
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

                            function ratioAt(mx) {
                                return Math.max(0.0, Math.min(1.0, mx / width))
                            }

                            onPressed: mouse => {
                                progressTrackContainer.dragRatio = ratioAt(mouse.x)
                                progressTrackContainer.isDragging = true
                            }
                            onPositionChanged: mouse => {
                                if (pressed) progressTrackContainer.dragRatio = ratioAt(mouse.x)
                            }
                            onReleased: mouse => {
                                var ratio = ratioAt(mouse.x)
                                progressTrackContainer.dragRatio = ratio
                                MediaService.seek(ratio * MediaService.length)
                                // Released only after the service has taken the
                                // new position, so the handover is continuous.
                                progressTrackContainer.isDragging = false
                            }
                            onCanceled: progressTrackContainer.isDragging = false
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: MediaService.positionStr
                            color: Theme.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsCaption
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: MediaService.buffering ? "Loading" : MediaService.lengthStr
                            color: Theme.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsCaption
                        }
                    }
                }

                // Transport controls.
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: Theme.sp1
                    spacing: Theme.sp3
                    opacity: MediaService.hasPlayer ? 1.0 : Theme.disabledOpacity
                    enabled: MediaService.hasPlayer

                    Behavior on opacity { NumberAnimation { duration: 120 } }

                    Rectangle {
                        width: 32
                        height: 32
                        radius: Theme.radiusChip
                        color: prevMouse.containsMouse ? Theme.stateHover : "transparent"

                        Behavior on color { ColorAnimation { duration: 100 } }

                        MediaIcon {
                            iconType: "prev"
                            color: prevMouse.containsMouse ? Theme.fg : Theme.textMuted
                            anchors.centerIn: parent
                            implicitWidth: 13
                            implicitHeight: 13
                        }

                        MouseArea {
                            id: prevMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: MediaService.previous()
                        }
                    }

                    Rectangle {
                        width: 38
                        height: 38
                        radius: Theme.radiusPill
                        color: playMouse.containsMouse ? Theme.subAccent : Theme.accent

                        Behavior on color { ColorAnimation { duration: 100 } }

                        MediaIcon {
                            iconType: MediaService.status === "Playing" ? "pause" : "play"
                            // Derived from the accent's own luminance, so the
                            // glyph stays readable on light palettes where
                            // Theme.bg was nearly the same value as the accent.
                            color: Theme.accentFg
                            anchors.centerIn: parent
                            implicitWidth: 15
                            implicitHeight: 15
                        }

                        MouseArea {
                            id: playMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: MediaService.playPause()
                        }
                    }

                    Rectangle {
                        width: 32
                        height: 32
                        radius: Theme.radiusChip
                        color: nextMouse.containsMouse ? Theme.stateHover : "transparent"

                        Behavior on color { ColorAnimation { duration: 100 } }

                        MediaIcon {
                            iconType: "next"
                            color: nextMouse.containsMouse ? Theme.fg : Theme.textMuted
                            anchors.centerIn: parent
                            implicitWidth: 13
                            implicitHeight: 13
                        }

                        MouseArea {
                            id: nextMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
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
        anchor.rect.y: Theme.popupGap
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
                        font.pixelSize: Theme.fsDisplay
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: WeatherService.city
                            color: Theme.fg
                            font.pixelSize: Theme.fsSubhead
                            font.weight: Font.Bold
                        }

                        Text {
                            text: WeatherService.condition + " • " + WeatherService.currentTempStr
                            color: Theme.textMuted
                            font.pixelSize: Theme.fsBody
                            font.family: Theme.fontFamily
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
                                    color: Theme.textMuted
                                    font.pixelSize: Theme.fsCaption
                                    font.family: Theme.fontFamily
                                    font.weight: Font.Medium
                                    Layout.alignment: Qt.AlignHCenter
                                }

                                Text {
                                    text: modelData.icon
                                    font.pixelSize: Theme.fsSubhead
                                    font.family: Theme.fontFamily
                                    Layout.alignment: Qt.AlignHCenter
                                }

                                Text {
                                    text: modelData.temp
                                    color: Theme.fg
                                    font.pixelSize: Theme.fsCaption
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
