import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import "modules/topbar"
import "modules/dock"
import "modules/launcher"
import "modules/wallpaper"
import "modules/notifications"
import "modules/desktop"
import "modules/lockscreen"
import "modules/osd"
import "services"

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

    // Monitor primário (confirmado via kscreen-doctor -o), usado por todas
    // as janelas abaixo para não caírem em telas diferentes por padrão.
    property var primaryScreen: Quickshell.screens.find(s => s.name === "DP-2") || Quickshell.screens[0]

    // Dynamic Theme Wallpaper (Layer: Background)
    WallpaperWindow {}

    // Floating Volume & Brightness On-Screen Display
    VolumeBrightnessOSD {}

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
        anchors {
            top: true
            left: true
            right: true
        }
        margins {
            top: 10
            left: 10
            right: 10
        }

        // Reserva espaço de verdade: como fica sempre visível, a janela
        // maximizada deve começar abaixo dela, não por baixo escondida.
        WlrLayershell.layer: WlrLayershell.Top
        implicitHeight: 40
        color: "transparent"

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

        // Não reserva espaço na tela: janelas maximizadas usam a tela
        // inteira e a dock some sozinha. O mask restringe o que realmente
        // recebe hover/clique: só uma faixa fina na borda quando oculta, a
        // janela inteira quando revelada (senão qualquer coisa perto do
        // fundo da tela reabria a dock à toa).
        exclusionMode: ExclusionMode.Ignore
        property bool revealed: false
        property int hoverStripHeight: 6

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
                    dockWindow.revealed = true
                } else {
                    hideDockTimer.restart()
                }
            }
        }

        // Com o menu de contexto aberto, o mouse costuma estar em cima dele
        // (uma janela separada), não da dock, então a dock não deveria
        // fechar sozinha enquanto o menu estiver aberto.
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

    // Application Launcher Overlay
    AppLauncher {}

    // Bottom-Right Notification Toast Overlay
    NotificationToast {}

    // Lockscreen overlay do tema desativado: o bloqueio real do Wayland não
    // deixa nada renderizar por cima da tela de bloqueio de verdade, então
    // esse overlay só aparecia depois, pedindo senha de novo à toa. A tela
    // nativa (Breeze) já está estilizada com o esquema Tokyo Night.
}
