import QtQuick
import QtQuick.Effects
import Quickshell
import "../theme"

// One icon language for the whole shell.
//
// Interface icons used to come from five places at once: filled Papirus SVGs,
// hand-drawn Canvas paths, emoji, loose Unicode symbols, and Nerd Font glyphs.
// Each brought its own stroke weight, corner radius and optical size, which is
// why nothing looked related to anything.
//
// These are Lucide (ISC): one 24px grid, 2px stroke, round caps and joins.
// The file ships white and is tinted here, so every icon answers to the
// palette instead of to whatever the icon theme decided.
//
// Application icons are deliberately NOT routed through this — an app's icon
// is its identity and keeps coming from the system icon theme.
Item {
    id: root

    property string name: ""
    property color color: Theme.fg
    property real strokeScale: 1.0

    implicitWidth: 16
    implicitHeight: 16

    Image {
        id: source
        anchors.fill: parent
        visible: false
        source: root.name !== ""
                ? "file://" + Quickshell.env("HOME") + "/.config/quickshell/icons/" + root.name + ".svg"
                : ""
        // Rasterised at twice the drawn size: a 2px stroke on a 24px grid goes
        // muddy when a 16px slot rasterises at 16.
        sourceSize.width: Math.round(root.width * 2)
        sourceSize.height: Math.round(root.height * 2)
        fillMode: Image.PreserveAspectFit
        smooth: true
        asynchronous: true
    }

    MultiEffect {
        anchors.fill: parent
        source: source
        visible: source.status === Image.Ready
        colorization: 1.0
        colorizationColor: root.color

        Behavior on colorizationColor {
            ColorAnimation { duration: 120; easing.type: Easing.OutCubic }
        }
    }
}
