// KWin JS Script: Temporarily Raise Specific Window to Front on Live Preview Hover
var targetId = "%TARGET_ID%".toLowerCase().trim();
var appName = "%APP_NAME%".toLowerCase().trim();

if ((targetId && targetId !== "") || (appName && appName !== "")) {
    var windows = workspace.windowList();
    var targetWin = null;

    // Pass 1: Strict Target UUID Match across all windows
    if (targetId && targetId !== "") {
        for (var i = 0; i < windows.length; i++) {
            var w1 = windows[i];
            if (!w1.normalWindow && !w1.fullScreen && !w1.managed) continue;

            var uuid1 = (w1.internalId ? w1.internalId.toString() : (w1.windowId ? String(w1.windowId) : "")).toLowerCase().trim();
            if (uuid1 && (uuid1 === targetId || uuid1.indexOf(targetId) !== -1 || targetId.indexOf(uuid1) !== -1)) {
                targetWin = w1;
                break;
            }
        }
    }

    // Pass 2: Fallback Caption / Class Match (only if UUID target was not matched)
    if (!targetWin && appName && appName !== "") {
        for (var j = 0; j < windows.length; j++) {
            var w2 = windows[j];
            if (!w2.normalWindow && !w2.fullScreen && !w2.managed) continue;

            var cls2 = (w2.desktopFileName || w2.resourceClass || w2.resourceName || "").toLowerCase().trim();
            var cap2 = (w2.caption || "").toLowerCase().trim();

            if (cap2 && (cap2 === appName || cap2.indexOf(appName) !== -1)) {
                targetWin = w2;
                break;
            }
            if (!targetWin && cls2 && (cls2 === appName || cls2.indexOf(appName) !== -1)) {
                targetWin = w2;
            }
        }
    }

    if (targetWin) {
        if (targetWin.minimized) {
            targetWin.minimized = false;
        }
        workspace.activeWindow = targetWin;
    }
}
