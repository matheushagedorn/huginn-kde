pragma Singleton
import QtQuick

Item {
    id: root

    property bool sessionMenuOpen: false
    property bool calendarMenuOpen: false
    property bool weatherPickerOpen: false
    property bool mediaMenuOpen: false
    property bool notificationMenuOpen: false
    property bool captureMenuOpen: false
    property bool clipboardMenuOpen: false
    property bool audioMenuOpen: false
    property bool bluetoothMenuOpen: false
    property bool brightnessMenuOpen: false
    property bool mountMenuOpen: false
    property bool networkMenuOpen: false
    property bool batteryMenuOpen: false
    property bool trayMenuOpen: false
    property bool dockMenuOpen: false
    property bool appLauncherOpen: false
    property bool themePickerOpen: false
    property bool wallpaperPickerOpen: false
    property bool previewOpen: false
    property bool contextMenuOpen: false

    property bool anyOpen: sessionMenuOpen || calendarMenuOpen || weatherPickerOpen || mediaMenuOpen || notificationMenuOpen || captureMenuOpen || clipboardMenuOpen || audioMenuOpen || bluetoothMenuOpen || brightnessMenuOpen || mountMenuOpen || networkMenuOpen || batteryMenuOpen || trayMenuOpen || dockMenuOpen || appLauncherOpen || themePickerOpen || wallpaperPickerOpen || contextMenuOpen

    function closeAll() {
        sessionMenuOpen = false
        calendarMenuOpen = false
        weatherPickerOpen = false
        mediaMenuOpen = false
        notificationMenuOpen = false
        captureMenuOpen = false
        clipboardMenuOpen = false
        audioMenuOpen = false
        bluetoothMenuOpen = false
        brightnessMenuOpen = false
        mountMenuOpen = false
        networkMenuOpen = false
        batteryMenuOpen = false
        trayMenuOpen = false
        dockMenuOpen = false
        appLauncherOpen = false
        themePickerOpen = false
        wallpaperPickerOpen = false
        previewOpen = false
        contextMenuOpen = false
    }

    function toggleThemePicker() {
        let state = !themePickerOpen
        closeAll()
        themePickerOpen = state
    }

    function toggleWallpaperPicker() {
        let state = !wallpaperPickerOpen
        closeAll()
        wallpaperPickerOpen = state
    }

    function toggleSession() {
        let state = !sessionMenuOpen
        closeAll()
        sessionMenuOpen = state
    }

    function toggleCalendar() {
        let state = !calendarMenuOpen
        closeAll()
        calendarMenuOpen = state
    }

    function toggleWeatherPicker() {
        let state = !weatherPickerOpen
        closeAll()
        weatherPickerOpen = state
    }

    function toggleMedia() {
        let state = !mediaMenuOpen
        closeAll()
        mediaMenuOpen = state
    }

    function toggleNotification() {
        let state = !notificationMenuOpen
        closeAll()
        notificationMenuOpen = state
    }

    function toggleCapture() {
        let state = !captureMenuOpen
        closeAll()
        captureMenuOpen = state
    }

    function toggleClipboard() {
        let state = !clipboardMenuOpen
        closeAll()
        clipboardMenuOpen = state
    }

    function toggleAudio() {
        let state = !audioMenuOpen
        closeAll()
        audioMenuOpen = state
    }

    function toggleBluetooth() {
        let state = !bluetoothMenuOpen
        closeAll()
        bluetoothMenuOpen = state
    }

    function toggleBrightness() {
        let state = !brightnessMenuOpen
        closeAll()
        brightnessMenuOpen = state
    }

    function toggleMount() {
        let state = !mountMenuOpen
        closeAll()
        mountMenuOpen = state
    }

    function toggleNetwork() {
        let state = !networkMenuOpen
        closeAll()
        networkMenuOpen = state
    }

    function toggleBattery() {
        let state = !batteryMenuOpen
        closeAll()
        batteryMenuOpen = state
    }

    function toggleTray() {
        let state = !trayMenuOpen
        closeAll()
        trayMenuOpen = state
    }

    function toggleDockMenu() {
        let state = !dockMenuOpen
        closeAll()
        dockMenuOpen = state
    }

    function toggleAppLauncher() {
        if (LockscreenService.isLocked) return;
        let state = !appLauncherOpen
        closeAll()
        appLauncherOpen = state
    }
}
