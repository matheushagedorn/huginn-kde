/*
    Huginn window switcher.

    A rail on the left edge holding the open windows as a deck of cards. Every
    card carries its own live thumbnail, so the whole desktop is readable at a
    glance; the selected card lifts out of the deck and opens its thumbnail to
    the full width of the rail. Only the current desktop is listed, so no card
    needs to say which desktop it is on.

    Colours come from HuginnPalette.qml, which the theme engine rewrites; sizes
    and type follow shell/theme/Theme.qml, which QML outside the shell cannot
    import, so the handful of values used here are repeated as literals and
    marked with the token they mirror.
*/
import QtQuick
import Qt5Compat.GraphicalEffects
import QtQuick.Layouts
import QtQuick.Window

import org.kde.kirigami as Kirigami
import org.kde.kwin as KWin
// DesktopBackground is registered through this module, the way the stock
// coverswitch layout pulls it in; without it the import above is not enough.
import org.kde.kwin.private.effects

KWin.TabBoxSwitcher {
    id: tabBox

    readonly property real screenFactor: screenGeometry.width / screenGeometry.height
    // Fixed, not a share of the screen: 15% of an ultrawide is a corridor.
    // Wide enough that a collapsed card fits a thumbnail and two lines of
    // caption side by side.
    readonly property int railWidth: 400
    readonly property int railPadding: 16   // Theme.sp4
    readonly property int cardPadding: 12   // Theme.sp3
    readonly property int spineGap: 8       // Theme.sp2
    readonly property int spineWidth: 3
    readonly property int overlap: 8        // how far a card sits under the next
    readonly property int fanStep: 5        // how far each card recedes from the deck
    readonly property int thumbWidth: 132   // a collapsed card's thumbnail
    readonly property int dur: Kirigami.Units.longDuration

    currentIndex: deck.currentIndex

    Window {
        id: window

        flags: Qt.Popup | Qt.BypassWindowManagerHint | Qt.FramelessWindowHint
        color: "transparent"

        x: tabBox.screenGeometry.x
        y: tabBox.screenGeometry.y
        width: tabBox.railWidth
        height: tabBox.screenGeometry.height
        // Workaround QTBUG-35244. Do not directly assign here to avoid warning
        visible: true

        HuginnPalette { id: colors }

        readonly property color dimFg: Qt.rgba(colors.fg.r, colors.fg.g, colors.fg.b, 0.62)

        // The desktop shows through the rail, blurred and clipped to it. No
        // full-screen scrim: the switcher takes the strip it needs and leaves
        // the rest of the screen alone.
        Item {
            anchors.fill: parent
            clip: true

            KWin.DesktopBackground {
                activity: KWin.Workspace.currentActivity
                desktop: KWin.Workspace.currentVirtualDesktop
                outputName: window.screen.name

                width: tabBox.screenGeometry.width
                height: tabBox.screenGeometry.height

                layer.enabled: true
                layer.effect: FastBlur { radius: 48 }
            }

            Rectangle {
                anchors.fill: parent
                color: colors.bg
                opacity: 0.85
            }
        }

        ListView {
            id: deck

            anchors {
                left: parent.left
                right: parent.right
                leftMargin: tabBox.railPadding
                rightMargin: tabBox.railPadding
            }
            // The deck sits centred in the rail while it fits, and only starts
            // scrolling once it is taller than the screen.
            height: Math.min(contentHeight + tabBox.overlap, parent.height - 2 * tabBox.railPadding)
            y: Math.round((parent.height - height) / 2)

            model: tabBox.model
            spacing: 0
            focus: true
            clip: true
            currentIndex: 0

            Behavior on height { NumberAnimation { duration: tabBox.dur; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: tabBox.dur; easing.type: Easing.OutCubic } }

            Connections {
                target: tabBox
                function onCurrentIndexChanged() {
                    deck.currentIndex = tabBox.currentIndex;
                    deck.positionViewAtIndex(deck.currentIndex, ListView.Contain);
                }
            }

            delegate: MouseArea {
                id: card

                readonly property bool selected: ListView.isCurrentItem
                // Cards recede from the selected one, two steps deep, so the
                // column reads as a deck fanned around the window in hand.
                readonly property int recess: Math.min(Math.abs(index - deck.currentIndex), 2) * tabBox.fanStep
                readonly property int bodyWidth: deck.width - tabBox.spineWidth - tabBox.spineGap - recess

                readonly property int thumbWidth: selected ? bodyWidth - 2 * tabBox.cardPadding
                                                           : tabBox.thumbWidth
                readonly property int thumbHeight: Math.round(thumbWidth / tabBox.screenFactor)

                width: deck.width
                height: selected
                    ? 2 * tabBox.cardPadding + thumbHeight + 10 + caption.height + tabBox.overlap
                    : 2 * tabBox.cardPadding + thumbHeight - tabBox.overlap
                // Cards nearer the top of the list lie over the ones below, so
                // the overlap reads as a deck rather than as clipping.
                z: selected ? deck.count : -index

                Accessible.name: model.caption
                Accessible.role: Accessible.ListItem

                onClicked: {
                    if (tabBox.noModifierGrab) {
                        tabBox.model.activate(index);
                    } else {
                        deck.currentIndex = index;
                    }
                }

                Behavior on height { NumberAnimation { duration: tabBox.dur; easing.type: Easing.OutCubic } }

                Rectangle {
                    id: spine

                    anchors {
                        left: parent.left
                        top: parent.top
                        bottom: parent.bottom
                        topMargin: card.selected ? 0 : 7
                        bottomMargin: card.selected ? tabBox.overlap : 7
                    }
                    width: card.selected ? tabBox.spineWidth : 1
                    radius: width / 2
                    color: card.selected ? colors.accent
                                         : Qt.rgba(colors.line.r, colors.line.g, colors.line.b, 0.7)

                    Behavior on width { NumberAnimation { duration: tabBox.dur; easing.type: Easing.OutCubic } }
                }

                Rectangle {
                    id: body

                    anchors {
                        left: spine.right
                        leftMargin: tabBox.spineGap
                        top: parent.top
                        bottom: parent.bottom
                        // A collapsed card runs past its row and under the next
                        // one; the selected card pulls clear of the deck.
                        bottomMargin: card.selected ? tabBox.overlap : -tabBox.overlap
                    }
                    width: card.bodyWidth

                    radius: 10   // Theme.radiusCard
                    color: card.selected ? colors.surface : Qt.darker(colors.surface, 1.18)
                    border.width: 1
                    border.color: card.selected
                        ? Qt.rgba(colors.accent.r, colors.accent.g, colors.accent.b, 0.45)
                        : Qt.rgba(colors.line.r, colors.line.g, colors.line.b, 0.55)
                    clip: true

                    Behavior on width { NumberAnimation { duration: tabBox.dur; easing.type: Easing.OutCubic } }

                    // Thumbnail and caption keep the same two items in both
                    // states and only move: the caption sits beside a collapsed
                    // thumbnail and drops below the one that has opened, so the
                    // change is a single travel rather than a swap of layouts.
                    Rectangle {
                        id: frame

                        x: tabBox.cardPadding
                        y: tabBox.cardPadding
                        width: card.thumbWidth
                        height: card.thumbHeight
                        radius: 4
                        color: Qt.rgba(colors.bg.r, colors.bg.g, colors.bg.b, 0.55)
                        clip: true

                        Behavior on width { NumberAnimation { duration: tabBox.dur; easing.type: Easing.OutCubic } }
                        Behavior on height { NumberAnimation { duration: tabBox.dur; easing.type: Easing.OutCubic } }

                        KWin.WindowThumbnail {
                            anchors.fill: parent
                            wId: windowId
                        }
                    }

                    Row {
                        id: caption

                        x: tabBox.cardPadding + (card.selected ? 0 : card.thumbWidth + tabBox.cardPadding)
                        y: card.selected ? frame.y + frame.height + 10
                                         : frame.y + Math.round((frame.height - height) / 2)
                        width: card.bodyWidth - x - tabBox.cardPadding
                        spacing: 10
                        // Vertical centre so a two-line caption stays level with
                        // the icon next to it.
                        Behavior on x { NumberAnimation { duration: tabBox.dur; easing.type: Easing.OutCubic } }
                        Behavior on y { NumberAnimation { duration: tabBox.dur; easing.type: Easing.OutCubic } }

                        Kirigami.Icon {
                            width: card.selected ? 22 : 18
                            height: width
                            source: model.icon
                            opacity: card.selected ? 1 : 0.8
                            anchors.verticalCenter: label.verticalCenter
                        }

                        Text {
                            id: label

                            width: parent.width - parent.spacing - (card.selected ? 22 : 18)
                            text: model.caption
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                            maximumLineCount: card.selected ? 1 : 2
                            color: card.selected ? colors.fg : window.dimFg
                            font.family: "Inter, Noto Sans, DejaVu Sans, Sans-Serif"   // Theme.fontFamily
                            font.pixelSize: card.selected ? 14 : 13   // Theme.fsStrong / fsBody
                            font.weight: card.selected ? Font.DemiBold : Font.Normal
                            lineHeight: 1.15   // Theme.lhTight

                            Behavior on color { ColorAnimation { duration: tabBox.dur } }
                        }
                    }
                }
            }

            Keys.onUpPressed: decrementCurrentIndex()
            Keys.onDownPressed: incrementCurrentIndex()
            Keys.onLeftPressed: decrementCurrentIndex()
            Keys.onRightPressed: incrementCurrentIndex()
        }

        Text {
            anchors.centerIn: parent
            width: parent.width - 2 * tabBox.railPadding
            visible: deck.count === 0
            text: "No open windows"
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            color: window.dimFg
            font.family: "Inter, Noto Sans, DejaVu Sans, Sans-Serif"   // Theme.fontFamily
            font.pixelSize: 13
        }

        onSceneGraphError: () => {
            // Intentionally blank, otherwise QtQuick may post a qFatal() message
            // on a graphics reset.
        }
    }

    onVisibleChanged: {
        if (!visible) {
            deck.currentIndex = 0;
        }
        window.visible = visible;
    }
}
