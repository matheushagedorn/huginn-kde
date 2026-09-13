import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../../theme"
import "../../services"

PanelWindow {
    id: lockscreenWindow

    screen: Quickshell.screens.find(s => s.name === "DP-2") || Quickshell.screens[0]
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.namespace: "lockscreen"
    WlrLayershell.keyboardFocus: LockscreenService.isLocked ? WlrLayershell.Exclusive : WlrLayershell.None
    exclusionMode: ExclusionMode.Ignore

    visible: LockscreenService.isLocked
    color: "#000000"

    // Raw System Wallpaper Image (Hidden from direct view, used as texture source)
    Image {
        id: bgImage
        anchors.fill: parent
        source: Theme.wallpaperPath
        fillMode: Image.PreserveAspectCrop
        visible: false

        Behavior on source {
            PropertyAnimation { duration: 300 }
        }
    }

    // ShaderEffectSource texture capture of wallpaper
    ShaderEffectSource {
        id: wallpaperSource
        anchors.fill: parent
        sourceItem: bgImage
        hideSource: false
        live: true
    }

    // 100% Solid GPU Blurred Background (Isolated strictly to background layer)
    MultiEffect {
        anchors.fill: parent
        source: wallpaperSource
        blurEnabled: true
        blur: 1.0
        blurMax: 56
        opacity: 1.0
    }

    // Subtle Dark Vignette Overlay for Readability
    Rectangle {
        anchors.fill: parent
        color: Theme.isDark ? Qt.rgba(0, 0, 0, 0.35) : Qt.rgba(0, 0, 0, 0.25)
    }

    // Razor-Sharp Lockscreen UI Content Layer (Profile, Password Box, Buttons)
    LockscreenContent {
        anchors.fill: parent
        z: 10
    }
}
