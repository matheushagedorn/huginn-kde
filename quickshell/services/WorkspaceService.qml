pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property bool hasWorkspaces: false
    property int activeWorkspace: 1
    property int totalWorkspaces: 0
    property var workspaces: []
    property var workspaceNames: []

    property bool isManualSwitching: false

    Timer {
        id: manualSwitchGuardTimer
        interval: 500
        repeat: false
        onTriggered: {
            root.isManualSwitching = false
        }
    }

    function switchTo(index) {
        if (index <= 0) return;
        root.isManualSwitching = true
        root.activeWorkspace = index
        manualSwitchGuardTimer.restart()
        Quickshell.execDetached(["python3", Quickshell.env("HOME") + "/.config/quickshell/services/python/workspace_service.py", "switch", index.toString()])
    }

    Process {
        id: queryProc
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/services/python/workspace_service.py"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    let parsed = JSON.parse(data.trim())
                    if (parsed && typeof parsed === "object") {
                        root.hasWorkspaces = parsed.hasWorkspaces === true && parsed.totalWorkspaces > 0
                        if (!root.isManualSwitching || parsed.activeWorkspace === root.activeWorkspace) {
                            root.activeWorkspace = parsed.activeWorkspace || 1
                            if (parsed.activeWorkspace === root.activeWorkspace) {
                                root.isManualSwitching = false
                            }
                        }
                        root.totalWorkspaces = parsed.totalWorkspaces || 0
                        root.workspaces = parsed.workspaces || []
                        
                        let names = []
                        if (Array.isArray(parsed.workspaces)) {
                            for (let i = 0; i < parsed.workspaces.length; i++) {
                                names.push(parsed.workspaces[i].name)
                            }
                        }
                        root.workspaceNames = names
                    }
                } catch (e) {
                    root.hasWorkspaces = false
                }
            }
        }
    }

    Timer {
        interval: 120
        running: true
        repeat: true
        onTriggered: {
            if (!queryProc.running) queryProc.running = true
        }
    }
}
