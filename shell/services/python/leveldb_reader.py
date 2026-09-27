#!/usr/bin/env python3
"""Read-only LevelDB reader, standard library only.

Hydra keeps its game library in a LevelDB database (hydra-db/), and the only
Python bindings for LevelDB are third-party packages this shell does not want
to depend on. The on-disk format is small and stable, so this reads it
directly: the write-ahead log (*.log) and the sorted tables (*.ldb / *.sst),
including the Snappy compression the tables use.

It never writes and never takes the LOCK file, so it is safe to run while the
owning application has the database open. A file that is half-written or
disappears mid-read (a compaction just ran) is skipped; the caller simply
tries again later.
"""
import os
import struct

# Value types stored in the low byte of an internal key's trailer.
_TYPE_DELETION = 0
_TYPE_VALUE = 1

_LOG_BLOCK = 32768
_TABLE_MAGIC = 0xdb4775248b80fb57


def _varint(buf, pos):
    result = 0
    shift = 0
    while True:
        b = buf[pos]
        pos += 1
        result |= (b & 0x7f) << shift
        if not b & 0x80:
            return result, pos
        shift += 7


def snappy_decompress(buf):
    """Raw Snappy block decompression (no framing), as LevelDB stores it."""
    length, pos = _varint(buf, 0)
    out = bytearray()
    n = len(buf)
    while pos < n:
        tag = buf[pos]
        pos += 1
        kind = tag & 3
        if kind == 0:
            # Literal. Lengths above 60 spill into 1-4 extra bytes.
            size = tag >> 2
            if size >= 60:
                extra = size - 59
                size = int.from_bytes(buf[pos:pos + extra], 'little')
                pos += extra
            size += 1
            out += buf[pos:pos + size]
            pos += size
            continue
        if kind == 1:
            size = ((tag >> 2) & 7) + 4
            offset = ((tag >> 5) << 8) | buf[pos]
            pos += 1
        elif kind == 2:
            size = (tag >> 2) + 1
            offset = int.from_bytes(buf[pos:pos + 2], 'little')
            pos += 2
        else:
            size = (tag >> 2) + 1
            offset = int.from_bytes(buf[pos:pos + 4], 'little')
            pos += 4
        if offset <= 0 or offset > len(out):
            raise ValueError('corrupt snappy stream')
        start = len(out) - offset
        # A copy may overlap what it is producing (run-length style), so it
        # has to go byte by byte when the source reaches the write position.
        if offset >= size:
            out += out[start:start + size]
        else:
            for i in range(size):
                out.append(out[start + i])
    if len(out) != length:
        raise ValueError('snappy length mismatch')
    return bytes(out)


def _log_records(data):
    """Reassembles the physical log records into logical ones."""
    pos = 0
    pending = None
    n = len(data)
    while pos + 7 <= n:
        block_left = _LOG_BLOCK - (pos % _LOG_BLOCK)
        if block_left < 7:
            # Trailer padding at the end of a block.
            pos += block_left
            continue
        length = data[pos + 4] | (data[pos + 5] << 8)
        rtype = data[pos + 6]
        payload = data[pos + 7:pos + 7 + length]
        pos += 7 + length
        if rtype == 0 and length == 0:
            # Zero-filled preallocated space: nothing more in this block.
            pos += _LOG_BLOCK - (pos % _LOG_BLOCK) if pos % _LOG_BLOCK else 0
            continue
        if len(payload) < length:
            return  # truncated tail, still being written
        if rtype == 1:      # FULL
            pending = None
            yield payload
        elif rtype == 2:    # FIRST
            pending = bytearray(payload)
        elif rtype == 3:    # MIDDLE
            if pending is not None:
                pending += payload
        elif rtype == 4:    # LAST
            if pending is not None:
                pending += payload
                yield bytes(pending)
            pending = None


def _read_log(path, entries):
    with open(path, 'rb') as fp:
        data = fp.read()
    for rec in _log_records(data):
        if len(rec) < 12:
            continue
        seq = struct.unpack_from('<Q', rec, 0)[0]
        count = struct.unpack_from('<I', rec, 8)[0]
        pos = 12
        try:
            for i in range(count):
                vtype = rec[pos]
                pos += 1
                klen, pos = _varint(rec, pos)
                key = rec[pos:pos + klen]
                pos += klen
                if vtype == _TYPE_VALUE:
                    vlen, pos = _varint(rec, pos)
                    value = rec[pos:pos + vlen]
                    pos += vlen
                else:
                    value = None
                _keep(entries, key, seq + i, value)
        except IndexError:
            continue


def _block_entries(block):
    """Yields (key, value) from one table block, undoing prefix compression."""
    if len(block) < 4:
        return
    num_restarts = struct.unpack_from('<I', block, len(block) - 4)[0]
    limit = len(block) - 4 - 4 * num_restarts
    pos = 0
    key = b''
    while pos < limit:
        shared, pos = _varint(block, pos)
        unshared, pos = _varint(block, pos)
        vlen, pos = _varint(block, pos)
        key = key[:shared] + block[pos:pos + unshared]
        pos += unshared
        value = block[pos:pos + vlen]
        pos += vlen
        yield key, value


def _read_block(data, offset, size):
    raw = data[offset:offset + size]
    ctype = data[offset + size]
    if ctype == 1:
        return snappy_decompress(raw)
    if ctype == 0:
        return raw
    raise ValueError('unsupported block compression %d' % ctype)


def _read_table(path, entries):
    with open(path, 'rb') as fp:
        data = fp.read()
    if len(data) < 48:
        return
    footer = data[-48:]
    if struct.unpack_from('<Q', footer, 40)[0] != _TABLE_MAGIC:
        return
    pos = 0
    _meta_off, pos = _varint(footer, pos)
    _meta_size, pos = _varint(footer, pos)
    index_off, pos = _varint(footer, pos)
    index_size, pos = _varint(footer, pos)
    index = _read_block(data, index_off, index_size)
    for _, handle in _block_entries(index):
        hpos = 0
        boff, hpos = _varint(handle, hpos)
        bsize, hpos = _varint(handle, hpos)
        for ikey, value in _block_entries(_read_block(data, boff, bsize)):
            if len(ikey) < 8:
                continue
            trailer = struct.unpack_from('<Q', ikey, len(ikey) - 8)[0]
            seq = trailer >> 8
            vtype = trailer & 0xff
            _keep(entries, ikey[:-8], seq, value if vtype == _TYPE_VALUE else None)


def _keep(entries, key, seq, value):
    old = entries.get(key)
    if old is None or seq > old[0]:
        entries[key] = (seq, value)


def read_all(db_dir, prefix=None):
    """Returns {key: value} for every live key in the database.

    `prefix` (bytes) limits the result to keys starting with it; the whole
    database is still scanned, which for a launcher's library is small.
    """
    entries = {}
    try:
        names = os.listdir(db_dir)
    except OSError:
        return {}
    for name in names:
        path = os.path.join(db_dir, name)
        try:
            if name.endswith('.log'):
                _read_log(path, entries)
            elif name.endswith('.ldb') or name.endswith('.sst'):
                _read_table(path, entries)
        except (OSError, ValueError, IndexError, struct.error):
            continue
    out = {}
    for key, (_, value) in entries.items():
        if value is None:
            continue
        if prefix is not None and not key.startswith(prefix):
            continue
        out[key] = value
    return out


if __name__ == '__main__':
    import sys
    db = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser('~/.config/hydralauncher/hydra-db')
    pfx = sys.argv[2].encode() if len(sys.argv) > 2 else None
    for k, v in sorted(read_all(db, pfx).items()):
        print(k.decode('utf-8', 'replace'), v[:200].decode('utf-8', 'replace'))
