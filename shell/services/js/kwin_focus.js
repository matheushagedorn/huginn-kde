// KWin JavaScript Script: Focus, Restore, or Cycle Application Windows
var name = "%APP_NAME%".toLowerCase().trim();
var targetId = "%TARGET_ID%".toLowerCase().trim();
var ix = %ICON_X%;
var iy = %ICON_Y%;

function isSameWin(w1, w2) {
    if (!w1 || !w2) return false;
    if (w1 === w2) return true;
    var id1 = (w1.internalId ? w1.internalId.toString() : (w1.windowId ? String(w1.windowId) : "")).toLowerCase().trim();
    var id2 = (w2.internalId ? w2.internalId.toString() : (w2.windowId ? String(w2.windowId) : "")).toLowerCase().trim();
    if (id1 && id2 && id1 === id2) return true;
    if (w1.caption && w2.caption && w1.caption === w2.caption && w1.resourceClass === w2.resourceClass) return true;
    return false;
}

if ((name && name !== "") || (targetId && targetId !== "")) {
    var windows = workspace.windowList();
    var exactWin = null;
    var matchingWindows = [];

    // Pass 1: Strict Target UUID Match (e.g. from preview card click)
    if (targetId && targetId !== "") {
        for (var i = 0; i < windows.length; i++) {
            var w1 = windows[i];
            if (!w1.normalWindow && !w1.fullScreen && !w1.managed) continue;

            var uuid1 = (w1.internalId ? w1.internalId.toString() : (w1.windowId ? String(w1.windowId) : "")).toLowerCase().trim();
            if (uuid1 && (uuid1 === targetId || uuid1.indexOf(targetId) !== -1 || targetId.indexOf(uuid1) !== -1)) {
                exactWin = w1;
                break;
            }
        }
    }

    // Pass 2: Class and Caption group collection
    if (!exactWin && name && name !== "") {
        for (var j = 0; j < windows.length; j++) {
            var w2 = windows[j];
            if (!w2.normalWindow && !w2.fullScreen && !w2.managed) continue;

            var cls2 = (w2.desktopFileName || w2.resourceClass || w2.resourceName || "").toLowerCase().trim();
            var cap2 = (w2.caption || "").toLowerCase().trim();

            var matches = false;
            if (cls2 === name) {
                matches = true;
            } else if (name.indexOf("code") !== -1 || name.indexOf("visual") !== -1 || name.indexOf("vscodium") !== -1) {
                if (cls2.indexOf("code") !== -1 || cls2.indexOf("vscodium") !== -1 || cap2.indexOf("visual studio code") !== -1 || cap2.indexOf("code - ") !== -1) {
                    matches = true;
                }
            } else if (name.indexOf("overwatch") !== -1 || name.indexOf("2357570") !== -1) {
                if (cls2.indexOf("overwatch") !== -1 || cap2.indexOf("overwatch") !== -1 || cls2 === "steam_app_2357570") {
                    matches = true;
                }
            } else if (name.indexOf("steam_app_") !== -1) {
                if (cls2 === name || cls2.indexOf(name) !== -1) {
                    matches = true;
                }
            } else if (name !== "steam") {
                if (cls2 && cls2 !== "steam" && (cls2.indexOf(name) !== -1 || name.indexOf(cls2) !== -1)) {
                    matches = true;
                } else if (cap2 && cap2.indexOf(name) !== -1) {
                    matches = true;
                }
            }

            if (matches) {
                matchingWindows.push(w2);
            }
        }
    }

    var activeWin = workspace.activeWindow;

    // 1. Direct Preview Card Specific Window Click (exactWin found or targetId set)
    if (exactWin || (targetId && targetId !== "" && matchingWindows.length > 0)) {
        var winToFocus = exactWin || matchingWindows[0];
        try { winToFocus.setMinimizeIconGeometry(Qt.rect(ix, iy, 42, 42)); } catch(e) {}
        winToFocus.minimized = false;
        workspace.activeWindow = winToFocus;
    }
    // 2. Main Dock App Icon Click (Single Window -> Toggle Minimize / Focus)
    else if (matchingWindows.length === 1) {
        var targetWin = matchingWindows[0];
        try { targetWin.setMinimizeIconGeometry(Qt.rect(ix, iy, 42, 42)); } catch(e) {}
        if ((targetWin.active || isSameWin(activeWin, targetWin)) && !targetWin.minimized) {
            targetWin.minimized = true;
        } else {
            targetWin.minimized = false;
            workspace.activeWindow = targetWin;
        }
    }
    // 3. Main Dock App Icon Click (Multiple Windows -> Cycle or Toggle Minimize)
    else if (matchingWindows.length > 1) {
        var activeIdx = -1;
        for (var k = 0; k < matchingWindows.length; k++) {
            var mw = matchingWindows[k];
            if ((mw.active || isSameWin(activeWin, mw)) && !mw.minimized) {
                activeIdx = k;
                break;
            }
        }

        var nextIdx = 0;
        if (activeIdx !== -1) {
            nextIdx = (activeIdx + 1) % matchingWindows.length;
        }

        var winToActivate = matchingWindows[nextIdx];
        try { winToActivate.setMinimizeIconGeometry(Qt.rect(ix, iy, 42, 42)); } catch(e) {}

        if (activeIdx !== -1 && activeIdx === nextIdx && !winToActivate.minimized) {
            winToActivate.minimized = true;
        } else {
            winToActivate.minimized = false;
            workspace.activeWindow = winToActivate;
        }
    }
}
