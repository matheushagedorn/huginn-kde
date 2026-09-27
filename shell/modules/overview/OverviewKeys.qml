import QtQuick
import Quickshell
import Quickshell.Wayland

// The overview's keyboard, and nothing else.
//
// A layer surface only gets keys while it is mapped with exclusive keyboard
// interactivity, and it has to be unmapped again for KWin to hand the keyboard
// back (keeping one mapped is what trapped the keyboard in the launcher once).
// Being mapped is also what KWin animates, so this surface is one transparent
// pixel with no input region: there is nothing for the animation to show.
// What it holds is drawn by OverviewScreen as the search line.
PanelWindow {
    id: keys

    property var overview: null

    screen: Quickshell.screens.find(s => overview && s.name === overview.focusScreen)
            || Quickshell.screens.find(s => s.name === "DP-2")
            || Quickshell.screens[0]
    anchors { top: true; left: true }
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 1
    implicitHeight: 1
    color: "transparent"
    mask: Region {}

    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.keyboardFocus: WlrLayershell.Exclusive

    visible: overview ? overview.open : false

    onVisibleChanged: {
        if (!visible) return
        input.text = ""
        Qt.callLater(() => input.forceActiveFocus())
    }

    // The query is typed into a real text field, invisible, so editing works
    // the way it does everywhere else (Ctrl+Backspace, Ctrl+A, paste).
    TextInput {
        id: input
        width: 1
        height: 1
        opacity: 0
        focus: true

        onTextChanged: if (keys.overview && keys.overview.query !== text) keys.overview.query = text

        Keys.onPressed: (event) => {
            let ov = keys.overview
            if (!ov) return
            switch (event.key) {
            case Qt.Key_Escape:
                // The first Escape clears a search, the next one leaves.
                if (input.text !== "") input.text = ""
                else ov.hide()
                break
            case Qt.Key_Left: ov.move(-1, 0); break
            case Qt.Key_Right: ov.move(1, 0); break
            case Qt.Key_Up: ov.move(0, -1); break
            case Qt.Key_Down: ov.move(0, 1); break
            case Qt.Key_Tab: ov.step(1); break
            case Qt.Key_Backtab: ov.step(-1); break
            case Qt.Key_Return:
            case Qt.Key_Enter:
                ov.activateSelected()
                break
            default:
                return
            }
            event.accepted = true
        }
    }
}
