import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import "modules/topbar"
import "components"
import "modules/dock"
import "modules/launcher"
import "modules/wallpaper"
import "modules/notifications"
import "modules/desktop"
import "modules/lockscreen"
import "modules/osd"
import "services"
import "theme"

Scope {
    IpcHandler {
        target: "reload"
        function reload() {
            if (typeof Quickshell.reload === "function") {
                Quickshell.reload()
            } else if (typeof Quickshell.reloadConfig === "function") {
                Quickshell.reloadConfig()
            }
        }
    }

    // Lets the panels be opened from a script, which is how they get
    // screenshotted and checked across theme variants.
    IpcHandler {
        target: "popup"
        function media() { PopupService.toggleMedia() }
        function brightness() { PopupService.toggleBrightness() }
        function calendar() { PopupService.toggleCalendar() }
        function weatherpicker() { PopupService.toggleWeatherPicker() }
        function session() { PopupService.toggleSession() }
        function notifications() { PopupService.toggleNotification() }
        function close() { PopupService.closeAll() }
    }

    IpcHandler {
        target: "launcher"
        function toggle() {
            TaskService.toggleLauncher()
        }
    }

    IpcHandler {
        target: "volume"
        function increase() {
            AudioService.volumeUp()
        }
        function decrease() {
            AudioService.volumeDown()
        }
        function mute() {
            AudioService.toggleMute()
        }
    }

    // Primary monitor (confirm yours with kscreen-doctor -o). Every window
    // below points at it, otherwise each one lands on a different screen.
    property var primaryScreen: Quickshell.screens.find(s => s.name === "DP-2") || Quickshell.screens[0]

    // Every screen that is not the primary one. The bar, the wallpaper and
    // the popups all used to be pinned to DP-2, so a second monitor showed
    // the bare compositor background and nothing else.
    property var secondaryScreens: Quickshell.screens.filter(s => s !== primaryScreen)

    // Dynamic Theme Wallpaper (Layer: Background), one per screen
    Variants {
        model: Quickshell.screens

        WallpaperWindow {
            required property var modelData
            screen: modelData
        }
    }

    // Companion bar on the other monitors: desktop, focused window, clock.
    Variants {
        model: secondaryScreens

        PanelWindow {
            id: secondaryBarWindow
            required property var modelData

            screen: modelData

            readonly property bool filled: secondaryBarWindow.screen
                                           && TaskService.filledScreens.indexOf(secondaryBarWindow.screen.name) >= 0
            readonly property int restGap: 10
            property real gap: filled ? 0 : restGap

            Behavior on gap {
                NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
            }

            anchors {
                top: true
                left: true
                right: true
            }
            margins {
                top: Math.round(secondaryBarWindow.gap)
                left: Math.round(secondaryBarWindow.gap)
                right: Math.round(secondaryBarWindow.gap)
            }

            WlrLayershell.layer: WlrLayershell.Top
            exclusiveZone: Theme.barHeight + (secondaryBarWindow.filled ? 0 : secondaryBarWindow.restGap)
            implicitHeight: Theme.barHeight
            color: "transparent"

            GlassSurface {
                anchors.fill: parent
                radius: Theme.radiusCard * (secondaryBarWindow.gap / secondaryBarWindow.restGap)
                surfaceX: secondaryBarWindow.gap
                surfaceY: secondaryBarWindow.gap
                screenWidth: secondaryBarWindow.screen ? secondaryBarWindow.screen.width : width
                screenHeight: secondaryBarWindow.screen ? secondaryBarWindow.screen.height : height
            }

            TopSecondaryBar {
                anchors.fill: parent
            }
        }
    }

    // Floating Volume & Brightness On-Screen Display
    //
    // Pinned like every other window here: a PanelWindow without `screen:`
    // picks an output on its own, and not always the same one.
    VolumeBrightnessOSD { screen: primaryScreen }

    // Desktop Plasmoid System Monitor (Layer: Bottom, Non-restricting)
    SystemWidget {}

    // Full-screen transparent dismiss overlay (Layer: Top)
    PanelWindow {
        id: dismissOverlay
        screen: primaryScreen
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        visible: PopupService.anyOpen
        color: "transparent"

        WlrLayershell.layer: WlrLayershell.Top
        WlrLayershell.keyboardFocus: WlrLayershell.None

        MouseArea {
            anchors.fill: parent
            onClicked: PopupService.closeAll()
        }
    }

    // Top Bar Container Window (Layer: Top)
    PanelWindow {
        id: window
        screen: primaryScreen

        // Edge to edge when a window owns the screen: the gap around the bar
        // is there to show the desktop through it, and with a maximized
        // window there is no desktop left to show.
        //
        // The gap is animated rather than switched. It drives the margins and,
        // through them, the reserved area, so the maximized window underneath
        // travels with the bar instead of jumping a frame later.
        readonly property bool filled: window.screen
                                       && TaskService.filledScreens.indexOf(window.screen.name) >= 0
        readonly property int restGap: 10
        property real gap: filled ? 0 : restGap

        Behavior on gap {
            NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
        }

        anchors {
            top: true
            left: true
            right: true
        }
        margins {
            top: Math.round(window.gap)
            left: Math.round(window.gap)
            right: Math.round(window.gap)
        }

        // Reserves real screen space: since the bar is always visible, a
        // maximized window should start below it, not hidden underneath.
        //
        // The zone is set by hand and steps between two values rather than
        // following the animated margins. Left on automatic it would be
        // recomputed on every frame of the slide, and the window underneath
        // would be resized sixty times for one transition.
        WlrLayershell.layer: WlrLayershell.Top
        exclusiveZone: Theme.barHeight + (window.filled ? 0 : window.restGap)

        implicitHeight: Theme.barHeight
        color: "transparent"

        // One slab from edge to edge instead of three floating pills with dead
        // space between them. The glass is the wallpaper itself, blurred: see
        // GlassSurface for why that is honest rather than a fake.
        GlassSurface {
            anchors.fill: parent
            // Corners open up as the bar reaches the screen edges, from the
            // same number, so the two never disagree mid-flight.
            radius: Theme.radiusCard * (window.gap / window.restGap)
            surfaceX: window.gap
            surfaceY: window.gap
            screenWidth: window.screen ? window.screen.width : width
            screenHeight: window.screen ? window.screen.height : height
        }

        TopLeftBar {
            id: topLeftBar
            anchors.left: parent.left
            anchors.top: parent.top
        }

        TopCenterBar {
            id: topCenterBar
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
        }

        TopRightBar {
            id: topRightBar
            anchors.right: parent.right
            anchors.top: parent.top
        }
    }

    // Bottom Dock Container Window (Layer: Top)
    PanelWindow {
        id: dockWindow
        screen: primaryScreen
        anchors {
            bottom: true
            left: true
            right: true
        }
        margins {
            bottom: 0
        }

        // Reserves no screen space: maximized windows get the whole screen
        // and the dock hides itself. The mask narrows what actually receives
        // hover/clicks to a thin strip at the edge while hidden, expanding to
        // the full window once revealed — otherwise anything near the bottom
        // of the screen would pop the dock open by accident.
        exclusionMode: ExclusionMode.Ignore
        property bool revealed: false
        // Two pixels: the dock should answer the edge of the screen, not the
        // neighbourhood of it. Paired with the dwell timer below, brushing
        // past the bottom no longer pops it open.
        property int hoverStripHeight: 2

        mask: Region {
            x: 0
            y: dockWindow.revealed ? 0 : dockWindow.height - dockWindow.hoverStripHeight
            width: dockWindow.width
            height: dockWindow.revealed ? dockWindow.height : dockWindow.hoverStripHeight
        }

        WlrLayershell.layer: WlrLayershell.Top
        implicitHeight: 66
        color: "transparent"

        HoverHandler {
            id: dockHover
            onHoveredChanged: {
                if (hovered) {
                    hideDockTimer.stop()
                    if (dockWindow.revealed) return
                    showDockTimer.restart()
                } else {
                    showDockTimer.stop()
                    hideDockTimer.restart()
                }
            }
        }

        // The pointer has to stay on the edge, not merely cross it.
        Timer {
            id: showDockTimer
            interval: 140
            onTriggered: if (dockHover.hovered) dockWindow.revealed = true
        }

        // While the context menu is open the pointer is usually over it (a
        // separate window), not over the dock, so the dock shouldn't hide
        // itself until the menu closes.
        Connections {
            target: PopupService
            function onDockMenuOpenChanged() {
                if (PopupService.dockMenuOpen) {
                    hideDockTimer.stop()
                    dockWindow.revealed = true
                } else if (!dockHover.hovered) {
                    hideDockTimer.restart()
                }
            }
        }

        Timer {
            id: hideDockTimer
            interval: 400
            onTriggered: {
                if (!PopupService.dockMenuOpen) {
                    dockWindow.revealed = false
                }
            }
        }

        BottomDock {
            id: bottomDock
            dockWindow: dockWindow
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: dockWindow.revealed ? 10 : -(implicitHeight + 20)
            Behavior on anchors.bottomMargin { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        }
    }

    // Backdrop Window: Catch clicks outside theme/wallpaper pickers to dismiss
    PanelWindow {
        id: pickerBackdrop
        screen: primaryScreen
        anchors { top: true; bottom: true; left: true; right: true }
        WlrLayershell.layer: WlrLayershell.Top
        exclusionMode: ExclusionMode.Ignore
        visible: PopupService.themePickerOpen || PopupService.wallpaperPickerOpen
        color: "transparent"

        MouseArea {
            anchors.fill: parent
            onClicked: PopupService.closeAll()
        }
    }

    // Theme Switcher Floating Overlay (Dedicated Window)
    PanelWindow {
        id: themePickerWindow
        screen: primaryScreen
        anchors {
            bottom: true
            right: true
        }
        margins {
            bottom: 74
            right: Math.max(20, Math.round((dockWindow.width - bottomDock.implicitWidth) / 2) + 48)
        }

        WlrLayershell.layer: WlrLayershell.Top
        exclusionMode: ExclusionMode.Ignore
        visible: PopupService.themePickerOpen
        implicitWidth: 440
        implicitHeight: 340
        color: "transparent"

        ThemePicker {
            anchors.fill: parent
        }
    }

    // Wallpaper Switcher Floating Overlay (Dedicated Window)
    PanelWindow {
        id: wallpaperPickerWindow
        screen: primaryScreen
        anchors {
            bottom: true
            right: true
        }
        margins {
            bottom: 74
            right: Math.max(20, Math.round((dockWindow.width - bottomDock.implicitWidth) / 2))
        }

        WlrLayershell.layer: WlrLayershell.Top
        exclusionMode: ExclusionMode.Ignore
        visible: PopupService.wallpaperPickerOpen
        implicitWidth: 440
        implicitHeight: 340
        color: "transparent"

        WallpaperPicker {
            anchors.fill: parent
        }
    }

    // Application Launcher Overlay, and the dim behind it. The dim is its own
    // window on purpose: see LauncherDim.
    LauncherDim { progress: appLauncher.openProgress }
    AppLauncher { id: appLauncher }

    // Bottom-Right Notification Toast Overlay
    NotificationToast { screen: primaryScreen }

    // The theme's lockscreen overlay is disabled on purpose: Wayland's
    // session lock stops any ordinary app from drawing over the real lock
    // screen, so this overlay only showed up afterwards, asking for the
    // password a second time. The native greeter is used instead.
}
