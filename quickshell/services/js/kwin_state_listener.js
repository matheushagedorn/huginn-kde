// KWin JavaScript Script: Active Window, Open Windows & Fullscreen DBus Listener
// Puts maximized windows back inside the area the bar reserves.
//
// The bar reserves its 54px correctly, and KWin usually re-fits maximized
// windows when that zone appears. Usually is not always: a window maximized
// while the shell was down keeps its full-screen geometry, stays flagged as
// maximized, and ends up sitting under the bar with no way back. Restarting
// the shell does not fix it, because nothing asks the window to re-maximize.
//
// So the shell asks. Cheap, idempotent, and a no-op on any window that is
// already where it belongs.
var fixingGeometry = false;

function fitMaximizedWindows() {
    if (fixingGeometry) return;
    fixingGeometry = true;
    try {
        var wins = workspace.windowList();
        for (var i = 0; i < wins.length; i++) {
            var w = wins[i];
            if (!w.normalWindow || w.fullScreen || w.minimized) continue;
            // 3 is MaximizeFull; anything less is not covering the work area
            if (w.maximizeMode !== 3) continue;
            if (!w.output) continue;

            var area = workspace.clientArea(KWin.MaximizeArea, w.output, workspace.currentDesktop);
            var geo = w.frameGeometry;
            var off = Math.abs(geo.x - area.x) + Math.abs(geo.y - area.y)
                    + Math.abs(geo.width - area.width) + Math.abs(geo.height - area.height);
            if (off <= 2) continue;   // already fitted, rounding aside

            w.setMaximize(false, false);
            w.setMaximize(true, true);
            // Rare enough to be worth a line in the journal of kwin_wayland:
            // if this shows up often, the reserved area is changing more than
            // it should.
            print("huginn: refitted " + w.resourceClass + " into " + area);
        }
    } catch (e) {
    } finally {
        fixingGeometry = false;
    }
}

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
                        // Wine and Proton report the same class for every
                        // game, so the pid is the only way back to which
                        // executable is actually running.
                        pid: w.pid || 0,
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

function onWindowEvent() {
    updateWindows();
    fitMaximizedWindows();
}

workspace.windowActivated.connect(onWindowEvent);
workspace.windowAdded.connect(onWindowEvent);
workspace.windowRemoved.connect(updateWindows);

// Runs as the shell starts, which is exactly when the reserved area comes
// back and windows may be left stranded underneath the bar.
updateWindows();
fitMaximizedWindows();
