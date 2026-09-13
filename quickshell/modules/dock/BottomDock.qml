import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../../components"
import "../../services"
import "../../theme"

Item {
    id: root

    implicitWidth: dockGlass.implicitWidth
    implicitHeight: dockGlass.implicitHeight

    // Active Context Menu State
    property var contextTargetApp: null
    property int contextTargetX: 0

    function getParabolicScale(itemIndex, hoveredIndex) {
        if (hoveredIndex < 0) return 1.0;
        let dist = Math.abs(itemIndex - hoveredIndex);
        if (dist === 0) return 1.15;
        return 1.0;
    }

    // Ambient Background Accent Glow behind Dock
    Rectangle {
        anchors.fill: dockGlass
        anchors.margins: -6
        radius: 20
        color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.16)
    }

    GlassPanel {
        id: dockGlass
        implicitWidth: dockRow.implicitWidth + 24
        implicitHeight: 52
        anchors.centerIn: parent

        RowLayout {
            id: dockRow
            anchors.centerIn: parent
            spacing: 6

            property int activeDragIndex: -1
            property real activeDragXOffset: 0
            property int activeOffsetSpaces: Math.round(activeDragXOffset / 48.0)
            property int hoveredDockIndex: -1

            // 1. Distro Application Launcher Button
            Item {
                id: launcherBtn
                width: 42
                height: 42
                Layout.alignment: Qt.AlignVCenter

                property bool isHovered: launcherMouse.containsMouse

                // Subtle Hover Capsule Background
                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: launcherBtn.isHovered ? Qt.rgba(255/255, 255/255, 255/255, 0.08) : "transparent"

                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                // Distro / Cute Emoji Icon Container
                Item {
                    anchors.centerIn: parent
                    width: 26
                    height: 26
                    scale: launcherBtn.isHovered ? 1.15 : 1.0

                    Behavior on scale {
                        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "▦"
                        font.pixelSize: 22
                        font.bold: true
                        color: Theme.fg
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                // Launcher Mouse Area
                MouseArea {
                    id: launcherMouse
                    anchors.fill: parent
                    hoverEnabled: true

                    onClicked: {
                        TaskService.toggleLauncher()
                    }
                }

            }

            // 2. Left Vertical Separator Line
            Rectangle {
                width: 1
                height: 22
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: 2
                Layout.rightMargin: 2
                color: Theme.separator
            }

            // Combined Unified Dock Items (Pinned Apps + Unpinned Running Apps)
            Repeater {
                id: dockRepeater
                model: TaskService.allDockApps

                Item {
                    id: dockItem
                    width: 42
                    height: 42
                    Layout.alignment: Qt.AlignVCenter

                    property string appId: modelData.appId

                    // Separator between pinned apps and open (unpinned) ones
                    Rectangle {
                        visible: index > 0 && !modelData.isPinned && TaskService.allDockApps[index - 1].isPinned
                        width: 1
                        height: 22
                        color: Theme.separator
                        anchors.verticalCenter: parent.verticalCenter
                        x: -(dockRow.spacing / 2) - width / 2
                    }

                    property bool isHovered: itemMouse.containsMouse
                    property bool isAppRunning: TaskService.isRunning(modelData.appId)
                    property bool isAppActive: TaskService.isActive(modelData.appId)
                    property bool isDraggingThis: itemMouse.isDragActive

                    property real shiftX: {
                        let dragIdx = dockRow.activeDragIndex
                        if (dragIdx < 0 || dragIdx === index) return 0.0;
                        let spaces = dockRow.activeOffsetSpaces
                        if (spaces > 0 && index > dragIdx && index <= dragIdx + spaces) {
                            return -48.0
                        } else if (spaces < 0 && index < dragIdx && index >= dragIdx + spaces) {
                            return 48.0
                        }
                        return 0.0
                    }

                    // Visual Content Container (Translates smoothly without moving MouseArea)
                    Item {
                        id: visualContainer
                        anchors.fill: parent
                        scale: isDraggingThis ? 1.2 : root.getParabolicScale(index, dockRow.hoveredDockIndex)
                        z: isDraggingThis ? 99 : 1

                        Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }

                        transform: Translate {
                            x: isDraggingThis ? itemMouse.dragXOffset : dockItem.shiftX
                            Behavior on x {
                                NumberAnimation {
                                    duration: isDraggingThis ? 0 : 250
                                    easing.type: Easing.OutBack
                                }
                            }
                        }

                        // Soft Active / Hover Background Capsule (Ambient Glass Rim)
                        Rectangle {
                            anchors.fill: parent
                            radius: 10
                            color: isAppActive 
                                ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18) 
                                : (isHovered ? Qt.rgba(255/255, 255/255, 255/255, 0.08) : "transparent")
                            border.color: isAppActive 
                                ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.65) 
                                : (isHovered ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.30) : "transparent")
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on border.color { ColorAnimation { duration: 120 } }
                        }

                        // Scalable Icon Container (Uniform 26x26 size)
                        Item {
                            anchors.centerIn: parent
                            width: 26
                            height: 26

                            Image {
                                anchors.fill: parent
                                sourceSize.width: 26
                                sourceSize.height: 26
                                fillMode: Image.PreserveAspectFit
                                source: getIconPath(modelData.icon || modelData.appId)
                            }
                        }

                        // Running / Active Indicator Bar at Bottom (Vibrant Glowing Indicator)
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 3
                            height: 3.5
                            width: isAppActive ? 16 : (isAppRunning ? 6 : 0)
                            radius: 1.75
                            color: isAppActive ? Theme.accent : Theme.subAccent
                            visible: isAppRunning || isAppActive

                            Behavior on width {
                                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                            }
                        }

                    }

                    // Mouse Interaction Area (Fixed Layout Sibling - Supports Pinned Reorder & Unpinned Bounce-Back)
                    MouseArea {
                        id: itemMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton

                        onEntered: {
                            dockRow.hoveredDockIndex = index
                        }

                        onExited: {
                            if (dockRow.hoveredDockIndex === index) dockRow.hoveredDockIndex = -1
                        }

                        property real dragXOffset: 0
                        property real pressStartX: 0
                        property bool isDragActive: false

                        drag.axis: Drag.XAxis
                        drag.minimumX: -(index * 48)
                        drag.maximumX: (TaskService.allDockApps.length - 1 - index) * 48

                        onPressed: (mouse) => {
                            if (PopupService.anyOpen || root.contextTargetApp !== null) {
                                return
                            }
                            if (mouse.button === Qt.LeftButton) {
                                pressStartX = mouse.x
                                isDragActive = false
                                dragXOffset = 0
                                dockRow.activeDragIndex = index
                                dockRow.activeDragXOffset = 0
                            }
                        }

                        onPositionChanged: (mouse) => {
                            if (pressed && (mouse.buttons & Qt.LeftButton)) {
                                dragXOffset = mouse.x - pressStartX
                                if (Math.abs(dragXOffset) > 6) {
                                    isDragActive = true
                                }
                                dockRow.activeDragXOffset = dragXOffset
                            }
                        }

                        onReleased: (mouse) => {
                            let wasDragging = isDragActive
                            let finalOffset = dragXOffset

                            // Reset state immediately (for unpinned apps, dragXOffset reset triggers smooth OutBack bounce-back)
                            dragXOffset = 0
                            isDragActive = false
                            dockRow.activeDragIndex = -1
                            dockRow.activeDragXOffset = 0

                            if (mouse.button === Qt.RightButton) {
                                root.isPreviewHovered = false
                                root.isCardHovered = false
                                previewCloseTimer.stop()

                                let isSameApp = (root.contextTargetApp === modelData && PopupService.dockMenuOpen)
                                PopupService.closeAll()

                                if (!isSameApp) {
                                    root.contextTargetApp = modelData
                                    let targetParent = root.dockWindow ? root.dockWindow.contentItem : root
                                    let posInWindow = itemMouse.mapToItem(targetParent, 0, 0).x
                                    root.contextTargetX = Math.round(posInWindow)

                                    dockContextMenu.visible = true
                                    PopupService.dockMenuOpen = true
                                } else {
                                    root.contextTargetApp = null
                                }
                                return
                            }

                            if (PopupService.anyOpen || root.contextTargetApp !== null) {
                                PopupService.closeAll()
                                root.contextTargetApp = null
                                root.previewActive = false
                                return
                            }

                            if (wasDragging) {
                                if (modelData.isPinned) {
                                    let offsetSpaces = Math.round(finalOffset / 48.0)
                                    let targetIndex = Math.max(0, Math.min(TaskService.pinnedApps.length - 1, index + offsetSpaces))
                                    if (targetIndex !== index) {
                                        TaskService.reorderPinnedApps(index, targetIndex)
                                    }
                                }
                            } else if (mouse.button === Qt.LeftButton) {
                                let instances = TaskService.isRunning(modelData.appId) ? TaskService.getWindowsForApp(modelData.appId) : []
                                if (instances && instances.length > 1) {
                                    // More than one window: show the picker cards, on click only.
                                    let targetParent = root.dockWindow ? root.dockWindow.contentItem : root
                                    let pt = itemMouse.mapToItem(targetParent, 0, 0)
                                    root.previewTargetX = Math.round(pt.x + itemMouse.width / 2)
                                    root.previewTargetApp = modelData
                                    root.previewWindowInstances = instances
                                    root.previewActive = true
                                    previewCloseTimer.restart()
                                } else {
                                    root.previewActive = false
                                    root.isPreviewHovered = false
                                    root.isCardHovered = false
                                    previewCloseTimer.stop()
                                    TaskService.clearOriginalActiveWin()
                                    let globalPos = itemMouse.mapToItem(root, 0, 0)
                                    TaskService.focusApp(modelData.appId, modelData.cmd, globalPos.x, globalPos.y)
                                }
                            }
                        }
                    }
                }
            }

        }
    }

    // Helper: Compute combined list of Pinned Apps + Unpinned Running Windows
    function getCombinedDockModel() {
        let list = Array.from(TaskService.pinnedApps)
        let pinnedIds = list.map(a => a.appId.toLowerCase())

        // Append unpinned running apps
        if (TaskService.runningWindows) {
            for (let i = 0; i < TaskService.runningWindows.length; i++) {
                let win = TaskService.runningWindows[i]
                let app = (win.appId || "").toLowerCase()
                if (app !== "" && !pinnedIds.includes(app)) {
                    pinnedIds.push(app)
                    list.push({
                        appId: win.appId,
                        name: win.title || win.appId,
                        icon: win.appId,
                        cmd: win.appId,
                        toplevel: win.toplevel
                    })
                }
            }
        }
        return list
    }

    // Helper: Icon Path Resolver with Dynamic Path Support
    function getIconPath(iconName) {
        let baseDir = Theme.iconsDir || "/usr/share/icons"
        if (!iconName || iconName === "") {
            return AppLauncherService.fallbackIconPath ? "file://" + AppLauncherService.fallbackIconPath : "file://" + baseDir + "/Papirus/64x64/apps/application-default-icon.svg"
        }
        let name = iconName.trim()
        if (name.startsWith("file://")) return name
        if (name.startsWith("/")) return "file://" + name

        let clean = name.toLowerCase().replace(/\.desktop$/, "")

        // 1. Dynamic lookup in AppLauncherService iconMap (resolves Flatpak & native app icons dynamically!)
        if (AppLauncherService.iconMap && AppLauncherService.iconMap[clean]) {
            let mapped = AppLauncherService.iconMap[clean]
            return mapped.startsWith("file://") ? mapped : "file://" + mapped
        }

        // 1b. Some apps report a window class that doesn't match their .desktop
        // id at all (Heroic reports "com.heroicgameslauncher.hgl" to KWin, but
        // the installed .desktop is "heroic"). Try a substring match against
        // known apps before falling back to the generic icon.
        if (AppLauncherService.allApps) {
            for (let i = 0; i < AppLauncherService.allApps.length; i++) {
                let app = AppLauncherService.allApps[i]
                let appId = (app.id || "").toLowerCase().replace(/\.desktop$/, "")
                if (!appId || !app.icon) continue;
                if (clean.includes(appId) || appId.includes(clean)) {
                    return app.icon.startsWith("file://") ? app.icon : "file://" + app.icon
                }
            }
        }

        // 2. Hardcoded fallback overrides for common system apps & games
        let themeDir = Theme.iconTheme
        if (clean.includes("overwatch") || clean.includes("2357570")) {
            return "file://" + baseDir + "/" + themeDir + "/64x64/apps/overwatch.svg"
        }
        if (clean.includes("heroic")) return "file://" + baseDir + "/" + themeDir + "/32x32/apps/heroic.svg"
        if (clean.includes("alacritty")) return "file://" + baseDir + "/" + themeDir + "/32x32/apps/Alacritty.svg"
        if (clean.includes("dolphin")) return "file://" + baseDir + "/" + themeDir + "/32x32/apps/org.kde.dolphin.svg"
        if (clean.includes("firefox")) return "file://" + baseDir + "/" + themeDir + "/32x32/apps/firefox.svg"
        if (clean.includes("code") || clean.includes("visualstudio")) return "file://" + baseDir + "/" + themeDir + "/32x32/apps/com.visualstudio.code.svg"
        if (clean.includes("kate")) return "file://" + baseDir + "/" + themeDir + "/32x32/apps/kate.svg"

        return AppLauncherService.fallbackIconPath ? "file://" + AppLauncherService.fallbackIconPath : "file://" + baseDir + "/Papirus/64x64/apps/application-default-icon.svg"
    }

    // Helper: Formatted Program Name Cleaner
    function getCleanProgramName(app) {
        if (!app) return "Application";
        if (app.name && app.name !== "" && app.name !== app.appId && app.name !== "Steam Game (2357570)") return app.name;
        let id = app.appId || "";
        if (!id) return "Application";
        let raw = id.includes(".") ? id.split(".").pop() : id;
        raw = raw.replace(/[-_]/g, " ");
        let lower = raw.toLowerCase();
        if (lower.includes("overwatch") || lower.includes("2357570")) return "Overwatch 2";
        if (lower === "alacritty") return "Alacritty";
        if (lower === "dolphin") return "Dolphin";
        if (lower === "firefox") return "Firefox";
        if (lower === "code" || lower === "visualstudio") return "VS Code";
        if (lower === "kate") return "Kate";
        if (lower === "spectacle") return "Spectacle";
        if (lower === "zen" || lower.includes("zen")) return "Zen Browser";
        if (lower === "antigravity" || lower.includes("antigravity")) return "Antigravity";
        if (lower === "equibop" || lower.includes("discord")) return "Discord";
        return raw.charAt(0).toUpperCase() + raw.slice(1);
    }

    function getToplevelForWindow(winObj) {
        if (!winObj || typeof ToplevelManager === "undefined" || !ToplevelManager.toplevels) return null;
        let list = ToplevelManager.toplevels.values;
        if (!list || list.length === 0) return null;

        let targetApp = (winObj.appId || "").toLowerCase().trim();
        let targetTitle = (winObj.caption || winObj.name || "").toLowerCase().trim();

        for (let i = 0; i < list.length; i++) {
            let t = list[i];
            if (!t) continue;
            let tApp = (t.appId || "").toLowerCase().trim();
            let tTitle = (t.title || "").toLowerCase().trim();

            if (tApp === targetApp || (tApp && targetApp && (tApp.includes(targetApp) || targetApp.includes(tApp)))) {
                if (!targetTitle || tTitle.includes(targetTitle) || targetTitle.includes(tTitle)) {
                    return t;
                }
            }
        }

        for (let i = 0; i < list.length; i++) {
            let t = list[i];
            if (!t) continue;
            let tApp = (t.appId || "").toLowerCase().trim();
            if (tApp === targetApp || (tApp && targetApp && (tApp.includes(targetApp) || targetApp.includes(tApp)))) {
                return t;
            }
        }

        return null;
    }

    function calculateCardsRowWidth(instances) {
        if (!instances || !Array.isArray(instances) || instances.length === 0) return 230;
        let count = Math.min(3, instances.length);
        let cardW = 230;
        let totalW = count * cardW + Math.max(0, (count - 1) * 8);
        return totalW;
    }

    property var dockWindow: null

    // Window Preview Hover State Properties
    property var previewTargetApp: null
    property var previewWindowInstances: []
    property int previewTargetX: 0
    property bool isPreviewHovered: false
    property bool isCardHovered: false
    property bool previewActive: false

    onPreviewActiveChanged: {
        PopupService.previewOpen = root.previewActive
    }

    onContextTargetAppChanged: {
        PopupService.contextMenuOpen = (root.contextTargetApp !== null)
        PopupService.dockMenuOpen = (root.contextTargetApp !== null)
    }

    Connections {
        target: PopupService
        function onPreviewOpenChanged() {
            if (!PopupService.previewOpen && root.previewActive) {
                root.previewActive = false
                root.isPreviewHovered = false
                root.isCardHovered = false
                previewCloseTimer.stop()
                TaskService.previewRestoreWindow()
            }
        }
        function onDockMenuOpenChanged() {
            if (!PopupService.dockMenuOpen && root.contextTargetApp !== null) {
                root.contextTargetApp = null
                dockContextMenu.visible = false
            }
        }
        function onContextMenuOpenChanged() {
            if (!PopupService.contextMenuOpen && root.contextTargetApp !== null) {
                root.contextTargetApp = null
                dockContextMenu.visible = false
            }
        }
    }

    Timer {
        id: previewCloseTimer
        interval: 400
        repeat: false
        onTriggered: {
            if (!root.isPreviewHovered && !previewMouseArea.containsMouse && !root.isCardHovered) {
                root.previewActive = false
                root.isPreviewHovered = false
                root.isCardHovered = false
                TaskService.previewRestoreWindow()
            }
        }
    }

    // Live Window Preview Floating Popup Window (Stationary Wayland Surface with Animated Interior Glass)
    PopupWindow {
        id: dockWindowPreview
        anchor.window: root.dockWindow
        anchor.rect.x: 0
        anchor.rect.y: 0
        anchor.edges: Edges.Top | Edges.Left
        anchor.gravity: Edges.Top | Edges.Right
        visible: root.previewActive && (root.previewWindowInstances && root.previewWindowInstances.length > 0)
        color: "transparent"

        implicitWidth: root.dockWindow ? root.dockWindow.width : 1200
        implicitHeight: previewGlass.implicitHeight + 4

        // Click outside preview card anywhere on the surface -> dismiss preview immediately
        MouseArea {
            anchors.fill: parent
            onClicked: {
                root.previewActive = false
                root.isPreviewHovered = false
                root.isCardHovered = false
                previewCloseTimer.stop()
                TaskService.previewRestoreWindow()
            }
        }

        Item {
            id: previewGlassContainer
            width: previewGlass.implicitWidth
            height: previewGlass.implicitHeight
            y: 0

            x: {
                let pWidth = previewGlass.implicitWidth
                let winWidth = root.dockWindow ? root.dockWindow.width : 1200
                let targetLeft = root.previewTargetX - Math.round(pWidth / 2)
                return Math.max(10, Math.min(winWidth - pWidth - 10, targetLeft))
            }

            Behavior on x {
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }

            MouseArea {
                id: previewMouseArea
                anchors.fill: parent
                anchors.margins: -12
                anchors.bottomMargin: -20
                hoverEnabled: true
                onEntered: {
                    previewCloseTimer.stop()
                    root.previewActive = true
                }
                onExited: {
                    if (!root.isPreviewHovered) {
                        previewCloseTimer.restart()
                    }
                }
            }

            GlassPanel {
                id: previewGlass
                implicitWidth: previewMainCol.implicitWidth + 24
                implicitHeight: previewMainCol.implicitHeight + 16
                anchors.fill: parent

                ColumnLayout {
                    id: previewMainCol
                    anchors.centerIn: parent
                    spacing: 8

                    // Compact Header: App Title & Instance Count
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Item {
                            width: 16
                            height: 16
                            Layout.alignment: Qt.AlignVCenter

                            Image {
                                anchors.fill: parent
                                sourceSize.width: 16
                                sourceSize.height: 16
                                fillMode: Image.PreserveAspectFit
                                source: root.getIconPath(root.previewTargetApp ? root.previewTargetApp.icon : "")
                            }
                        }

                        Text {
                            text: root.previewTargetApp ? root.getCleanProgramName(root.previewTargetApp) : "Windows"
                            color: Theme.fg
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            height: 18
                            width: countTxt.implicitWidth + 12
                            radius: 9
                            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                            border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.40)
                            border.width: 1
                            Layout.alignment: Qt.AlignVCenter

                            Text {
                                id: countTxt
                                anchors.centerIn: parent
                                text: root.previewWindowInstances ? (root.previewWindowInstances.length + (root.previewWindowInstances.length === 1 ? " Open" : " Open")) : "0"
                                color: Theme.accent
                                font.pixelSize: 9
                                font.weight: Font.Bold
                            }
                        }
                    }

                    // Window Preview Cards (Empilhados verticalmente)
                    ColumnLayout {
                        id: previewCardsRow
                        implicitWidth: 230
                        spacing: 8
                        Repeater {
                            model: 3

                            Item {
                                id: cardItem
                                property var winData: (root.previewWindowInstances && index < root.previewWindowInstances.length) ? root.previewWindowInstances[index] : null
                                visible: winData !== null

                                implicitWidth: 230
                                implicitHeight: 48
                                Layout.preferredWidth: implicitWidth
                                Layout.preferredHeight: implicitHeight

                                property bool cardHovered: cardMouseArea.containsMouse

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 8
                                    color: cardItem.cardHovered 
                                        ? Qt.rgba(255/255, 255/255, 255/255, 0.12) 
                                        : (cardItem.winData && cardItem.winData.active ? Qt.rgba(255/255, 255/255, 255/255, 0.07) : Qt.rgba(0, 0, 0, 0.35))
                                    border.color: (cardItem.winData && cardItem.winData.active) 
                                        ? Theme.accent 
                                        : (cardItem.cardHovered ? Theme.subAccent : Qt.rgba(255/255, 255/255, 255/255, 0.08))
                                    border.width: (cardItem.winData && cardItem.winData.active) || cardItem.cardHovered ? 1.5 : 1

                                    Behavior on color { ColorAnimation { duration: 120 } }
                                    Behavior on border.color { ColorAnimation { duration: 120 } }

                                    MouseArea {
                                        id: cardMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        onEntered: {
                                            root.isCardHovered = true
                                            root.previewActive = true
                                            previewCloseTimer.stop()
                                        }
                                        onExited: {
                                            root.isCardHovered = false
                                            previewCloseTimer.restart()
                                        }
                                        onPressed: (mouse) => {
                                            TaskService.clearOriginalActiveWin()
                                        }
                                        onClicked: (mouse) => {
                                            TaskService.clearOriginalActiveWin()
                                            root.previewActive = false
                                            root.isPreviewHovered = false
                                            root.isCardHovered = false
                                            previewCloseTimer.stop()
                                            if (cardItem.winData) {
                                                if (mouse.button === Qt.RightButton) {
                                                    dockContextMenu.visible = true
                                                    PopupService.dockMenuOpen = true
                                                } else {
                                                    let globalPos = cardItem.mapToItem(root, 0, 0)
                                                    TaskService.focusSpecificWindow(cardItem.winData, globalPos.x, globalPos.y)
                                                }
                                            }
                                        }
                                    }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 8
                                        spacing: 8

                                        // Active Window Indicator Bar (Constant 16px height, highlighted color when active)
                                        Rectangle {
                                            width: 3
                                            height: 16
                                            radius: 1.5
                                            color: (cardItem.winData && cardItem.winData.active) ? Theme.accent : Qt.rgba(255/255, 255/255, 255/255, 0.22)
                                            Layout.alignment: Qt.AlignVCenter

                                            Behavior on color { ColorAnimation { duration: 120 } }
                                        }

                                        // Window Caption & Status Subtitle
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            Layout.alignment: Qt.AlignVCenter
                                            spacing: 2

                                            Text {
                                                id: cardCaptionText
                                                text: cardItem.winData ? (cardItem.winData.caption || cardItem.winData.name || "Window") : ""
                                                color: (cardItem.winData && cardItem.winData.active) ? Theme.accent : Theme.fg
                                                font.pixelSize: 11
                                                font.weight: (cardItem.winData && cardItem.winData.active) ? Font.Bold : Font.Medium
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }

                                            Text {
                                                text: cardItem.winData ? ((cardItem.winData.active) ? "Active Window" : (cardItem.winData.minimized ? "Minimized" : "Click to focus")) : ""
                                                color: (cardItem.winData && cardItem.winData.active) ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.85) : Theme.comment
                                                font.pixelSize: 9
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                        }

                                        // Individual Window Close Button (✕)
                                        Item {
                                            width: 22
                                            height: 22
                                            z: 10
                                            Layout.alignment: Qt.AlignVCenter

                                            Rectangle {
                                                anchors.fill: parent
                                                radius: 11
                                                color: closeMouse.containsMouse ? Qt.rgba(255/255, 85/255, 85/255, 0.85) : Qt.rgba(255/255, 255/255, 255/255, 0.08)

                                                Behavior on color { ColorAnimation { duration: 100 } }
                                                Canvas {
                                                     anchors.centerIn: parent
                                                     width: 8
                                                     height: 8
                                                     onPaint: {
                                                         let ctx = getContext("2d")
                                                         ctx.strokeStyle = closeMouse.containsMouse ? "#ffffff" : Theme.comment
                                                         ctx.lineWidth = 1.4
                                                         ctx.beginPath()
                                                         ctx.moveTo(0, 0); ctx.lineTo(8, 8)
                                                         ctx.moveTo(8, 0); ctx.lineTo(0, 8)
                                                         ctx.stroke()
                                                     }
                                                 }

                                                MouseArea {
                                                    id: closeMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    acceptedButtons: Qt.LeftButton
                                                    onEntered: { root.isCardHovered = true; root.previewActive = true; previewCloseTimer.stop() }
                                                    onExited: { root.isCardHovered = false; previewCloseTimer.restart() }
                                                    onPressed: (mouse) => { mouse.accepted = true }
                                                    onClicked: (mouse) => {
                                                        mouse.accepted = true
                                                        if (cardItem.winData) {
                                                            TaskService.closeSpecificWindow(cardItem.winData)
                                                            let targetId = String(cardItem.winData.id || "")
                                                            let rem = root.previewWindowInstances ? root.previewWindowInstances.filter(w => String(w ? (w.id || "") : "") !== targetId) : []
                                                            if (!rem || rem.length === 0) {
                                                                root.previewActive = false
                                                                root.isPreviewHovered = false
                                                                root.isCardHovered = false
                                                                previewCloseTimer.stop()
                                                                TaskService.previewRestoreWindow()
                                                            } else {
                                                                root.previewWindowInstances = rem
                                                                root.previewActive = true
                                                                root.isCardHovered = true
                                                                previewCloseTimer.stop()
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Dock Context Menu Detached Popup Window
    PopupWindow {
        id: dockContextMenu
        anchor.window: root.dockWindow
        anchor.rect.x: Math.max(10, Math.min(root.dockWindow ? root.dockWindow.width - dockCtxGlass.implicitWidth - 10 : 800, root.contextTargetX - Math.round(dockCtxGlass.implicitWidth / 2) + 21))
        anchor.rect.y: 0
        anchor.edges: Edges.Top | Edges.Left
        anchor.gravity: Edges.Top | Edges.Right
        visible: false
        color: "transparent"

        // Fixed size, dimensioned for the case where every option is visible:
        // the popup surface doesn't resize properly once created, so a
        // content-driven size made the text overlap when switching apps.
        implicitWidth: 160
        implicitHeight: 140

        property real animProgress: 0.0

        NumberAnimation on animProgress {
            id: dockMenuPopIn
            running: false
            to: 1.0
            duration: 220
            easing.type: Easing.OutBack
            easing.overshoot: 1.15
        }

        NumberAnimation on animProgress {
            id: dockMenuPopOut
            running: false
            to: 0.0
            duration: 160
            easing.type: Easing.InQuad
            onFinished: dockContextMenu.visible = false
        }

        Connections {
            target: PopupService
            function onDockMenuOpenChanged() {
                if (PopupService.dockMenuOpen) {
                    dockMenuPopOut.running = false
                    dockContextMenu.visible = true
                    dockMenuPopIn.restart()
                } else if (dockContextMenu.visible) {
                    dockMenuPopIn.running = false
                    dockMenuPopOut.restart()
                }
            }
        }

        GlassPanel {
            id: dockCtxGlass
            implicitWidth: 160
            implicitHeight: 140
            anchors.fill: parent

            opacity: dockContextMenu.animProgress
            scale: 0.90 + 0.10 * dockContextMenu.animProgress
            transformOrigin: Item.BottomLeft

            ColumnLayout {
                id: ctxCol
                anchors.fill: parent
                anchors.margins: 8
                spacing: 4

                // Header Title with Icon (Fixed 22px Height)
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 22
                    spacing: 6

                    Item {
                        width: 14
                        height: 14
                        Layout.alignment: Qt.AlignVCenter

                        Image {
                            anchors.fill: parent
                            sourceSize.width: 14
                            sourceSize.height: 14
                            source: root.contextTargetApp ? root.getIconPath(root.contextTargetApp.icon || root.contextTargetApp.appId) : ""
                            fillMode: Image.PreserveAspectFit
                        }
                    }

                    Text {
                        text: root.contextTargetApp ? root.getCleanProgramName(root.contextTargetApp) : "Application"
                        color: Theme.accent
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                    }
                }

                // Divider
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Theme.currentLine
                }

                // Option 1: Launch New Instance
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 24
                    radius: 4
                    color: launchMouse.containsMouse ? Theme.currentLine : "transparent"

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Launch New Instance"
                        color: Theme.fg
                        font.pixelSize: 10
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        id: launchMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (root.contextTargetApp && root.contextTargetApp.cmd) {
                                TaskService.launchApp(root.contextTargetApp.cmd)
                            }
                            PopupService.closeAll()
                        }
                    }
                }

                // Option 2: Pin / Unpin Toggle
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 24
                    radius: 4
                    color: pinMouse.containsMouse ? Theme.currentLine : "transparent"

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: (root.contextTargetApp && TaskService.isPinned(root.contextTargetApp.appId)) ? "Unpin from Dock" : "Pin to Dock"
                        color: Theme.fg
                        font.pixelSize: 10
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        id: pinMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (root.contextTargetApp) {
                                TaskService.togglePin(root.contextTargetApp)
                            }
                            PopupService.closeAll()
                        }
                    }
                }

                // Option 3: Close Application (Red text)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 24
                    radius: 4
                    visible: root.contextTargetApp && TaskService.isRunning(root.contextTargetApp.appId)
                    color: closeMouse.containsMouse ? Qt.rgba(255/255, 85/255, 85/255, 0.2) : "transparent"

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Close Application"
                        color: Theme.red
                        font.pixelSize: 10
                        font.weight: Font.Bold
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (root.contextTargetApp) {
                                TaskService.closeApp(root.contextTargetApp.appId)
                            }
                            PopupService.closeAll()
                        }
                    }
                }
            }
        }
    }

    Timer {
        id: geomTimer
        interval: 500
        running: true
        repeat: true
        onTriggered: {
            let map = {}
            for (let i = 0; i < dockRepeater.count; i++) {
                let item = dockRepeater.itemAt(i)
                if (item && item.appId) {
                    let pt = item.mapToItem(root, 0, 0)
                    map[item.appId.toLowerCase()] = { x: Math.round(pt.x), y: Math.round(pt.y) }
                }
            }
            TaskService.updateIconGeometries(map)
        }
    }
}
