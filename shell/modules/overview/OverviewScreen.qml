import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../../components"
import "../../theme"

// One screen of the overview: the wash behind the cards and the cards
// themselves.
//
// Always mapped, for the reason in Overview.qml. While the overview is closed
// it draws nothing and its input region is empty, so it is not there as far
// as the pointer is concerned.
//
// It also rests on the Top layer while closed and only rises to Overlay when
// opened. Overlay sits above full-screen windows, and a surface parked over a
// game, even a transparent one, keeps KWin from handing the game's buffer
// straight to the display. On Top it is below them, where LauncherDim already
// lives.
PanelWindow {
    id: win

    property var overview: null

    readonly property string screenName: win.screen ? win.screen.name : ""
    readonly property bool isFocusScreen: overview && overview.focusScreen === win.screenName
    readonly property var slots: overview && overview.layouts[win.screenName] ? overview.layouts[win.screenName] : ({})

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    WlrLayershell.layer: overview && overview.active ? WlrLayershell.Overlay : WlrLayershell.Top
    WlrLayershell.keyboardFocus: WlrLayershell.None

    visible: true
    mask: Region {
        width: win.overview && win.overview.active ? win.width : 0
        height: win.overview && win.overview.active ? win.height : 0
    }

    // ── The wash ──────────────────────────────────────────────────────────
    //
    // The shell's glass is the wallpaper, blurred and tinted (GlassSurface),
    // and the overview is that glass over the whole screen. It fades in as
    // the cards leave their windows, so by the time they reach their slots
    // the windows underneath are gone and only the cards stand for them.
    Item {
        id: wash
        anchors.fill: parent
        opacity: win.overview ? win.overview.progress : 0
        visible: opacity > 0

        Image {
            id: washSource
            anchors.fill: parent
            visible: false
            source: Theme.wallpaperPath
            fillMode: Image.PreserveAspectCrop
            // It is about to be blurred beyond recognition; a quarter of the
            // resolution is plenty and saves a full-size texture per screen.
            sourceSize.width: Math.round(win.width / 4)
            asynchronous: true
            cache: true
        }

        MultiEffect {
            anchors.fill: parent
            source: washSource
            blurEnabled: true
            blur: 1.0
            blurMax: 64
            blurMultiplier: 1.6
            autoPaddingEnabled: false
            saturation: 0.1
        }

        // Without a wallpaper the blur has nothing to show; the tint alone
        // still reads as the shell's ground.
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, washSource.status === Image.Ready ? 0.50 : 0.90) }
                GradientStop { position: 1.0; color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, washSource.status === Image.Ready ? 0.68 : 0.95) }
            }
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.06) }
                GradientStop { position: 0.5; color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.01) }
                GradientStop { position: 1.0; color: Qt.rgba(Theme.subAccent.r, Theme.subAccent.g, Theme.subAccent.b, 0.06) }
            }
        }
    }

    // Empty space closes. hoverEnabled so the pointer over the wash is not
    // also hovering something underneath.
    MouseArea {
        anchors.fill: parent
        enabled: win.overview && win.overview.active
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: if (win.overview) win.overview.hide()
    }

    // ── The search line ───────────────────────────────────────────────────
    //
    // Drawn here rather than in OverviewKeys, which holds the keyboard: that
    // window is a single pixel, so it can be mapped on open without KWin's
    // map animation being visible, and the line is just a picture of what it
    // holds. Only on the screen the overview opened from.
    Item {
        id: searchLine
        visible: win.isFocusScreen && opacity > 0
        opacity: win.overview ? win.overview.progress : 0
        anchors.horizontalCenter: parent.horizontalCenter
        y: 36 - 12 * (1 - opacity)
        width: Math.min(560, win.width - 2 * Theme.sp5)
        height: 44

        readonly property string query: win.overview ? win.overview.query : ""

        // A click on the line itself is not a click on empty space.
        MouseArea { anchors.fill: parent; hoverEnabled: true }

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.72)
            border.width: 1
            border.color: searchLine.query !== ""
                ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.55)
                : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.24)

            Behavior on border.color { ColorAnimation { duration: 150 } }
        }

        UiIcon {
            id: searchIcon
            name: "search"
            width: 16
            height: 16
            color: Theme.textMuted
            anchors.left: parent.left
            anchors.leftMargin: Theme.sp4
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            id: queryText
            anchors.left: searchIcon.right
            anchors.leftMargin: Theme.sp3
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, countText.x - x - Theme.sp3)
            text: searchLine.query !== "" ? searchLine.query : "Type to filter windows"
            color: searchLine.query !== "" ? Theme.fg : Theme.textMuted
            font.pixelSize: Theme.fsSubhead
            font.family: Theme.fontFamily
            elide: Text.ElideLeft
        }

        // A caret, so it is plain that typing goes here even though nothing
        // on screen looks like a text field.
        Rectangle {
            visible: searchLine.query !== ""
            x: queryText.x + queryText.width + 2
            anchors.verticalCenter: parent.verticalCenter
            width: 2
            height: 18
            color: Theme.accent

            SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: searchLine.visible && searchLine.query !== ""
                NumberAnimation { to: 0; duration: 520; easing.type: Easing.InOutQuad }
                NumberAnimation { to: 1; duration: 520; easing.type: Easing.InOutQuad }
            }
        }

        // What the machine counts, in the machine's voice, as the launcher
        // does.
        Text {
            id: countText
            anchors.right: parent.right
            anchors.rightMargin: Theme.sp4
            anchors.verticalCenter: parent.verticalCenter
            text: {
                let n = win.overview ? win.overview.visibleWindows.length : 0
                return n + (n === 1 ? " window" : " windows")
            }
            color: Theme.textMuted
            font.pixelSize: Theme.fsCaption
            font.family: Theme.fontMono
        }
    }

    // Said outright, rather than leaving an empty wash to be puzzled over.
    Text {
        anchors.centerIn: parent
        visible: win.overview && win.overview.open && win.isFocusScreen
                 && win.overview.visibleWindows.length === 0
        opacity: win.overview ? win.overview.progress : 0
        text: win.overview && win.overview.query !== ""
              ? "No window matches “" + win.overview.query + "”"
              : "No windows on this desktop"
        color: Theme.textMuted
        font.pixelSize: Theme.fsHead
        font.family: Theme.fontFamily
        font.weight: Font.Light
    }

    // ── The cards ─────────────────────────────────────────────────────────
    //
    // Keyed by window id through ScriptModel, so a card survives the list
    // being rebuilt (a window closing, a caption changing) and can glide to
    // its new slot instead of being torn down and drawn again.
    Repeater {
        model: ScriptModel {
            values: win.overview
                ? win.overview.windows.filter(w => w.screen === win.screenName).map(w => w.id)
                : []
        }

        OverviewCard {
            required property string modelData
            overview: win.overview
            windowId: modelData
            screenX: win.screen ? win.screen.x : 0
            screenY: win.screen ? win.screen.y : 0
            slot: win.slots[modelData] || null
        }
    }
}
