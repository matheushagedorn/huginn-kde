pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property string city: "Pocheon-si"
    property real tempC: 24
    property string condition: "Clear"
    property int weatherCode: 0
    property bool isDay: true
    property var forecastData: []

    property string currentTempStr: Math.round(tempC) + "°C"

    function getWeatherIcon(code) {
        if (code === 0) return "☀️"
        if (code >= 1 && code <= 3) return "⛅"
        if (code === 45 || code === 48) return "🌫️"
        if (code >= 51 && code <= 55) return "🌧️"
        if (code >= 61 && code <= 65) return "🌧️"
        if (code >= 71 && code <= 75) return "❄️"
        if (code >= 80 && code <= 82) return "🌦️"
        if (code >= 95) return "⛈️"
        return "☀️"
    }

    function getWeatherDescription(code) {
        if (code === 0) return "Clear"
        if (code >= 1 && code <= 3) return "Partly Cloudy"
        if (code === 45 || code === 48) return "Foggy"
        if (code >= 51 && code <= 55) return "Drizzle"
        if (code >= 61 && code <= 65) return "Rainy"
        if (code >= 71 && code <= 75) return "Snowy"
        if (code >= 80 && code <= 82) return "Showers"
        if (code >= 95) return "Thunderstorm"
        return "Clear"
    }

    function fetchWeather() {
        weatherProc.running = true
    }

    Process {
        id: weatherProc
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/services/python/weather_service.py"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                let parts = data.trim().split("|||")
                if (parts.length >= 4) {
                    root.city = parts[0] ? parts[0] : "Local"
                    let tc = parseFloat(parts[1])
                    if (!isNaN(tc)) {
                        root.tempC = tc
                    }
                    let code = parseInt(parts[2])
                    if (!isNaN(code)) {
                        root.weatherCode = code
                        root.condition = root.getWeatherDescription(code)
                    }
                    root.isDay = parts[3] === "1"

                    if (parts.length >= 5 && parts[4]) {
                        try {
                            let parsedForecast = JSON.parse(parts[4])
                            if (Array.isArray(parsedForecast)) {
                                let list = []
                                for (let i = 0; i < parsedForecast.length; i++) {
                                    let item = parsedForecast[i]
                                    list.push({
                                        day: item.day,
                                        temp: item.temp,
                                        icon: root.getWeatherIcon(item.code)
                                    })
                                }
                                root.forecastData = list
                            }
                        } catch (e) {}
                    }
                }
            }
        }
    }

    // Auto refresh every 15 minutes
    Timer {
        interval: 900000
        running: true
        repeat: true
        onTriggered: fetchWeather()
    }
}
