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
        id: tpPopIn
        running: false
        to: 1.0
        duration: 180
        easing.type: Easing.OutCubic
    }

    NumberAnimation on animProgress {
        id: tpPopOut
        running: false
        to: 0.0
        duration: 140
        easing.type: Easing.InQuad
        onFinished: {
            root.visible = false
            themeGrid.hoveredIndex = -1
        }
    }

    Connections {
        target: PopupService
        function onThemePickerOpenChanged() {
            if (PopupService.themePickerOpen) {
                tpPopOut.running = false
                themeGrid.hoveredIndex = -1
                root.visible = true
                tpPopIn.restart()
            } else if (root.visible) {
                tpPopIn.running = false
                tpPopOut.restart()
            }
        }
    }

    property string activeCategory: "All"
    onActiveCategoryChanged: themeGrid.hoveredIndex = -1

    property var catFlickRef: catFlick

    readonly property var filteredVariants: {
        if (activeCategory === "All") return Theme.variants;
        let list = [];
        for (let i = 0; i < Theme.variants.length; i++) {
            let v = Theme.variants[i];
            if (v.category === activeCategory) list.push(v);
        }
        return list;
    }

    implicitWidth: 400
    implicitHeight: 330

    GlassPanel {
        anchors.fill: parent
        radius: Theme.radiusCard

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // ── Clean Header ───────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "Themes"
                    color: Theme.fg
                    font.pixelSize: Theme.fsHead
                    font.family: Theme.fontFamily
                    font.weight: Font.Bold
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: Theme.currentVariant
                    color: Theme.accent
                    font.pixelSize: Theme.fsBody
                    font.family: Theme.fontFamily
                    font.weight: Font.Medium
                }
            }

            // ── Strictly Clipped Category Filter Bar (No Protrusion) ───────────
            Item {
                Layout.fillWidth: true
                implicitHeight: 26
                clip: true

                Flickable {
                    id: catFlick
                    anchors.fill: parent
                    clip: true
                    contentWidth: catRow.implicitWidth
                    boundsBehavior: Flickable.StopAtBounds

                    Row {
                        id: catRow
                        spacing: 6

                        Repeater {
                            model: Theme.themeCategories

                            Rectangle {
                                implicitWidth: catTxt.implicitWidth + 14
                                implicitHeight: 24
                                radius: 6

                                property bool isActiveCat: root.activeCategory === modelData

                                color: isActiveCat ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.20)
                                                   : (catMouse.containsMouse ? Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.08) : Theme.surface)

                                Behavior on color { ColorAnimation { duration: 110 } }

                                Text {
                                    id: catTxt
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: isActiveCat ? Theme.accent : (catMouse.containsMouse ? Theme.fg : Theme.comment)
                                    font.pixelSize: Theme.fsBody
                                    font.family: Theme.fontFamily
                                    font.weight: isActiveCat ? Font.DemiBold : Font.Normal
                                }

                                MouseArea {
                                    id: catMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: root.activeCategory = modelData
                                    onWheel: (wheel) => {
                                        let delta = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x
                                        if (root.catFlickRef) {
                                            let cf = root.catFlickRef
                                            cf.contentX = Math.max(0, Math.min(cf.contentWidth - cf.width, cf.contentX - delta * 0.8))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── Scrollable Theme Grid ─────────────────────────────────────────
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Flickable {
                    id: mainFlick
                    anchors.fill: parent
                    anchors.rightMargin: 8
                    clip: true
                    contentWidth: width
                    contentHeight: themeGrid.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds

                    Grid {
                        id: themeGrid
                        width: parent.width
                        columns: 2
                        spacing: 8

                        property int hoveredIndex: -1

                        Repeater {
                            model: root.filteredVariants

                            Rectangle {
                                width: Math.floor((themeGrid.width - 8) / 2)
                                height: 44
                                radius: 8

                                property bool isSelected: Theme.currentVariant === modelData.name
                                property bool isHovered: themeGrid.hoveredIndex === index

                                color: isSelected ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15)
                                                  : (isHovered ? Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.08) : Theme.surface)

                                border.color: isSelected ? Theme.accent : (isHovered ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.30) : "transparent")
                                border.width: 1

                                Behavior on color { ColorAnimation { duration: 110 } }
                                Behavior on border.color { ColorAnimation { duration: 110 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 8

                                    // Handcrafted Swatch Trio
                                    Item {
                                        width: 18; height: 18
                                        Layout.alignment: Qt.AlignVCenter

                                        Rectangle {
                                            width: 12; height: 12; radius: 6
                                            x: 0; y: 3
                                            color: modelData.accent
                                        }

                                        Rectangle {
                                            width: 10; height: 10; radius: 5
                                            x: 6; y: 0
                                            color: modelData.subAccent ? modelData.subAccent : modelData.accent
                                            border.color: Theme.surface
                                            border.width: 1.5
                                        }
                                    }

                                    // Theme Name
                                    Text {
                                        text: modelData.name
                                        color: isSelected ? Theme.accent : Theme.fg
                                        font.pixelSize: Theme.fsBody
                                        font.family: Theme.fontFamily
                                        font.weight: isSelected ? Font.DemiBold : Font.Normal
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }
                                }

                                MouseArea {
                                    id: itemMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: themeGrid.hoveredIndex = index
                                    onExited: {
                                        if (themeGrid.hoveredIndex === index) themeGrid.hoveredIndex = -1
                                    }
                                    onClicked: Theme.setVariant(modelData.name)
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
