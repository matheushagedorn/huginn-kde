pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property var items: []

    Component.onCompleted: {
        scanClipboard()
    }

    function copyEntry(id) {
        var entry = items.find(i => i.id === id)
        if (!entry) return

        copyProc.running = false
        if (entry.type === "image") {
            copyProc.command = ["bash", "-c", "wl-copy --type image/png < " + entry.path]
        } else {
            copyProc.command = ["wl-copy", entry.content]
        }
        copyProc.running = true
    }

    function deleteEntry(id) {
        var entry = items.find(i => i.id === id)
        var arr = []
        for (var i = 0; i < items.length; i++) {
            if (items[i].id !== id) {
                arr.push(items[i])
            }
        }
        items = arr
        itemsChanged()

        if (entry) {
            let query = entry.type === "image" ? entry.hash : (entry.content ? entry.content.substring(0, 40) : entry.hash)
            if (query) {
                deleteProc.running = false
                deleteProc.command = ["python3", Quickshell.env("HOME") + "/.config/quickshell/services/python/clipboard_service.py", "delete", query]
                deleteProc.running = true
            }
        }
    }

    function clearAll() {
        scanProc.running = false
        copyProc.running = false
        items = []
        itemsChanged()
        copyProc.command = ["bash", "-c", "cliphist wipe 2>/dev/null; wl-copy -c 2>/dev/null; python3 " + Quickshell.env("HOME") + "/.config/quickshell/services/python/clipboard_service.py clear 2>/dev/null"]
        copyProc.running = true
    }

    function restartService() {
        scanProc.running = false
        copyProc.running = false
        deleteProc.running = false
        items = []
        scanProc.running = true
    }

    function scanClipboard() {
        if (!copyProc.running && !scanProc.running) {
            scanProc.running = true
        }
    }

    Process {
        id: copyProc
        onExited: {
            copyProc.running = false
            if (root.items.length === 0) {
                scanProc.running = false
            }
        }
    }

    Process {
        id: deleteProc
        onExited: {
            deleteProc.running = false
        }
    }

    Process {
        id: scanProc
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/services/python/clipboard_service.py"]
        running: false
        onExited: {
            scanProc.running = false
        }
        stdout: SplitParser {
            onRead: data => root.handleData(data)
        }
    }

    function handleData(data) {
        if (!data) return
        let trimmed = data.trim()
        if (!trimmed) return

        let rawItems = []
        try {
            let parsed = JSON.parse(trimmed)
            if (Array.isArray(parsed)) {
                rawItems = parsed
            } else if (parsed && typeof parsed === "object") {
                rawItems = [parsed]
            }
        } catch (e) {
            let lines = trimmed.split("\n")
            for (let i = 0; i < lines.length; i++) {
                let line = lines[i].trim()
                if (!line) continue
                try {
                    let obj = JSON.parse(line)
                    if (obj) rawItems.push(obj)
                } catch (err) {}
            }
        }

        if (!rawItems || rawItems.length === 0) return

        let d = new Date()
        let hours = d.getHours() < 10 ? "0" + d.getHours() : "" + d.getHours()
        let mins = d.getMinutes() < 10 ? "0" + d.getMinutes() : "" + d.getMinutes()
        let currentTime = hours + ":" + mins

        let existingTimeMap = {}
        if (root.items) {
            for (let k = 0; k < root.items.length; k++) {
                if (root.items[k] && root.items[k].hash) {
                    existingTimeMap[root.items[k].hash] = root.items[k].time || currentTime
                }
            }
        }

        let parsedList = []
        for (let i = 0; i < rawItems.length; i++) {
            let item = rawItems[i]
            if (item && item.hash) {
                if (parsedList.some(existing => existing.hash === item.hash)) continue

                item.id = item.hash
                item.time = existingTimeMap[item.hash] || currentTime
                parsedList.push(item)
                if (parsedList.length >= 30) break
            }
        }

        let isDifferent = false
        if (!root.items || root.items.length !== parsedList.length) {
            isDifferent = true
        } else {
            for (let j = 0; j < parsedList.length; j++) {
                if (!root.items[j] || root.items[j].hash !== parsedList[j].hash) {
                    isDifferent = true
                    break
                }
            }
        }

        if (isDifferent) {
            root.items = parsedList
        }
    }

    Timer {
        interval: 2500
        running: true
        repeat: true
        onTriggered: scanClipboard()
    }
}
