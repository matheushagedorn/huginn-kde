import Quickshell
import Quickshell.Wayland
import QtQuick
import "../../services"

// The screen darkening behind the launcher, in a window of its own.
//
// It used to live inside the launcher window, and that window is mapped when
// the launcher opens. KWin animates a surface being mapped with its Scale
// effect, so the dim was scaled along with everything else: instead of the
// screen evenly darkening, a dark rectangle grew and shrank around the panel.
//
// Here the surface is always mapped, so there is no mapping for KWin to
// animate and the dim only ever changes opacity. It never takes input or
// keyboard focus: the launcher window above it owns both, which is why this
// can stay mapped without the focus trouble that came from doing the same to
// the launcher itself.
PanelWindow {
    id: dim

    property real progress: 0.0

    screen: Quickshell.screens.find(s => s.name === "DP-2") || Quickshell.screens[0]
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    WlrLayershell.layer: WlrLayershell.Top
    WlrLayershell.keyboardFocus: WlrLayershell.None

    visible: true
    mask: Region {}

    Rectangle {
        anchors.fill: parent
        visible: dim.progress > 0
        color: Qt.rgba(0, 0, 0, 0.72 * dim.progress)
    }
}
