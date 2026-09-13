import QtQuick
import QtQuick.Layouts
import "../services"
import "../theme"

Item {
    id: root
    implicitWidth: 210
    implicitHeight: mainLayout.implicitHeight

    property date currentDate: new Date()
    property int selectedYear: currentDate.getFullYear()
    property int selectedMonth: currentDate.getMonth()

    function getMonthName(monthIndex) {
        var names = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
        return names[monthIndex]
    }

    function generateGrid() {
        var result = []
        var firstDayIndex = new Date(selectedYear, selectedMonth, 1).getDay()
        var startOffset = (firstDayIndex + 6) % 7
        var daysInMonth = new Date(selectedYear, selectedMonth + 1, 0).getDate()
        var prevMonthDays = new Date(selectedYear, selectedMonth, 0).getDate()

        // Leading days from previous month
        for (var i = startOffset - 1; i >= 0; i--) {
            result.push({ day: prevMonthDays - i, isCurrentMonth: false, isToday: false })
        }

        // Active month days
        var today = new Date()
        for (var d = 1; d <= daysInMonth; d++) {
            var isToday = (d === today.getDate() && selectedMonth === today.getMonth() && selectedYear === today.getFullYear())
            result.push({ day: d, isCurrentMonth: true, isToday: isToday })
        }

        // Trailing days from next month to complete fixed 42 cells (6 rows x 7 cols)
        var totalNeeded = 42 - result.length
        for (var n = 1; n <= totalNeeded; n++) {
            result.push({ day: n, isCurrentMonth: false, isToday: false })
        }

        return result
    }

    property var gridData: generateGrid()

    function prevMonth() {
        if (selectedMonth === 0) {
            selectedMonth = 11
            selectedYear -= 1
        } else {
            selectedMonth -= 1
        }
        gridData = generateGrid()
    }

    function nextMonth() {
        if (selectedMonth === 11) {
            selectedMonth = 0
            selectedYear += 1
        } else {
            selectedMonth += 1
        }
        gridData = generateGrid()
    }

    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        spacing: 8

        // Month & Year Header Navigation
        RowLayout {
            Layout.fillWidth: true
            spacing: 0

            Rectangle {
                width: 24; height: 24; radius: 4
                color: prevMonthMouse.containsMouse ? Theme.currentLine : "transparent"
                Text { text: "‹"; color: Theme.fg; font.pixelSize: Theme.fsSubhead; anchors.centerIn: parent }
                MouseArea {
                    id: prevMonthMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.prevMonth()
                }
            }

            Text {
                text: root.getMonthName(root.selectedMonth) + " " + root.selectedYear
                color: Theme.fg
                font.pixelSize: Theme.fsStrong
                font.family: Theme.fontFamily
                font.weight: Font.Bold
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
            }

            Rectangle {
                width: 24; height: 24; radius: 4
                color: nextMonthMouse.containsMouse ? Theme.currentLine : "transparent"
                Text { text: "›"; color: Theme.fg; font.pixelSize: Theme.fsSubhead; anchors.centerIn: parent }
                MouseArea {
                    id: nextMonthMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.nextMonth()
                }
            }
        }

        // Days of Week Header Row
        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            Repeater {
                model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                Text {
                    text: modelData
                    color: Theme.accent
                    font.pixelSize: Theme.fsCaption
                    font.family: Theme.fontFamily
                    font.weight: Font.Bold
                    Layout.preferredWidth: 26
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        // Calendar Days Fixed Grid (6 x 7)
        GridLayout {
            columns: 7
            columnSpacing: 4
            rowSpacing: 4
            Layout.fillWidth: true

            Repeater {
                model: root.gridData

                Rectangle {
                    width: 26
                    height: 22
                    radius: 4
                    color: modelData.isToday ? Theme.accent : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: modelData.day.toString()
                        color: modelData.isToday ? Theme.accentFg : (modelData.isCurrentMonth ? Theme.fg : Qt.rgba(Theme.comment.r, Theme.comment.g, Theme.comment.b, 0.5))
                        font.pixelSize: Theme.fsCaption
                        font.family: Theme.fontFamily
                        font.weight: modelData.isToday ? Font.Bold : Font.Normal
                    }
                }
            }
        }
    }
}
