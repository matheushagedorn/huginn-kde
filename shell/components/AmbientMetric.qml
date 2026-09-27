import QtQuick
import QtQuick.Layouts
import "../theme"

// One reading of the desktop system strip.
//
// At rest it is a single quiet line: a small label, the number, and a trace
// of where the number has been. No frame and no fill, and everything in the
// muted text colour, so the strip reads as part of the wallpaper rather than
// as four windows parked on it. The number only takes a colour when the
// reading behind it crosses a threshold, which is the one moment the strip
// has something to say. `flag` is for the case where the reading that
// crossed is not the number on show (a CPU at 20% load running at 90°C): it
// appears beside the number, in the same colour, and only then.
//
// Resting on it reveals the rest in place: the device name and the detail
// rows grow out underneath on a faint backdrop, so they stay legible over any
// wallpaper, and fold away again when the pointer leaves. A short dwell
// before opening keeps a pointer on its way somewhere else from setting the
// whole column off.
//
// Every reading has the same anatomy. The graph slot holds the history
// sparkline for anything that moves; a reading without a history, like how
// full the disk is, passes `fill` instead and gets a hairline bar in the same
// slot, so the column keeps one shape all the way down.
Item {
    id: metric

    property string label: ""
    property string value: ""
    property string flag: ""
    // 0 calm, 1 warning, 2 critical. The caller decides what crossing means
    // for its reading; this only decides how it looks.
    property int level: 0

    property var history: []
    property bool autoScale: false
    property real maxVal: 100
    // 0..100 draws a bar in the graph slot instead of the history.
    property real fill: -1

    property string subtitle: ""
    // [{ label, value, level }], already filtered by the caller down to the
    // hardware that actually exists.
    property var details: []

    readonly property bool expanded: dwell.armed
    // What the detail block adds when open, so the window that holds the
    // strip can be sized for the tallest one before anything opens.
    readonly property real detailHeight: detailCol.implicitHeight + Theme.sp2
    readonly property real restHeight: rowHeight + 2 * Theme.sp1

    readonly property color levelColor: level >= 2 ? Theme.danger
                                      : level === 1 ? Theme.warning
                                      : expanded ? Theme.fg : Theme.textMuted

    implicitHeight: body.implicitHeight + 2 * Theme.sp1

    // Laid out left to right so every row lines its numbers up with the
    // row above, whatever the label or the unit.
    readonly property int rowHeight: 20
    readonly property int labelWidth: 36
    readonly property int valueWidth: 68
    readonly property int graphWidth: 64
    readonly property int graphHeight: 14

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusCard
        color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.78)
        opacity: metric.expanded ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onContainsMouseChanged: if (!containsMouse) dwell.armed = false
    }

    Timer {
        id: dwell
        property bool armed: false
        interval: 160
        running: pointer.containsMouse && !armed
        onTriggered: armed = true
    }

    ColumnLayout {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: Theme.sp2
        anchors.rightMargin: Theme.sp2
        anchors.topMargin: Theme.sp1
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: metric.rowHeight
            spacing: Theme.sp2

            Text {
                text: metric.label
                color: Theme.textMuted
                opacity: metric.expanded ? 1 : 0.8
                font.pixelSize: Theme.fsCaption
                font.family: Theme.fontFamily
                font.weight: Font.Medium
                font.letterSpacing: 0.6
                Layout.preferredWidth: metric.labelWidth
            }

            Text {
                text: metric.value
                color: metric.levelColor
                font.pixelSize: Theme.fsBody
                font.family: Theme.fontFamily
                font.weight: metric.level > 0 ? Font.Bold : Font.Medium
                // Tabular figures, so a number ticking from 9 to 10 does not
                // shuffle the digits beside it every refresh.
                font.features: { "tnum": 1 }
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideLeft
                Layout.preferredWidth: metric.valueWidth

                Behavior on color { ColorAnimation { duration: 200 } }
            }

            Text {
                text: metric.flag
                visible: metric.flag !== ""
                color: metric.levelColor
                font.pixelSize: Theme.fsCaption
                font.family: Theme.fontFamily
                font.weight: Font.Bold
                font.features: { "tnum": 1 }
            }

            Item { Layout.fillWidth: true }

            Item {
                Layout.preferredWidth: metric.graphWidth
                Layout.preferredHeight: metric.graphHeight
                Layout.alignment: Qt.AlignVCenter

                SparklineGraph {
                    anchors.fill: parent
                    visible: metric.fill < 0
                    historyData: metric.history
                    autoScale: metric.autoScale
                    maxVal: metric.maxVal
                    // Muted like the text until something is wrong, then in
                    // the same colour as the number that says so.
                    barColor: metric.level > 0 ? metric.levelColor : Theme.textMuted
                    lineWidth: 1.2
                    fillOpacity: metric.expanded || metric.level > 0 ? 0.30 : 0.16
                    inset: 1.5
                }

                GaugeBar {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: metric.fill >= 0
                    value: Math.max(0, metric.fill)
                    thickness: 3
                    fillColor: metric.level > 0 ? metric.levelColor : Theme.textMuted
                    trackColor: Qt.rgba(Theme.textMuted.r, Theme.textMuted.g, Theme.textMuted.b, 0.18)
                }
            }
        }

        // Clipped and grown rather than toggled, so opening reads as the
        // reading unfolding in place and not as a popup landing on it.
        Item {
            Layout.fillWidth: true
            // implicitHeight rather than Layout.preferredHeight: a Behavior
            // on an attached property does not animate.
            implicitHeight: metric.expanded ? metric.detailHeight : 0
            clip: true
            opacity: metric.expanded ? 1 : 0

            Behavior on implicitHeight { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

            ColumnLayout {
                id: detailCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: Theme.sp1
                spacing: 2

                Text {
                    text: metric.subtitle
                    visible: metric.subtitle !== ""
                    color: Theme.textMuted
                    font.pixelSize: Theme.fsCaption
                    font.family: Theme.fontFamily
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    Layout.bottomMargin: 2
                }

                Repeater {
                    model: metric.details

                    RowLayout {
                        id: detailRow
                        required property var modelData

                        Layout.fillWidth: true
                        spacing: Theme.sp2

                        Text {
                            text: detailRow.modelData.label
                            color: Theme.textMuted
                            font.pixelSize: Theme.fsCaption
                            font.family: Theme.fontFamily
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: detailRow.modelData.value
                            color: (detailRow.modelData.level || 0) >= 2 ? Theme.danger
                                 : (detailRow.modelData.level || 0) === 1 ? Theme.warning
                                 : Theme.fg
                            font.pixelSize: Theme.fsCaption
                            font.family: Theme.fontFamily
                            font.features: { "tnum": 1 }
                        }
                    }
                }
            }
        }
    }
}
