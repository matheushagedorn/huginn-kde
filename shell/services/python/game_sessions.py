#!/usr/bin/env python3
"""Which windows are games, and how long each game has been played.

Game mode hides the bar and the dock and holds notifications while a game owns
the screen, so it has to tell a game from anything else that goes fullscreen.
A browser playing a video in fullscreen is the case that must not trip it: it
is fullscreen and active exactly like a game, and only the process behind the
window says otherwise.

What counts as a game, first match wins:

1. The window class says so. Proton names every window steam_app_<id> (or
   steam_app_default when nothing set an id, which is every Heroic and umu
   launch). Plain Wine names a window after its executable, so any class
   ending in .exe, plus the bare wine/wine64/proton classes. gamescope is a
   nested compositor that only ever runs games. Wine's own explorer.exe is
   the exception: it is Wine's desktop and tray, never the game.

2. The process was started as a game. Steam exports SteamGameId/SteamAppId to
   everything it launches, native Linux games included; Proton adds
   STEAM_COMPAT_DATA_PATH, Wine needs WINEPREFIX, umu sets GAMEID and Lutris
   LUTRIS_GAME_UUID. These are read from /proc/<pid>/environ, and only count
   when they differ from the shell's own environment: someone who exports
   WINEPREFIX in their profile would otherwise turn every window into a game.

   The environment is inherited, though, so a browser opened from a game or
   from the Steam overlay carries SteamGameId too, and its fullscreen video
   would pass. Rule 2 therefore ignores executables that belong to the
   system (/usr, /bin) or to a Flatpak (/app): games live in a library
   folder under the home directory, browsers do not.

Sessions are counted per game name, from the first window of that game
appearing to the last one closing, so a launcher and its game (Ubisoft
Connect and Far Cry, both steam_app_<same id>) make one session. Only runs of
at least MIN_SESSION_SECONDS are kept: anything shorter is a launch that
crashed or a launcher flashing a window, and would bury the real sessions.
"""
import json
import os
import time

CACHE_DIR = os.path.expanduser("~/.cache/huginn")
SESSIONS_PATH = os.path.join(CACHE_DIR, "play-sessions.json")
# The sessions still running, so a shell restart in the middle of a game
# picks the session up again instead of starting the clock over.
OPEN_PATH = os.path.join(CACHE_DIR, "play-sessions-open.json")

MIN_SESSION_SECONDS = 120

GAME_CLASSES = ("wine", "wine64", "proton", "gamescope")
NOT_GAME_CLASSES = ("explorer.exe",)

ENV_MARKERS = ("SteamGameId", "SteamAppId", "STEAM_COMPAT_DATA_PATH",
               "WINEPREFIX", "GAMEID", "LUTRIS_GAME_UUID")

SYSTEM_PREFIXES = ("/usr/", "/bin/", "/sbin/", "/app/")


def is_game_class(app_lower):
    """Rule 1: the window class alone names a game."""
    if not app_lower or app_lower in NOT_GAME_CLASSES:
        return False
    return app_lower.startswith("steam_app_") \
        or app_lower.endswith(".exe") \
        or app_lower in GAME_CLASSES


def read_environ(pid, proc_root="/proc"):
    """A process's environment as a dict, or None when it cannot be read."""
    try:
        with open(os.path.join(proc_root, str(int(pid)), "environ"), "rb") as f:
            raw = f.read()
    except (OSError, ValueError):
        return None
    env = {}
    for entry in raw.split(b"\0"):
        key, sep, value = entry.partition(b"=")
        if sep:
            env[key.decode("utf-8", "replace")] = value.decode("utf-8", "replace")
    return env


def game_markers(env, baseline):
    """The launcher variables this process has and the shell does not."""
    found = {}
    for key in ENV_MARKERS:
        value = env.get(key, "")
        # Steam leaves SteamGameId=0 on things it did not start as a game.
        if not value or value == "0":
            continue
        if baseline.get(key) == value:
            continue
        found[key] = value
    return found


def is_system_executable(pid, proc_root="/proc"):
    try:
        exe = os.readlink(os.path.join(proc_root, str(int(pid)), "exe"))
    except (OSError, ValueError):
        return False
    return exe.startswith(SYSTEM_PREFIXES)


def steam_id_from(markers):
    """A real Steam app id, when the environment carries one.

    Non-Steam shortcuts get a 64-bit SteamGameId that names nothing in any
    manifest, so only ids that fit an app id are returned.
    """
    for key in ("SteamAppId", "SteamGameId"):
        value = markers.get(key, "")
        if value.isdigit() and 0 < int(value) < 2 ** 32:
            return value
    return ""


class GameDetector:
    """Answers "is this window a game" and remembers the answer per pid.

    The KWin listener reports on every activation and state change, and the
    answer for a process never changes while it lives, so /proc is read once
    per pid. Pids that no longer own a window are forgotten on each update,
    which is also what keeps a reused pid from inheriting an old answer.
    """

    def __init__(self, proc_root="/proc", baseline=None):
        self.proc_root = proc_root
        self.baseline = dict(os.environ) if baseline is None else baseline
        self._by_pid = {}

    def classify(self, app_lower, pid):
        """(is_game, steam_id) for one window."""
        if is_game_class(app_lower):
            return True, ""
        if not pid:
            return False, ""
        if pid in self._by_pid:
            return self._by_pid[pid]
        result = (False, "")
        env = read_environ(pid, self.proc_root)
        if env is not None:
            markers = game_markers(env, self.baseline)
            if markers and not is_system_executable(pid, self.proc_root):
                result = (True, steam_id_from(markers))
        self._by_pid[pid] = result
        return result

    def forget_except(self, pids):
        live = set(pids)
        for pid in list(self._by_pid):
            if pid not in live:
                del self._by_pid[pid]


def _write_json(path, data):
    """Written whole and swapped in, so a reader never sees half a file."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
    os.replace(tmp, path)


def _read_json(path, default):
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return default


class PlaySessions:
    """Opens and closes play sessions from the list of open windows.

    play-sessions.json is a plain list of {name, icon, start, end}, times in
    Unix seconds, oldest first, so anything else can sum it without knowing
    how it was written.
    """

    def __init__(self, sessions_path=SESSIONS_PATH, open_path=OPEN_PATH,
                 min_seconds=MIN_SESSION_SECONDS, clock=time.time):
        self.sessions_path = sessions_path
        self.open_path = open_path
        self.min_seconds = min_seconds
        self.clock = clock
        # Sessions left open by the previous run. They are settled on the
        # first update, once it is known whether the game is still there.
        self._recovered = _read_json(open_path, {})
        if not isinstance(self._recovered, dict):
            self._recovered = {}
        self.open = {}

    def update(self, windows):
        """Takes the enriched windows, returns the sessions that just ended.

        Only sessions long enough to keep are returned; each one has already
        been written to disk.
        """
        now = int(self.clock())
        playing = {}
        for w in windows:
            if w.get("game") and w.get("name"):
                playing.setdefault(w["name"], w.get("icon", ""))

        ended = []
        changed = False

        if self._recovered is not None:
            for name, session in self._recovered.items():
                if not isinstance(session, dict) or "start" not in session:
                    continue
                if name in playing:
                    self.open[name] = session
                else:
                    # The game closed while the shell was down. When exactly
                    # is unknown; the last heartbeat is the latest moment it
                    # was seen alive, which undercounts by under a minute.
                    session = dict(session, end=int(session.get("lastSeen", session["start"])))
                    self._close(session)
            self._recovered = None
            changed = True

        for name, icon in playing.items():
            if name not in self.open:
                self.open[name] = {"name": name, "icon": icon, "start": now, "lastSeen": now}
                changed = True
            elif icon and self.open[name].get("icon") != icon:
                # The icon of a Wine game can resolve a moment after its first
                # window shows up; keep the better one.
                self.open[name]["icon"] = icon

        for name in [n for n in self.open if n not in playing]:
            session = dict(self.open.pop(name), end=now)
            if self._close(session):
                ended.append(self._public(session))
            changed = True

        if changed:
            self._save_open()
        return ended

    def heartbeat(self):
        """Marks every open session as seen now. Returns True for GLib."""
        if self.open:
            now = int(self.clock())
            for session in self.open.values():
                session["lastSeen"] = now
            self._save_open()
        return True

    def _close(self, session):
        if session["end"] - session["start"] < self.min_seconds:
            return False
        sessions = _read_json(self.sessions_path, None)
        if not isinstance(sessions, list):
            # Unreadable history is set aside rather than written over: it is
            # the only record of every session before this one.
            if os.path.exists(self.sessions_path):
                try:
                    os.replace(self.sessions_path, self.sessions_path + ".broken")
                except OSError:
                    return False
            sessions = []
        sessions.append(self._public(session))
        try:
            _write_json(self.sessions_path, sessions)
        except OSError:
            return False
        return True

    @staticmethod
    def _public(session):
        return {"name": session["name"], "icon": session.get("icon", ""),
                "start": int(session["start"]), "end": int(session["end"])}

    def _save_open(self):
        try:
            _write_json(self.open_path, self.open)
        except OSError:
            pass
