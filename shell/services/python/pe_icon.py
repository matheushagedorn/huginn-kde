#!/usr/bin/env python3
"""Pulls the application icon out of a Windows executable.

Games launched through Heroic report a window class of `steam_app_default`,
which says nothing about which game is running. Their icon lives inside the
.exe itself, in the PE resource table, so that is where this reads it from.

Written against the PE format directly rather than shelling out to icoutils:
the shell has no other binary dependency for this, and a missing package
would silently cost every game its icon.

The result is written as a PNG of the largest size the executable carries.
Handing Qt a multi-size .ico would leave the choice of size to the image
reader, and the first entry in these files is usually 16x16 — a blurred
smudge in a 48px dock slot.
"""
import hashlib
import os
import struct
import zlib

RT_ICON = 3
RT_GROUP_ICON = 14

CACHE_DIR = os.path.expanduser("~/.cache/huginn/game-icons")


def _read(f, offset, size):
    f.seek(offset)
    return f.read(size)


def _largest_image(path):
    with open(path, "rb") as f:
        if f.read(2) != b"MZ":
            return None

        f.seek(0x3C)
        pe_offset = struct.unpack("<I", f.read(4))[0]
        if _read(f, pe_offset, 4) != b"PE\0\0":
            return None

        coff = _read(f, pe_offset + 4, 20)
        section_count = struct.unpack("<H", coff[2:4])[0]
        optional_size = struct.unpack("<H", coff[16:18])[0]

        optional_offset = pe_offset + 24
        magic = struct.unpack("<H", _read(f, optional_offset, 2))[0]
        # The data directory sits after the optional header proper, whose size
        # differs between PE32 (96 bytes) and PE32+ (112).
        data_dir = optional_offset + (96 if magic == 0x10B else 112)
        resource_rva, _ = struct.unpack("<II", _read(f, data_dir + 16, 8))
        if not resource_rva:
            return None

        sections = []
        section_offset = optional_offset + optional_size
        for i in range(section_count):
            raw = _read(f, section_offset + i * 40, 40)
            virtual_size = struct.unpack("<I", raw[8:12])[0]
            virtual_address = struct.unpack("<I", raw[12:16])[0]
            raw_size = struct.unpack("<I", raw[16:20])[0]
            raw_pointer = struct.unpack("<I", raw[20:24])[0]
            sections.append((virtual_address, max(virtual_size, raw_size), raw_pointer))

        def to_offset(rva):
            for address, size, pointer in sections:
                if address <= rva < address + size:
                    return pointer + (rva - address)
            return None

        base = to_offset(resource_rva)
        if base is None:
            return None

        def entries(directory):
            header = _read(f, directory, 16)
            named, by_id = struct.unpack("<HH", header[12:16])
            found = []
            for i in range(named + by_id):
                raw = _read(f, directory + 16 + i * 8, 8)
                found.append(struct.unpack("<II", raw))
            return found

        def find_type(resource_type):
            for name, offset in entries(base):
                if not (name & 0x80000000) and name == resource_type and offset & 0x80000000:
                    return base + (offset & 0x7FFFFFFF)
            return None

        def first_leaf(directory):
            # type -> name -> language, and the language level holds the data
            for _, offset in entries(directory):
                if offset & 0x80000000:
                    leaf = first_leaf(base + (offset & 0x7FFFFFFF))
                    if leaf:
                        return leaf
                else:
                    raw = _read(f, base + offset, 16)
                    return struct.unpack("<II", raw[0:8])
            return None

        def icons_by_id():
            directory = find_type(RT_ICON)
            found = {}
            if directory is None:
                return found
            for name, offset in entries(directory):
                if offset & 0x80000000:
                    leaf = first_leaf(base + (offset & 0x7FFFFFFF))
                    if leaf:
                        found[name] = leaf
            return found

        group_dir = find_type(RT_GROUP_ICON)
        if group_dir is None:
            return None
        group = first_leaf(group_dir)
        if not group:
            return None

        group_data = _read(f, to_offset(group[0]), group[1])
        count = struct.unpack("<H", group_data[4:6])[0]
        images = icons_by_id()

        best = None
        best_area = -1
        for i in range(count):
            raw = group_data[6 + i * 14: 20 + i * 14]
            width, height, _colors, _pad, _planes, bpp, _size, ident = struct.unpack("<BBBBHHIH", raw)
            leaf = images.get(ident)
            if not leaf:
                continue
            # 0 means 256 in the icon directory
            area = (width or 256) * (height or 256)
            if area > best_area or (area == best_area and bpp > best[1]):
                best = (_read(f, to_offset(leaf[0]), leaf[1]), bpp)
                best_area = area

        return best[0] if best else None


def _png_chunk(kind, payload):
    return (struct.pack(">I", len(payload)) + kind + payload
            + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF))


def _png_from_rgba(width, height, rows):
    raw = b"".join(b"\x00" + row for row in rows)  # filter type 0 per scanline
    header = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)  # 8-bit RGBA
    return (b"\x89PNG\r\n\x1a\n"
            + _png_chunk(b"IHDR", header)
            + _png_chunk(b"IDAT", zlib.compress(raw, 9))
            + _png_chunk(b"IEND", b""))


def _dib_to_png(blob):
    """Converts a 32bpp icon bitmap to PNG.

    Icon bitmaps are stored bottom-up, in BGRA, and with a height twice the
    real one: the second half is the 1bpp AND mask from the days before an
    alpha channel. Older or paletted depths are left alone — every executable
    seen here ships 32bpp, and guessing at palettes would be a lot of code for
    an icon nobody would recognise anyway.
    """
    if len(blob) < 40:
        return None
    header_size, width, height, _planes, bpp = struct.unpack("<IiiHH", blob[:16])
    if header_size < 40 or bpp != 32 or width <= 0:
        return None

    height = abs(height) // 2 or abs(height)
    pixels = blob[header_size:header_size + width * height * 4]
    if len(pixels) < width * height * 4:
        return None

    stride = width * 4
    rows = []
    for y in range(height - 1, -1, -1):  # bottom-up
        line = pixels[y * stride:(y + 1) * stride]
        rows.append(bytes(b for i in range(0, stride, 4)
                          for b in (line[i + 2], line[i + 1], line[i], line[i + 3])))

    if not any(row[3::4].strip(b"\x00") for row in rows):
        # Fully transparent alpha means the file predates it: opaque is better
        # than invisible.
        rows = [bytes(b if (i % 4) != 3 else 255 for i, b in enumerate(row)) for row in rows]

    return _png_from_rgba(width, height, rows)


def icon_for_exe(exe_path):
    """Returns a cached PNG path for this executable, or "" if it has no icon.

    The cache key includes the file's mtime, so a patched game picks up a new
    icon instead of keeping the one from the version before the update.
    """
    if not exe_path or not os.path.isfile(exe_path):
        return ""

    try:
        stamp = f"{os.path.realpath(exe_path)}:{os.path.getmtime(exe_path)}"
        cached = os.path.join(CACHE_DIR, hashlib.sha1(stamp.encode()).hexdigest() + ".png")
        if os.path.exists(cached):
            return cached if os.path.getsize(cached) > 0 else ""

        os.makedirs(CACHE_DIR, exist_ok=True)

        blob = _largest_image(exe_path)
        png = None
        if blob:
            if blob[:8] == b"\x89PNG\r\n\x1a\n":
                png = blob          # Vista and later may store PNG directly
            else:
                png = _dib_to_png(blob)

        if png:
            partial = cached + ".part"
            with open(partial, "wb") as out:
                out.write(png)
            os.replace(partial, cached)
            return cached

        # Remember the failure too, so a 200MB executable with no usable icon
        # is not parsed again on every window update.
        open(cached, "wb").close()
        return ""
    except Exception:
        return ""


if __name__ == "__main__":
    import sys
    for target in sys.argv[1:]:
        print(target, "->", icon_for_exe(target) or "no icon")
