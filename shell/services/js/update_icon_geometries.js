// KWin JavaScript Script: Set Minimize Icon Geometry for all matching open windows
var iconMapRaw = '%ICON_MAP_JSON%';

try {
    var iconMap = JSON.parse(iconMapRaw);
    var windows = workspace.windowList();
    
    for (var i = 0; i < windows.length; i++) {
        var win = windows[i];
        if (!win.normalWindow || win.skipTaskbar) continue;
        
        var cls = (win.resourceClass || win.desktopFileName || "").toLowerCase().trim();
        if (!cls) continue;

        for (var appId in iconMap) {
            var lowerApp = appId.toLowerCase().trim();
            if (!lowerApp) continue;
            if (cls.indexOf(lowerApp) !== -1 || lowerApp.indexOf(cls) !== -1) {
                var coords = iconMap[appId];
                if (coords && typeof coords.x === "number" && typeof coords.y === "number") {
                    try {
                        win.setMinimizeIconGeometry(Qt.rect(coords.x, coords.y, 42, 42));
                    } catch(e) {}
                }
                break;
            }
        }
    }
} catch (e) {}
