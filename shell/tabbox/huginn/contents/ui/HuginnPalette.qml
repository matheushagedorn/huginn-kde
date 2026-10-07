// Rewritten by shell/services/python/theme_sync.py on every theme change, the
// same way the splash package is. Only the six colours the theme engine knows
// about live here; everything derived (dimmed text, tinted borders) is worked
// out in main.qml, so a new theme never has to touch this file's shape.
import QtQuick

QtObject {
    readonly property color bg: "#1c1616"
    readonly property color surface: "#2b2323"
    readonly property color line: "#4c3f41"
    readonly property color fg: "#f7ebec"
    readonly property color accent: "#c76d75"
    readonly property color subAccent: "#c7a872"
}
