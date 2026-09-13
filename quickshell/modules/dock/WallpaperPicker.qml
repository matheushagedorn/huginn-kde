import QtQuick
import QtQuick.Layouts
import "../../components"
import "../../services"
import "../../theme"

Item {
    id: root

    visible: false
    opacity: animProgress
    scale: 0.95 + 0.05 * animProgress
    transformOrigin: Item.BottomRight

    property real animProgress: 0.0

    NumberAnimation on animProgress {
        id: wpPopIn
        running: false
        to: 1.0
        duration: 180
        easing.type: Easing.OutCubic
    }

    NumberAnimation on animProgress {
        id: wpPopOut
        running: false
        to: 0.0
        duration: 140
        easing.type: Easing.InQuad
        onFinished: {
            root.visible = false
            wpGrid.hoveredIndex = -1
        }
    }

    Connections {
        target: PopupService
        function onWallpaperPickerOpenChanged() {
            if (PopupService.wallpaperPickerOpen) {
                wpPopOut.running = false
                wpGrid.hoveredIndex = -1
                root.visible = true
                wpPopIn.restart()
                WallpaperService.refresh()
            } else if (root.visible) {
                wpPopIn.running = false
                wpPopOut.restart()
            }
        }
    }

    readonly property var filteredWallpapers: {
        if (!WallpaperService.wallpapers) return [];
        let curVar = Theme.currentVariant.toLowerCase().trim();
        let list = [];
        for (let i = 0; i < WallpaperService.wallpapers.length; i++) {
            let wp = WallpaperService.wallpapers[i];
            let wpVar = (wp.variant || "").toLowerCase().trim();
            if (wpVar === curVar || wpVar === "custom") {
                list.push(wp);
            }
        }
        return list;
    }

    implicitWidth: 400
    implicitHeight: 330

    GlassPanel {
        anchors.fill: parent
        radius: 16

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // ── Clean Header ───────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "Wallpapers"
                    color: Theme.fg
                    font.pixelSize: 15
                    font.family: "Inter, Sans-Serif"
                    font.weight: Font.Bold
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: root.filteredWallpapers.length + " wallpapers"
                    color: Theme.comment
                    font.pixelSize: 11
                    font.family: "Inter, Sans-Serif"
                    font.weight: Font.Normal
                }
            }

            // ── Scrollable Wallpaper Cards Grid ───────────────────────────────
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Flickable {
                    id: mainFlick
                    anchors.fill: parent
                    anchors.rightMargin: 8
                    clip: true
                    contentWidth: width
                    contentHeight: wpGrid.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds

                    Grid {
                        id: wpGrid
                        width: parent.width
                        columns: 2
                        spacing: 8

                        property int hoveredIndex: -1

                        Repeater {
                            model: root.filteredWallpapers

                            Rectangle {
                                width: Math.floor((wpGrid.width - 8) / 2)
                                height: 100
                                radius: 8

                                property bool isSelected: Theme.wallpaperPath.endsWith("/" + modelData.name) || WallpaperService.activeCustomWallpaper === modelData.path
                                property bool isHovered: wpGrid.hoveredIndex === index

                                color: Theme.surface
                                border.color: isSelected ? Theme.accent : (isHovered ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35) : "transparent")
                                border.width: 1

                                Behavior on border.color { ColorAnimation { duration: 110 } }

                                // 16:9 Image Thumbnail Container
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    radius: 6
                                    clip: true
                                    color: Theme.bg

                                    Image {
                                        anchors.fill: parent
                                        fillMode: Image.PreserveAspectCrop
                                        source: "file://" + modelData.path
                                        asynchronous: true
                                        cache: true
                                    }

                                    // Clean Minimalist Title Pill at Bottom
                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        height: 20
                                        color: Qt.rgba(0, 0, 0, 0.55)

                                        Text {
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors.leftMargin: 6
                                            anchors.rightMargin: 6
                                            text: modelData.name
                                            color: "#ffffff"
                                            font.pixelSize: 10
                                            font.family: "Inter, Sans-Serif"
                                            font.weight: Font.Normal
                                            elide: Text.ElideRight
                                        }
                                    }
                                }

                                MouseArea {
                                    id: wpMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: wpGrid.hoveredIndex = index
                                    onExited: {
                                        if (wpGrid.hoveredIndex === index) wpGrid.hoveredIndex = -1
                                    }
                                    onClicked: WallpaperService.applyWallpaper(modelData.path)
                                }
                            }
                        }
                    }
                }

                // Interactive ScrollBar
                Item {
                    id: scrollTrack
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 4
                    visible: mainFlick.contentHeight > mainFlick.height

                    Rectangle {
                        anchors.fill: parent
                        radius: 2
                        color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.08)
                    }

                    Rectangle {
                        id: scrollThumb
                        width: parent.width; radius: 2
                        color: scrollMouse.pressed ? Theme.accent : (scrollMouse.containsMouse ? Theme.accent : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.60))
                        y: mainFlick.visibleArea.yPosition * scrollTrack.height
                        height: Math.max(20, mainFlick.visibleArea.heightRatio * scrollTrack.height)
                        Behavior on color { ColorAnimation { duration: 100 } }
                    }

                    MouseArea {
                        id: scrollMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        property real dragStartY: 0
                        property real initialContentY: 0
                        onPressed: (mouse) => {
                            dragStartY = mouse.y
                            initialContentY = mainFlick.contentY
                            let thumbY = scrollThumb.y
                            let thumbH = scrollThumb.height
                            if (mouse.y < thumbY || mouse.y > thumbY + thumbH) {
                                let targetRatio = (mouse.y - thumbH / 2) / (scrollTrack.height - thumbH)
                                targetRatio = Math.max(0, Math.min(1, targetRatio))
                                mainFlick.contentY = targetRatio * (mainFlick.contentHeight - mainFlick.height)
                                initialContentY = mainFlick.contentY
                            }
                        }
                        onPositionChanged: (mouse) => {
                            if (pressed) {
                                let deltaY = mouse.y - dragStartY
                                let trackSpace = scrollTrack.height - scrollThumb.height
                                if (trackSpace > 0) {
                                    let contentDelta = (deltaY / trackSpace) * (mainFlick.contentHeight - mainFlick.height)
                                    mainFlick.contentY = Math.max(0, Math.min(mainFlick.contentHeight - mainFlick.height, initialContentY + contentDelta))
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
