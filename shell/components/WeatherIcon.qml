import QtQuick
import "../theme"

// Sky condition, mapped from the WMO weather code Open-Meteo returns.
UiIcon {
    property int weatherCode: 0
    property bool isDay: true

    implicitWidth: 16
    implicitHeight: 16

    name: {
        let c = weatherCode
        if (c === 0) return isDay ? "sun" : "moon"
        if (c <= 3) return isDay ? "cloud-sun" : "cloudy"
        if (c === 45 || c === 48) return "cloud-fog"
        if (c >= 51 && c <= 55) return "cloud-drizzle"
        if (c >= 61 && c <= 65) return "cloud-rain"
        if (c >= 71 && c <= 75) return "cloud-snow"
        if (c >= 80 && c <= 82) return "cloud-rain"
        if (c >= 95) return "cloud-lightning"
        return "cloud"
    }

    color: Theme.fg
}
