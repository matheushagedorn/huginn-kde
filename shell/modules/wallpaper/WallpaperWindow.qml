import Quickshell
import Quickshell.Wayland
import QtQuick
import "../../theme"

PanelWindow {
    id: wallpaperWindow
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayershell.Background
    WlrLayershell.keyboardFocus: WlrLayershell.None
    exclusionMode: ExclusionMode.Ignore
    color: Theme.bg

    mask: Region {}

    property string currentSource: Theme.wallpaperPath
    property string previousSource: ""
    property real fadeProgress: 1.0

    onCurrentSourceChanged: {
        if (currentSource === "") return

        // The first picture of the session has nothing to cross over from, so
        // it is simply there. Only a change from one wallpaper to another is
        // worth animating.
        if (previousSource === "") {
            fadeProgress = 1.0
            previousSource = currentSource
            return
        }

        fadeProgress = 0.0
        fadeAnim.restart()
    }

    Binding {
        target: wallpaperWindow
        property: "currentSource"
        value: Theme.wallpaperPath
    }

    // Background Previous Image (Fades Out)
    Image {
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        source: wallpaperWindow.previousSource !== "" ? wallpaperWindow.previousSource : wallpaperWindow.currentSource
        opacity: 1.0 - wallpaperWindow.fadeProgress
        visible: opacity > 0
        asynchronous: true
        cache: true
    }

    // Foreground Current Image (Fades In)
    Image {
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        source: wallpaperWindow.currentSource
        opacity: wallpaperWindow.fadeProgress
        asynchronous: true
        cache: true
    }

    NumberAnimation {
        id: fadeAnim
        target: wallpaperWindow
        property: "fadeProgress"
        from: 0.0
        to: 1.0
        duration: 450
        easing.type: Easing.InOutQuad
        onFinished: {
            wallpaperWindow.previousSource = wallpaperWindow.currentSource
        }
    }
}
