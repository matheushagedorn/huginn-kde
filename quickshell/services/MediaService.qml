pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property string playerName: ""
    property string playerDisplayName: getDisplayName(playerName)
    property string title: ""
    property string artist: ""
    property string album: ""
    property string artUrl: ""
    property string status: "Stopped"
    property bool hasPlayer: false
    property bool isSeeking: false

    property real position: 0
    property real length: 0
    property real progress: length > 0 ? Math.min(1.0, Math.max(0.0, position / length)) : 0.0
    property string positionStr: formatTime(position)
    property string lengthStr: length > 0 ? formatTime(length) : "--:--"

    function formatTime(secs) {
        if (isNaN(secs) || secs <= 0) return "0:00"
        var m = Math.floor(secs / 60)
        var s = Math.floor(secs % 60)
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    function getDisplayName(name) {
        if (!name) return ""
        let lower = name.toLowerCase()
        if (lower.indexOf("firefox") !== -1) return "Firefox"
        if (lower.indexOf("zen") !== -1) return "Zen"
        if (lower.indexOf("chrome") !== -1 || lower.indexOf("chromium") !== -1) return "Chrome"
        if (lower.indexOf("brave") !== -1) return "Brave"
        if (lower.indexOf("spotify") !== -1) return "Spotify"
        if (lower.indexOf("feishin") !== -1) return "Feishin"
        if (lower.indexOf("vlc") !== -1) return "VLC"
        if (lower.indexOf("mpv") !== -1) return "MPV"
        if (lower.indexOf("amberol") !== -1) return "Amberol"
        return name.charAt(0).toUpperCase() + name.slice(1)
    }

    function extractYouTubeArt(url) {
        if (!url) return "";
        var match = url.match(/(?:v=|\/vi\/|youtu\.be\/)([a-zA-Z0-9_-]{11})/);
        if (match && match[1]) {
            return "https://img.youtube.com/vi/" + match[1] + "/hqdefault.jpg";
        }
        return "";
    }

    function playPause() {
        var pName = root.playerName !== "" ? root.playerName : "%any"
        Quickshell.execDetached(["bash", "-c", "playerctl -p '" + pName + "' play-pause 2>/dev/null || true"])
    }

    function next() {
        root.position = 0
        var pName = root.playerName !== "" ? root.playerName : "%any"
        Quickshell.execDetached(["bash", "-c", "playerctl -p '" + pName + "' next 2>/dev/null || true"])
    }

    function previous() {
        root.position = 0
        var pName = root.playerName !== "" ? root.playerName : "%any"
        Quickshell.execDetached(["bash", "-c", "playerctl -p '" + pName + "' previous 2>/dev/null || true"])
    }

    function seek(targetSec) {
        if (length > 0) {
            var validSec = Math.max(0, Math.min(length, targetSec))
            root.position = validSec
            root.isSeeking = true
            seekTimer.restart()

            var targetMicro = Math.floor(validSec * 1000000)
            Quickshell.execDetached([
                "bash", "-c",
                "PLAYER_SERVICE=$(busctl --user list | grep -m1 'org.mpris.MediaPlayer2' | awk '{print $1}'); " +
                "TRACK_ID=$(playerctl metadata --format '{{mpris:trackid}}' | tr -d \"'\"); " +
                "[ -z \"$TRACK_ID\" ] && TRACK_ID=\"/org/mpris/MediaPlayer2/TrackList/NoTrack\"; " +
                "busctl --user call \"$PLAYER_SERVICE\" /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player SetPosition ox \"$TRACK_ID\" " + targetMicro
            ])
        }
    }

    Timer {
        id: seekTimer
        interval: 3000
        repeat: false
        onTriggered: root.isSeeking = false
    }

    // Continuous Real-Time Streaming Metadata Process (0ms latency, zero polling lag)
    Process {
        id: mprisProc
        command: ["playerctl", "metadata", "--follow", "--format", "{{playerName}}|||{{title}}|||{{artist}}|||{{album}}|||{{mpris:artUrl}}|||{{mpris:length}}|||{{xesam:url}}|||{{status}}"]
        running: true

        stdout: SplitParser {
            onRead: data => {
                let parts = data.trim().split("|||")
                if (parts.length >= 8) {
                    let newPlayerName = parts[0] ? parts[0].trim() : ""
                    let rawTitle = parts[1] ? parts[1].trim() : ""
                    let rawArtist = parts[2] ? parts[2].trim() : ""
                    let rawAlbum = parts[3] ? parts[3].trim() : ""
                    let rawArt = parts[4] ? parts[4].trim() : ""
                    let pageUrl = parts.length >= 7 ? parts[6].trim() : ""
                    let newStatus = parts[7] ? parts[7].trim() : "Stopped"

                    let newTitle = rawTitle
                    if (!newTitle || newTitle === "No Title" || newTitle === "undefined") {
                        if (pageUrl && pageUrl.includes("/")) {
                            try {
                                let lastSegment = pageUrl.substring(pageUrl.lastIndexOf("/") + 1)
                                if (lastSegment.includes("watch?v=")) {
                                    newTitle = "YouTube Media"
                                } else if (lastSegment.includes(".")) {
                                    lastSegment = lastSegment.substring(0, lastSegment.lastIndexOf("."))
                                    if (lastSegment) newTitle = decodeURIComponent(lastSegment).replace(/[_-]/g, " ")
                                }
                            } catch (e) {}
                        }
                        if (!newTitle || newTitle === "No Title" || newTitle === "undefined") {
                            newTitle = newPlayerName ? root.getDisplayName(newPlayerName) + " Audio" : "Playing Media"
                        }
                    }

                    let newArtist = (rawArtist && rawArtist !== "Unknown Artist") ? rawArtist : ""

                    // Smart Active Player Filter:
                    // 1. If incoming status is "Playing", prioritize and switch to this active player!
                    // 2. Accept updates from the current active player.
                    // 3. Block idle background events from secondary paused players while music is active.
                    let isCurrentPlayer = (root.playerName === "" || root.playerName === newPlayerName)
                    let isPlayingEvent = (newStatus === "Playing")
                    let isCurrentlyStopped = (root.status !== "Playing")

                    if (isPlayingEvent || isCurrentPlayer || isCurrentlyStopped) {
                        let fetchedArt = rawArt !== "" ? rawArt : root.extractYouTubeArt(pageUrl)

                        root.playerName = newPlayerName
                        root.title = newTitle
                        root.artist = newArtist
                        root.album = rawAlbum
                        root.artUrl = fetchedArt

                        if (parts[5] && parts[5] !== "") {
                            let lenMicro = parseFloat(parts[5])
                            if (!isNaN(lenMicro) && lenMicro > 0) {
                                root.length = lenMicro > 100000 ? lenMicro / 1000000.0 : lenMicro
                            }
                        }

                        if (newStatus === "Playing" || newStatus === "Paused" || newStatus === "Stopped") {
                            if (root.status !== newStatus) root.status = newStatus
                            root.hasPlayer = true
                        } else {
                            if (root.status !== "Stopped") root.status = "Stopped"
                            root.hasPlayer = false
                        }
                    }
                } else if (data.trim() === "" || data.includes("No players found")) {
                    root.hasPlayer = false
                    root.status = "Stopped"
                }
            }
        }
    }

    // Position sync timer
    Timer {
        interval: 500
        running: true
        repeat: true
        onTriggered: {
            if (root.status === "Playing" && root.length > 0) {
                root.position = Math.min(root.length, root.position + 0.5)
            }
            if (!root.isSeeking) {
                posProc.running = true
            }
        }
    }

    Process {
        id: posProc
        command: ["playerctl", "position"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                let posVal = parseFloat(data.trim())
                if (!isNaN(posVal) && posVal >= 0 && !root.isSeeking) {
                    root.position = posVal
                }
            }
        }
    }
}
