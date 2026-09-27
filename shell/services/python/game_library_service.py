#!/usr/bin/env python3
"""Installed games from Steam, Hydra and Heroic, for the launcher's Games tab.

Prints one JSON line, {"games": [...]}, whenever the library changes. Each
game carries what the launcher needs and nothing else: a title, where it came
from, a portrait cover on disk (or "" for none yet) and the argv that starts
it through its own store.

The list is built once and then only rebuilt when a source file actually
moved: every line on stdin (the launcher sends one each time it opens) is a
cheap stat() of the files the sources are read from, compared with the last
build. Covers that only exist online are fetched on a background thread into
~/.cache/huginn/game-covers/, and the list is printed again once they land,
so the launcher never waits on the network.

Games are always started through their launcher, never by running the
executable: Steam, Heroic and Hydra each set up their own Proton/umu
environment, and bypassing them is what breaks saves and anti-cheat.
"""
import hashlib
import json
import os
import re
import sys
import threading
import urllib.parse
import urllib.request

import leveldb_reader

HOME = os.path.expanduser('~')

STEAM_ROOTS = [
    os.path.join(HOME, '.local/share/Steam'),
    os.path.join(HOME, '.steam/steam'),
    os.path.join(HOME, '.var/app/com.valvesoftware.Steam/.local/share/Steam'),
]

HEROIC_ROOTS = [
    os.path.join(HOME, '.config/heroic'),
    os.path.join(HOME, '.var/app/com.heroicgameslauncher.hgl/config/heroic'),
]

HYDRA_DB = os.path.join(HOME, '.config/hydralauncher/hydra-db')

COVER_DIR = os.path.join(HOME, '.cache/huginn/game-covers')

# Steam installs its own runtimes and compatibility tools as ordinary apps,
# with manifests like any game. They are not something anyone wants to "play".
STEAM_TOOL_NAME = re.compile(
    r'^(Proton\b|Steam Linux Runtime|Steamworks Common Redistributables|SteamVR\b)',
    re.IGNORECASE)
STEAM_TOOL_IDS = {
    '228980',   # Steamworks Common Redistributables
    '1070560',  # Steam Linux Runtime 1.0 (scout)
    '1391110',  # Steam Linux Runtime 2.0 (soldier)
    '1628350',  # Steam Linux Runtime 3.0 (sniper)
    '4183110',  # Steam Linux Runtime 4.0
    '1493710',  # Proton Experimental
    '2180100',  # Proton Hotfix
    '1826330',  # Proton EasyAntiCheat Runtime
    '1161040',  # Proton BattlEye Runtime
    '250820',   # SteamVR
}

# StateFlags bit for "fully installed". An app that is still downloading for
# the first time does not have it; one waiting on an update keeps it.
STEAM_FULLY_INSTALLED = 4

# Portrait art in Steam's local cache, best first. Newer clients keep each
# file inside a per-asset hash folder; older ones put it directly in the
# app's folder, and much older ones flattened everything into one directory.
STEAM_PORTRAIT_NAMES = [
    'library_600x900_2x.jpg',
    'library_600x900.jpg',
    'library_capsule_2x.jpg',
    'library_capsule.jpg',
]

STEAM_CDN = 'https://shared.steamstatic.com/store_item_assets/steam/apps/{}/{}'


def _read_json(path):
    try:
        with open(path, 'r', encoding='utf-8') as fp:
            return json.load(fp)
    except (OSError, ValueError):
        return None


def _first_existing(paths):
    for p in paths:
        if os.path.isdir(p):
            return os.path.realpath(p)
    return None


def _stat_sig(path):
    try:
        st = os.stat(path)
        return (path, st.st_mtime_ns, st.st_size)
    except OSError:
        return (path, None, None)


# ── Steam ────────────────────────────────────────────────────────────────

def _steam_roots():
    seen = []
    for r in STEAM_ROOTS:
        if os.path.isdir(os.path.join(r, 'steamapps')):
            real = os.path.realpath(r)
            if real not in seen:
                seen.append(real)
    return seen


def _steam_libraries(roots):
    libs = []
    for root in roots:
        candidates = [root]
        vdf = os.path.join(root, 'steamapps', 'libraryfolders.vdf')
        try:
            with open(vdf, 'r', encoding='utf-8', errors='ignore') as fp:
                for m in re.finditer(r'"path"\s+"((?:[^"\\]|\\.)*)"', fp.read()):
                    candidates.append(m.group(1).replace('\\\\', '\\'))
        except OSError:
            pass
        for c in candidates:
            # realpath so ~/.steam/steam and ~/.local/share/Steam, which are
            # the same place, are not read twice. An unmounted library (a
            # Windows partition that is not mounted right now) simply has no
            # steamapps folder and drops out here.
            real = os.path.realpath(c)
            if real not in libs and os.path.isdir(os.path.join(real, 'steamapps')):
                libs.append(real)
    return libs


def _acf_field(text, key):
    m = re.search(r'^\s*"' + key + r'"\s+"((?:[^"\\]|\\.)*)"', text, re.MULTILINE)
    return m.group(1) if m else ''


def _steam_local_cover(roots, appid):
    for root in roots:
        cache = os.path.join(root, 'appcache', 'librarycache')
        folder = os.path.join(cache, appid)
        dirs = [folder]
        try:
            dirs += [e.path for e in os.scandir(folder) if e.is_dir()]
        except OSError:
            pass
        for name in STEAM_PORTRAIT_NAMES:
            for d in dirs:
                p = os.path.join(d, name)
                if os.path.isfile(p):
                    return p
        flat = os.path.join(cache, appid + '_library_600x900.jpg')
        if os.path.isfile(flat):
            return flat
    return ''


def _steam_cdn_urls(appid):
    # Only the unhashed names can be guessed. Recent releases publish their
    # art under a hash and 404 here, which is why the local cache goes first.
    return [STEAM_CDN.format(appid, 'library_600x900_2x.jpg'),
            STEAM_CDN.format(appid, 'library_600x900.jpg')]


def steam_watch(roots, libs):
    paths = []
    for root in roots:
        paths.append(os.path.join(root, 'steamapps', 'libraryfolders.vdf'))
    for lib in libs:
        apps = os.path.join(lib, 'steamapps')
        paths.append(apps)
        try:
            paths += sorted(e.path for e in os.scandir(apps)
                            if e.name.startswith('appmanifest_') and e.name.endswith('.acf'))
        except OSError:
            pass
    return paths


def steam_games(roots, libs):
    games = []
    seen = set()
    for lib in libs:
        apps = os.path.join(lib, 'steamapps')
        try:
            entries = sorted(os.scandir(apps), key=lambda e: e.name)
        except OSError:
            continue
        for e in entries:
            if not (e.name.startswith('appmanifest_') and e.name.endswith('.acf')):
                continue
            try:
                with open(e.path, 'r', encoding='utf-8', errors='ignore') as fp:
                    text = fp.read()
            except OSError:
                continue
            appid = _acf_field(text, 'appid')
            name = _acf_field(text, 'name')
            if not appid or not name or appid in seen:
                continue
            try:
                flags = int(_acf_field(text, 'StateFlags') or '0')
            except ValueError:
                flags = 0
            if not flags & STEAM_FULLY_INSTALLED:
                continue
            if appid in STEAM_TOOL_IDS or STEAM_TOOL_NAME.search(name):
                continue
            seen.add(appid)
            games.append({
                'id': 'steam:' + appid,
                'name': name,
                'source': 'Steam',
                'cover': _steam_local_cover(roots, appid),
                'coverUrls': _steam_cdn_urls(appid),
                'launch': ['steam', 'steam://rungameid/' + appid],
            })
    return games


# ── Hydra ────────────────────────────────────────────────────────────────

def hydra_watch():
    paths = [HYDRA_DB]
    try:
        paths += sorted(os.path.join(HYDRA_DB, n) for n in os.listdir(HYDRA_DB)
                        if n.endswith('.log') or n.endswith('.ldb') or n.endswith('.sst'))
    except OSError:
        pass
    return paths


def _local_image(ref):
    # Hydra stores a custom cover as either a plain path or its own
    # "local:" protocol URL pointing at one.
    if not ref or not isinstance(ref, str):
        return ''
    path = ref
    if path.startswith('local:'):
        path = urllib.parse.unquote(path[len('local:'):])
    elif path.startswith('file://'):
        path = urllib.parse.unquote(path[len('file://'):])
    return path if os.path.isabs(path) and os.path.isfile(path) else ''


def hydra_games(steam_roots):
    if not os.path.isdir(HYDRA_DB):
        return []
    rows = leveldb_reader.read_all(HYDRA_DB, b'!game')
    games = []
    for key, value in rows.items():
        if not key.startswith(b'!games!'):
            continue
        try:
            g = json.loads(value)
        except ValueError:
            continue
        if not isinstance(g, dict) or g.get('isDeleted'):
            continue
        shop_key = key[len(b'!games!'):].decode('utf-8', 'replace')
        shop, _, object_id = shop_key.partition(':')
        shop = g.get('shop') or shop
        object_id = str(g.get('objectId') or object_id)
        # Hydra's own "run" deep link refuses a game without an executable,
        # and one whose executable has since moved would only fail inside
        # Hydra. Only what Hydra can actually start is listed.
        exe = g.get('executablePath')
        if not exe or not os.path.isfile(exe):
            continue
        title = g.get('title') or object_id

        assets = {}
        raw_assets = rows.get(b'!gameShopAssets!' + shop_key.encode())
        if raw_assets:
            try:
                assets = json.loads(raw_assets) or {}
            except ValueError:
                assets = {}

        cover = _local_image(g.get('customCoverImageUrl'))
        urls = []
        if not cover and shop == 'steam':
            # Hydra's Steam games use the real Steam AppID, so if Steam
            # itself has ever shown this game its art is already on disk.
            cover = _steam_local_cover(steam_roots, object_id)
        for u in (g.get('customCoverImageUrl'), assets.get('coverImageUrl')):
            if isinstance(u, str) and u.startswith('http') and u not in urls:
                urls.append(u)
        if shop == 'steam':
            urls += [u for u in _steam_cdn_urls(object_id) if u not in urls]

        query = urllib.parse.urlencode({'shop': shop, 'objectId': object_id})
        games.append({
            'id': 'hydra:' + shop + ':' + object_id,
            'name': title,
            'source': 'Hydra',
            'cover': cover,
            'coverUrls': urls,
            'launch': ['xdg-open', 'hydralauncher://run?' + query],
        })
    return games


# ── Heroic ───────────────────────────────────────────────────────────────

def _heroic_files(root):
    return {
        'sideload': os.path.join(root, 'sideload_apps', 'library.json'),
        'legendary_installed': os.path.join(root, 'legendaryConfig', 'legendary', 'installed.json'),
        'legendary_library': os.path.join(root, 'store_cache', 'legendary_library.json'),
        'gog_installed': os.path.join(root, 'gog_store', 'installed.json'),
        'gog_library': os.path.join(root, 'store_cache', 'gog_library.json'),
        'nile_installed': os.path.join(root, 'nile_config', 'nile', 'installed.json'),
        'nile_library': os.path.join(root, 'store_cache', 'nile_library.json'),
    }


def heroic_watch(root):
    return sorted(_heroic_files(root).values()) if root else []


def _heroic_launch_url(runner, app_name):
    # Heroic reads the path form as-is, without percent-decoding, so it only
    # suits names made of plain characters (which all store ids are). Anything
    # else goes through the query form, which Heroic does decode.
    if re.fullmatch(r'[A-Za-z0-9._-]+', app_name):
        return 'heroic://launch/{}/{}'.format(runner, app_name)
    return 'heroic://launch?' + urllib.parse.urlencode({'appName': app_name, 'runner': runner})


def _heroic_cover(root, art):
    if not art or not isinstance(art, str):
        return '', []
    if os.path.isabs(art):
        return (art, []) if os.path.isfile(art) else ('', [])
    if art.startswith('http'):
        # Heroic caches every image it has shown under the SHA-256 of its URL.
        cached = os.path.join(root, 'images-cache', hashlib.sha256(art.encode()).hexdigest())
        if os.path.isfile(cached):
            return cached, []
        return '', [art]
    return '', []


def _library_index(path, list_key):
    data = _read_json(path)
    items = data.get(list_key) if isinstance(data, dict) else None
    out = {}
    for item in items or []:
        if isinstance(item, dict) and item.get('app_name'):
            out[str(item['app_name'])] = item
    return out


def heroic_games(root):
    if not root:
        return []
    files = _heroic_files(root)
    found = []   # (runner, app_name, title, art)

    side = _read_json(files['sideload'])
    for g in (side or {}).get('games', []) if isinstance(side, dict) else []:
        if isinstance(g, dict) and g.get('is_installed') and g.get('app_name'):
            found.append(('sideload', str(g['app_name']), g.get('title'),
                          g.get('art_square') or g.get('art_cover')))

    legendary = _read_json(files['legendary_installed'])
    if isinstance(legendary, dict) and legendary:
        lib = _library_index(files['legendary_library'], 'library')
        for app_name, info in legendary.items():
            if not isinstance(info, dict) or info.get('is_dlc'):
                continue
            meta = lib.get(app_name, {})
            found.append(('legendary', app_name, info.get('title') or meta.get('title'),
                          meta.get('art_square') or meta.get('art_cover')))

    gog = _read_json(files['gog_installed'])
    gog_list = gog.get('installed') if isinstance(gog, dict) else None
    if gog_list:
        lib = _library_index(files['gog_library'], 'games')
        for info in gog_list:
            if not isinstance(info, dict) or info.get('is_dlc'):
                continue
            app_name = str(info.get('appName') or '')
            meta = lib.get(app_name, {})
            if not app_name:
                continue
            found.append(('gog', app_name, meta.get('title'),
                          meta.get('art_square') or meta.get('art_cover')))

    nile = _read_json(files['nile_installed'])
    if isinstance(nile, list) and nile:
        lib = _library_index(files['nile_library'], 'library')
        for info in nile:
            if not isinstance(info, dict) or not info.get('id'):
                continue
            app_name = str(info['id'])
            meta = lib.get(app_name, {})
            found.append(('nile', app_name, meta.get('title'),
                          meta.get('art_square') or meta.get('art_cover')))

    games = []
    for runner, app_name, title, art in found:
        cover, urls = _heroic_cover(root, art)
        games.append({
            'id': 'heroic:' + runner + ':' + app_name,
            'name': title or app_name,
            'source': 'Heroic',
            'cover': cover,
            'coverUrls': urls,
            'launch': ['xdg-open', _heroic_launch_url(runner, app_name)],
        })
    return games


# ── Covers that only exist online ────────────────────────────────────────

def _cache_path(game_id, url):
    ext = os.path.splitext(urllib.parse.urlparse(url).path)[1].lower()
    if ext not in ('.jpg', '.jpeg', '.png', '.webp'):
        ext = '.jpg'
    safe = re.sub(r'[^A-Za-z0-9._-]+', '_', game_id)
    return os.path.join(COVER_DIR, safe + ext)


def _cached_cover(game_id):
    safe = re.sub(r'[^A-Za-z0-9._-]+', '_', game_id)
    for ext in ('.jpg', '.jpeg', '.png', '.webp'):
        p = os.path.join(COVER_DIR, safe + ext)
        try:
            if os.path.getsize(p) > 0:
                return p
        except OSError:
            pass
    return ''


class CoverFetcher:
    """Downloads missing covers one at a time on a daemon thread.

    A game whose every URL failed is not retried until the service restarts,
    so an offline machine or a 404 does not turn into a request per open.
    """

    MAX_BYTES = 12 * 1024 * 1024

    def __init__(self, on_fetched):
        self._on_fetched = on_fetched
        self._lock = threading.Lock()
        self._wake = threading.Condition(self._lock)
        self._queue = []
        self._known = set()
        self._fetched_since_print = False
        threading.Thread(target=self._run, daemon=True).start()

    def want(self, game_id, urls):
        with self._lock:
            if game_id in self._known or not urls:
                return
            self._known.add(game_id)
            self._queue.append((game_id, list(urls)))
            self._wake.notify()

    def _run(self):
        while True:
            with self._lock:
                while not self._queue:
                    self._wake.wait()
                game_id, urls = self._queue.pop(0)
                more = bool(self._queue)
            got = False
            for url in urls:
                if self._fetch(url, _cache_path(game_id, url)):
                    got = True
                    break
            # One reprint per batch rather than per cover: a first run with
            # twenty missing covers should not rebuild the grid twenty times.
            if got:
                self._fetched_since_print = True
            if not more and self._fetched_since_print:
                self._fetched_since_print = False
                self._on_fetched()

    def _fetch(self, url, dest):
        tmp = dest + '.part'
        try:
            os.makedirs(COVER_DIR, exist_ok=True)
            req = urllib.request.Request(url, headers={'User-Agent': 'huginn-shell'})
            with urllib.request.urlopen(req, timeout=15) as resp:
                ctype = resp.headers.get('Content-Type', '')
                if not ctype.startswith('image/'):
                    return False
                data = resp.read(self.MAX_BYTES + 1)
            if not data or len(data) > self.MAX_BYTES:
                return False
            with open(tmp, 'wb') as fp:
                fp.write(data)
            os.replace(tmp, dest)
            return True
        except Exception:
            try:
                os.remove(tmp)
            except OSError:
                pass
            return False


# ── The library ──────────────────────────────────────────────────────────

class GameLibrary:
    def __init__(self):
        self._print_lock = threading.Lock()
        self._build_lock = threading.Lock()
        self._last_sig = None
        self._last_out = None
        self._fetcher = CoverFetcher(lambda: self.refresh(force=True))

    def _sources(self):
        roots = _steam_roots()
        libs = _steam_libraries(roots)
        heroic = _first_existing(HEROIC_ROOTS)
        return roots, libs, heroic

    def _signature(self, roots, libs, heroic):
        watched = steam_watch(roots, libs) + hydra_watch() + heroic_watch(heroic)
        return tuple(_stat_sig(p) for p in watched)

    def refresh(self, force=False):
        with self._build_lock:
            roots, libs, heroic = self._sources()
            sig = self._signature(roots, libs, heroic)
            if not force and sig == self._last_sig:
                return
            self._last_sig = sig

            games = []
            for build in (lambda: steam_games(roots, libs),
                          lambda: hydra_games(roots),
                          lambda: heroic_games(heroic)):
                try:
                    games += build()
                except Exception:
                    # One broken source must not take the other two with it.
                    continue

            for g in games:
                urls = g.pop('coverUrls', [])
                if not g['cover']:
                    g['cover'] = _cached_cover(g['id'])
                if not g['cover']:
                    self._fetcher.want(g['id'], urls)

            games.sort(key=lambda g: g['name'].lower())
            out = json.dumps({'games': games})
            if out == self._last_out:
                return
            self._last_out = out
        with self._print_lock:
            try:
                print(out, flush=True)
            except (BrokenPipeError, OSError):
                os._exit(0)


def main():
    lib = GameLibrary()
    lib.refresh(force=True)
    # Any line means "the launcher just opened, check again". EOF means the
    # shell went away, and so does this process.
    for _ in sys.stdin:
        lib.refresh()


if __name__ == '__main__':
    main()
