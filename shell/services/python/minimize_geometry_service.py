#!/usr/bin/env python3
"""Tell KWin where each window's icon sits on the Huginn dock.

KWin's minimize animation (squash) aims at Window::iconGeometry. On Wayland that
value has exactly one source: a client that speaks org_kde_plasma_window_
management and calls set_minimized_geometry for the window, which is the job
of the Plasma task manager. Huginn replaces the task manager, and nothing in
QuickShell or in KWin's scripting API can fill that in -- iconGeometry is
read-only there, and setMinimizeIconGeometry does not exist. So the rectangles
stay 0x0, the animation has no target and falls back to the nearest screen edge.

This service is the missing task manager, and nothing else: it maps a surface
of its own (the protocol anchors the rectangles to a client surface, so there
has to be one), follows the window list, and reports the rectangle the dock
publishes for each window's application.

The dock writes those rectangles to ~/.cache/huginn/icon_geometry.json; see
BottomDock.qml and update_icon_geometries.py.
"""
import json
import mmap
import os
import selectors
import subprocess
import sys
import tempfile

CACHE_DIR = os.path.expanduser('~/.cache/huginn')
ICON_MAP_PATH = os.path.join(CACHE_DIR, 'icon_geometry.json')
BINDINGS_DIR = os.path.join(CACHE_DIR, 'wayland-protocols')

# pywayland ships bindings for the core protocol and the xdg family, but not
# for these two. The scanner needs the protocols they refer to in the same
# run, or it stops at an unknown interface (wl_surface, xdg_popup).
PROTOCOL_XML = [
    '/usr/share/wayland/wayland.xml',
    '/usr/share/plasma-wayland-protocols/plasma-window-management.xml',
    '/usr/share/wlr-protocols/unstable/wlr-layer-shell-unstable-v1.xml',
]

# wayland-protocols is not installed here; Qt ships the same file.
XDG_SHELL_XML = [
    '/usr/share/wayland-protocols/stable/xdg-shell/xdg-shell.xml',
    '/usr/share/qt6/wayland/protocols/xdg-shell/xdg-shell.xml',
]

# How often the icon map is re-read. The dock only writes it when an icon
# actually moves, so this is a cheap stat() almost every time.
POLL_SECONDS = 0.4


def ensure_bindings():
    """Generate Python bindings for the two protocols pywayland does not ship.

    They land in the cache rather than in the repository: they are build
    output, and regenerating them costs a second at first start.
    """
    out_dir = os.path.join(BINDINGS_DIR, 'pywayland', 'protocol')
    if os.path.exists(os.path.join(out_dir, 'plasma_window_management.py')):
        return True

    inputs = list(PROTOCOL_XML)
    for candidate in XDG_SHELL_XML:
        if os.path.exists(candidate):
            inputs.insert(1, candidate)
            break

    missing = [xml for xml in inputs if not os.path.exists(xml)]
    if missing:
        print(f"minimize_geometry: missing protocol files: {', '.join(missing)}", file=sys.stderr)
        return False

    os.makedirs(out_dir, exist_ok=True)
    result = subprocess.run(
        [sys.executable, '-m', 'pywayland.scanner',
         '--input', *inputs,
         '--output-dir', out_dir],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        print(f"minimize_geometry: scanner failed: {result.stderr.strip()}", file=sys.stderr)
        return False

    # The Plasma protocol names an argument "is" (in virtual_desktop_left),
    # the scanner copies argument names straight into the signature, and the
    # module then fails to parse. Nothing here uses that event, so renaming
    # the parameter is enough.
    generated = os.path.join(out_dir, 'plasma_window_management.py')
    with open(generated, 'r', encoding='utf-8') as f:
        code = f.read()
    code = code.replace('def virtual_desktop_left(self, is: str)',
                        'def virtual_desktop_left(self, desktop_id: str)')
    code = code.replace('self._post_event(12, is)', 'self._post_event(12, desktop_id)')
    with open(generated, 'w', encoding='utf-8') as f:
        f.write(code)
    return True


def load_icon_map():
    try:
        with open(ICON_MAP_PATH, 'r', encoding='utf-8') as f:
            raw = json.load(f)
    except Exception:
        return {}, None

    icons = {}
    dock = None
    for key, rect in raw.items():
        if key == '__dock__':
            dock = rect
        else:
            icons[key.lower()] = rect
    return icons, dock


def pick_rect(app_id, icons, dock):
    """The dock entry for an app id, the dock itself, or nothing.

    Same rule as the window switcher: an exact hit wins, and among partial
    hits the longest app id wins, because that is the most specific one. A
    Brave web app is "brave-<hash>-Default" and must not be swallowed by the
    plain "brave" entry.
    """
    app_id = (app_id or '').lower().strip()
    if not app_id:
        return dock

    best = None
    best_score = 0
    for key, rect in icons.items():
        if key == app_id:
            score = 1000 + len(key)
        elif key in app_id or app_id in key:
            score = len(key)
        else:
            continue
        if score > best_score:
            best_score = score
            best = rect
    return best or dock


class MinimizeGeometryService:
    def __init__(self):
        self.display = None
        self.compositor = None
        self.shm = None
        self.layer_shell = None
        self.wm = None
        self.origin_output = None
        self.surface = None
        self.layer_surface = None
        self.buffer = None
        self.windows = {}          # uuid -> window proxy
        self.app_ids = {}          # uuid -> app id
        self.resource_names = {}   # uuid -> X11 resource name, when there is one
        self.icons = {}
        self.dock = None
        self.map_stamp = None

    # -- wayland plumbing ---------------------------------------------------

    def run(self):
        from pywayland.client import Display
        from pywayland.protocol.wayland import WlCompositor, WlOutput, WlShm
        from pywayland.protocol.wlr_layer_shell_unstable_v1 import ZwlrLayerShellV1
        from pywayland.protocol.plasma_window_management import OrgKdePlasmaWindowManagement

        # Before the registry: binding the window management interface makes
        # the compositor send the whole window list at once, and each of those
        # windows is matched against the map as it arrives.
        self.reload_icon_map(force=True)

        self.display = Display()
        self.display.connect()

        registry = self.display.get_registry()
        outputs = []

        def on_global(reg, name, interface, version):
            if interface == 'wl_compositor':
                self.compositor = reg.bind(name, WlCompositor, min(version, 4))
            elif interface == 'wl_shm':
                self.shm = reg.bind(name, WlShm, min(version, 1))
            elif interface == 'zwlr_layer_shell_v1':
                self.layer_shell = reg.bind(name, ZwlrLayerShellV1, min(version, 1))
            elif interface == 'org_kde_plasma_window_management':
                self.wm = reg.bind(name, OrgKdePlasmaWindowManagement, min(version, 16))
                # The window list arrives right after the bind, so the
                # listener goes on before anything else can dispatch it:
                # registering it after the first roundtrip drops every window
                # that already existed.
                self.wm.dispatcher['window_with_uuid'] = self.on_window_with_uuid
            elif interface == 'wl_output':
                output = reg.bind(name, WlOutput, min(version, 2))
                outputs.append(output)
                output.user_data = {'x': None, 'y': None}

                def on_geometry(out, x, y, *rest):
                    out.user_data['x'] = x
                    out.user_data['y'] = y

                output.dispatcher['geometry'] = on_geometry

        registry.dispatcher['global'] = on_global
        self.display.roundtrip()
        self.display.roundtrip()   # outputs answer their geometry on the second

        if not (self.compositor and self.shm and self.layer_shell and self.wm):
            print('minimize_geometry: compositor is missing one of the required '
                  'interfaces (wl_compositor, wl_shm, zwlr_layer_shell_v1, '
                  'org_kde_plasma_window_management)', file=sys.stderr)
            return 1

        # The rectangles are relative to our own surface, and the protocol
        # carries them as unsigned integers, so the surface has to sit at the
        # origin of the desktop for every dock position to stay positive.
        self.origin_output = self.pick_origin_output(outputs)
        self.create_anchor_surface()

        self.display.roundtrip()

        # Windows that answered before the anchor surface existed.
        for uuid in list(self.windows):
            self.apply(uuid)

        self.loop()
        return 0

    def pick_origin_output(self, outputs):
        best = None
        best_key = None
        for output in outputs:
            data = getattr(output, 'user_data', None) or {}
            if data.get('x') is None:
                continue
            key = (data['x'], data['y'])
            if best_key is None or key < best_key:
                best_key = key
                best = output
        return best

    def create_anchor_surface(self):
        """A 1x1 transparent layer surface, only so the protocol has an anchor.

        KWin resolves the rectangles against the window that owns this surface,
        so it has to be mapped -- an unmapped surface is not a window and the
        geometry is dropped.
        """
        from pywayland.protocol.wlr_layer_shell_unstable_v1 import ZwlrLayerShellV1, ZwlrLayerSurfaceV1

        self.surface = self.compositor.create_surface()
        self.layer_surface = self.layer_shell.get_layer_surface(
            self.surface, self.origin_output,
            ZwlrLayerShellV1.layer.background.value, 'huginn-minimize-anchor')
        self.layer_surface.set_size(1, 1)
        self.layer_surface.set_anchor(
            ZwlrLayerSurfaceV1.anchor.top.value | ZwlrLayerSurfaceV1.anchor.left.value)
        self.layer_surface.set_exclusive_zone(-1)
        self.layer_surface.set_keyboard_interactivity(0)

        def on_configure(layer_surface, serial, width, height):
            layer_surface.ack_configure(serial)
            self.attach_pixel()

        self.layer_surface.dispatcher['configure'] = on_configure
        self.surface.commit()
        self.display.roundtrip()

    def attach_pixel(self):
        from pywayland.protocol.wayland import WlShm

        if self.buffer is None:
            with tempfile.TemporaryFile() as fd:
                fd.write(b'\x00\x00\x00\x00')
                fd.flush()
                fd.seek(0)
                mm = mmap.mmap(fd.fileno(), 4)
                pool = self.shm.create_pool(fd.fileno(), 4)
                self.buffer = pool.create_buffer(0, 1, 1, 4, WlShm.format.argb8888.value)
                pool.destroy()
                self._keepalive = mm
        self.surface.attach(self.buffer, 0, 0)
        self.surface.damage(0, 0, 1, 1)
        self.surface.commit()

    # -- window bookkeeping -------------------------------------------------

    def on_window_with_uuid(self, wm, window_id, uuid):
        window = wm.get_window_by_uuid(uuid)
        self.windows[uuid] = window

        def on_app_id(win, app_id):
            self.app_ids[uuid] = app_id
            self.apply(uuid)

        # X11 apps often carry a useful resource name and a useless app id.
        def on_resource_name(win, resource_name):
            self.resource_names[uuid] = resource_name
            if not self.app_ids.get(uuid):
                self.apply(uuid)

        def on_unmapped(win):
            self.windows.pop(uuid, None)
            self.app_ids.pop(uuid, None)
            self.resource_names.pop(uuid, None)

        window.dispatcher['app_id_changed'] = on_app_id
        window.dispatcher['resource_name_changed'] = on_resource_name
        window.dispatcher['unmapped'] = on_unmapped

    def apply(self, uuid):
        window = self.windows.get(uuid)
        if window is None or self.surface is None:
            return
        rect = pick_rect(self.app_ids.get(uuid), self.icons, self.dock)
        if rect is self.dock:
            rect = pick_rect(self.resource_names.get(uuid), self.icons, self.dock)
        if not rect:
            return
        window.set_minimized_geometry(
            self.surface,
            max(0, int(rect.get('x', 0))), max(0, int(rect.get('y', 0))),
            max(1, int(rect.get('width', 42))), max(1, int(rect.get('height', 42))))

    def reload_icon_map(self, force=False):
        try:
            stamp = os.stat(ICON_MAP_PATH).st_mtime_ns
        except OSError:
            return False
        if not force and stamp == self.map_stamp:
            return False
        self.map_stamp = stamp
        self.icons, self.dock = load_icon_map()
        return True

    # -- main loop ----------------------------------------------------------

    def loop(self):
        selector = selectors.DefaultSelector()
        selector.register(self.display.get_fd(), selectors.EVENT_READ)

        while True:
            self.display.flush()
            events = selector.select(POLL_SECONDS)
            if events:
                self.display.dispatch(block=False)
            if self.reload_icon_map():
                for uuid in list(self.windows):
                    self.apply(uuid)


def main():
    os.makedirs(CACHE_DIR, exist_ok=True)
    if not ensure_bindings():
        return 1

    # pywayland.protocol is a namespace package, so the generated modules are
    # reachable by adding the cache to its search path; sys.path alone would
    # not do it, because pywayland itself is a regular package.
    import pywayland.protocol
    pywayland.protocol.__path__.append(os.path.join(BINDINGS_DIR, 'pywayland', 'protocol'))
    return MinimizeGeometryService().run()


if __name__ == '__main__':
    sys.exit(main())
