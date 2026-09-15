import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import "../../components"
import "../../services"
import "../../theme"

// Full-screen application launcher.
//
// Two voices, on purpose: what the person writes and reads (the query, app
// names, categories) is Inter; what the machine reports (counts, the
// calculator result, the key hints) is the same mono face the terminal uses.
// That split is the launcher's whole identity, so the panel itself stays
// plain — one rule, one filled selection block, no card-in-card chrome.
PanelWindow {
    id: root

    screen: Quickshell.screens.find(s => s.name === "DP-2") || Quickshell.screens[0]
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.keyboardFocus: WlrLayershell.Exclusive

    readonly property bool open: PopupService.appLauncherOpen && !LockscreenService.isLocked

    visible: root.open

    // Currently highlighted app index for keyboard navigation
    property int selectedIndex: 0

    readonly property bool searching: searchField.text.length > 0

    // Math Evaluator Result
    property string mathResult: {
        let txt = searchField.text.trim()
        if (!txt || !/^[\d\s\+\-\*\/\(\)\.\%\^]+$/.test(txt) || !/\d/.test(txt)) return ""
        try {
            let clean = txt.replace(/\^/g, "**")
            let res = Function('"use strict"; return (' + clean + ')')()
            if (typeof res === "number" && !isNaN(res) && isFinite(res)) {
                return String(res)
            }
        } catch (e) {}
        return ""
    }

    // ── Open / Close animation state ─────────────────────────────────────
    property real openProgress: 0.0

    NumberAnimation on openProgress {
        id: openAnim
        running: false
        to: 1.0
        duration: 250
        easing.type: Easing.OutCubic
    }

    NumberAnimation on openProgress {
        id: closeAnim
        running: false
        to: 0.0
        duration: 180
        easing.type: Easing.InCubic
        onFinished: PopupService.appLauncherOpen = false
    }

    onOpenChanged: {
        if (open) {
            closeAnim.running = false
            openProgress = 0.0
            openAnim.restart()
            AppLauncherService.reset()
            AppLauncherService.reload()
            searchField.text = ""
            root.selectedIndex = 0
            contextMenu.opened = false
            Qt.callLater(() => {
                searchField.forceActiveFocus()
                if (appGrid.count > 0) appGrid.positionViewAtIndex(0, GridView.Contain)
            })
        } else {
            // Closing through PopupService directly, as the shortcut and
            // closeAll() do, skips the close animation and used to leave
            // openProgress at 1. That did not show while the dim lived in this
            // window, because the window went with it; now the dim is its own
            // window and a stale progress leaves the screen darkened with
            // nothing on it.
            openAnim.running = false
            closeAnim.running = false
            openProgress = 0.0
        }
    }

    function closeWithAnimation() {
        openAnim.running = false
        closeAnim.restart()
    }

    function launchSelected() {
        let list = AppLauncherService.filteredApps
        if (root.selectedIndex >= 0 && root.selectedIndex < list.length) {
            AppLauncherService.launch(list[root.selectedIndex])
            root.closeWithAnimation()
        }
    }

    // Opens the context menu for whatever the keyboard is on, centred under
    // the tile so it reads the same as a right-click.
    function openMenuForSelection() {
        let list = AppLauncherService.filteredApps
        if (root.selectedIndex < 0 || root.selectedIndex >= list.length) return
        let item = appGrid.itemAtIndex(root.selectedIndex)
        if (!item) return
        let pt = item.mapToItem(null, item.width / 2, item.height / 2)
        contextMenu.openAt(pt.x, pt.y, list[root.selectedIndex])
    }

    // The dim lives in LauncherDim, a window that stays mapped so KWin has
    // no surface mapping to animate. See the note there. Dismissing on a click
    // outside the panel stays here, where the input is.
    MouseArea {
        anchors.fill: parent
        onClicked: root.closeWithAnimation()
    }

    // ── Center launcher panel ────────────────────────────────────────────
    Item {
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.88, 1080)
        height: Math.min(parent.height * 0.85, 740)

        focus: root.open
        Keys.onEscapePressed: root.closeWithAnimation()

        opacity: Math.max(0.0, Math.min(1.0, root.openProgress))
        scale: 0.88 + 0.12 * root.openProgress

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusCard
            color: Theme.bg
            border.color: Theme.separator
            border.width: 1

            Behavior on color { ColorAnimation { duration: 150 } }

            // Stop clicks from falling through to dim background
            MouseArea { anchors.fill: parent; onClicked: {} }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.sp5 + Theme.sp1
                spacing: Theme.sp4

                // ── Query line ────────────────────────────────────────────
                // No box, no icon, no border: on a panel that exists only to
                // be typed into, a search field does not need to announce
                // itself as one.
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.sp4

                    TextInput {
                        id: searchField
                        focus: true
                        Layout.fillWidth: true
                        color: Theme.fg
                        font.pixelSize: Theme.fsDisplay
                        font.family: Theme.fontFamily
                        font.weight: Font.Light
                        selectionColor: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35)
                        selectedTextColor: Theme.fg
                        clip: true

                        cursorDelegate: Rectangle {
                            width: 2
                            color: Theme.accent

                            SequentialAnimation on opacity {
                                loops: Animation.Infinite
                                running: searchField.activeFocus
                                NumberAnimation { to: 0; duration: 520; easing.type: Easing.InOutQuad }
                                NumberAnimation { to: 1; duration: 520; easing.type: Easing.InOutQuad }
                            }
                        }

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: "Search or calculate"
                            color: Theme.textMuted
                            font.pixelSize: Theme.fsDisplay
                            font.family: Theme.fontFamily
                            font.weight: Font.Light
                            visible: !searchField.text
                        }

                        onTextChanged: {
                            AppLauncherService.searchQuery = text
                            root.selectedIndex = 0
                            contextMenu.close()
                            if (appGrid.count > 0) appGrid.positionViewAtIndex(0, GridView.Contain)
                        }

                        Keys.onPressed: (event) => {
                            if (event.key === Qt.Key_Escape) {
                                if (contextMenu.opened) contextMenu.close()
                                else root.closeWithAnimation()
                                event.accepted = true
                                return
                            }

                            // Shift+F10 and the Menu key are what every other
                            // desktop uses to open a context menu by keyboard.
                            if (event.key === Qt.Key_Menu
                                    || (event.key === Qt.Key_F10 && (event.modifiers & Qt.ShiftModifier))) {
                                root.openMenuForSelection()
                                event.accepted = true
                                return
                            }

                            let count = AppLauncherService.filteredApps.length
                            if (count === 0) return

                            let cols = Math.max(1, Math.floor(appGrid.width / appGrid.cellWidth))

                            if (event.key === Qt.Key_Right) {
                                root.selectedIndex = Math.min(count - 1, root.selectedIndex + 1)
                                appGrid.positionViewAtIndex(root.selectedIndex, GridView.Contain)
                                event.accepted = true
                            } else if (event.key === Qt.Key_Left) {
                                root.selectedIndex = Math.max(0, root.selectedIndex - 1)
                                appGrid.positionViewAtIndex(root.selectedIndex, GridView.Contain)
                                event.accepted = true
                            } else if (event.key === Qt.Key_Down) {
                                root.selectedIndex = Math.min(count - 1, root.selectedIndex + cols)
                                appGrid.positionViewAtIndex(root.selectedIndex, GridView.Contain)
                                event.accepted = true
                            } else if (event.key === Qt.Key_Up) {
                                root.selectedIndex = Math.max(0, root.selectedIndex - cols)
                                appGrid.positionViewAtIndex(root.selectedIndex, GridView.Contain)
                                event.accepted = true
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                root.launchSelected()
                                event.accepted = true
                            }
                        }
                    }

                    // What the machine knows, in the machine's voice.
                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        text: appGrid.count + (appGrid.count === 1 ? " app" : " apps")
                        color: Theme.textMuted
                        font.pixelSize: Theme.fsCaption
                        font.family: Theme.fontMono
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    Layout.topMargin: -Theme.sp2
                    color: Theme.separator
                }

                // ── Calculator result ─────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    visible: root.mathResult !== ""
                    spacing: Theme.sp3

                    Text {
                        text: searchField.text.trim() + " ="
                        color: Theme.textMuted
                        font.pixelSize: Theme.fsSubhead
                        font.family: Theme.fontMono
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.mathResult
                        color: Theme.accent
                        font.pixelSize: Theme.fsSubhead
                        font.family: Theme.fontMono
                        font.weight: Font.Medium
                    }

                    Text {
                        text: copyMouse.containsMouse ? "copied on click" : "copy"
                        color: copyMouse.containsMouse ? Theme.accent : Theme.textMuted
                        font.pixelSize: Theme.fsCaption
                        font.family: Theme.fontMono

                        MouseArea {
                            id: copyMouse
                            anchors.fill: parent
                            anchors.margins: -Theme.sp2
                            hoverEnabled: true
                            onClicked: Quickshell.execDetached(["wl-copy", root.mathResult])
                        }
                    }
                }

                // ── Categories ────────────────────────────────────────────
                // Text, not pills: these are a place in a list, not buttons.
                //
                // Recent and Favorites lead the row, kept apart by a rule:
                // they come from how this person uses the launcher, the rest
                // comes from the desktop files.
                RowLayout {
                    id: catRow
                    Layout.fillWidth: true
                    Layout.preferredHeight: 26
                    spacing: Theme.sp4

                    CategoryLabel {
                        label: AppLauncherService.recentCategory
                        visible: AppLauncherService.recentApps.length > 0
                    }

                    CategoryLabel {
                        label: AppLauncherService.favoritesCategory
                        visible: AppLauncherService.favoriteApps.length > 0
                    }

                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 14
                        Layout.alignment: Qt.AlignVCenter
                        color: Theme.separator
                        visible: AppLauncherService.recentApps.length > 0
                                 || AppLauncherService.favoriteApps.length > 0
                    }

                    ListView {
                        id: categoryList
                        Layout.fillWidth: true
                        // Fixed, never fillHeight: the delegate used to take
                        // its height from the list while the list measured
                        // itself from the delegate, and the row swallowed the
                        // whole panel.
                        Layout.preferredHeight: 26
                        Layout.alignment: Qt.AlignTop
                        orientation: ListView.Horizontal
                        model: AppLauncherService.categories
                        spacing: Theme.sp4
                        clip: true

                        ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AlwaysOff }

                        delegate: CategoryLabel {
                            required property string modelData
                            label: modelData
                        }
                    }
                }

                // ── Application grid ──────────────────────────────────────
                Item {
                    id: gridWrap
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    // Without a zero minimum the grid refuses to shrink and
                    // the last row ends up drawn outside the panel.
                    Layout.minimumHeight: 0

                    GridView {
                        id: appGrid
                        anchors.fill: parent
                        clip: true

                        model: AppLauncherService.filteredApps
                        cellWidth: Math.floor(width / Math.max(1, Math.floor(width / 132)))
                        cellHeight: 130

                        ScrollBar.vertical: ScrollBar {
                            // The custom contentItem does not inherit the
                            // policy's own hiding, so say it outright.
                            visible: appGrid.contentHeight > appGrid.height
                            policy: ScrollBar.AsNeeded
                            contentItem: Rectangle {
                                implicitWidth: 3
                                radius: 1.5
                                color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.4)
                            }
                            background: Rectangle { color: "transparent" }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: appGrid.count === 0
                            text: root.searching
                              ? "Nothing matches " + '"' + searchField.text + '"'
                              : "Nothing here yet"
                            color: Theme.textMuted
                            font.pixelSize: Theme.fsBody
                            font.family: Theme.fontFamily
                        }

                        delegate: AppTile {
                            id: tile
                            required property var modelData
                            required property int index

                            width: appGrid.cellWidth
                            height: appGrid.cellHeight

                            app: modelData
                            selected: index === root.selectedIndex
                            interactive: !contextMenu.opened

                            // The one orchestrated moment: tiles arrive column by
                            // column as the panel opens, and never animate again.
                            opacity: {
                                let cols = Math.max(1, Math.floor(appGrid.width / appGrid.cellWidth))
                                let delay = (index % cols) * 0.06
                                return Math.max(0, Math.min(1, (root.openProgress - delay) * 4))
                            }

                            onHoverEntered: root.selectedIndex = index
                            onActivated: {
                                root.selectedIndex = index
                                AppLauncherService.launch(modelData)
                                root.closeWithAnimation()
                            }
                            onContextRequested: (gx, gy) => contextMenu.openAt(gx, gy, modelData)
                        }
                    }

                    // The grid scrolls, so the last visible row is usually cut
                    // in half. Fading it into the panel keeps that cut from
                    // reading as a broken row. Kept outside the GridView,
                    // which would scroll it away with the rows.
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: Theme.sp5 + Theme.sp4
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 1.0; color: Theme.bg }
                        }
                    }
                }
            }
        }
    }

    // Drawn last so it sits above the panel; it fills the whole surface and
    // positions its own card.
    AppContextMenu {
        id: contextMenu
    }

    // ── One entry in the category row ────────────────────────────────────
    component CategoryLabel: Item {
        id: cat
        property string label: ""
        readonly property bool isActive: label === AppLauncherService.activeCategory

        Layout.preferredWidth: implicitWidth
        implicitWidth: catText.implicitWidth
        implicitHeight: 26

        Text {
            id: catText
            anchors.top: parent.top
            text: cat.label
            color: cat.isActive
                   ? Theme.accent
                   : (catMouse.containsMouse ? Theme.fg : Theme.textMuted)
            font.pixelSize: Theme.fsBody
            font.family: Theme.fontFamily
            font.weight: cat.isActive ? Font.Medium : Font.Normal

            Behavior on color { ColorAnimation { duration: 120 } }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: catText.bottom
            anchors.topMargin: 5
            height: 2
            radius: 1
            color: Theme.accent
            opacity: cat.isActive ? 1 : 0

            Behavior on opacity { NumberAnimation { duration: 120 } }
        }

        MouseArea {
            id: catMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
                AppLauncherService.activeCategory = cat.label
                root.selectedIndex = 0
            }
        }
    }
}
