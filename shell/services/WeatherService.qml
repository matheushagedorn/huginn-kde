pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Weather, from Open-Meteo.
//
// The placeholder values that used to live here (a city in South Korea, 24°C)
// were what the panel showed whenever the lookup failed, which was always:
// the location was resolved over plain HTTP against a host this network
// refuses. A failure now reads as a failure instead of as mild weather.
Item {
    id: root

    property string city: ""
    property real tempC: 0
    property string condition: ""
    property int weatherCode: 0
    property bool isDay: true
    property var forecastData: []

    // False until a real reading arrives, so nothing invents a temperature.
    property bool available: false
    property string lastError: ""

    readonly property string currentTempStr: available ? Math.round(tempC) + "°C" : "--°"

    // Returns an icon name from the shared set, not an emoji. Emoji came from
    // the system font, ignored the palette, and were the last thing in the
    // shell still drawn in somebody else's style.
    function getWeatherIcon(code) {
        if (!available) return "cloud"
        if (code === 0) return isDay ? "sun" : "moon"
        if (code <= 3) return isDay ? "cloud-sun" : "cloudy"
        if (code === 45 || code === 48) return "cloud-fog"
        if (code >= 51 && code <= 55) return "cloud-drizzle"
        if (code >= 61 && code <= 65) return "cloud-rain"
        if (code >= 71 && code <= 75) return "cloud-snow"
        if (code >= 80 && code <= 82) return "cloud-rain"
        if (code >= 95) return "cloud-lightning"
        return "cloud"
    }

    function getWeatherDescription(code) {
        if (code === 0) return "Clear"
        if (code >= 1 && code <= 3) return "Partly cloudy"
        if (code === 45 || code === 48) return "Foggy"
        if (code >= 51 && code <= 55) return "Drizzle"
        if (code >= 61 && code <= 65) return "Rain"
        if (code >= 71 && code <= 75) return "Snow"
        if (code >= 80 && code <= 82) return "Showers"
        if (code >= 95) return "Thunderstorm"
        return "Clear"
    }

    function fetchWeather() {
        weatherProc.running = true
    }

    // ---- City picker ----------------------------------------------------
    // Backs the search in the weather panel, so choosing a location is done in
    // the interface instead of by editing a config file.

    property var searchResults: []
    property bool searching: false
    property string searchError: ""
    property string pinnedCity: ""

    readonly property string locationScript:
        Quickshell.env("HOME") + "/.config/huginn/services/python/weather_location.py"

    function searchCity(query) {
        searchDebounce.pendingQuery = query
        searchDebounce.restart()
    }

    function applyCity(name, latitude, longitude, region) {
        setProc.command = ["python3", locationScript, "set",
                           name, String(latitude), String(longitude), region || ""]
        setProc.running = true
    }

    function useAutoLocation() {
        setProc.command = ["python3", locationScript, "clear"]
        setProc.running = true
    }

    // Typing should not fire a request per keystroke.
    Timer {
        id: searchDebounce
        interval: 350
        repeat: false
        property string pendingQuery: ""
        onTriggered: {
            if (pendingQuery.trim().length < 2) {
                root.searchResults = []
                root.searching = false
                root.searchError = ""
                return
            }
            root.searching = true
            root.searchError = ""
            searchProc.running = false
            searchProc.command = ["python3", root.locationScript, "search", pendingQuery]
            searchProc.running = true
        }
    }

    Process {
        id: searchProc
        stdout: SplitParser {
            onRead: data => {
                root.searching = false
                try {
                    let payload = JSON.parse(data.trim())
                    if (payload.ok) {
                        root.searchResults = payload.results || []
                        root.searchError = root.searchResults.length === 0 ? "No match" : ""
                    } else {
                        root.searchResults = []
                        root.searchError = payload.error || "Search failed"
                    }
                } catch (e) {
                    root.searchResults = []
                    root.searchError = "Search failed"
                }
            }
        }
    }

    Process {
        id: setProc
        stdout: SplitParser {
            onRead: data => {
                try {
                    let payload = JSON.parse(data.trim())
                    root.pinnedCity = payload.city || ""
                } catch (e) {}
                root.searchResults = []
                // Re-read straight away so the panel reflects the choice.
                root.fetchWeather()
            }
        }
    }

    Process {
        id: readPinnedProc
        command: ["bash", "-c",
            "python3 -c \"import json,os;p=os.path.expanduser('~/.config/huginn_weather.json');print(json.load(open(p)).get('city','') if os.path.exists(p) else '')\""]
        running: true
        stdout: SplitParser {
            onRead: data => root.pinnedCity = data.trim()
        }
    }

    Process {
        id: weatherProc
        command: ["python3", Quickshell.env("HOME") + "/.config/huginn/services/python/weather_service.py"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                let report
                try {
                    report = JSON.parse(data.trim())
                } catch (e) {
                    root.available = false
                    root.lastError = "unreadable response"
                    return
                }

                if (!report || !report.ok) {
                    root.available = false
                    root.lastError = report && report.error ? report.error : "lookup failed"
                    root.city = ""
                    root.condition = ""
                    root.forecastData = []
                    return
                }

                root.city = report.city || ""
                root.tempC = report.temp
                root.weatherCode = report.code || 0
                root.condition = root.getWeatherDescription(root.weatherCode)
                root.isDay = report.isDay !== 0

                // Set before building the list: getWeatherIcon returns the
                // unavailable glyph while this is false, so every forecast day
                // came out as a placeholder.
                root.lastError = ""
                root.available = true

                let list = []
                if (Array.isArray(report.forecast)) {
                    for (let i = 0; i < report.forecast.length; i++) {
                        let item = report.forecast[i]
                        list.push({
                            day: item.day,
                            temp: item.temp,
                            icon: root.getWeatherIcon(item.code)
                        })
                    }
                }
                root.forecastData = list
            }
        }
    }

    // Retries sooner while there is nothing to show, so a shell that started
    // before the network was up does not sit on a dash for a quarter of an hour.
    Timer {
        interval: root.available ? 900000 : 60000
        running: true
        repeat: true
        onTriggered: root.fetchWeather()
    }
}
