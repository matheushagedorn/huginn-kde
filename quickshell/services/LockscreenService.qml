pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property bool isLocked: false
    property bool isUnlocking: false
    property string userPassword: ""
    property bool isAuthenticating: false
    property bool authFailed: false
    property string authErrorMsg: ""
    property int typedCount: 0
    property string username: ""
    property string realName: ""
    property string avatarPath: ""

    // Signal emitted whenever a key is typed to trigger animated dot entry/bounce
    signal keyTyped(string char)
    signal keyDeleted()

    Timer {
        id: resetErrorTimer
        interval: 2000
        repeat: false
        onTriggered: {
            root.authFailed = false
            root.authErrorMsg = ""
        }
    }

    Timer {
        id: unlockGraceTimer
        interval: 2500
        repeat: false
        onTriggered: {
            root.isUnlocking = false
        }
    }

    Component.onCompleted: {
        usernameProc.running = true
        avatarProc.running = true
    }

    Process {
        id: avatarProc
        command: ["python3", "-c", "import os; u = os.environ.get('USER', ''); paths = [f'/var/lib/AccountsService/icons/{u}', os.path.expanduser('~/.face'), os.path.expanduser('~/.face.icon')]; print(next((p for p in paths if os.path.exists(p) and os.path.getsize(p) > 0), ''))"]
        stdout: SplitParser {
            onRead: data => {
                let p = data.trim()
                if (p !== "") root.avatarPath = "file://" + p
            }
        }
    }

    Timer {
        interval: 300
        running: true
        repeat: true
        onTriggered: {
            if (!checkLockTriggerProc.running) checkLockTriggerProc.running = true
        }
    }

    Process {
        id: checkLockTriggerProc
        command: ["bash", "-c", "if [ -f /tmp/quickshell_lock_trigger ] || pidof kscreenlocker_greet >/dev/null; then rm -f /tmp/quickshell_lock_trigger; echo 'LOCK'; fi"]
        stdout: SplitParser {
            onRead: data => {
                if (data.trim() === "LOCK" && !root.isLocked && !root.isUnlocking) {
                    root.lock()
                }
            }
        }
    }

    Process {
        id: usernameProc
        command: ["whoami"]
        stdout: SplitParser {
            onRead: data => {
                let u = data.trim()
                if (u !== "") root.username = u
            }
        }
    }

    function lock() {
        PopupService.closeAll()
        userPassword = ""
        typedCount = 0
        authFailed = false
        authErrorMsg = ""
        isLocked = true
        isUnlocking = false
        disableEffectsProc.running = true
    }

    function unlock() {
        userPassword = ""
        typedCount = 0
        authFailed = false
        authErrorMsg = ""
        isLocked = false
        isUnlocking = true
        unlockGraceTimer.restart()
        enableEffectsProc.running = true
        unlockPlasmaProc.running = true
    }

    Process {
        id: unlockPlasmaProc
        command: ["bash", "-c", "loginctl unlock-session 2>/dev/null; sleep 0.2; pkill -9 -f kscreenlocker_greet 2>/dev/null || true"]
        onExited: running = false
    }

    Process {
        id: disableEffectsProc
        command: ["bash", "-c", "qdbus org.kde.KWin /Effects org.kde.kwin.Effects.unloadEffect overview 2>/dev/null; qdbus org.kde.KWin /Effects org.kde.kwin.Effects.unloadEffect grid 2>/dev/null; qdbus org.kde.KWin /Effects org.kde.kwin.Effects.unloadEffect presentwindows 2>/dev/null"]
        onExited: running = false
    }

    Process {
        id: enableEffectsProc
        command: ["bash", "-c", "qdbus org.kde.KWin /Effects org.kde.kwin.Effects.loadEffect overview 2>/dev/null; qdbus org.kde.KWin /Effects org.kde.kwin.Effects.loadEffect grid 2>/dev/null; qdbus org.kde.KWin /Effects org.kde.kwin.Effects.loadEffect presentwindows 2>/dev/null"]
        onExited: running = false
    }

    function appendChar(ch) {
        if (isAuthenticating) return;
        authFailed = false
        userPassword += ch
        typedCount = userPassword.length
        root.keyTyped(ch)
    }

    function backspace() {
        if (isAuthenticating) return;
        authFailed = false
        if (userPassword.length > 0) {
            userPassword = userPassword.substring(0, userPassword.length - 1)
            typedCount = userPassword.length
            root.keyDeleted()
        }
    }

    function clearPassword() {
        userPassword = ""
        typedCount = 0
    }

    function submitPassword() {
        if (isAuthenticating || userPassword === "") return;
        isAuthenticating = true
        authFailed = false
        authErrorMsg = ""

        authProc.command = ["python3", Quickshell.env("HOME") + "/.config/quickshell/services/python/lockscreen_auth_service.py", userPassword]
        authProc.running = true
    }

    Process {
        id: authProc
        onExited: (code, exitStatus) => {
            root.isAuthenticating = false
            if (code === 0) {
                root.unlock()
            } else {
                root.authFailed = true
                root.authErrorMsg = "Incorrect password"
                root.clearPassword()
                resetErrorTimer.restart()
            }
        }
    }
}
