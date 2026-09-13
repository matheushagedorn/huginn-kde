// KWin JavaScript Script: Active Window, Open Windows & Fullscreen DBus Listener
function updateWindows() {
    var openApps = [];
    var actApp = "";
    var isFullscreen = false;
    var wins = workspace.windowList();
    var activeWin = workspace.activeWindow;

    if (activeWin) {
        var actCls = (activeWin.resourceClass || activeWin.desktopFileName || activeWin.resourceName || "").toLowerCase();
        if (!actCls && activeWin.caption) actCls = activeWin.caption.toLowerCase();
        if (actCls && actCls !== "quickshell" && actCls !== "plasmashell") {
            actApp = actCls;
        }
        if (activeWin.fullScreen) {
            isFullscreen = true;
        }
    }

    for (var i = 0; i < wins.length; i++) {
        var w = wins[i];
        if (w.fullScreen && (w.active || w === activeWin)) {
            isFullscreen = true;
        }
        if (w.normalWindow || w.fullScreen || w.managed) {
            var cls = (w.desktopFileName || w.resourceClass || w.resourceName || "").toLowerCase();
            if (!cls && w.caption) cls = w.caption.toLowerCase();
            if (cls) {
                var isSystemShell = (cls === "quickshell" || cls === "plasmashell" || cls === "krunner" ||
                                     cls.indexOf("status_icon") !== -1 || cls.indexOf("tray") !== -1 || cls.indexOf("desktop") !== -1);
                if (!isSystemShell) {
                    var winId = String(w.internalId || w.windowId || (cls + "_" + i));
                    var fg = w.frameGeometry || w.clientGeometry || w.bufferGeometry || {};
                    var wx = Math.round(fg.x !== undefined ? fg.x : (w.x || 0));
                    var wy = Math.round(fg.y !== undefined ? fg.y : (w.y || 0));
                    var ww = Math.round(fg.width !== undefined ? fg.width : (w.width || 800));
                    var wh = Math.round(fg.height !== undefined ? fg.height : (w.height || 600));

                    openApps.push({
                        id: winId,
                        appId: cls,
                        caption: w.caption || cls,
                        x: wx,
                        y: wy,
                        width: ww,
                        height: wh,
                        minimized: w.minimized || false,
                        active: (w === activeWin || w.active || false)
                    });
                }
            }
        }
    }

    try {
        callDBus("io.quickshell.ActiveApp", "/ActiveApp", "io.quickshell.ActiveApp", "updateState", actApp, JSON.stringify(openApps), isFullscreen ? "true" : "false");
    } catch(e) {}
}

workspace.windowActivated.connect(updateWindows);
workspace.windowAdded.connect(updateWindows);
workspace.windowRemoved.connect(updateWindows);
updateWindows();
