import QtQuick
import QtQuick.Layouts
import "../theme"

// One card of the desktop system monitor.
//
// The four cards were four hand-built Rectangles with the same intent and
// four different executions, which is how the storage one ended up with no
// headline reading, no usage bar, rows a size smaller than everyone else's
// and its history graph stranded in the middle of the card. The anatomy is
// fixed here and every card gets it: heading with the one reading that names
// the card's state, the identity line that says what is being measured, the
// usage bar, the caller's rows, then the history graph on the bottom edge.
//
// `content` is a plain list property rather than the default one: aliasing a
// default property onto an inner layout makes this component's own children
// land inside themselves.
Rectangle {
    id: card

    property string title: ""
    property string headline: ""      // the single reading that names the state
    property string subtitle: ""      // the device or total being measured
    property real gaugeValue: 0       // 0..100
    property color gaugeColor: Theme.accent
    property var history: []
    property color graphColor: Theme.accent
    // A percentage series is drawn against a fixed 0-100 scale, so an idle
    // card reads as idle. Only a series with no ceiling of its own, like
    // network throughput, scales to its own peak.
    property bool graphAutoScale: false
    property alias content: body.data

    Layout.fillWidth: true
    Layout.preferredWidth: 314
    implicitHeight: 206
    radius: Theme.radiusCard
    color: Theme.surface
    border.width: 1
    border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.24)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.sp3
        spacing: Theme.sp1

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.sp2

            Text {
                text: card.title
                color: Theme.accent
                font.pixelSize: Theme.fsSubhead
                font.family: Theme.fontFamily
                font.weight: Font.Bold
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: card.headline
                color: Theme.accent
                font.pixelSize: Theme.fsHead
                font.family: Theme.fontFamily
                font.weight: Font.Bold
            }
        }

        Text {
            text: card.subtitle
            color: Theme.textMuted
            font.pixelSize: Theme.fsCaption
            font.family: Theme.fontFamily
            elide: Text.ElideRight
            Layout.fillWidth: true
            Layout.bottomMargin: 2
        }

        GaugeBar {
            value: card.gaugeValue
            fillColor: card.gaugeColor
        }

        // No spacing here: the rhythm comes from the slot height of each line,
        // so every card puts its first, second and third line at the same
        // height as every other card.
        ColumnLayout {
            id: body
            Layout.fillWidth: true
            Layout.topMargin: Theme.sp1
            spacing: 0
        }

        Item { Layout.fillHeight: true }

        SparklineGraph {
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            historyData: card.history
            barColor: card.graphColor
            autoScale: card.graphAutoScale
            maxVal: 100
        }
    }
}
