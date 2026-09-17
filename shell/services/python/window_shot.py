#!/usr/bin/env python3
"""Capture a single window by its KWin uuid, for the dock's window picker.

A Wayland client cannot read another window's pixels. KWin.WindowThumbnail
only exists inside KWin's own QML (effects and the window switcher), and this
build of QuickShell has no screencopy API, so the picker cannot show a live
thumbnail the way the Alt+Tab switcher does. What is available is
org.kde.KWin.ScreenShot2, which hands over one frame on request -- a snapshot
taken when the picker opens, not a live view.

That interface is restricted: KWin only answers a caller whose .desktop file
lists it in X-KDE-DBUS-Restricted-Interfaces, which is why this runs through
the shell's own helper binary and not through /usr/bin/python3.

Usage: huginn-shell-helper window_shot.py <window uuid> [<window uuid> ...]
Prints one "<uuid>\t<path>" line per window it managed to capture. A window
that cannot be captured (a minimized one has no buffer) is simply left out.
"""
import os
import sys
import time

CACHE_DIR = os.path.expanduser('~/.cache/huginn/previews')
# Wide enough to read at the card's size, small enough to encode quickly.
MAX_WIDTH = 560


def capture(uuid):
    import dbus
    from PIL import Image

    read_fd, write_fd = os.pipe()
    try:
        bus = dbus.SessionBus()
        screenshot = dbus.Interface(
            bus.get_object('org.kde.KWin.ScreenShot2', '/org/kde/KWin/ScreenShot2'),
            'org.kde.KWin.ScreenShot2')

        # The call returns the frame's metadata and writes the raw pixels into
        # the pipe, so the read has to happen while the call is in flight --
        # a pipe that nobody drains blocks the compositor's write.
        import threading
        chunks = []

        def drain():
            with os.fdopen(read_fd, 'rb', closefd=True) as stream:
                while True:
                    chunk = stream.read(1 << 16)
                    if not chunk:
                        break
                    chunks.append(chunk)

        reader = threading.Thread(target=drain, daemon=True)
        reader.start()

        options = {'include-decoration': False, 'include-cursor': False}
        results = screenshot.CaptureWindow(uuid, options, dbus.types.UnixFd(write_fd))
        os.close(write_fd)
        write_fd = -1
        reader.join(timeout=4)

        width = int(results['width'])
        height = int(results['height'])
        stride = int(results['stride'])
        data = b''.join(chunks)
        if not data or width <= 0 or height <= 0:
            return None

        # KWin hands over premultiplied BGRA rows, padded to the stride.
        rows = [data[y * stride:y * stride + width * 4] for y in range(height)]
        image = Image.frombytes('RGBA', (width, height), b''.join(rows))
        b, g, r, a = image.split()
        image = Image.merge('RGB', (r, g, b))

        if width > MAX_WIDTH:
            image = image.resize((MAX_WIDTH, max(1, round(height * MAX_WIDTH / width))),
                                 Image.LANCZOS)

        os.makedirs(CACHE_DIR, exist_ok=True)
        # A fresh name every time: QtQuick keeps an image cached by URL, so
        # reusing one path would show the previous frame forever. The older
        # frames of this window go with it.
        safe = ''.join(c for c in uuid if c.isalnum() or c in '-_')
        cutoff = time.time() - 3600
        for stale in os.listdir(CACHE_DIR):
            stale_path = os.path.join(CACHE_DIR, stale)
            # This window's earlier frames, and anything left behind by a window
            # that has since been closed -- nothing here is worth keeping, since
            # the picker captures again every time it opens.
            try:
                if stale.startswith(safe) or os.path.getmtime(stale_path) < cutoff:
                    os.remove(stale_path)
            except OSError:
                pass
        path = os.path.join(CACHE_DIR, f'{safe}-{time.monotonic_ns() // 1000000}.png')
        tmp_path = path + '.tmp'
        image.save(tmp_path, 'PNG')
        os.replace(tmp_path, path)
        return path
    finally:
        if write_fd >= 0:
            try:
                os.close(write_fd)
            except OSError:
                pass


if __name__ == '__main__':
    if len(sys.argv) < 2:
        sys.exit(1)
    for window_uuid in sys.argv[1:]:
        try:
            result = capture(window_uuid)
        except Exception as exc:
            print(f'window_shot: {window_uuid}: {exc}', file=sys.stderr)
            continue
        if result:
            print(f'{window_uuid}\t{result}', flush=True)
