pragma Singleton
import QtQuick

Item {
    id: root

    property string timeStr: ""
    property string dateStr: ""
    property string fullDateStr: ""

    function updateTime() {
        var date = new Date()
        timeStr = Qt.formatDateTime(date, "hh:mm AP")
        dateStr = Qt.formatDateTime(date, "ddd, MMM d")
        fullDateStr = Qt.formatDateTime(date, "dddd, MMMM d, yyyy")
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.updateTime()
    }
}
