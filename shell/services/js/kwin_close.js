// KWin JavaScript Script: Close all windows matching an app class/caption
var name = "%APP_NAME%".toLowerCase().trim();

if (name && name !== "") {
    var windows = workspace.windowList();
    var matchingWindows = [];

    for (var j = 0; j < windows.length; j++) {
        var w = windows[j];
        if (!w.normalWindow && !w.fullScreen && !w.managed) continue;

        var cls = (w.desktopFileName || w.resourceClass || w.resourceName || "").toLowerCase().trim();
        var cap = (w.caption || "").toLowerCase().trim();

        var matches = false;
        if (cls === name) {
            matches = true;
        } else if (name !== "steam" && cls && cls !== "steam" && (cls.indexOf(name) !== -1 || name.indexOf(cls) !== -1)) {
            matches = true;
        } else if (cap && cap.indexOf(name) !== -1) {
            matches = true;
        }

        if (matches) {
            matchingWindows.push(w);
        }
    }

    for (var k = 0; k < matchingWindows.length; k++) {
        try { matchingWindows[k].closeWindow(); } catch (e) {}
    }
}
