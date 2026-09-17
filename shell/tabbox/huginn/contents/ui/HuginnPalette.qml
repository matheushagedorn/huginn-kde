// Rewritten by shell/services/python/theme_sync.py on every theme change, the
// same way the splash package is. Only the six colours the theme engine knows
// about live here; everything derived (dimmed text, tinted borders) is worked
// out in main.qml, so a new theme never has to touch this file's shape.
import QtQuick

QtObject {
    readonly property color bg: "#16171c"
    readonly property color surface: "#23242b"
    readonly property color line: "#3f424c"
    readonly property color fg: "#ebedf7"
    readonly property color accent: "#6d7ec7"
    readonly property color subAccent: "#9f72c7"
}
