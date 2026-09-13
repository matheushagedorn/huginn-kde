import QtQuick
import "../theme"

Image {
    id: icon
    property int percentage: 100
    property bool isCharging: false

    width: 16
    height: 16
    sourceSize.width: 16
    sourceSize.height: 16
    fillMode: Image.PreserveAspectFit

    source: {
        let base = "file://" + Theme.iconsDir + "/" + Theme.panelIconDir + "/24x24/panel/"
        let chg = isCharging ? "-charging" : ""
        if (percentage > 90) {
            return base + "battery-100" + chg + ".svg"
        } else if (percentage > 70) {
            return base + "battery-080" + chg + ".svg"
        } else if (percentage > 50) {
            return base + "battery-060" + chg + ".svg"
        } else if (percentage > 30) {
            return base + "battery-040" + chg + ".svg"
        } else if (percentage > 10) {
            return base + "battery-020" + chg + ".svg"
        } else {
            return base + "battery-000" + chg + ".svg"
        }
    }
}
