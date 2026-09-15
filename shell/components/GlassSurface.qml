import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import "../theme"

// Glass, made of the actual wallpaper.
//
// KWin does not blur what is behind a layer-shell surface, so the usual trick
// is a flat translucent panel that only pretends. This does not have to
// pretend: the bar reserves its own strip of screen, so whatever is behind it
// is always the wallpaper, and the wallpaper is ours. The same picture is
// drawn here, shifted so its pixels line up with the ones the surface covers,
// blurred, and tinted. What you see through the bar is really what is behind
// it.
//
// `surfaceX` and `surfaceY` are where this sits on the screen, and the screen
// size is what the wallpaper is fitted to, exactly as WallpaperWindow fits it.
ClippingRectangle {
    id: surface

    property real surfaceX: 0
    property real surfaceY: 0
    property real screenWidth: 1920
    property real screenHeight: 1080

    // How much of the glass is tint and how much is picture.
    property real tintOpacity: 0.62
    property real blurAmount: 1.0

    radius: Theme.radiusCard
    color: "transparent"

    Image {
        id: backdropSource
        visible: false
        source: Theme.wallpaperPath
        x: -surface.surfaceX
        y: -surface.surfaceY
        width: surface.screenWidth
        height: surface.screenHeight
        fillMode: Image.PreserveAspectCrop
        // A quarter of the real resolution: it is about to be blurred, and a
        // 4K texture per bar is a lot of memory for something nobody can
        // resolve through 48px of blur.
        sourceSize.width: Math.round(surface.screenWidth / 4)
        asynchronous: true
        cache: true
    }

    MultiEffect {
        source: backdropSource
        x: backdropSource.x
        y: backdropSource.y
        width: backdropSource.width
        height: backdropSource.height
        blurEnabled: true
        blur: surface.blurAmount
        blurMax: 48
        blurMultiplier: 1.4
        autoPaddingEnabled: false
        saturation: 0.15
    }

    // The tint. Without it the bar is a window onto the wallpaper and nothing
    // on it is readable; with it the picture reads as depth behind the type.
    //
    // It is a gradient, not a flat fill, because a flat fill over a flat sky
    // is just a grey rectangle. Thinner at the top where the light would
    // catch, heavier at the bottom where the slab would be thickest.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, surface.tintOpacity - 0.12) }
            GradientStop { position: 0.55; color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, surface.tintOpacity) }
            GradientStop { position: 1.0; color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, surface.tintOpacity + 0.10) }
        }
    }

    // A breath of the accent across the slab, so the glass belongs to the
    // palette rather than being neutral grey over a coloured picture.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.07) }
            GradientStop { position: 0.5; color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.02) }
            GradientStop { position: 1.0; color: Qt.rgba(Theme.subAccent.r, Theme.subAccent.g, Theme.subAccent.b, 0.07) }
        }
    }

    // Light catching the top edge, which is what makes a slab read as glass
    // rather than as a rectangle with a picture in it.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 1
        color: Qt.rgba(1, 1, 1, Theme.isDark ? 0.14 : 0.40)
    }

    // And the edge it rests on, which reads as the thickness of the slab.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: Qt.rgba(0, 0, 0, Theme.isDark ? 0.35 : 0.12)
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        radius: surface.radius
        border.width: 1
        border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.24)
    }
}
