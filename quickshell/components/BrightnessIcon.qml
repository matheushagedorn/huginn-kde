import QtQuick
import "../theme"

Image {
    id: icon
    property int brightness: 100

    width: 16
    height: 16
    sourceSize.width: 16
    sourceSize.height: 16
    fillMode: Image.PreserveAspectFit

    source: "file://" + Theme.iconsDir + "/" + Theme.panelIconDir + "/24x24/panel/gpm-brightness-lcd.svg"
}
