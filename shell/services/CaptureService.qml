pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    readonly property string runnerScript: Quickshell.env("HOME") + "/.config/huginn/services/python/spectacle_runner.py"

    function captureRegion() {
        PopupService.closeAll()
        Quickshell.execDetached(["python3", runnerScript, "region"])
    }

    function captureFullscreen() {
        PopupService.closeAll()
        Quickshell.execDetached(["python3", runnerScript, "fullscreen"])
    }

    function captureWindow() {
        PopupService.closeAll()
        Quickshell.execDetached(["python3", runnerScript, "window"])
    }

    function recordRegion() {
        PopupService.closeAll()
        Quickshell.execDetached(["python3", runnerScript, "record_region"])
    }

    function recordScreen() {
        PopupService.closeAll()
        Quickshell.execDetached(["python3", runnerScript, "record_screen"])
    }

    function openGui() {
        PopupService.closeAll()
        Quickshell.execDetached(["python3", runnerScript, "gui"])
    }
}
