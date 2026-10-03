import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../../components"
import "../../services"
import "../../theme"

GlassPanel {
    id: root
    chrome: false
    implicitWidth: mainLayout.implicitWidth + 24
    implicitHeight: Theme.barHeight - 4

    // Where the row of controls starts inside the panel: the GlassPanel
    // inset plus the row margin, read from the items themselves.
    readonly property real contentInset: mainLayout.parent.x + mainLayout.x

    RowLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 8

        // Time & Date Section with Bell / DND Icon on the left
        Rectangle {
            id: timeBtn
            Layout.preferredWidth: timeRow.implicitWidth + 18
            Layout.preferredHeight: Theme.barCapsule
            radius: 8
            color: PopupService.calendarMenuOpen
                   ? Theme.stateActive
                   : (timeMouse.containsMouse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.20) : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.10))
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
                    color: timeMouse.containsMouse ? Theme.accent : Theme.fg
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
        //
        // The island takes its colour from the cover that is playing: a wash
        // of that colour behind it, a slim spectrum behind the title, and the
        // source badge in the same hue. With no cover it falls back to the
        // palette accent, so it never shows a colour that is not on screen.
        Rectangle {
            id: mediaBtn
            // A fixed width, not the width of the contents. The badge is as
            // wide as the player's name, so sizing from it re-centred the whole
            // bar (and slid every popup anchored to it) whenever the player
            // changed or went away. The title takes whatever is left.
            Layout.preferredWidth: 252
            Layout.preferredHeight: Theme.barCapsule
            radius: 7
            color: PopupService.mediaMenuOpen
                   ? Theme.stateActive
                   : (mediaMouse.containsMouse ? Theme.stateAccentHover : "transparent")
            border.color: mediaMouse.containsMouse
                          ? Qt.rgba(tint.r, tint.g, tint.b, 0.45)
                          : Qt.rgba(tint.r, tint.g, tint.b, 0.20 * presence * tintStrength)
            border.width: 1

            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on border.color { ColorAnimation { duration: 120 } }

            readonly property bool playing: MediaService.hasPlayer && MediaService.status === "Playing"

            // Kept apart from `tint` because the Behavior below makes `tint`
            // the colour on its way there, and the contrast check has to be
            // made against where it is going, not where it is.
            // The cover's colour, brought into the palette: raw, a blue
            // thumbnail sat on a warm theme like something from another desktop.
            readonly property color tintTarget: MediaService.hasPlayer && MediaService.artTint !== ""
                                                ? Theme.harmonize(MediaService.artTint, Theme.accent, 0.55) : Theme.accent
            property color tint: tintTarget
            Behavior on tint { ColorAnimation { duration: 700; easing.type: Easing.InOutQuad } }

            // Full while playing, half while paused, gone with no player: the
            // island looks alive exactly when something is.
            property real presence: !MediaService.hasPlayer ? 0.0 : (playing ? 1.0 : 0.5)
            Behavior on presence { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

            // Strongest wash (behind the cover) and the spectrum's own alpha.
            readonly property real washPeak: 0.30
            readonly property real barsAlpha: 0.30

            // The most tint any point under the title can end up with: the
            // strongest wash with a full-height spectrum bar over it.
            readonly property real worstAlpha: 1 - (1 - washPeak) * (1 - barsAlpha)

            // How much of the tint the island can carry with Theme.fg still
            // clearing 4.5:1 at that worst point. Most covers keep all of it;
            // a pale one (a yellow sleeve on a dark bar) is toned down instead
            // of the title losing out. Never below half, or the island would
            // go back to looking static on the palettes that need it most.
            property real tintStrength: {
                let t = tintTarget
                for (let k = 1.0; k > 0.5; k -= 0.1) {
                    let ground = Theme.flatten(Qt.rgba(t.r, t.g, t.b, worstAlpha * k), Theme.bg)
                    if (Theme.contrastRatio(Theme.fg, ground) >= 4.5) return k
                }
                return 0.5
            }
            Behavior on tintStrength { NumberAnimation { duration: 700 } }

            // Title colour. Theme.fg wherever it already reads; on palettes
            // whose own fg only just clears AA against bg (Solarized, Tokyo
            // Night Day) any tint at all tips it under, so it is lifted toward
            // white or black just far enough. Checked against the same worst
            // point, so it holds wherever the spectrum happens to peak.
            readonly property color titleFg: Theme.ensureContrast(
                Theme.fg,
                Theme.flatten(Qt.rgba(tintTarget.r, tintTarget.g, tintTarget.b, worstAlpha * tintStrength), Theme.bg),
                Theme.bg, 4.5)

            // What the badge sits on, for its own contrast check.
            readonly property color washGround: Theme.flatten(
                Qt.rgba(tint.r, tint.g, tint.b, washPeak * tintStrength * presence), Theme.bg)

            Rectangle {
                id: tintWash
                anchors.fill: parent
                radius: parent.radius
                opacity: mediaBtn.presence
                visible: opacity > 0

                // Brightest behind the cover, where the colour came from, and
                // fading out along the title so the text sits on almost the
                // plain bar.
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0;  color: Qt.rgba(mediaBtn.tint.r, mediaBtn.tint.g, mediaBtn.tint.b, mediaBtn.washPeak * mediaBtn.tintStrength) }
                    GradientStop { position: 0.45; color: Qt.rgba(mediaBtn.tint.r, mediaBtn.tint.g, mediaBtn.tint.b, 0.12 * mediaBtn.tintStrength) }
                    GradientStop { position: 1.0;  color: Qt.rgba(mediaBtn.tint.r, mediaBtn.tint.g, mediaBtn.tint.b, 0.03 * mediaBtn.tintStrength) }
                }
            }

            // Spectrum behind the title, from the same cava stream as the
            // popup's meter. CavaService only runs cava while something is
            // playing, and this fades out with it, so a paused track costs
            // nothing and leaves no frozen bars behind.
            //
            // Laid over the title's slot rather than put inside the row: the
            // row is a layout, and the spectrum must not take part in sizing.
            Item {
                id: titleSpectrum
                x: mediaRow.x + marqueeTitle.x
                width: marqueeTitle.width
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.topMargin: 4
                anchors.bottomMargin: 3
                clip: true
                opacity: mediaBtn.playing && CavaService.available ? 1.0 : 0.0
                visible: opacity > 0

                Behavior on opacity { NumberAnimation { duration: 300 } }

                readonly property real slot: width / CavaService.bars
                readonly property color barColor: Qt.rgba(mediaBtn.tint.r, mediaBtn.tint.g, mediaBtn.tint.b,
                                                          mediaBtn.barsAlpha * mediaBtn.tintStrength)

                Repeater {
                    model: CavaService.bars

                    // Plain rectangles with one height binding each, driven by
                    // the service's `tick`: nothing is allocated per frame
                    // here, and nothing animates on its own. cava already
                    // smooths the signal at 30 fps.
                    Rectangle {
                        required property int index
                        x: Math.round(index * titleSpectrum.slot)
                        width: Math.max(1, Math.round(titleSpectrum.slot) - 2)
                        anchors.bottom: parent.bottom
                        radius: 1
                        color: titleSpectrum.barColor
                        height: {
                            let t = CavaService.tick
                            let raw = CavaService.values.length > index ? CavaService.values[index] : 0
                            // Same gamma as the popup's meter, so quiet
                            // passages still move.
                            return Math.round(Math.pow(raw / 100.0, 0.55) * titleSpectrum.height)
                        }
                    }
                }
            }

            RowLayout {
                id: mediaRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 7
                anchors.rightMargin: 7
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
                    id: sourceBadge
                    visible: MediaService.hasPlayer && MediaService.playerDisplayName !== ""
                    implicitWidth: sourceText.implicitWidth + 10
                    implicitHeight: 16
                    // An app with a long Identity must not eat the title.
                    Layout.maximumWidth: 88
                    radius: 4
                    color: Qt.rgba(mediaBtn.tint.r, mediaBtn.tint.g, mediaBtn.tint.b, 0.16)
                    border.color: Qt.rgba(mediaBtn.tint.r, mediaBtn.tint.g, mediaBtn.tint.b, 0.42)
                    border.width: 1

                    Text {
                        id: sourceText
                        anchors.centerIn: parent
                        width: Math.min(implicitWidth, sourceBadge.width - 10)
                        elide: Text.ElideRight
                        text: MediaService.playerDisplayName
                        // The cover's colour as text, lifted just far enough to
                        // read on the badge and on the wash around it.
                        color: Theme.ensureContrast(mediaBtn.tint,
                                                    Theme.flatten(sourceBadge.color, mediaBtn.washGround),
                                                    mediaBtn.washGround, 4.5)
                        font.pixelSize: Theme.fsCaption
                        font.family: Theme.fontFamily
                        font.weight: Font.Bold
                    }
                }

                // Scrolling Marquee Track Title
                MarqueeText {
                    id: marqueeTitle
                    Layout.fillWidth: true
                    implicitHeight: 16
                    text: MediaService.hasPlayer && MediaService.title ? MediaService.title + (MediaService.artist ? " - " + MediaService.artist : "") : "No Media Playing"
                    color: MediaService.hasPlayer ? mediaBtn.titleFg : Theme.comment
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
        anchor.rect.x: Theme.popupX(root, root.contentInset + timeBtn.x, timeBtn.width, implicitWidth, window.width, root.contentInset)
        anchor.rect.y: Theme.popupGap
        anchor.edges: Edges.Bottom
        visible: false
        color: "transparent"

        implicitWidth: calendarGlass.implicitWidth
        implicitHeight: calendarGlass.implicitHeight

        MorphPanel {
            id: calendarGlass
            popup: timeMenu
            trigger: timeBtn
            open: PopupService.calendarMenuOpen
            implicitWidth: dashboard.implicitWidth + 32
            implicitHeight: dashboard.implicitHeight + 28
            anchors.fill: parent

            Dashboard {
                id: dashboard
                anchors.centerIn: parent
            }
        }
    }

    // Detached MPRIS Player Card Popup Window
    PopupWindow {
        id: mediaMenu
        anchor.window: window
        anchor.rect.x: Theme.popupX(root, root.contentInset + mediaBtn.x, mediaBtn.width, implicitWidth, window.width, root.contentInset)
        anchor.rect.y: Theme.popupGap
        anchor.edges: Edges.Bottom
        visible: false
        color: "transparent"

        implicitWidth: playerGlass.implicitWidth
        implicitHeight: playerGlass.implicitHeight

        MorphPanel {
            id: playerGlass
            popup: mediaMenu
            trigger: mediaBtn
            open: PopupService.mediaMenuOpen
            implicitWidth: 260

            // The spectrum gets its own band at the foot of the card. It used
            // to fill the whole card and grow up through the controls row, so
            // the prev/next glyphs — drawn on a transparent button — had bars
            // crossing them whenever something was playing.
            readonly property int spectrumBand: spectrum.visible ? 26 : 0

            implicitHeight: playerLayout.implicitHeight + Theme.sp5 + spectrumBand
            anchors.fill: parent

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

    // City picker, on right-click of the weather capsule.
    //
    // A PanelWindow rather than a PopupWindow: keyboardFocus is a property of
    // the layer surface, and a popup is a child surface, so a text field inside
    // one never receives a keystroke. This is the same shape the app launcher
    // uses, which is the one that works.
    PanelWindow {
        id: weatherPicker
        screen: window.screen
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"

        WlrLayershell.layer: WlrLayershell.Overlay
        WlrLayershell.keyboardFocus: WlrLayershell.Exclusive

        visible: PopupService.weatherPickerOpen

        onVisibleChanged: {
            if (visible) {
                cityField.text = ""
                WeatherService.searchResults = []
                cityField.forceActiveFocus()
            }
        }

        // Anywhere outside the card dismisses it.
        MouseArea {
            anchors.fill: parent
            onClicked: PopupService.closeAll()
        }

        GlassPanel {
            id: pickerGlass
            // Lines up under the clock, which is where the weather lives now:
            // the bar window is inset by
            // 10px, and the popups below the bar sit at Theme.popupGap.
            x: 10 + Theme.popupX(root, root.contentInset + timeBtn.x, timeBtn.width, width, window.width, root.contentInset)
            y: 10 + Theme.popupGap
            width: 300
            // Content height, plus this layout's own margins, plus the 4px
            // inset GlassPanel puts around its children on every side. Leaving
            // that inset out is what was cropping the last row: the content
            // asked for 78px and was handed 70.
            readonly property int chrome: Theme.sp3 * 2 + 8
            height: pickerCol.implicitHeight + chrome

            // Clicks on the card must not reach the dismiss area behind it.
            MouseArea { anchors.fill: parent }

            ColumnLayout {
                id: pickerCol
                anchors.fill: parent
                anchors.margins: Theme.sp3
                spacing: Theme.sp2
                clip: true

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        text: "Location"
                        color: Theme.fg
                        font.pixelSize: Theme.fsStrong
                        font.family: Theme.fontFamily
                        font.weight: Font.Bold
                    }

                    Text {
                        // States where the reading comes from without looking
                        // like a control. The first version put "Auto" in the
                        // corner, which read as a button and did nothing.
                        text: WeatherService.pinnedCity !== ""
                              ? "Pinned to " + WeatherService.pinnedCity
                              : (WeatherService.city !== ""
                                 ? "Detected as " + WeatherService.city
                                 : "Detecting…")
                        color: Theme.textMuted
                        font.pixelSize: Theme.fsCaption
                        font.family: Theme.fontFamily
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    radius: Theme.radiusChip
                    color: Theme.stateHover
                    border.color: cityField.activeFocus ? Theme.stateFocus : Theme.separator
                    border.width: 1

                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    TextInput {
                        id: cityField
                        anchors.fill: parent
                        anchors.leftMargin: Theme.sp2
                        anchors.rightMargin: Theme.sp2
                        verticalAlignment: Text.AlignVCenter
                        color: Theme.fg
                        font.pixelSize: Theme.fsBody
                        font.family: Theme.fontFamily
                        selectionColor: Theme.stateActive
                        selectedTextColor: Theme.fg
                        selectByMouse: true
                        clip: true
                        focus: true

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: "Type a city name"
                            color: Theme.textMuted
                            font.pixelSize: Theme.fsBody
                            font.family: Theme.fontFamily
                            visible: !cityField.text
                        }

                        onTextChanged: WeatherService.searchCity(text)
                        Keys.onEscapePressed: PopupService.closeAll()
                    }
                }

                // An empty list should never be silently empty.
                Text {
                    visible: text !== ""
                    text: WeatherService.searching
                          ? "Searching…"
                          : (cityField.text.length >= 2 && WeatherService.searchError !== ""
                             ? WeatherService.searchError : "")
                    color: Theme.textMuted
                    font.pixelSize: Theme.fsCaption
                    font.family: Theme.fontFamily
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    visible: WeatherService.searchResults.length > 0

                    Repeater {
                        model: WeatherService.searchResults

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 38
                            radius: Theme.radiusChip
                            color: hitMouse.containsMouse ? Theme.stateHover : "transparent"

                            Behavior on color { ColorAnimation { duration: 100 } }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.sp2
                                anchors.rightMargin: Theme.sp2
                                spacing: 0

                                Text {
                                    text: modelData.name
                                    color: Theme.fg
                                    font.pixelSize: Theme.fsBody
                                    font.family: Theme.fontFamily
                                    font.weight: Font.Medium
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: modelData.region
                                    color: Theme.textMuted
                                    font.pixelSize: Theme.fsCaption
                                    font.family: Theme.fontFamily
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            MouseArea {
                                id: hitMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    WeatherService.applyCity(modelData.name,
                                                             modelData.latitude,
                                                             modelData.longitude,
                                                             modelData.region)
                                    PopupService.closeAll()
                                }
                            }
                        }
                    }
                }

                // No fillHeight spacer here: the card sizes itself from this
                // layout while the layout fills the card, and an item that
                // absorbs leftover space makes that circular. The footer was
                // left hanging over the bottom edge.
                Rectangle {
                    visible: WeatherService.pinnedCity !== ""
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.sp1
                    Layout.preferredHeight: 1
                    color: Theme.separator
                }

                Rectangle {
                    visible: WeatherService.pinnedCity !== ""
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    radius: Theme.radiusChip
                    color: autoMouse.containsMouse ? Theme.stateHover : "transparent"
                    border.color: autoMouse.containsMouse ? Theme.separator : "transparent"
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: 100 } }

                    Text {
                        anchors.centerIn: parent
                        text: "Detect my location again"
                        color: Theme.textMuted
                        font.pixelSize: Theme.fsCaption
                        font.family: Theme.fontFamily
                    }

                    MouseArea {
                        id: autoMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            WeatherService.useAutoLocation()
                            PopupService.closeAll()
                        }
                    }
                }
            }
        }
    }
}
