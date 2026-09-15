import QtQuick
import QtQuick.Layouts
import "../theme"

// A line of readings inside a monitoring card: one reading on the left edge,
// an optional second one on the right. The colon belongs to the row, not to
// the caller, so no card can spell its labels differently from the next.
RowLayout {
    id: row

    property string label: ""
    property string value: ""
    property color valueColor: Theme.fg

    property string trailingLabel: ""
    property string trailingValue: ""
    property color trailingValueColor: Theme.fg

    Layout.fillWidth: true
    Layout.preferredHeight: Theme.cardSlot
    spacing: Theme.sp1

    Text {
        text: row.label ? row.label + ":" : ""
        visible: row.label !== ""
        color: Theme.textMuted
        font.pixelSize: Theme.fsStrong
        font.family: Theme.fontFamily
    }

    Text {
        text: row.value
        color: row.valueColor
        font.pixelSize: Theme.fsStrong
        font.family: Theme.fontFamily
    }

    Item { Layout.fillWidth: true }

    Text {
        text: row.trailingLabel ? row.trailingLabel + ":" : ""
        visible: row.trailingValue !== ""
        color: Theme.textMuted
        font.pixelSize: Theme.fsStrong
        font.family: Theme.fontFamily
    }

    Text {
        text: row.trailingValue
        visible: row.trailingValue !== ""
        color: row.trailingValueColor
        font.pixelSize: Theme.fsStrong
        font.family: Theme.fontFamily
    }
}
