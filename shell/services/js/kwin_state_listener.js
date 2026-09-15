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
var lastSignature = "";

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
        // "quickshell" here is the window class of the shell's own process,
        // reported by the framework it runs on. It is not a name this project
        // chooses, and it has to keep matching what KWin sees.
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
                    // A window maximized on another virtual desktop leaves
                    // this one showing the desktop, so it must not count as
                    // covering the screen.
                    var onHere = w.onAllDesktops
                        || !w.desktops
                        || w.desktops.length === 0
                        || w.desktops.indexOf(workspace.currentDesktop) >= 0;
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
                        active: (w === activeWin || w.active || false),
                        // Whether this window owns its whole screen, and which
                        // screen that is: the bar goes edge to edge on an
                        // output that has nothing of the desktop left showing.
                        maximized: (w.maximizeMode === 3) && onHere,
                        fullScreen: (w.fullScreen || false) && onHere,
                        output: (w.output && w.output.name) ? w.output.name : ""
                    });
                }
            }
        }
    }

    // frameGeometryChanged fires on every frame of a drag or resize. The
    // shell only reads a handful of these fields, so a payload that differs
    // only in pixel position is not worth a DBus round trip and a rebuild of
    // the dock on the other side.
    var signature = actApp + "|" + isFullscreen;
    for (var s = 0; s < openApps.length; s++) {
        var a = openApps[s];
        signature += "|" + a.id + "," + a.appId + "," + a.caption + "," + a.minimized
                  + "," + a.active + "," + a.maximized + "," + a.fullScreen + "," + a.output;
    }
    if (signature === lastSignature) return;
    lastSignature = signature;

    try {
        callDBus("io.huginn.ActiveApp", "/ActiveApp", "io.huginn.ActiveApp", "updateState", actApp, JSON.stringify(openApps), isFullscreen ? "true" : "false");
    } catch(e) {}
}

function onWindowEvent() {
    updateWindows();
    fitMaximizedWindows();
}

// Which windows are already being listened to, by internalId. KWin objects
// cannot carry a flag of our own, so the bookkeeping lives here.
var watched = {};

// A window changing state is not a workspace event.
//
// The listener only heard about windows appearing, disappearing and being
// activated, so minimising and maximising went unreported: the bar kept
// whatever it had decided the last time a window was activated, which is why
// it stayed floating over a maximized window and stayed full width after a
// minimise. These are the signals that actually say a window changed shape.
function watchWindow(w) {
    if (!w) return;
    var key = String(w.internalId || w.windowId || "");
    if (!key || watched[key]) return;
    watched[key] = true;

    // updateWindows only, never the refit: the bar animates its reserved area
    // when a window is maximized, every frame of that lands here as a
    // geometry change, and refitting on each one would fight the animation.
    var signals = ["minimizedChanged", "fullScreenChanged", "maximizedAboutToChange",
                   "frameGeometryChanged", "outputChanged", "desktopsChanged"];
    for (var i = 0; i < signals.length; i++) {
        try {
            if (w[signals[i]] && w[signals[i]].connect) w[signals[i]].connect(updateWindows);
        } catch (e) {}
    }
}

function onWindowAdded(w) {
    watchWindow(w);
    onWindowEvent();
}

function onWindowRemoved(w) {
    if (w) {
        var key = String(w.internalId || w.windowId || "");
        if (key) delete watched[key];
    }
    updateWindows();
}

function watchAll() {
    var wins = workspace.windowList();
    for (var i = 0; i < wins.length; i++) watchWindow(wins[i]);
}

// The bar fills the screen only while something covers it, so a desktop
// switch has to be reported like any window event.
workspace.currentDesktopChanged.connect(updateWindows);
workspace.windowActivated.connect(onWindowEvent);
workspace.windowAdded.connect(onWindowAdded);
workspace.windowRemoved.connect(onWindowRemoved);

watchAll();

// Runs as the shell starts, which is exactly when the reserved area comes
// back and windows may be left stranded underneath the bar.
updateWindows();
fitMaximizedWindows();
